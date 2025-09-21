
#!/usr/bin/env bash
set -Eeuo pipefail

# ---- settings ----
BOX_WIDTH=${BOX_WIDTH:-120}
BOX_HEIGHT=${BOX_HEIGHT:-35}
LOG_FILE=${LOG_FILE:-/tmp/premig_live.log}

# ensure file exists
: >"$LOG_FILE"

# cleanup
cleanup() {
  exec 1>&3 2>&4 || true
  [[ -n "${PAGER_PID:-}" ]] && kill "$PAGER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# check terminal large enough; if not, shrink box
cols=$(tput cols || echo 80); lines=$(tput lines || echo 24)
(( BOX_WIDTH > cols )) && BOX_WIDTH=$cols
(( BOX_HEIGHT > (lines-2) )) && BOX_HEIGHT=$((lines-2))

# start the pager reading the log (never blocks writers)
# -n +1 shows the whole file from the start
# -F follows across rotations
tail -n +1 -F "$LOG_FILE" \
  | gum pager --border rounded --width "$BOX_WIDTH" --height "$BOX_HEIGHT" \
              --soft-wrap --show-line-numbers &
PAGER_PID=$!

# keep original TTY fds for prompts
exec 3>&1 4>&2

# send all output to log file (writers never block)
# if you want to SEE output also in terminal, swap for: exec 1> >(tee -a "$LOG_FILE") 2>&1
exec 1>>"$LOG_FILE" 2>&1

# ---------- helpers ----------
with_tty() {  # run commands interactively on real TTY (not in pager)
  ( exec 1>&3 2>&4; "$@" )
}
log() { printf "[%(%F %T)T] %s\n" -1 "$*"; }  # simple timestamped log line

# reduce buffering for some tools (optional)
export PYTHONUNBUFFERED=1
export STDOUT_LINE_BUFFERED=1

# ---------- your logic ----------
log "Premig Testsuite started"
/mount/sa4zdmfs/zdmconfig/dev/premigration/scripts/premig_login.sh


