#!/bin/bash
# Deploy Chao workflow to n8n
# Injects secrets from .secrets.json before deploying, so secrets never touch git.
#
# Usage: scripts/deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$PROJECT_DIR/.secrets.json"
WORKFLOW_FILE="$PROJECT_DIR/workflows/chao-telegram-bot-v2.json"
WORKFLOW_ID="YEugdBF6miKsMD77"

N8N_API="${N8N_API:-https://n8n.srv1363974.hstgr.cloud/api/v1}"
N8N_KEY="${N8N_API_KEY:-}"

if [ -z "$N8N_KEY" ]; then
  echo "Error: N8N_API_KEY is not set." >&2
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "Error: $SECRETS_FILE not found." >&2
  echo "Create it with: {\"ANTHROPIC_API_KEY\": \"...\", \"TELEGRAM_BOT_TOKEN\": \"...\"}" >&2
  exit 1
fi

echo "Injecting secrets and deploying..."

# Build the payload: read workflow, replace placeholders with real secrets
PAYLOAD=$(python3 -c "
import json
with open('$WORKFLOW_FILE') as f:
    wf = json.load(f)
with open('$SECRETS_FILE') as f:
    secrets = json.load(f)

# Convert to string, replace placeholders, convert back
wf_str = json.dumps(wf)
wf_str = wf_str.replace('YOUR_ANTHROPIC_API_KEY', secrets['ANTHROPIC_API_KEY'])
wf_str = wf_str.replace('YOUR_TELEGRAM_BOT_TOKEN', secrets['TELEGRAM_BOT_TOKEN'])
print(wf_str)
")

# Deactivate
curl -s -X POST "$N8N_API/workflows/$WORKFLOW_ID/deactivate" \
  -H "X-N8N-API-KEY: $N8N_KEY" > /dev/null
echo "Deactivated"
sleep 2

# Update
curl -s -X PUT "$N8N_API/workflows/$WORKFLOW_ID" \
  -H "X-N8N-API-KEY: $N8N_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null
echo "Updated"
sleep 2

# Activate
curl -s -X POST "$N8N_API/workflows/$WORKFLOW_ID/activate" \
  -H "X-N8N-API-KEY: $N8N_KEY" > /dev/null
echo "Activated"

echo "Deploy complete."
