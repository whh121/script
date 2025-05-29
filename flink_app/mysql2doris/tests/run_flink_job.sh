#!/bin/bash

echo "=== 启动MySQL到Doris同步作业 ==="
echo "开始时间: $(date)"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FLINK_HOME="/home/ubuntu/flink"
SCRIPT_DIR="/home/ubuntu/work/script"

# 检查Flink环境
echo -e "${YELLOW}检查Flink环境...${NC}"
if [ ! -d "$FLINK_HOME" ]; then
    echo -e "${RED}错误: Flink目录不存在: $FLINK_HOME${NC}"
    exit 1
fi

if [ ! -f "$FLINK_HOME/bin/sql-client.sh" ]; then
    echo -e "${RED}错误: Flink SQL客户端不存在${NC}"
    exit 1
fi

# 检查作业文件
if [ ! -f "$SCRIPT_DIR/mysql_to_doris_simple.sql" ]; then
    echo -e "${RED}错误: 作业文件不存在: $SCRIPT_DIR/mysql_to_doris_simple.sql${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Flink环境检查通过${NC}"

# 启动Flink集群（如果未启动）
echo -e "${YELLOW}检查Flink集群状态...${NC}"
FLINK_PROCESSES=$(ps aux | grep -i flink | grep -v grep | wc -l)
if [ $FLINK_PROCESSES -eq 0 ]; then
    echo -e "${YELLOW}启动Flink集群...${NC}"
    cd $FLINK_HOME
    ./bin/start-cluster.sh
    sleep 10
    
    FLINK_PROCESSES=$(ps aux | grep -i flink | grep -v grep | wc -l)
    if [ $FLINK_PROCESSES -eq 0 ]; then
        echo -e "${RED}错误: Flink集群启动失败${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Flink集群运行中${NC}"

# 创建临时SQL文件用于批量执行
echo -e "${YELLOW}准备执行Flink作业...${NC}"
TEMP_SQL="/tmp/flink_job_temp.sql"

# 复制作业文件并添加退出命令
cp "$SCRIPT_DIR/mysql_to_doris_simple.sql" "$TEMP_SQL"
echo "" >> "$TEMP_SQL"
echo "-- 显示所有作业" >> "$TEMP_SQL"
echo "SHOW JOBS;" >> "$TEMP_SQL"
echo "" >> "$TEMP_SQL"
echo "-- 等待一段时间让作业启动" >> "$TEMP_SQL"
echo "-- 注意: 在生产环境中，作业会持续运行" >> "$TEMP_SQL"

echo -e "${GREEN}临时SQL文件创建: $TEMP_SQL${NC}"

# 显示即将执行的作业内容
echo -e "${YELLOW}作业内容预览:${NC}"
echo "=================="
head -20 "$TEMP_SQL"
echo "... (显示前20行)"
echo "=================="
echo ""

# 提示用户
echo -e "${YELLOW}即将在Flink SQL客户端中执行作业...${NC}"
echo -e "${GREEN}作业执行后将持续运行，监控MySQL变化并同步到Doris${NC}"
echo ""
echo "执行方式:"
echo "1. 自动执行（推荐用于测试）"
echo "2. 手动执行（进入交互模式）"
echo ""
read -p "请选择执行方式 (1/2): " choice

case $choice in
    1)
        echo -e "${YELLOW}自动执行模式...${NC}"
        cd $FLINK_HOME
        
        # 使用非交互模式执行
        timeout 60s ./bin/sql-client.sh -f "$TEMP_SQL" || {
            echo -e "${YELLOW}作业已启动，超时退出SQL客户端${NC}"
        }
        ;;
    2)
        echo -e "${YELLOW}手动执行模式...${NC}"
        echo "请在SQL客户端中执行:"
        echo "source '$SCRIPT_DIR/mysql_to_doris_simple.sql';"
        echo ""
        cd $FLINK_HOME
        ./bin/sql-client.sh
        ;;
    *)
        echo -e "${RED}无效选择，退出${NC}"
        exit 1
        ;;
esac

# 检查作业状态
echo ""
echo -e "${YELLOW}检查作业状态...${NC}"
sleep 5

# 通过REST API检查作业状态
echo "正在检查Flink作业状态..."
curl -s http://localhost:8081/jobs 2>/dev/null | python3 -m json.tool 2>/dev/null || {
    echo "无法通过REST API获取作业状态，请手动检查:"
    echo "1. 访问 http://localhost:8081"
    echo "2. 或运行: $FLINK_HOME/bin/flink list"
}

echo ""
echo -e "${GREEN}作业启动完成！${NC}"
echo ""
echo "监控命令:"
echo "1. 查看Flink Web UI: http://localhost:8081"
echo "2. 查看作业列表: $FLINK_HOME/bin/flink list"
echo "3. 查看日志: tail -f $FLINK_HOME/log/flink-*.log"
echo ""
echo "测试同步:"
echo "1. 在MySQL中插入新数据"
echo "2. 检查Doris表中是否出现相应数据"

# 清理临时文件
rm -f "$TEMP_SQL"

echo ""
echo "结束时间: $(date)" 