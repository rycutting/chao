# Chao

Chao is a Telegram-based AI meta-assistant (`@Chao23Bot`) that acts as a central hub across projects.  
This repository contains workflow definitions, storage API contract examples, and sync utilities used to keep context aligned between Telegram, n8n, and Claude.

## What This Repo Contains

- `workflows/chao-telegram-bot-v2.json`: Main Telegram agent workflow
- `workflows/file-api.json`: Key-value File API workflow used for storage
- `scripts/sync-projects.sh`: Utility script for syncing project context
- `projects/`: Local project context backups
- `conversations/`: Local conversation backups
- `docs/`: Supporting documentation
- `CLAUDE.md`: Internal operational notes and architecture details

## Architecture Summary

- Interface: Telegram bot (`@Chao23Bot`)
- Orchestration: n8n workflows
- Model backend: Anthropic Claude (via HTTP in workflow nodes)
- Storage: n8n workflow static data exposed through a File API webhook

## File API

Endpoint (POST):

```text
https://n8n.srv1363974.hstgr.cloud/webhook/chao-files
```

Supported actions:

- `write`: store value under key
- `read`: fetch value by key
- `list`: list keys by prefix
- `delete`: remove key

Example payloads:

```json
{"action":"write","key":"project:my-project","value":"{\"name\":\"my-project\"}"}
```

```json
{"action":"read","key":"project:my-project"}
```

```json
{"action":"list","key":"project:"}
```

```json
{"action":"delete","key":"project:old-project"}
```

## Storage Keys

- `project:{name}`: Project definition JSON
- `conv:{name}`: Conversation history array
- `user:{chat_id}`: Active project selection for a Telegram user

## Development Notes

- Git remote should use SSH (already configured in this repo).
- Use `gh` CLI for repo metadata and automation tasks.
- Keep secrets in credential stores, not in committed files.

## Related Docs

For deeper implementation details, see `CLAUDE.md`.
