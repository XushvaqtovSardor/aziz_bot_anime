-- Database Performance Monitoring Scripts
-- Bu script'larni psql yoki pgAdmin orqali ishlatish mumkin

-- 1. CPU yuqori ishlatuvchi query'larni topish
-- pg_stat_statements extension kerak (postgresql.conf'da yoqilgan)
SELECT 
  substring(query, 1, 100) AS short_query,
  calls,
  total_exec_time / 1000 AS total_exec_seconds,
  mean_exec_time / 1000 AS mean_exec_seconds,
  max_exec_time / 1000 AS max_exec_seconds,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- 2. Sekin query'larni monitoring qilish
SELECT 
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query,
  state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds'
  AND state = 'active';

-- 3. Database ulanishlarni tekshirish
SELECT 
  count(*) as total_connections,
  count(*) FILTER (WHERE state = 'active') as active_connections,
  count(*) FILTER (WHERE state = 'idle') as idle_connections
FROM pg_stat_activity
WHERE datname = 'aziz_grammydb';

-- 4. Lock'larni tekshirish (deadlock muammolari uchun)
SELECT 
  pg_stat_activity.pid,
  pg_stat_activity.query,
  pg_locks.mode,
  pg_locks.granted
FROM pg_locks
JOIN pg_stat_activity ON pg_locks.pid = pg_stat_activity.pid
WHERE NOT pg_locks.granted
ORDER BY pg_stat_activity.query_start;

-- 5. Index ishlatilmayotgan table'larni topish
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;

-- 6. Cache hit ratio (>90% bo'lishi kerak)
SELECT 
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 as cache_hit_ratio
FROM pg_statio_user_tables;

-- 7. Eng ko'p o'qiladigan table'lar
SELECT 
  schemaname,
  tablename,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  n_tup_ins,
  n_tup_upd,
  n_tup_del
FROM pg_stat_user_tables
ORDER BY seq_scan + idx_scan DESC
LIMIT 10;

-- 8. Table bloat (keraksiz joy) tekshirish
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  n_dead_tup,
  n_live_tup,
  round((n_dead_tup::float / NULLIF(n_live_tup + n_dead_tup, 0)) * 100) as dead_percentage
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- 9. Vacuum va Analyze kerak bo'lgan table'lar
SELECT
  schemaname,
  tablename,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  n_dead_tup
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
  OR last_autovacuum IS NULL
ORDER BY n_dead_tup DESC;

-- 10. Database hajmini tekshirish
SELECT 
  pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datname = 'aziz_grammydb';
