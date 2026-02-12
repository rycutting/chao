# GitHub Concepts

## Core Model
- Local repo: your files and commit history on this machine
- Remote repo: hosted copy on GitHub (typically `origin`)
- Branches: parallel lines of development
- Pull Request: review and merge mechanism from one branch into another

## Authentication Paths
- SSH for Git operations (`git push`, `git pull`)
- `gh` authentication for API-backed actions (repo settings, PR automation, issues)

## Good Defaults
- Keep `main` protected and stable
- Use short-lived feature branches
- Write clear commits with scoped changes
- Push early and often to avoid local-only drift
