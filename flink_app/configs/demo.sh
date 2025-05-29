#!/bin/bash
# Flink配置模板系统演示脚本
# ==============================
# 
# 演示如何使用配置模板系统生成Flink作业
# 包括schema检测、配置生成、SQL生成等完整流程

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Flink配置模板系统演示"
echo "========================="
echo "项目目录: $PROJECT_DIR"
echo "配置目录: $SCRIPT_DIR"
echo ""

# 函数: 打印分隔线
print_separator() {
    echo "----------------------------------------"
}

# 函数: 检查依赖
check_dependencies() {
    echo "📋 检查系统依赖..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python3 未安装"
        exit 1
    fi
    echo "✅ Python3: $(python3 --version)"
    
    # 检查必要的Python包
    echo "📦 检查Python依赖包..."
    python3 -c "import yaml" 2>/dev/null || {
        echo "❌ PyYAML 未安装，请执行: pip install PyYAML"
        echo "   或使用以下命令安装:"
        echo "   pip install PyYAML mysql-connector-python pymysql"
        exit 1
    }
    echo "✅ PyYAML 已安装"
    
    # 检查Flink
    if command -v flink &> /dev/null; then
        echo "✅ Flink: $(flink --version 2>/dev/null | head -1)"
    else
        echo "⚠️  Flink CLI 未找到，请确保Flink已正确安装"
    fi
    
    echo ""
}

# 函数: 展示配置模板
show_template_structure() {
    echo "🏗️  配置模板结构展示..."
    
    echo "配置文件结构:"
    tree "$SCRIPT_DIR" 2>/dev/null || {
        echo "configs/"
        echo "├── job_template.yaml       # 主配置模板"
        echo "├── config_generator.py     # 配置生成器"
        echo "├── schema_detector.py      # Schema检测器"
        echo "├── examples/               # 配置示例"
        echo "└── README.md              # 详细文档"
    }
    echo ""
    
    echo "支持的作业类型:"
    echo "- mysql2doris: MySQL CDC 到 Doris"
    echo "- kafka2doris: Kafka 到 Doris"
    echo ""
    
    echo "支持的环境:"
    echo "- prod: 生产环境"
    echo "- test: 测试环境"
    echo "- dev: 开发环境"
    echo ""
}

# 函数: 演示Schema检测 (使用模拟数据)
demo_schema_detection() {
    echo "🔍 Schema检测演示..."
    print_separator
    
    echo "1. 检测MySQL表结构 (模拟):"
    echo "命令示例:"
    echo "python3 schema_detector.py \\"
    echo "  --type mysql \\"
    echo "  --host xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com \\"
    echo "  --username content-ro \\"
    echo "  --password \"k5**^k12o\" \\"
    echo "  --database content_data_20250114 \\"
    echo "  --table content_audit_record"
    echo ""
    
    echo "预期输出示例:"
    cat << 'EOF'
    id BIGINT COMMENT '主键ID',
    content_id BIGINT COMMENT '内容ID',
    audit_status INT COMMENT '审核状态',
    audit_result STRING COMMENT '审核结果',
    audit_time TIMESTAMP(3) COMMENT '审核时间',
    created_at TIMESTAMP(3) COMMENT '创建时间',
    updated_at TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id) NOT ENFORCED
EOF
    echo ""
    
    echo "2. 检测Doris表结构 (模拟):"
    echo "命令示例:"
    echo "python3 schema_detector.py \\"
    echo "  --type doris \\"
    echo "  --host 172.31.0.82 \\"
    echo "  --port 9030 \\"
    echo "  --username root \\"
    echo "  --password \"JzyZqbx!309\" \\"
    echo "  --database xme_dw_ods \\"
    echo "  --table xme_ods_content_content_audit_record_di"
    echo ""
}

# 函数: 演示配置生成
demo_config_generation() {
    echo "⚙️  配置生成演示..."
    print_separator
    
    echo "1. 生成MySQL2Doris生产环境配置:"
    echo "python3 config_generator.py --job mysql2doris --env prod"
    echo ""
    
    echo "2. 生成Kafka2Doris测试环境配置:"
    echo "python3 config_generator.py --job kafka2doris --env test"
    echo ""
    
    # 实际生成一个示例SQL (使用现有模板)
    echo "3. 实际生成示例SQL文件..."
    if [ -f "$SCRIPT_DIR/job_template.yaml" ]; then
        echo "尝试生成SQL文件..."
        cd "$SCRIPT_DIR"
        
        # 生成SQL文件
        python3 config_generator.py --job mysql2doris --env prod --output demo_mysql2doris_prod.sql 2>/dev/null || {
            echo "⚠️  生成失败，可能需要安装依赖包"
            echo "   请执行: pip install PyYAML"
        }
        
        if [ -f "demo_mysql2doris_prod.sql" ]; then
            echo "✅ 成功生成示例SQL文件: demo_mysql2doris_prod.sql"
            echo ""
            echo "生成的SQL文件内容预览:"
            head -20 demo_mysql2doris_prod.sql
            echo "... (完整内容请查看文件)"
            echo ""
        fi
    else
        echo "⚠️  job_template.yaml 文件不存在"
    fi
}

