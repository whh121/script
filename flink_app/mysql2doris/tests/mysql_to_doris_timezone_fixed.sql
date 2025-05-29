-- MySQL到Doris数据同步作业 - 修复时区问题
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
    'table-name' = 'user_data',
    'server-time-zone' = 'Asia/Shanghai'
);

CREATE TABLE print_sink (
    id BIGINT,
    uid BIGINT,
    platformType STRING
) WITH (
    'connector' = 'print'
);

INSERT INTO print_sink SELECT id, uid, platformType FROM mysql_source; 