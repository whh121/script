# Flink应用工程

## 项目简介
这是一个企业级Flink应用工程项目，专门用于管理多个Flink实时数据处理应用。包含完整的Kafka到Doris和MySQL到Doris的实时数据同步功能，具备完善的监控和告警系统。

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
    │   ├── kafka_to_doris_production.sql      # ✅ 生产环境主同步脚本
    │   ├── kafka_to_doris_solution_sample.sql # ⚠️ 参考样例脚本
    │   ├── flink_monitor.py                   # ✅ 生产级监控脚本
    │   └── start_monitor.sh                   # ✅ 监控启动脚本
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
- **监控**: 5分钟间隔健康检查，15分钟完整监控
- **详细文档**: 查看 `mysql2doris/README.md`

#### 核心文件
- `mysql_sync.sql`: 主同步脚本，支持CDC变更数据捕获
- `mysql_content_audit_to_doris.sql`: 批处理同步，支持初始化和增量
- `mysql_incremental_sync.py`: 增量同步调度器，每小时自动增量同步
- `mysql_doris_sync_monitor.sh`: 监控脚本，自动重启和报警

### 2. Kafka2Doris - Kafka到Doris实时数据同步  
- **状态**: ✅ 生产运行中
- **功能**: 从AWS MSK的client_cold_start topic消费数据并实时写入Doris
- **特性**: MSK集群支持，完整监控报警，60秒检查间隔
- **数据源**: client_cold_start topic (JSON格式用户行为数据)
- **详细文档**: 查看 `kafka2doris/README.md`

#### 核心文件
- `kafka_to_doris_production.sql`: ✅ 生产环境主脚本，包含完整配置
- `kafka_to_doris_solution_sample.sql`: ⚠️ 样例参考脚本，用于开发调试
- `flink_monitor.py`: ✅ 生产级监控脚本，自动重启和飞书报警
- `start_monitor.sh`: ✅ 监控启动脚本，支持start/stop/restart/status

## 环境配置

### Kafka集群 (AWS MSK)
```
Brokers:
- b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092
- b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092  
- b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092

Topics:
- client_cold_start (JSON格式用户行为数据)
```

### MySQL数据库
```
生产库: xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306
用户: content-ro / 密码: k5**^k12o
数据库: content_data_20250114

主要表:
- content_audit_record (内容审核记录)
- user_interests (用户兴趣数据)
```

### Doris集群
```
生产环境: 172.31.0.82:8030 / root / JzyZqbx!309
测试环境: 10.10.41.243:8030 / root / doris@123

主要数据库:
- xme_dw_ods (ODS层数据)
- test_flink (测试数据)
```

### 数据结构示例
```json
// client_cold_start topic数据格式
{
  "uid": 123456,
  "platformType": "iOS", 
  "userIP": "192.168.1.1",
  "version": "1.0.0",
  "deviceId": "device123",
  "timestamp": "1640995200000"
}
```

## 快速开始

### 环境要求
- Flink 1.17+
- Java 8+
- MySQL 5.7+ (mysql2doris项目)
- Apache Kafka (kafka2doris项目)
- Apache Doris 1.2+
- Python 3.7+ (监控脚本)

### 1. 启动Flink集群
```bash
cd /opt/flink
./bin/start-cluster.sh

# 验证集群状态
curl http://localhost:8081/overview
```

### 2. 运行kafka2doris项目
```bash
# 进入项目目录
cd flink_app/kafka2doris

# 查看项目文档
cat README.md

# 运行生产环境同步任务
cd /home/ubuntu/work/script
flink sql-client -f flink_app/kafka2doris/scripts/kafka_to_doris_production.sql

# 启动监控
cd flink_app/kafka2doris
./scripts/start_monitor.sh start

# 查看监控日志
tail -f logs/monitor_$(date +%Y%m%d).log
```

### 3. 运行mysql2doris项目
```bash
# 进入项目目录
cd flink_app/mysql2doris

# 查看项目文档
cat README.md

# 运行数据同步
flink sql-client -f scripts/mysql_sync.sql

# 配置定时监控
./scripts/setup_monitor_cron.sh

# 启动增量同步调度器
nohup python3 scripts/mysql_incremental_sync.py > mysql_sync.log 2>&1 &
```

## 监控和告警

### 监控指标
1. **Flink集群健康状态** - 每60秒检查
2. **作业运行状态** - RUNNING/FAILED/CANCELED状态监控
3. **Kafka消费延迟** - 实时消费lag监控
4. **Doris写入成功率** - 写入性能和错误监控
5. **数据同步延迟** - 端到端延迟监控

