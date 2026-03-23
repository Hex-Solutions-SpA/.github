# Hex Solutions — Organization Defaults & Repo Template

This repo serves two purposes for **Hex-Solutions-SpA**:

1. **Org-wide defaults** — GitHub automatically uses the files here as fallbacks for any repo in the org that doesn't define its own equivalent.
2. **Repo template** — the files listed below are the canonical starting point for every new repo.

> **Important:** This repo must remain **public** for org-wide defaults to work.

---

## What to copy to every new repo

| Source (here) | Destination (new repo) |
|---|---|
| `ISSUE_TEMPLATE/` | `.github/ISSUE_TEMPLATE/` |
| `pull_request_template.md` | `.github/pull_request_template.md` |
| `workflows/ci.yml` | `.github/workflows/ci.yml` |
| `workflows/commitlint.yml` | `.github/workflows/commitlint.yml` |
| `commitlint.config.js` | `commitlint.config.js` (repo root) |

After copying, **replace the placeholder job in `.github/workflows/ci.yml`** with the actual build, analysis, and test steps for that repo. See Fyodor for a real example.

---

## Issue templates

Three templates covering all project domains:

| Template | When to use |
|---|---|
| `bug_report.md` | Software or firmware errors |
| `feature_request.md` | New functionality proposals |
| `hardware_issue.md` | PCB schematic, layout, or BOM issues |

## Pull request template

Loaded automatically when opening any PR. Fill in the change type, testing environment, validation checklist, and related issue number.

---

## Branch governance (org ruleset)

Branch protection is configured directly in GitHub via an organization ruleset — no automation needed.

**To view or edit:** `github.com/organizations/Hex-Solutions-SpA/settings/rules`

### Rules applied to `main` and `dev` across all repos

- **PRs required** — no direct pushes
- **2 reviewer approvals** before merging
- **Branch must be up to date** with target before merge
- **Required status checks must pass** — configure per repo (see below)
- **Linear history** — one commit per merged PR (squash or rebase)
- **No force-push** or branch deletion

### Configuring required status checks for a new repo

When you add a new repo, add its CI checks to the ruleset:

1. Run the CI workflow once on any branch — this registers the check names in GitHub
2. Go to `github.com/organizations/Hex-Solutions-SpA/settings/rules`
3. Edit the ruleset → Required status checks → add the checks that must pass
4. Check names follow the format `{workflow name} / {job name}`, e.g.:
   - `CI / firmware-format`
   - `CI / firmware-sca`
   - `CI / firmware-test`
   - `Commitlint / commitlint`

---

## CI/CD structure

Each repo has a `.github/workflows/ci.yml` with named jobs. There is no required job name — all jobs that should block merging must be added to the org ruleset manually.

For Zephyr firmware repos the standard jobs are:

| Job | What it does |
|---|---|
| `firmware-format` | `clang-format -Werror --dry-run` on `src/` and `include/` |
| `firmware-sca` | CodeChecker (clangsa + clang-tidy) via `west build` with SCA variant |
| `firmware-test` | `west twister -p native_sim` for unit tests |

Runners must be self-hosted and tagged `[self-hosted, linux, zephyr, <repo-name>]`.

---

## Commit message convention (Commitlint)

Every repo includes `commitlint.yml` and `commitlint.config.js` to enforce [Conventional Commits](https://www.conventionalcommits.org).

**Format:** `<type>: <description>`

| Type | Use for |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that isn't a fix or feature |
| `test` | Adding or updating tests |
| `build` | Build system or dependency changes |
| `ci` | CI configuration changes |
| `chore` | Maintenance |
| `perf` | Performance improvement |
| `style` | Formatting, no logic change |
| `revert` | Reverting a previous commit |

Example: `feat: add IMU driver for LSM6DSO`
