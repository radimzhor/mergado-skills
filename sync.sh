#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Sync each mergado skill from ~/.claude/skills to the repo
for skill in "$SKILLS_DIR"/mergado-*/; do
  name=$(basename "$skill")
  echo "Syncing $name..."
  rsync -a --delete "$skill" "$REPO_DIR/$name/"
done

cd "$REPO_DIR"

if git diff --quiet && git diff --cached --quiet; then
  echo "Nothing changed."
  exit 0
fi

git add .
git commit -m "Sync Mergado skills from ~/.claude/skills"
git push
echo "Done."
