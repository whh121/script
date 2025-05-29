# Flink分离模板系统

## 🎯 概述

这是一个全新的Flink配置模板系统，将**配置管理**和**SQL模板**完全分离，提供了更加灵活、可维护的Flink作业开发方式。

### 🆚 与原系统对比

| 特性 | 原系统 (job_template.yaml) | 新系统 (分离模板) |
|------|---------------------------|------------------|
| 配置方式 | 配置和模板混合 | 配置和模板分离 |
| 模板引擎 | Python字符串替换 | Jinja2模板引擎 |
| 环境管理 | 重复配置 | 独立环境文件 |
| 扩展性 | 有限 | 高度可扩展 |
| 维护性 | 较难 | 简单直观 |
| 复用性 | 低 | 高 |

## 📁 系统架构

```
configs/
├── environments/              # 环境配置
│   ├── prod.yaml             # 生产环境
│   ├── test.yaml             # 测试环境
│   └── dev.yaml              # 开发环境
├── jobs/                     # 作业定义
│   ├── mysql2doris.yaml      # MySQL CDC作业
│   └── kafka2doris.yaml      # Kafka流作业
├── templates/                # SQL模板
│   ├── mysql_cdc_source.sql.jinja2
│   ├── kafka_source.sql.jinja2
│   ├── doris_sink.sql.jinja2
│   ├── mysql2doris_complete.sql.jinja2
│   └── kafka2doris_complete.sql.jinja2
├── template_generator.py     # 模板生成器 v2.0
├── template_demo.sh          # 系统演示脚本
└── README_TEMPLATE_SYSTEM.md # 本文档
```

## 🚀 快速开始

### 1. 安装依赖
```bash
pip install PyYAML Jinja2
```

### 2. 生成作业
```bash
# MySQL CDC到Doris (生产环境)
python3 template_generator.py \
  --job mysql2doris \
  --env prod \
  --source-table content_audit_record \
  --target-table xme_ods_content_audit_record_di

# Kafka到Doris (测试环境)
python3 template_generator.py \
  --job kafka2doris \
  --env test \
  --source-topic client_cold_start \
  --target-table client_cold_start_test
```

### 3. 运行演示
```bash
./template_demo.sh
```

## 🌍 环境配置

### 配置文件结构
环境配置文件包含环境相关的所有参数，但**不包含业务逻辑**：

```yaml
# environments/prod.yaml
environment: "prod"

# 集群配置
cluster:
  name: "flink-prod-cluster"
  parallelism: 8
  taskmanager:
    memory: "4g"
    slots: 2

# 数据源配置
sources:
  mysql:
    host: "xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com"
    port: 3306
    username: "content-ro"
    password: "k5**^k12o"
    databases:
      content: "content_data_20250114"
      behavior: "content_behavior"
    server_id_range: "5001-5999"
  
  kafka:
    brokers:
      - "b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092"
      - "b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092"
      - "b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092"

# 数据目标配置
sinks:
  doris:
    fenodes: "172.31.0.82:8030"
    username: "root"
    password: "JzyZqbx!309"
    databases:
      ods: "xme_dw_ods"
      dw: "xme_dw"
    load_properties:
      batch_size: "2000"
      batch_interval: "5s"
```

### 环境差异化配置

| 环境 | 并行度 | 批量大小 | 检查点间隔 | 数据库 |
|------|--------|----------|------------|--------|
| prod | 8 | 2000 | 60s | 生产RDS |
| test | 4 | 500 | 120s | 测试RDS |
| dev | 2 | 100 | 300s | 本地DB |

## ⚙️ 作业定义

作业定义文件包含**数据流逻辑**，但**不包含环境配置**：

```yaml
# jobs/mysql2doris.yaml
job:
  name: "mysql2doris"
  type: "stream"
  description: "MySQL CDC实时同步到Doris数据仓库"

dataflow:
  source:
    type: "mysql-cdc"
    database: "{{ source_database }}"
    table: "{{ source_table }}"
    cdc:
      startup_mode: "{{ startup_mode | default('initial') }}"
      server_id: "{{ server_id }}"
      debezium:
        snapshot_mode: "{{ snapshot_mode | default('initial') }}"
        decimal_handling_mode: "string"
  
  transform:
    field_mapping:
      # 字段映射 (可选)
    filter:
      # 数据过滤 (可选)
  
  sink:
    type: "doris"
    database: "{{ target_database }}"
    table: "{{ target_table }}"
    table_model: "UNIQUE"
    load:
      format: "json"
      mode: "stream_load"
      enable_delete: true

templates:
  source_sql: "mysql_cdc_source.sql.jinja2"
  sink_sql: "doris_sink.sql.jinja2"
  complete_sql: "mysql2doris_complete.sql.jinja2"
```

