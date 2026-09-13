#!/usr/bin/env bash
# Run mini-eats against a local SQLite file, or stop it.
#   ./serve.sh up | down | status
# Detached with setsid so it survives the launching shell. The WAL store must
# live on a native Linux filesystem for a WSL reader to memory-map it -- set
# MINI_EATS_DB to a /tmp path.
set -euo pipefail
cd "$(dirname "$0")"
PORT="${MINI_EATS_PORT:-8130}"
export MINI_EATS_PORT="${PORT}"
LOG="${MINI_EATS_LOG:-/tmp/mini-eats-${PORT}.log}"
PIDFILE="/tmp/mini-eats-${PORT}.pid"
free_port() {
  # Kill whatever still holds the port, however it was launched. A stale server
  # left on this port keeps answering, so a fresh bind that silently fails looks
  # "up" while serving an empty store -- turning every case into a spurious
  # Blocked. Freeing the port is the reliable guard.
  if command -v fuser >/dev/null 2>&1; then fuser -k "${PORT}/tcp" 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then lsof -ti tcp:"${PORT}" 2>/dev/null | xargs -r kill 2>/dev/null || true; fi
}
case "${1:-up}" in
  up)
    [ -f "${PIDFILE}" ] && kill "$(cat "${PIDFILE}")" 2>/dev/null || true
    pkill -f "mini-eats/server.js" 2>/dev/null || true
    free_port
    sleep 0.4
    if [ -n "${MINI_EATS_DB:-}" ]; then rm -f "${MINI_EATS_DB}" "${MINI_EATS_DB}-shm" "${MINI_EATS_DB}-wal" 2>/dev/null || true; else rm -rf ./data 2>/dev/null || true; fi
    setsid nohup node "$(pwd)/server.js" > "${LOG}" 2>&1 < /dev/null &
    echo $! > "${PIDFILE}"; disown || true
    for i in $(seq 1 40); do curl -sf "http://127.0.0.1:${PORT}/restaurants" >/dev/null 2>&1 && break; sleep 0.2; done
    curl -s "http://127.0.0.1:${PORT}/restaurants" >/dev/null && echo "mini-eats up on ${PORT} (db ${MINI_EATS_DB:-./data/mini-eats.db})" || { echo "did not come up"; cat "${LOG}"; exit 1; }
    ;;
  down) [ -f "${PIDFILE}" ] && kill "$(cat "${PIDFILE}")" 2>/dev/null || true; rm -f "${PIDFILE}"; echo "stopped" ;;
  status) curl -s "http://127.0.0.1:${PORT}/restaurants" && echo || echo "not running" ;;
  *) echo "usage: $0 up|down|status" >&2; exit 2 ;;
esac
