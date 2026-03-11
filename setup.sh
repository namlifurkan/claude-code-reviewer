#!/bin/bash
# One-time setup script for Claude Code PR Reviewer
# Works on macOS, Linux, and Windows (Git Bash / WSL)
# Run: ./setup.sh

set -euo pipefail

OS="unknown"
case "$(uname -s)" in
  Darwin*)  OS="macos" ;;
  Linux*)   OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${ROOT_DIR}/config.json"

echo "=== Claude Code PR Reviewer Setup ==="
echo "Detected OS: ${OS}"
echo ""

# 1. Check prerequisites
echo "[1/5] Checking prerequisites..."

if ! command -v node &>/dev/null; then
  echo "  ERROR: Node.js not found."
  case "$OS" in
    macos)   echo "  Install: brew install node" ;;
    linux)   echo "  Install: sudo apt install nodejs npm" ;;
    windows) echo "  Install: https://nodejs.org" ;;
  esac
  exit 1
fi
echo "  Node.js: OK ($(node --version))"

if ! command -v claude &>/dev/null; then
  echo "  ERROR: Claude Code CLI not found."
  echo "  Install: npm install -g @anthropic-ai/claude-code"
  exit 1
fi
echo "  Claude Code CLI: OK"

if ! command -v gh &>/dev/null; then
  echo "  ERROR: GitHub CLI (gh) not found."
  case "$OS" in
    macos)   echo "  Install: brew install gh" ;;
    linux)   echo "  Install: https://github.com/cli/cli/blob/trunk/docs/install_linux.md" ;;
    windows) echo "  Install: winget install GitHub.cli" ;;
  esac
  exit 1
fi
echo "  GitHub CLI: OK ($(gh --version | head -1))"

if ! command -v jq &>/dev/null; then
  echo "  ERROR: jq not found."
  case "$OS" in
    macos)   echo "  Install: brew install jq" ;;
    linux)   echo "  Install: sudo apt install jq" ;;
    windows) echo "  Install: winget install jqlang.jq" ;;
  esac
  exit 1
fi
echo "  jq: OK"

# 2. Check gh auth
echo ""
echo "[2/5] Checking GitHub authentication..."
if ! gh auth status &>/dev/null; then
  echo "  ERROR: Not authenticated. Run: gh auth login"
  exit 1
fi
echo "  GitHub auth: OK"

# 3. Check config
echo ""
echo "[3/5] Checking configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
  echo "  ERROR: config.json not found. Copy config.json.example to config.json and edit it."
  exit 1
fi

REPO_COUNT=$(jq '.repos | length' "$CONFIG_FILE")
echo "  config.json: OK (${REPO_COUNT} repo(s) configured)"

# 4. Check repo access
echo ""
echo "[4/5] Checking repo access..."

for i in $(seq 0 $(( REPO_COUNT - 1 ))); do
  REPO=$(jq -r ".repos[$i].github" "$CONFIG_FILE")
  SKILL=$(jq -r ".repos[$i].skill" "$CONFIG_FILE")
  SKILL_FILE="${ROOT_DIR}/skills/${SKILL}/skill.md"

  if ! gh repo view "$REPO" --json name &>/dev/null; then
    echo "  WARNING: Cannot access ${REPO}. Check your GitHub permissions."
  else
    echo "  ${REPO}: OK"
  fi

  if [ ! -f "$SKILL_FILE" ]; then
    echo "  WARNING: Skill file missing for ${REPO}: skills/${SKILL}/skill.md"
  fi
done

# 5. Setup
echo ""
echo "[5/5] Setting up..."
chmod +x scripts/*.sh 2>/dev/null || true
mkdir -p .state
echo "  Scripts: OK"
echo "  State directory: OK"

WATCH_PATH="${ROOT_DIR}/scripts/watch-prs.sh"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Quick start:"

FIRST_REPO=$(jq -r '.repos[0].name' "$CONFIG_FILE")
echo "  ./scripts/review-pr.sh ${FIRST_REPO} <PR_NUMBER>"
echo ""

echo "Auto-review setup:"
case "$OS" in
  macos|linux)
    echo "  crontab -e"
    echo "  */10 * * * * ${WATCH_PATH}"
    ;;
  windows)
    echo "  # WSL:"
    echo "  crontab -e"
    echo "  */10 * * * * ${WATCH_PATH}"
    echo ""
    echo "  # Git Bash / PowerShell:"
    echo "  schtasks /create /tn \"ClaudeCodeReviewer\" /tr \"bash ${WATCH_PATH}\" /sc minute /mo 10"
    ;;
esac

echo ""
echo "Logs:  .state/review.log"
echo "State: .state/<repo-name>.json"
