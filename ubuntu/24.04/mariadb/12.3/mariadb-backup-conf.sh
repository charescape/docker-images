#!/bin/sh

# Load MARIADB_BACKUP_* from /wwwdata/misc/mariadb12v3.conf (KEY=VALUE).
# Source this file. Does not source the conf file.

CONTAINER_CONF="${CONTAINER_CONF:-/wwwdata/misc/mariadb12v3.conf}"

MARIADB_BACKUP_ENABLE=0
MARIADB_BACKUP_HOUR=3
MARIADB_BACKUP_MINUTE=0
MARIADB_BACKUP_KEEP_DAYS=30
MARIADB_BACKUP_DIR=/wwwdata/misc/backup

if [ -f "$CONTAINER_CONF" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '\r')
    trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
    case "$trimmed" in
      '' | \#*) continue ;;
    esac
    case "$trimmed" in
      *=*) ;;
      *) continue ;;
    esac
    key=$(printf '%s' "${trimmed%%=*}" | sed 's/[[:space:]]*$//')
    val="${trimmed#*=}"
    case "$key" in
      MARIADB_BACKUP_ENABLE | MARIADB_BACKUP_HOUR | MARIADB_BACKUP_MINUTE | MARIADB_BACKUP_KEEP_DAYS | MARIADB_BACKUP_DIR) ;;
      *) continue ;;
    esac
    case "$val" in
      \"*\")
        val="${val#\"}"
        val="${val%\"}"
        ;;
      \'*\')
        val="${val#\'}"
        val="${val%\'}"
        ;;
    esac
    case "$key" in
      MARIADB_BACKUP_ENABLE) MARIADB_BACKUP_ENABLE="$val" ;;
      MARIADB_BACKUP_HOUR) MARIADB_BACKUP_HOUR="$val" ;;
      MARIADB_BACKUP_MINUTE) MARIADB_BACKUP_MINUTE="$val" ;;
      MARIADB_BACKUP_KEEP_DAYS) MARIADB_BACKUP_KEEP_DAYS="$val" ;;
      MARIADB_BACKUP_DIR) MARIADB_BACKUP_DIR="$val" ;;
    esac
  done <"$CONTAINER_CONF"
fi

unset line trimmed key val
