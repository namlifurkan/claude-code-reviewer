---
description: "Review Python PRs with inline line-based comments categorized by severity"
---

# Python PR Review

You are tasked with reviewing a GitHub Pull Request on the **{{GITHUB_REPO}}** repository and leaving **inline line-based comments** directly on the diff.

## Input

User will provide a PR number.

## Process

### 1. Gather PR Information

```bash
gh pr view <PR_NUMBER> --repo {{GITHUB_REPO}} --json title,body,state,author,baseRefName,headRefName,files,additions,deletions
gh pr diff <PR_NUMBER> --repo {{GITHUB_REPO}}
gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER> --jq '.head.sha'
```

### 2. Analyze the Diff

Review ALL changed files carefully. Focus on:
- **Bugs and logic errors**
- **Missing type hints** (function signatures, return types)
- **Exception handling** (bare except, swallowed exceptions, missing error context)
- **Security concerns** (SQL injection, command injection, path traversal, pickle deserialization)
- **Resource management** (missing context managers for files/connections)
- **Concurrency issues** (race conditions, shared mutable state)
- **Missing input validation** at API boundaries

### 3. Categorize Findings by Severity

- **Major**: Bugs, security vulnerabilities, data loss risk, broken functionality, resource leaks
- **Minor**: Missing type hints, design concerns, missing test coverage, code smell
- **Trivial**: Style issues, naming conventions, import ordering

### 4. Submit Review with Inline Comments

```bash
cat <<'JSONEOF' | gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews --method POST --input -
{
  "commit_id": "<COMMIT_SHA>",
  "event": "COMMENT",
  "body": "<Summary of findings: X major, Y minor, Z trivial>",
  "comments": [
    {
      "path": "path/to/file.py",
      "line": <LINE_NUMBER_IN_NEW_FILE>,
      "body": "**[Major]** Description of the issue."
    }
  ]
}
JSONEOF
```

## Rules

1. **ONLY leave comments for issues/bugs/concerns.** No positive or praise comments.
2. **Every comment MUST have a severity prefix**: `**[Major]**`, `**[Minor]**`, or `**[Trivial]**`.
3. **Comments must be on diff lines only.**
4. **Be concise and actionable.** State the problem and suggest a fix.
5. **Write all review comments in {{REVIEW_LANGUAGE}}.**
6. **Do NOT comment on deleted files.**

## Python-Specific Checks

- Use `with` statements for file/connection handling (no manual `.close()`)
- Avoid bare `except:` — always catch specific exceptions
- Check for mutable default arguments (`def foo(items=[])`)
- Verify `__init__` doesn't do heavy I/O
- Check for proper `async`/`await` usage (missing await, sync calls in async context)
- SQL queries should use parameterized queries, not f-strings
- Check for path traversal in file operations (`os.path.join` with user input)
- Verify proper use of `Optional` types and None checks
- Migration files (Django/Alembic) should have reversible operations

## Output

After submitting, summarize findings:
- Count per severity (e.g., "2 Major, 3 Minor, 1 Trivial")
- Brief one-liner per comment
