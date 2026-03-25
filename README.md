# Laboratorio BD Avanzadas - PostgreSQL distribuido (EC2 + Docker)

Este laboratorio implementa **3 nodos** en una sola EC2 usando Docker:
- 1 nodo primario (`pg-primary`)
- 2 nodos replica streaming (`pg-replica-1`, `pg-replica-2`)

Contexto de negocio (no clasico de clase): **Plataforma de telemetria de vehiculos de flota**.

Dimension seleccionada para la evaluacion:
- **Particionamiento**
- **Replicacion**

## 1. Estructura creada

- `docker-compose.yml`
- `postgres/primary/postgresql.conf`
- `postgres/primary/pg_hba.conf`
- `postgres/replica/postgresql.conf`
- `postgres/init/00-init-primary.sh`
- `scripts/setup-replica.sh`
- `sql/01_schema.sql`
- `sql/02_seed.sql`
- `sql/03_queries_transactions.sql`
- `sql/04_replication_checks.sql`

## 2. Levantar infraestructura en EC2

Desde la raiz del proyecto:

```bash
docker compose down -v
docker compose up -d
docker compose ps
```

Verifica logs:

```bash
docker logs -f pg-primary
```

En otra terminal:

```bash
docker logs -f pg-replica-1
docker logs -f pg-replica-2
```

## 3. Cargar esquema y datos (solo en PRIMARY)

```bash
docker exec -i pg-primary psql -U postgres -d fleetdb < sql/01_schema.sql
docker exec -i pg-primary psql -U postgres -d fleetdb < sql/02_seed.sql
```

Validacion rapida de volumen de datos:

```bash
docker exec -it pg-primary psql -U postgres -d fleetdb -c "SELECT COUNT(*) AS total_eventos FROM evento_telemetria;"
```

## 4. Ejecutar consultas y transacciones para evidencias

```bash
docker exec -i pg-primary psql -U postgres -d fleetdb < sql/03_queries_transactions.sql
```

Este script incluye:
- `EXPLAIN ANALYZE` con filtros de fecha para mostrar **partition pruning**
- consulta analitica de frenados bruscos
- una transaccion de negocio (`BEGIN ... COMMIT`) que abre mantenimiento y cambia estado del vehiculo

## 5. Validar replicacion en los 3 nodos

En primario:

```bash
docker exec -it pg-primary psql -U postgres -d fleetdb -f sql/04_replication_checks.sql
```

En replica 1:

```bash
docker exec -it pg-replica-1 psql -U postgres -d fleetdb -f sql/04_replication_checks.sql
```

En replica 2:

```bash
docker exec -it pg-replica-2 psql -U postgres -d fleetdb -f sql/04_replication_checks.sql
```

## 6. Conectar pgAdmin por tunel SSH

Ejemplo desde tu maquina local:

```bash
ssh -i TU_KEY.pem -L 15432:127.0.0.1:5432 -L 15433:127.0.0.1:5433 -L 15434:127.0.0.1:5434 ec2-user@TU_EC2_PUBLIC_DNS
```

Luego en pgAdmin creas 3 conexiones:

- Primary:
  - Host: `127.0.0.1`
  - Port: `15432`
  - User: `postgres`
  - Password: `postgres`
  - Database: `fleetdb`

- Replica 1:
  - Host: `127.0.0.1`
  - Port: `15433`
  - User: `postgres`
  - Password: `postgres`
  - Database: `fleetdb`

- Replica 2:
  - Host: `127.0.0.1`
  - Port: `15434`
  - User: `postgres`
  - Password: `postgres`
  - Database: `fleetdb`