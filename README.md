# Chao

Chao is a Telegram-based AI meta-assistant (`@Chao23Bot`) that acts as a central hub across projects.  
This repository contains n8n workflows, bridge tooling, and durable knowledge artifacts that keep context aligned between Telegram, n8n, and Claude Code.

## What This Repo Contains

- `workflows/chao-telegram-bot-v2.json`: Main Telegram agent workflow
- `workflows/chao-telegram-bot-v1-archive.json`: Archived v1 workflow snapshot
- `workflows/file-api.json`: Secondary key-value File API workflow
- `scripts/chao-bridge.sh`: Bridge between Claude Code and bot static data via n8n API
- `scripts/sync-projects.sh`: Legacy sync utility (File API based)
- `SKILLS.md`: Chao identity and behavior charter
- `knowledge/`: Reusable topic knowledge folders (shared with other bots)
- `projects/`: Local project context backups
- `conversations/`: Local conversation backups
- `docs/`: Supporting documentation
- `CLAUDE.md`: Internal operational notes and architecture details

## Architecture Summary

- Interface: Telegram bot (`@Chao23Bot`)
- Orchestration: n8n workflows
- Model backend: Anthropic Claude (via HTTP in workflow nodes)
- Primary storage: Bot workflow static data (`$getWorkflowStaticData('global')`)
- Secondary storage: File API webhook workflow (`/webhook/chao-files`)

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

## Bridge Workflow Access

Common bridge commands:

```bash
export N8N_API_KEY="your_n8n_api_key"
scripts/chao-bridge.sh list-projects
scripts/chao-bridge.sh read-conv general
echo "Context update" | scripts/chao-bridge.sh push-context my-project
scripts/chao-bridge.sh add-project my-project "My Project"
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
