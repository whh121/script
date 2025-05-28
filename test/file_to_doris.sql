SET sql-client.execution.result-mode=TABLEAU;

-- 创建本地文件源表
CREATE TABLE file_source (
    uid STRING,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    ts STRING,
    event_time TIMESTAMP(3),
    partition_day STRING
) WITH (
    'connector' = 'filesystem',
    'path' = 'file:///home/ubuntu/work/script/flink/output',
    'format' = 'json'
);

-- 创建 Doris 目标表
CREATE TABLE doris_sink (
    uid STRING,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    ts STRING,
    event_time TIMESTAMP(3),
    partition_day STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '172.31.0.82:8030',
    'table.identifier' = 'xme_dw_ods.xme_ods_user_kafka_client_cold_start_di',
    'username' = 'root',
    'password' = 'JzyZqbx!309',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'false',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10mb',
    'sink.buffer-flush.interval' = '5s'
);

-- 打印 file_source 表数据，调试用
SELECT * FROM file_source LIMIT 10;

-- 插入数据到 Doris 目标表
INSERT INTO doris_sink
SELECT 
    uid,
    platformType,
    userIP,
    version,
    deviceId,
    ts,
    event_time,
    partition_day
FROM file_source; 