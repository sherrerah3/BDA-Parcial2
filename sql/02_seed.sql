-- Carga de datos realistas para flota de transporte

INSERT INTO region (nombre)
VALUES
  ('NORTE'),
  ('CENTRO'),
  ('SUR'),
  ('ORIENTE'),
  ('OCCIDENTE');

INSERT INTO ruta (nombre, region_id, distancia_km)
VALUES
  ('RUTA N1 INTERMUNICIPAL', 1, 240.5),
  ('RUTA N2 MONTAÑA', 1, 180.2),
  ('RUTA C1 URBANA', 2, 35.8),
  ('RUTA C2 URBANA NOCTURNA', 2, 42.4),
  ('RUTA S1 CARGA PESADA', 3, 310.0),
  ('RUTA S2 CARGA MIXTA', 3, 275.7),
  ('RUTA O1 FRONTERA', 4, 460.9),
  ('RUTA O2 LOGISTICA', 4, 390.3),
  ('RUTA W1 COSTERA', 5, 220.1),
  ('RUTA W2 PUERTOS', 5, 198.6),
  ('RUTA C3 TRONCAL', 2, 58.0),
  ('RUTA S3 REGIONAL', 3, 132.3);

INSERT INTO vehiculo (placa, tipo, capacidad_kg, estado, fecha_ingreso)
SELECT
  'FLT-' || LPAD(gs::TEXT, 4, '0'),
  CASE WHEN gs % 3 = 0 THEN 'BUS' ELSE 'CAMION' END,
  5000 + (gs * 120),
  'ACTIVO',
  DATE '2021-01-01' + ((gs * 3) % 1200)
FROM generate_series(1, 120) AS gs;

INSERT INTO conductor (documento, nombre_completo, categoria_licencia, fecha_vinculacion)
SELECT
  'CC' || LPAD(gs::TEXT, 8, '0'),
  'Conductor ' || gs,
  CASE WHEN gs % 2 = 0 THEN 'C2' ELSE 'C3' END,
  DATE '2020-06-01' + ((gs * 7) % 1600)
FROM generate_series(1, 90) AS gs;

INSERT INTO asignacion_vehiculo_conductor (vehiculo_id, conductor_id, fecha_desde, fecha_hasta)
SELECT
  v.vehiculo_id,
  ((v.vehiculo_id - 1) % 90) + 1,
  DATE '2025-01-01' + (((v.vehiculo_id * 2) % 320)::INT),
  NULL
FROM vehiculo v;

INSERT INTO mantenimiento (vehiculo_id, tipo, fecha_programada, fecha_ejecucion, costo, estado, observacion)
SELECT
  ((gs - 1) % 120) + 1,
  CASE
    WHEN gs % 4 = 0 THEN 'CAMBIO_FRENOS'
    WHEN gs % 4 = 1 THEN 'CAMBIO_ACEITE'
    WHEN gs % 4 = 2 THEN 'REVISION_ELECTRICA'
    ELSE 'ALINEACION_BALANCEO'
  END,
  DATE '2026-01-01' + (gs % 120),
  CASE WHEN gs % 5 = 0 THEN DATE '2026-01-01' + ((gs + 1) % 120) ELSE NULL END,
  ROUND((250000 + random() * 900000)::NUMERIC, 2),
  CASE WHEN gs % 5 = 0 THEN 'EJECUTADO' ELSE 'PENDIENTE' END,
  'Orden generada por kilometraje y telemetria'
FROM generate_series(1, 300) AS gs;

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
  ((EXTRACT(EPOCH FROM fecha_evento)::BIGINT % 120) + 1) AS vehiculo_id,
  ((EXTRACT(EPOCH FROM fecha_evento)::BIGINT % 12) + 1) AS ruta_id,
  ((EXTRACT(EPOCH FROM fecha_evento)::BIGINT % 5) + 1) AS region_id,
  fecha_evento,
  ROUND((-4.900000 + random() * 2.000000)::NUMERIC, 6) AS latitud,
  ROUND((-74.200000 + random() * 2.000000)::NUMERIC, 6) AS longitud,
  ROUND((45 + random() * 55 + 15 * sin(EXTRACT(EPOCH FROM fecha_evento) / 3600.0))::NUMERIC, 2) AS velocidad_kmh,
  (random() < 0.07) AS frenado_brusco,
  ROUND((15 + random() * 85)::NUMERIC, 2) AS combustible_pct,
  ROUND((10000 + EXTRACT(EPOCH FROM fecha_evento) / 3600.0 * 52 + random() * 12)::NUMERIC, 2) AS odometro_km
FROM generate_series(
  '2026-01-01 00:00:00+00'::TIMESTAMPTZ,
  '2026-03-31 23:59:00+00'::TIMESTAMPTZ,
  INTERVAL '1 minute'
) AS fecha_evento;

ANALYZE;
