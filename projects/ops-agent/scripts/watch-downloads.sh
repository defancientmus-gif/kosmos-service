#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SOURCE_DIR="${1:-$HOME/Downloads}"
TARGET_DIR="${2:-$ROOT_DIR/_inbox/fns}"
STAMP_FILE="${3:-/private/tmp/kosmos-fns-watch-start}"

mkdir -p "$TARGET_DIR"
touch "$STAMP_FILE"

echo "Watching: $SOURCE_DIR"
echo "Copying new files to: $TARGET_DIR"
echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"

while true; do
  find "$SOURCE_DIR" -maxdepth 1 -type f -newer "$STAMP_FILE" \
    ! -name ".DS_Store" \
    ! -name "*.download" \
    ! -name "*.crdownload" \
    ! -name "*.part" \
    ! -name "*.tmp" \
    -print0 | while IFS= read -r -d '' file; do
      name="$(basename "$file")"
      target="$TARGET_DIR/$name"

      if [[ ! -e "$target" ]]; then
        cp -p "$file" "$target"
        echo "Copied: $name"
      fi
    done

  sleep 5
done
