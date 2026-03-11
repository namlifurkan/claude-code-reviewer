#!/bin/bash
# Watches for new/updated PRs across all configured repos and auto-reviews them.
# Tracks reviewed PRs by commit SHA to avoid duplicate reviews.
# Designed to run via cron.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config.json"
STATE_DIR="${ROOT_DIR}/.state"
LOG_FILE="${STATE_DIR}/review.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Map language code to full name
resolve_language() {
  local code="$1"
  case "$code" in
    tr) echo "Turkish" ;;
    en) echo "English" ;;
    de) echo "German" ;;
    fr) echo "French" ;;
    es) echo "Spanish" ;;
    pt) echo "Portuguese" ;;
    ja) echo "Japanese" ;;
    ko) echo "Korean" ;;
    zh) echo "Chinese" ;;
    ru) echo "Russian" ;;
    ar) echo "Arabic" ;;
    it) echo "Italian" ;;
    nl) echo "Dutch" ;;
    pl) echo "Polish" ;;
    hi) echo "Hindi" ;;
    *)  echo "$code" ;;
  esac
}

mkdir -p "$STATE_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  log "ERROR: config.json not found"
  exit 1
fi

DEFAULT_LANG=$(jq -r '.default_language // "en"' "$CONFIG_FILE")
REPO_COUNT=$(jq '.repos | length' "$CONFIG_FILE")

for i in $(seq 0 $(( REPO_COUNT - 1 ))); do
  REPO_NAME=$(jq -r ".repos[$i].name" "$CONFIG_FILE")
  GITHUB_REPO=$(jq -r ".repos[$i].github" "$CONFIG_FILE")
  SKILL_NAME=$(jq -r ".repos[$i].skill" "$CONFIG_FILE")
  SKILL_FILE="${ROOT_DIR}/skills/${SKILL_NAME}/skill.md"
  STATE_FILE="${STATE_DIR}/${REPO_NAME}.json"

  # Language: repo-level > global default
  REPO_LANG=$(jq -r ".repos[$i].language // empty" "$CONFIG_FILE")
  LANG_CODE="${REPO_LANG:-$DEFAULT_LANG}"
  LANG_NAME=$(resolve_language "$LANG_CODE")

  # Read base branches
  BASE_BRANCHES=$(jq -r ".repos[$i].base_branches[]" "$CONFIG_FILE" 2>/dev/null || echo "main")

  [ -f "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"

  if [ ! -f "$SKILL_FILE" ]; then
    log "[${GITHUB_REPO}] WARN: Skill file not found: ${SKILL_FILE}"
    continue
  fi

  # Build gh pr list args for base branches
  BASE_ARGS=""
  for branch in $BASE_BRANCHES; do
    BASE_ARGS="${BASE_ARGS} --base ${branch}"
  done

  # Get open PRs, not draft
  prs=$(gh pr list --repo "$GITHUB_REPO" \
    $BASE_ARGS \
    --state open \
    --json number,headRefOid,isDraft,headRefName \
    --jq '.[] | select(.isDraft == false) | "\(.number) \(.headRefOid) \(.headRefName)"' 2>/dev/null || true)

  if [ -z "$prs" ]; then
    log "[${GITHUB_REPO}] No open PRs found."
    continue
  fi

  # Replace placeholders in skill content
  SKILL_CONTENT=$(sed -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" -e "s|{{REVIEW_LANGUAGE}}|${LANG_NAME}|g" "$SKILL_FILE")

  while IFS=' ' read -r pr_number commit_sha branch_name; do
    reviewed_sha=$(jq -r --arg pr "$pr_number" '.[$pr] // ""' "$STATE_FILE")

    if [ "$reviewed_sha" = "$commit_sha" ]; then
      continue
    fi

    log "[${GITHUB_REPO}] New/updated PR #${pr_number} (${branch_name}) - reviewing in ${LANG_NAME}..."

    if claude -p "${SKILL_CONTENT}

ARGUMENTS: ${pr_number}" \
      --allowedTools "Bash,Read,Glob,Grep,WebFetch" >> "$LOG_FILE" 2>&1; then
      jq --arg pr "$pr_number" --arg sha "$commit_sha" \
        '. + {($pr): $sha}' "$STATE_FILE" > "${STATE_FILE}.tmp" \
        && mv "${STATE_FILE}.tmp" "$STATE_FILE"
      log "[${GITHUB_REPO}] PR #${pr_number} review complete."
    else
      log "[${GITHUB_REPO}] PR #${pr_number} review failed."
    fi

  done <<< "$prs"
done
