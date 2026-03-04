#!/bin/bash
# Block TaskCreate/TodoWrite, suggest beads instead
# This hook is only triggered for matched tools (TaskCreate, TodoWrite)

cat << 'EOF'
{"decision": "block", "reason": "Use bd (beads) instead. Commands: bd create --title=\"task\" --priority=2, bd ready, bd close <id>"}
EOF
