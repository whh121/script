#!/bin/bash
# user_interests CDC作业监控定时任务设置脚本
# 作业ID: 275a6f22da1f5bdf896b9341028b2de0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor_user_interests.py"

echo "=== user_interests CDC监控定时任务设置 ==="
echo "项目目录: $PROJECT_DIR"
echo "监控脚本: $MONITOR_SCRIPT"

# 检查监控脚本是否存在
if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo "❌ 监控脚本不存在: $MONITOR_SCRIPT"
    exit 1
fi

# 检查Python依赖
echo "检查Python依赖..."
python3 -c "import requests, json" 2>/dev/null || {
    echo "❌ Python依赖缺失，请安装: pip3 install requests"
    exit 1
}

# 确保脚本有执行权限
chmod +x "$MONITOR_SCRIPT"

# 生成cron任务
CRON_JOB="*/5 * * * * cd $PROJECT_DIR && python3 scripts/monitor_user_interests.py >> logs/user_interests_cron.log 2>&1"

echo "cron任务内容:"
echo "$CRON_JOB"
echo ""

# 检查是否已存在相同任务
if crontab -l 2>/dev/null | grep -q "monitor_user_interests.py"; then
    echo "⚠️  检测到已存在user_interests监控任务"
    echo "当前cron任务:"
    crontab -l | grep "monitor_user_interests.py" || true
    echo ""
    read -p "是否要替换现有任务? (y/N): " replace
    if [[ "$replace" =~ ^[Yy]$ ]]; then
        # 删除现有任务
        crontab -l 2>/dev/null | grep -v "monitor_user_interests.py" | crontab -
        echo "✅ 已删除现有任务"
    else
        echo "保持现有任务不变"
        exit 0
    fi
fi

# 添加新的cron任务
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "✅ cron任务设置成功!"
echo ""
echo "监控配置:"
echo "- 检查间隔: 每5分钟"
echo "- 日志文件: $PROJECT_DIR/logs/user_interests_monitor_YYYYMMDD.log"
echo "- cron日志: $PROJECT_DIR/logs/user_interests_cron.log"
echo "- 状态文件: $PROJECT_DIR/logs/user_interests_status.json"
echo ""

# 验证cron任务
echo "当前所有cron任务:"
crontab -l | grep -E "(monitor|flink)" || echo "无相关监控任务"
echo ""

# 手动测试一次
echo "执行一次监控测试..."
cd "$PROJECT_DIR"
python3 scripts/monitor_user_interests.py

echo ""
echo "=== 设置完成 ==="
echo "✅ user_interests CDC监控已启动"
echo "📊 Flink Web UI: http://localhost:8081"
echo "📋 作业ID: 275a6f22da1f5bdf896b9341028b2de0"
echo "🔍 监控日志: tail -f $PROJECT_DIR/logs/user_interests_monitor_$(date +%Y%m%d).log" 