-- user_interests表测试 - 先验证数据读取
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

CREATE TABLE print_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING
) WITH (
    'connector' = 'print'
);

INSERT INTO print_sink SELECT id, user_id, interest_ids FROM mysql_user_interests; 