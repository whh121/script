#!/bin/bash

# 设置监控脚本的定时任务
# 功能: 配置crontab自动运行监控检查
# 优化: 日志统一管理到logs目录，减少频繁报警

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MONITOR_SCRIPT="$SCRIPT_DIR/mysql_doris_sync_monitor.sh"
LOG_DIR="$PROJECT_DIR/logs"

echo "配置MySQL到Doris同步监控定时任务..."

# 确保脚本有执行权限
chmod +x "$MONITOR_SCRIPT"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 创建新的crontab配置
CRON_FILE="/tmp/monitor_crontab"

cat > "$CRON_FILE" << EOF
# MySQL到Doris数据同步监控定时任务

# 每5分钟执行轻量级健康检查 (不发送正常状态报警)
*/5 * * * * $MONITOR_SCRIPT health >> $LOG_DIR/cron_\$(date +\%Y\%m\%d).log 2>&1

# 每15分钟执行一次完整监控检查 (只在异常时报警)
*/15 * * * * $MONITOR_SCRIPT monitor >> $LOG_DIR/cron_\$(date +\%Y\%m\%d).log 2>&1

# 每天早上8:00发送日报 (专门的日报任务)
0 8 * * 1-5 $MONITOR_SCRIPT monitor >> $LOG_DIR/cron_\$(date +\%Y\%m\%d).log 2>&1

# 每周日凌晨2点清理旧日志文件
0 2 * * 0 $MONITOR_SCRIPT cleanup >> $LOG_DIR/cron_\$(date +\%Y\%m\%d).log 2>&1

EOF

# 安装crontab配置
crontab "$CRON_FILE"

# 清理临时文件
rm "$CRON_FILE"

echo "定时任务配置完成！"
echo ""
echo "当前crontab配置:"
crontab -l
echo ""
echo "监控任务说明:"
echo "  - 每5分钟: 轻量级健康检查 (不发送正常报警)"
echo "  - 每15分钟: 完整监控检查 (异常时报警)"  
echo "  - 每天8点: 发送日报 (仅工作日)"
echo "  - 每周日: 清理旧日志文件"
echo ""
echo "日志目录: $LOG_DIR/"
echo "  - 监控日志: monitor_YYYYMMDD.log"
echo "  - 定时任务日志: cron_YYYYMMDD.log"
echo "  - 自动保留: 7天" 