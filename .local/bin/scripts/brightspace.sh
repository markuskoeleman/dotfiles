#!/usr/bin/env bash
set -euo pipefail

: "${BRIGHTSPACE_ICS_URL:?BRIGHTSPACE_ICS_URL is not set}"

ICS_URL="$BRIGHTSPACE_ICS_URL"
PROJECT="brightspace"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

ICS_FILE="$(mktemp)"
TASKS_FILE="$(mktemp)"

trap 'rm -f "$ICS_FILE" "$TASKS_FILE"' EXIT

echo "Downloading Brightspace calendar..."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "$ICS_URL" \
    --output "$ICS_FILE"


# Export ALL Taskwarrior tasks, including completed ones.
task export > "$TASKS_FILE"

python3 "$SCRIPT_DIR/brightspaceICS.py" "$ICS_FILE" "$TASKS_FILE" "$PROJECT"
