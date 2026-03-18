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

# Noise control: max_comments and min_severity
MAX_COMMENTS=$(echo "$REPO_CONFIG" | jq -r '.max_comments // empty')
[ -z "$MAX_COMMENTS" ] && MAX_COMMENTS=$(jq -r '.max_comments // 7' "$CONFIG_FILE")

MIN_SEVERITY=$(echo "$REPO_CONFIG" | jq -r '.min_severity // empty')
[ -z "$MIN_SEVERITY" ] && MIN_SEVERITY=$(jq -r '.min_severity // "P2"' "$CONFIG_FILE")

# Build exclude patterns for filtering sensitive files from diff
EXCLUDE_PATTERNS=$(jq -r '.exclude_patterns // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
REPO_EXCLUDES=$(echo "$REPO_CONFIG" | jq -r '.exclude_patterns // [] | .[]' 2>/dev/null)

# Merge global + repo-level excludes
ALL_EXCLUDES=$(printf '%s\n%s' "$EXCLUDE_PATTERNS" "$REPO_EXCLUDES" | sort -u | grep -v '^$')

# Replace placeholders in skill
SKILL_CONTENT=$(sed -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" -e "s|{{REVIEW_LANGUAGE}}|${LANG_NAME}|g" "$SKILL_FILE")

# Inject exclude list into skill so Claude knows which files to skip
if [ -n "$ALL_EXCLUDES" ]; then
  EXCLUDE_LIST=$(echo "$ALL_EXCLUDES" | sed 's/^/- /' | tr '\n' '\n')
  SKILL_CONTENT="${SKILL_CONTENT}

## Excluded Files (Privacy/Security)

The following file patterns are EXCLUDED from review. **Do NOT comment on these files**, skip them entirely when analyzing the diff:

${EXCLUDE_LIST}"
fi

# Context: inject repo structure exploration and context files
EXPLORE_STRUCTURE=$(echo "$REPO_CONFIG" | jq -r '.explore_repo_structure // empty')
CONTEXT_FILES=$(echo "$REPO_CONFIG" | jq -r '.context_files // [] | .[]' 2>/dev/null)

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

# Get source directory structure (adjust src/ to match project)
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

echo "Reviewing PR #${PR_NUMBER} on ${GITHUB_REPO} (${LANG_NAME})..."

claude -p "${SKILL_CONTENT}

ARGUMENTS: ${PR_NUMBER}" \
  --allowedTools "Bash,Read,Glob,Grep,WebFetch"

echo "Review complete for PR #${PR_NUMBER} on ${GITHUB_REPO}"
