#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flink模板生成器 v2.0
====================

基于分离的配置和SQL模板系统，生成Flink作业SQL文件

特性:
- 环境配置和作业定义分离
- 使用Jinja2模板引擎
- 支持模板继承和包含
- 自动Schema检测和类型映射
- 灵活的字段映射和过滤

使用示例:
python template_generator.py \
  --job mysql2doris \
  --env prod \
  --source-table content_audit_record \
  --target-table xme_ods_content_content_audit_record_di
"""

import yaml
import os
import sys
import argparse
import logging
from typing import Dict, Any, List, Optional
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass

try:
    from jinja2 import Environment, FileSystemLoader, select_autoescape
except ImportError:
    print("错误: 需要安装Jinja2模板引擎")
    print("请执行: pip install Jinja2")
    sys.exit(1)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class JobContext:
    """作业上下文数据类"""
    job_type: str
    job_name: str
    environment: str
    source_table: str
    target_table: str
    source_database: str = "content"
    target_database: str = "ods"
    consumer_group: Optional[str] = None
    source_topic: Optional[str] = None
    server_id: Optional[str] = None

class FlinkTemplateGenerator:
    """Flink模板生成器"""
    
    def __init__(self, configs_dir: str = None):
        """
        初始化模板生成器
        
        Args:
            configs_dir: 配置目录路径
        """
        if configs_dir is None:
            configs_dir = Path(__file__).parent
        
        self.configs_dir = Path(configs_dir)
        self.templates_dir = self.configs_dir / "templates"
        self.environments_dir = self.configs_dir / "environments"
        self.jobs_dir = self.configs_dir / "jobs"
        
        # 初始化Jinja2环境
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(self.templates_dir)),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=False,
            lstrip_blocks=False
        )
        
        # 添加自定义过滤器
        self.jinja_env.filters['lower'] = str.lower
        self.jinja_env.filters['upper'] = str.upper
        
    def load_environment_config(self, env: str) -> Dict[str, Any]:
        """加载环境配置"""
        env_file = self.environments_dir / f"{env}.yaml"
        if not env_file.exists():
            raise FileNotFoundError(f"环境配置文件不存在: {env_file}")
        
        with open(env_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        logger.info(f"加载环境配置: {env}")
        return config
    
    def load_job_definition(self, job_type: str) -> Dict[str, Any]:
        """加载作业定义"""
        job_file = self.jobs_dir / f"{job_type}.yaml"
        if not job_file.exists():
            raise FileNotFoundError(f"作业定义文件不存在: {job_file}")
        
        with open(job_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        logger.info(f"加载作业定义: {job_type}")
        return config
    
    def detect_schema(self, context: JobContext, env_config: Dict[str, Any]) -> Dict[str, Any]:
        """检测表结构信息"""
        # 尝试使用schema检测器获取真实表结构
        try:
            from schema_detector import SchemaDetector
            
            # 构建环境配置文件路径
            env_config_path = f"environments/{context.environment}.yaml"
            detector = SchemaDetector(env_config_path)
            
            if context.job_type == "mysql2doris":
                # 对于mysql2doris，直接检测MySQL表结构
                schema = detector.detect_table_schema(context.source_table)
                logger.info(f"成功检测到{context.source_table}表结构，字段数: {len(schema['source_fields'])}")
                return schema
            
        except Exception as e:
            logger.warning(f"无法获取真实表结构，使用默认结构: {str(e)}")
        
        # 如果无法连接数据库，使用默认schema
        if context.job_type == "mysql2doris":
            if context.source_table == "user_interests":
                # user_interests表的schema
                source_fields = [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'user_id', 'flink_type': 'BIGINT', 'comment': '用户ID'},
                    {'name': 'interest_type', 'flink_type': 'STRING', 'comment': '兴趣类型'},
                    {'name': 'interest_value', 'flink_type': 'STRING', 'comment': '兴趣值'},
                    {'name': 'score', 'flink_type': 'DECIMAL(10,2)', 'comment': '评分'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ]
                target_fields = source_fields.copy()
                primary_keys = ['id']
            else:
                # 默认content_audit_record表的schema
                source_fields = [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'content_id', 'flink_type': 'BIGINT', 'comment': '内容ID'},
                    {'name': 'audit_status', 'flink_type': 'INT', 'comment': '审核状态'},
                    {'name': 'audit_result', 'flink_type': 'STRING', 'comment': '审核结果'},
                    {'name': 'audit_time', 'flink_type': 'TIMESTAMP(3)', 'comment': '审核时间'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ]
                target_fields = source_fields.copy()
                primary_keys = ['id']
            
        elif context.job_type == "kafka2doris":
            source_fields = [
                {'name': 'uid', 'flink_type': 'BIGINT', 'comment': '用户ID'},
                {'name': 'platformType', 'flink_type': 'STRING', 'comment': '平台类型'},
                {'name': 'userIP', 'flink_type': 'STRING', 'comment': '用户IP'},
                {'name': 'version', 'flink_type': 'STRING', 'comment': '版本号'},
                {'name': 'deviceId', 'flink_type': 'STRING', 'comment': '设备ID'},
                {'name': 'timestamp', 'flink_type': 'BIGINT', 'comment': '时间戳'}
            ]
            target_fields = source_fields.copy()
            primary_keys = []
        
        else:
            raise ValueError(f"不支持的作业类型: {context.job_type}")
        
        return {
            'source_fields': source_fields,
            'target_fields': target_fields,
            'primary_keys': primary_keys
        }
    
    def generate_server_id(self, env_config: Dict[str, Any], context: JobContext) -> str:
        """生成MySQL Server ID"""
        if context.job_type != "mysql2doris":
            return ""
        
        # 检查是否有表专用配置
        if context.source_table in env_config['sources']['mysql']:
            server_id_range = env_config['sources']['mysql'][context.source_table]['server_id_range']
        else:
            server_id_range = env_config['sources']['mysql']['server_id_range']
        
        start_id, end_id = server_id_range.split('-')
        
        # 简单的ID分配策略，实际使用时可以更复杂
        return f"{start_id}-{int(start_id) + 3}"
    
    def generate_consumer_group(self, context: JobContext) -> str:
        """生成Kafka消费者组ID"""
        if context.job_type != "kafka2doris":
            return ""
        
        topic = context.source_topic or "default_topic"
        return f"flink_{context.job_type}_{topic}_{context.environment}"
    
    def prepare_template_context(self, context: JobContext, 
                                env_config: Dict[str, Any], 
                                job_config: Dict[str, Any]) -> Dict[str, Any]:
        """准备模板渲染上下文"""
        
        # 检测Schema
        schema = self.detect_schema(context, env_config)
        
        # 生成表名
        source_table_name = f"source_{context.source_table}"
        target_table_name = f"sink_{context.target_table}"
        
        # 准备渲染上下文
        template_context = {
            # 基本信息
            'job_type': context.job_type,
            'job_name': context.job_name,
            'current_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            
            # 环境配置
            'env': env_config,
            
            # 作业配置
            'job': job_config,
            
            # 表信息
            'source_table': context.source_table,
            'target_table': context.target_table,
            'source_database': context.source_database,
            'target_database': context.target_database,
            'source_table_name': source_table_name,
            'target_table_name': target_table_name,
            
            # Schema信息
            'schema': schema,
            
            # 额外参数
            'server_id': context.server_id or self.generate_server_id(env_config, context),
            'consumer_group': context.consumer_group or self.generate_consumer_group(context),
            'source_topic': context.source_topic
        }
        
        return template_context
    
    def render_template(self, template_name: str, context: Dict[str, Any]) -> str:
        """渲染模板"""
        try:
            template = self.jinja_env.get_template(template_name)
            return template.render(context)
        except Exception as e:
            logger.error(f"模板渲染失败: {template_name}, 错误: {e}")
            raise
    
    def generate_sql(self, context: JobContext) -> str:
        """生成完整的Flink SQL"""
        
        # 加载配置
        env_config = self.load_environment_config(context.environment)
        job_config = self.load_job_definition(context.job_type)
        
        # 准备模板上下文
        template_context = self.prepare_template_context(context, env_config, job_config)
        
        # 选择模板
        template_name = job_config['templates']['complete_sql']
        
        # 渲染模板
        sql_content = self.render_template(template_name, template_context)
        
        logger.info(f"成功生成SQL: {context.job_name}")
        return sql_content
    
    def save_sql_file(self, sql_content: str, context: JobContext, 
                     output_path: str = None) -> str:
        """保存SQL文件"""
        
        if output_path is None:
            # 默认保存到对应项目的scripts目录
            project_dir = self.configs_dir.parent / context.job_type / "scripts"
            project_dir.mkdir(parents=True, exist_ok=True)
            filename = f"{context.job_name}_{context.environment}_generated.sql"
            output_path = project_dir / filename
        
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(sql_content)
        
        logger.info(f"SQL文件已保存: {output_path}")
        return str(output_path)
    
    def generate_monitoring_config(self, context: JobContext, 
                                  env_config: Dict[str, Any]) -> str:
        """生成监控配置"""
        
        config = f"""#!/bin/bash
