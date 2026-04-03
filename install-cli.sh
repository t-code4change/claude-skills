#!/usr/bin/env bash
# ============================================================================
# install-cli.sh — Install init-claude CLI to your machine
# Usage: curl -fsSL https://raw.githubusercontent.com/t-code4change/claude-skills/main/install-cli.sh | bash
# ============================================================================
set -euo pipefail

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RESET='\033[0m'
info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }

REPO="https://raw.githubusercontent.com/t-code4change/claude-skills/main"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="init-claude"

# Create install dir if needed
mkdir -p "$INSTALL_DIR"

# Download init-claude
info "Downloading $SCRIPT_NAME..."
curl -fsSL "$REPO/bin/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
ok "Installed to $INSTALL_DIR/$SCRIPT_NAME"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    SHELL_RC=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [[ -n "$SHELL_RC" ]]; then
        echo "" >> "$SHELL_RC"
        echo "# init-claude CLI" >> "$SHELL_RC"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
        ok "Added $INSTALL_DIR to PATH in $SHELL_RC"
        warn "Run: source $SHELL_RC (or open a new terminal)"
    else
        warn "Add $INSTALL_DIR to your PATH manually"
    fi
fi

echo ""
echo -e "${GREEN}✅ init-claude installed!${RESET}"
echo ""
echo "Usage:"
echo "  init-claude              # scaffold .claude/ in current project"
echo "  init-claude my-project   # scaffold with custom name"
echo ""
echo "To update later:"
echo "  curl -fsSL https://raw.githubusercontent.com/t-code4change/claude-skills/main/install-cli.sh | bash"
