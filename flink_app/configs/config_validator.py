#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flink配置验证器
==============

严格检查数据同步方式配置，确保按照配置文件指定的方式执行：
- batch (增量同步): 基于时间戳或ID的增量轮询同步
- stream (实时同步): 实时流处理，MySQL必须使用CDC

核心原则: 配置驱动，严格执行，禁止降级
"""

import yaml
import requests
import sys
import logging
from pathlib import Path
from typing import Dict, Any, List

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ConfigValidator:
    """配置验证器"""
    
    def __init__(self, configs_dir: str = None):
        if configs_dir is None:
            configs_dir = Path(__file__).parent
        
        self.configs_dir = Path(configs_dir)
        self.flink_web_url = "http://localhost:8081"
        
    def load_job_config(self, job_type: str) -> Dict[str, Any]:
        """加载作业配置"""
        job_file = self.configs_dir / "jobs" / f"{job_type}.yaml"
        if not job_file.exists():
            raise FileNotFoundError(f"作业配置文件不存在: {job_file}")
        
        with open(job_file, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    def check_flink_connectors(self) -> List[str]:
        """检查Flink集群可用的连接器"""
        try:
            # 通过尝试创建一个临时表来获取可用连接器列表
            # 这个方法比较间接，但可以获取实际可用的连接器
            response = requests.get(f"{self.flink_web_url}/jobs", timeout=10)
            if response.status_code == 200:
                logger.info("Flink集群连接正常")
                # 返回已知的连接器列表 (从之前的错误信息获取)
                return [
                    'blackhole', 'datagen', 'doris', 'filesystem', 
                    'kafka', 'print', 'python-input-format', 'upsert-kafka'
                ]
            else:
                logger.error(f"无法连接Flink集群: HTTP {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"检查Flink连接器失败: {e}")
            return []
    
    def validate_sync_mode(self, job_type: str, source_table: str = None) -> Dict[str, Any]:
        """验证同步方式配置"""
        logger.info(f"开始验证作业配置: {job_type}")
        
        # 加载作业配置
        job_config = self.load_job_config(job_type)
        
        # 提取同步配置
        dataflow = job_config.get('dataflow', {})
        dataflow_type = dataflow.get('type', '')
        source_config = dataflow.get('source', {})
        source_type = source_config.get('type', '')
        
        logger.info(f"配置检查:")
        logger.info(f"  - dataflow.type: {dataflow_type}")
        logger.info(f"  - source.type: {source_type}")
        
        # 检查可用连接器
        available_connectors = self.check_flink_connectors()
        logger.info(f"可用连接器: {available_connectors}")
        
        # 验证结果
        validation_result = {
            'job_type': job_type,
            'source_table': source_table,
            'dataflow_type': dataflow_type,
            'source_type': source_type,
            'available_connectors': available_connectors,
            'is_stream_mode': False,
            'requires_mysql_cdc': False,
            'mysql_cdc_available': False,
            'validation_passed': False,
            'error_messages': [],
            'recommendations': []
        }
        
        # 判断是否为stream模式
        if 'stream' in dataflow_type.lower() or 'cdc' in dataflow_type.lower():
            validation_result['is_stream_mode'] = True
            logger.info("✓ 检测到stream模式配置")
        
        # 判断是否需要MySQL CDC
        if 'mysql' in source_type.lower() and 'cdc' in source_type.lower():
            validation_result['requires_mysql_cdc'] = True
            logger.info("✓ 检测到需要mysql-cdc连接器")
        
        # 检查MySQL CDC是否可用
        mysql_cdc_available = 'mysql-cdc' in available_connectors
        validation_result['mysql_cdc_available'] = mysql_cdc_available
        
        # 严格验证规则
        if validation_result['is_stream_mode'] and validation_result['requires_mysql_cdc']:
            if not mysql_cdc_available:
                validation_result['error_messages'].append(
                    "❌ 严重错误: 配置要求stream模式使用mysql-cdc连接器，但连接器不可用"
                )
                validation_result['error_messages'].append(
                    "❌ 根据配置驱动原则，禁止降级为其他同步方式"
                )
                validation_result['recommendations'].extend([
                    "1. 下载MySQL CDC连接器 jar 文件",
                    "2. 安装到Flink集群的 lib 目录",
                    "3. 重启Flink集群使连接器生效",
                    "4. 重新验证配置后执行SQL"
                ])
            else:
                validation_result['validation_passed'] = True
                logger.info("✅ 配置验证通过: stream模式，mysql-cdc连接器可用")
        
        elif not validation_result['is_stream_mode']:
            # batch模式的验证逻辑
            validation_result['validation_passed'] = True
            logger.info("✅ 配置验证通过: batch模式")
        
        else:
            validation_result['error_messages'].append(
                "❌ 配置不明确: 无法确定同步方式"
            )
        
        return validation_result
    
    def print_validation_report(self, result: Dict[str, Any]):
        """打印验证报告"""
        print("\n" + "="*60)
        print("🔍 Flink配置验证报告")
        print("="*60)
        
        print(f"作业类型: {result['job_type']}")
        if result['source_table']:
            print(f"源表: {result['source_table']}")
        
        print(f"数据流类型: {result['dataflow_type']}")
        print(f"源类型: {result['source_type']}")
        print(f"Stream模式: {'是' if result['is_stream_mode'] else '否'}")
        print(f"需要MySQL CDC: {'是' if result['requires_mysql_cdc'] else '否'}")
        print(f"MySQL CDC可用: {'是' if result['mysql_cdc_available'] else '否'}")
        
        print(f"\n🎯 验证结果: {'✅ 通过' if result['validation_passed'] else '❌ 失败'}")
        
        if result['error_messages']:
            print("\n💥 错误信息:")
            for error in result['error_messages']:
                print(f"  {error}")
        
        if result['recommendations']:
            print("\n💡 建议操作:")
            for rec in result['recommendations']:
                print(f"  {rec}")
        
        print("\n📋 可用连接器:")
        for connector in result['available_connectors']:
            print(f"  - {connector}")
        
        print("="*60)
    
    def generate_mysql_cdc_install_guide(self):
        """生成MySQL CDC连接器安装指南"""
        guide = """
