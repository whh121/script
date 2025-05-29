# MySQL到Doris数据同步Flink作业

## 概述
这个Flink作业使用MySQL CDC连接器从MySQL数据库实时同步数据到Doris数据库。

## 配置信息
- **MySQL源**：10.10.33.48:3306/test_flink
- **Doris目标**：10.10.41.243:9030/test_flink
- **Flink路径**：/home/ubuntu/flink

## 功能特性
- 支持MySQL CDC增量同步
- 自动分区（按日期）
- 数据去重和容错处理
- 支持调试输出（打印和文件系统）

## 使用前准备

### 1. 确保MySQL配置
```sql
-- 在MySQL中创建示例表（如果不存在）
CREATE TABLE user_data (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    uid BIGINT NOT NULL,
    platformType VARCHAR(50),
    userIP VARCHAR(45),
    version VARCHAR(20),
    deviceId VARCHAR(100),
    created_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 确保MySQL开启binlog
-- 在my.cnf中添加：
-- log-bin=mysql-bin
-- binlog-format=ROW
-- server-id=1
```

### 2. 确保Doris表结构
```sql
-- 在Doris中创建目标表
CREATE TABLE test_flink.user_data_sync (
    id BIGINT,
    partition_day DATE,
    uid BIGINT,
    platformType VARCHAR(50),
    userIP VARCHAR(45),
    version VARCHAR(20),
    deviceId VARCHAR(100),
    created_time VARCHAR(30),
    updated_time VARCHAR(30)
) DISTRIBUTED BY HASH(id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1"
);
```

### 3. 准备Flink依赖
确保Flink lib目录包含以下jar包：
- flink-connector-mysql-cdc-*.jar
- flink-connector-doris-*.jar
- mysql-connector-java-*.jar

## 运行步骤

### 1. 启动Flink集群
```bash
cd /home/ubuntu/flink
./bin/start-cluster.sh
```

### 2. 提交作业
```bash
# 启动Flink SQL客户端
./bin/sql-client.sh

# 在SQL客户端中执行
source '/home/ubuntu/work/script/mysql_to_doris_solution.sql';
```

### 3. 监控作业
- 访问Flink Web UI：http://10.10.33.48:8081
- 查看作业状态和指标

## 重要参数说明

### MySQL CDC配置
- `server-id`：MySQL复制服务器ID，需要唯一
- `scan.incremental.snapshot.enabled`：启用增量快照
- `scan.incremental.snapshot.chunk.size`：快照块大小

### Doris连接器配置
- `sink.enable-2pc`：启用两阶段提交保证一致性
- `sink.buffer-flush.max-rows`：批次最大行数
- `sink.buffer-flush.interval`：刷新间隔

### Checkpoint配置
- 间隔：60秒
- 模式：EXACTLY_ONCE
- 存储：本地文件系统

## 注意事项

1. **表名修改**：请根据实际情况修改以下内容：
   - MySQL源表名：`table-name` 参数
   - Doris目标表：`table.identifier` 参数

2. **权限要求**：
   - MySQL用户需要REPLICATION SLAVE权限
   - Doris用户需要目标表的写入权限

3. **网络连接**：确保Flink能够访问MySQL和Doris服务器

4. **数据类型**：注意MySQL和Doris之间的数据类型兼容性

## 故障排除

### 常见问题
1. **连接超时**：检查网络连接和防火墙设置
2. **权限错误**：确认数据库用户权限
3. **Checkpoint失败**：检查checkpoint目录权限
4. **数据类型不匹配**：调整表结构或添加类型转换

### 日志查看
```bash
# 查看Flink作业日志
tail -f /home/ubuntu/flink/log/flink-*.log

# 查看TaskManager日志
tail -f /home/ubuntu/flink/log/flink-*-taskexecutor-*.log
```

## 性能优化建议

1. **并行度设置**：根据数据量调整作业并行度
2. **Checkpoint间隔**：根据数据延迟要求调整
3. **批次大小**：根据网络和内存情况调整Doris批次参数
4. **内存配置**：适当增加TaskManager内存 