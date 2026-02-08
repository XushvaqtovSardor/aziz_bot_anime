# 🚀 Tez Yo'riqnoma - PostgreSQL Optimizatsiya

## 1. O'RNATISH (Birinchi Marta)

```bash
# 1. Backup olish
docker exec aziz_animedb pg_dump -U postgres aziz_grammydb > backup.sql

# 2. Optimizatsiyani qo'llash
bash apply-optimizations.sh

# 3. Tekshirish
bash quick-check.sh
```

**Kutish vaqti:** 5-10 daqiqa

---

## 2. MONITORING (Har Kuni)

### Tez Tekshirish
```bash
bash quick-check.sh
```

### To'liq Monitoring
```bash
bash monitor-db.sh
```

### Real-time Stats
```bash
# CPU va Memory
watch -n 5 'docker stats aziz_animedb --no-stream'

# Log'lar
docker logs aziz_animedb -f --tail 100
```

---

## 3. MUAMMOLARNI HAL QILISH

### ❗ CPU Yuqori (>50%)
```bash
# 1. Sekin query'larni topish
bash monitor-db.sh

# 2. Query'ni to'xtatish (agar kerak bo'lsa)
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pg_terminate_backend(PID);"

# 3. VACUUM qilish
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "VACUUM ANALYZE;"
```

### ❗ Ko'p Ulanishlar (>20)
```bash
# 1. Ulanishlarni ko'rish
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT * FROM pg_stat_activity WHERE datname='aziz_grammydb';"

# 2. Idle ulanishlarni o'chirish
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '10 minutes';"
```

### ❗ Memory To'lib Ketsa
```bash
# 1. docker-compose.yml'da limit oshirish
# memory: 2G  # 1G o'rniga

# 2. Restart
docker-compose restart db
```

### ❗ Sekin Query'lar
```sql
-- Query'ni tahlil qilish
EXPLAIN ANALYZE SELECT ...;

-- Index qo'shish (agar kerak bo'lsa)
CREATE INDEX idx_custom ON "TableName" ("field1", "field2");
```

---

## 4. KUNDALIK VAZIFALAR

### Har Kuni
```bash
# 1. Status tekshirish
bash quick-check.sh

# 2. CPU/Memory monitoring
docker stats aziz_animedb --no-stream
```

### Har Hafta
```bash
# 1. VACUUM
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "VACUUM ANALYZE;"

# 2. Dead tuples tekshirish
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT tablename, n_dead_tup FROM pg_stat_user_tables WHERE n_dead_tup > 1000;"
```

### Har Oy
```bash
# 1. Full backup
docker exec aziz_animedb pg_dump -U postgres aziz_grammydb | gzip > backup_$(date +%Y%m%d).sql.gz

# 2. Database hajmi
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pg_size_pretty(pg_database_size('aziz_grammydb'));"

# 3. Index effectiveness
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -f database-monitoring.sql
```

---

## 5. FOYDALI COMMANDLAR

### Container Boshqarish
```bash
# To'xtatish
docker-compose down

# Ishga tushirish
docker-compose up -d

# Restart
docker-compose restart

# Rebuild
docker-compose build --no-cache && docker-compose up -d
```

### Database Commands
```bash
# Database ichiga kirish
docker exec -it aziz_animedb psql -U postgres -d aziz_grammydb

# SQL file ishlatish
docker exec -i aziz_animedb psql -U postgres -d aziz_grammydb < file.sql

# Backup olish
docker exec aziz_animedb pg_dump -U postgres aziz_grammydb > backup.sql

# Backup restore qilish
docker exec -i aziz_animedb psql -U postgres -d aziz_grammydb < backup.sql
```

### Prisma Commands
```bash
# Migration yaratish
npx prisma migrate dev --name migration_name

# Migration deploy (production)
npx prisma migrate deploy

# Studio (UI)
npx prisma studio

# Schema format
npx prisma format
```

---

## 6. KUTILGAN NATIJALAR

### ✅ Normal Holatda:
- **CPU:** 10-30%
- **Memory:** 200-500MB
- **Connections:** 2-15
- **Slow queries:** 0
- **Cache hit ratio:** >90%

### ⚠️  Ogohlantirishlar:
- **CPU:** >50% - sekin query'lar bor
- **Memory:** >800MB - limit oshirish kerak
- **Connections:** >20 - connection leak
- **Dead tuples:** >10000 - VACUUM kerak

### ❌ Muammolar:
- **CPU:** >80% - darhol tekshirish!
- **Memory:** >900MB - restart kerak
- **Connections:** >40 - muammo bor
- **Lock'lar:** >5 - deadlock xavfi

---

## 7. ENVIRONMENT VARIABLES

`.env` faylida:
```env
# Database
DATABASE_URL=postgresql://postgres:12345@localhost:5433/aziz_grammydb

# Prisma
PRISMA_QUERY_ENGINE_LIBRARY=/path/to/prisma

# Node
NODE_ENV=production
```

---

## 8. HELP

### Qo'shimcha Ma'lumot
- Batafsil: `DATABASE_OPTIMIZATION.md`
- Qo'shimcha tuning: `ADVANCED_TUNING.md`
- Monitoring: `database-monitoring.sql`

### Log'lar
```bash
# App log'lari
docker logs aziz_anime -f

# Database log'lari
docker logs aziz_animedb -f

# Ikkisini birga
docker-compose logs -f
```

### Container Ma'lumotlari
```bash
# Container hajmi
docker system df

# Container inspect
docker inspect aziz_animedb

# Resource limits
docker inspect aziz_animedb | grep -A 10 Resources
```

---

## 9. EMERGENCY COMMANDS

### Database Freeze Bo'lsa
```bash
# 1. Container restart
docker restart aziz_animedb

# 2. Agar restart ishlamasa - to'xtatib qayta boshlash
docker stop aziz_animedb
docker start aziz_animedb

# 3. Agar hali ham ishlamasa - rebuild
docker-compose down
docker-compose up -d
```

### Barcha Ulanishlarni O'chirish
```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'aziz_grammydb'
  AND pid <> pg_backend_pid();
```

### Database Reset (EHTIYOTKORLIK!)
```bash
# BACKUP OLING!
docker exec aziz_animedb pg_dump -U postgres aziz_grammydb > emergency_backup.sql

# Reset
docker-compose down -v
docker-compose up -d
npx prisma migrate deploy

# Data restore
docker exec -i aziz_animedb psql -U postgres -d aziz_grammydb < emergency_backup.sql
```

---

## 10. CONTACT va SUPPORT

### Log収集
Muammo haqida xabar berishda shu ma'lumotlarni bering:

```bash
# 1. System info
uname -a
docker --version

# 2. Container stats
docker stats --no-stream

# 3. Database status
bash quick-check.sh > status.txt

# 4. Recent logs
docker logs aziz_animedb --tail 200 > db_logs.txt
docker logs aziz_anime --tail 200 > app_logs.txt
```

---

**© 2026 - Aziz Anime Bot Database Optimization**
