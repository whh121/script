-- user_interests表基础连接测试 - 使用JDBC connector
CREATE TABLE mysql_user_interests_jdbc (
    id INT,
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_behavior',
    'table-name' = 'user_interests',
    'username' = 'bigdata-user-interests',
    'password' = 'BId.3DKRF5dDFwfs'
);

CREATE TABLE print_sink (
    id INT,
    user_id BIGINT,
    interest_ids STRING
) WITH (
    'connector' = 'print'
);

INSERT INTO print_sink SELECT id, user_id, interest_ids FROM mysql_user_interests_jdbc LIMIT 10; 