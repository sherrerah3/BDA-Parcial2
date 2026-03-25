#!/usr/bin/env bash
set -euo pipefail

PRIMARY_HOST="${1:-postgres-primary}"
PRIMARY_PORT="${2:-5432}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  exec gosu postgres "$0" "$@"
fi

export PGPASSWORD="${REPL_PASSWORD:-replpass}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "[replica] Waiting for primary at ${PRIMARY_HOST}:${PRIMARY_PORT} ..."
  until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U postgres; do
    sleep 2
  done

  echo "[replica] Cleaning data directory ..."
  rm -rf "${PGDATA:?}"/*

  echo "[replica] Running pg_basebackup ..."
  pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p "$PRIMARY_PORT" \
    -U replicator \
    -D "$PGDATA" \
    -R \
    -X stream \
    -P

  chmod 700 "$PGDATA"
fi

exec postgres -c config_file=/etc/postgresql/postgresql.conf -c hba_file=/etc/postgresql/pg_hba.conf
