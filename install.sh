#!/bin/bash
# Install Claude Skills to ~/.claude/skills/
# Usage: ./install.sh [skill-name | all]

set -e

SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"
AVAILABLE=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | xargs -I{} basename {})

usage() {
  echo "Usage: $0 [skill-name | all]"
  echo ""
  echo "Available skills:"
  for s in $AVAILABLE; do echo "  - $s"; done
  echo ""
  echo "Examples:"
  echo "  ./install.sh all          # install all skills"
  echo "  ./install.sh ios-pro      # install one skill"
}

install_skill() {
  local name="$1"
  local src="$SKILLS_DIR/$name"
  local dst="$TARGET_DIR/$name"

  if [ ! -d "$src" ]; then
    echo "❌ Skill '$name' not found."
    exit 1
  fi

  mkdir -p "$dst"
  cp -r "$src/." "$dst/"
  echo "✅ Installed: $name → $dst"
}

# Default: show usage if no args
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

mkdir -p "$TARGET_DIR"

if [ "$1" = "all" ]; then
  for skill in $AVAILABLE; do
    install_skill "$skill"
  done
  echo ""
  echo "✅ All skills installed to $TARGET_DIR"
else
  install_skill "$1"
fi
