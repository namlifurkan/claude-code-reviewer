---
description: "Review GitHub PRs with inline line-based comments categorized by severity (Major/Minor/Trivial)"
---

# PR Review

You are tasked with reviewing a GitHub Pull Request on the **{{GITHUB_REPO}}** repository and leaving **inline line-based comments** directly on the diff.

## Input

User will provide a PR number. Extract the PR number from it.

## Process

### 1. Gather PR Information

```bash
# Get PR metadata
gh pr view <PR_NUMBER> --repo {{GITHUB_REPO}} --json title,body,state,author,baseRefName,headRefName,files,additions,deletions

# Get the full diff
gh pr diff <PR_NUMBER> --repo {{GITHUB_REPO}}

# Get latest commit SHA (needed for inline comments)
gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER> --jq '.head.sha'
```

### 2. Analyze the Diff

Review ALL changed files carefully. Focus on finding:
- **Bugs and logic errors**
- **Missing edge cases or null checks**
- **Behavioral changes that may break existing functionality**
- **Type mismatches or incorrect casts**
- **Deleted tests without replacement coverage**
- **Security concerns** (SQL injection, XSS, command injection, OWASP top 10)
- **Race conditions and concurrency issues**

### 3. Categorize Findings by Severity

- **Major**: Bugs, data loss risk, behavioral changes that break things, missing validations at boundaries, security vulnerabilities
- **Minor**: Design concerns, missing coverage, questionable decisions that won't break but should be discussed
- **Trivial**: Inconsistencies, style issues, small questions about intent

### 4. Submit Review with Inline Comments

Use the GitHub API to create a review with inline comments. Each comment MUST include the severity prefix: `**[Major]**`, `**[Minor]**`, or `**[Trivial]**`.

```bash
cat <<'JSONEOF' | gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews --method POST --input -
{
  "commit_id": "<COMMIT_SHA>",
  "event": "COMMENT",
  "body": "<Summary of findings: X major, Y minor, Z trivial>",
  "comments": [
    {
      "path": "path/to/file",
      "line": <LINE_NUMBER_IN_NEW_FILE>,
      "body": "**[Major]** Description of the issue."
    }
  ]
}
JSONEOF
```

## Rules

1. **ONLY leave comments for issues/bugs/concerns.** Do NOT leave positive or praise comments ("good refactor", "nice job", etc.). No noise.
2. **Every comment MUST have a severity prefix**: `**[Major]**`, `**[Minor]**`, or `**[Trivial]**`.
3. **Comments must be on diff lines only.** The `line` field refers to the line number in the NEW version of the file as shown in the diff.
4. **Be concise and actionable.** State the problem and, if possible, suggest a fix.
5. **Do NOT comment on deleted files** — GitHub API does not support inline comments on deleted files.

## Project Context

<!-- CUSTOMIZE THIS SECTION FOR YOUR PROJECT -->

- Add your project-specific context here
- Framework, language, patterns used
- Architecture decisions reviewers should know about
- Common pitfalls specific to your codebase

## Output

After submitting, summarize findings to the user:
- List count per severity (e.g., "2 Major, 3 Minor, 1 Trivial")
- Brief one-liner per comment so the user knows what was flagged