## 📝 SQL模板

使用**Jinja2模板引擎**，支持强大的模板语法：

### 基本语法
- **变量替换**: `{{ variable }}`
- **条件判断**: `{% if condition %} ... {% endif %}`
- **循环**: `{% for item in list %} ... {% endfor %}`
- **模板包含**: `{% include 'template.sql.jinja2' %}`
- **过滤器**: `{{ value | filter }}`

### 示例模板
```sql
{# MySQL CDC源表模板 #}
CREATE TABLE {{ source_table_name }} (
{%- for field in schema.source_fields %}
    {{ field.name }} {{ field.flink_type }}
    {%- if field.comment %} COMMENT '{{ field.comment }}'{% endif %}
    {%- if not loop.last %},{% endif %}
{%- endfor %}
{%- if schema.primary_keys %},
    PRIMARY KEY ({{ schema.primary_keys | join(', ') }}) NOT ENFORCED
{%- endif %}
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '{{ env.sources.mysql.host }}',
    'port' = '{{ env.sources.mysql.port }}',
    'username' = '{{ env.sources.mysql.username }}',
    'password' = '{{ env.sources.mysql.password }}',
    'database-name' = '{{ env.sources.mysql.databases[source_database] }}',
    'table-name' = '{{ source_table }}',
    'server-id' = '{{ server_id }}'
);
```

## 🔧 模板生成器

### 命令行参数

```bash
python3 template_generator.py [OPTIONS]

必需参数:
  --job {mysql2doris,kafka2doris}  作业类型
  --env {prod,test,dev}            环境

MySQL作业参数:
  --source-table TEXT              源表名 (必需)
  --target-table TEXT              目标表名
  --source-db TEXT                 源数据库名 (默认: content)
  --target-db TEXT                 目标数据库名 (默认: ods)
  --server-id TEXT                 MySQL CDC Server ID

Kafka作业参数:
  --source-topic TEXT              Kafka源Topic (必需)
  --target-table TEXT              目标表名
  --consumer-group TEXT            Kafka消费者组

输出选项:
  --output TEXT                    输出文件路径
  --configs-dir TEXT               配置目录路径
```

### 使用示例

```bash
# 基本用法
python3 template_generator.py \
  --job mysql2doris \
  --env prod \
  --source-table content_audit_record \
  --target-table xme_ods_content_audit_record_di

# 自定义参数
python3 template_generator.py \
  --job kafka2doris \
  --env test \
  --source-topic client_cold_start \
  --target-table client_cold_start_test \
  --consumer-group my_consumer_group \
  --output /tmp/my_job.sql

# 查看帮助
python3 template_generator.py --help
```

## 📊 生成的文件

运行生成器后，会产生以下文件：

```
../mysql2doris/scripts/
├── mysql2doris_content_audit_record_prod_generated.sql  # 主SQL文件
└── monitor_mysql2doris_content_audit_record_prod.sh     # 监控配置
```

### SQL文件结构
```sql
-- =====================================================
-- Flink作业: mysql2doris_content_audit_record_prod
-- 生成时间: 2025-01-28 15:30:00
-- 环境: prod
-- =====================================================

-- Flink执行配置
SET 'parallelism.default' = '8';

-- 检查点配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

-- MySQL CDC源表
CREATE TABLE source_content_audit_record (
    id BIGINT COMMENT '主键ID',
    content_id BIGINT COMMENT '内容ID',
    audit_status INT COMMENT '审核状态',
    -- ... 其他字段
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com',
    -- ... 其他配置
);

-- Doris目标表
CREATE TABLE sink_xme_ods_content_audit_record_di (
    -- 字段定义...
) WITH (
    'connector' = 'doris',
    'fenodes' = '172.31.0.82:8030',
    -- ... 其他配置
);

-- 数据同步
INSERT INTO sink_xme_ods_content_audit_record_di
SELECT * FROM source_content_audit_record;
```

## 🎨 自定义和扩展

### 1. 添加新环境
```bash
# 复制现有环境配置
cp environments/prod.yaml environments/staging.yaml

# 修改配置
vi environments/staging.yaml
```

