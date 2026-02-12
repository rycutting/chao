# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Chao?

Chao is Ryan's all-knowing AI meta-assistant, accessible via Telegram (@Chao23Bot). Chao is the central intelligence hub with visibility into ALL projects. Specialized bots handle specific tasks, but Chao sees everything. See `SKILLS.md` for Chao's identity charter and behavioral rules.

## Infrastructure

| Resource | Value |
|---|---|
| n8n URL | https://n8n.srv1363974.hstgr.cloud |
| n8n API Base | https://n8n.srv1363974.hstgr.cloud/api/v1 |
| n8n API Key | Stored in local secure env/credentials (do not commit plaintext keys) |
| VPS | srv1363974.hstgr.cloud (Hostinger), Tailscale IP: 100.87.167.74 |
| Workstation | ryan-coding, Tailscale IP: 100.95.230.36 |
| Telegram Bot | @Chao23Bot |
| Claude Model | claude-sonnet-4-5-20250929 (via direct HTTP to Anthropic API) |

## n8n Workflows

| Workflow | ID | Purpose |
|---|---|---|
| Chao - Telegram Claude Agent | `YEugdBF6miKsMD77` | Main bot: project-aware Claude assistant via Telegram |
| Chao - File API | `eprcRb9T9XYEc6KC` | Key-value storage API (webhook: `/webhook/chao-files`) |

## n8n Credentials

| Name | ID | Type | Notes |
|---|---|---|---|
| Telegram - Chao Bot | `L3EZ6B16Neo5QPbZ` | telegramApi | Works fine |
| Anthropic - Claude | `GwBddnedM9lndcuO` | anthropicApi | Broken for AI Agent sub-nodes; use direct HTTP instead |

## Architecture

```
Telegram (Ryan's phone)
    ↕ Telegram Bot API
n8n (VPS) — Chao Bot Workflow (YEugdBF6miKsMD77)
    ├── Telegram Trigger (message + callback_query)
    ├── Router (Code node) — commands, callbacks, routing, static data ops
    ├── IF: Needs Claude? — branches based on action type
    │   ├── Yes → Call Claude (HTTP Request → Anthropic API)
    │   │       → Save & Respond (Code node) — saves conv, formats reply
    │   │       → Send Claude Reply (HTTP Request → Telegram API)
    │   └── No  → Send Direct Reply (HTTP Request → Telegram API)
    └── Storage: $getWorkflowStaticData('global')

Claude Code (workstation terminal)
    ↕ chao-bridge.sh (reads/writes via n8n REST API → workflow static data)
n8n (VPS) — Same bot workflow static data
```

### Primary Storage: Bot Workflow Static Data

All data lives in the bot workflow's `$getWorkflowStaticData('global')`:

```javascript
{
  projects:      { key: {name, description, context, systemPrompt} },
  conversations: { key: [{role, content, timestamp}, ...] },  // max 100 per project
  userProjects:  { chatId: currentProjectKey },
  userState:     { chatId: {action: 'awaiting_project_name'} },
  lastActivity:  { chatId: timestampMs }
}
```

"General" is the implicit default project (key: `general`). Users start there and can switch via `/projects`.

### Secondary Storage: File API

The File API workflow (`eprcRb9T9XYEc6KC`) has its own separate static data store, accessed via HTTP POST to `/webhook/chao-files`. It was used for early data seeding and can serve as a secondary/backup store. Not directly connected to the bot's storage.

## Bridge: Claude Code ↔ Chao

The bridge script reads/writes the bot's internal data via the n8n REST API:

```bash
scripts/chao-bridge.sh list-projects              # List all projects
scripts/chao-bridge.sh read-conv <project-key>     # Read conversation (truncated)
scripts/chao-bridge.sh read-conv-full <project-key> # Read full conversation JSON
scripts/chao-bridge.sh push-context <project-key>   # Push context (reads from stdin)
scripts/chao-bridge.sh add-project <key> <name>     # Create a new project
scripts/chao-bridge.sh dump                         # Dump all raw static data
scripts/chao-bridge.sh get-field <field>            # Get specific field

# Examples:
scripts/chao-bridge.sh read-conv general
echo "Project is about day trading" | scripts/chao-bridge.sh push-context trading
scripts/chao-bridge.sh add-project trading "Day Trading"
```

The bridge does GET-modify-PUT on the workflow via the n8n API. It wraps/unwraps the `global` key in static data.

## Telegram Bot Commands

| Command | Behavior |
|---|---|
| `/projects` or `/start` | Show project buttons (excludes General) + "New Project" button |
| `/close` | Close current project, revert to General |
| `/status` | Show current project, message count, all projects |
| Tap project button | Switch to that project, load its context |
| Tap "+ New Project" | Chao asks for name → creates project → switches to it |
| Any text message | Sent to Claude with project context + last 20 conversation exchanges |

### Session Management
- **Default**: General (no project context, always active)
- **Timeout**: After 2 hours of inactivity in a non-General project, auto-reverts to General. Claude mentions the revert in its response.
- **Manual close**: `/close` immediately reverts to General

## Deploying Workflow Updates

```bash
# 1. Deactivate
curl -s -X POST "$API/workflows/YEugdBF6miKsMD77/deactivate" -H "X-N8N-API-KEY: $KEY"

# 2. Update (from workflow JSON file)
curl -s -X PUT "$API/workflows/YEugdBF6miKsMD77" -H "X-N8N-API-KEY: $KEY" \
  -H "Content-Type: application/json" -d @workflows/chao-telegram-bot-v2.json

# 3. Activate
curl -s -X POST "$API/workflows/YEugdBF6miKsMD77/activate" -H "X-N8N-API-KEY: $KEY"
```

## Critical n8n Constraints

- **Code node sandbox**: `require('fs')`, `require('child_process')` blocked. Only `$getWorkflowStaticData()`, `$input`, `$('NodeName')` references, and standard JS.
- **No executeCommand node**: Not available in this n8n installation.
- **Credential system quirk**: Anthropic credentials via API don't work in AI Agent sub-nodes. Workaround: direct HTTP Request with API key in headers.
- **Switch node V3**: Broken when deployed via API. Use IF nodes for routing.
- **Static data isolation**: Each workflow has its own `$getWorkflowStaticData()`. Workflows cannot access each other's data.
- **Deploy cycle**: Must deactivate → PUT → activate. Uses `POST .../deactivate` and `POST .../activate` (not PATCH).

## File Layout

```
chao/
├── CLAUDE.md                                  ← This file
├── SKILLS.md                                  ← Chao identity charter and behavior rules
├── README.md                                  ← Project overview
├── workflows/
│   ├── chao-telegram-bot-v2.json              ← Current deployed bot workflow
│   ├── chao-telegram-bot-v1-archive.json      ← Original simple bot (archived)
│   └── file-api.json                          ← File API workflow
├── scripts/
│   ├── chao-bridge.sh                         ← Bridge: Claude Code ↔ bot data via n8n API
│   └── sync-projects.sh                       ← Legacy File API sync (superseded by bridge)
├── knowledge/                                 ← Durable knowledge bases (see SKILLS.md)
│   └── github/                                ← GitHub knowledge folder
├── projects/                                  ← Local project context backups
└── conversations/                             ← Local conversation log backups
```

## Related Project

The n8n infrastructure config lives at `/home/ryan/projects/n8n_setup/`. That repo has n8n reference docs, the instance utility script, and its own CLAUDE.md with infrastructure details.
