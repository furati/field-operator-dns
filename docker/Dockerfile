FROM alpine:latest

# Argumente für Flexibilität beim Build (können via --build-arg überschrieben werden)
ARG BIND_VERSION="9.18"
ARG REPO_URL="https://github.com/furati/field-operator-dns.git"
ARG AUTHOR_NAME="Ralf Buhlrich"
ARG AUTHOR_EMAIL="ralf@buhlrich.com"

# OCI Standard Labels für die Registry-Integration
LABEL org.opencontainers.image.title="Field Operator DNS" \
    org.opencontainers.image.description="Lightweight Bind9 DNS Server for Field Operators" \
    org.opencontainers.image.url=${REPO_URL} \
    org.opencontainers.image.source=${REPO_URL} \
    org.opencontainers.image.version=${BIND_VERSION} \
    org.opencontainers.image.licenses="MIT" \
    # Custom tool version metadata
    tool.bind.version=${BIND_VERSION} \
    tool.base.image="alpine:latest" \
    # Author/Vendor Informationen
    org.opencontainers.image.vendor="${AUTHOR_NAME} <${AUTHOR_EMAIL}>" \
    org.opencontainers.image.authors="${AUTHOR_NAME} <${AUTHOR_EMAIL}>"

# Installation von Bind9 und su-exec
RUN apk add --no-cache bind su-exec bash

# Verzeichnisse vorbereiten
RUN mkdir -p /var/cache/bind /var/run/named /var/log/named && \
    chmod -R 777 /var/cache/bind /var/run/named /var/log/named

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Standard-Pfad für die Konfiguration
VOLUME ["/etc/bind"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Standard-Command falls kein su-exec greift
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf"]