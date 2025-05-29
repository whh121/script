-- 步骤1: 测试MySQL CDC读取（已验证可工作）
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

-- 步骤2: 创建Doris表（参考成功案例配置）
CREATE TABLE doris_user_interests_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING
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
    'sink.properties.columns' = 'id, user_id, interest_ids',
    'sink.label-prefix' = 'user_interests_to_doris',
    'sink.properties.read_timeout' = '3600',
    'sink.properties.write_timeout' = '3600'
);

-- 步骤3: 执行数据同步（简化版本）
INSERT INTO doris_user_interests_sink 
SELECT id, user_id, interest_ids FROM mysql_user_interests; 