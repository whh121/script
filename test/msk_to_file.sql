-- 创建Kafka源表
CREATE TABLE kafka_source (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    `timestamp` STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'client_cold_start',
    'properties.bootstrap.servers' = 'b-1.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-2.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092,b-3.xmeprodlog.o53475.c3.kafka.ap-southeast-1.amazonaws.com:9092',
    'properties.group.id' = 'flink-msk-test',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true',
    'properties.security.protocol' = 'PLAINTEXT',
    'properties.auto.offset.reset' = 'earliest'
);

-- 创建文件输出表
CREATE TABLE file_sink (
    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    `timestamp` STRING,
    process_time TIMESTAMP(3)
) WITH (
    'connector' = 'filesystem',
    'path' = 'file:///tmp/flink-msk-output',
    'format' = 'json',
    'sink.rolling-policy.file-size' = '1MB',
    'sink.rolling-policy.rollover-interval' = '1 min',
    'sink.rolling-policy.check-interval' = '1 min'
);

-- 插入数据到文件
INSERT INTO file_sink
SELECT 
    uid,
    platformType,
    userIP,
    version,
    `timestamp`,
    CURRENT_TIMESTAMP as process_time
FROM kafka_source; 