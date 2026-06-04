#!/usr/bin/env zsh
set -euo pipefail
setopt typeset_silent

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
COMMAND="${1:-help}"

source_names=(fns bank suppliers livesklad manual)

source_dropzone_for() {
  case "$1" in
    fns) echo "$ROOT_DIR/Загрузки Космос/ФНС" ;;
    bank) echo "$ROOT_DIR/Загрузки Космос/Банк" ;;
    suppliers) echo "$ROOT_DIR/Загрузки Космос/Поставщики" ;;
    livesklad) echo "$ROOT_DIR/Загрузки Космос/LiveSklad" ;;
    manual) echo "$ROOT_DIR/Загрузки Космос/Вручную" ;;
    *) return 1 ;;
  esac
}

human_target_for() {
  case "$1" in
    fns) echo "$ROOT_DIR/Документы Космос/00_Входящие/ФНС" ;;
    bank) echo "$ROOT_DIR/Документы Космос/00_Входящие/Банк" ;;
    suppliers) echo "$ROOT_DIR/Документы Космос/00_Входящие/Поставщики" ;;
    livesklad) echo "$ROOT_DIR/Документы Космос/00_Входящие/LiveSklad" ;;
    manual) echo "$ROOT_DIR/Документы Космос/00_Входящие/Вручную" ;;
    *) return 1 ;;
  esac
}

tech_target_for() {
  case "$1" in
    fns) echo "$ROOT_DIR/_inbox/fns" ;;
    bank) echo "$ROOT_DIR/_inbox/bank" ;;
    suppliers) echo "$ROOT_DIR/_inbox/suppliers" ;;
    livesklad) echo "$ROOT_DIR/_inbox/livesklad" ;;
    manual) echo "$ROOT_DIR/_inbox/manual" ;;
    *) return 1 ;;
  esac
}

count_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "0"
    return
  fi

  find "$dir" -maxdepth 1 -type f ! -name ".DS_Store" | wc -l | tr -d " "
}

print_header() {
  echo
  echo "== $1 =="
}

ensure_source() {
  local source_kind="$1"
  if (( ${source_names[(Ie)$source_kind]} == 0 )); then
    echo "Unknown source: $source_kind"
    echo "Use one of: ${source_names[*]}"
    exit 2
  fi
}

cmd_help() {
  cat <<'HELP'
Kosmos Auto — безопасный командный центр рутины

Usage:
  projects/ops-agent/scripts/kosmos-auto.sh init
  projects/ops-agent/scripts/kosmos-auto.sh dashboard
  projects/ops-agent/scripts/kosmos-auto.sh preflight
  projects/ops-agent/scripts/kosmos-auto.sh inbox
  projects/ops-agent/scripts/kosmos-auto.sh watch <fns|bank|suppliers|livesklad|manual> [source-dir]
  projects/ops-agent/scripts/kosmos-auto.sh review
  projects/ops-agent/scripts/kosmos-auto.sh smoke
  projects/ops-agent/scripts/kosmos-auto.sh all

Commands:
  init       Создаёт локальные приватные папки и недостающие таблицы data/live из шаблонов. Не перезаписывает.
  dashboard  Показывает путь к локальной HTML-доске документов.
  preflight  Проверяет структуру, git, игнор приватных папок и базовые файлы памяти.
  inbox      Показывает количество файлов во входящих папках.
  watch      Запускает приёмщик из локальной папки Загрузки Космос/<источник>.
  review     Показывает git status, diff stat и быстрые предупреждения перед commit.
  smoke      Проверяет синтаксис shell-скриптов ops-agent.
  all        Выполняет preflight + inbox + smoke + review.
HELP
}

cmd_init() {
  exec "$ROOT_DIR/projects/ops-agent/scripts/init-vault.sh"
}

cmd_dashboard() {
  print_header "Dashboard"
  echo "$ROOT_DIR/projects/ops-agent/dashboard/index.html"
}

