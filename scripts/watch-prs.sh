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

  # Noise control: max_comments and min_severity (repo-level > global)
  MAX_COMMENTS=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .max_comments // empty' "$CONFIG_FILE" 2>/dev/null)
  [ -z "$MAX_COMMENTS" ] && MAX_COMMENTS=$(jq -r '.max_comments // 7' "$CONFIG_FILE")

  MIN_SEVERITY=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .min_severity // empty' "$CONFIG_FILE" 2>/dev/null)
  [ -z "$MIN_SEVERITY" ] && MIN_SEVERITY=$(jq -r '.min_severity // "P2"' "$CONFIG_FILE")

  # Replace placeholders in skill content
  SKILL_CONTENT=$(sed -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" -e "s|{{REVIEW_LANGUAGE}}|${LANG_NAME}|g" "$SKILL_FILE")

  # Build exclude patterns for filtering sensitive files
  EXCLUDE_PATTERNS=$(jq -r '.exclude_patterns // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
  REPO_EXCLUDES=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .exclude_patterns // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
  ALL_EXCLUDES=$(printf '%s\n%s' "$EXCLUDE_PATTERNS" "$REPO_EXCLUDES" | sort -u | grep -v '^$')

  # Inject exclude list into skill so Claude knows which files to skip
  if [ -n "$ALL_EXCLUDES" ]; then
    EXCLUDE_LIST=$(echo "$ALL_EXCLUDES" | sed 's/^/- /')
    SKILL_CONTENT="${SKILL_CONTENT}

## Excluded Files (Privacy/Security)

The following file patterns are EXCLUDED from review. **Do NOT comment on these files**, skip them entirely when analyzing the diff:

${EXCLUDE_LIST}"
  fi

  # Context: inject repo structure exploration and context files
  EXPLORE_STRUCTURE=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .explore_repo_structure // empty' "$CONFIG_FILE" 2>/dev/null)
  CONTEXT_FILES=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .context_files // [] | .[]' "$CONFIG_FILE" 2>/dev/null)

  if [ "$EXPLORE_STRUCTURE" = "true" ] || [ -n "$CONTEXT_FILES" ]; then
    CONTEXT_SECTION="

## Repository Context

Before reviewing the diff, gather context about the project to avoid suggesting code that already exists or patterns that contradict the project conventions."

    if [ "$EXPLORE_STRUCTURE" = "true" ]; then
      CONTEXT_SECTION="${CONTEXT_SECTION}

### Step 0: Explore Repository Structure

Before analyzing the diff, run these commands to understand the project layout:

\`\`\`bash
# Get top-level structure
gh api repos/${GITHUB_REPO}/git/trees/HEAD --jq '.tree[] | .path' | head -30

# Get source directory structure
gh api repos/${GITHUB_REPO}/contents/src --jq '.[].path' 2>/dev/null || true
\`\`\`

Use this context to:
- Identify existing utility functions before suggesting new ones
- Understand the project's module organization
- Spot when a PR re-implements something that already exists
- Check if new code follows existing naming conventions"
    fi

    if [ -n "$CONTEXT_FILES" ]; then
      CONTEXT_SECTION="${CONTEXT_SECTION}

### Context Files

Before reviewing, read these files to understand project conventions and available utilities:

\`\`\`bash"
      while IFS= read -r ctx_file; do
        CONTEXT_SECTION="${CONTEXT_SECTION}
gh api repos/${GITHUB_REPO}/contents/${ctx_file} --jq '.content' | base64 -d"
      done <<< "$CONTEXT_FILES"
      CONTEXT_SECTION="${CONTEXT_SECTION}
\`\`\`

Use this context to catch:
- Duplicate implementations of existing utilities
- Deviations from established patterns
- Missed opportunities to reuse existing code"
    fi

    SKILL_CONTENT="${SKILL_CONTENT}
${CONTEXT_SECTION}"
  fi

  # Inject noise control rules into skill
  SKILL_CONTENT="${SKILL_CONTENT}

## Noise Control

- **Maximum ${MAX_COMMENTS} comments per review.** Prioritize by severity. If there are more findings, mention the omitted count in the review body summary.
- **Minimum severity: ${MIN_SEVERITY}.** Do NOT post comments below this severity level. Only mention omitted lower-severity count in the review body summary (e.g., \"Also found 3 P3 issues, omitted per noise policy\").
- **Group similar findings.** If the same issue pattern appears in multiple files, post ONE comment on the most impactful occurrence and note \"Same pattern also found in: file2.py:45, file3.py:78\" instead of separate comments for each."

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
