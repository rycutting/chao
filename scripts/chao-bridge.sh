#!/bin/bash
# Chao Bridge Script
# Reads/writes Chao bot's internal data via the n8n REST API.
# This is the bridge between Claude Code sessions and Chao's Telegram bot.
#
# Usage:
#   chao-bridge.sh list-projects          List all projects
#   chao-bridge.sh read-conv <project>    Read conversation history
#   chao-bridge.sh push-context <project> Push project context (reads from stdin)
#   chao-bridge.sh add-project <key> <name>  Create a new project
#   chao-bridge.sh dump                   Dump all static data (raw)
#   chao-bridge.sh get-field <field>      Get a top-level field from static data

N8N_API="https://n8n.srv1363974.hstgr.cloud/api/v1"
N8N_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlYWQ5MmZlMi1hMWZjLTQ1ZGQtYWZhNS05NGI3ZDZiMWY5ZmEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiNjhlYTg5ODgtZWY5Mi00MmViLTg1YTQtNjg1NTAzOGFlOTA3IiwiaWF0IjoxNzcwOTE1NDA3fQ.YhTe92pbexQ6N_yW9HPapIdSU5lgyfo0S1SDwWqgLy4"
WORKFLOW_ID="YEugdBF6miKsMD77"

# Fetch the workflow's static data (unwraps the 'global' key)
get_static_data() {
  curl -s "${N8N_API}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_KEY}" | python3 -c "
import sys, json
wf = json.load(sys.stdin)
sd = wf.get('staticData')
if sd is None:
    print('{}')
elif isinstance(sd, str):
    sd = json.loads(sd) if sd else {}
    print(json.dumps(sd.get('global', sd)))
else:
    print(json.dumps(sd.get('global', sd)))
"
}

# Update the workflow's static data (GET-modify-PUT)
put_static_data() {
  local NEW_SD="$1"

  # Get full workflow first
  local FULL_WF
  FULL_WF=$(curl -s "${N8N_API}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_KEY}")

  # Build update payload: wrap static data back in 'global' key
  local PAYLOAD
  PAYLOAD=$(echo "$FULL_WF" | python3 -c "
import sys, json
wf = json.load(sys.stdin)
new_sd = json.loads('''${NEW_SD}''')
update = {
    'name': wf['name'],
    'nodes': wf['nodes'],
    'connections': wf['connections'],
    'settings': wf.get('settings', {}),
    'staticData': {'global': new_sd}
}
print(json.dumps(update))
")

  curl -s -X PUT "${N8N_API}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null 2>&1

  echo "OK"
}

case "$1" in
  list-projects)
    get_static_data | python3 -c "
import sys, json
sd = json.load(sys.stdin)
projects = sd.get('projects', {})
user_projects = sd.get('userProjects', {})
convs = sd.get('conversations', {})
print('Projects:')
print('  general (default, always active)')
for key, proj in projects.items():
    if key == 'general':
        continue
    conv_count = len(convs.get(key, []))
    active = ' [ACTIVE]' if key in user_projects.values() else ''
    print(f'  {key}: {proj[\"name\"]}{active} ({conv_count} messages)')
"
    ;;

  read-conv)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 read-conv <project-key>"
      exit 1
    fi
    get_static_data | python3 -c "
import sys, json
sd = json.load(sys.stdin)
convs = sd.get('conversations', {})
conv = convs.get('$PROJECT', [])
if not conv:
    print('No conversation history for: $PROJECT')
    sys.exit(0)
print(f'Conversation for $PROJECT ({len(conv)} messages):')
print('---')
for msg in conv:
    role = msg.get('role', '?')
    content = msg.get('content', '')
    ts = msg.get('timestamp', '')
    prefix = 'Ryan' if role == 'user' else 'Chao'
    # Truncate long messages for display
    if len(content) > 300:
        content = content[:297] + '...'
    print(f'[{ts}] {prefix}: {content}')
    print()
