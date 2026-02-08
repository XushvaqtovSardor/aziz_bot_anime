#!/bin/bash
# Database Optimizatsiyani Qo'llash Script'i
# Bu script barcha o'zgarishlarni ketma-ket qo'llaydi

set -e  # Xato bo'lsa to'xtaydi

echo "=========================================="
echo "🚀 Database Optimizatsiya"
echo "=========================================="
echo ""

# Step 1: Backup
echo "📦 Step 1: Database Backup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
echo "Backup yaratilmoqda: $BACKUP_FILE"

if docker ps | grep -q aziz_animedb; then
    docker exec aziz_animedb pg_dump -U postgres aziz_grammydb > "$BACKUP_FILE"
    echo "✅ Backup saqlandi: $BACKUP_FILE"
else
    echo "⚠️  Database ishlamayapti, backup o'tkazib yuborildi"
fi
echo ""

# Step 2: Stop containers
echo "🛑 Step 2: Container'larni To'xtatish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose down
echo "✅ Container'lar to'xtatildi"
echo ""

# Step 3: Create migration
echo "🔄 Step 3: Migration Yaratish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "package.json" ]; then
    echo "Prisma migration yaratilmoqda..."
    npx prisma migrate dev --name optimize_database_performance
    echo "✅ Migration yaratildi"
else
    echo "⚠️  package.json topilmadi, migration o'tkazib yuborildi"
fi
echo ""

# Step 4: Rebuild containers
echo "🔨 Step 4: Container'larni Rebuild Qilish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose build --no-cache
echo "✅ Build tugadi"
echo ""

# Step 5: Start containers
echo "▶️  Step 5: Container'larni Ishga Tushirish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose up -d
echo "✅ Container'lar ishga tushdi"
echo ""

# Step 6: Wait for database
echo "⏳ Step 6: Database'ni Kutish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Database tayyor bo'lguncha kutilmoqda..."
sleep 10

MAX_TRIES=30
TRIES=0
while ! docker exec aziz_animedb pg_isready -U postgres -d aziz_grammydb > /dev/null 2>&1; do
    TRIES=$((TRIES+1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo "❌ Database vaqtida tayyor bo'lmadi"
        exit 1
    fi
    echo "Kutilmoqda... ($TRIES/$MAX_TRIES)"
    sleep 2
done
echo "✅ Database tayyor"
echo ""

# Step 7: Run migrations (production)
echo "📊 Step 7: Migration Deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker exec aziz_anime npx prisma migrate deploy
echo "✅ Migration deploy tugadi"
echo ""

# Step 8: VACUUM ANALYZE
echo "🧹 Step 8: Database Tozalash va Optimizatsiya"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "VACUUM ANALYZE;"
echo "✅ VACUUM ANALYZE tugadi"
echo ""

# Step 9: Check status
echo "✅ Step 9: Status Tekshirish"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# CPU and Memory
echo "📊 Resource Ishlatish:"
docker stats aziz_animedb --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
echo ""

# Connections
CONN_COUNT=$(docker exec aziz_animedb psql -U postgres -d aziz_grammydb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='aziz_grammydb';")
echo "🔌 Ulanishlar: $CONN_COUNT"
echo ""

# Database size
echo "💾 Database Hajmi:"
docker exec aziz_animedb psql -U postgres -d aziz_grammydb -c "SELECT pg_size_pretty(pg_database_size('aziz_grammydb')) AS size;"
echo ""

echo "=========================================="
echo "🎉 Optimizatsiya Tugadi!"
echo "=========================================="
echo ""
echo "📋 Keyingi Qadamlar:"
echo "  1. Monitoring: bash quick-check.sh"
echo "  2. Log'lar: docker logs aziz_animedb -f"
echo "  3. Stats: watch -n 5 'docker stats aziz_animedb --no-stream'"
echo ""
echo "📁 Backup fayl: $BACKUP_FILE"
echo "   Muammo bo'lsa restore qiling:"
echo "   docker exec -i aziz_animedb psql -U postgres aziz_grammydb < $BACKUP_FILE"
echo ""
echo "✅ Barcha o'zgarishlar qo'llanildi!"
echo "=========================================="
