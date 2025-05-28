-- MySQL到Doris实时数据同步 - 最终完整版本
-- 项目: user_interests表实时同步
-- 时间: 2025-05-27
-- 状态: 测试成功 ✅
-- 优化: 支持MySQL UPDATE操作，使用UNIQUE KEY模型

SET 'sql-client.execution.result-mode'='TABLEAU';

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file:///home/ubuntu/work/script/flink/checkpoints';
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- MySQL源表配置 (支持CDC变更数据捕获)
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

-- Doris目标表配置 (UNIQUE KEY模型支持UPDATE)
CREATE TABLE doris_user_interests_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3),
    partition_day DATE
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8030',
    'table.identifier' = 'test_flink.user_interests_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '3',
    'sink.properties.columns' = 'id, user_id, interest_ids, updated_at, partition_day',
    'sink.label-prefix' = 'user_interests_unique_sync'
);

-- 执行实时数据同步 (支持INSERT/UPDATE/DELETE)
INSERT INTO doris_user_interests_sink
SELECT 
    id,
    user_id,
    interest_ids,
    updated_at,
    CASE 
        WHEN updated_at IS NOT NULL THEN partition_day
        ELSE CURRENT_DATE
    END AS partition_day
FROM mysql_user_interests; 