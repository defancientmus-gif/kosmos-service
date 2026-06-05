# Supabase — Космос Сервис

Этот каталог готовит отдельный Supabase-проект для личного агента, CRM и будущей синхронизации данных.

## Что здесь есть

- `migrations/20260605_000001_kosmos_cloud_core.sql` — базовая схема CRM/документов/финансов/действий агента, RLS и policies через `auth.uid()`.
- `migrations/20260605_000002_kosmos_realtime.sql` — optional Realtime для первых таблиц синхронизации.
- `functions/agent/index.ts` — Edge Function для защищённых AI/GitHub-действий через Supabase Auth.

## Ручной порядок запуска

1. Создать отдельный Supabase project для Космос Сервиса.
2. Применить миграции по порядку.
3. Включить email OTP в Auth.
4. Задать Edge Function secrets.
5. Деплоить функцию `agent`.

Подробный чеклист: `texts/SUPABASE_GITHUB_SETUP.md`.
