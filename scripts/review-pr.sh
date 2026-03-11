#!/bin/bash
# Usage: ./scripts/review-pr.sh <REPO_NAME> <PR_NUMBER>
#
# REPO_NAME must match a "name" in config.json.
#
# Examples:
#   ./scripts/review-pr.sh api 229
#   ./scripts/review-pr.sh frontend 42

set -euo pipefail

REPO_NAME="${1:?Usage: $0 <REPO_NAME> <PR_NUMBER>}"
PR_NUMBER="${2:?Usage: $0 <REPO_NAME> <PR_NUMBER>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.json not found at ${CONFIG_FILE}"
  exit 1
fi

# Look up repo config
REPO_CONFIG=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name)' "$CONFIG_FILE")

if [ -z "$REPO_CONFIG" ] || [ "$REPO_CONFIG" = "null" ]; then
  AVAILABLE=$(jq -r '.repos[].name' "$CONFIG_FILE" | tr '\n' ', ' | sed 's/,$//')
  echo "ERROR: Unknown repo '${REPO_NAME}'. Available: ${AVAILABLE}"
  exit 1
fi

GITHUB_REPO=$(echo "$REPO_CONFIG" | jq -r '.github')
SKILL_NAME=$(echo "$REPO_CONFIG" | jq -r '.skill')
SKILL_FILE="${ROOT_DIR}/skills/${SKILL_NAME}/skill.md"

# Language: repo-level override > global default > "en"
REVIEW_LANG=$(echo "$REPO_CONFIG" | jq -r '.language // empty')
if [ -z "$REVIEW_LANG" ]; then
  REVIEW_LANG=$(jq -r '.default_language // "en"' "$CONFIG_FILE")
fi

# Map language code to full name
case "$REVIEW_LANG" in
  tr) LANG_NAME="Turkish" ;;
  en) LANG_NAME="English" ;;
  de) LANG_NAME="German" ;;
  fr) LANG_NAME="French" ;;
  es) LANG_NAME="Spanish" ;;
  pt) LANG_NAME="Portuguese" ;;
  ja) LANG_NAME="Japanese" ;;
  ko) LANG_NAME="Korean" ;;
  zh) LANG_NAME="Chinese" ;;
  ru) LANG_NAME="Russian" ;;
  ar) LANG_NAME="Arabic" ;;
  it) LANG_NAME="Italian" ;;
  nl) LANG_NAME="Dutch" ;;
  pl) LANG_NAME="Polish" ;;
  hi) LANG_NAME="Hindi" ;;
  *)  LANG_NAME="$REVIEW_LANG" ;;
esac

if [ ! -f "$SKILL_FILE" ]; then
  echo "ERROR: Skill file not found: ${SKILL_FILE}"
  exit 1
fi

# Replace placeholders in skill
SKILL_CONTENT=$(sed -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" -e "s|{{REVIEW_LANGUAGE}}|${LANG_NAME}|g" "$SKILL_FILE")

echo "Reviewing PR #${PR_NUMBER} on ${GITHUB_REPO} (${LANG_NAME})..."

claude -p "${SKILL_CONTENT}

ARGUMENTS: ${PR_NUMBER}" \
  --allowedTools "Bash,Read,Glob,Grep,WebFetch"

echo "Review complete for PR #${PR_NUMBER} on ${GITHUB_REPO}"
