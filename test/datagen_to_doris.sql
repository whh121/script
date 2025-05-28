SET sql-client.execution.result-mode=TABLEAU;

-- 创建Doris目标表
CREATE TABLE doris_sink (
    partition_day DATE,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    event_time STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '172.31.0.82:8030',
    'table.identifier' = 'xme_dw_ods.xme_ods_user_kafka_client_cold_start_di',
    'username' = 'root',
    'password' = 'JzyZqbx!309',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'true',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '1s',
    'sink.max-retries' = '5',
    'sink.properties.read_timeout' = '3600',
    'sink.properties.write_timeout' = '3600'
);

-- 创建datagen源表用于测试Doris写入
CREATE TABLE datagen_source (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING
) WITH (
    'connector' = 'datagen',
    'rows-per-second' = '1',
    'fields.uid.kind' = 'random',
    'fields.platformType.kind' = 'random',
    'fields.platformType.length' = '10',
    'fields.userIP.kind' = 'random',
    'fields.userIP.length' = '15',
    'fields.version.kind' = 'random',
    'fields.version.length' = '10',
    'fields.deviceId.kind' = 'random',
    'fields.deviceId.length' = '20'
);

-- 验证Doris写入：使用datagen数据源
INSERT INTO doris_sink
SELECT 
    DATE '2025-05-18' AS partition_day,
    uid,
    platformType,
    userIP,
    version,
    deviceId,
    '1704067200000' AS event_time
FROM datagen_source; 