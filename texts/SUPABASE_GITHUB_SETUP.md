# Supabase и GitHub — подключение Космос Сервиса

Цель: подключить отдельный cloud-контур для будущей CRM, личного агента, синхронизации и серверных интеграций без утечки личных документов, ключей и реальных баз.

## Что уже подготовлено в репозитории

- `supabase/migrations/20260605_000001_kosmos_cloud_core.sql` — таблицы, индексы, триггеры `updated_at`, RLS и policies через `auth.uid()`.
- `supabase/migrations/20260606_kosmos_realtime.sql` — optional Realtime для первых синхронизируемых таблиц.
- `supabase/functions/agent/index.ts` — Edge Function с проверкой Supabase Auth, CORS, AI-запросом и GitHub-записью только в разрешённые пути.
- `.env.example` — только placeholders, без реальных секретов.
- `deploy.sh` — безопасный deploy helper: не делает `git add -A`, требует явный список файлов.

## Supabase project

1. Создать новый Supabase project именно для Космос Сервиса.
2. Не использовать project ref, URL, anon key и secrets из `Разберёмся`.
3. В SQL Editor или через Supabase CLI применить миграции по порядку:

```sh
supabase db push
```

Если Supabase CLI ещё не связан с проектом:

```sh
supabase login
supabase link --project-ref <KOSMOS_PROJECT_REF>
supabase db push
```

## Auth

В Supabase Dashboard:

- Authentication -> Providers -> Email: включить email OTP.
- Authentication -> URL Configuration:
  - пока локально: `http://127.0.0.1:5050`
  - позже добавить production URL.
- Redirect URLs:
  - `http://127.0.0.1:5050`
  - `http://localhost:5050`
  - будущий production URL.

## Edge Function secrets

Добавить в Supabase Edge Function secrets, не в frontend:

```sh
supabase secrets set SUPABASE_URL="https://<KOSMOS_PROJECT_REF>.supabase.co"
supabase secrets set SUPABASE_ANON_KEY="<KOSMOS_PUBLIC_ANON_KEY>"
supabase secrets set ANTHROPIC_API_KEY="<ANTHROPIC_KEY>"
supabase secrets set ANTHROPIC_MODEL="claude-sonnet-4-5"
supabase secrets set GITHUB_REPO="<owner>/<kosmos-repo>"
supabase secrets set GITHUB_TOKEN="<github_token_with_repo_contents_write>"
supabase secrets set KOSMOS_ALLOWED_ORIGINS="http://127.0.0.1:5050,http://localhost:5050"
```

`service_role` нельзя вставлять в клиентский код. Если он понадобится для серверной задачи, хранить только в Supabase secrets или secrets платформы деплоя.

Деплой функции:

```sh
supabase functions deploy agent
```

## GitHub

Локально подключить отдельный repo:

```sh
git remote add origin <NEW_KOSMOS_REPO_URL>
git push -u origin main
```

В GitHub не должны попадать:

- `.env` и реальные ключи;
- `data/live/`;
- `Документы Космос/`;
- `Загрузки Космос/`;
- реальные документы, базы, подписи, архивы и персональные данные.

## Разрешённые GitHub-записи агента

Edge Function `agent` может писать только в:

- `texts/agent-notes/`
- `texts/backlog/`
- `texts/prompts/`
- `data/templates/`

Она блокирует:

- `.env`;
- `_inbox/`;
- `_archive/`;
- `data/live/`;
- `private/`;
- `secrets/`;
- `Документы Космос/`;
- `Загрузки Космос/`.

## Что проверить после подключения

- В Supabase Table Editor все пользовательские таблицы с RLS enabled.
- Policies используют `auth.uid() = user_id`.
- Email OTP реально присылает код.
- `supabase functions deploy agent` прошёл без ошибок.
- В GitHub нет `.env`, документов, `data/live` и архивов.
- `git remote -v` показывает отдельный repo Космос Сервиса.
- Первый push уходит в нужный repo, не в `razberemsia` и не в сайт отдельного проекта.
