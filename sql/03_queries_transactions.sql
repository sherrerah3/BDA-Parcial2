\timing on

-- 1) Evidencia de particionamiento: pruning por rango de fechas (solo febrero)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  e.vehiculo_id,
  ROUND(AVG(e.velocidad_kmh), 2) AS velocidad_promedio,
  COUNT(*) AS total_eventos
FROM evento_telemetria e
WHERE e.fecha_evento >= '2026-02-01 00:00:00+00'
  AND e.fecha_evento <  '2026-03-01 00:00:00+00'
GROUP BY e.vehiculo_id
ORDER BY velocidad_promedio DESC
LIMIT 10;

-- 2) Consulta analitica por ruta para frenados bruscos
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  r.nombre AS ruta,
  COUNT(*) FILTER (WHERE e.frenado_brusco) AS frenados_bruscos,
  ROUND(100.0 * COUNT(*) FILTER (WHERE e.frenado_brusco) / NULLIF(COUNT(*), 0), 2) AS pct_frenado
FROM evento_telemetria e
JOIN ruta r ON r.ruta_id = e.ruta_id
WHERE e.fecha_evento >= '2026-03-01 00:00:00+00'
  AND e.fecha_evento <  '2026-04-01 00:00:00+00'
GROUP BY r.nombre
ORDER BY frenados_bruscos DESC
LIMIT 5;

-- 3) Transaccion de negocio: detectar riesgo, abrir mantenimiento y marcar vehiculo
BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;

WITH vehiculo_objetivo AS (
  SELECT e.vehiculo_id
  FROM evento_telemetria e
  WHERE e.fecha_evento >= '2026-03-15 00:00:00+00'
    AND e.fecha_evento <  '2026-03-16 00:00:00+00'
  GROUP BY e.vehiculo_id
  ORDER BY COUNT(*) FILTER (WHERE e.frenado_brusco) DESC
  LIMIT 1
)
INSERT INTO mantenimiento (vehiculo_id, tipo, fecha_programada, estado, observacion)
SELECT
  v.vehiculo_id,
  'INSPECCION_SEGURIDAD',
  CURRENT_DATE + 1,
  'PENDIENTE',
  'Generado por alta frecuencia de frenados bruscos en telemetria'
FROM vehiculo_objetivo v;

WITH ultimo_mantenimiento AS (
  SELECT m.vehiculo_id
  FROM mantenimiento m
  WHERE m.tipo = 'INSPECCION_SEGURIDAD'
  ORDER BY m.mantenimiento_id DESC
  LIMIT 1
)
UPDATE vehiculo ve
SET estado = 'REVISION_PRIORITARIA'
FROM ultimo_mantenimiento um
WHERE ve.vehiculo_id = um.vehiculo_id;

WITH ultimo_mantenimiento AS (
  SELECT m.vehiculo_id
  FROM mantenimiento m
  WHERE m.tipo = 'INSPECCION_SEGURIDAD'
  ORDER BY m.mantenimiento_id DESC
  LIMIT 1
)
INSERT INTO evento_telemetria (
  vehiculo_id,
  ruta_id,
  region_id,
  fecha_evento,
  latitud,
  longitud,
  velocidad_kmh,
  frenado_brusco,
  combustible_pct,
  odometro_km
)
SELECT
  um.vehiculo_id,
  1,
  2,
  NOW(),
  -4.650000,
  -74.090000,
  0,
  FALSE,
  55,
  15000
FROM ultimo_mantenimiento um;

COMMIT;

-- 4) Validacion post-transaccion
SELECT vehiculo_id, estado
FROM vehiculo
WHERE estado = 'REVISION_PRIORITARIA'
ORDER BY vehiculo_id DESC
LIMIT 5;

SELECT mantenimiento_id, vehiculo_id, tipo, estado, fecha_programada
FROM mantenimiento
WHERE tipo = 'INSPECCION_SEGURIDAD'
ORDER BY mantenimiento_id DESC
LIMIT 5;

-- 5) Ver distribucion por particion para evidencias
SELECT
  tableoid::regclass AS particion,
  COUNT(*) AS total
FROM evento_telemetria
GROUP BY tableoid
ORDER BY total DESC;
