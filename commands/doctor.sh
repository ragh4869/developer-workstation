#!/usr/bin/env bash

# ============================================================
# Workstation - Platform Doctor
# Command orchestration
# ============================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ============================================================
# Arguments
# ============================================================

PLATFORM="${1:-}"

# ============================================================
# Header
# ============================================================

print_header "Platform Doctor"

# ============================================================
# Validate platform argument
# ============================================================

if [[ -z "$PLATFORM" ]]; then
    printf 'Platform : All\n\n'
    printf '✗ Platform is required.\n'
    printf '\nUsage:\n'
    printf '  platform doctor <platform>\n'
    printf '\nExample:\n'
    printf '  platform doctor database\n'
    exit 1
fi

printf 'Platform : %s\n' "$PLATFORM"
printf '\n'

# ============================================================
# Run doctor
# ============================================================

doctor_platform "$PLATFORM"

exit $?
