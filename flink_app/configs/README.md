# Flink配置模板系统

## 📋 概述

这是一个类似SeaTunnel的配置模板系统，用于统一管理Flink作业配置和自动生成SQL文件。

### 系统特性
- **YAML配置**: 使用YAML格式定义作业配置，清晰易读
- **多环境支持**: 支持prod/test/dev等多环境配置
- **自动生成**: 基于配置模板自动生成Flink SQL文件
- **Schema检测**: 自动检测数据库表结构，确保字段映射正确
- **类型映射**: 自动完成MySQL/Kafka到Flink的数据类型映射
- **监控集成**: 自动生成对应的监控脚本配置

## 📁 文件结构

```
configs/
├── README.md                   # 配置系统说明(本文档)
├── job_template.yaml           # 作业配置模板
├── config_generator.py         # 配置生成器
├── schema_detector.py          # 数据库Schema检测器
├── schema_cache.json           # Schema缓存文件(自动生成)
└── examples/                   # 配置示例
    ├── mysql2doris_prod.yaml   # MySQL CDC示例
    ├── kafka2doris_test.yaml   # Kafka流处理示例
    └── batch_sync.yaml         # 批处理同步示例
```

## 🎯 快速开始

### 1. 生成Flink SQL
```bash
# 进入配置目录
cd flink_app/configs

# 生成MySQL2Doris生产环境SQL
python config_generator.py --job mysql2doris --env prod

# 生成Kafka2Doris测试环境SQL
python config_generator.py --job kafka2doris --env test --output /tmp/kafka_test.sql
```

### 2. 检测数据库Schema
```bash
# 检测MySQL表结构
python schema_detector.py \
  --type mysql \
  --host xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com \
  --username content-ro \
  --password "k5**^k12o" \
  --database content_data_20250114 \
  --table content_audit_record

# 检测Doris表结构
python schema_detector.py \
  --type doris \
  --host 172.31.0.82 \
  --port 9030 \
  --username root \
  --password "JzyZqbx!309" \
  --database xme_dw_ods \
  --table xme_ods_content_content_audit_record_di
```

### 3. 运行生成的SQL
```bash
# 运行生成的SQL文件
cd /home/ubuntu/work/script
flink sql-client -f flink_app/mysql2doris/scripts/mysql2doris_prod_generated.sql
```

## ⚙️ 配置模板详解

### 基本结构
```yaml
mysql2doris:                    # 作业类型
  prod:                         # 环境
    job:                        # 作业配置
      name: "job_name"
      parallelism: 4
      mode: "stream"
    
    checkpoint:                 # 检查点配置
      interval: "60s"
      mode: "EXACTLY_ONCE"
      timeout: "600s"
      dir: "file://./flink_app/mysql2doris/checkpoints"
    
    restart:                    # 重启策略
      strategy: "fixed-delay"
      attempts: 3
      delay: "30s"
    
    source:                     # 数据源配置
      type: "mysql-cdc"
      host: "hostname"
      # ... 其他配置
    
    sink:                       # 数据目标配置
      type: "doris"
      fenodes: "hostname:port"
      # ... 其他配置
```

### 支持的数据源类型

#### 1. MySQL CDC
```yaml
source:
  type: "mysql-cdc"
  driver: "com.mysql.cj.jdbc.Driver"
  host: "mysql.example.com"
  port: 3306
  database: "database_name"
  table: "table_name"
  username: "username"
  password: "password"
  server-id: "5001-5004"
  scan:
    startup-mode: "initial"    # initial | earliest-offset | latest-offset
  debezium:
    snapshot.mode: "initial"
    snapshot.locking.mode: "minimal"
```

#### 2. Kafka
```yaml
source:
  type: "kafka"
  brokers:
    - "broker1:9092"
    - "broker2:9092"
    - "broker3:9092"
  topic: "topic_name"
  consumer:
    group-id: "consumer_group"
    startup-mode: "earliest-offset"
    format: "json"
    json:
      ignore-parse-errors: true
      timestamp-format:
        standard: "ISO-8601"
```

### 支持的数据目标类型

#### 1. Apache Doris
```yaml
sink:
  type: "doris"
  fenodes: "doris-fe:8030"
  database: "database_name"
  table: "table_name"
  username: "username"
  password: "password"
  stream-load:
    format: "json"
    properties:
      format: "json"
      read_json_by_line: "true"
      load-mode: "stream_load"
      batch.size: "1000"
      batch.interval: "10s"
```

## 🔧 工具使用说明

### config_generator.py
配置生成器，根据YAML模板生成Flink SQL文件

