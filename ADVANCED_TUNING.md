# PostgreSQL Performance Tuning - Qo'shimcha Sozlamalar

## Mohiyati
Agar apply-optimizations.sh'dan keyin ham muammolar bo'lsa, bu qo'shimcha sozlamalar yordam beradi.

## 1. PostgreSQL Extension'lar

### pg_stat_statements (Query Monitoring)
```sql
-- Container ichida
docker exec -it aziz_animedb psql -U postgres -d aziz_grammydb

-- Extension yaratish
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Tekshirish
SELECT * FROM pg_stat_statements LIMIT 5;
```

### pg_repack (Table Bloat)
Agar table'lar hajmi katta bo'lib qolsa:
```bash
# Container ichiga kirish
docker exec -it aziz_animedb bash

# pg_repack o'rnatish (agar yo'q bo'lsa)
apt-get update && apt-get install -y postgresql-16-repack

# Ishlatish
pg_repack -U postgres -d aziz_grammydb --table=User
pg_repack -U postgres -d aziz_grammydb --table=WatchHistory
```

## 2. Index Monitoring

### Ishlatilmayotgan Index'lar
```sql
-- Keraksiz index'larni topish
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Agar index ishlatilmasa, o'chirish:
-- DROP INDEX index_nomi;
```

### Index Efficiency
```sql
-- Index effectiveness
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

## 3. Query Optimization

### EXPLAIN ANALYZE
Sekin query'ni topish va tahlil qilish:
```sql
-- Query'ni tahlil qilish
EXPLAIN ANALYZE
SELECT * FROM "User" 
WHERE "isPremium" = true 
ORDER BY "lastActivity" DESC
LIMIT 10;

-- Index ishlatilmoqdami? "Index Scan" bo'lishi kerak
-- Agar "Seq Scan" bo'lsa - index qo'shish kerak
```

### Composite Index Strategy
Ko'p WHERE condition'larda:
```sql
-- Masalan:
-- WHERE userId = ? AND status = ? ORDER BY createdAt DESC

-- Composite index qo'shish:
CREATE INDEX idx_payment_user_status_created 
ON "Payment" ("userId", "status", "createdAt" DESC);
```

## 4. Connection Pooling (Production)

### PgBouncer Qo'shish
Connection pooler - juda ko'p ulanishlar bo'lsa:

`docker-compose-pgbouncer.yml`:
```yaml
version: "3.9"

services:
  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    container_name: aziz_pgbouncer
    environment:
      DATABASES_HOST: db
      DATABASES_PORT: 5432
      DATABASES_USER: postgres
      DATABASES_PASSWORD: 12345
      DATABASES_DBNAME: aziz_grammydb
      PGBOUNCER_POOL_MODE: transaction
      PGBOUNCER_MAX_CLIENT_CONN: 100
      PGBOUNCER_DEFAULT_POOL_SIZE: 20
      PGBOUNCER_RESERVE_POOL_SIZE: 5
    ports:
      - "6432:5432"
    depends_on:
      - db

  db:
    # ... existing db config
    ports:
      - "5433:5432"  # Direct access
    # PgBouncer orqali: localhost:6432
```

DATABASE_URL ni o'zgartirish:
```env
# Oldin:
DATABASE_URL=postgresql://postgres:12345@localhost:5433/aziz_grammydb

