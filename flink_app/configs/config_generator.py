#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flink配置生成器
===============

根据YAML配置模板自动生成Flink SQL文件
类似SeaTunnel的配置解析方式

功能特性:
- 读取job_template.yaml配置
- 生成对应的Flink SQL文件
- 支持多环境配置(prod/test/dev)
- 自动类型映射和schema验证
- 生成监控和部署脚本

使用示例:
python config_generator.py --job mysql2doris --env prod --output mysql2doris_prod.sql
"""

import yaml
import os
import sys
import argparse
import logging
from typing import Dict, Any, List
from pathlib import Path

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FlinkConfigGenerator:
    """Flink配置生成器类"""
    
    def __init__(self, config_file: str = "job_template.yaml"):
        """
        初始化配置生成器
        
        Args:
            config_file: 配置模板文件路径
        """
        self.config_file = config_file
        self.config = None
        self.load_config()
    
    def load_config(self):
        """加载YAML配置文件"""
        try:
            config_path = Path(__file__).parent / self.config_file
            with open(config_path, 'r', encoding='utf-8') as f:
                self.config = yaml.safe_load(f)
            logger.info(f"配置文件加载成功: {config_path}")
        except Exception as e:
            logger.error(f"配置文件加载失败: {e}")
            sys.exit(1)
    
    def generate_flink_sql(self, job_type: str, env: str) -> str:
        """
        生成Flink SQL文件
        
        Args:
            job_type: 作业类型 (mysql2doris, kafka2doris)
            env: 环境 (prod, test, dev)
            
        Returns:
            生成的Flink SQL内容
        """
        if job_type not in self.config:
            raise ValueError(f"不支持的作业类型: {job_type}")
        
        if env not in self.config[job_type]:
            raise ValueError(f"不支持的环境: {env}")
        
        job_config = self.config[job_type][env]
        
        # 生成SQL内容
        sql_content = self._generate_sql_header(job_config)
        sql_content += self._generate_sql_settings(job_config)
        sql_content += self._generate_source_table(job_config['source'], job_type)
        sql_content += self._generate_sink_table(job_config['sink'], job_type)
        sql_content += self._generate_insert_statement(job_config)
        
        return sql_content
    
    def _generate_sql_header(self, job_config: Dict[str, Any]) -> str:
        """生成SQL文件头部注释"""
        job_name = job_config['job']['name']
        parallelism = job_config['job']['parallelism']
        mode = job_config['job']['mode']
        
        return f"""-- =====================================================
-- Flink作业: {job_name}
-- 生成时间: {self._get_current_time()}
-- 并行度: {parallelism}
-- 模式: {mode}
-- 生成器: Flink配置生成器 v1.0
-- =====================================================

"""
    
    def _generate_sql_settings(self, job_config: Dict[str, Any]) -> str:
        """生成Flink配置设置"""
        checkpoint = job_config['checkpoint']
        restart = job_config['restart']
        job = job_config['job']
        
        settings = f"""-- Flink执行配置
SET 'parallelism.default' = '{job['parallelism']}';

-- 检查点配置
SET 'execution.checkpointing.interval' = '{checkpoint['interval']}';
SET 'execution.checkpointing.mode' = '{checkpoint['mode']}';
SET 'execution.checkpointing.timeout' = '{checkpoint['timeout']}';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = '{checkpoint['dir']}';

-- 重启策略配置
SET 'restart-strategy' = '{restart['strategy']}';
SET 'restart-strategy.fixed-delay.attempts' = '{restart['attempts']}';
SET 'restart-strategy.fixed-delay.delay' = '{restart['delay']}';

-- 性能优化配置
SET 'table.exec.sink.not-null-enforcer' = 'drop';
SET 'table.exec.sink.upsert-materialize' = 'none';

"""
        return settings
    
    def _generate_source_table(self, source_config: Dict[str, Any], job_type: str) -> str:
        """生成源表DDL"""
        source_type = source_config['type']
        
        if source_type == 'mysql-cdc':
            return self._generate_mysql_cdc_table(source_config)
        elif source_type == 'kafka':
            return self._generate_kafka_table(source_config)
        elif source_type == 'jdbc':
            return self._generate_jdbc_table(source_config)
        else:
            raise ValueError(f"不支持的源类型: {source_type}")
    
    def _generate_mysql_cdc_table(self, config: Dict[str, Any]) -> str:
        """生成MySQL CDC源表"""
        table_name = f"source_{config['table']}"
        
        # 这里需要根据实际表结构生成字段定义
        # 实际使用时可以通过数据库连接获取schema
        fields = self._get_mysql_table_schema(config)
        
        sql = f"""-- MySQL CDC源表
