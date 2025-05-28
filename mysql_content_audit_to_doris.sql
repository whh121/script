-- MySQL到Doris增量数据同步 - content_audit_record表
-- 项目: content_audit_record表基于update_time增量同步
-- 时间: 2025-05-27
-- 状态: 优化版本 ✅
-- 说明: 由于表未开启binlog，提供两种同步方案

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file:///home/ubuntu/work/script/flink/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- 方案1: 批量同步历史数据 (用于初始化)
CREATE TABLE mysql_content_audit_record_batch (
    id BIGINT,
    content_id BIGINT,
    source STRING,
    language STRING,
    push_time TIMESTAMP(3),
    submit_time BIGINT,
    ai_audit_result INT,
    ai_audit_time BIGINT,
    ai_audit_channel INT,
    ai_audit_id BIGINT,
    manual_audit_result INT,
    manual_audit_time BIGINT,
    manual_audit_channel INT,
    manual_audit_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    partition_day AS CAST(DATE_FORMAT(update_time, 'yyyy-MM-dd') AS DATE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_data_20250114?useSSL=false&serverTimezone=UTC&useUnicode=true&characterEncoding=utf8',
    'table-name' = 'content_audit_record',
    'username' = 'content-ro',
    'password' = 'k5**^k12o',
    'driver' = 'com.mysql.cj.jdbc.Driver',
    -- 基于ID分区批量读取
    'scan.partition.column' = 'id',
    'scan.partition.strategy' = 'range',
    'scan.partition.lower-bound' = '1',
    'scan.partition.upper-bound' = '10000000',
    'scan.partition.num' = '8',
    'scan.fetch-size' = '5000'
);

-- 方案2: 增量数据源 (基于update_time定时轮询)
-- 注意: 需要结合外部调度系统定时执行
CREATE TABLE mysql_content_audit_record_incremental (
    id BIGINT,
    content_id BIGINT,
    source STRING,
    language STRING,
    push_time TIMESTAMP(3),
    submit_time BIGINT,
    ai_audit_result INT,
    ai_audit_time BIGINT,
    ai_audit_channel INT,
    ai_audit_id BIGINT,
    manual_audit_result INT,
    manual_audit_time BIGINT,
    manual_audit_channel INT,
    manual_audit_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    partition_day AS CAST(DATE_FORMAT(update_time, 'yyyy-MM-dd') AS DATE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_data_20250114?useSSL=false&serverTimezone=UTC&useUnicode=true&characterEncoding=utf8',
    'table-name' = '(SELECT * FROM content_audit_record WHERE update_time >= DATE_SUB(NOW(), INTERVAL 1 HOUR)) AS recent_records',
    'username' = 'content-ro',
    'password' = 'k5**^k12o',
    'driver' = 'com.mysql.cj.jdbc.Driver',
    'scan.fetch-size' = '1000'
);

-- Doris目标表配置 (UNIQUE KEY模型支持UPDATE/DELETE)
CREATE TABLE doris_content_audit_record_sink (
    id BIGINT,
    content_id BIGINT,
    source STRING,
    language STRING,
    push_time TIMESTAMP(3),
    submit_time BIGINT,
    ai_audit_result INT,
    ai_audit_time BIGINT,
    ai_audit_channel INT,
    ai_audit_id BIGINT,
    manual_audit_result INT,
    manual_audit_time BIGINT,
    manual_audit_channel INT,
    manual_audit_id BIGINT,
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
    'sink.properties.columns' = 'id, content_id, source, language, push_time, submit_time, ai_audit_result, ai_audit_time, ai_audit_channel, ai_audit_id, manual_audit_result, manual_audit_time, manual_audit_channel, manual_audit_id, create_time, update_time, partition_day',
    'sink.label-prefix' = 'content_audit_record_sync'
);

-- 执行批量数据同步 (初始化使用)
-- INSERT INTO doris_content_audit_record_sink
-- SELECT 
--     id,
--     content_id,
--     source,
--     language,
--     push_time,
--     submit_time,
--     ai_audit_result,
--     ai_audit_time,
--     ai_audit_channel,
--     ai_audit_id,
--     manual_audit_result,
--     manual_audit_time,
--     manual_audit_channel,
--     manual_audit_id,
--     create_time,
--     update_time,
--     CASE 
--         WHEN update_time IS NOT NULL THEN partition_day
--         ELSE CURRENT_DATE
--     END AS partition_day
-- FROM mysql_content_audit_record_batch;

-- 执行增量数据同步 (定时执行)
INSERT INTO doris_content_audit_record_sink
SELECT 
    id,
    content_id,
    source,
    language,
    push_time,
    submit_time,
    ai_audit_result,
    ai_audit_time,
    ai_audit_channel,
    ai_audit_id,
    manual_audit_result,
    manual_audit_time,
    manual_audit_channel,
    manual_audit_id,
    create_time,
    update_time,
    CASE 
        WHEN update_time IS NOT NULL THEN partition_day
        ELSE CURRENT_DATE
    END AS partition_day
FROM mysql_content_audit_record_incremental; 