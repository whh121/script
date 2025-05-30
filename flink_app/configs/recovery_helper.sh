#!/bin/bash
# Flink作业恢复辅助脚本
# ======================
# 
# 用途: 协助从savepoint恢复Flink作业
# 特性: 自动检测savepoint、提供恢复命令
# 作者: Flink运维团队
# 更新: 2025-05-29

set -e

# 配置变量
FLINK_WEB="http://localhost:8081"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 查找可用的savepoint
find_savepoints() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    log_info "在 $backup_dir 查找savepoint..."
    
    if [ -d "$backup_dir/savepoints" ]; then
        echo
        echo "📁 发现的savepoint目录:"
        ls -la "$backup_dir/savepoints/"
        echo
        
        # 查找具体的savepoint路径
        find "$backup_dir/savepoints" -name "_metadata" 2>/dev/null | while read metadata_file; do
            savepoint_path=$(dirname "$metadata_file")
            echo "✅ 可用savepoint: $savepoint_path"
        done
    else
        log_warn "未找到savepoint目录"
    fi
}

# 显示可用的SQL文件
show_sql_files() {
    log_info "作业SQL文件分类:"
    echo
    
    echo "🔴 当前线上运行的作业SQL:"
    echo "  - flink_app/kafka2doris/scripts/kafka_to_doris_solution_sample.sql"
    echo "    └── 对应作业: Kafka → Doris (client_cold_start)"
    echo "    └── 状态: 正在运行"
    echo
    
    echo "📄 其他可用的作业SQL:"
    echo "  MySQL CDC作业:"
    if [ -d "$PROJECT_ROOT/flink_app/mysql2doris/scripts" ]; then
        ls -la "$PROJECT_ROOT/flink_app/mysql2doris/scripts"/*.sql 2>/dev/null | sed 's/^/    /' || echo "    无SQL文件"
    fi
    echo
    
    echo "  Kafka作业:"
    if [ -d "$PROJECT_ROOT/flink_app/kafka2doris/scripts" ]; then
        ls -la "$PROJECT_ROOT/flink_app/kafka2doris/scripts"/*.sql 2>/dev/null | sed 's/^/    /' || echo "    无SQL文件"
    fi
    echo
    
    echo "🟡 准备部署的新作业:"
    echo "  - flink_app/configs/user_interests_with_real_schema.sql"
    echo "    └── 对应作业: MySQL CDC → Doris (user_interests)"
    echo "    └── 状态: 待部署 (需先安装mysql-cdc连接器)"
    echo
}

# 分析备份目录中的作业信息
analyze_backup_jobs() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir/job_analysis" ]; then
        log_warn "未找到作业分析信息，将提供通用恢复方案"
        return 1
    fi
    
    log_info "读取作业分析信息..."
    
    if [ -f "$backup_dir/job_analysis/job_details.txt" ]; then
        echo
        echo "📋 停机前运行的作业分析:"
        echo "=========================="
        cat "$backup_dir/job_analysis/job_details.txt"
        echo
        
        # 提取推荐的SQL文件
        recommended_sqls=$(grep -A 10 "可能的SQL文件:" "$backup_dir/job_analysis/job_details.txt" | grep "flink_app" || echo "")
        
        if [ -n "$recommended_sqls" ]; then
            echo "🎯 推荐的恢复SQL文件:"
            echo "$recommended_sqls" | while read sql_file; do
                sql_file=$(echo "$sql_file" | sed 's/.*- //')
                if [ -f "$PROJECT_ROOT/$sql_file" ]; then
                    echo "  ✅ $sql_file (文件存在)"
                else
                    echo "  ❌ $sql_file (文件不存在)"
                fi
            done
            echo
        fi
        
        return 0
    else
        return 1
    fi
}

# 分析SQL匹配结果
analyze_sql_matches() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir/sql_analysis" ]; then
        log_warn "未找到SQL匹配分析信息"
        return 1
    fi
    
    log_info "分析SQL匹配结果..."
    
    # 显示匹配报告
    if [ -f "$backup_dir/sql_analysis/sql_match_report.txt" ]; then
        echo
        echo "🔍 SQL内容匹配分析报告:"
        echo "========================"
        cat "$backup_dir/sql_analysis/sql_match_report.txt"
        echo
    fi
    
    return 0
}

# 进行智能组合作业匹配分析
analyze_combined_job_matches() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir/sql_analysis" ]; then
        log_warn "未找到SQL匹配分析信息"
        return 1
    fi
    
    log_info "进行智能组合作业匹配分析..."
    
    # 创建组合分析报告
    echo "# 智能组合作业匹配报告 - $(date)" > "$backup_dir/sql_analysis/combined_match_report.txt"
    echo "# =======================================" >> "$backup_dir/sql_analysis/combined_match_report.txt"
    echo "" >> "$backup_dir/sql_analysis/combined_match_report.txt"
    
    # 收集所有作业特征
    python3 -c "
import os, re, glob

# 收集所有作业的特征
all_job_features = {}
feature_files = glob.glob('$backup_dir/sql_analysis/*_features.txt')

for feature_file in feature_files:
    job_id = os.path.basename(feature_file).replace('_features.txt', '')
    try:
        with open(feature_file, 'r') as f:
            content = f.read()
            # 提取特征部分
            if '特征: ' in content:
                feature_str = content.split('特征: ')[1].strip()
                features = set(feature_str.split('|')) if feature_str else set()
                all_job_features[job_id] = features
    except:
        continue

print(f'发现 {len(all_job_features)} 个作业需要分析')

# SQL文件特征提取
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

# 计算组合匹配度
def calculate_combined_match(all_jobs_features, sql_features):
    # 将所有作业特征合并
    combined_features = set()
    for job_features in all_jobs_features.values():
        combined_features.update(job_features)
    
    if not combined_features or not sql_features:
        return 0, {}
    
    intersection = combined_features.intersection(sql_features)
    union = combined_features.union(sql_features)
    
    # 计算基础匹配度
    base_score = len(intersection) / len(union) if union else 0
    
    # 计算sink表匹配度（关键指标）
    job_sink_tables = {f for f in combined_features if f.startswith('sink_table:')}
    sql_sink_tables = {f for f in sql_features if f.startswith('sink_table:')}
    sink_match_count = len(job_sink_tables.intersection(sql_sink_tables))
    sink_total = len(job_sink_tables)
    
    sink_coverage = sink_match_count / sink_total if sink_total > 0 else 0
    
    # 综合评分: 基础匹配度 + sink表覆盖度权重
    final_score = base_score * 0.6 + sink_coverage * 0.4
    
    match_details = {
        'base_score': base_score,
        'sink_coverage': sink_coverage,
        'sink_matches': sink_match_count,
        'sink_total': sink_total,
        'intersection': sorted(intersection),
        'job_features': sorted(combined_features),
        'sql_features': sorted(sql_features)
    }
    
    return final_score, match_details

print('\\n🎯 组合作业匹配分析:')
print('=' * 60)

best_matches = []
for sql_file in sql_files:
    if os.path.exists(sql_file):
        sql_features = extract_sql_features(sql_file)
        score, details = calculate_combined_match(all_job_features, sql_features)
        
        if score > 0:
            best_matches.append((sql_file, score, details))

# 排序并输出详细分析
best_matches.sort(key=lambda x: x[1], reverse=True)

for sql_file, score, details in best_matches:
    filename = sql_file.split('/')[-1]
    print(f'\\n📄 {filename}:')
    print(f'  综合匹配度: {score:.2f}')
    print(f'  基础匹配度: {details[\"base_score\"]:.2f}')
    print(f'  Sink表覆盖: {details[\"sink_coverage\"]:.2f} ({details[\"sink_matches\"]}/{details[\"sink_total\"]})')
    
    if details['sink_matches'] > 0:
        job_sinks = [f.split(':')[1] for f in details['job_features'] if f.startswith('sink_table:')]
        sql_sinks = [f.split(':')[1] for f in details['sql_features'] if f.startswith('sink_table:')]
        matched_sinks = set(job_sinks).intersection(set(sql_sinks))
        print(f'  匹配的表: {sorted(matched_sinks)}')

if best_matches:
    print(f'\\n🏆 最佳匹配: {best_matches[0][0].split(\"/\")[-1]} (匹配度: {best_matches[0][1]:.2f})')
    
    # 判断匹配质量
    best_score = best_matches[0][1]
    if best_score >= 0.8:
        print('✅ 高置信度匹配 - 强烈推荐使用此SQL文件恢复')
    elif best_score >= 0.6:
        print('✅ 良好匹配 - 推荐使用此SQL文件恢复')
    elif best_score >= 0.4:
        print('⚠️  中等匹配 - 建议验证后使用')
    else:
        print('❌ 低匹配度 - 建议从配置文件重建')
else:
    print('\\n❌ 未找到合适的匹配文件')
"
    
    return 0
}

# 生成基于匹配结果的恢复选项
generate_match_based_recovery() {
    local backup_dir="$1"
    
    echo "🎯 基于SQL匹配的精确恢复方案:"
    echo "========================================="
    echo
    
    if [ ! -d "$backup_dir/sql_analysis" ]; then
        echo "❌ 未找到SQL匹配分析，使用通用方案"
        return 1
    fi
    
    # 处理每个作业的匹配结果
    for match_file in "$backup_dir/sql_analysis"/*_match.txt; do
        if [ -f "$match_file" ]; then
            job_id=$(basename "$match_file" _match.txt)
            
            echo "📋 作业 $job_id 恢复选项:"
            echo "----------------------------------------"
            
            # 读取匹配结果
            match_content=$(cat "$match_file")
            
            # 解析最佳匹配
            best_match=$(echo "$match_content" | grep -A 1 "^---$" | tail -n +2 | head -n 1)
            
            if [ -n "$best_match" ]; then
                sql_file=$(echo "$best_match" | cut -d':' -f1)
                score=$(echo "$best_match" | cut -d':' -f2)
                
                # 判断匹配质量
                match_quality=$(python3 -c "
score = float('$score')
if score >= 0.8:
    print('excellent')
elif score >= 0.6:
    print('good')
elif score >= 0.3:
    print('fair')
else:
    print('poor')
")
                
                echo "🎯 匹配结果: $sql_file (匹配度: $score)"
                echo
                
                case $match_quality in
                    "excellent"|"good")
                        echo "✅ 高置信度匹配! 推荐恢复选项:"
                        echo
                        echo "选项1: 使用匹配的SQL文件恢复 (推荐)"
                        echo "  cd $(dirname "$sql_file")"
                        echo "  flink sql-client -f $(basename "$sql_file")"
                        echo
                        echo "选项2: 使用保存的作业配置恢复"
                        echo "  # 从备份配置重建作业 (需要手动构建SQL)"
                        echo "  # 配置文件: $backup_dir/sql_analysis/${job_id}_config.json"
                        ;;
                    "fair")
                        echo "⚠️  中等匹配度，建议对比验证:"
                        echo
                        echo "选项1: 验证后使用匹配的SQL文件"
                        echo "  # 先检查: cat $sql_file"
                        echo "  # 对比配置: cat $backup_dir/sql_analysis/${job_id}_signature.txt"
                        echo "  cd $(dirname "$sql_file")"
                        echo "  flink sql-client -f $(basename "$sql_file")"
                        echo
                        echo "选项2: 使用保存的作业配置重建 (安全)"
                        echo "  # 从配置文件手动重建SQL"
                        echo "  # 配置参考: $backup_dir/sql_analysis/${job_id}_config.json"
                        ;;
                    "poor")
                        echo "❌ 匹配度较低，建议手动重建:"
                        echo
                        echo "推荐选项: 使用保存的作业配置重建"
                        echo "  # 配置文件: $backup_dir/sql_analysis/${job_id}_config.json"
                        echo "  # 作业签名: $backup_dir/sql_analysis/${job_id}_signature.txt"
                        echo "  # 手动构建对应的SQL文件"
                        echo
                        echo "备选: 检查可能匹配 (需验证)"
                        echo "  # 低匹配: $sql_file"
                        echo "  # 请仔细对比后再使用"
                        ;;
                esac
            else
                echo "❌ 未找到匹配的SQL文件"
                echo
                echo "推荐操作: 从保存的配置重建作业"
                echo "  # 作业配置: $backup_dir/sql_analysis/${job_id}_config.json"
                echo "  # 作业签名: $backup_dir/sql_analysis/${job_id}_signature.txt"
                echo "  # 执行计划: $backup_dir/sql_analysis/${job_id}_plan.json"
            fi
            
            echo
            echo "🔧 配置文件位置:"
            echo "  - 完整配置: $backup_dir/sql_analysis/${job_id}_config.json"
            echo "  - 关键签名: $backup_dir/sql_analysis/${job_id}_signature.txt"  
            echo "  - 执行计划: $backup_dir/sql_analysis/${job_id}_plan.json"
            echo
            echo "═══════════════════════════════════════════"
            echo
        fi
    done
}

# 生成配置文件重建指导
generate_config_rebuild_guide() {
    local backup_dir="$1"
    
    echo "🔨 从配置文件重建作业指导:"
    echo "================================="
    echo
    echo "如果匹配度不高或需要精确重建，可以使用以下方法:"
    echo
    echo "1. 查看保存的作业配置:"
    echo "   cat $backup_dir/sql_analysis/JOB_ID_config.json | jq '.'"
    echo
    echo "2. 提取关键配置信息:"
    echo "   cat $backup_dir/sql_analysis/JOB_ID_signature.txt"
    echo
    echo "3. 根据配置重建SQL文件:"
    echo "   - 从 connector 配置重建 CREATE TABLE 语句"
    echo "   - 从 table.identifier 确定目标表"
    echo "   - 从 topic/hostname 确定数据源"
    echo
    echo "4. 使用模板生成器 (如果适用):"
    echo "   cd $PROJECT_ROOT/flink_app/configs"
    echo "   # 根据配置类型选择合适的模板生成命令"
    echo
    echo "💡 重建提示:"
    echo "  - 保存的配置包含了作业的完整运行时参数"
    echo "  - 可以作为重新编写SQL的准确参考"
    echo "  - 确保新SQL的连接器配置与原配置一致"
}

# 生成动态恢复命令
generate_dynamic_recovery_commands() {
    local backup_dir="$1"
    
    echo "🔧 动态作业恢复方法:"
    echo
    
    # 如果有作业分析信息，使用分析结果
    if analyze_backup_jobs "$backup_dir" >/dev/null 2>&1; then
        echo "📈 基于作业分析的恢复建议:"
        echo "--------------------------------------"
        
        # 从分析文件中提取推荐的SQL
        if [ -f "$backup_dir/job_analysis/job_details.txt" ]; then
            recommended_sqls=$(grep -A 10 "可能的SQL文件:" "$backup_dir/job_analysis/job_details.txt" | grep "flink_app" | sed 's/.*- //' || echo "")
            
            if [ -n "$recommended_sqls" ]; then
                echo "$recommended_sqls" | while read sql_file; do
                    if [ -f "$PROJECT_ROOT/$sql_file" ]; then
                        echo "# 恢复作业: $(basename "$sql_file" .sql)"
                        echo "cd $PROJECT_ROOT/$(dirname "$sql_file")"
                        echo "flink sql-client -f $(basename "$sql_file")"
                        echo
                    fi
                done
            else
                echo "# 未找到匹配的SQL文件，请手动确认"
            fi
        fi
    else
        echo "⚠️  无作业分析信息，提供通用恢复方案:"
        echo "--------------------------------------"
        echo "# 检查可用的SQL文件并手动选择"
        echo "ls -la $PROJECT_ROOT/flink_app/*/scripts/*.sql"
        echo
        echo "# 常见的恢复命令："
        echo "cd $PROJECT_ROOT/flink_app/kafka2doris/scripts"
        echo "flink sql-client -f kafka_to_doris_solution_sample.sql"
        echo
        echo "cd $PROJECT_ROOT/flink_app/mysql2doris/scripts"  
        echo "flink sql-client -f mysql_sync.sql"
        echo
    fi
}

# 检查当前集群状态
check_cluster_status() {
    log_info "检查Flink集群状态..."
    
    if curl -s "$FLINK_WEB/jobs" >/dev/null; then
        log_success "Flink集群运行正常"
        
        # 显示当前运行的作业
        jobs=$(curl -s "$FLINK_WEB/jobs" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    running_jobs = [job for job in data.get('jobs', []) if job['status'] == 'RUNNING']
    if running_jobs:
        print(f'当前运行 {len(running_jobs)} 个作业:')
        for job in running_jobs:
            print(f'  - {job[\"id\"]} ({job[\"status\"]})')
    else:
        print('当前没有运行的作业')
except:
    print('无法解析作业状态')
")
        echo "$jobs"
    else
        log_error "无法连接到Flink集群"
        return 1
    fi
}

# 主功能
main() {
    local backup_dir="$1"
    
    echo "🔄 Flink作业恢复辅助工具"
    echo "=========================="
    echo
    
    # 检查集群状态
    check_cluster_status
    echo
    
    # 如果提供了备份目录，分析作业信息
    if [ -n "$backup_dir" ]; then
        if analyze_backup_jobs "$backup_dir"; then
            echo "✅ 成功读取作业分析信息"
        else
            log_warn "无法读取作业分析信息，将提供通用方案"
        fi
        
        # 查找savepoint
        find_savepoints "$backup_dir"
        echo
    fi
    
    # 显示可用的SQL文件
    show_sql_files
    
    # 分析SQL匹配结果
    analyze_sql_matches "$backup_dir"
    
    # 进行智能组合作业匹配分析
    analyze_combined_job_matches "$backup_dir"
    
    # 生成基于匹配结果的恢复选项
    generate_match_based_recovery "$backup_dir"
    
    # 生成配置文件重建指导
    generate_config_rebuild_guide "$backup_dir"
    
    # 添加通用操作指导
    echo
    echo "🟡 部署新的user_interests作业:"
    echo "--------------------------------------"
    echo "# 确认MySQL CDC连接器已安装"
    echo "cd $PROJECT_ROOT/flink_app/configs"
    echo "./config_validator.py --job mysql2doris --table user_interests"
    echo
    echo "# 部署新作业"
    echo "flink sql-client -f user_interests_with_real_schema.sql"
    echo
    
    echo "📊 验证和监控:"
    echo "--------------------------------------"
    echo "flink list                           # 查看所有作业"
    echo "curl http://localhost:8081/jobs | jq # 查看详细状态"
    echo
    
    echo "💡 恢复建议:"
    echo "1. 优先恢复分析报告中推荐的SQL文件"
    echo "2. 验证恢复的作业数据流正常"
    echo "3. 确认所有作业状态为RUNNING"
    echo "4. 部署新作业前确认现有作业稳定"
}

# 命令行参数处理
case "${1:-}" in
    "")
        echo "Flink作业恢复辅助脚本"
        echo
        echo "用法:"
        echo "  $0 <backup-directory>  - 从指定备份目录恢复"
        echo "  $0 check               - 仅检查集群状态"
        echo "  $0 list                - 列出可用的SQL文件"
        echo
        echo "示例:"
        echo "  $0 /tmp/flink_backup_20250529_083736"
        echo "  $0 check"
        ;;
    "check")
        check_cluster_status
        ;;
    "list")
        show_sql_files
        ;;
    *)
        main "$1"
        ;;
esac 