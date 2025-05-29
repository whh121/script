-- Doris写入测试 - 修复buffer参数
SET 'sql-client.execution.result-mode'='TABLEAU';

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

-- MySQL源表 (已验证可工作)
CREATE TABLE mysql_user_interests (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3),
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

-- Doris目标表 (修复buffer参数)
CREATE TABLE doris_user_interests_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8040',
    'table.identifier' = 'test_flink.user_interests_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '10000',
    'sink.buffer-flush.max-bytes' = '10485760',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '3'
);

-- 执行数据同步
INSERT INTO doris_user_interests_sink
SELECT id, user_id, interest_ids FROM mysql_user_interests; 