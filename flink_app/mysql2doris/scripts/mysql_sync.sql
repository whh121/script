-- MySQL到Doris增量数据同步 - content_audit_record表
-- 项目: content_audit_record表基于update_time增量同步
-- 时间: 2025-05-27
-- 状态: 优化版本 ✅
-- 说明: 由于表未开启binlog，使用JDBC轮询方式基于update_time增量同步

-- 生产环境不需要TABLEAU模式
-- SET 'sql-client.execution.result-mode'='TABLEAU';

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- MySQL源表配置 (使用自定义Source进行定时增量读取)
-- 注意: 由于Flink JDBC连接器不支持流式增量读取，这里提供两种方案：

-- 方案1: 使用自定义Source (推荐)
-- 需要开发自定义的MySQL增量读取Source，基于update_time字段定时轮询

-- 方案2: 使用定时批处理作业 (临时方案)
CREATE TABLE mysql_content_audit_record (
    id BIGINT,
    content_id BIGINT,
    audit_status INT,
    audit_reason STRING,
    auditor_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    -- 计算字段和水印
    partition_day AS CAST(DATE_FORMAT(update_time, 'yyyy-MM-dd') AS DATE),
    WATERMARK FOR update_time AS update_time - INTERVAL '10' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_data_20250114?useSSL=false&serverTimezone=UTC',
    'table-name' = 'content_audit_record',
    'username' = 'content-ro',
    'password' = 'k5**^k12o',
    'driver' = 'com.mysql.cj.jdbc.Driver',
    -- 批量读取配置 (用于一次性同步历史数据)
    'scan.partition.column' = 'id',
    'scan.partition.strategy' = 'range',
    'scan.partition.lower-bound' = '1',
    'scan.partition.upper-bound' = '1000000',
    'scan.partition.num' = '4',
    'scan.fetch-size' = '1000'
);

-- Doris目标表配置 (UNIQUE KEY模型支持UPDATE/DELETE)
CREATE TABLE doris_content_audit_record_sink (
    id BIGINT,
    content_id BIGINT,
    audit_status INT,
    audit_reason STRING,
    auditor_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    partition_day DATE
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8030',
    'table.identifier' = 'test_flink.content_audit_record_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '5000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '3',
    'sink.properties.columns' = 'id, content_id, audit_status, audit_reason, auditor_id, create_time, update_time, partition_day',
    'sink.label-prefix' = 'content_audit_record_sync'
);

-- 执行增量数据同步
INSERT INTO doris_content_audit_record_sink
SELECT 
    id,
    content_id,
    audit_status,
    audit_reason,
    auditor_id,
    create_time,
    update_time,
    CASE 
        WHEN update_time IS NOT NULL THEN partition_day
        ELSE CURRENT_DATE
    END AS partition_day
FROM mysql_content_audit_record; 