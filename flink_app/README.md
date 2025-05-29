# Flink应用工程

## 项目简介
这是一个企业级Flink应用工程项目，专门用于管理多个Flink实时数据处理应用。目前包含Kafka到Doris和MySQL到Doris的实时数据同步功能。

## 项目结构
```
flink_app/                      # Flink应用工程根目录
├── README.md                   # 主项目说明(本文档)
├── MIGRATION.md               # 迁移历史文档
├── .gitignore                 # Git忽略文件配置
├── mysql2doris/               # MySQL到Doris同步项目
│   ├── README.md              # 项目详细文档
│   ├── scripts/               # SQL脚本和Shell脚本
│   │   ├── mysql_sync.sql
│   │   ├── mysql_content_audit_to_doris.sql
│   │   ├── mysql_incremental_sync.py
│   │   ├── mysql_doris_sync_monitor.sh
│   │   └── setup_monitor_cron.sh
│   ├── configs/               # 配置文件
│   ├── logs/                  # 日志文件
│   ├── docs/                  # 项目文档
│   ├── tests/                 # 测试文件
│   └── checkpoints/           # Flink检查点存储
└── kafka2doris/               # Kafka到Doris同步项目
    ├── README.md              # 项目详细文档
    ├── scripts/               # SQL脚本和Shell脚本
    │   ├── kafka_to_doris_production.sql
    │   ├── kafka_to_doris_solution_sample.sql
    │   ├── flink_monitor.py
    │   └── start_monitor.sh
    ├── configs/               # 配置文件
    ├── logs/                  # 日志文件
    ├── docs/                  # 项目文档
    ├── tests/                 # 测试文件
    └── checkpoints/           # Flink检查点存储
```

## 当前项目

### 1. MySQL2Doris - MySQL到Doris实时数据同步
- **状态**: ✅ 生产运行中
- **功能**: MySQL CDC监听，实时同步到Apache Doris
- **特性**: 支持UPDATE操作，使用UNIQUE KEY模型
- **详细文档**: 查看 `mysql2doris/README.md`

### 2. Kafka2Doris - Kafka到Doris实时数据同步  
- **状态**: ✅ 生产运行中
- **功能**: Kafka流数据消费，实时写入Apache Doris
- **特性**: MSK集群支持，完整监控报警
- **详细文档**: 查看 `kafka2doris/README.md`

## 设计特点

### 1. 模块化设计
- **多项目支持**: 每个Flink应用独立一个子目录
- **标准化结构**: 所有项目遵循统一的目录结构
- **独立管理**: 每个项目有独立的配置、日志、检查点

### 2. 配置规范
- **检查点管理**: 每个项目使用独立的checkpoints目录
- **相对路径**: 使用相对路径配置，便于项目迁移
- **版本控制**: 重要配置纳入Git管理

### 3. 运维友好
- **监控系统**: 自动健康检查和报警
- **日志管理**: 按天切割，自动清理
- **文档完善**: 详细的操作和故障处理文档

## 快速开始

### 环境要求
- Flink 1.17+
- Java 8+
- MySQL 5.7+ (mysql2doris项目)
- Apache Kafka (kafka2doris项目)
- Apache Doris 1.2+

### 运行mysql2doris项目
```bash
# 进入项目目录
cd flink_app/mysql2doris

# 查看项目文档
cat README.md

# 运行数据同步
flink sql-client -f scripts/mysql_sync.sql

# 配置监控(可选)
./scripts/setup_monitor_cron.sh
```

### 运行kafka2doris项目
```bash
# 进入项目目录
cd flink_app/kafka2doris

# 查看项目文档
cat README.md

# 运行数据同步
flink sql-client -f scripts/kafka_to_doris_production.sql

# 启动监控
./scripts/start_monitor.sh start
```

## 添加新项目

### 1. 创建项目目录
```bash
cd flink_app
mkdir -p new_project/{scripts,configs,logs,docs,tests,checkpoints}
```

### 2. 复制模板文件
```bash
cp mysql2doris/README.md new_project/
cp mysql2doris/configs/project.md new_project/configs/
# 根据需要调整配置
```

### 3. 配置检查点路径
在Flink SQL中使用项目独立路径:
```sql
SET 'state.checkpoints.dir' = 'file://./flink_app/new_project/checkpoints';
```

## 配置说明

### 检查点配置
每个项目使用独立的检查点目录，格式如下：
```sql
-- 项目独立检查点路径
SET 'state.checkpoints.dir' = 'file://./flink_app/[项目名]/checkpoints';
```

### 监控配置
- 健康检查间隔: 5分钟 (mysql2doris) / 60秒 (kafka2doris)
- 完整监控间隔: 15分钟  
- 报警通道: 飞书群组
- 日志保留: 7天

## 最佳实践

### 开发规范
1. 遵循统一的目录结构
2. 使用相对路径配置
3. 编写完整的项目文档
4. 提供测试脚本和样例

### 运维规范
1. 定期备份检查点
2. 监控磁盘空间使用
3. 及时清理旧日志
4. 记录重要操作历史

### 故障处理
1. 查看监控日志: `tail -f [项目名]/logs/monitor_*.log`
2. 检查Flink作业状态: `flink list`
3. 查看检查点: `ls -la [项目名]/checkpoints/`
4. 重启作业: 参考各项目README文档

## 相关链接
- [Flink官方文档](https://flink.apache.org/docs/)
- [MySQL CDC连接器](https://ververica.github.io/flink-cdc-connectors/)
- [Kafka连接器](https://nightlies.apache.org/flink/flink-docs-master/docs/connectors/datastream/kafka/)
- [Doris Flink连接器](https://doris.apache.org/docs/ecosystem/flink-doris-connector/)

## 联系方式
如有问题请联系大数据团队。 