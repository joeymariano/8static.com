#!/usr/bin/env bash
# Build the Jekyll site and mirror _site/ to the SFTP host defined in .env.
# Usage:  ./deploy.sh           (build + upload)
#         ./deploy.sh --no-build (skip jekyll build, just upload existing _site/)
#         ./deploy.sh --dry-run  (show what lftp would do, don't transfer)
#
# Requires: lftp  (brew install lftp)
# Credentials come from .env (gitignored). See .env.example.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# --- Load .env -------------------------------------------------------------
if [[ ! -f .env ]]; then
  echo "error: .env not found. Copy .env.example to .env and fill in your SFTP credentials." >&2
  exit 1
fi
# shellcheck disable=SC1091
set -a; source .env; set +a

: "${SFTP_HOST:?SFTP_HOST not set in .env}"
: "${SFTP_USER:?SFTP_USER not set in .env}"
: "${SFTP_PASS:?SFTP_PASS not set in .env}"
: "${SFTP_REMOTE_PATH:?SFTP_REMOTE_PATH not set in .env}"
SFTP_PORT="${SFTP_PORT:-22}"

# --- Check lftp ------------------------------------------------------------
if ! command -v lftp >/dev/null 2>&1; then
  echo "error: lftp is not installed. Install it with:  brew install lftp" >&2
  exit 1
fi

# --- Parse flags -----------------------------------------------------------
BUILD=1
DRY_RUN=""
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --dry-run)  DRY_RUN="--dry-run" ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# --- Pre-flight binary integrity checks ------------------------------------
# Catches the corrupt-VT323.woff2 class of bug (UTF-8 lossy re-encoding
# from a text editor / quick look / errant script) before it ships.
# Add more (path, validator) entries below as needed.

check_woff2() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ missing: $path" >&2
    return 1
  fi
  python3 - "$path" <<'PY'
import struct, sys
p = sys.argv[1]
d = open(p,'rb').read()
sig = d[0:4]
if sig != b'wOF2':
    print(f"  ✗ {p}: not a woff2 file (signature={sig!r})", file=sys.stderr)
    sys.exit(1)
header_len = struct.unpack('>I', d[8:12])[0]
if header_len != len(d):
    print(f"  ✗ {p}: header length {header_len} != file size {len(d)} — file is corrupted", file=sys.stderr)
    print(f"    likely a UTF-8 lossy re-encoding (text editor opened the binary?)", file=sys.stderr)
    print(f"    grab a fresh copy from fonts.gstatic.com — see scripts notes.", file=sys.stderr)
    sys.exit(1)
print(f"  ✓ {p} ({len(d)} bytes, woff2 header ok)")
PY
}

echo "==> integrity check"
check_woff2 css/VT323.woff2 || { echo "==> aborting deploy" >&2; exit 1; }

# --- Build -----------------------------------------------------------------
if [[ "$BUILD" -eq 1 ]]; then
  echo "==> bundle exec jekyll build"
  bundle exec jekyll build
fi

if [[ ! -d _site ]]; then
  echo "error: _site/ does not exist. Run without --no-build, or run 'bundle exec jekyll build' first." >&2
  exit 1
fi

# --- Upload ----------------------------------------------------------------
echo "==> mirroring _site/ -> sftp://${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}${SFTP_REMOTE_PATH}"
[[ -n "$DRY_RUN" ]] && echo "    (dry run — no files will be transferred)"

# mirror -R    = reverse mirror (upload local -> remote)
# --delete     = remove remote files that no longer exist locally
# --parallel=4 = 4 concurrent transfers
# --exclude-glob .DS_Store = never upload macOS junk
#
# Output is piped through sed to redact any //user:pass@ patterns lftp prints
# in verbose/dry-run mode, so credentials never reach the terminal or logs.
lftp -u "${SFTP_USER},${SFTP_PASS}" -p "${SFTP_PORT}" "sftp://${SFTP_HOST}" <<EOF 2>&1 | sed -E 's#//[^:/@]+:[^@]+@#//***:***@#g'
set sftp:auto-confirm yes
set ssl:verify-certificate no
mirror -R ${DRY_RUN} --delete --parallel=4 --exclude-glob .DS_Store --verbose _site/ ${SFTP_REMOTE_PATH}
bye
EOF

echo "==> done"
