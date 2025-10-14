export DOCKER_BUILDKIT=1

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
		-p 8080:8080 \
		-v /Users/nebojsaprodana/dev/personal/certs:/certs \
		autofirma-legacy

clean:
	docker rmi autofirma-legacy 2>/dev/null || true
	docker system prune -f

rebuild: clean run