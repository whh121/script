#!/bin/bash

# Flink监控脚本启动器
# 使用方式: ./start_monitor.sh [start|stop|restart|status]

SCRIPT_DIR="/home/ubuntu/work/script"
MONITOR_SCRIPT="$SCRIPT_DIR/flink_monitor.py"
PID_FILE="$SCRIPT_DIR/flink_monitor.pid"
LOG_FILE="$SCRIPT_DIR/monitor.log"

case "$1" in
    start)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null 2>&1; then
                echo "监控脚本已在运行 (PID: $PID)"
                exit 1
            else
                rm -f "$PID_FILE"
            fi
        fi
        
        echo "启动Flink监控脚本..."
        cd "$SCRIPT_DIR"
        nohup python3 "$MONITOR_SCRIPT" > "$LOG_FILE" 2>&1 &
        PID=$!
        echo $PID > "$PID_FILE"
        echo "监控脚本已启动 (PID: $PID)"
        echo "日志文件: $LOG_FILE"
        ;;
        
    stop)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null 2>&1; then
                echo "停止监控脚本 (PID: $PID)..."
                kill $PID
                rm -f "$PID_FILE"
                echo "监控脚本已停止"
            else
                echo "监控脚本未运行"
                rm -f "$PID_FILE"
            fi
        else
            echo "监控脚本未运行"
        fi
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
        
    status)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null 2>&1; then
                echo "监控脚本正在运行 (PID: $PID)"
                echo "最近的日志:"
                tail -5 "$LOG_FILE"
            else
                echo "监控脚本未运行 (PID文件存在但进程不存在)"
                rm -f "$PID_FILE"
            fi
        else
            echo "监控脚本未运行"
        fi
        ;;
        
    *)
        echo "使用方式: $0 {start|stop|restart|status}"
        echo ""
        echo "  start   - 启动监控脚本"
        echo "  stop    - 停止监控脚本"
        echo "  restart - 重启监控脚本"
        echo "  status  - 查看监控脚本状态"
        exit 1
        ;;
esac 