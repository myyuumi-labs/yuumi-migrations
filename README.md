# yuumi-migrations

Central [Flyway](https://flywaydb.org/) migrations for **MyYuumi** ecommerce PostgreSQL databases.

Each service owns a separate database (same layout as MockBank). SQL files live under `src/main/resources/db/migration/<database>/`.

| Database | Service | Migration folder |
|----------|---------|------------------|
| `customerdb` | CustomerService | `db/migration/customerdb` |
| `accountsdb` | AccountService | `db/migration/accountsdb` |
| `billerdb` | BillerService | `db/migration/billerdb` |
| `paymentdb` | PaymentOrchestrator | `db/migration/paymentdb` |
| `settlementdb` | SettlementService | `db/migration/settlementdb` |
| `billpayworkerdb` | BillPayWorkerService | `db/migration/billpayworkerdb` |

## Prerequisites

Start PostgreSQL (creates all app databases on first run):

```bash
cd yuumi/yuumi-infras/observability
docker compose up -d postgres
```

Default credentials: user `postgres`, password `1`.

## Run migrations (interactive script)

```bash
cd yuumi/yuumi-migrations
chmod +x scripts/migrate.sh
./scripts/migrate.sh
```

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

Migrate one database:

```bash
cd yuumi/yuumi-migrations
mvn flyway:migrate -Pcustomerdb
```

Migrate all databases:

```bash
mvn flyway:migrate@customerdb flyway:migrate@accountsdb flyway:migrate@billerdb flyway:migrate@paymentdb flyway:migrate@settlementdb flyway:migrate@billpayworkerdb
```

Other Flyway goals work the same way, e.g. `flyway:info -Paccountsdb`.

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

Schema is applied by this module (CI/CD or local `mvn flyway:migrate`), not at app startup.

## Adding a migration

1. Add `V2__description.sql` (or next version) under the correct `db/migration/<database>/` folder.
2. Never edit a migration that has already been applied in shared environments.
3. Run `mvn flyway:migrate -P<database>` to apply locally.

Naming convention: `V{version}__{snake_case_description}.sql`
