#!/bin/bash
# MySQL CDC连接器安全安装脚本
# ================================
# 
# 用途: 在生产环境安全安装MySQL CDC连接器
# 特性: 检查点保存、作业恢复、回滚保护
# 作者: Flink运维团队
# 更新: 2025-05-29

set -e  # 遇错即停

# 配置变量
FLINK_HOME="/home/ubuntu/flink"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/tmp/flink_backup_$(date +%Y%m%d_%H%M%S)"
CDC_JAR="/tmp/flink-sql-connector-mysql-cdc-3.2.1.jar"
FLINK_WEB="http://localhost:8081"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查前置条件
check_prerequisites() {
    log_info "开始检查前置条件..."
    
    # 检查CDC jar文件
    if [ ! -f "$CDC_JAR" ]; then
        log_error "MySQL CDC连接器文件不存在: $CDC_JAR"
        log_info "请先运行: wget https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.2.1/flink-sql-connector-mysql-cdc-3.2.1.jar -O $CDC_JAR"
        exit 1
    fi
    
    # 检查Flink目录
    if [ ! -d "$FLINK_HOME" ]; then
        log_error "Flink目录不存在: $FLINK_HOME"
        exit 1
    fi
    
    # 检查Flink集群状态
    if ! curl -s "$FLINK_WEB/jobs" >/dev/null; then
        log_error "无法连接Flink集群: $FLINK_WEB"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 获取当前运行的作业
get_running_jobs() {
    log_info "获取当前运行的作业列表..."
    
    JOBS=$(curl -s "$FLINK_WEB/jobs" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for job in data.get('jobs', []):
    if job['status'] == 'RUNNING':
        print(f'{job[\"id\"]}:{job[\"status\"]}')
")
    
    if [ -z "$JOBS" ]; then
        log_info "当前没有运行的作业"
    else
        log_info "当前运行的作业:"
        echo "$JOBS" | while read job; do
            echo "  - $job"
        done
    fi
    
    echo "$JOBS"
}

# 分析当前运行的作业详情
analyze_running_jobs() {
    local jobs="$1"
    log_info "分析当前运行作业的详细信息..."
    
    mkdir -p "$BACKUP_DIR/job_analysis"
    
    echo "# 当前运行作业分析报告 - $(date)" > "$BACKUP_DIR/job_analysis/job_details.txt"
    echo "# ==========================================" >> "$BACKUP_DIR/job_analysis/job_details.txt"
    echo "" >> "$BACKUP_DIR/job_analysis/job_details.txt"
    
    echo "$jobs" | while read job_line; do
        if [ -n "$job_line" ]; then
            job_id=$(echo "$job_line" | cut -d':' -f1)
            log_info "分析作业: $job_id"
            
            # 获取作业详细信息
            job_detail=$(curl -s "$FLINK_WEB/jobs/$job_id")
            echo "$job_detail" > "$BACKUP_DIR/job_analysis/${job_id}_detail.json"
            
            # 解析作业名称和类型
            job_info=$(echo "$job_detail" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    job_name = data.get('name', 'Unknown')
    vertices = data.get('vertices', [])
    
    print(f'作业ID: ${job_id}')
    print(f'作业名称: {job_name}')
    print(f'顶点数量: {len(vertices)}')
    
    # 分析作业类型
    job_type = 'Unknown'
    if 'kafka' in job_name.lower():
        job_type = 'Kafka作业'
    elif 'mysql' in job_name.lower() or 'cdc' in job_name.lower():
        job_type = 'MySQL CDC作业'
    elif 'doris' in job_name.lower():
        job_type = 'Doris相关作业'
    
    print(f'推测类型: {job_type}')
    
    # 查找source和sink信息
    for vertex in vertices:
        vertex_name = vertex.get('name', '')
        if 'source' in vertex_name.lower():
            print(f'Source: {vertex_name}')
        elif 'sink' in vertex_name.lower():
            print(f'Sink: {vertex_name}')
except Exception as e:
    print(f'解析失败: {e}')
")
            
            echo "作业 $job_id:" >> "$BACKUP_DIR/job_analysis/job_details.txt"
            echo "$job_info" | sed 's/^/  /' >> "$BACKUP_DIR/job_analysis/job_details.txt"
            echo "" >> "$BACKUP_DIR/job_analysis/job_details.txt"
            
            # 尝试匹配可能的SQL文件
            possible_sql=$(echo "$job_detail" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    job_name = data.get('name', '').lower()
    vertices = data.get('vertices', [])
    
    # 根据作业特征推断可能的SQL文件
    suggestions = []
    
    # 检查是否是Kafka作业
    has_kafka_source = any('kafka' in v.get('name', '').lower() for v in vertices)
    has_doris_sink = any('doris' in v.get('name', '').lower() for v in vertices)
    
    if has_kafka_source and has_doris_sink:
        suggestions.append('flink_app/kafka2doris/scripts/kafka_to_doris_production.sql')
        suggestions.append('flink_app/kafka2doris/scripts/kafka_to_doris_solution_sample.sql')
    
    # 检查是否是MySQL CDC作业
    has_mysql_source = any('mysql' in v.get('name', '').lower() for v in vertices)
    if has_mysql_source:
        suggestions.append('flink_app/mysql2doris/scripts/mysql_sync.sql')
        suggestions.append('flink_app/mysql2doris/scripts/mysql_content_audit_to_doris.sql')
    
    for suggestion in suggestions:
        print(suggestion)
        
except:
    pass
")
            
            if [ -n "$possible_sql" ]; then
                echo "  可能的SQL文件:" >> "$BACKUP_DIR/job_analysis/job_details.txt"
                echo "$possible_sql" | sed 's/^/    - /' >> "$BACKUP_DIR/job_analysis/job_details.txt"
            fi
            echo "" >> "$BACKUP_DIR/job_analysis/job_details.txt"
        fi
    done
    
    log_success "作业分析完成，报告保存到: $BACKUP_DIR/job_analysis/"
}

# 简化的SQL内容匹配功能
extract_and_match_sql() {
    local jobs="$1"
    log_info "提取当前作业信息并进行SQL匹配..."
    
    mkdir -p "$BACKUP_DIR/sql_analysis"
    
    echo "# SQL匹配分析报告 - $(date)" > "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
    echo "# =================================" >> "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
    echo "" >> "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
    
    echo "$jobs" | while read job_line; do
        if [ -n "$job_line" ]; then
            job_id=$(echo "$job_line" | cut -d':' -f1)
            log_info "分析作业 $job_id..."
            
            # 获取作业详细信息
            job_detail=$(curl -s "$FLINK_WEB/jobs/$job_id")
            echo "$job_detail" > "$BACKUP_DIR/sql_analysis/${job_id}_detail.json"
            
            # 获取作业执行计划
            job_plan=$(curl -s "$FLINK_WEB/jobs/$job_id/plan")
            echo "$job_plan" > "$BACKUP_DIR/sql_analysis/${job_id}_plan.json"
            
            # 从执行计划和作业名称中提取关键特征
            job_features=$(echo "$job_plan" | python3 -c "
import sys, json, re

try:
    data = json.load(sys.stdin)
    plan_nodes = data.get('plan', {}).get('nodes', [])
    
    features = set()
    
    for node in plan_nodes:
        description = node.get('description', '')
        
        # 提取源表信息
        if 'TableSourceScan' in description:
            table_match = re.search(r'table=\[\[default_catalog, default_database, ([^,\]]+)', description)
            if table_match:
                table_name = table_match.group(1)
                features.add(f'source_table:{table_name}')
        
        # 查找连接器相关的关键词
        if 'kafka' in description.lower():
            features.add('connector:kafka')
        if 'mysql' in description.lower() or 'cdc' in description.lower():
            features.add('connector:mysql-cdc')
        if 'doris' in description.lower():
            features.add('connector:doris')
        if 'filesystem' in description.lower() or 'Writer' in description:
            features.add('connector:filesystem')
    
    print('|'.join(sorted(features)))
    
except Exception as e:
    print(f'解析错误: {e}')
")
            
            # 从作业名称中提取目标表信息
            job_name=$(echo "$job_detail" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    job_name = data.get('name', '')
    if 'insert-into_default_catalog.default_database.' in job_name:
        sink_table = job_name.split('.')[-1]
        print(f'sink_table:{sink_table}')
except:
    print('')
")

            # 合并特征
            if [ -n "$job_name" ]; then
                job_features="$job_features|$job_name"
            fi
            
            # 保存作业特征
            echo "作业 $job_id 特征: $job_features" > "$BACKUP_DIR/sql_analysis/${job_id}_features.txt"
            
            # 匹配现有SQL文件
            log_info "匹配作业 $job_id 与现有SQL文件..."
            
            match_result=$(python3 -c "
import os, re

# 作业特征
job_features = set('$job_features'.split('|')) if '$job_features' else set()

# 增强的SQL文件特征提取
def extract_sql_features(sql_file):
    try:
        with open(sql_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        return set()
    
    features = set()
    
    # 检查连接器类型
    if \"'connector' = 'kafka'\" in content:
        features.add('connector:kafka')
    if \"'connector' = 'mysql-cdc'\" in content:
        features.add('connector:mysql-cdc')
    if \"'connector' = 'doris'\" in content:
        features.add('connector:doris')
    if \"'connector' = 'filesystem'\" in content:
        features.add('connector:filesystem')
    
    # 检查源表名（CREATE TABLE）
    source_table_matches = re.findall(r'CREATE TABLE (\w+)', content, re.IGNORECASE)
    for table in source_table_matches:
        features.add(f'source_table:{table}')
    
    # 检查目标表名（INSERT INTO）
    sink_table_matches = re.findall(r'INSERT INTO (\w+)', content, re.IGNORECASE)
    for table in sink_table_matches:
        features.add(f'sink_table:{table}')
    
    return features

# 候选SQL文件
sql_files = [
    '/home/ubuntu/work/script/flink_app/kafka2doris/scripts/kafka_to_doris_production.sql',
    '/home/ubuntu/work/script/flink_app/kafka2doris/scripts/kafka_to_doris_solution_sample.sql',
    '/home/ubuntu/work/script/flink_app/mysql2doris/scripts/mysql_sync.sql',
    '/home/ubuntu/work/script/flink_app/mysql2doris/scripts/mysql_content_audit_to_doris.sql'
]

# 计算匹配度
matches = []
for sql_file in sql_files:
    if os.path.exists(sql_file):
        sql_features = extract_sql_features(sql_file)
        
        if job_features and sql_features:
            intersection = job_features.intersection(sql_features)
            union = job_features.union(sql_features)
            
            # 对sink_table匹配给予更高权重
            sink_table_matches = len([f for f in intersection if f.startswith('sink_table:')])
            if sink_table_matches > 0:
                # 如果sink表匹配，给额外加分
                score = (len(intersection) + sink_table_matches * 0.5) / len(union) if union else 0
            else:
                score = len(intersection) / len(union) if union else 0
        else:
            score = 0
        
        if score > 0:
            matches.append((sql_file, score, sorted(sql_features)))

# 排序并输出
matches.sort(key=lambda x: x[1], reverse=True)

print(f'作业特征: {sorted(job_features)}')
print('---')
for sql_file, score, sql_features in matches:
    print(f'{sql_file}:{score:.2f}:{sql_features}')
")
            
            echo "作业 $job_id 匹配分析:" >> "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
            echo "$match_result" >> "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
            echo "" >> "$BACKUP_DIR/sql_analysis/sql_match_report.txt"
            
            # 保存匹配结果
            echo "$match_result" > "$BACKUP_DIR/sql_analysis/${job_id}_match.txt"
            
            # 保存作业详细描述用于手动重建
            job_description=$(echo "$job_detail" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    vertices = data.get('vertices', [])
    print('作业构成:')
    for vertex in vertices:
        print(f'  - {vertex.get(\"name\", \"Unknown\")}')
except:
    print('无法解析作业描述')
")
            echo "$job_description" > "$BACKUP_DIR/sql_analysis/${job_id}_description.txt"
        fi
    done
    
    log_success "SQL匹配分析完成，报告保存到: $BACKUP_DIR/sql_analysis/"
}

# 创建savepoint
create_savepoints() {
    local jobs="$1"
    log_info "为运行中的作业创建savepoint..."
    
    mkdir -p "$BACKUP_DIR/savepoints"
    
    echo "$jobs" | while read job_line; do
        if [ -n "$job_line" ]; then
            job_id=$(echo "$job_line" | cut -d':' -f1)
            log_info "为作业 $job_id 创建savepoint..."
            
            # 触发savepoint创建
            savepoint_result=$(curl -s -X POST "$FLINK_WEB/jobs/$job_id/savepoints" \
                -H "Content-Type: application/json" \
                -d '{"target-directory": "'$BACKUP_DIR'/savepoints", "cancel-job": false}')
            
            echo "$savepoint_result" > "$BACKUP_DIR/savepoints/${job_id}_trigger.json"
            log_info "Savepoint创建请求已发送: $job_id"
            
            # 等待savepoint完成并记录路径
            sleep 5
            savepoint_status=$(curl -s "$FLINK_WEB/jobs/$job_id/savepoints")
            echo "$savepoint_status" > "$BACKUP_DIR/savepoints/${job_id}_status.json"
        fi
    done
    
    log_info "等待savepoint创建完成..."
    sleep 10
    
    # 记录恢复指令
    echo "# Flink作业恢复命令 - $(date)" > "$BACKUP_DIR/recovery_commands.sh"
    echo "# ================================" >> "$BACKUP_DIR/recovery_commands.sh"
    echo "" >> "$BACKUP_DIR/recovery_commands.sh"
    
    echo "$jobs" | while read job_line; do
        if [ -n "$job_line" ]; then
            job_id=$(echo "$job_line" | cut -d':' -f1)
            
            # 尝试从状态文件中提取savepoint路径
            if [ -f "$BACKUP_DIR/savepoints/${job_id}_status.json" ]; then
                savepoint_path=$(cat "$BACKUP_DIR/savepoints/${job_id}_status.json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'savepoints' in data and len(data['savepoints']) > 0:
        latest = data['savepoints'][-1]
        if 'location' in latest:
            print(latest['location'])
except:
    pass
" 2>/dev/null || echo "")
            
                if [ -n "$savepoint_path" ]; then
                    echo "# 恢复作业 $job_id" >> "$BACKUP_DIR/recovery_commands.sh"
                    echo "flink run -s $savepoint_path <原作业jar路径>" >> "$BACKUP_DIR/recovery_commands.sh"
                    echo "" >> "$BACKUP_DIR/recovery_commands.sh"
                else
                    echo "# 恢复作业 $job_id (需要手动查找savepoint路径)" >> "$BACKUP_DIR/recovery_commands.sh"
                    echo "# 在 $BACKUP_DIR/savepoints/ 目录查找savepoint" >> "$BACKUP_DIR/recovery_commands.sh"
                    echo "flink run -s <savepoint-path> <原作业jar路径>" >> "$BACKUP_DIR/recovery_commands.sh"
                    echo "" >> "$BACKUP_DIR/recovery_commands.sh"
                fi
            fi
        fi
    done
}

# 停止作业
stop_jobs() {
    local jobs="$1"
    log_info "停止运行中的作业..."
    
    echo "$jobs" | while read job_line; do
        if [ -n "$job_line" ]; then
            job_id=$(echo "$job_line" | cut -d':' -f1)
            log_info "停止作业: $job_id"
            
            # 使用cancel来停止作业（保持savepoint）
            curl -s -X PATCH "$FLINK_WEB/jobs/$job_id" >/dev/null
        fi
    done
    
    # 等待作业完全停止
    log_info "等待作业停止..."
    sleep 5
}

# 备份当前配置
backup_config() {
    log_info "备份当前Flink配置..."
    
    mkdir -p "$BACKUP_DIR/config"
    cp -r "$FLINK_HOME/conf"/* "$BACKUP_DIR/config/"
    
    if [ -d "$FLINK_HOME/lib" ]; then
        mkdir -p "$BACKUP_DIR/lib"
        cp "$FLINK_HOME/lib"/*.jar "$BACKUP_DIR/lib/" 2>/dev/null || true
    fi
    
    log_success "配置备份完成: $BACKUP_DIR"
}

# 安装MySQL CDC连接器
install_connector() {
    log_info "安装MySQL CDC连接器..."
    
    # 复制连接器到lib目录
    cp "$CDC_JAR" "$FLINK_HOME/lib/"
    
    # 验证文件
    if [ -f "$FLINK_HOME/lib/flink-sql-connector-mysql-cdc-3.2.1.jar" ]; then
        log_success "连接器安装成功"
    else
        log_error "连接器安装失败"
        exit 1
    fi
}

# 重启Flink集群
restart_cluster() {
    log_info "重启Flink集群..."
    
    # 停止集群
    log_info "停止Flink集群..."
    "$FLINK_HOME/bin/stop-cluster.sh"
    
    # 等待完全停止
    sleep 5
    
    # 启动集群
    log_info "启动Flink集群..."
    "$FLINK_HOME/bin/start-cluster.sh"
    
    # 等待集群就绪
    log_info "等待集群启动..."
    sleep 10
    
    # 验证集群状态
    if curl -s "$FLINK_WEB/jobs" >/dev/null; then
        log_success "Flink集群重启成功"
    else
        log_error "Flink集群启动失败"
        exit 1
    fi
}

# 验证连接器安装
verify_installation() {
    log_info "验证MySQL CDC连接器安装..."
    
    cd "$SCRIPT_DIR"
    if python3 config_validator.py --job mysql2doris --table user_interests; then
        log_success "MySQL CDC连接器验证成功"
    else
        log_error "MySQL CDC连接器验证失败"
        return 1
    fi
}

# 主安装流程
main_install() {
    log_info "开始MySQL CDC连接器安装流程..."
    echo
    
    # 1. 检查前置条件
    check_prerequisites
    echo
    
    # 2. 获取运行中的作业
    RUNNING_JOBS=$(get_running_jobs)
    echo
    
    # 3. 分析作业详情
    analyze_running_jobs "$RUNNING_JOBS"
    echo
    
    # 4. 提取SQL内容并进行匹配
    extract_and_match_sql "$RUNNING_JOBS"
    echo
    
    # 5. 用户确认
    if [ -n "$RUNNING_JOBS" ]; then
        log_warn "检测到运行中的作业，安装过程将会停止这些作业"
        echo "继续安装将会:"
        echo "  1. 为每个作业创建savepoint"
        echo "  2. 停止所有运行中的作业"
        echo "  3. 重启Flink集群"
        echo "  4. 需要手动恢复作业"
        echo
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
    
    # 6. 备份配置
    backup_config
    echo
    
    # 7. 创建savepoint
    if [ -n "$RUNNING_JOBS" ]; then
        create_savepoints "$RUNNING_JOBS"
        echo
        
        # 8. 停止作业
        stop_jobs "$RUNNING_JOBS"
        echo
    fi
    
    # 9. 安装连接器
    install_connector
    echo
    
    # 10. 重启集群
    restart_cluster
    echo
    
    # 11. 验证安装
    if verify_installation; then
        log_success "🎉 MySQL CDC连接器安装完成!"
        echo
        echo "📋 接下来的操作步骤:"
        echo
        echo "🔴 1. 恢复线上作业 (优先级最高!)"
        echo "   cd /home/ubuntu/work/script/flink_app/kafka2doris/scripts"
        echo "   flink sql-client -f kafka_to_doris_solution_sample.sql"
        echo
        if [ -n "$RUNNING_JOBS" ]; then
            echo "   📄 详细恢复指令: cat $BACKUP_DIR/recovery_commands.sh"
            echo "   📁 Savepoint位置: $BACKUP_DIR/savepoints/"
            echo
        fi
        echo "🟡 2. 部署新的user_interests作业 (在恢复现有作业后)"
        echo "   cd /home/ubuntu/work/script/flink_app/configs"
        echo "   flink sql-client -f user_interests_with_real_schema.sql"
        echo
        echo "📊 3. 验证所有作业状态"
        echo "   flink list"
        echo "   curl http://localhost:8081/jobs"
        echo
        echo "🆘 4. 如果需要恢复帮助"
        echo "   ./recovery_helper.sh $BACKUP_DIR"
    else
        log_error "安装验证失败，请检查日志"
        echo
        echo "🔧 回滚操作:"
        echo "  1. 恢复配置: cp -r $BACKUP_DIR/config/* $FLINK_HOME/conf/"
        echo "  2. 恢复连接器: cp $BACKUP_DIR/lib/* $FLINK_HOME/lib/"
        echo "  3. 重启集群: $FLINK_HOME/bin/stop-cluster.sh && $FLINK_HOME/bin/start-cluster.sh"
        exit 1
    fi
}

# 检查命令行参数
case "${1:-}" in
    "install")
        main_install
        ;;
    "verify")
        verify_installation
        ;;
    "backup")
        backup_config
        ;;
    *)
        echo "MySQL CDC连接器安装脚本"
        echo
        echo "用法:"
        echo "  $0 install  - 安装MySQL CDC连接器"
        echo "  $0 verify   - 验证连接器安装"
        echo "  $0 backup   - 仅备份配置"
        echo
        echo "注意事项:"
        echo "  - 安装前请确保已下载连接器文件到 $CDC_JAR"
        echo "  - 安装过程会重启Flink集群，影响运行中的作业"
        echo "  - 会自动创建savepoint用于作业恢复"
        echo "  - 建议在业务低峰期执行"
        ;;
esac 