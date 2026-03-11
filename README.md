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
      "base_branches": ["main"]
    }
  ],
  "review_language": "en",
  "cron_interval_minutes": 10
}
```

| Field | Description |
|-------|-------------|
| `repos[].name` | Short name used in CLI commands (e.g., `./scripts/review-pr.sh api 42`) |
| `repos[].github` | Full GitHub repo path (`owner/repo`) |
| `repos[].skill` | Name of the skill folder in `skills/` to use for this repo |
| `repos[].base_branches` | Target branches to watch for PRs (e.g., `main`, `dev`) |

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

The `{{GITHUB_REPO}}` placeholder in skill files is automatically replaced with the repo path from config.

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

## License

MIT