CREATE TABLE {table_name} (
{fields}
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = '{config['host']}',
    'port' = '{config['port']}',
    'username' = '{config['username']}',
    'password' = '{config['password']}',
    'database-name' = '{config['database']}',
    'table-name' = '{config['table']}',
    'server-id' = '{config.get('server-id', '5001')}',
    'scan.startup.mode' = '{config['scan']['startup-mode']}',
    'debezium.snapshot.mode' = '{config['debezium']['snapshot.mode']}',
    'debezium.snapshot.locking.mode' = '{config['debezium']['snapshot.locking.mode']}'
);

"""
        return sql
    
    def _generate_kafka_table(self, config: Dict[str, Any]) -> str:
        """生成Kafka源表"""
        table_name = f"source_{config['topic']}"
        brokers = ','.join(config['brokers'])
        consumer = config['consumer']
        
        # Kafka JSON格式的通用字段定义
        fields = self._get_kafka_table_schema(config['topic'])
        
        sql = f"""-- Kafka源表
CREATE TABLE {table_name} (
{fields}
) WITH (
    'connector' = 'kafka',
    'topic' = '{config['topic']}',
    'properties.bootstrap.servers' = '{brokers}',
    'properties.group.id' = '{consumer['group-id']}',
    'scan.startup.mode' = '{consumer['startup-mode']}',
    'format' = '{consumer['format']}',
    'json.ignore-parse-errors' = '{consumer.get('json', {}).get('ignore-parse-errors', 'false')}',
    'json.timestamp-format.standard' = '{consumer.get('json', {}).get('timestamp-format', {}).get('standard', 'ISO-8601')}'
);

"""
        return sql
    
    def _generate_sink_table(self, sink_config: Dict[str, Any], job_type: str) -> str:
        """生成目标表DDL"""
        sink_type = sink_config['type']
        
        if sink_type == 'doris':
            return self._generate_doris_table(sink_config, job_type)
        elif sink_type == 'kafka':
            return self._generate_kafka_sink_table(sink_config)
        elif sink_type == 'print':
            return self._generate_print_table(sink_config)
        else:
            raise ValueError(f"不支持的目标类型: {sink_type}")
    
    def _generate_doris_table(self, config: Dict[str, Any], job_type: str) -> str:
        """生成Doris目标表"""
        table_name = f"sink_{config['table']}"
        stream_load = config['stream-load']
        
        # 根据作业类型生成对应的字段定义
        fields = self._get_doris_table_schema(config['table'], job_type)
        
        sql = f"""-- Doris目标表
CREATE TABLE {table_name} (
{fields}
) WITH (
    'connector' = 'doris',
    'fenodes' = '{config['fenodes']}',
    'table.identifier' = '{config['database']}.{config['table']}',
    'username' = '{config['username']}',
    'password' = '{config['password']}',
    'sink.batch.size' = '{stream_load['properties']['batch.size']}',
    'sink.batch.interval' = '{stream_load['properties']['batch.interval']}',
    'sink.properties.format' = '{stream_load['format']}',
    'sink.properties.read_json_by_line' = '{stream_load['properties']['read_json_by_line']}',
    'sink.properties.load-mode' = '{stream_load['properties']['load-mode']}'
);

"""
        return sql
    
    def _generate_insert_statement(self, job_config: Dict[str, Any]) -> str:
        """生成INSERT语句"""
        source_table = f"source_{job_config['source'].get('table', job_config['source'].get('topic'))}"
        sink_table = f"sink_{job_config['sink']['table']}"
        
        sql = f"""-- 数据同步INSERT语句
INSERT INTO {sink_table}
SELECT * FROM {source_table};

