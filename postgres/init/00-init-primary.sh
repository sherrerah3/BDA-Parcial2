#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replpass';
  CREATE ROLE fleet_app WITH LOGIN PASSWORD 'fleetpass';
  GRANT CONNECT ON DATABASE fleetdb TO fleet_app;
EOSQL
