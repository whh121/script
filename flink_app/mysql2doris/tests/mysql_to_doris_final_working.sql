-- MySQL到Doris实时数据同步作业 - 最终可工作版本
SET sql-client.execution.result-mode=TABLEAU;

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

-- 创建MySQL源表（修复了时区问题）
CREATE TABLE mysql_source (
    id BIGINT,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    created_time TIMESTAMP(3),
    updated_time TIMESTAMP(3),
    partition_day AS CAST(DATE_FORMAT(created_time, 'yyyy-MM-dd') AS DATE),
    WATERMARK FOR created_time AS created_time - INTERVAL '5' SECOND,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '10.10.33.48',
    'port' = '3306',
    'username' = 'root',
    'password' = 'mysql@123',
    'database-name' = 'test_flink',
    'table-name' = 'user_data',
    'server-time-zone' = 'Asia/Shanghai'
);

-- 创建Doris目标表
CREATE TABLE doris_sink (
    id BIGINT,
    partition_day DATE,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    created_time STRING,
    updated_time STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:9030',
    'table.identifier' = 'test_flink.user_data_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.interval' = '10s',
    'sink.label-prefix' = 'mysql_to_doris_sync'
);

-- 执行完整数据同步
INSERT INTO doris_sink
SELECT
    id,
    partition_day,
    uid,
    platformType,
    userIP,
    version,
    COALESCE(deviceId, 'unknown') AS deviceId,
    CAST(created_time AS STRING) AS created_time,
    CAST(updated_time AS STRING) AS updated_time
FROM mysql_source; 