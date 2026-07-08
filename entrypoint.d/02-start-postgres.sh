#!/bin/bash
# Start PostgreSQL database
PG_BIN="/usr/lib/postgresql/current/bin"
PGDATA="/opt/polarion/data/postgres-data"
PG_PORT=5433
PG_SOCKET_DIR="/var/run/postgresql"

start_postgres() {
	sudo -u postgres "${PG_BIN}/pg_ctl" -D "$PGDATA" -l "$PGDATA/log.out" -o "-p ${PG_PORT}" start
}

if ! start_postgres; then
	if sudo -u postgres "${PG_BIN}/pg_isready" -h "$PG_SOCKET_DIR" -p "$PG_PORT" >/dev/null 2>&1; then
		echo "PostgreSQL is already running."
	else
		echo "PostgreSQL failed to start; removing stale socket/lock files from an unclean shutdown..."
		rm -f "${PG_SOCKET_DIR}"/.s.PGSQL."${PG_PORT}"*
		start_postgres || { echo "FATAL: PostgreSQL still failed to start after cleanup." >&2; exit 1; }
	fi
fi
