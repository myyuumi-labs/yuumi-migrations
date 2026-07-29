# yuumi-migrations

Central database scripts for **MyYuumi** ecommerce PostgreSQL databases.

Layout matches nexthcm-migration style: SQL on the filesystem (no `src/`), Flyway via
`filesystem:migration/...`.

```
yuumi-migrations/
  init/<database>/V1__init_database.sql     # CREATE DATABASE
  migration/<database>/V1__....sql          # schema (Flyway)
  scripts/init-dbs.sh
  scripts/migrate.sh
  pom.xml                                   # flyway-maven-plugin only
```

| Layer | Path | Purpose |
|-------|------|---------|
| Init | `init/<database>/V1__init_database.sql` | `CREATE DATABASE` (empty DBs) |
| Migration | `migration/<database>/` | Tables, indexes, constraints (Flyway) |

| Database | Service | Init | Migration |
|----------|---------|------|-----------|
| `keycloak` | Keycloak | `init/keycloak` | — (Keycloak manages schema) |
| `customerdb` | CustomerService | `init/customerdb` | `migration/customerdb` |
| `accountsdb` | AccountService | `init/accountsdb` | `migration/accountsdb` |
| `billerdb` | BillerService | `init/billerdb` | `migration/billerdb` |
| `paymentdb` | PaymentOrchestrator | `init/paymentdb` | `migration/paymentdb` |
| `settlementdb` | SettlementService | `init/settlementdb` | `migration/settlementdb` |
| `billpayworkerdb` | BillPayWorkerService | `init/billpayworkerdb` | `migration/billpayworkerdb` |

## Prerequisites

Start PostgreSQL (container only — no SQL in infra):

```bash
cd yuumi/yuumi-infras
podman compose up -d postgres
# or: docker compose up -d postgres
```

Default credentials: user `postgres`, password `1`. Requires `psql` on PATH for init.

## Create databases (init)

```bash
cd yuumi/yuumi-migrations
chmod +x scripts/init-dbs.sh
./scripts/init-dbs.sh
```

## Run migrations (interactive script)

```bash
cd yuumi/yuumi-migrations
chmod +x scripts/migrate.sh
./scripts/migrate.sh
```

When action is `migrate`, the script runs `init-dbs.sh` first, then Flyway.

The script prompts for:

1. **Database** — pick one or `all`
2. **Schema** — lists schemas from Postgres when `psql` is available, otherwise defaults to `public`
3. **Action** — `migrate`, `info`, `validate`, or `repair`

Non-interactive example:

```bash
./scripts/migrate.sh -d accountsdb -s public -a migrate -y
./scripts/migrate.sh -d all -a migrate -y
```

## Run migrations (Maven)

Run from the repo root so `filesystem:migration/...` resolves correctly.

```bash
cd yuumi/yuumi-migrations
mvn flyway:migrate -Pcustomerdb
```

Migrate all databases:

```bash
mvn flyway:migrate@customerdb flyway:migrate@accountsdb flyway:migrate@billerdb flyway:migrate@paymentdb flyway:migrate@settlementdb flyway:migrate@billpayworkerdb
```

Other Flyway goals work the same way, e.g. `flyway:info -Paccountsdb`.

Maven does **not** run `init/` — use `./scripts/init-dbs.sh` (or `migrate.sh`) first.

## Override connection

```bash
mvn flyway:migrate -Pcustomerdb -Dflyway.host=db.example.com -Dflyway.password=secret
```

## Wire a Spring service

In each service `application.yml`:

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
  flyway:
    enabled: false
```

Schema is applied by this module (CI/CD or local `migrate.sh` / `mvn flyway:migrate`), not at app startup.

## Adding a migration

1. Add `V2__description.sql` (or next version) under `migration/<database>/`.
2. Never edit a migration that has already been applied in shared environments.
3. Run `mvn flyway:migrate -P<database>` from the repo root.

Naming convention: `V{version}__{snake_case_description}.sql`

## Adding a new database

1. Add `init/<dbname>/V1__init_database.sql` with `CREATE DATABASE IF NOT EXISTS <dbname>;`
2. Add Flyway folder `migration/<dbname>/`
3. Register the DB in `pom.xml` profiles/executions and `scripts/migrate.sh` `DATABASES` array
