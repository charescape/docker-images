#!/bin/sh
set -eu

# Wait until mariadbd accepts SQL on the Unix socket (build-time / one-shot helper).
MARIADB="${MARIADB:-/usr/local/mysql/bin/mariadb}"
TIMEOUT="${1:-90}"
i=0

until "$MARIADB" -h localhost --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge "$TIMEOUT" ]; then
    echo "mariadbd did not become ready within ${TIMEOUT}s" >&2
    exit 1
  fi
  sleep 1
done
