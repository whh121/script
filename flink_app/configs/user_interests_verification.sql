-- =====================================================
-- Flink作业: mysql2doris_user_interests_prod
-- 生成时间: 2025-05-29 07:26:43
-- 环境: prod
-- 源表: content_behavior.user_interests
-- 目标表: xme_dw_ods.xme_ods_user_rds_user_interests_di
-- =====================================================
-- Flink执行配置
SET 'parallelism.default' = '8';

-- 检查点配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.timeout' = '600s';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file://./flink_app/mysql2doris/checkpoints';

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
-- 表名: source_user_interests-- 数据库: content_behavior
CREATE TABLE source_user_interests (    id BIGINT COMMENT '主键ID',    user_id BIGINT COMMENT '用户ID',    interest_type STRING COMMENT '兴趣类型',    interest_value STRING COMMENT '兴趣值',    score DECIMAL(10,2) COMMENT '评分',    created_at TIMESTAMP(3) COMMENT '创建时间',    updated_at TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id) NOT ENFORCED) WITH (
    'connector' = 'mysql-cdc',    'hostname' = 'xme-prod-rds-analysis-readonly.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com',
    'port' = '3306',
    'username' = 'prod-bigdata-user-interests',
    'password' = 'Dd4.fD3DFDk4.9cc',
    'database-name' = 'content_behavior',    'table-name' = 'user_interests',
    'server-id' = '5101-5104',
    'scan.startup.mode' = '{{ startup_mode | default('initial') }}',
    'debezium.snapshot.mode' = '{{ snapshot_mode | default('initial') }}',
    'debezium.snapshot.locking.mode' = '{{ snapshot_locking_mode | default('minimal') }}',
    'debezium.decimal.handling.mode' = 'string',
    'debezium.bigint.unsigned.handling.mode' = 'long',
    'debezium.include.schema.changes' = 'false',
    'debezium.tombstones.on.delete' = 'false'
); 
-- Doris目标表定义
-- 表名: xme_ods_user_rds_user_interests_di
-- 数据库: xme_dw_ods

CREATE TABLE sink_xme_ods_user_rds_user_interests_di (    id BIGINT COMMENT '主键ID',    user_id BIGINT COMMENT '用户ID',    interest_type STRING COMMENT '兴趣类型',    interest_value STRING COMMENT '兴趣值',    score DECIMAL(10,2) COMMENT '评分',    created_at TIMESTAMP(3) COMMENT '创建时间',    updated_at TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id) NOT ENFORCED) WITH (
    'connector' = 'doris',
    'fenodes' = '172.31.0.82:8030',
    'table.identifier' = 'xme_dw_ods.xme_ods_user_rds_user_interests_di',
    'username' = 'flink_user',
    'password' = 'flink@123',
    'sink.batch.size' = '2000',
    'sink.batch.interval' = '5s',
    'sink.max-retries' = '3',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true',
    'sink.properties.load-mode' = 'stream_load',
    'sink.enable-delete' = 'true'); 
-- 数据同步INSERT语句
INSERT INTO sink_xme_ods_user_rds_user_interests_di
SELECT    *FROM source_user_interests;

-- 作业监控信息
-- 作业名称: mysql2doris_user_interests_prod
-- 检查点目录: ./flink_app/mysql2doris/checkpoints
-- 监控地址: http://localhost:8081
-- 告警webhook: https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089 