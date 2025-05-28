SET sql-client.execution.result-mode=TABLEAU;

-- 创建Kafka源表
CREATE TABLE kafka_source (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    `timestamp` STRING,
    event_time AS DATE_FORMAT(TO_TIMESTAMP(CAST(CAST(`timestamp` AS BIGINT) / 1000 AS STRING)), 'yyyy-MM-dd HH:mm:ss'),
    partition_day AS COALESCE(CAST(DATE_FORMAT(TO_TIMESTAMP(CAST(CAST(`timestamp` AS BIGINT) / 1000 AS STRING)), 'yyyy-MM-dd') AS DATE), CURRENT_DATE),
    WATERMARK FOR event_time AS TO_TIMESTAMP(event_time) - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'client_cold_start',
    'properties.bootstrap.servers' = 'b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092',
    'properties.group.id' = 'flink-kafka-doris-group',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- 创建本地文件输出表
CREATE TABLE local_file_sink (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    `timestamp` STRING,
    event_time TIMESTAMP,
    partition_day DATE
) WITH (
    'connector' = 'filesystem',
    'path' = 'file:///home/ubuntu/work/script/flink/output',
    'format' = 'json'
);

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
    partition_day DATE,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    event_time TIMESTAMP(3)
) WITH (
    'connector' = 'datagen',
    'rows-per-second' = '1',
    'fields.uid.kind' = 'sequence',
    'fields.uid.start' = '1',
    'fields.uid.end' = '1000',
    'fields.platformType.kind' = 'random',
    'fields.platformType.length' = '10',
    'fields.userIP.kind' = 'random',
    'fields.userIP.length' = '15',
    'fields.version.kind' = 'random',
    'fields.version.length' = '10',
    'fields.deviceId.kind' = 'random',
    'fields.deviceId.length' = '20',
    'fields.event_time.kind' = 'sequence',
    'fields.event_time.start' = '2024-01-01 00:00:00',
    'fields.event_time.end' = '2024-12-31 23:59:59',
    'fields.partition_day.kind' = 'sequence',
    'fields.partition_day.start' = '2024-01-01',
    'fields.partition_day.end' = '2024-12-31'
);

-- 1. 验证Kafka读取：将数据写入本地文件
INSERT INTO local_file_sink
SELECT 
    uid,
    platformType,
    userIP,
    version,
    deviceId,
    `timestamp`,
    event_time,
    partition_day
FROM kafka_source;

-- 2. 验证Doris写入：使用datagen数据源
INSERT INTO doris_sink
SELECT 
    partition_day,
    uid,
    platformType,
    userIP,
    version,
    deviceId,
    event_time
FROM datagen_source;

-- 调试：直接打印Kafka源表数据（限制5条）
SELECT * FROM kafka_source LIMIT 5; 