---
description: "Review Laravel PRs with inline line-based comments categorized by severity"
---

# Laravel PR Review

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
- **Missing edge cases or null checks**
- **Behavioral changes that may break existing functionality**
- **Type mismatches or incorrect casts**
- **Deleted tests without replacement coverage**
- **Security concerns** (SQL injection, XSS, mass assignment)
- **Migration issues** (column types, indexes, rollback safety, data loss risk)
- **N+1 query problems**

### 3. Categorize Findings by Severity

- **Major**: Bugs, data loss risk, breaking behavioral changes, missing validations, dangerous migrations, security vulnerabilities
- **Minor**: Design concerns, missing coverage, questionable decisions that won't break but should be discussed
- **Trivial**: Inconsistencies, style issues, small questions about intent

### 4. Submit Review with Inline Comments

```bash
cat <<'JSONEOF' | gh api repos/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews --method POST --input -
{
  "commit_id": "<COMMIT_SHA>",
  "event": "COMMENT",
  "body": "<Summary of findings: X major, Y minor, Z trivial>",
  "comments": [
    {
      "path": "path/to/file.php",
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
3. **Comments must be on diff lines only.** The `line` field refers to the line number in the NEW version of the file.
4. **Be concise and actionable.** State the problem and suggest a fix.
5. **Write all review comments in {{REVIEW_LANGUAGE}}.**
6. **Do NOT comment on deleted files.**

## Laravel-Specific Checks

- `DB::table()` does NOT auto-apply SoftDeletes — verify `whereNull('deleted_at')` filters
- Nullable fields cast with `(int)` turn `null` into `0` — check for logic bugs
- `Collection::get()` can return `null` — verify nullsafe operator (`?->`) usage
- `factory()` helper is deprecated — use `Model::factory()`
- PHPUnit 10+ uses `#[DataProvider()]` attributes, not `@dataProvider` annotations
- Data providers must be `static` methods
- Check migrations for rollback safety (`down()` method)
- Verify mass assignment protection (`$fillable` / `$guarded`)

## Documentation References

Before reviewing, fetch relevant Laravel documentation for features used in the diff:

```
WebFetch url="https://laravel.com/docs/11.x/eloquent#soft-deleting"
WebFetch url="https://laravel.com/docs/11.x/eloquent-mutators#attribute-casting"
WebFetch url="https://laravel.com/docs/11.x/migrations#available-column-types"
```

Adjust the version (`11.x`) to match the project's `composer.json`.

## Output

After submitting, summarize findings:
- Count per severity (e.g., "2 Major, 3 Minor, 1 Trivial")
- Brief one-liner per comment