# PgBouncer bilan:
DATABASE_URL=postgresql://postgres:12345@localhost:6432/aziz_grammydb
```

## 5. Vacuum Strategy

### Manual VACUUM
```sql
-- Full vacuum (sekin, lekin to'liq tozalaydi)
VACUUM FULL ANALYZE "User";
VACUUM FULL ANALYZE "WatchHistory";

-- Regular vacuum (tez, ko'pincha yetarli)
VACUUM ANALYZE;
```

### Autovacuum Tuning
Agar autovacuum yetarli tez ishlamasa:

`postgresql.conf`:
```conf
autovacuum_naptime = 30s              # 60s -> 30s
autovacuum_vacuum_threshold = 25      # 50 -> 25
autovacuum_vacuum_scale_factor = 0.05 # 0.1 -> 0.05
```

## 6. Monitoring va Alerting

### Prometheus + Grafana
Database metrics'ni visualize qilish:

1. **postgres_exporter qo'shish:**
```yaml
# docker-compose.monitoring.yml'ga qo'shish
postgres_exporter:
  image: prometheuscommunity/postgres-exporter
  environment:
    DATA_SOURCE_NAME: "postgresql://postgres:12345@db:5432/aziz_grammydb?sslmode=disable"
  ports:
    - "9187:9187"
```

2. **Grafana Dashboard:**
- Dashboard ID: 9628 (PostgreSQL Database)
- Metrics: CPU, Memory, Connections, Query time, etc.

### Custom Alerts
```yaml
# prometheus/alerts.yml
groups:
  - name: database
    rules:
      - alert: HighCPUUsage
        expr: container_cpu_usage_seconds_total{name="aziz_animedb"} > 0.8
        for: 5m
        annotations:
          summary: "Database CPU yuqori"
      
      - alert: TooManyConnections
        expr: pg_stat_activity_count > 40
        for: 2m
        annotations:
          summary: "Ko'p ulanishlar"
```

## 7. Backup Strategy

### Automated Backup
```bash
#!/bin/bash
# backup-daily.sh

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"

# Backup
docker exec aziz_animedb pg_dump -U postgres aziz_grammydb | gzip > "$BACKUP_FILE"

# Eski backup'larni o'chirish (7 kundan ortiq)
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "✅ Backup saqlandi: $BACKUP_FILE"
```

Cron job:
```bash
# crontab -e
0 2 * * * /path/to/backup-daily.sh
```

## 8. Read Replicas (Katta Load uchun)

Agar traffic juda ko'p bo'lsa:

```yaml
# docker-compose-replica.yml
db_replica:
  image: postgres:16
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: 12345
    PGDATA: /var/lib/postgresql/data/replica
  command: |
    postgres
    -c wal_level=replica
    -c hot_standby=on
    -c max_wal_senders=10
```

Prisma'da read replica:
```typescript
// Read operations
await prisma.$replica.user.findMany({...});

// Write operations  
await prisma.user.create({...});
```

## 9. Caching Strategy

### Redis Cache
Ko'p o'qiladigan data uchun:

```typescript
// Redis cache service
@Injectable()
export class CacheService {
  async getUserFromCache(userId: number) {
    const cached = await redis.get(`user:${userId}`);
    if (cached) return JSON.parse(cached);
    
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });
    
    await redis.setex(`user:${userId}`, 3600, JSON.stringify(user));
    return user;
  }
}
```

Docker:
```yaml
redis:
  image: redis:alpine
  ports:
    - "6379:6379"
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

## 10. Performance Testing

### pgbench
Load testing:
```bash
# Initialize
docker exec aziz_animedb pgbench -i -U postgres aziz_grammydb

# Run test (100 clients, 10 threads, 60 seconds)
docker exec aziz_animedb pgbench -c 100 -j 10 -T 60 -U postgres aziz_grammydb
```

### Custom Load Test
```bash
# Apache Bench
ab -n 1000 -c 10 http://localhost:3001/api/users

# wrk
wrk -t12 -c400 -d30s http://localhost:3001/api/movies
```

## 11. Database Partitioning

Katta table'lar uchun (masalan, WatchHistory):

```sql
-- Partition by date
CREATE TABLE "WatchHistory_2026_01" PARTITION OF "WatchHistory"
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE "WatchHistory_2026_02" PARTITION OF "WatchHistory"
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- Index har bir partition'da
CREATE INDEX ON "WatchHistory_2026_01" ("userId", "watchedAt");
```

## 12. Query Queue (Agar Kerak Bo'lsa)

Heavy query'lar uchun queue:

```typescript
// Bull Queue
@Processor('heavy-queries')
export class QueryProcessor {
  @Process('calculate-stats')
  async calculateStats(job: Job) {
    // Heavy query
    const stats = await prisma.$queryRaw`...`;
    return stats;
  }
}
```

## Xulosa

Bu qo'shimcha optimizatsiyalar faqat kerak bo'lgandagina qo'llash:
1. ✅ Dastlab `apply-optimizations.sh` ishlatish
2. ⚠️  Agar yetarli bo'lmasa, shu document'dagi qo'shimcha usullar
3. 📊 Doimiy monitoring (prometheus/grafana)
4. 🔄 Regular vakuum va backup

Har bir qo'shimcha optimizatsiya o'z vazni bilan keladi - faqat muammolar bo'lganda qo'llash!
