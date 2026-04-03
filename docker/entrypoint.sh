#!/bin/sh
set -e

# Falls HOST_UID und HOST_GID gesetzt sind, User dynamisch anlegen
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    
    # 1. Gruppe behandeln
    EXISTING_GROUP=$(getent group "$HOST_GID" | cut -d: -f1)
    if [ -z "$EXISTING_GROUP" ]; then
        addgroup -g "$HOST_GID" nxgroup
        GROUP_NAME="nxgroup"
    else
        GROUP_NAME="$EXISTING_GROUP"
    fi

    # 2. User behandeln
    EXISTING_USER=$(getent passwd "$HOST_UID" | cut -d: -f1)
    if [ -z "$EXISTING_USER" ]; then
        adduser -D -u "$HOST_UID" -G "$GROUP_NAME" nxuser
        USER_NAME="nxuser"
    else
        USER_NAME="$EXISTING_USER"
    fi

    # 3. DNS-Spezifische Berechtigungen
    # Bind benötigt Schreibrechte in seinem Cache/Run Verzeichnis
    chown -R "$USER_NAME":"$GROUP_NAME" /var/cache/bind /var/run/named /var/log/named 2>/dev/null || true

    echo "Starte DNS als User: $USER_NAME ($HOST_UID) in Gruppe: $GROUP_NAME ($HOST_GID)"
    
    # Startet 'named' über su-exec mit den Rechten des Host-Users
    # -g: im Vordergrund, -u: User im Container, -c: Config-Pfad
    exec su-exec "$USER_NAME" /usr/sbin/named -g -u "$USER_NAME" -c /etc/bind/named.conf
fi

# Fallback, falls keine IDs übergeben wurden
exec "$@"