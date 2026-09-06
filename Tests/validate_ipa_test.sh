#!/usr/bin/env bash
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/validate_ipa.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/empty/Payload"; (cd "$tmp/empty" && zip -qry "$tmp/empty.ipa" Payload)
if "$script" "$tmp/empty.ipa" "$tmp/report" 2>/dev/null; then echo 'empty archive was accepted' >&2; exit 1; fi
echo 'validator rejects empty/undersized archive'
