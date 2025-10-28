#!/usr/bin/env bash
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if present
ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
  echo "✓ Loaded environment from $ENV_FILE"
else
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

# Validate required variables
if [ -z "${ACTIVE_POOL:-}" ]; then
  echo "ERROR: ACTIVE_POOL not set in .env"
  exit 1
fi

if [ "$ACTIVE_POOL" != "blue" ] && [ "$ACTIVE_POOL" != "green" ]; then
  echo "ERROR: ACTIVE_POOL must be 'blue' or 'green', got: $ACTIVE_POOL"
  exit 1
fi

# Generate upstream entries based on active pool
# Active pool is primary, inactive pool is backup (only used if primary fails)
if [ "$ACTIVE_POOL" = "blue" ]; then
  UPSTREAM_ENTRIES="server app_blue:8081 max_fails=2 fail_timeout=5s;
        server app_green:8082 backup;"
  echo "✓ Active pool: BLUE (primary)"
  echo "  - app_blue:8081 (active)"
  echo "  - app_green:8082 (backup)"
else
  UPSTREAM_ENTRIES="server app_green:8082 max_fails=2 fail_timeout=5s;
        server app_blue:8081 backup;"
  echo "✓ Active pool: GREEN (primary)"
  echo "  - app_green:8082 (active)"
  echo "  - app_blue:8081 (backup)"
fi

export UPSTREAM_ENTRIES

# File paths
TEMPLATE_FILE="${SCRIPT_DIR}/nginx.conf.template"
OUTPUT_FILE="${SCRIPT_DIR}/nginx.conf"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "ERROR: Template file not found at $TEMPLATE_FILE"
  exit 1
fi

# Generate nginx.conf from template
# Only substitute UPSTREAM_ENTRIES to preserve nginx variables like $host, $remote_addr
envsubst '${UPSTREAM_ENTRIES}' < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "✓ Generated $OUTPUT_FILE"
echo ""
echo "Upstream configuration:"
echo "$UPSTREAM_ENTRIES"
