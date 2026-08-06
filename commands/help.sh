#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/../lib/common.sh"

print_header "Workstation Help"

cat << EOF

Usage:

  platform doctor
  platform health <platform>

  platform start <platform>
  platform stop <platform>
  platform restart <platform>

  platform status <platform>

  platform logs <container>

  platform update <platform>

  platform version

  platform info <platform>

Examples:

  platform health operations
  platform start ai
  platform logs homepage
  platform status database
  platform info operations

EOF