# 函数: 展示最佳实践
show_best_practices() {
    echo "📚 最佳实践建议..."
    print_separator
    
    echo "1. 配置管理:"
    echo "   - 使用Git管理配置文件"
    echo "   - 敏感信息使用环境变量"
    echo "   - 定期备份schema缓存"
    echo ""
    
    echo "2. 环境隔离:"
    echo "   - 生产和测试使用不同配置"
    echo "   - 检查点目录按环境隔离"
    echo "   - 消费者组按环境命名"
    echo ""
    
    echo "3. 性能优化:"
    echo "   - 根据数据量调整并行度"
    echo "   - 合理设置检查点间隔"
    echo "   - 优化批量写入大小"
    echo ""
    
    echo "4. 监控告警:"
    echo "   - 配置合适的作业名称"
    echo "   - 使用统一的告警webhook"
    echo "   - 定期检查作业状态"
    echo ""
}

# 函数: 展示项目结构对比
show_before_after() {
    echo "📊 项目结构优化对比..."
    print_separator
    
    echo "优化前 (传统方式):"
    echo "❌ 手写SQL文件，容易出错"
    echo "❌ 配置分散，难以管理"
    echo "❌ 环境配置混乱"
    echo "❌ 缺乏标准化规范"
    echo ""
    
    echo "优化后 (模板配置):"
    echo "✅ YAML配置，清晰易读"
    echo "✅ 自动生成SQL，减少错误"
    echo "✅ 多环境统一管理"
    echo "✅ 标准化配置规范"
    echo "✅ Schema自动检测"
    echo "✅ 类型自动映射"
    echo ""
    
    echo "优势总结:"
    echo "- 提高开发效率 📈"
    echo "- 减少配置错误 🛡️"
    echo "- 统一管理规范 📋"
    echo "- 便于维护升级 🔧"
    echo ""
}

# 函数: 展示使用流程
show_workflow() {
    echo "🔄 完整使用流程..."
    print_separator
    
    echo "步骤1: 检测数据库表结构"
    echo "python3 schema_detector.py --type mysql --host ... --table ..."
    echo ""
    
    echo "步骤2: 编辑配置模板"
    echo "vi job_template.yaml  # 根据需求调整配置"
    echo ""
    
    echo "步骤3: 生成Flink SQL"
    echo "python3 config_generator.py --job mysql2doris --env prod"
    echo ""
    
    echo "步骤4: 部署运行作业"
    echo "cd /home/ubuntu/work/script"
    echo "flink sql-client -f flink_app/mysql2doris/scripts/mysql2doris_prod_generated.sql"
    echo ""
    
    echo "步骤5: 配置监控告警"
    echo "# 自动生成的监控脚本"
    echo "./monitor_mysql2doris_prod.sh"
    echo ""
}

# 函数: 清理演示文件
cleanup_demo_files() {
    echo "🧹 清理演示文件..."
    cd "$SCRIPT_DIR"
    
    # 删除演示生成的文件
    [ -f "demo_mysql2doris_prod.sql" ] && rm -f demo_mysql2doris_prod.sql
    [ -f "monitor_mysql2doris_prod.sh" ] && rm -f monitor_mysql2doris_prod.sh
    
    echo "✅ 清理完成"
    echo ""
}

# 主函数
main() {
    echo "开始演示..."
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 展示模板结构
    show_template_structure
    
    # Schema检测演示
    demo_schema_detection
    
    # 配置生成演示
    demo_config_generation
    
    # 最佳实践
    show_best_practices
    
    # 前后对比
    show_before_after
    
    # 使用流程
    show_workflow
    
    # 清理文件
    cleanup_demo_files
    
    echo "🎉 演示完成！"
    echo ""
    echo "📖 更多信息请查看:"
    echo "   - 详细文档: flink_app/configs/README.md"
    echo "   - 配置模板: flink_app/configs/job_template.yaml"
    echo "   - 配置示例: flink_app/configs/examples/"
    echo ""
    echo "🚀 立即开始使用:"
    echo "   cd flink_app/configs"
    echo "   python3 config_generator.py --job mysql2doris --env prod"
    echo ""
}

# 运行主函数
main "$@" 