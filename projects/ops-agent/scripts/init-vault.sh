#!/usr/bin/env zsh
set -euo pipefail
setopt typeset_silent

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/data/templates"
LIVE_DIR="$ROOT_DIR/data/live"
DOCS_DIR="$ROOT_DIR/Документы Космос"

print_header() {
  echo
  echo "== $1 =="
}

ensure_private_dirs() {
  local dirs=(
    "$ROOT_DIR/_inbox/fns"
    "$ROOT_DIR/_inbox/bank"
    "$ROOT_DIR/_inbox/suppliers"
    "$ROOT_DIR/_inbox/livesklad"
    "$ROOT_DIR/_inbox/manual"
    "$ROOT_DIR/_archive/documents"
    "$ROOT_DIR/_archive/processed"
    "$LIVE_DIR"
    "$ROOT_DIR/Загрузки Космос/ФНС"
    "$ROOT_DIR/Загрузки Космос/Банк"
    "$ROOT_DIR/Загрузки Космос/Поставщики"
    "$ROOT_DIR/Загрузки Космос/LiveSklad"
    "$ROOT_DIR/Загрузки Космос/Вручную"
    "$DOCS_DIR/00_Входящие/ФНС"
    "$DOCS_DIR/00_Входящие/Банк"
    "$DOCS_DIR/00_Входящие/Поставщики"
    "$DOCS_DIR/00_Входящие/LiveSklad"
    "$DOCS_DIR/00_Входящие/Вручную"
    "$DOCS_DIR/01_ФНС/ЕГРИП"
    "$DOCS_DIR/01_ФНС/ЕНС"
    "$DOCS_DIR/01_ФНС/Патент_ПСН"
    "$DOCS_DIR/01_ФНС/УСН"
    "$DOCS_DIR/01_ФНС/Страховые_взносы"
    "$DOCS_DIR/02_Банк/Выписки"
    "$DOCS_DIR/02_Банк/Платежки"
    "$DOCS_DIR/03_Бухгалтерия/Вопросы"
    "$DOCS_DIR/04_Поставщики/Счета"
    "$DOCS_DIR/05_Аренда"
    "$DOCS_DIR/06_ККТ_ОФД"
    "$DOCS_DIR/07_LiveSklad/Выгрузки"
    "$DOCS_DIR/09_Оплата_счетов/Новые_к_оплате"
    "$DOCS_DIR/09_Оплата_счетов/Оплачено"
    "$DOCS_DIR/11_Владелец_ИП/01_Паспорт"
    "$DOCS_DIR/11_Владелец_ИП/02_ИП_регистрация"
    "$DOCS_DIR/11_Владелец_ИП/03_Налоговые_режимы"
    "$DOCS_DIR/11_Владелец_ИП/04_Банк_и_реквизиты"
    "$DOCS_DIR/11_Владелец_ИП/05_Контакты_и_доступы_описание"
    "$DOCS_DIR/11_Владелец_ИП/06_Шаблоны_данных"
    "$DOCS_DIR/99_Разобрать"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    echo "ok   ${dir#$ROOT_DIR/}"
  done
}

copy_live_templates() {
  local copied=0
  local skipped=0

  if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "MISS data/templates"
    return 1
  fi

  mkdir -p "$LIVE_DIR"

  for template in "$TEMPLATE_DIR"/*.csv; do
    [[ -e "$template" ]] || continue

    local name
    local target
    name="$(basename "$template")"
    target="$LIVE_DIR/$name"

    if [[ -e "$target" ]]; then
      echo "skip $name"
      (( skipped += 1 ))
    else
      cp -p "$template" "$target"
      echo "copy $name"
      (( copied += 1 ))
    fi
  done

  echo
  echo "copied=$copied skipped=$skipped"
}

print_next_steps() {
  print_header "Next"
  echo "1. Fill local cards in Документы Космос/11_Владелец_ИП/06_Шаблоны_данных/"
  echo "2. Put new downloaded files into Загрузки Космос/<source>/."
  echo "3. Run: projects/ops-agent/scripts/kosmos-auto.sh watch fns"
}

print_header "Init vault"
echo "Root: $ROOT_DIR"
echo "Mode: safe local init, no overwrite"

print_header "Private directories"
ensure_private_dirs

print_header "Live registers"
copy_live_templates

print_next_steps
