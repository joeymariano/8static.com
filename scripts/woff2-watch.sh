#!/usr/bin/env bash
# Passive watcher for css/VT323.woff2 (the file that got UTF-8-mangled once
# already). On every modification, append integrity + process snapshot to
# ~/Library/Logs/8static-woff2.log so you can correlate any future corruption
# with what was running at the time.
#
# Usage:
#   ./scripts/woff2-watch.sh             # one-shot: log current state
#   ./scripts/woff2-watch.sh --install   # set up the launchd watcher
#   ./scripts/woff2-watch.sh --uninstall # tear down the launchd watcher
#   ./scripts/woff2-watch.sh --tail      # tail the log

set -u

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
# WOFF2_WATCH_FILE env var (set by the installed plist) takes precedence so
# the installed copy in ~/Library/Application Support/ still points at the
# real file in the repo. Falls back to repo-relative path for manual runs.
WATCH_FILE="${WOFF2_WATCH_FILE:-$REPO_ROOT/css/VT323.woff2}"
LOG="$HOME/Library/Logs/8static-woff2.log"
PLIST_LABEL="com.joeymariano.8static.woff2-watch"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

# macOS TCC blocks launchd from executing scripts under ~/Documents (and from
# reading files there) without Full Disk Access. We sidestep that by copying
# the script into ~/Library/Application Support/ (not TCC-protected) at install
# time. The watched file path may still need FDA — see install_watcher().
INSTALLED_SCRIPT_DIR="$HOME/Library/Application Support/8static-woff2-watch"
INSTALLED_SCRIPT="$INSTALLED_SCRIPT_DIR/woff2-watch.sh"

log_event() {
  mkdir -p "$(dirname "$LOG")"
  {
    printf -- '===== %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    if [[ -f "$WATCH_FILE" ]]; then
      printf 'path:   %s\n' "$WATCH_FILE"
      printf 'size:   %s bytes\n' "$(/usr/bin/stat -f %z "$WATCH_FILE")"
      printf 'mtime:  %s\n' "$(/usr/bin/stat -f '%Sm' "$WATCH_FILE")"

      # Try to read the contents for sha256 + woff2 validation. If launchd is
      # blocked by macOS TCC from reading inside ~/Documents (the common case
      # without Full Disk Access), this gracefully falls back to a notice.
      if SHA_OUT="$(/usr/bin/shasum -a 256 "$WATCH_FILE" 2>&1)"; then
        printf 'sha256: %s\n' "$(echo "$SHA_OUT" | awk '{print $1}')"
        /usr/bin/python3 - "$WATCH_FILE" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
sig = d[0:4]
if sig != b'wOF2':
    print(f"  X INVALID: signature={sig!r} (not a woff2)")
else:
    header_len = struct.unpack('>I', d[8:12])[0]
    if header_len != len(d):
        print(f"  X CORRUPT: header length {header_len} != file size {len(d)}")
        print(f"    looks like UTF-8 lossy re-encoding; replace from fonts.gstatic.com")
    else:
        print(f"  OK valid (header length {header_len} matches file size)")
PY
      else
        echo "sha256: (TCC blocked: $(echo "$SHA_OUT" | head -1))"
        echo "  ! cannot read file contents from launchd context."
        echo "  ! grant Full Disk Access to /bin/bash in System Settings"
        echo "  ! (Privacy & Security > Full Disk Access > + > /bin/bash)"
        echo "  ! the metadata + process snapshot below is still useful for forensics."
      fi
    else
      echo "MISSING: $WATCH_FILE"
    fi
    echo ""
    echo "-- open handles on the file right now --"
    /usr/sbin/lsof -- "$WATCH_FILE" 2>/dev/null | sed 's/^/  /' || true
    [[ -z "$(/usr/sbin/lsof -- "$WATCH_FILE" 2>/dev/null)" ]] && echo "  (no open handles)"
    echo ""
    echo "-- candidate apps running now (editors, browsers, finder, terminal, etc.) --"
    # Filter to apps that could plausibly open/write a binary file.
    # Drops system widget extensions, helpers, framework agents, etc.
    /bin/ps -A -o comm | \
      grep -E '\.app/Contents/MacOS/' | \
      grep -v -E '(WidgetExtension|Widget\.appex|\.appex/|Helper|helper|Service|Agent|Extension|crashpad)' | \
      sort -u | \
      sed 's|.*/||' | \
      sort -u | \
      sed 's/^/  /'
    echo ""
  } >> "$LOG"
}

install_watcher() {
  mkdir -p "$(dirname "$PLIST_PATH")" "$(dirname "$LOG")" "$INSTALLED_SCRIPT_DIR"

  # Copy the script out of ~/Documents so launchd can execute it
  cp "$SCRIPT_PATH" "$INSTALLED_SCRIPT"
  chmod +x "$INSTALLED_SCRIPT"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${INSTALLED_SCRIPT}</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>WOFF2_WATCH_FILE</key>
    <string>${WATCH_FILE}</string>
  </dict>

  <key>WatchPaths</key>
  <array>
    <string>${WATCH_FILE}</string>
  </array>

  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/8static-woff2-launchd.log</string>

  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/8static-woff2-launchd.log</string>
</dict>
</plist>
EOF

  # Unload first in case an older version was loaded
  /bin/launchctl unload "$PLIST_PATH" 2>/dev/null || true
  /bin/launchctl load "$PLIST_PATH"

  echo "installed:"
  echo "  plist:           $PLIST_PATH"
  echo "  installed script: $INSTALLED_SCRIPT"
  echo "  source script:    $SCRIPT_PATH"
  echo "  watch:            $WATCH_FILE"
  echo "  log:              $LOG"
  echo ""
  echo "NOTE: if logs show 'Operation not permitted', grant Full Disk Access to bash:"
  echo "  System Settings -> Privacy & Security -> Full Disk Access -> add /bin/bash"
  echo ""
  echo "If you ever edit the script, re-run --install to copy the new version."
  echo "Tail the log with:  ./scripts/woff2-watch.sh --tail"
}

uninstall_watcher() {
  if [[ -f "$PLIST_PATH" ]]; then
    /bin/launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    rm -rf "$INSTALLED_SCRIPT_DIR"
    echo "uninstalled (plist + installed script removed and unloaded)"
  else
    echo "nothing to uninstall (plist not present at $PLIST_PATH)"
  fi
}

case "${1:-}" in
  --install)   install_watcher ;;
  --uninstall) uninstall_watcher ;;
  --tail)      tail -f "$LOG" ;;
  "")          log_event; echo "logged a snapshot to $LOG" ;;
  *)           echo "unknown flag: $1" >&2; exit 1 ;;
esac
