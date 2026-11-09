# Apache AGE Container Images for CloudNativePG (CNPG)

Lightweight container images that add the **Apache AGE** graph extension onto
[CloudNativePG](https://cloudnative-pg.io/) base PostgreSQL images.

Use them to run property graph workloads side-by-side with standard relational
SQL in Kubernetes clusters managed by CloudNativePG.

## Image variants

Five image variants are published for each matrix entry:

| Image                            | File                                        | Extensions included                                                |
| -------------------------------- | ------------------------------------------- | ------------------------------------------------------------------ |
| `age`                            | `Dockerfile`                                | AGE, pgvector (pgvector inherited from the base image)             |
| `age-pgvector`                   | `Dockerfile.age-pgvector`                   | AGE, pgvector (pgvector inherited from the base image)             |
| `age-pgvector-postgis`           | `Dockerfile.age-pgvector-postgis`           | AGE, pgvector, PostGIS                                             |
| `age-pgvector-timescale`         | `Dockerfile.age-pgvector-timescale`         | AGE, pgvector, TimescaleDB (when `timescale_version` set)          |
| `age-pgvector-postgis-timescale` | `Dockerfile.age-pgvector-postgis-timescale` | AGE, pgvector, PostGIS, TimescaleDB (when `timescale_version` set) |

### Where pgvector comes from

The CloudNativePG base images already ship pgvector — `postgresql:<pg>-standard-<os>`
and `postgis:<pg>-<postgis>-standard-<os>` both provide it (0.8.7 at the time of
writing). None of the Dockerfiles install it from apt any more: that step pulled an
older package *over* the base (`postgresql-<pg>-pgvector` 0.8.6), silently
downgrading the extension. pgvector's version is now owned by the base image, so a
rebuild tracks whatever CloudNativePG ships.

Consequently **`age` and `age-pgvector` contain the same extensions**; `age` is
kept published for backwards compatibility so existing pins keep resolving. Prefer
`age-pgvector*` in new deployments — the name states the requirement.

If you build with a base variant that does *not* carry pgvector (e.g. setting
`CNPG_VARIANT=minimal-trixie`), pgvector will be missing from the resulting image;
only the `standard-*` variants in the build matrix below are covered.

### Upgrading an existing database

Rebuilding these images changes the pgvector release inside them: the current
base image provides **0.8.7**, while the images published before the apt step was
removed carried **0.8.6**. The library travels with the image, but a database's
*extension* version is fixed when the extension is created, so an existing
database keeps the version it was instantiated with — even after its pods have
been rolled onto the rebuilt image.

After a cluster runs on a rebuilt image, check the application database:

```sql
SELECT extversion FROM pg_extension WHERE extname = 'vector';               -- installed
SELECT default_version FROM pg_available_extensions WHERE name = 'vector';  -- shipped by the image
```

If they differ, upgrade the extension in place:

```sql
ALTER EXTENSION vector UPDATE;
```

Verified on a database created by `age-pgvector:18-1.7.0-standard-trixie`
(pgvector 0.8.6) and then served by `postgresql:18-standard-trixie` (0.8.7):

- before the update the check reported `installed = 0.8.6`, `image ships = 0.8.7`;
  queries and an existing HNSW index kept working (the newer library is backward
  compatible with the older SQL objects);
- `ALTER EXTENSION vector UPDATE` moved it to 0.8.7 — same query results, same
  index plan, index still valid (`indisvalid = 1`), no table or index rebuild;
- running it again is a no-op (`NOTICE: version "0.8.7" of extension "vector" is
  already installed`), so it is safe to script.

New clusters need nothing: `CREATE EXTENSION vector` in the bootstrap SQL creates
the version the image ships.

Run the update per database that has pgvector (for the Konnektr Graph: the
application database), as the owner of the extension — the bootstrap superuser
(`postgres`), not the application user.



## Image tags

Current build matrix (see workflow in `.github/workflows/build.yml`):

### `age` and `age-pgvector`

| PostgreSQL | AGE version(s) | Variants                               |
| ---------- | -------------- | -------------------------------------- |
| 16         | 1.5.0, 1.6.0   | `standard-bookworm`, `standard-trixie` |
| 17         | 1.6.0          | `standard-bookworm`, `standard-trixie` |
| 18         | 1.7.0          | `standard-trixie`                      |
| 18         | 1.8.0          | `standard-trixie`                      |

Each row publishes two tag forms:

- `ghcr.io/<owner>/age:<pg_major>-<age_version>-<variant>` — fully qualified
- `ghcr.io/<owner>/age:<pg_major>-<age_version>` — short tag (only for `standard-trixie`)

Example for **age** (same pattern for **age-pgvector**):

```
ghcr.io/konnektr-io/age:16-1.5.0-standard-bookworm
ghcr.io/konnektr-io/age:16-1.5.0-standard-trixie
ghcr.io/konnektr-io/age:16-1.5.0         (short, standard-trixie only)
ghcr.io/konnektr-io/age:16-1.6.0-standard-bookworm
ghcr.io/konnektr-io/age:16-1.6.0-standard-trixie
ghcr.io/konnektr-io/age:16-1.6.0         (short)
ghcr.io/konnektr-io/age:17-1.6.0-standard-bookworm
ghcr.io/konnektr-io/age:17-1.6.0-standard-trixie
ghcr.io/konnektr-io/age:17-1.6.0         (short)
ghcr.io/konnektr-io/age:18-1.7.0-standard-trixie
ghcr.io/konnektr-io/age:18-1.7.0         (short)
ghcr.io/konnektr-io/age:18-1.8.0-standard-trixie
ghcr.io/konnektr-io/age:18-1.8.0         (short)
```

### `age-pgvector-postgis`

| PostgreSQL | AGE version(s) |
| ---------- | -------------- |
| 16         | 1.5.0          |
| 16         | 1.6.0          |
| 17         | 1.6.0          |
| 18         | 1.7.0          |
| 18         | 1.8.0          |

Tags: `ghcr.io/<owner>/age-pgvector-postgis:<pg_major>-<age_version>`

```
ghcr.io/konnektr-io/age-pgvector-postgis:16-1.5.0
ghcr.io/konnektr-io/age-pgvector-postgis:16-1.6.0
ghcr.io/konnektr-io/age-pgvector-postgis:17-1.6.0
ghcr.io/konnektr-io/age-pgvector-postgis:18-1.7.0
ghcr.io/konnektr-io/age-pgvector-postgis:18-1.8.0
```

### `age-pgvector-timescale` (TimescaleDB)

| PostgreSQL | AGE version | Variant           | TimescaleDB |
| ---------- | ----------- | ----------------- | ----------- |
| 17         | 1.6.0       | `standard-trixie` | 2.24.0      |

Tags: `ghcr.io/<owner>/age-pgvector-timescale:<pg_major>-<age_version>-<variant>`

```
ghcr.io/konnektr-io/age-pgvector-timescale:17-1.6.0-standard-trixie
```

### `age-pgvector-postgis-timescale` (PostGIS + TimescaleDB)

| PostgreSQL | AGE version | TimescaleDB |
| ---------- | ----------- | ----------- |
| 17         | 1.6.0       | 2.24.0      |
| 18         | 1.7.0       | 2.25.1      |
| 18         | 1.8.0       | 2.30.1      |

Tags: `ghcr.io/<owner>/age-pgvector-postgis-timescale:<pg_major>-<age_version>`

```
ghcr.io/konnektr-io/age-pgvector-postgis-timescale:17-1.6.0
ghcr.io/konnektr-io/age-pgvector-postgis-timescale:18-1.7.0
ghcr.io/konnektr-io/age-pgvector-postgis-timescale:18-1.8.0
```

## Using with CloudNativePG

Two common approaches:

### 1. Directly reference the image

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: age-demo
spec:
  imageName: ghcr.io/konnektr-io/age:16-1.6.0-standard-trixie
  instances: 1
  bootstrap:
    initdb:
      postInitTemplateSQL:
        - CREATE EXTENSION age;
        - GRANT SELECT ON ag_catalog.ag_graph TO app;
        - GRANT USAGE ON SCHEMA ag_catalog TO app;
        - ALTER USER app REPLICATION;
        - CREATE PUBLICATION age_pub FOR ALL TABLES;
        - SELECT * FROM pg_create_logical_replication_slot('age_slot', 'pgoutput');
  storage:
    size: 2Gi
```

### 2. Via a ClusterImageCatalog (recommended for multiple clusters)

Create a `ClusterImageCatalog` (example—adjust to your org/versions):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ClusterImageCatalog
metadata:
  name: age
spec:
  images:
    - major: 16
      image: ghcr.io/konnektr-io/age:16-1.6.0-standard-trixie
    - major: 17
      image: ghcr.io/konnektr-io/age:17-1.6.0-standard-trixie
    - major: 18
      image: ghcr.io/konnektr-io/age:18-1.8.0-standard-trixie
```

Then in your `Cluster` use:

```yaml
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ClusterImageCatalog
  name: age
  major: 18
```

## Quick AGE usage

After the cluster is ready:

```bash
kubectl exec -ti age-demo-1 -- psql app -c "CREATE EXTENSION IF NOT EXISTS age; LOAD 'age'; SET search_path = ag_catalog,\"$user\",public; SELECT create_graph('g');"
kubectl exec -ti age-demo-1 -- psql app -c "SELECT * FROM create_vlabel('g', 'Person');"
kubectl exec -ti age-demo-1 -- psql app -c "SELECT * FROM cypher('g', $$ CREATE (n:Person {name:'Alice'}) RETURN n $$) AS (n agtype);"
kubectl exec -ti age-demo-1 -- psql app -c "SELECT * FROM cypher('g', $$ MATCH (n:Person) RETURN n.name $$) AS (name text);"
```

## Building locally

You can reproduce the build for a given combination:

```bash
# Base AGE image
docker build \
  --build-arg PG_MAJOR=16 \
  --build-arg AGE_VERSION=1.6.0 \
  --build-arg CNPG_VARIANT=standard-trixie \
  -t age:16-1.6.0-standard-trixie .

# AGE + pgvector
docker build -f Dockerfile.age-pgvector \
  --build-arg PG_MAJOR=16 \
  --build-arg AGE_VERSION=1.6.0 \
  --build-arg CNPG_VARIANT=standard-trixie \
  -t age-pgvector:16-1.6.0-standard-trixie .

# AGE + pgvector + PostGIS
docker build -f Dockerfile.age-pgvector-postgis \
  --build-arg PG_MAJOR=16 \
  --build-arg AGE_VERSION=1.6.0 \
  --build-arg CNPG_POSTGIS_VARIANT=3-standard-trixie \
  -t age-pgvector-postgis:16-1.6.0 .

# AGE + pgvector + TimescaleDB
docker build -f Dockerfile.age-pgvector-timescale \
  --build-arg PG_MAJOR=17 \
  --build-arg AGE_VERSION=1.6.0 \
  --build-arg CNPG_VARIANT=standard-trixie \
  --build-arg TIMESCALE_VERSION_ARG=2.24.0 \
  -t age-pgvector-timescale:17-1.6.0-standard-trixie .

# AGE + pgvector + PostGIS + TimescaleDB
docker build -f Dockerfile.age-pgvector-postgis-timescale \
  --build-arg PG_MAJOR=18 \
  --build-arg AGE_VERSION=1.8.0 \
  --build-arg CNPG_POSTGIS_VARIANT=3-standard-trixie \
  --build-arg TIMESCALE_VERSION_ARG=2.30.1 \
  -t age-pgvector-postgis-timescale:18-1.8.0 .
```

## CI / Publishing

Automated builds run via GitHub Actions on pushes to `main` or manual dispatch.
See `.github/workflows/build.yml`. Each matrix entry is built and pushed with
OCI image labels (title, description, source, revision, license).
