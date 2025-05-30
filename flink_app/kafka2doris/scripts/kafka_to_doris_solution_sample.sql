SET sql-client.execution.result-mode=TABLEAU;

-- 设置 checkpoint 配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file:///home/ubuntu/work/script/flink_app/kafka2doris/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- 创建Kafka源表
CREATE TABLE kafka_source (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    `timestamp` STRING,
    event_time AS TO_TIMESTAMP_LTZ(CAST(`timestamp` AS BIGINT), 3),
    partition_day AS COALESCE(CAST(DATE_FORMAT(TO_TIMESTAMP(CAST(CAST(`timestamp` AS BIGINT) / 1000 AS STRING)), 'yyyy-MM-dd') AS DATE), CURRENT_DATE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'client_cold_start',
    'properties.bootstrap.servers' = 'b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092',
    'properties.group.id' = 'flink-kafka-doris-solution-group-2',
    'properties.auto.offset.reset' = 'earliest',
    'properties.enable.auto.commit' = 'false',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- 创建临时表用于调试
CREATE TABLE print_table (
    partition_day DATE,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    event_time STRING
) WITH (
    'connector' = 'print'
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
    'sink.properties.strip_outer_array' = 'false',
    'sink.enable-2pc' = 'true',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '5',
    'sink.properties.columns' = 'partition_day, uid, platformType, userIP, version, deviceId, event_time',
    'sink.label-prefix' = 'flink_to_doris_solution',
    'sink.properties.read_timeout' = '3600',
    'sink.properties.write_timeout' = '3600'
);

-- 创建文件系统目标表用于调试
CREATE TABLE fs_sink (
    partition_day DATE,
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    event_time STRING
) WITH (
    'connector' = 'filesystem',
    'path' = 'file:///home/ubuntu/work/script/flink/output/kafka_data',
    'format' = 'json'
);

-- 先打印出来看看
INSERT INTO print_table
SELECT
  partition_day,
  uid,
  platformType,
  userIP,
  version,
  COALESCE(deviceId, 'unknown') AS deviceId,
  CAST(event_time AS STRING)
FROM kafka_source;

-- 读取Kafka并写入Doris
INSERT INTO doris_sink
SELECT
  partition_day,
  uid,
  platformType,
  userIP,
  version,
  COALESCE(deviceId, 'unknown') AS deviceId,
  CAST(event_time AS STRING)
FROM kafka_source;

-- 写入文件系统进行调试
INSERT INTO fs_sink
SELECT
  partition_day,
  uid,
  platformType,
  userIP,
  version,
  COALESCE(deviceId, 'unknown') AS deviceId,
  CAST(event_time AS STRING)
FROM kafka_source; 