# Apache Age Container Images for CloudNativePG

These images are built on top of the [Official Postgres image](https://hub.docker.com/_/postgres)
maintained by the [PostgreSQL Docker Community](https://github.com/docker-library/postgres),
by adding the following software:

- Barman Cloud
- PGAudit
- Postgres Failover Slots
# Apache AGE images for CloudNativePG

Lightweight container images that add the **Apache AGE** graph extension to the
CloudNativePG base PostgreSQL images. Use them to run property graph workloads
side-by-side with standard relational SQL in Kubernetes clusters managed by
[CloudNativePG](https://cloudnative-pg.io/).

## Contents

Each image includes:

* CloudNativePG upstream base image (variant: `standard-trixie`)
* Compiled Apache AGE extension (version per tag)
* pgvector (from upstream base, available for convenience)

Nothing else is bundled intentionally—focus is on Apache AGE.

## Image tags

Current build matrix (see workflow in `.github/workflows/build.yml`):

| PostgreSQL | AGE version(s)       | Variant         |
|------------|----------------------|-----------------|
| 16         | 1.5.0, 1.6.0         | standard-trixie |
| 17         | 1.6.0                | standard-trixie |

Tag format:

```
ghcr.io/<owner>/age:<pg_major>-<age_version>-<variant>
```

Examples:

```
ghcr.io/konnektr-io/age:16-1.5.0-standard-trixie
ghcr.io/konnektr-io/age:16-1.6.0-standard-trixie
ghcr.io/konnektr-io/age:17-1.6.0-standard-trixie
```

Short tags without the variant (e.g. `16-1.6.0`) may also exist for the default
variant; prefer the fully qualified form to avoid ambiguity in the future if
more variants are added.

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
```

Then in your `Cluster` use:

```yaml
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ClusterImageCatalog
  name: age
  major: 16
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
docker build \
  --build-arg PG_MAJOR=16 \
  --build-arg AGE_VERSION=1.6.0 \
  --build-arg CNPG_VARIANT=standard-trixie \
  -t age:16-1.6.0-standard-trixie .
```

## CI / Publishing

Automated builds run via GitHub Actions on pushes to `main` or manual dispatch.
See `.github/workflows/build.yml`. Each matrix entry is built and pushed with
OCI image labels (title, description, source, revision, license).