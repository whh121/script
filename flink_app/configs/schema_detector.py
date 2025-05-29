#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Schema检测器 - 连接真实数据库获取表结构
用于确保生成的Flink SQL与实际表结构保持一致
"""

import pymysql
import yaml
from typing import Dict, List, Any
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SchemaDetector:
    """MySQL表结构检测器"""
    
    def __init__(self, env_config_path: str):
        """初始化，加载环境配置"""
        with open(env_config_path, 'r', encoding='utf-8') as f:
            self.env_config = yaml.safe_load(f)
    
    def get_mysql_connection(self, table_name: str = None):
        """获取MySQL连接"""
        mysql_config = self.env_config['sources']['mysql']
        
        # 检查是否有表专用配置
        if table_name and table_name in mysql_config:
            config = mysql_config[table_name]
            host = config['host']
            port = config['port']
            username = config['username']
            password = config['password']
            database = config['database']
        else:
            # 使用默认配置
            host = mysql_config['host']
            port = mysql_config['port']
            username = mysql_config['username']
            password = mysql_config['password']
            database = mysql_config['databases']['content']  # 默认数据库
        
        return pymysql.connect(
            host=host,
            port=port,
            user=username,
            password=password,
            database=database,
            charset='utf8mb4'
        )
    
    def detect_table_schema(self, table_name: str, database_name: str = None) -> Dict[str, Any]:
        """检测表结构"""
        logger.info(f"检测表结构: {table_name}")
        
        try:
            connection = self.get_mysql_connection(table_name)
            cursor = connection.cursor()
            
            # 获取表结构
            if database_name:
                cursor.execute(f"DESCRIBE {database_name}.{table_name}")
            else:
                cursor.execute(f"DESCRIBE {table_name}")
            
            columns = cursor.fetchall()
            
            # 获取主键信息
            if database_name:
                cursor.execute(f"""
                    SELECT COLUMN_NAME 
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
                    WHERE TABLE_SCHEMA = '{database_name}' 
                    AND TABLE_NAME = '{table_name}' 
                    AND CONSTRAINT_NAME = 'PRIMARY'
                """)
            else:
                cursor.execute(f"""
                    SELECT COLUMN_NAME 
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
                    WHERE TABLE_NAME = '{table_name}' 
                    AND CONSTRAINT_NAME = 'PRIMARY'
                """)
            
            primary_keys = [row[0] for row in cursor.fetchall()]
            
            # 转换为Flink格式
            source_fields = []
            for col in columns:
                field_name = col[0]
                mysql_type = col[1]
                is_nullable = col[2] == 'YES'
                default_value = col[4]
                comment = col[5] if len(col) > 5 else ''
                
                # MySQL类型转Flink类型
                flink_type = self.mysql_to_flink_type(mysql_type)
                
                source_fields.append({
                    'name': field_name,
                    'mysql_type': mysql_type,
                    'flink_type': flink_type,
                    'nullable': is_nullable,
                    'comment': comment or f'{field_name}字段'
                })
            
            cursor.close()
            connection.close()
            
            logger.info(f"成功获取表结构: {table_name}, 字段数: {len(source_fields)}")
            
            return {
                'source_fields': source_fields,
                'target_fields': source_fields.copy(),  # 目标表字段与源表相同
                'primary_keys': primary_keys
            }
            
        except Exception as e:
            logger.error(f"获取表结构失败: {table_name}, 错误: {str(e)}")
            # 返回默认结构
            return self.get_default_schema(table_name)
    
    def mysql_to_flink_type(self, mysql_type: str) -> str:
        """MySQL类型转换为Flink类型"""
        mysql_type = mysql_type.lower()
        
        if 'bigint' in mysql_type:
            return 'BIGINT'
        elif 'int' in mysql_type:
            return 'INT'
        elif 'varchar' in mysql_type or 'text' in mysql_type or 'char' in mysql_type:
            return 'STRING'
        elif 'datetime' in mysql_type or 'timestamp' in mysql_type:
            return 'TIMESTAMP(3)'
        elif 'decimal' in mysql_type or 'numeric' in mysql_type:
            return 'DECIMAL(10,2)'
        elif 'float' in mysql_type or 'double' in mysql_type:
            return 'DOUBLE'
        elif 'date' in mysql_type:
            return 'DATE'
        elif 'time' in mysql_type:
            return 'TIME'
        elif 'boolean' in mysql_type or 'tinyint(1)' in mysql_type:
            return 'BOOLEAN'
        else:
            return 'STRING'  # 默认类型
    
    def get_default_schema(self, table_name: str) -> Dict[str, Any]:
        """获取默认表结构（当无法连接数据库时使用）"""
        logger.warning(f"使用默认表结构: {table_name}")
        
        if table_name == 'user_interests':
            return {
                'source_fields': [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'user_id', 'flink_type': 'BIGINT', 'comment': '用户ID'},
                    {'name': 'interest_type', 'flink_type': 'STRING', 'comment': '兴趣类型'},
                    {'name': 'interest_value', 'flink_type': 'STRING', 'comment': '兴趣值'},
                    {'name': 'score', 'flink_type': 'DECIMAL(10,2)', 'comment': '评分'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ],
                'target_fields': [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'user_id', 'flink_type': 'BIGINT', 'comment': '用户ID'},
                    {'name': 'interest_type', 'flink_type': 'STRING', 'comment': '兴趣类型'},
                    {'name': 'interest_value', 'flink_type': 'STRING', 'comment': '兴趣值'},
                    {'name': 'score', 'flink_type': 'DECIMAL(10,2)', 'comment': '评分'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ],
                'primary_keys': ['id']
            }
        else:
            # 默认content_audit_record结构
            return {
                'source_fields': [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'content_id', 'flink_type': 'BIGINT', 'comment': '内容ID'},
                    {'name': 'audit_status', 'flink_type': 'INT', 'comment': '审核状态'},
                    {'name': 'audit_result', 'flink_type': 'STRING', 'comment': '审核结果'},
                    {'name': 'audit_time', 'flink_type': 'TIMESTAMP(3)', 'comment': '审核时间'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ],
                'target_fields': [
                    {'name': 'id', 'flink_type': 'BIGINT', 'comment': '主键ID'},
                    {'name': 'content_id', 'flink_type': 'BIGINT', 'comment': '内容ID'},
                    {'name': 'audit_status', 'flink_type': 'INT', 'comment': '审核状态'},
                    {'name': 'audit_result', 'flink_type': 'STRING', 'comment': '审核结果'},
                    {'name': 'audit_time', 'flink_type': 'TIMESTAMP(3)', 'comment': '审核时间'},
                    {'name': 'created_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '创建时间'},
                    {'name': 'updated_at', 'flink_type': 'TIMESTAMP(3)', 'comment': '更新时间'}
                ],
                'primary_keys': ['id']
            }

if __name__ == "__main__":
    # 测试
    detector = SchemaDetector("environments/prod.yaml")
    schema = detector.detect_table_schema("user_interests")
    print("检测到的表结构:")
    for field in schema['source_fields']:
        print(f"  {field['name']}: {field['flink_type']} - {field['comment']}")
    print(f"主键: {schema['primary_keys']}") 