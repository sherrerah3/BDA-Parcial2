-- Contexto: Plataforma de telemetria de flota (camiones/buses)
-- Dimension elegida para la evaluacion: Particionamiento + Replicacion

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

DROP TABLE IF EXISTS evento_telemetria CASCADE;
DROP TABLE IF EXISTS mantenimiento CASCADE;
DROP TABLE IF EXISTS asignacion_vehiculo_conductor CASCADE;
DROP TABLE IF EXISTS conductor CASCADE;
DROP TABLE IF EXISTS ruta CASCADE;
DROP TABLE IF EXISTS vehiculo CASCADE;
DROP TABLE IF EXISTS region CASCADE;

CREATE TABLE region (
  region_id SMALLSERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE vehiculo (
  vehiculo_id BIGSERIAL PRIMARY KEY,
  placa VARCHAR(12) NOT NULL UNIQUE,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('CAMION', 'BUS')),
  capacidad_kg INTEGER NOT NULL CHECK (capacidad_kg > 0),
  estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
  fecha_ingreso DATE NOT NULL
);

CREATE TABLE conductor (
  conductor_id BIGSERIAL PRIMARY KEY,
  documento VARCHAR(20) NOT NULL UNIQUE,
  nombre_completo VARCHAR(100) NOT NULL,
  categoria_licencia VARCHAR(10) NOT NULL,
  fecha_vinculacion DATE NOT NULL
);

CREATE TABLE ruta (
  ruta_id BIGSERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL,
  region_id SMALLINT NOT NULL REFERENCES region(region_id),
  distancia_km NUMERIC(8,2) NOT NULL CHECK (distancia_km > 0),
  activa BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE asignacion_vehiculo_conductor (
  asignacion_id BIGSERIAL PRIMARY KEY,
  vehiculo_id BIGINT NOT NULL REFERENCES vehiculo(vehiculo_id),
  conductor_id BIGINT NOT NULL REFERENCES conductor(conductor_id),
  fecha_desde DATE NOT NULL,
  fecha_hasta DATE,
  UNIQUE (vehiculo_id, conductor_id, fecha_desde),
  CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);

CREATE TABLE mantenimiento (
  mantenimiento_id BIGSERIAL PRIMARY KEY,
  vehiculo_id BIGINT NOT NULL REFERENCES vehiculo(vehiculo_id),
  tipo VARCHAR(40) NOT NULL,
  fecha_programada DATE NOT NULL,
  fecha_ejecucion DATE,
  costo NUMERIC(12,2),
  estado VARCHAR(20) NOT NULL CHECK (estado IN ('PENDIENTE', 'EJECUTADO', 'CANCELADO')),
  observacion TEXT
);

CREATE TABLE evento_telemetria (
  evento_id BIGINT GENERATED ALWAYS AS IDENTITY,
  vehiculo_id BIGINT NOT NULL REFERENCES vehiculo(vehiculo_id),
  ruta_id BIGINT NOT NULL REFERENCES ruta(ruta_id),
  region_id SMALLINT NOT NULL REFERENCES region(region_id),
  fecha_evento TIMESTAMPTZ NOT NULL,
  latitud NUMERIC(9,6) NOT NULL,
  longitud NUMERIC(9,6) NOT NULL,
  velocidad_kmh NUMERIC(6,2) NOT NULL CHECK (velocidad_kmh >= 0 AND velocidad_kmh <= 160),
  frenado_brusco BOOLEAN NOT NULL DEFAULT FALSE,
  combustible_pct NUMERIC(5,2) NOT NULL CHECK (combustible_pct >= 0 AND combustible_pct <= 100),
  odometro_km NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (evento_id, fecha_evento)
) PARTITION BY RANGE (fecha_evento);

CREATE TABLE evento_telemetria_2026_01 PARTITION OF evento_telemetria
  FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-02-01 00:00:00+00');

CREATE TABLE evento_telemetria_2026_02 PARTITION OF evento_telemetria
  FOR VALUES FROM ('2026-02-01 00:00:00+00') TO ('2026-03-01 00:00:00+00');

CREATE TABLE evento_telemetria_2026_03 PARTITION OF evento_telemetria
  FOR VALUES FROM ('2026-03-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');

CREATE TABLE evento_telemetria_default PARTITION OF evento_telemetria DEFAULT;

CREATE INDEX idx_evento_fecha ON evento_telemetria (fecha_evento DESC);
CREATE INDEX idx_evento_vehiculo_fecha ON evento_telemetria (vehiculo_id, fecha_evento DESC);
CREATE INDEX idx_evento_region_fecha ON evento_telemetria (region_id, fecha_evento DESC);

CREATE INDEX idx_mantenimiento_vehiculo_fecha ON mantenimiento (vehiculo_id, fecha_programada DESC);
CREATE INDEX idx_asignacion_vehiculo ON asignacion_vehiculo_conductor (vehiculo_id, fecha_desde DESC);
