#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SOURCE_KIND="${1:-manual}"
STAMP_FILE="${3:-/private/tmp/kosmos-docs-watch-start-${SOURCE_KIND}}"

source_dir_for() {
  case "$1" in
    fns) echo "$ROOT_DIR/Загрузки Космос/ФНС" ;;
    bank) echo "$ROOT_DIR/Загрузки Космос/Банк" ;;
    suppliers) echo "$ROOT_DIR/Загрузки Космос/Поставщики" ;;
    livesklad) echo "$ROOT_DIR/Загрузки Космос/LiveSklad" ;;
    manual) echo "$ROOT_DIR/Загрузки Космос/Вручную" ;;
    *) return 1 ;;
  esac
}

SOURCE_DIR="${2:-$(source_dir_for "$SOURCE_KIND")}"

case "$SOURCE_KIND" in
  fns)
    HUMAN_TARGET="$ROOT_DIR/Документы Космос/00_Входящие/ФНС"
    TECH_TARGET="$ROOT_DIR/_inbox/fns"
    ;;
  bank)
    HUMAN_TARGET="$ROOT_DIR/Документы Космос/00_Входящие/Банк"
    TECH_TARGET="$ROOT_DIR/_inbox/bank"
    ;;
  suppliers)
    HUMAN_TARGET="$ROOT_DIR/Документы Космос/00_Входящие/Поставщики"
    TECH_TARGET="$ROOT_DIR/_inbox/suppliers"
    ;;
  livesklad)
    HUMAN_TARGET="$ROOT_DIR/Документы Космос/00_Входящие/LiveSklad"
    TECH_TARGET="$ROOT_DIR/_inbox/livesklad"
    ;;
  manual)
    HUMAN_TARGET="$ROOT_DIR/Документы Космос/00_Входящие/Вручную"
    TECH_TARGET="$ROOT_DIR/_inbox/manual"
    ;;
  *)
    echo "Unknown source: $SOURCE_KIND"
    echo "Use one of: fns, bank, suppliers, livesklad, manual"
    exit 2
    ;;
esac

mkdir -p "$SOURCE_DIR" "$HUMAN_TARGET" "$TECH_TARGET"
touch "$STAMP_FILE"

echo "Watching: $SOURCE_DIR"
echo "Source kind: $SOURCE_KIND"
echo "Drop files here: $SOURCE_DIR"
echo "Human inbox: $HUMAN_TARGET"
echo "Agent inbox: $TECH_TARGET"
echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Stop with Ctrl+C"

while true; do
  find "$SOURCE_DIR" -maxdepth 1 -type f -newer "$STAMP_FILE" \
    ! -name ".DS_Store" \
    ! -name "*.download" \
    ! -name "*.crdownload" \
    ! -name "*.part" \
    ! -name "*.tmp" \
    -print0 | while IFS= read -r -d '' file; do
      name="$(basename "$file")"
      human_target="$HUMAN_TARGET/$name"
      tech_target="$TECH_TARGET/$name"

      if [[ ! -e "$human_target" ]]; then
        cp -p "$file" "$human_target"
        echo "Copied to documents: $name"
      fi

      if [[ ! -e "$tech_target" ]]; then
        cp -p "$file" "$tech_target"
        echo "Copied to agent inbox: $name"
      fi
    done

  sleep 5
done
