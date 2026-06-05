#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
LIVE_DIR="$ROOT_DIR/data/live"
BACKUP_DIR="${KOSMOS_BACKUP_DIR:-$ROOT_DIR/_archive/backups}"
KEEP="${KOSMOS_BACKUP_KEEP:-60}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
LABEL="${1:-manual}"

mkdir -p "$BACKUP_DIR"

if [[ ! -d "$LIVE_DIR" ]]; then
  print "Нет data/live, backup пропущен."
  exit 0
fi

TMP_DIR="$BACKUP_DIR/.tmp-$STAMP"
OUT="$BACKUP_DIR/kosmos-live-$STAMP-$LABEL.tar.gz"
mkdir -p "$TMP_DIR/live"

cp -R "$LIVE_DIR/." "$TMP_DIR/live/"

DB_PATH="$LIVE_DIR/kosmos_crm.db"
DB_COPY="$TMP_DIR/live/kosmos_crm.db"
if [[ -f "$DB_PATH" ]] && command -v sqlite3 >/dev/null 2>&1; then
  rm -f "$DB_COPY"
  sqlite3 "$DB_PATH" "VACUUM INTO '$DB_COPY';"
fi

tar -czf "$OUT" -C "$TMP_DIR" live
rm -rf "$TMP_DIR"

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$OUT" > "$OUT.sha256"
fi

backups=("$BACKUP_DIR"/kosmos-live-*.tar.gz(N.om))
if (( ${#backups} > KEEP )); then
  for old in "${backups[@]:$KEEP}"; do
    rm -f "$old" "$old.sha256"
  done
fi

print "Backup готов: $OUT"
