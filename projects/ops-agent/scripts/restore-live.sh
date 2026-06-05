#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
LIVE_DIR="$ROOT_DIR/data/live"
RESTORE_DIR="$ROOT_DIR/_archive/restore-replaced"

if [[ $# -ne 1 ]]; then
  print "Usage: projects/ops-agent/scripts/restore-live.sh _archive/backups/kosmos-live-YYYYMMDD-HHMMSS-label.tar.gz" >&2
  exit 64
fi

BACKUP="$1"
if [[ "$BACKUP" != /* ]]; then
  BACKUP="$ROOT_DIR/$BACKUP"
fi

if [[ ! -f "$BACKUP" ]]; then
  print "Backup не найден: $BACKUP" >&2
  exit 66
fi

if command -v lsof >/dev/null 2>&1 && lsof -a -iTCP:5050 -sTCP:LISTEN -n -P >/dev/null 2>&1; then
  print "CRM запущена на 5050. Закрой CRM перед restore." >&2
  exit 69
fi

"$ROOT_DIR/projects/ops-agent/scripts/backup-live.sh" before-restore

TMP_DIR="$ROOT_DIR/_archive/.restore-tmp-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$TMP_DIR"
tar -xzf "$BACKUP" -C "$TMP_DIR"

if [[ ! -d "$TMP_DIR/live" ]]; then
  rm -rf "$TMP_DIR"
  print "В архиве нет папки live, restore остановлен." >&2
  exit 65
fi

mkdir -p "$RESTORE_DIR"
if [[ -d "$LIVE_DIR" ]]; then
  mv "$LIVE_DIR" "$RESTORE_DIR/live-$(date '+%Y%m%d-%H%M%S')"
fi

mkdir -p "$(dirname "$LIVE_DIR")"
mv "$TMP_DIR/live" "$LIVE_DIR"
rm -rf "$TMP_DIR"

print "Restore готов: $LIVE_DIR"
