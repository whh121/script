-- user_interests表从MySQL到Doris实时数据同步作业
SET sql-client.execution.result-mode=TABLEAU;

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

-- 创建MySQL源表 - user_interests
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

-- 创建Doris目标表
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
    'sink.max-retries' = '3',
    'sink.label-prefix' = 'user_interests_sync'
);

-- 执行数据同步
INSERT INTO doris_user_interests_sink
SELECT
    id,
    user_id,
    interest_ids,
    CAST(updated_at AS STRING) AS updated_at,
    partition_day
FROM mysql_user_interests; 