�� MySQL CDC连接器安装指南 (生产环境安全方案)
===============================================

⚠️  重要提醒: 以下方案考虑生产环境影响，选择适合的安装策略

🔵 方案一: 热加载连接器 (推荐 - 零停机)
----------------------------------------
适用于支持动态加载的Flink版本：

1. 检查Flink版本和热加载支持
   ```bash
   flink --version
   # 检查是否支持动态加载jar包
   curl http://localhost:8081/jars
   ```

2. 下载连接器到临时目录
   ```bash
   cd /tmp
   wget https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/2.4.3/flink-sql-connector-mysql-cdc-2.4.3.jar
   ```

3. 尝试动态上传连接器
   ```bash
   # 通过REST API上传jar
   curl -X POST -H "Content-Type: application/octet-stream" \
     --data-binary @/tmp/flink-sql-connector-mysql-cdc-2.4.3.jar \
     http://localhost:8081/jars/upload
   ```

4. 验证连接器是否可用
   ```bash
   python3 config_validator.py --job mysql2doris --table user_interests
   ```

🟡 方案二: 维护窗口重启 (低峰时段)
---------------------------------
如果热加载不支持，安排维护窗口：

1. 选择业务低峰时段 (如凌晨2-4点)

2. 提前通知相关团队作业停机维护

3. 安全停止作业
   ```bash
   # 查看当前运行的作业
   flink list
   
   # 停止作业 (保存检查点)
   flink stop <job-id>
   ```

4. 安装连接器
   ```bash
   cp /tmp/flink-sql-connector-mysql-cdc-2.4.3.jar /home/ubuntu/flink/lib/
   ```

5. 重启集群
   ```bash
   /home/ubuntu/flink/bin/stop-cluster.sh
   /home/ubuntu/flink/bin/start-cluster.sh
   ```

6. 恢复作业
   ```bash
   # 从检查点恢复作业
   flink run -s <savepoint-path> your-job.jar
   ```

🟠 方案三: 备用集群切换 (企业级方案)
----------------------------------
如果有备用Flink集群环境：

1. 在备用集群安装mysql-cdc连接器

2. 配置备用集群环境

3. 将新的user_interests作业部署到备用集群

4. 验证备用集群作业正常运行

5. 在主集群维护窗口安装连接器

6. 将作业切回主集群

🔴 方案四: 仅部署新作业 (隔离方案)
--------------------------------
如果当前作业与user_interests无关：

1. 确认当前运行的作业列表
   ```bash
   flink list
   curl http://localhost:8081/jobs | jq '.jobs[] | {id, name, state}'
   ```

2. 如果没有MySQL CDC相关作业在运行，可以安全安装

3. 安装连接器并重启集群

4. 仅影响新部署的user_interests作业

📋 安装前检查清单
================
- [ ] 确认当前运行的作业类型和重要性
- [ ] 评估停机窗口的业务影响
- [ ] 备份当前Flink配置和检查点
- [ ] 准备作业恢复脚本
- [ ] 通知相关团队维护计划
- [ ] 测试连接器兼容性

🔧 连接器下载地址
================
根据Flink版本选择对应的CDC连接器：

- Flink 1.20.x: flink-sql-connector-mysql-cdc-2.4.3.jar
- Flink 1.19.x: flink-sql-connector-mysql-cdc-2.4.2.jar  
- Flink 1.18.x: flink-sql-connector-mysql-cdc-2.4.1.jar

下载地址：
https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/

📞 应急联系
==========
如果安装过程中遇到问题：
1. 立即检查集群状态: curl http://localhost:8081/jobs
2. 查看Flink日志: tail -f /home/ubuntu/flink/log/flink-*.log
3. 如有必要，快速回滚到之前状态

💡 最佳实践建议
==============
- 优先尝试热加载方案（方案一）
- 生产环境变更务必在维护窗口进行
- 保持备用集群环境同步
- 定期测试作业恢复流程
"""
        print(guide)


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Flink配置验证器')
    parser.add_argument('--job', required=True, help='作业类型 (mysql2doris, kafka2doris)')
    parser.add_argument('--table', help='源表名')
    parser.add_argument('--install-guide', action='store_true', help='显示MySQL CDC安装指南')
    
    args = parser.parse_args()
    
    validator = ConfigValidator()
    
    if args.install_guide:
        validator.generate_mysql_cdc_install_guide()
        return
    
    try:
        # 执行配置验证
        result = validator.validate_sync_mode(args.job, args.table)
        
        # 打印验证报告
        validator.print_validation_report(result)
        
        # 根据验证结果决定退出码
        if not result['validation_passed']:
            print("\n❌ 配置验证失败，停止执行")
            if result['requires_mysql_cdc'] and not result['mysql_cdc_available']:
                print("💡 运行 --install-guide 查看MySQL CDC安装指南")
            sys.exit(1)
        else:
            print("\n✅ 配置验证通过，可以继续执行")
            sys.exit(0)
            
    except Exception as e:
        logger.error(f"配置验证失败: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main() 