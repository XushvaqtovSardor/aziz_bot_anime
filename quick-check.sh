#!/bin/bash
# Tez diagnostika - Database muammolarini tekshirish
# Bu script hozirgi holatni tezda ko'rsatadi

echo "=========================================="
echo "🔍 PostgreSQL Tez Diagnostika"
echo "=========================================="
echo ""

# Container ishlab turibmi?
if ! docker ps | grep -q aziz_animedb; then
    echo "❌ Database container ishlamayapti!"
    echo "Start qiling: docker-compose up -d"
    exit 1
fi

echo "✅ Database container ishlayapti"
echo ""

# CPU va Memory
echo "📊 RESOURCE ISHLATISH:"
echo "━━━━━━━━━━━━━━━━━━━"
docker stats aziz_animedb --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
echo ""

# Connection count
echo "🔌 ULANISHLAR:"
echo "━━━━━━━━━━━━━━━━━━━"
CONN_COUNT=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='aziz_grammydb';")
echo "Jami ulanishlar: $CONN_COUNT"

ACTIVE_CONN=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='aziz_grammydb' AND state='active';")
echo "Faol ulanishlar: $ACTIVE_CONN"

IDLE_CONN=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='aziz_grammydb' AND state='idle';")
echo "Idle ulanishlar: $IDLE_CONN"
echo ""

# Slow queries
echo "🐌 SEKIN QUERY'LAR (>5 sek):"
echo "━━━━━━━━━━━━━━━━━━━"
SLOW_QUERIES=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_stat_activity WHERE (now() - query_start) > interval '5 seconds' AND state = 'active' AND datname='aziz_grammydb';")

if [ "$SLOW_QUERIES" -gt 0 ]; then
    echo "⚠️  $SLOW_QUERIES ta sekin query topildi!"
    docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pid, round(EXTRACT(epoch FROM (now() - query_start))::numeric, 2) AS duration_sec, substring(query, 1, 60) AS query FROM pg_stat_activity WHERE (now() - query_start) > interval '5 seconds' AND state = 'active' AND datname='aziz_grammydb';"
else
    echo "✅ Sekin query'lar yo'q"
fi
echo ""

# Database size
echo "💾 DATABASE HAJMI:"
echo "━━━━━━━━━━━━━━━━━━━"
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pg_size_pretty(pg_database_size('aziz_grammydb')) AS size;"
echo ""

# Locks
echo "🔒 LOCK'LAR:"
echo "━━━━━━━━━━━━━━━━━━━"
LOCKS=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_locks WHERE NOT granted;")
if [ "$LOCKS" -gt 0 ]; then
    echo "⚠️  $LOCKS ta lock topildi!"
else
    echo "✅ Lock'lar yo'q"
fi
echo ""

# Dead tuples (vacuum kerakmi?)
echo "🧹 VACUUM HOLATI:"
echo "━━━━━━━━━━━━━━━━━━━"
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT tablename, n_dead_tup, last_autovacuum FROM pg_stat_user_tables WHERE n_dead_tup > 100 ORDER BY n_dead_tup DESC LIMIT 5;"
echo ""

# Tavsiyalar
echo "📋 TAVSIYALAR:"
echo "━━━━━━━━━━━━━━━━━━━"

CPU_PERC=$(docker stats aziz_animedb --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
if (( $(echo "$CPU_PERC > 50" | bc -l) )); then
    echo "⚠️  CPU yuqori ($CPU_PERC%) - monitor-db.sh'ni ishlatib sekin query'larni tekshiring"
fi

if [ "$CONN_COUNT" -gt 15 ]; then
    echo "⚠️  Ko'p ulanishlar ($CONN_COUNT) - connection pool ishlayaptimi?"
fi

if [ "$SLOW_QUERIES" -gt 0 ]; then
    echo "⚠️  Sekin query'lar bor - ularni optimizatsiya qiling yoki timeout qo'ying"
fi

DEAD_TUPLES=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT COALESCE(SUM(n_dead_tup), 0) FROM pg_stat_user_tables;")
if [ "$DEAD_TUPLES" -gt 10000 ]; then
    echo "⚠️  Ko'p dead tuples ($DEAD_TUPLES) - VACUUM ANALYZE kerak"
    echo "   Ishlatish: docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c 'VACUUM ANALYZE;'"
fi

echo ""
echo "=========================================="
echo "To'liq monitoring uchun: bash monitor-db.sh"
echo "Log'lar uchun: docker logs aziz_animedb -f"
echo "=========================================="
