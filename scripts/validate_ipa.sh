#!/usr/bin/env bash
set -euo pipefail

ipa=${1:?usage: validate_ipa.sh path/to/DJIwphone.ipa [report]}
report=${2:-ipa-validation.txt}
min_ipa_bytes=${MIN_IPA_BYTES:-1048576}
min_exec_bytes=${MIN_EXEC_BYTES:-65536}
expected_bundle=${EXPECTED_BUNDLE_ID:-com.kevin2xiaomao.qdc507communication}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

[[ -f "$ipa" ]] || { echo "IPA missing: $ipa" >&2; exit 1; }
ipa_bytes=$(stat -f %z "$ipa")
(( ipa_bytes >= min_ipa_bytes )) || { echo "IPA too small: $ipa_bytes bytes" >&2; exit 1; }
unzip -q -t "$ipa" >/dev/null
unzip -q "$ipa" -d "$tmp/unpacked"
apps=()
while IFS= read -r app_path; do apps+=("$app_path"); done < <(find "$tmp/unpacked/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print)
(( ${#apps[@]} == 1 )) || { echo "expected exactly one Payload app, found ${#apps[@]}" >&2; exit 1; }
app=${apps[0]}
[[ "$(basename "$app")" == "DJIwphone.app" ]] || { echo "wrong app name: $(basename "$app")" >&2; exit 1; }
plist="$app/Info.plist"
[[ -f "$plist" ]] || { echo "Info.plist missing" >&2; exit 1; }
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
[[ "$bundle" == "$expected_bundle" ]] || { echo "wrong Bundle ID: $bundle" >&2; exit 1; }
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
[[ -n "$executable" && -f "$app/$executable" ]] || { echo "main executable missing" >&2; exit 1; }
exec_path="$app/$executable"
exec_bytes=$(stat -f %z "$exec_path")
(( exec_bytes >= min_exec_bytes )) || { echo "main executable too small: $exec_bytes bytes" >&2; exit 1; }
[[ -x "$exec_path" ]] || { echo "main executable is not executable" >&2; exit 1; }
file_info=$(file "$exec_path")
[[ "$file_info" == *"Mach-O"* && "$file_info" == *"arm64"* ]] || { echo "main executable is not arm64 Mach-O: $file_info" >&2; exit 1; }

framework_dir="$app/Frameworks"
otool_info=$(otool -L "$exec_path")
while IFS= read -r dependency; do
  [[ -z "$dependency" ]] && continue
  case "$dependency" in
    /System/Library/*|/usr/lib/*|"$exec_path":*) continue ;;
    @rpath/*)
      framework_name=${dependency#@rpath/}; framework_name=${framework_name%% *}
      [[ -e "$framework_dir/$framework_name" ]] || { echo "unresolved @rpath dependency: $framework_name" >&2; exit 1; } ;;
    *) echo "unexpected external dependency: $dependency" >&2; exit 1 ;;
  esac
done < <(printf '%s\n' "$otool_info" | tail -n +2 | sed 's/^[[:space:]]*//' | sed 's/ (.*$//')

{
  echo "ipa=$ipa"
  echo "ipa_bytes=$ipa_bytes"
  echo "app=$app"
  echo "bundle_id=$bundle"
  echo "executable=$executable"
  echo "executable_bytes=$exec_bytes"
  echo "file=$file_info"
  echo "frameworks="
  find "$framework_dir" -maxdepth 1 -mindepth 1 -print 2>/dev/null | sort || true
  echo "otool="
  printf '%s\n' "$otool_info"
  echo "archive="
  unzip -l "$ipa"
} > "$report"
echo "IPA validation passed: $ipa_bytes bytes, $bundle, $exec_bytes-byte arm64 Mach-O"
