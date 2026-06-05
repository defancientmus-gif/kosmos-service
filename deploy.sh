#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

usage() {
  print "Usage: ./deploy.sh \"commit message\" <file-or-dir> [more files...]"
  print ""
  print "Example:"
  print "  ./deploy.sh \"Add Supabase scaffold\" .gitignore .env.example supabase supabase.sql texts/SUPABASE_GITHUB_SETUP.md deploy.sh"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 64
fi

COMMIT_MESSAGE="$1"
shift

print "== status before =="
git status --short --branch

print "== safety checks =="
zsh -n "$0"

if [[ -d projects/ops-agent/scripts ]]; then
  for script in projects/ops-agent/scripts/*.sh(N); do
    zsh -n "$script"
  done
fi

if [[ -x projects/ops-agent/scripts/kosmos-auto.sh ]]; then
  projects/ops-agent/scripts/kosmos-auto.sh smoke
fi

if [[ -f projects/site/sw.js ]]; then
  print "PWA service worker exists. Bump cache/version manually with the frontend change."
else
  print "No PWA service worker found; cache bump skipped."
fi

for path in "$@"; do
  case "$path" in
    .env.example)
      ;;
    .env|.env.*|data/live|data/live/*|Документы\ Космос|Документы\ Космос/*|Загрузки\ Космос|Загрузки\ Космос/*|_inbox|_inbox/*|_archive|_archive/*|private|private/*|secrets|secrets/*)
      print "Refusing to stage private path: $path" >&2
      exit 65
      ;;
  esac
done

git add -- "$@"
git diff --cached --check

print "== staged files =="
git diff --cached --name-only

if git diff --cached --quiet; then
  print "Nothing staged."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"

if git remote get-url origin >/dev/null 2>&1; then
  git push origin HEAD
else
  print "No origin remote configured. Commit is local; add remote and push when ready."
fi
