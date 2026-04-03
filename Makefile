# ==========================================
# Nutanix Field DNS - Management
# ==========================================

# Dynamische Ermittlung der Bind-Version (Alpine Repository)
BIND_VER := $(shell docker run --rm alpine:latest sh -c "apk update > /dev/null && apk info bind -V" | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
IMAGE_NAME := nutanix-field-dns
REGISTRY   := registry.deine-firma.de/nutanix-tools

# Host IDs für das Permission-Mapping (wichtig für USB-Sticks/macOS Mounts)
export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

# Pfade basierend auf deiner Verzeichnisstruktur
DOCKER_DIR := ./docker
CONF_DIR   := $(shell pwd)/config

.DEFAULT_GOAL := help

.PHONY: help build run stop logs test clean push shell

help: ## Zeigt diese Hilfe und die aktuelle Tool-Konfiguration an
	@echo "\033[33mUsage:\033[0m make [target]"
	@echo ""
	@echo "\033[32m--- PROJEKT ADMINISTRATION ---\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {if ($$1 !~ /run|stop|logs|test/) printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[32m--- FIELD OPERATIONS (IM EINSATZ) ---\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {if ($$1 ~ /run|stop|logs|test/) printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[33mKonfiguration:\033[0m"
	@echo "  Bind Version: $(BIND_VER)"
	@echo "  Projekt-Pfad: $(shell pwd)"
	@echo "  Config-Pfad:  $(CONF_DIR)"

build: ## Erstellt das Docker-Image lokal (nutzt ./docker/Dockerfile)
	@echo "--- Starte Build-Prozess für Version $(BIND_VER) ---"
	docker build -t $(IMAGE_NAME) \
		--build-arg BIND_VERSION=$(BIND_VER) \
		-f $(DOCKER_DIR)/Dockerfile $(DOCKER_DIR)

run: ## Startet den DNS-Dienst im Hintergrund
	@if [ ! -f "$(CONF_DIR)/named.conf" ]; then echo "Fehler: $(CONF_DIR)/named.conf fehlt!"; exit 1; fi
	@echo "--- Starte Nutanix Field DNS Container ---"
	@docker run -d \
		--name $(IMAGE_NAME) \
		-e HOST_UID=$(HOST_UID) \
		-e HOST_GID=$(HOST_GID) \
		-p 53:53/udp -p 53:53/tcp \
		-v "$(CONF_DIR):/etc/bind:ro" \
		$(IMAGE_NAME) > /dev/null
	@echo "✅ Container läuft im Hintergrund."
	@echo "👉 Logs einsehen mit:  make logs"
	@echo "👉 Testen mit:         make test"

stop: ## Beendet den DNS-Dienst und entfernt den Container
	@echo "--- Stoppe DNS Dienst ---"
	docker stop $(IMAGE_NAME) 2>/dev/null || true
	docker rm $(IMAGE_NAME) 2>/dev/null || true

logs: ## Zeigt die Live-Logs des DNS-Servers an (Strg+C zum Beenden)
	docker logs -f $(IMAGE_NAME)

test: ## Validiert die DNS-Grundfunktion (agnostisch via localhost)
	@echo "--- Teste DNS Erreichbarkeit (localhost) ---"
	@nslookup localhost 127.0.0.1 > /dev/null && \
		echo "✅ DNS Dienst ist bereit und antwortet." || \
		(echo "❌ DNS Fehler: Dienst antwortet nicht auf localhost." && exit 1)
shell: ## Öffnet eine interaktive Shell im Container (nur für Debugging)
	docker exec -it $(IMAGE_NAME) /bin/sh

push: ## Taggt das Image und pusht es in die Firmen-Registry
	@echo "--- Push zu $(REGISTRY) ---"
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME):latest
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME):$(BIND_VER)
	docker push $(REGISTRY)/$(IMAGE_NAME):latest
	docker push $(REGISTRY)/$(IMAGE_NAME):$(BIND_VER)

clean: stop ## Bereinigt die Docker-Umgebung (Stoppt Dienst und löscht Image)
	docker rmi $(IMAGE_NAME) 2>/dev/null || true