# 监控配置 - {context.job_name}
# 自动生成于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

JOB_NAME="{context.job_name}"
ENVIRONMENT="{context.environment}"
CHECK_INTERVAL={env_config['monitoring']['check_interval']}
MAX_FAILURES={env_config['monitoring']['max_failures']}
WEBHOOK_URL="{env_config['monitoring']['webhook_url']}"

# 检查点目录
CHECKPOINT_DIR="{env_config['checkpoint']['base_dir']}/{context.job_type}/checkpoints"

# Flink Web UI
FLINK_WEB_UI="http://localhost:8081"

echo "监控配置已加载: $JOB_NAME ($ENVIRONMENT)"
"""
        return config

def create_job_context(args) -> JobContext:
    """创建作业上下文"""
    
    # 生成作业名称
    if args.job == "mysql2doris":
        job_name = f"mysql2doris_{args.source_table}_{args.env}"
        source_topic = None
    elif args.job == "kafka2doris":
        job_name = f"kafka2doris_{args.source_topic}_{args.env}"
        source_topic = args.source_topic
    else:
        raise ValueError(f"不支持的作业类型: {args.job}")
    
    context = JobContext(
        job_type=args.job,
        job_name=job_name,
        environment=args.env,
        source_table=args.source_table or "default_table",
        target_table=args.target_table or "default_target",
        source_database=args.source_db or "content",
        target_database=args.target_db or "ods",
        source_topic=source_topic,
        server_id=args.server_id,
        consumer_group=args.consumer_group
    )
    
    return context

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Flink模板生成器 v2.0')
    
    # 基本参数
    parser.add_argument('--job', required=True, choices=['mysql2doris', 'kafka2doris'],
                       help='作业类型')
    parser.add_argument('--env', required=True, choices=['prod', 'test', 'dev'],
                       help='环境')
    
    # 表信息
    parser.add_argument('--source-table', help='源表名')
    parser.add_argument('--target-table', help='目标表名')
    parser.add_argument('--source-db', help='源数据库名 (默认: content)')
    parser.add_argument('--target-db', help='目标数据库名 (默认: ods)')
    
    # Kafka相关
    parser.add_argument('--source-topic', help='Kafka源Topic')
    parser.add_argument('--consumer-group', help='Kafka消费者组')
    
    # MySQL相关
    parser.add_argument('--server-id', help='MySQL CDC Server ID')
    
    # 输出选项
    parser.add_argument('--output', help='输出文件路径')
    parser.add_argument('--configs-dir', help='配置目录路径')
    
    args = parser.parse_args()
    
    # 参数验证
    if args.job == "mysql2doris" and not args.source_table:
        parser.error("mysql2doris作业需要指定 --source-table")
    
    if args.job == "kafka2doris" and not args.source_topic:
        parser.error("kafka2doris作业需要指定 --source-topic")
    
    try:
        # 创建生成器
        generator = FlinkTemplateGenerator(args.configs_dir)
        
        # 创建作业上下文
        context = create_job_context(args)
        
        # 生成SQL
        sql_content = generator.generate_sql(context)
        
        # 保存文件
        output_path = generator.save_sql_file(sql_content, context, args.output)
        
        # 生成监控配置
        env_config = generator.load_environment_config(args.env)
        monitoring_config = generator.generate_monitoring_config(context, env_config)
        
        # 保存监控配置
        monitoring_path = Path(output_path).parent / f"monitor_{context.job_name}.sh"
        with open(monitoring_path, 'w', encoding='utf-8') as f:
            f.write(monitoring_config)
        
        print(f"✅ 成功生成Flink作业:")
        print(f"   SQL文件: {output_path}")
        print(f"   监控配置: {monitoring_path}")
        print(f"   作业名称: {context.job_name}")
        print(f"   环境: {context.environment}")
        
    except Exception as e:
        logger.error(f"生成失败: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main() 