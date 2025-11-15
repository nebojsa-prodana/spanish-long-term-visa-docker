export DOCKER_BUILDKIT=1

# Get absolute path to certs directory
CERTS_DIR := $(shell pwd)/certs
CITA_DIR := $(shell pwd)/cita-checker
ENV_FILE := $(shell pwd)/cita-checker/.env
CONTAINER_NAME := visa-autofirma
IMAGE_NAME := ghcr.io/nebojsa-prodana/spanish-long-term-visa-docker:main

.PHONY: help
help:
	@echo "Spanish Long-Term Visa Docker - Makefile Commands"
	@echo ""
	@echo "Container Management:"
	@echo "  make run              - Pull and run the latest image from GHCR"
	@echo "  make build-and-run    - Build and run the container locally"
	@echo "  make shell            - Open a bash shell in the running container"
	@echo "  make clean            - Remove container and image"
	@echo "  make rebuild          - Clean and rebuild"
	@echo ""
	@echo "Cita Checking:"
	@echo "  make check-cita       - Check for cita availability once (uses .env config)"
	@echo "  make monitor-start    - Start continuous monitoring (checks every N minutes)"
	@echo "  make monitor-stop     - Stop continuous monitoring"
	@echo "  make monitor-status   - Check monitoring status"
	@echo "  make monitor-logs     - View monitoring logs"
	@echo ""
	@echo "Setup:"
	@echo "  1. Copy cita-checker/.env.example to cita-checker/.env"
	@echo "  2. Edit .env with your settings (NEVER commit this file!)"
	@echo "  3. Run 'make build-and-run' or 'make run'"
	@echo "  4. Open http://localhost:8080/vnc.html in your browser"
	@echo ""
	@echo "Note: .env file is mounted as read-only volume for security"


run:
	@echo "Pulling latest image from GHCR..."
	docker pull --platform=linux/amd64 $(IMAGE_NAME)
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "WARNING: .env file not found at $(ENV_FILE)"; \
		echo "Creating from .env.example..."; \
		cp $(CITA_DIR)/.env.example $(ENV_FILE); \
		echo "Please edit $(ENV_FILE) with your settings!"; \
	fi
	docker run -it \
		--platform=linux/amd64 \
		--name $(CONTAINER_NAME) \
		-p 8080:8080 \
		-v $(CERTS_DIR):/certs \
		-v $(CITA_DIR):/workspace/cita-checker \
		-v $(ENV_FILE):/workspace/cita-checker/.env:ro \
		$(IMAGE_NAME)

build-and-run:
	@echo "Building autofirma-legacy container with retries..."
	@for i in 1 2 3; do \
		echo "Build attempt $$i..."; \
		if docker build --platform=linux/amd64 -t autofirma-legacy .; then \
			echo "Build successful on attempt $$i"; \
			break; \
		else \
			echo "Build attempt $$i failed"; \
			if [ $$i -eq 3 ]; then \
				echo "All build attempts failed"; \
				exit 1; \
			fi; \
			sleep 10; \
		fi; \
	done
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "WARNING: .env file not found at $(ENV_FILE)"; \
		echo "Creating from .env.example..."; \
		cp $(CITA_DIR)/.env.example $(ENV_FILE); \
		echo "Please edit $(ENV_FILE) with your settings!"; \
	fi
	docker run -it \
		--platform=linux/amd64 \
		--name $(CONTAINER_NAME) \
		-p 8080:8080 \
		-v $(CERTS_DIR):/certs \
		-v $(CITA_DIR):/workspace/cita-checker \
		-v $(ENV_FILE):/workspace/cita-checker/.env:ro \
		autofirma-legacy

shell:
	docker exec -it $(CONTAINER_NAME) bash

# Check for cita availability once (reads .env for config)
check-cita:
	@echo "Checking for cita availability..."
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "ERROR: .env file not found at $(ENV_FILE)"; \
		echo "Please copy .env.example to .env and configure it"; \
		exit 1; \
	fi
	docker exec -it $(CONTAINER_NAME) bash -c "pkill -9 firefox 2>/dev/null || true; sleep 2; python3 -B /workspace/cita-checker/check-cita.py -p \$$(grep '^PROVINCIA=' /workspace/cita-checker/.env | cut -d= -f2) -o \$$(grep '^OFICINA=' /workspace/cita-checker/.env | cut -d= -f2) -t \$$(grep '^TRAMITE=' /workspace/cita-checker/.env | cut -d= -f2)"

# Start continuous monitoring (checks every N minutes, reads .env for config)
monitor-start:
	@echo "Starting continuous cita monitoring..."
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "ERROR: .env file not found at $(ENV_FILE)"; \
		echo "Please copy .env.example to .env and configure it"; \
		exit 1; \
	fi
	docker exec -d $(CONTAINER_NAME) bash -c "/workspace/cita-checker/monitor-cita.sh start"
	@echo ""
	@echo "Monitor started in background!"
	@echo "Use 'make monitor-status' to check status"
	@echo "Use 'make monitor-logs' to view logs"
	@echo "Use 'make monitor-stop' to stop monitoring"

# Stop continuous monitoring
monitor-stop:
	@echo "Stopping cita monitor..."
	docker exec -it $(CONTAINER_NAME) bash -c "/workspace/cita-checker/monitor-cita.sh stop"

# Check monitoring status
monitor-status:
	docker exec -it $(CONTAINER_NAME) bash -c "/workspace/cita-checker/monitor-cita.sh status"

# View monitoring logs
monitor-logs:
	docker exec -it $(CONTAINER_NAME) bash -c "/workspace/cita-checker/monitor-cita.sh logs"

clean:
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

rebuild: clean build-and-run