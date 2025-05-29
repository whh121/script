# Kafka2Doris - Kafka到Doris实时数据同步项目

## 项目简介
这是一个基于Apache Flink的实时数据处理项目，专门负责从Kafka消费数据并实时写入Apache Doris数据仓库。

## 项目状态
- **状态**: ✅ 生产运行中
- **最近更新**: 2025-05-28
- **版本**: v2.0

## 目录结构
```
kafka2doris/
├── README.md                              # 项目说明(本文档)
├── scripts/                               # 脚本文件
│   ├── kafka_to_doris_production.sql      # 生产环境主同步脚本
│   ├── kafka_to_doris_solution_sample.sql # 参考样例脚本
│   ├── flink_monitor.py                   # Flink作业监控脚本
│   └── start_monitor.sh                   # 监控启动脚本
├── configs/                               # 配置文件
├── logs/                                  # 日志文件
├── docs/                                  # 项目文档
├── tests/                                 # 测试文件
└── checkpoints/                           # Flink检查点存储
```

## 功能特性

### 数据流处理
- **数据源**: Kafka集群 (MSK - Amazon Managed Streaming for Apache Kafka)
- **数据目标**: Apache Doris数据仓库
- **处理模式**: 实时流处理
- **容错机制**: Flink Checkpoint + 重启策略

### 监控报警
- **自动监控**: 60秒间隔健康检查
- **故障重启**: 最多3次自动重试
- **报警通知**: 飞书群组实时推送
- **日志记录**: 完整的运行日志

## 环境配置

### Kafka集群 (MSK)
```
Brokers:
- b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092
- b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092  
- b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092
```

### Doris集群
- **生产环境**: `172.31.0.82:8030` / `root` / `JzyZqbx!309`
- **测试环境**: `10.10.41.243:8030` / `root` / `doris@123`

### Flink配置
```sql
-- 检查点配置 (项目独立)
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/kafka2doris/checkpoints';
```

## 快速开始

### 1. 运行数据同步
```bash
# 进入项目目录
cd flink_app/kafka2doris

# 启动Flink集群 (如果未启动)
cd /opt/flink && ./bin/start-cluster.sh

# 运行生产环境同步任务
cd /home/ubuntu/work/script
flink sql-client -f flink_app/kafka2doris/scripts/kafka_to_doris_production.sql
```

### 2. 配置监控 (可选)
```bash
# 启动监控脚本
cd flink_app/kafka2doris
./scripts/start_monitor.sh start

# 查看监控日志
tail -f logs/monitor_$(date +%Y%m%d).log
```

## 核心文件说明

### SQL脚本
1. **kafka_to_doris_production.sql**
   - 生产环境主同步脚本
   - 包含完整的Kafka源表和Doris目标表配置
   - 状态: ✅ 生产使用

2. **kafka_to_doris_solution_sample.sql**
   - 参考样例脚本
   - 用于开发和测试
   - 状态: ⚠️ 样例参考

### 监控脚本
1. **flink_monitor.py**
   - Python监控脚本
   - 功能: 作业状态检查、自动重启、报警通知
   - 检查间隔: 60秒

2. **start_monitor.sh**
   - 监控启动脚本
   - 支持 start/stop/restart/status 操作

## 运维操作

### 作业管理
```bash
# 查看作业状态
flink list

# 停止作业
flink cancel [job-id]

# 从检查点恢复
flink run -s checkpoints/[checkpoint-id] [job.jar]
```

### 日志管理
```bash
# 实时查看监控日志
tail -f logs/monitor_$(date +%Y%m%d).log

# 查看Flink作业日志
tail -f /opt/flink/log/flink-*.log

# 清理旧日志 (保留7天)
find logs/ -name "*.log" -mtime +7 -delete
```

### 检查点管理
```bash
# 查看检查点
ls -la checkpoints/

# 备份检查点
tar -czf checkpoint_backup_$(date +%Y%m%d).tar.gz checkpoints/

# 清理旧检查点 (保留最近10个)
cd checkpoints && ls -t | tail -n +11 | xargs rm -rf
```

## 故障排查

### 常见问题
1. **Kafka连接失败**
   - 检查网络连通性
   - 验证Kafka集群状态
   - 确认Topic存在

2. **Doris写入失败**
   - 检查Doris集群状态
   - 验证表结构匹配
   - 确认用户权限

3. **检查点失败**
   - 检查磁盘空间
   - 验证目录权限
   - 查看Flink日志

### 检查命令
```bash
# 检查Kafka连通性
kafka-console-consumer --bootstrap-server [broker] --topic [topic] --from-beginning

# 检查Doris连通性
mysql -h 172.31.0.82 -P 9030 -u root -p

# 检查Flink集群状态
flink list
```

## 性能优化

### Kafka配置
- 合理设置消费者并行度
- 优化批量大小和提交间隔
- 监控消费延迟

### Doris配置
- 使用合适的分区策略
- 优化批量写入大小
- 监控写入性能

### Flink调优
- 根据数据量调整并行度
- 优化内存和CPU配置
- 设置合理的检查点间隔

## 联系方式
- **大数据团队**: 技术支持和问题咨询
- **运维团队**: 环境问题和资源申请
- **项目负责人**: 业务需求和功能规划

## 更新历史
- **2025-05-28**: 重构为kafka2doris独立项目，使用项目独立检查点
- **2025-05-27**: 优化监控脚本，增加自动重启功能
- **2025-05-26**: 上线生产环境，稳定运行 