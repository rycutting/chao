#!/bin/bash
# Chao Project Sync Script
# Usage:
#   ./sync-projects.sh push <project-name> <context-text>
#   ./sync-projects.sh pull <project-name>
#   ./sync-projects.sh list
#   ./sync-projects.sh pull-conv <project-name>

CHAO_API="https://n8n.srv1363974.hstgr.cloud/webhook/chao-files"

case "$1" in
  push)
    PROJECT="$2"
    CONTEXT="$3"
    if [ -z "$PROJECT" ] || [ -z "$CONTEXT" ]; then
      echo "Usage: $0 push <project-name> <context>"
      exit 1
    fi
    # Read existing project
    EXISTING=$(curl -s -X POST "$CHAO_API" -H "Content-Type: application/json" \
      -d "{\"action\":\"read\",\"key\":\"project:$PROJECT\"}")

    # Update context in existing project or create new
    RESULT=$(echo "$EXISTING" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('success'):
        proj = json.loads(data['result'])
        proj['context'] = '''$CONTEXT'''
    else:
        proj = {'name': '$PROJECT', 'description': '', 'context': '''$CONTEXT''', 'systemPrompt': ''}
    print(json.dumps(proj))
except:
    proj = {'name': '$PROJECT', 'description': '', 'context': '''$CONTEXT''', 'systemPrompt': ''}
    print(json.dumps(proj))
")

    curl -s -X POST "$CHAO_API" -H "Content-Type: application/json" \
      -d "{\"action\":\"write\",\"key\":\"project:$PROJECT\",\"value\":$(echo "$RESULT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")}"
    echo ""
    echo "Pushed context for project: $PROJECT"
    ;;

  pull)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 pull <project-name>"
      exit 1
    fi
    curl -s -X POST "$CHAO_API" -H "Content-Type: application/json" \
      -d "{\"action\":\"read\",\"key\":\"project:$PROJECT\"}" | python3 -m json.tool
    ;;

  list)
    curl -s -X POST "$CHAO_API" -H "Content-Type: application/json" \
      -d '{"action":"list","key":"project:"}' | python3 -m json.tool
    ;;

  pull-conv)
    PROJECT="$2"
    if [ -z "$PROJECT" ]; then
      echo "Usage: $0 pull-conv <project-name>"
      exit 1
    fi
    curl -s -X POST "$CHAO_API" -H "Content-Type: application/json" \
      -d "{\"action\":\"read\",\"key\":\"conv:$PROJECT\"}" | python3 -m json.tool
    ;;

  *)
    echo "Chao Project Sync"
    echo "Usage:"
    echo "  $0 push <project-name> <context>    Push project context"
    echo "  $0 pull <project-name>              Pull project data"
    echo "  $0 list                             List all projects"
    echo "  $0 pull-conv <project-name>         Pull conversation history"
    ;;
esac
