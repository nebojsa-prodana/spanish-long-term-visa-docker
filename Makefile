export DOCKER_BUILDKIT=1

# Get absolute path to certs directory
CERTS_DIR := $(shell pwd)/certs
CONTAINER_NAME := autofirma-legacy
IMAGE_NAME := ghcr.io/nebojsa-prodana/spanish-long-term-visa-docker:main

run:
	@echo "Pulling latest image from GHCR..."
	docker pull --platform=linux/amd64 $(IMAGE_NAME)
	docker run -it \
		--platform=linux/amd64 \
		--name $(CONTAINER_NAME) \
		-p 8080:8080 \
		-v $(CERTS_DIR):/certs \
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
	docker run -it \
		--platform=linux/amd64 \
		--name $(CONTAINER_NAME) \
		-p 8080:8080 \
		-v $(CERTS_DIR):/certs \
		autofirma-legacy

shell:
	docker exec -it $(CONTAINER_NAME) bash

clean:
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

rebuild: clean build-and-run