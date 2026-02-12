# GitHub Playbooks

## 1) Create and Push a New Repository
1. Initialize or enter local repo
2. Create remote repository on GitHub
3. Set SSH remote URL
4. Push default branch and set upstream

Reference commands are in `COMMANDS.md`.

## 2) Add a README and Ship It
1. Draft `README.md` with purpose, setup, and usage
2. Commit README only (avoid unrelated files)
3. Push to `main` or open a PR

## 3) Fix SSH Push Failures
1. Confirm remote URL uses `git@github.com:<owner>/<repo>.git`
2. Test SSH auth: `ssh -T git@github.com`
3. Ensure repo exists and account has write access
4. Retry push

## 4) Update Repo Metadata
1. Confirm `gh auth status`
2. Run `gh repo edit` for description/homepage/topics
3. Verify with `gh repo view --json ...`
