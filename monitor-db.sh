#!/bin/bash
# Database Performance Monitoring Script
# Ushbu script database holatini tekshiradi

echo "======================================"
echo "PostgreSQL Performance Monitor"
echo "======================================"
echo ""

# Database ga ulanish
PGPASSWORD=12345 psql -h localhost -p 5433 -U postgres -d aziz_grammydb << 'EOF'

-- CPU ishlatayotgan query'lar
\echo '1. Eng ko\'p CPU ishlatayotgan query\'lar:'
\echo '----------------------------------------'
SELECT 
  substring(query, 1, 80) AS query,
  calls,
  round(total_exec_time::numeric / 1000, 2) AS total_sec,
  round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

\echo ''
\echo '2. Hozirgi faol ulanishlar:'
\echo '----------------------------------------'
SELECT 
  count(*) as total,
  count(*) FILTER (WHERE state = 'active') as active,
  count(*) FILTER (WHERE state = 'idle') as idle
FROM pg_stat_activity
WHERE datname = 'aziz_grammydb';

\echo ''
\echo '3. Sekin ishlayotgan query\'lar (>5 sekund):'
\echo '----------------------------------------'
SELECT 
  pid,
  round(EXTRACT(epoch FROM (now() - query_start))::numeric, 2) AS duration_sec,
  substring(query, 1, 80) AS query
FROM pg_stat_activity
WHERE (now() - query_start) > interval '5 seconds'
  AND state = 'active'
  AND datname = 'aziz_grammydb';

\echo ''
\echo '4. Cache hit ratio (90%+ bo\'lishi kerak):'
\echo '----------------------------------------'
SELECT 
  round((sum(heap_blks_hit)::float / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0)) * 100, 2) as cache_hit_ratio
FROM pg_statio_user_tables;

\echo ''
\echo '5. Database hajmi:'
\echo '----------------------------------------'
SELECT 
  pg_size_pretty(pg_database_size('aziz_grammydb')) AS size;

\echo ''
\echo '6. Vacuum kerak bo\'lgan table\'lar:'
\echo '----------------------------------------'
SELECT
  tablename,
  n_dead_tup,
  last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 100
ORDER BY n_dead_tup DESC
LIMIT 5;

EOF

echo ""
echo "======================================"
echo "Monitoring tugadi"
echo "======================================"