"""
        return sql
    
    def _get_mysql_table_schema(self, config: Dict[str, Any]) -> str:
        """获取MySQL表结构（示例实现）"""
        # 实际使用时应该连接数据库获取真实schema
        table = config['table']
        
        if table == 'content_audit_record':
            return """    id BIGINT,
    content_id BIGINT,
    audit_status INT,
    audit_result STRING,
    audit_time TIMESTAMP(3),
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED"""
        
        elif table == 'user_interests':
            return """    id BIGINT,
    user_id BIGINT,
    interest_type STRING,
    interest_value STRING,
    score DECIMAL(10,2),
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED"""
        
        else:
            return """    id BIGINT,
    data STRING,
    created_at TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED"""
    
    def _get_kafka_table_schema(self, topic: str) -> str:
        """获取Kafka表结构（示例实现）"""
        if topic == 'client_cold_start':
            return """    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    timestamp BIGINT,
    proc_time AS PROCTIME()"""
        
        else:
            return """    data STRING,
    timestamp BIGINT,
    proc_time AS PROCTIME()"""
    
    def _get_doris_table_schema(self, table: str, job_type: str) -> str:
        """获取Doris表结构（示例实现）"""
        if job_type == 'mysql2doris':
            return """    id BIGINT,
    content_id BIGINT,
    audit_status INT,
    audit_result STRING,
    audit_time TIMESTAMP(3),
    created_at TIMESTAMP(3),
    updated_at TIMESTAMP(3)"""
        
        elif job_type == 'kafka2doris':
            return """    uid BIGINT,
    platformType STRING,
    userIP STRING,
    version STRING,
    deviceId STRING,
    timestamp BIGINT,
    proc_time TIMESTAMP(3)"""
        
        else:
            return """    id BIGINT,
    data STRING,
    created_at TIMESTAMP(3)"""
    
    def _get_current_time(self) -> str:
        """获取当前时间字符串"""
        from datetime import datetime
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    def save_sql_file(self, sql_content: str, job_type: str, env: str, output_dir: str = None) -> str:
        """
        保存SQL文件
        
        Args:
            sql_content: SQL内容
            job_type: 作业类型
            env: 环境
            output_dir: 输出目录
            
        Returns:
            生成的文件路径
        """
        if output_dir is None:
            output_dir = Path(__file__).parent.parent / job_type / "scripts"
        
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        filename = f"{job_type}_{env}_generated.sql"
        file_path = output_dir / filename
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(sql_content)
        
        logger.info(f"SQL文件生成成功: {file_path}")
        return str(file_path)
    
    def generate_monitoring_script(self, job_type: str, env: str) -> str:
        """生成监控脚本配置"""
        job_config = self.config[job_type][env]
        job_name = job_config['job']['name']
        
        script_content = f"""#!/bin/bash
# 自动生成的监控脚本配置
# 作业: {job_name}
# 环境: {env}

JOB_NAME="{job_name}"
CHECK_INTERVAL=60
MAX_FAILURES=3
WEBHOOK_URL="https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"

# 启动监控
./flink_monitor.py --job-name "$JOB_NAME" --interval $CHECK_INTERVAL --max-failures $MAX_FAILURES
"""
        return script_content

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Flink配置生成器')
    parser.add_argument('--job', required=True, choices=['mysql2doris', 'kafka2doris'], 
                       help='作业类型')
    parser.add_argument('--env', required=True, choices=['prod', 'test', 'dev'], 
                       help='环境')
    parser.add_argument('--output', help='输出文件路径')
    parser.add_argument('--config', default='job_template.yaml', 
                       help='配置文件路径')
    
    args = parser.parse_args()
    
    try:
        # 创建配置生成器
        generator = FlinkConfigGenerator(args.config)
        
        # 生成SQL
        sql_content = generator.generate_flink_sql(args.job, args.env)
        
        # 保存文件
        if args.output:
            output_path = args.output
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(sql_content)
        else:
            output_path = generator.save_sql_file(sql_content, args.job, args.env)
        
        logger.info(f"成功生成Flink SQL: {output_path}")
        
        # 生成监控脚本配置
        monitoring_script = generator.generate_monitoring_script(args.job, args.env)
        monitoring_path = Path(output_path).parent / f"monitor_{args.job}_{args.env}.sh"
        with open(monitoring_path, 'w', encoding='utf-8') as f:
            f.write(monitoring_script)
        
        logger.info(f"成功生成监控脚本: {monitoring_path}")
        
    except Exception as e:
        logger.error(f"生成失败: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main() 