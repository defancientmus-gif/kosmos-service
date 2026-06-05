# Ops Agent — локальный агент рутины

## Цель

Создать локального агента, который снимает с владельца рутину выгрузки и первичной обработки документов.

Первый модуль — ФНС.

## Принцип

Стартовый режим: `download-only`.

Агент может:

- открыть нужный сервис;
- дождаться входа владельца;
- пройти по заранее разрешённым разделам;
- скачать документы;
- сложить файлы в `_inbox/`;
- записать лог действий.

Агент не может без отдельного подтверждения:

- вводить пароли, SMS-коды и PIN КЭП;
- подписывать КЭП;
- отправлять заявления;
- создавать платежи;
- менять настройки сервиса;
- отправлять документы третьим лицам.

## Будущие модули

- `fns` — ЛК ФНС: ЕГРИП, ЕНС, патент, УСН, взносы, обращения, ККТ.
- `bank` — банк: выписки, платёжки, комиссии, входящие/исходящие операции.
- `livesklad` — LiveSklad: заказы, товары, склад, клиенты, статусы.
- `suppliers` — поставщики: заказы, счета, накладные, статусы доставки.
- `registry` — разбор входящих файлов и создание строк в реестрах.

## MVP

1. Владелец запускает агента.
2. Агент открывает сервис ФНС.
3. Владелец входит сам.
4. Агент скачивает разрешённые документы.
5. Агент складывает файлы в `_inbox/fns/`.
6. Агент создаёт отчёт: что скачано, что не найдено, что требует ручного действия.

## Текущие helper-скрипты

- `scripts/kosmos-auto.sh` — безопасный командный центр: preflight, статус входящих, запуск приёмщика, smoke-проверка скриптов, git-review перед commit.
- `scripts/init-vault.sh` — подготовка локального сейфа: создаёт приватные папки и копирует недостающие шаблоны в `data/live/`, не перезаписывая заполненные файлы.
- `scripts/watch-downloads.sh` — старый совместимый приёмщик ФНС: по умолчанию смотрит `Загрузки Космос/ФНС`, не системную `~/Downloads`.
- `scripts/watch-documents.sh` — приёмщик документов: копирует новые файлы из локальной папки `Загрузки Космос/<источник>/` сразу в человеческую папку `Документы Космос/00_Входящие/...` и в техническую папку `_inbox/...`.
- `dashboard/index.html` — локальная минималистичная доска-планер по документам, статусам и папкам.
- `scripts/backup-live.sh` — локальный snapshot `data/live` в `_archive/backups/`.
- `scripts/restore-live.sh` — восстановление `data/live` из backup с защитным snapshot перед заменой.

Главная команда:

```sh
projects/ops-agent/scripts/kosmos-auto.sh all
```

Основные режимы:

```sh
projects/ops-agent/scripts/kosmos-auto.sh init
projects/ops-agent/scripts/kosmos-auto.sh dashboard
projects/ops-agent/scripts/kosmos-auto.sh preflight
projects/ops-agent/scripts/kosmos-auto.sh inbox
projects/ops-agent/scripts/kosmos-auto.sh watch fns
projects/ops-agent/scripts/kosmos-auto.sh watch bank
projects/ops-agent/scripts/kosmos-auto.sh review
projects/ops-agent/scripts/kosmos-auto.sh smoke
projects/ops-agent/scripts/backup-live.sh manual
```

Старый совместимый запуск:

```sh
projects/ops-agent/scripts/watch-downloads.sh
```

Можно передать свои папки:

```sh
projects/ops-agent/scripts/watch-downloads.sh "Загрузки Космос/ФНС" ../../_inbox/fns
```

Новый рекомендуемый запуск:

```sh
projects/ops-agent/scripts/kosmos-auto.sh init
projects/ops-agent/scripts/watch-documents.sh fns
projects/ops-agent/scripts/watch-documents.sh bank
projects/ops-agent/scripts/watch-documents.sh suppliers
projects/ops-agent/scripts/watch-documents.sh livesklad
projects/ops-agent/scripts/watch-documents.sh manual
```

Первый аргумент выбирает источник. По умолчанию используется `manual`.
Если нужно разово смотреть другую папку, можно передать её вторым аргументом. По умолчанию системная `~/Downloads` больше не используется, чтобы агент не подтягивал лишние личные загрузки.

## Конфиги

- `config.example.json` — пример безопасной настройки.
- реальные локальные настройки хранить как `config/*.local.json`; они игнорируются git.