"
    ;;

  read-conv-full)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 read-conv-full <project-key>"
      exit 1
    fi
    get_static_data | python3 -c "
import sys, json
sd = json.load(sys.stdin)
convs = sd.get('conversations', {})
conv = convs.get('$PROJECT', [])
print(json.dumps(conv, indent=2))
"
    ;;

  push-context)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 push-context <project-key>"
      echo "Then type or pipe the context text, end with Ctrl+D"
      exit 1
    fi
    CONTEXT=$(cat)
    if [ -z "$CONTEXT" ]; then
      echo "No context provided."
      exit 1
    fi

    SD=$(get_static_data)
    NEW_SD=$(echo "$SD" | python3 -c "
import sys, json
sd = json.load(sys.stdin)
context = sys.stdin.read() if not sys.stdin.closed else ''
" 2>/dev/null)

    # Use a temp file approach to avoid quoting hell
    TMPFILE=$(mktemp)
    echo "$SD" > "$TMPFILE"
    python3 -c "
import json, sys
with open('$TMPFILE') as f:
    sd = json.load(f)
projects = sd.setdefault('projects', {})
if '$PROJECT' in projects:
    projects['$PROJECT']['context'] = '''$CONTEXT'''
else:
    projects['$PROJECT'] = {
        'name': '$PROJECT',
        'description': '',
        'context': '''$CONTEXT''',
        'systemPrompt': ''
    }
with open('$TMPFILE', 'w') as f:
    json.dump(sd, f)
"
    NEW_SD=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    put_static_data "$NEW_SD"
    echo "Pushed context for project: $PROJECT"
    ;;

  add-project)
    KEY="$2"
    NAME="$3"
    if [ -z "$KEY" ] || [ -z "$NAME" ]; then
      echo "Usage: $0 add-project <key> <display-name>"
      exit 1
    fi
    TMPFILE=$(mktemp)
    get_static_data > "$TMPFILE"
    python3 -c "
import json
with open('$TMPFILE') as f:
    sd = json.load(f)
projects = sd.setdefault('projects', {})
if '$KEY' in projects:
    print('Project $KEY already exists: ' + projects['$KEY']['name'])
else:
    projects['$KEY'] = {
        'name': '$NAME',
        'description': '',
        'context': '',
        'systemPrompt': ''
    }
    sd.setdefault('conversations', {})['$KEY'] = []
    print('Created project: $NAME ($KEY)')
with open('$TMPFILE', 'w') as f:
    json.dump(sd, f)
"
    NEW_SD=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    put_static_data "$NEW_SD"
    ;;

  dump)
    get_static_data | python3 -m json.tool
    ;;

  get-field)
    FIELD="$2"
    if [ -z "$FIELD" ]; then
      echo "Usage: $0 get-field <field>"
      echo "Fields: projects, conversations, userProjects, userState, lastActivity"
      exit 1
    fi
    get_static_data | python3 -c "
import sys, json
sd = json.load(sys.stdin)
data = sd.get('$FIELD')
if data is None:
    print('Field not found: $FIELD')
else:
    print(json.dumps(data, indent=2))
"
    ;;

  *)
    echo "Chao Bridge - sync data between Claude Code and Chao bot"
    echo ""
    echo "Usage:"
    echo "  $0 list-projects              List all projects and their status"
    echo "  $0 read-conv <project>         Read conversation history (truncated)"
    echo "  $0 read-conv-full <project>    Read full conversation history (JSON)"
    echo "  $0 push-context <project>      Push project context (pipe or type text)"
    echo "  $0 add-project <key> <name>    Create a new project"
    echo "  $0 dump                        Dump all raw static data"
    echo "  $0 get-field <field>           Get a specific field from static data"
    echo ""
    echo "Examples:"
    echo "  $0 list-projects"
    echo "  $0 read-conv n8n-setup"
    echo "  echo 'New context info' | $0 push-context n8n-setup"
    echo "  $0 add-project trading 'Day Trading'"
    ;;
esac