cmd_preflight() {
  print_header "Preflight"
  echo "Root: $ROOT_DIR"

  print_header "Required files"
  local required=(
    "AGENTS.md"
    "CLAUDE.md"
    "texts/README.md"
    "texts/NEXT.md"
    "projects/ops-agent/README.md"
    ".gitignore"
  )
  for file in "${required[@]}"; do
    if [[ -f "$ROOT_DIR/$file" ]]; then
      echo "ok   $file"
    else
      echo "MISS $file"
    fi
  done

  print_header "Git"
  git -C "$ROOT_DIR" status --short --branch

  print_header "Private paths ignored by git"
  local ignored=(
    "_inbox"
    "_archive"
    "Документы Космос"
    "Загрузки Космос"
    "data/live"
    ".env"
  )
  for ignored_path in "${ignored[@]}"; do
    if git -C "$ROOT_DIR" check-ignore -q "$ignored_path"; then
      echo "ok   $ignored_path"
    else
      echo "WARN not ignored: $ignored_path"
    fi
  done

  print_header "Remote"
  if git -C "$ROOT_DIR" remote -v | grep -q .; then
    git -C "$ROOT_DIR" remote -v
  else
    echo "No git remote configured"
  fi

  print_header "Web/PWA"
  if [[ -f "$ROOT_DIR/projects/site/index.html" ]]; then
    echo "site index: projects/site/index.html"
  fi
  if [[ -f "$ROOT_DIR/projects/site/sw.js" ]]; then
    echo "service worker: projects/site/sw.js"
  else
    echo "service worker: not present"
  fi
  if find "$ROOT_DIR/projects/site" -maxdepth 1 -name "manifest*" -type f | grep -q .; then
    find "$ROOT_DIR/projects/site" -maxdepth 1 -name "manifest*" -type f
  else
    echo "manifest: not present"
  fi
}

cmd_inbox() {
  print_header "Inbox status"
  for source_kind in "${source_names[@]}"; do
    local human_dir
    local tech_dir
    local dropzone_dir
    human_dir="$(human_target_for "$source_kind")"
    tech_dir="$(tech_target_for "$source_kind")"
    dropzone_dir="$(source_dropzone_for "$source_kind")"
    printf "%-10s dropzone=%s documents=%s agent=%s\n" "$source_kind" "$(count_files "$dropzone_dir")" "$(count_files "$human_dir")" "$(count_files "$tech_dir")"
  done
}

cmd_watch() {
  local source_kind="${1:-manual}"
  local source_dir="${2:-}"
  ensure_source "$source_kind"
  if [[ -n "$source_dir" ]]; then
    exec "$ROOT_DIR/projects/ops-agent/scripts/watch-documents.sh" "$source_kind" "$source_dir"
  else
    exec "$ROOT_DIR/projects/ops-agent/scripts/watch-documents.sh" "$source_kind"
  fi
}

cmd_review() {
  print_header "Review"
  git -C "$ROOT_DIR" status --short --branch

  print_header "Diff stat"
  git -C "$ROOT_DIR" diff --stat || true

  print_header "Staged diff stat"
  git -C "$ROOT_DIR" diff --cached --stat || true

  print_header "Whitespace check"
  git -C "$ROOT_DIR" diff --check || true

  print_header "Potential secrets in tracked diff"
  if git -C "$ROOT_DIR" diff -- . ":(exclude)Документы Космос" | grep -Ei "^[+][^+].*(api[_-]?key|secret|token|password)[a-z0-9_-]*[[:space:]]*[:=]" >/dev/null; then
    echo "WARN possible secret-like text in diff"
  else
    echo "ok   no obvious secret-like text in unstaged diff"
  fi
}

cmd_smoke() {
  print_header "Shell syntax"
  local failed=0
  for script in "$ROOT_DIR"/projects/ops-agent/scripts/*.sh; do
    if zsh -n "$script"; then
      echo "ok   ${script#$ROOT_DIR/}"
    else
      echo "FAIL ${script#$ROOT_DIR/}"
      failed=1
    fi
  done
  return "$failed"
}

case "$COMMAND" in
  help|-h|--help)
    cmd_help
    ;;
  init)
    cmd_init
    ;;
  dashboard)
    cmd_dashboard
    ;;
  preflight)
    cmd_preflight
    ;;
  inbox)
    cmd_inbox
    ;;
  watch)
    shift
    cmd_watch "${1:-manual}" "${2:-}"
    ;;
  review)
    cmd_review
    ;;
  smoke)
    cmd_smoke
    ;;
  all)
    cmd_preflight
    cmd_inbox
    cmd_smoke
    cmd_review
    ;;
  *)
    echo "Unknown command: $COMMAND"
    cmd_help
    exit 2
    ;;
esac
