# yuumi-migrations

Central database scripts for **MyYuumi** ecommerce PostgreSQL databases.

Layout matches **nexthcm-migration**: SQL on the filesystem (no `src/`), per-DB Flyway
config under `config/<env>/`, thin root `pom.xml` (no per-DB profiles/executions).

```
yuumi-migrations/
  init/<database>/V1__init_database.sql     # CREATE DATABASE
  migration/<database>/V1__....sql          # schema (Flyway)
  config/local/flyway_<database>.conf       # url, user, locations, schemas
  scripts/init-dbs.sh
  scripts/migrate.sh
  pom.xml                                   # flyway-maven-plugin only
```

| Layer | Path | Purpose |
|-------|------|---------|
| Init | `init/<database>/V1__init_database.sql` | `CREATE DATABASE` (empty DBs) |
| Migration | `migration/<database>/` | Tables, indexes, constraints (Flyway) |
| Config | `config/<env>/flyway_<database>.conf` | Connection + `filesystem:migration/...` |

| Database | Service | Init | Migration | Config |
|----------|---------|------|-----------|--------|
| `accountdb` | AccountService (yuumi-account) | yes | yes | `flyway_accountdb.conf` |

## Prerequisites

```bash
cd yuumi/yuumi-infras
podman compose up -d postgres
```

Default credentials in `config/local/*.conf`: user `postgres`, password `1`. Requires `psql` for init.

## Create databases (init)

```bash
cd yuumi/yuumi-migrations
./scripts/init-dbs.sh
```

## Run migrations (recommended)

```bash
./scripts/migrate.sh
./scripts/migrate.sh -d accountdb -a migrate -y
./scripts/migrate.sh -d all -e local -a migrate -y
```

`migrate.sh` discovers databases from `config/<env>/flyway_*.conf` (add a conf file = new DB in the menu).

## Run migrations (Maven / nexthcm style)

```bash
mvn flyway:migrate -Dflyway.configFiles=$PWD/config/local/flyway_accountdb.conf
mvn flyway:info    -Dflyway.configFiles=$PWD/config/local/flyway_accountdb.conf
```

Maven does **not** run `init/` — use `./scripts/init-dbs.sh` (or `migrate.sh`) first.

## Adding a new database

1. `init/<dbname>/V1__init_database.sql`
2. `migration/<dbname>/V1__....sql`
3. `config/local/flyway_<dbname>.conf` (url + `filesystem:migration/<dbname>`)

No `pom.xml` changes.

## Wire a Spring service

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
  flyway:
    enabled: false
```
