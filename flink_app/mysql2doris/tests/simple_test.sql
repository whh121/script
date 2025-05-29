-- 创建简单的MySQL源表
CREATE TABLE mysql_source (
    id BIGINT,
    uid BIGINT,
    platformType STRING
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '10.10.33.48',
    'port' = '3306',
    'username' = 'root',
    'password' = 'mysql@123',
    'database-name' = 'test_flink',
    'table-name' = 'user_data'
); 