export DOCKER_BUILDKIT=1

# Get absolute path to certs directory
CERTS_DIR := $(shell pwd)/certs
CONTAINER_NAME := autofirma-legacy

run:
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
	docker rmi autofirma-legacy 2>/dev/null || true
	docker system prune -f

rebuild: clean run