**命令行参数:**
- `--job`: 作业类型 (mysql2doris, kafka2doris)
- `--env`: 环境 (prod, test, dev)
- `--output`: 输出文件路径 (可选)
- `--config`: 配置文件路径 (默认: job_template.yaml)

**示例:**
```bash
# 基本用法
python config_generator.py --job mysql2doris --env prod

# 指定输出文件
python config_generator.py --job kafka2doris --env test --output custom.sql

# 使用自定义配置文件
python config_generator.py --job mysql2doris --env prod --config custom_template.yaml
```

### schema_detector.py
数据库Schema检测器，自动获取表结构并生成Flink表定义

**命令行参数:**
- `--type`: 数据库类型 (mysql, doris)
- `--host`: 数据库主机
- `--port`: 端口号 (可选，默认: MySQL=3306, Doris=9030)
- `--username`: 用户名
- `--password`: 密码
- `--database`: 数据库名
- `--table`: 表名
- `--output`: 输出配置文件路径 (可选)

**示例:**
```bash
# 检测MySQL表结构
python schema_detector.py \
  --type mysql \
  --host localhost \
  --username root \
  --password password \
  --database testdb \
  --table users

# 输出到文件
python schema_detector.py \
  --type mysql \
  --host localhost \
  --username root \
  --password password \
  --database testdb \
  --table users \
  --output users_schema.json
```

## 🎨 数据类型映射

### MySQL → Flink 类型映射
| MySQL类型 | Flink类型 | 说明 |
|-----------|-----------|------|
| tinyint | TINYINT | 1字节整数 |
| int | INT | 4字节整数 |
| bigint | BIGINT | 8字节整数 |
| varchar(n) | VARCHAR(n) | 变长字符串 |
| text | STRING | 文本类型 |
| datetime | TIMESTAMP(3) | 时间戳(毫秒精度) |
| decimal(p,s) | DECIMAL(p,s) | 精确数值 |
| json | STRING | JSON字符串 |

### Kafka JSON → Flink 类型映射
| JSON类型 | Flink类型 | 说明 |
|----------|-----------|------|
| number | BIGINT/DECIMAL | 根据值范围自动选择 |
| string | STRING | 字符串 |
| boolean | BOOLEAN | 布尔值 |
| object | ROW<...> | 嵌套对象 |
| array | ARRAY<...> | 数组类型 |

## 📈 性能优化建议

### 1. 并行度设置
```yaml
job:
  parallelism: 4    # 根据数据量和CPU核数调整
```

### 2. 检查点优化
```yaml
checkpoint:
  interval: "60s"   # 根据数据量调整，通常30-300秒
  timeout: "600s"   # 检查点超时时间
```

### 3. Doris写入优化
```yaml
sink:
  stream-load:
    properties:
      batch.size: "2000"      # 批量大小，根据内存调整
      batch.interval: "5s"    # 批量间隔，根据延迟要求调整
```

## 🔍 故障排查

### 常见问题

#### 1. 配置文件语法错误
```bash
# 检查YAML语法
python -c "import yaml; yaml.safe_load(open('job_template.yaml'))"
```

#### 2. 数据库连接失败
```bash
# 测试MySQL连接
mysql -h host -P port -u username -p

# 测试Doris连接
mysql -h host -P 9030 -u username -p
```

#### 3. Schema检测失败
- 检查数据库连接权限
- 确认表名和数据库名正确
- 检查INFORMATION_SCHEMA访问权限

#### 4. 生成的SQL运行失败
- 检查表结构是否匹配
- 验证连接器JAR包是否加载
- 查看Flink日志排查具体错误

## 📝 最佳实践

### 1. 配置管理
- 使用Git管理配置文件
- 敏感信息使用环境变量
- 定期备份schema缓存

### 2. 环境隔离
- 生产和测试使用不同的配置
- 检查点目录按环境隔离
- 消费者组按环境命名

### 3. 监控集成
- 配置合适的作业名称
- 使用统一的告警webhook
- 定期检查作业状态

### 4. 版本控制
- 配置文件版本化管理
- 记录重要配置变更
- 保留配置变更历史

## 🔄 未来规划

### 即将支持的功能
- [ ] 图形化配置界面
- [ ] 更多数据源类型 (PostgreSQL, MongoDB等)
- [ ] 自动性能调优建议
- [ ] 配置验证和测试工具
- [ ] 配置模板市场

### 贡献指南
欢迎提交Issue和Pull Request来改进配置系统！

## 📞 联系方式
- 技术支持: 大数据团队
- 问题反馈: 请提交Issue
- 功能建议: 欢迎讨论 