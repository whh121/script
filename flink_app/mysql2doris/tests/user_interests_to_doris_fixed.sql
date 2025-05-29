-- user_interests表从MySQL到Doris实时数据同步作业 - 修复版本
SET sql-client.execution.result-mode=TABLEAU;

-- 设置checkpoint配置（参考成功案例）
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

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

-- 创建打印表用于调试
CREATE TABLE print_sink (
    partition_day DATE,
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at STRING
) WITH (
    'connector' = 'print'
);

-- 创建Doris目标表（参考成功配置）
CREATE TABLE doris_user_interests_sink (
    partition_day DATE,
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:9030',
    'table.identifier' = 'test_flink.user_interests_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'false',
    'sink.enable-2pc' = 'true',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '5',
    'sink.properties.columns' = 'partition_day, id, user_id, interest_ids, updated_at',
    'sink.label-prefix' = 'user_interests_to_doris',
    'sink.properties.read_timeout' = '3600',
    'sink.properties.write_timeout' = '3600'
);

-- 先打印数据验证
INSERT INTO print_sink
SELECT
    partition_day,
    id,
    user_id,
    interest_ids,
    CAST(updated_at AS STRING) AS updated_at
FROM mysql_user_interests;

-- 写入Doris
INSERT INTO doris_user_interests_sink
SELECT
    partition_day,
    id,
    user_id,
    interest_ids,
    CAST(updated_at AS STRING) AS updated_at
FROM mysql_user_interests; 