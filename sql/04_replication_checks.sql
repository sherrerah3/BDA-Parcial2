-- Ejecutar primero en PRIMARY (puerto 5432)
SELECT
  application_name,
  client_addr,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  COALESCE(write_lag, '0 seconds'::interval) AS write_lag,
  COALESCE(replay_lag, '0 seconds'::interval) AS replay_lag
FROM pg_stat_replication;

-- Ejecutar en cada REPLICA (puerto 5433 y 5434)
SELECT
  pg_is_in_recovery() AS es_replic;

SELECT
  now() - pg_last_xact_replay_timestamp() AS retraso_replay;

-- Verificacion de datos replicados en replicas
SELECT COUNT(*) AS total_eventos FROM evento_telemetria;
SELECT COUNT(*) AS total_mantenimientos FROM mantenimiento;
