---
description: "Review GitHub PRs with inline line-based comments categorized by severity (P0/P1/P2/P3)"
---

# PR Review

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

### 2. Large Diff Strategy

If the diff exceeds **500 lines**, do NOT try to review everything at once:
1. First run `gh pr diff <PR_NUMBER> --repo {{GITHUB_REPO}} | diffstat` to get a file summary
2. Group files by module/directory
3. Review each module group separately
4. Prioritize by risk: core logic > data layer > API surface > tests > config

### 3. Analyze the Diff

Review ALL changed files through these lenses:

#### A. Bugs & Logic Errors
- Missing edge cases or null checks
- Behavioral changes that may break existing functionality
- Type mismatches or incorrect casts
- Off-by-one errors, wrong comparison operators

#### B. SOLID Principles
- **Single Responsibility**: Does a class/method do too many things?
- **Open/Closed**: Are changes modifying existing code where extension would be safer?
- **Liskov Substitution**: Do overridden methods change expected behavior?
- **Interface Segregation**: Are interfaces bloated with unused methods?
- **Dependency Inversion**: Are concrete classes used where abstractions should be?

Only flag SOLID violations when they introduce real risk — not theoretical purity.

#### C. Removal Candidates
- Unused imports, variables, methods added in this PR
- Dead code behind impossible conditions
- Redundant checks where the type system already guarantees safety
- Categorize as: "safe to delete now" vs "defer with follow-up"

#### D. Security & Reliability
- Injection attacks (SQL, command, XSS)
- Authorization/authentication gaps
- Secret leakage (hardcoded keys, credentials)
- Race conditions (check-then-act without locking)
- Unsafe deserialization
- Missing input validation at system boundaries

#### E. Performance
- N+1 query problems
- Unbounded queries or loops
- Missing pagination
- Heavy operations inside loops
- Missing cache invalidation

### 4. Categorize Findings by Severity

- 🔴 **P0 (Critical)**: Security vulnerabilities, data loss risk, production-breaking bugs — **must block merge**
- 🟠 **P1 (High)**: Logic errors, SOLID violations with real impact, performance regressions
- 🟡 **P2 (Medium)**: Code smells, missing coverage, maintainability concerns — fix now or create follow-up
- 🟢 **P3 (Low)**: Style, naming, minor inconsistencies — optional, nice to fix

### 5. Submit Review with Inline Comments

```bash
cat <<'JSONEOF' | gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews --method POST --input -
{
  "commit_id": "<COMMIT_SHA>",
  "event": "COMMENT",
  "body": "<Summary: X P0, Y P1, Z P2, W P3. Overall: BLOCK/APPROVE WITH COMMENTS/APPROVE>",
  "comments": [
    {
      "path": "path/to/file",
      "line": <LINE_NUMBER_IN_NEW_FILE>,
      "body": "🔴 **[P0]** Description of the issue."
    }
  ]
}
JSONEOF
```

**Review event logic:**
- Any P0 finding → `"event": "REQUEST_CHANGES"`
- Only P1-P3 findings → `"event": "COMMENT"`
- No findings → `"event": "APPROVE"` with body "LGTM"

## Rules

1. **ONLY leave comments for issues/bugs/concerns.** No positive or praise comments. No noise.
2. **Every comment MUST have a severity prefix**: `🔴 **[P0]**`, `🟠 **[P1]**`, `🟡 **[P2]**`, or `🟢 **[P3]**`.
3. **Comments must be on diff lines only.** The `line` field refers to the line number in the NEW version of the file.
4. **Be concise and actionable.** State the problem and suggest a fix.
5. **Do NOT comment on deleted files.**
6. **Max 15 comments per review.** Prioritize by severity, mention omitted count in review body.

## Project Context

<!-- CUSTOMIZE THIS SECTION FOR YOUR PROJECT -->

- Add your project-specific context here
- Framework, language, patterns used
- Architecture decisions reviewers should know about
- Common pitfalls specific to your codebase
- Known bug patterns to watch for

## Output

After submitting, summarize findings:
- Count per severity (e.g., "1 P0, 2 P1, 3 P2, 1 P3")
- Overall verdict: BLOCK / APPROVE WITH COMMENTS / APPROVE
- Brief one-liner per comment
