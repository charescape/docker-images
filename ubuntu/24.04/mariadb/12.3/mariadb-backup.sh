#!/bin/bash
set -euo pipefail

# Logical dump via Unix socket (my.cnf [mariadb-dump] defaults to TCP).
# Settings from /wwwdata/misc/mariadb12v3.conf (MARIADB_BACKUP_*).
# --scheduled: heartbeat from cron; HOUR/MINUTE (TZ) may dump; ENABLE off skips.
# Manual run (no --scheduled) does not check time or ENABLE.

scheduled=0
if [ "${1:-}" = "--scheduled" ]; then
  scheduled=1
fi

# shellcheck disable=SC1091
. /usr/local/sbin/mariadb-backup-conf.sh

if [ "$scheduled" -eq 1 ]; then
  case "${MARIADB_BACKUP_HOUR}" in
    0 | [1-9] | 1[0-9] | 2[0-3]) ;;
    *)
      echo "mariadb-backup: invalid MARIADB_BACKUP_HOUR=${MARIADB_BACKUP_HOUR}" >&2
      exit 1
      ;;
  esac
  case "${MARIADB_BACKUP_MINUTE}" in
    0 | [1-9] | [1-5][0-9]) ;;
    *)
      echo "mariadb-backup: invalid MARIADB_BACKUP_MINUTE=${MARIADB_BACKUP_MINUTE}" >&2
      exit 1
      ;;
  esac
  if [ "$(date +%H:%M)" != "$(printf '%02d:%02d' "$MARIADB_BACKUP_HOUR" "$MARIADB_BACKUP_MINUTE")" ]; then
    exit 0
  fi
fi

MARIADB="${MARIADB:-/usr/local/mysql/bin/mariadb}"
MARIADB_DUMP="${MARIADB_DUMP:-/usr/local/mysql/bin/mariadb-dump}"
ZSTD="${ZSTD:-/usr/bin/zstd}"
MARIADB_BACKUP_DIR="${MARIADB_BACKUP_DIR:-/wwwdata/misc/backup}"
MARIADB_BACKUP_KEEP_DAYS="${MARIADB_BACKUP_KEEP_DAYS:-30}"
READY_TIMEOUT="${MARIADB_BACKUP_READY_TIMEOUT:-90}"

mkdir -p "$MARIADB_BACKUP_DIR"
LOG="${MARIADB_BACKUP_DIR}/backup.log"
touch "$LOG"
chown www-data:www-data "$MARIADB_BACKUP_DIR" "$LOG" || true

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"
}

if [ "$scheduled" -eq 1 ]; then
  enabled=0
  case "${MARIADB_BACKUP_ENABLE:-0}" in
    1|true|TRUE|yes|YES|on|ON) enabled=1 ;;
  esac
  if [ "$enabled" -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') backup skipped MARIADB_BACKUP_ENABLE=${MARIADB_BACKUP_ENABLE}" >>"$LOG"
    exit 0
  fi
fi

LOCK_FILE="/var/lock/mariadb-backup.lock"
mkdir -p /var/lock
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "mariadb-backup: another backup is already running" >&2
  exit 1
fi

case "$MARIADB_BACKUP_KEEP_DAYS" in
  ''|*[!0-9]*)
    log "invalid MARIADB_BACKUP_KEEP_DAYS=${MARIADB_BACKUP_KEEP_DAYS}"
    exit 1
    ;;
esac

log "backup start dir=${MARIADB_BACKUP_DIR} keep_days=${MARIADB_BACKUP_KEEP_DAYS}"

i=0
until "$MARIADB" -h localhost --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge "$READY_TIMEOUT" ]; then
    log "mariadbd did not become ready within ${READY_TIMEOUT}s"
    exit 1
  fi
  sleep 1
done

STAMP="$(date +%Y%m%d-%H%M%S)"
BASENAME="all-databases-${STAMP}.sql.zst"
TMP="${MARIADB_BACKUP_DIR}/${BASENAME}.tmp"
FINAL="${MARIADB_BACKUP_DIR}/${BASENAME}"

rm -f "$TMP"
trap 'rm -f "$TMP"' EXIT

log "dump ${BASENAME}"
if ! "$MARIADB_DUMP" -h localhost --protocol=socket -u root \
  --all-databases \
  --single-transaction \
  --routines \
  --events \
  --triggers \
  --hex-blob \
  --default-character-set=utf8mb4 \
  | "$ZSTD" -T2 -q -o "$TMP"; then
  log "backup failed"
  exit 1
fi

mv "$TMP" "$FINAL"
chown www-data:www-data "$FINAL"
trap - EXIT

find "$MARIADB_BACKUP_DIR" -maxdepth 1 -name 'all-databases-*.sql.zst.tmp' -delete
find "$MARIADB_BACKUP_DIR" -maxdepth 1 -name 'all-databases-*.sql.zst' -mtime "+${MARIADB_BACKUP_KEEP_DAYS}" -delete

log "backup ok ${FINAL} ($(du -h "$FINAL" | awk '{print $1}'))"