### 告警策略
- **立即告警**: 作业失败、集群异常
- **恢复通知**: 自动重启成功
- **定期报告**: 同步完成状态

### 飞书告警配置
```python
webhook_url = "https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"
```

## 配置说明

### 检查点配置
每个项目使用独立的检查点目录：
```sql
-- MySQL2Doris项目
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

-- Kafka2Doris项目  
SET 'state.checkpoints.dir' = 'file://./flink_app/kafka2doris/checkpoints';
```

### 标准Flink配置
```sql
-- 基础配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';

-- 重启策略
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';
```

## 运维操作

### 作业管理
```bash
# 查看所有作业状态
flink list

# 停止指定作业
flink cancel [job-id]

# 从检查点恢复作业
flink run -s checkpoints/[checkpoint-id] [job.jar]

# 检查作业详情
curl http://localhost:8081/jobs/[job-id]
```

### 日志管理
```bash
# 查看kafka2doris监控日志
tail -f flink_app/kafka2doris/logs/monitor_$(date +%Y%m%d).log

# 查看mysql2doris监控日志
tail -f flink_app/mysql2doris/logs/monitor_$(date +%Y%m%d).log

# 查看Flink集群日志
tail -f /opt/flink/log/flink-*.log

# 清理旧日志 (保留7天)
find flink_app/*/logs/ -name "*.log" -mtime +7 -delete
```

### 检查点管理
```bash
# 查看项目检查点
ls -la flink_app/*/checkpoints/

# 备份检查点
tar -czf checkpoint_backup_$(date +%Y%m%d).tar.gz flink_app/*/checkpoints/

# 清理旧检查点 (保留最近10个)
cd flink_app/kafka2doris/checkpoints && ls -t | tail -n +11 | xargs rm -rf
```

## 添加新项目

### 1. 创建项目目录
```bash
cd flink_app
mkdir -p new_project/{scripts,configs,logs,docs,tests,checkpoints}
```

### 2. 复制模板文件
```bash
cp kafka2doris/README.md new_project/
cp kafka2doris/configs/project.md new_project/configs/
# 根据需要调整配置
```

### 3. 配置检查点路径
在Flink SQL中使用项目独立路径:
```sql
SET 'state.checkpoints.dir' = 'file://./flink_app/new_project/checkpoints';
```

## 故障排查

### 常见问题
1. **Kafka连接失败**
   - 检查网络连通性和安全组配置
   - 验证Kafka集群状态和Topic存在性
   
2. **Doris写入失败**
   - 检查Doris集群状态和用户权限
   - 验证表结构匹配和数据格式
   
3. **MySQL CDC失败**
   - 检查MySQL连接和用户权限
   - 验证binlog配置和表结构

4. **检查点失败**
   - 检查磁盘空间和目录权限
   - 验证路径配置正确性

### 检查命令
```bash
# 检查Kafka连通性
kafka-console-consumer --bootstrap-server [broker] --topic client_cold_start --from-beginning

# 检查MySQL连通性
mysql -h xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com -P 3306 -u content-ro -p

# 检查Doris连通性
mysql -h 172.31.0.82 -P 9030 -u root -p

# 检查Flink集群状态
curl http://localhost:8081/jobs
```

### 日志位置
- **Flink日志**: `/opt/flink/log/`
- **Kafka2Doris监控日志**: `flink_app/kafka2doris/logs/monitor_*.log`
- **MySQL2Doris监控日志**: `flink_app/mysql2doris/logs/monitor_*.log`
- **检查点目录**: `flink_app/*/checkpoints/`

## 性能优化

### Kafka配置优化
- 合理设置消费者并行度（建议与分区数相等）
- 优化批量大小和提交间隔
- 监控消费延迟和吞吐量

### Doris配置优化
- 使用合适的分区策略和分桶数
- 优化批量写入大小和频率
- 监控写入性能和资源使用

### Flink调优
- 根据数据量调整并行度和资源配置
- 优化内存和CPU配置
- 设置合理的检查点间隔

## 最佳实践

### 开发规范
1. 遵循统一的目录结构
2. 使用项目独立相对路径配置
3. 编写完整的项目文档
4. 提供测试脚本和样例

### 运维规范
1. 定期备份各项目检查点
2. 监控磁盘空间和资源使用
3. 及时清理旧日志和检查点
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
- **大数据团队**: 技术支持和问题咨询
- **运维团队**: 环境问题和资源申请
- **告警通知**: 飞书机器人自动推送
- **手动检查**: Flink Web UI (http://localhost:8081) 