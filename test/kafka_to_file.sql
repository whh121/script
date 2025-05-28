SET sql-client.execution.result-mode=TABLEAU;

-- 创建Kafka源表
CREATE TABLE kafka_source (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    `timestamp` STRING,
    event_time AS COALESCE(TO_TIMESTAMP(CAST(CAST(`timestamp` AS BIGINT) / 1000 AS STRING)), CURRENT_TIMESTAMP),
    partition_day AS COALESCE(CAST(DATE_FORMAT(TO_TIMESTAMP(CAST(CAST(`timestamp` AS BIGINT) / 1000 AS STRING)), 'yyyy-MM-dd') AS DATE), CURRENT_DATE),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
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
    event_time STRING,
    partition_day DATE
) WITH (
    'connector' = 'filesystem',
    'path' = 'file:///home/ubuntu/work/script/flink/output',
    'format' = 'json'
);

-- 验证Kafka读取：将数据写入本地文件
INSERT INTO local_file_sink
SELECT 
    uid,
    platformType,
    userIP,
    version,
    deviceId,
    `timestamp`,
    CAST(event_time AS STRING),
    partition_day
FROM kafka_source; 