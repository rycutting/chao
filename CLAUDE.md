# Chao - All-Knowing AI Assistant

## What is Chao?
Chao is Ryan's all-knowing AI meta-assistant, accessible via Telegram (@Chao23Bot). Chao has visibility into all projects and serves as the central AI hub. Specialized bots handle specific tasks, but Chao sees everything.

## Architecture
- **Telegram Bot**: @Chao23Bot (token stored in n8n credentials)
- **n8n Instance**: https://n8n.srv1363974.hstgr.cloud
- **Model**: Claude Sonnet 4.5 via Anthropic API (direct HTTP)
- **Storage**: n8n workflow static data via File API webhook
- **File API URL**: https://n8n.srv1363974.hstgr.cloud/webhook/chao-files

## n8n Workflows
- **Chao - Telegram Claude Agent** (ID: YEugdBF6miKsMD77) - Main bot workflow
- **Chao - File API** (ID: eprcRb9T9XYEc6KC) - Key-value storage API

## Storage Schema
Data is stored as key-value pairs via the File API webhook:
- `project:{name}` - Project definition JSON: {name, description, context, systemPrompt}
- `conv:{name}` - Conversation history JSON array: [{role, content, timestamp}, ...]
- `user:{chat_id}` - Current project selection for a user

## File API Usage
POST to https://n8n.srv1363974.hstgr.cloud/webhook/chao-files

### Write:
```json
{"action": "write", "key": "project:my-project", "value": "{...json string...}"}
```

### Read:
```json
{"action": "read", "key": "project:my-project"}
```

### List (by prefix):
```json
{"action": "list", "key": "project:"}
```

### Delete:
```json
{"action": "delete", "key": "project:old-project"}
```

## Adding a New Project
1. Push project data via File API or sync script
2. Chao will automatically show it in /projects menu

## Syncing Context Between Claude Code and Chao
- From Claude Code: Use sync script or curl to push project context updates
- From Chao: Conversation history auto-saved; Claude Code reads via File API

## Credentials
- n8n API Key: stored in /home/ryan/projects/n8n_setup/CLAUDE.md
- Telegram Bot Token: stored in n8n credential ID L3EZ6B16Neo5QPbZ
- Anthropic API Key: used directly in workflow HTTP Request headers

## Project Folder Structure
```
chao/
├── CLAUDE.md          ← This file
├── workflows/         ← Workflow JSON definitions
├── scripts/           ← Sync and utility scripts
├── projects/          ← Local project context backups
├── conversations/     ← Local conversation log backups
└── docs/              ← Documentation
```
