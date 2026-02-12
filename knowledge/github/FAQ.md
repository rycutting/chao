# GitHub FAQ

## Why does `git push` say "Repository not found"?
- The repository may not exist yet, the remote URL may be wrong, or your account lacks access.

## Why does `ssh -T git@github.com` work but push still fails?
- SSH key auth is valid, but repository authorization is still missing (wrong owner/repo or no write permission).

## Why does `gh` fail while `git push` works?
- `gh` uses API tokens; Git SSH and GitHub API auth are separate.

## When should I ask before changing GitHub settings?
- Ask before destructive/security-sensitive changes. Routine metadata updates can be autonomous.
