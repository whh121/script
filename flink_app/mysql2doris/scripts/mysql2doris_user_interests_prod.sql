-- =====================================================
-- Flink作业: mysql2doris_user_interests_prod
-- 生成时间: 2025-05-29 08:03:08
-- 环境: prod
-- 源表: content_behavior.user_interests
-- 目标表: xme_dw_ods.xme_ods_user_rds_user_interests_di
-- =====================================================

-- Flink执行配置
SET 'parallelism.default' = '4';

-- 检查点配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file:///home/ubuntu/work/script/flink_app/mysql2doris/checkpoints';

-- 重启策略配置
SET 'restart-strategy' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '30s';

-- 性能优化配置
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'table.exec.sink.upsert-materialize' = 'none';

-- 网络配置
SET 'akka.ask.timeout' = '30s';
SET 'web.timeout' = '60s';



-- MySQL CDC源表定义
-- 表名: source_user_interests
-- 数据库: content_behavior

CREATE TABLE source_user_interests (
    id INT COMMENT 'auto_increment',
    user_id BIGINT COMMENT 'user_id字段',
    interest_ids STRING COMMENT 'interest_ids字段',
    updated_at TIMESTAMP(3) COMMENT 'DEFAULT_GENERATED on update CURRENT_TIMESTAMP',
    created_at TIMESTAMP(3) COMMENT 'DEFAULT_GENERATED',
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'xme-prod-rds-analysis-readonly.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com',
    'port' = '3306',
    'username' = 'prod-bigdata-user-interests',
    'password' = 'Dd4.fD3DFDk4.9cc',
    'database-name' = 'content_behavior',
    'table-name' = 'user_interests',
    'server-id' = '5101-5104',
    'scan.startup.mode' = 'initial',
    'debezium.snapshot.mode' = 'initial',
    'debezium.snapshot.locking.mode' = 'minimal',
    'debezium.decimal.handling.mode' = 'string',
    'debezium.bigint.unsigned.handling.mode' = 'long',
    'debezium.include.schema.changes' = 'false',
    'debezium.tombstones.on.delete' = 'false'
); 



-- Doris目标表定义
-- 表名: xme_ods_user_rds_user_interests_di
-- 数据库: xme_dw_ods

CREATE TABLE sink_xme_ods_user_rds_user_interests_di (
    id INT COMMENT 'auto_increment',
    user_id BIGINT COMMENT 'user_id字段',
    interest_ids STRING COMMENT 'interest_ids字段',
    updated_at TIMESTAMP(3) COMMENT 'DEFAULT_GENERATED on update CURRENT_TIMESTAMP',
    created_at TIMESTAMP(3) COMMENT 'DEFAULT_GENERATED',
    partition_day STRING COMMENT '分区日期字段，格式yyyy-MM-dd',
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = '172.31.0.82:8030',
    'table.identifier' = 'xme_dw_ods.xme_ods_user_rds_user_interests_di',
    'username' = 'flink_user',
    'password' = 'flink@123',
    'doris.batch.size' = '2000',
    'sink.buffer-flush.interval' = '5s',
    'sink.max-retries' = '3',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true',
    'sink.properties.load-mode' = 'stream_load',
    'sink.enable-delete' = 'true',
    'sink.label-prefix' = 'flink_mysql_cdc_20250529_1011'
); 

-- 数据同步INSERT语句
INSERT INTO sink_xme_ods_user_rds_user_interests_di
SELECT
    id,
    user_id,
    interest_ids,
    updated_at,
    created_at,
    DATE_FORMAT(created_at, 'yyyy-MM-dd') AS partition_day
FROM source_user_interests;

-- 作业监控信息
-- 作业名称: mysql2doris_user_interests_prod
-- 检查点目录: ./flink_app/mysql2doris/checkpoints
-- 监控地址: http://localhost:8081
-- 告警webhook: https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089 