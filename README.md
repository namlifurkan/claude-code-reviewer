# Claude Code PR Reviewer

Automated pull request reviewer powered by [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Analyzes PR diffs and posts inline comments directly on GitHub with severity-based categorization.

Uses your **Claude Code subscription** — no API key needed.

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  cron (every N minutes)                             │
│  └─ watch-prs.sh                                    │
│      ├─ gh pr list → find new/updated PRs           │
│      ├─ claude -p (headless) → analyze diff          │
│      └─ gh api → post inline comments on GitHub     │
└─────────────────────────────────────────────────────┘
```

1. Checks configured repos for open PRs
2. Skips PRs already reviewed (tracked by commit SHA)
3. Runs Claude Code in headless mode with your skill file
4. Posts categorized inline comments (**Major** / **Minor** / **Trivial**)
5. When a new commit is pushed, the PR gets re-reviewed

## Features

- **Multi-repo** — review PRs across multiple repositories from one place
- **Configurable skills** — different review rules per repo/language
- **Auto-dedup** — tracks commit SHAs, never reviews the same code twice
- **Cross-platform** — macOS, Linux, Windows (WSL/Git Bash)
- **Zero API cost** — runs on your Claude Code subscription
- **Severity labels** — every comment tagged Major/Minor/Trivial
- **Customizable** — add your own project context, patterns, and language

## Quick Start

```bash
git clone https://github.com/namlifurkan/claude-code-reviewer.git
cd claude-code-reviewer

# Edit config.json with your repos
cp config.json config.json.backup
nano config.json

# Run setup
chmod +x setup.sh
./setup.sh

# Review a PR manually
./scripts/review-pr.sh api 42
```

## Prerequisites

| Tool | macOS | Linux | Windows |
|------|-------|-------|---------|
| **Node.js** | `brew install node` | `sudo apt install nodejs npm` | [nodejs.org](https://nodejs.org) |
| **Claude Code** | `npm i -g @anthropic-ai/claude-code` | same | same |
| **GitHub CLI** | `brew install gh` | [install guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) | `winget install GitHub.cli` |
| **jq** | `brew install jq` | `sudo apt install jq` | `winget install jqlang.jq` |

You also need:
- **Claude Pro or Max subscription** (for Claude Code CLI access)
- **GitHub access** to the repos you want to review (read + write PR comments)

## Configuration

### config.json

```json
{
  "repos": [
    {
      "name": "api",
      "github": "your-org/your-api-repo",
      "skill": "example-laravel",
      "base_branches": ["main", "dev"]
    },
    {
      "name": "frontend",
      "github": "your-org/your-frontend-repo",
      "skill": "example-react",
      "base_branches": ["main"],
      "language": "tr"
    }
  ],
  "default_language": "en",
  "cron_interval_minutes": 10
}
```

| Field | Description |
|-------|-------------|
| `repos[].name` | Short name used in CLI commands (e.g., `./scripts/review-pr.sh api 42`) |
| `repos[].github` | Full GitHub repo path (`owner/repo`) |
| `repos[].skill` | Name of the skill folder in `skills/` to use for this repo |
| `repos[].base_branches` | Target branches to watch for PRs (e.g., `main`, `dev`) |
| `repos[].language` | Review comment language for this repo (overrides `default_language`) |
| `repos[].context_files` | Array of file paths to read before review for project context (e.g., `["src/utils/index.ts"]`) |
| `repos[].explore_repo_structure` | If `true`, Claude explores the repo structure before reviewing (default: `false`) |
| `repos[].max_comments` | Max comments per review for this repo (overrides global) |
| `repos[].min_severity` | Minimum severity to post for this repo (overrides global) |
| `repos[].exclude_patterns` | Additional exclude patterns for this repo (merged with global) |
| `default_language` | Default language for all repos (default: `en`) |
| `max_comments` | Global max comments per review (default: `7`) |
| `min_severity` | Global minimum severity to post: `P0`, `P1`, `P2`, or `P3` (default: `P2`) |
| `exclude_patterns` | Global file patterns to exclude from review (e.g., `.env*`, `*.lock`) |

### Review Language

Review comments can be written in any language. Set per-repo or globally:

```json
{
  "default_language": "en",
  "repos": [
    { "name": "api", "language": "tr", "..." : "..." },
    { "name": "frontend", "..." : "..." }
  ]
}
```

- `api` reviews will be in **Turkish** (repo-level override)
- `frontend` reviews will be in **English** (falls back to `default_language`)

**Supported language codes:**

| Code | Language | Code | Language | Code | Language |
|------|----------|------|----------|------|----------|
| `en` | English | `fr` | French | `ja` | Japanese |
| `tr` | Turkish | `es` | Spanish | `ko` | Korean |
| `de` | German | `pt` | Portuguese | `zh` | Chinese |
| `it` | Italian | `nl` | Dutch | `ru` | Russian |
| `pl` | Polish | `hi` | Hindi | `ar` | Arabic |

Any other value is passed as-is (e.g., `"language": "Brazilian Portuguese"`).

### Skills

Skills define **how** Claude reviews a specific repo. Each skill is a markdown file with:
- Instructions for analyzing the diff
- Project-specific context (framework, patterns, common pitfalls)
- Language-specific checks

**Included templates:**

| Skill | Language/Framework | Key Checks |
|-------|--------------------|------------|
| `example` | Generic | Bugs, null checks, security, edge cases |
| `example-laravel` | PHP / Laravel | Soft deletes, casts, migrations, N+1, mass assignment |
| `example-react` | React / TypeScript | useEffect deps, memory leaks, XSS, accessibility |
| `example-python` | Python | Type hints, exceptions, async, SQL injection, resource mgmt |

**To create your own skill:**

```bash
cp -r skills/example skills/my-project
nano skills/my-project/skill.md
```

Then reference it in `config.json`:
```json
{ "name": "my-project", "github": "org/repo", "skill": "my-project", ... }
```

Placeholders in skill files are automatically replaced:
- `{{GITHUB_REPO}}` → repo path from config (e.g., `your-org/your-repo`)
- `{{REVIEW_LANGUAGE}}` → language name from config (e.g., `Turkish`, `English`)

## Usage

### Manual Review

```bash
# Review a specific PR
./scripts/review-pr.sh <repo-name> <pr-number>

# Examples
./scripts/review-pr.sh api 229
./scripts/review-pr.sh frontend 42
```

### Automatic Review (Cron)

The watcher checks all configured repos for new/updated PRs and reviews them automatically.

**Test it first:**
```bash
./scripts/watch-prs.sh
```

#### macOS / Linux

```bash
crontab -e
# Add this line (adjust path and interval):
*/10 * * * * /absolute/path/to/claude-code-reviewer/scripts/watch-prs.sh
```

#### Windows (WSL)

```bash
# Start cron service (required in WSL)
sudo service cron start

crontab -e
# */10 * * * * /path/to/claude-code-reviewer/scripts/watch-prs.sh
```

> WSL cron stops when the terminal closes. To auto-start, add to `~/.bashrc`:
> ```bash
> [ -z "$(ps -ef | grep cron | grep -v grep)" ] && sudo service cron start
> ```

#### Windows (Git Bash / PowerShell)

```powershell
schtasks /create /tn "ClaudeCodeReviewer" /tr "bash C:\path\to\scripts\watch-prs.sh" /sc minute /mo 10
```

### How Dedup Works

Each PR is tracked by its latest commit SHA in `.state/<repo-name>.json`:

```json
{
  "229": "abc123def456...",
  "230": "789xyz..."
}
```

- New PR opened → not in state → gets reviewed
- Same commit → already in state → skipped
- New commit pushed → SHA changed → gets re-reviewed

## Project Structure

```
claude-code-reviewer/
├── config.json                  # Your repo configuration
├── setup.sh                     # One-time setup (cross-platform)
├── scripts/
│   ├── review-pr.sh             # Manual: review single PR
│   └── watch-prs.sh             # Auto: watch all repos for new PRs
├── skills/
│   ├── example/                 # Generic review template
│   │   └── skill.md
│   ├── example-laravel/         # Laravel-specific checks
│   │   └── skill.md
│   ├── example-react/           # React/TypeScript-specific checks
│   │   └── skill.md
│   └── example-python/          # Python-specific checks
│       └── skill.md
└── .state/                      # (gitignored) Runtime state
    ├── <repo-name>.json         # Reviewed PR commit SHAs
    └── review.log               # Review logs
```

## Monitoring

```bash
# Watch logs in real-time
tail -f .state/review.log

# Check reviewed PRs for a repo
cat .state/api.json | jq .

# Force re-review a PR (remove from state)
jq 'del(."229")' .state/api.json > tmp && mv tmp .state/api.json

# Or just run it manually
./scripts/review-pr.sh api 229
```

## Comment Format

Every comment posted on GitHub follows this format:

```
**[Major]** `DB::table()` does not auto-apply SoftDeletes.
Deleted records are being counted in the query. Add `->whereNull('deleted_at')`.
```

Severity levels:

| Level | Meaning | Action Required |
|-------|---------|-----------------|
| **Major** | Bug, security issue, data loss risk, breaking change | Must fix before merge |
| **Minor** | Design concern, missing coverage, questionable pattern | Should discuss |
| **Trivial** | Style, naming, minor inconsistency | Nice to fix |

## Adding a New Repo

1. Create a skill (or reuse an existing one):
   ```bash
   cp -r skills/example-laravel skills/my-new-project
   # Edit skills/my-new-project/skill.md with project-specific context
   ```

2. Add to `config.json`:
   ```json
   {
     "name": "my-new-project",
     "github": "org/repo",
     "skill": "my-new-project",
     "base_branches": ["main"]
   }
   ```

3. Done. The watcher will pick it up on the next cycle.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `claude: command not found` | `npm install -g @anthropic-ai/claude-code` |
| `gh: command not found` | Install GitHub CLI for your platform (see Prerequisites) |
| `Cannot access repo` | `gh auth login` — ensure you have repo access |
| Cron not running | Verify with `crontab -l`, use absolute paths |
| Cron not running (WSL) | Run `sudo service cron start` |
| PR not being reviewed | Check `.state/<repo>.json` — delete the PR entry to force re-review |
| Wrong skill used | Verify `config.json` maps the repo to the correct skill name |
| Rate limited by GitHub | Reduce cron frequency or number of repos |

## Data Privacy

**Important:** This tool sends PR diffs to the Anthropic API via Claude Code for analysis. Be aware of the following:

- **Code is sent externally.** PR diffs are processed by Anthropic's Claude API. Review [Anthropic's data policy](https://www.anthropic.com/privacy) for details.
- **Sensitive files are excluded by default.** Files matching `exclude_patterns` in `config.json` (e.g., `.env*`, `*.pem`, `*.key`, `*.lock`) are automatically filtered out and never sent for review.
- **You can add custom exclusions.** Add patterns globally or per-repo to prevent sensitive files from being reviewed:

```json
{
  "exclude_patterns": [".env*", "*.pem", "secrets/", "internal-docs/"],
  "repos": [
    {
      "name": "api",
      "exclude_patterns": ["config/credentials.php"]
    }
  ]
}
```

- **Lock files are excluded** to avoid wasting review time on auto-generated content.
- For highly sensitive projects, consider self-hosting or review the diff output before enabling auto-review.

## Noise Control

Control how many and which severity comments are posted:

```json
{
  "max_comments": 7,
  "min_severity": "P1",
  "repos": [
    {
      "name": "api",
      "max_comments": 5,
      "min_severity": "P0"
    }
  ]
}
```

| Setting | Effect |
|---------|--------|
| `max_comments: 7` | At most 7 comments per review, prioritized by severity |
| `min_severity: "P1"` | Only P0 and P1 findings are posted as comments |
| Similar findings | Grouped into one comment with "also found in: ..." references |

Lower-severity findings that are filtered out are still mentioned in the review summary (e.g., "Also found 3 P3 issues, omitted per noise policy").

## Repository Context

Help Claude understand your project beyond the diff:

```json
{
  "repos": [
    {
      "name": "api",
      "explore_repo_structure": true,
      "context_files": [
        "src/utils/index.ts",
        "src/helpers/common.ts",
        "ARCHITECTURE.md"
      ]
    }
  ]
}
```

| Setting | Effect |
|---------|--------|
| `explore_repo_structure: true` | Claude reads the repo's file tree before reviewing |
| `context_files: [...]` | Specific files Claude reads before every review |

This prevents "reinventing the wheel" comments and helps Claude catch:
- Duplicate implementations of existing utilities
- Pattern deviations from established conventions
- Missed opportunities to reuse existing code

## License

MIT
