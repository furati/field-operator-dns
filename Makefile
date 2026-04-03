# ==========================================
# Nutanix Field DNS - Management
# ==========================================

# Dynamic Tool Version Discovery (Bind9 via Alpine)
BIND_VER := $(shell docker run --rm alpine:latest sh -c "apk update > /dev/null && apk info bind -V" | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Project Variables
IMAGE_NAME := field-operator-dns
GITHUB_USER := furati
REGISTRY   := ghcr.io/$(GITHUB_USER)
TOKEN_FILE := .github_token
DOCKER_DIR := ./docker
CONF_DIR   := $(shell pwd)/config

BUILDER_IMAGE := ghcr.io/furati/iac-toolbox:latest
TOKEN_FILE    := .github_token

# TTY Detection für CI/CD
INTERACTIVE := $(shell [ -t 0 ] && [ -z "$$GITHUB_ACTIONS" ] && echo "-it" || echo "")

# Der "Builder"-Befehl: 
# Er braucht Zugriff auf den Docker-Socket des Hosts, um Images zu bauen/pushen
DOCKER_BUILDER := docker run --rm $(INTERACTIVE) \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $(shell [ -f $(HOME)/.docker/config.json ] && echo "-v $(HOME)/.docker/config.json:/root/.docker/config.json") \
    -v "$(shell pwd):/workbench" \
    -w /workbench \
    -e HOST_UID=$(shell id -u) \
    -e HOST_GID=$(shell id -g) \
    -e DOCKER_API_VERSION=1.41 \
    $(BUILDER_IMAGE)

# Exporting Host IDs for Permission Mapping (Crucial for USB/macOS Mounts)
export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

# 1. Robust TTY Detection
# Checks if we are in a terminal AND not in a CI environment (GitHub Actions)
INTERACTIVE := $(shell [ -t 0 ] && [ -z "$$GITHUB_ACTIONS" ] && echo "-it" || echo "")

# 2. Base Docker Command Template
# Note: We mount the config directory as the main working volume
DOCKER_BASE := docker run --rm $(INTERACTIVE) \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $(shell [ -f $(HOME)/.docker/config.json ] && echo "-v $(HOME)/.docker/config.json:/root/.docker/config.json") \
    -v "$(CONF_DIR):/etc/bind:ro" \
    -e HOST_UID=$(HOST_UID) \
    -e HOST_GID=$(HOST_GID) \
    $(IMAGE_NAME)

.DEFAULT_GOAL := help
.PHONY: help build run stop logs test clean push shell

help: ## Display this help information
	@echo "-----------------------------------------------------------------------"
	@echo "Field Operator DNS - Available Commands:"
	@echo "-----------------------------------------------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo "-----------------------------------------------------------------------"
	@echo "Current Configuration:"
	@echo "Bind Version: $(BIND_VER) | Registry: $(REGISTRY)"

build: ## Build the DNS image locally with current Bind9 version
	@echo "--- Starting Build Process ---"
	docker build -t $(IMAGE_NAME) \
		--build-arg BIND_VERSION=$(BIND_VER) \
		--build-arg REPO_URL="https://github.com/$(GITHUB_USER)/$(IMAGE_NAME)" \
		-f $(DOCKER_DIR)/Dockerfile $(DOCKER_DIR)

run: ## Launch the DNS server in background (Daemon Mode)
	@if [ ! -f "$(CONF_DIR)/named.conf" ]; then echo "Error: $(CONF_DIR)/named.conf missing!"; exit 1; fi
	@echo "--- Starting DNS Service ---"
	@docker run -d --name $(IMAGE_NAME) \
		-e HOST_UID=$(HOST_UID) -e HOST_GID=$(HOST_GID) \
		-p 53:53/udp -p 53:53/tcp \
		-v "$(CONF_DIR):/etc/bind:ro" \
		$(IMAGE_NAME) > /dev/null
	@echo "✅ DNS is running. Use 'make test' to verify."

stop: ## Stop and remove the running DNS container
	@docker stop $(IMAGE_NAME) 2>/dev/null || true
	@docker rm $(IMAGE_NAME) 2>/dev/null || true

logs: ## View live Bind9 logs (Ctrl+C to exit)
	docker logs -f $(IMAGE_NAME)

test: ## Agnostic Smoke Test: Verify localhost resolution
	@echo "--- Starting DNS Smoke Test ---"
	@nslookup localhost 127.0.0.1 > /dev/null && \
		echo "✅ DNS service is responding correctly." || \
		(echo "❌ DNS Error: Service not responding." && exit 1)

shell: ## Open an interactive shell inside the container
	docker exec -it $(IMAGE_NAME) /bin/sh

push: ## Nutzt die iac-toolbox (Ansible), um den DNS-Container zu pushen
	@if [ -n "$$GITHUB_TOKEN" ]; then \
		TOKEN="$$GITHUB_TOKEN"; \
	elif [ -f $(TOKEN_FILE) ]; then \
		TOKEN=$$(cat $(TOKEN_FILE)); \
	else \
		echo "No token found. Please enter your GitHub PAT: "; \
		read secret; \
		TOKEN=$$secret; \
	fi; \
	if [ -z "$$TOKEN" ]; then \
		echo "ERROR: Authentication token is required."; exit 1; \
	fi; \
	echo "--- Starting Push Workflow via Toolbox (Ansible) ---"; \
	$(DOCKER_BUILDER) ansible-playbook build-and-push.yml -e "gh_token=$$TOKEN"

clean: stop ## Prune local image and dangling layers
	docker rmi $(IMAGE_NAME) 2>/dev/null || true