### 2. 自定义作业类型
```bash
# 创建新作业定义
cp jobs/mysql2doris.yaml jobs/postgres2doris.yaml

# 修改数据流定义
vi jobs/postgres2doris.yaml
```

### 3. 扩展SQL模板
```bash
# 创建新模板
vi templates/postgres_source.sql.jinja2

# 更新作业定义中的模板引用
vi jobs/postgres2doris.yaml
```

### 4. 集成Schema检测
```python
# 在template_generator.py中集成schema_detector.py
def detect_schema(self, context, env_config):
    from schema_detector import DatabaseSchemaDetector
    detector = DatabaseSchemaDetector()
    return detector.generate_table_config(...)
```

## 🔍 故障排查

### 常见问题

1. **模板渲染失败**
   ```bash
   # 检查模板语法
   python3 -c "from jinja2 import Template; Template(open('template.sql.jinja2').read())"
   ```

2. **配置文件错误**
   ```bash
   # 验证YAML语法
   python3 -c "import yaml; yaml.safe_load(open('prod.yaml'))"
   ```

3. **依赖包缺失**
   ```bash
   pip install PyYAML Jinja2
   ```

4. **生成的SQL错误**
   - 检查字段映射是否正确
   - 验证连接器配置
   - 确认表结构匹配

## 📈 性能优化

### 1. 环境配置优化

| 环境 | 推荐配置 |
|------|----------|
| 生产 | parallelism=8, batch_size=2000, interval=60s |
| 测试 | parallelism=4, batch_size=500, interval=120s |
| 开发 | parallelism=2, batch_size=100, interval=300s |

### 2. 模板优化
- 避免复杂的Jinja2逻辑
- 使用合理的变量命名
- 添加必要的注释

### 3. 作业优化
- 合理设置并行度
- 优化检查点间隔
- 配置合适的批量大小

## 🔄 迁移指南

### 从原系统迁移到新系统

1. **备份原配置**
   ```bash
   cp job_template.yaml job_template.yaml.backup
   ```

2. **提取环境配置**
   - 将prod/test环境配置分别提取到`environments/`目录
   - 删除重复的配置项

3. **提取作业定义**
   - 将数据流逻辑提取到`jobs/`目录
   - 使用Jinja2变量替换硬编码值

4. **创建SQL模板**
   - 将SQL生成逻辑转换为Jinja2模板
   - 分离源表、目标表、完整作业模板

5. **验证和测试**
   ```bash
   # 测试生成
   python3 template_generator.py --job mysql2doris --env test --source-table test_table --target-table test_target
   
   # 对比输出
   diff old_generated.sql new_generated.sql
   ```

## 🏆 最佳实践

### 1. 配置管理
- ✅ 环境配置独立管理
- ✅ 敏感信息使用环境变量
- ✅ 配置版本化管理
- ✅ 定期备份重要配置

### 2. 模板开发
- ✅ 使用语义化变量名
- ✅ 添加清晰的注释
- ✅ 保持模板简洁
- ✅ 验证模板语法

### 3. 作业定义
- ✅ 明确的字段映射
- ✅ 合理的默认值
- ✅ 完整的错误处理
- ✅ 详细的文档说明

### 4. 部署流程
- ✅ 先在测试环境验证
- ✅ 使用统一的命名规范
- ✅ 配置监控和告警
- ✅ 保留部署历史

## 🔮 未来规划

### 即将支持的功能
- [ ] Web UI配置界面
- [ ] 可视化数据流设计器
- [ ] 更多数据源类型支持
- [ ] 自动性能调优
- [ ] 配置验证和测试工具
- [ ] 模板市场和分享

### 技术演进
- [ ] 支持Kubernetes部署
- [ ] 集成CI/CD流水线
- [ ] 多租户配置管理
- [ ] 实时配置热更新

## 📞 技术支持

- **问题反馈**: 创建Issue
- **功能建议**: 提交Pull Request
- **技术交流**: 大数据团队
- **文档改进**: 欢迎贡献

---

## 🎉 总结

分离模板系统提供了：

1. **更清晰的架构**: 配置、逻辑、模板分离
2. **更好的维护性**: 独立的环境管理
3. **更强的扩展性**: Jinja2模板引擎支持
4. **更高的复用性**: 模板和配置可复用
5. **更低的错误率**: 类型安全和语法检查

这是一个面向未来的Flink开发框架，大大提升了开发效率和系统可维护性！ 