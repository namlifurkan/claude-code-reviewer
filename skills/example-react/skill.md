---
description: "Review React/TypeScript PRs with inline line-based comments categorized by severity"
---

# React PR Review

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
- **React anti-patterns** (missing deps in useEffect, stale closures, unnecessary re-renders)
- **TypeScript type safety** (any casts, missing types, incorrect generics)
- **Missing error boundaries and error handling**
- **Accessibility issues** (missing ARIA labels, keyboard navigation)
- **Security concerns** (XSS via dangerouslySetInnerHTML, unsanitized user input)
- **Memory leaks** (missing cleanup in useEffect, unsubscribed listeners)
- **Performance issues** (missing memoization, large bundle imports)

### 3. Categorize Findings by Severity

- **Major**: Bugs, security vulnerabilities, memory leaks, broken functionality, data loss risk
- **Minor**: Performance concerns, missing types, accessibility issues, design pattern violations
- **Trivial**: Style inconsistencies, naming conventions, import ordering

### 4. Submit Review with Inline Comments

```bash
cat <<'JSONEOF' | gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews --method POST --input -
{
  "commit_id": "<COMMIT_SHA>",
  "event": "COMMENT",
  "body": "<Summary of findings: X major, Y minor, Z trivial>",
  "comments": [
    {
      "path": "path/to/file.tsx",
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
5. **Do NOT comment on deleted files.**

## React/TypeScript-Specific Checks

- `useEffect` dependencies must be complete — missing deps cause stale closures
- `useEffect` cleanup functions must be present for subscriptions, timers, and abort controllers
- `useMemo` / `useCallback` should wrap expensive computations and callback props
- Avoid `as any` and `@ts-ignore` — prefer proper typing
- Keys in lists must be stable (not array index for dynamic lists)
- Event handlers should be properly typed (not `any`)
- Check for XSS: `dangerouslySetInnerHTML`, `innerHTML`, unescaped user content
- Verify error boundaries around async components
- Check for proper loading/error states in data fetching

## Output

After submitting, summarize findings:
- Count per severity (e.g., "2 Major, 3 Minor, 1 Trivial")
- Brief one-liner per comment
