# user_interests 表 MySQL到Doris同步解决方案

## 🔍 问题分析

### 当前状况
- **源表**：`content_behavior.user_interests` (AWS RDS)
- **数据量**：1560+ 条记录，持续增长（每10秒新增1条）
- **目标**：实时同步到 Doris `test_flink.user_interests_sync`

### 遇到的关键问题

#### 1. ❌ MySQL用户权限不足
```
ERROR: Access denied; you need (at least one of) the SUPER, REPLICATION CLIENT privilege(s)
```

**原因**：`bigdata-user-interests` 用户缺少CDC所需的复制权限

#### 2. ✅ 连接配置正确
- 基础连接：✅ 成功
- 时区配置：✅ UTC 正确
- 表结构：✅ 匹配

## 🚀 解决方案

### 方案一：申请MySQL权限 (推荐)

#### 需要的权限
```sql
-- 需要DBA执行以下权限授予
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'bigdata-user-interests'@'%';
GRANT SELECT ON content_behavior.user_interests TO 'bigdata-user-interests'@'%';
FLUSH PRIVILEGES;
```

#### 验证权限
```sql
SHOW GRANTS FOR 'bigdata-user-interests'@'%';
```

#### 完整同步作业 (权限修复后可用)
```sql
-- user_interests 实时同步作业
CREATE TABLE mysql_user_interests (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3),
    partition_day AS CAST(DATE_FORMAT(updated_at, 'yyyy-MM-dd') AS DATE),
    WATERMARK FOR updated_at AS updated_at - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com',
    'port' = '3306',
    'username' = 'bigdata-user-interests',
    'password' = 'BId.3DKRF5dDFwfs',
    'database-name' = 'content_behavior',
    'table-name' = 'user_interests',
    'server-time-zone' = 'UTC'
);

CREATE TABLE doris_user_interests_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at STRING,
    partition_day DATE
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:9030',
    'table.identifier' = 'test_flink.user_interests_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.interval' = '10s',
    'sink.label-prefix' = 'user_interests_sync'
);

INSERT INTO doris_user_interests_sink
SELECT id, user_id, interest_ids, CAST(updated_at AS STRING), partition_day
FROM mysql_user_interests;
```

### 方案二：定时批量同步 (临时方案)

如果无法获取CDC权限，可以使用定时批量同步：

#### 1. 安装JDBC连接器
```bash
cd /home/ubuntu/flink/lib
wget https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.1.1/flink-connector-jdbc-3.1.1.jar
/home/ubuntu/flink/bin/stop-cluster.sh
/home/ubuntu/flink/bin/start-cluster.sh
```

#### 2. 批量同步作业
```sql
-- 每5分钟同步最新数据
CREATE TABLE mysql_user_interests_batch (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_behavior',
    'table-name' = 'user_interests',
    'username' = 'bigdata-user-interests',
    'password' = 'BId.3DKRF5dDFwfs'
);
```

### 方案三：使用现有有权限的用户

如果有其他具备CDC权限的MySQL用户，可以直接使用。

## 📋 立即可执行步骤

### 1. 验证权限状态
```bash
mysql -h xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com \
  -u bigdata-user-interests -p'BId.3DKRF5dDFwfs' \
  -e "SHOW GRANTS; SHOW MASTER STATUS;"
```

### 2. 联系DBA申请权限
- **用户**：`bigdata-user-interests`
- **所需权限**：`REPLICATION SLAVE`, `REPLICATION CLIENT`
- **目标表**：`content_behavior.user_interests`

### 3. 权限获取后立即可用
一旦权限问题解决，现有的Flink CDC框架可以立即用于实时同步：
- ✅ 连接器已安装
- ✅ Doris目标表已创建
- ✅ 同步作业已编写完成
- ✅ 时区配置已修复

## 🎯 预期效果

权限修复后，可实现：
- **延迟**：< 1秒的实时同步
- **吞吐量**：支持高频更新（每10秒1条记录）
- **可靠性**：自动故障恢复和checkpointing
- **监控**：完整的作业状态监控

---
**状态**：⚠️ 等待MySQL用户权限修复  
**解决方案**：已准备就绪，权限修复后可立即部署  
**预计修复时间**：5-10分钟（DBA操作） 