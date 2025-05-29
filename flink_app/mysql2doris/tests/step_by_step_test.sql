-- 步骤1: 创建简化的MySQL源表
CREATE TABLE mysql_source (
    id BIGINT,
    uid BIGINT,
    platformType STRING,
    created_time TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '10.10.33.48',
    'port' = '3306',
    'username' = 'root',
    'password' = 'mysql@123',
    'database-name' = 'test_flink',
    'table-name' = 'user_data'
);

-- 步骤2: 创建print表进行测试
CREATE TABLE print_sink (
    id BIGINT,
    uid BIGINT,
    platformType STRING
) WITH (
    'connector' = 'print'
);

-- 步骤3: 测试数据读取
INSERT INTO print_sink SELECT id, uid, platformType FROM mysql_source; 