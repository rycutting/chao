# GitHub Commands

## Inspect Repo State
```bash
git status -sb
git branch --show-current
git remote -v
```

## Set SSH Remote
```bash
git remote set-url origin git@github.com:<owner>/<repo>.git
```

## SSH Auth Check
```bash
ssh -T git@github.com
```

## Push with Upstream
```bash
git push -u origin main
```

## GitHub CLI Auth
```bash
gh auth login
gh auth status
```

## Edit Repo Description
```bash
gh repo edit <owner>/<repo> --description "Your repo description"
gh repo view <owner>/<repo> --json name,description,url
```
