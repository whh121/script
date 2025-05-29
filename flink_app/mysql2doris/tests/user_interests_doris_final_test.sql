-- 修复版本: user_interests到Doris实时同步
SET 'sql-client.execution.result-mode'='TABLEAU';

-- 设置checkpoint配置（参考成功案例）
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- MySQL源表 (已验证可工作)
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

-- Doris目标表 (修复配置)
CREATE TABLE doris_user_interests_sink (
    partition_day DATE,
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8040',
    'table.identifier' = 'test_flink.user_interests_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'false',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.max-bytes' = '1048576',
    'sink.buffer-flush.interval' = '5s',
    'sink.max-retries' = '3',
    'sink.properties.columns' = 'partition_day, id, user_id, interest_ids, updated_at',
    'sink.label-prefix' = 'user_interests_sync'
);

-- 执行数据同步
INSERT INTO doris_user_interests_sink
SELECT
    partition_day,
    id,
    user_id,
    interest_ids,
    CAST(updated_at AS STRING) AS updated_at
FROM mysql_user_interests; 