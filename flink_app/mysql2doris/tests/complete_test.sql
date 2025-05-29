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

CREATE TABLE print_sink (
    id BIGINT,
    uid BIGINT,
    platformType STRING
) WITH (
    'connector' = 'print'
);

INSERT INTO print_sink SELECT id, uid, platformType FROM mysql_source; 