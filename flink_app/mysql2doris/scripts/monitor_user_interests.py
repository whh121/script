#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
user_interests表MySQL CDC到Doris同步监控脚本
作业ID: 275a6f22da1f5bdf896b9341028b2de0
监控内容: 作业状态、数据同步延迟、错误告警
"""

import requests
import json
import time
import logging
import datetime
import os
import sys

# 日志配置
log_dir = os.path.join(os.path.dirname(__file__), '..', 'logs')
os.makedirs(log_dir, exist_ok=True)

# 按天切割日志
log_file = os.path.join(log_dir, f"user_interests_monitor_{datetime.datetime.now().strftime('%Y%m%d')}.log")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# 配置参数
FLINK_REST_URL = "http://localhost:8081"
JOB_ID = "275a6f22da1f5bdf896b9341028b2de0"
JOB_NAME = "user_interests_mysql_cdc"
WEBHOOK_URL = "https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"

# 状态文件
STATUS_FILE = os.path.join(log_dir, "user_interests_status.json")

class UserInterestsMonitor:
    def __init__(self):
        self.last_status = self.load_last_status()
        
    def load_last_status(self):
        """加载上次状态，避免重复告警"""
        try:
            if os.path.exists(STATUS_FILE):
                with open(STATUS_FILE, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"加载状态文件失败: {e}")
        return {}
    
    def save_status(self, status):
        """保存当前状态"""
        try:
            status['timestamp'] = time.time()
            with open(STATUS_FILE, 'w', encoding='utf-8') as f:
                json.dump(status, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存状态文件失败: {e}")
    
    def send_alert(self, message, is_error=False):
        """发送飞书告警"""
        try:
            color = "red" if is_error else "green"
            payload = {
                "msg_type": "interactive",
                "card": {
                    "config": {"wide_screen_mode": True},
                    "header": {
                        "title": {
                            "tag": "plain_text",
                            "content": f"🔍 user_interests CDC监控 {'❌' if is_error else '✅'}"
                        },
                        "template": color
                    },
                    "elements": [
                        {
                            "tag": "div",
                            "text": {
                                "tag": "lark_md",
                                "content": f"**作业**: {JOB_NAME}\n**时间**: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n**消息**: {message}"
                            }
                        }
                    ]
                }
            }
            
            response = requests.post(
                WEBHOOK_URL,
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                logger.info("告警发送成功")
            else:
                logger.error(f"告警发送失败: {response.status_code} - {response.text}")
                
        except Exception as e:
            logger.error(f"发送告警异常: {e}")
    
    def check_flink_cluster(self):
        """检查Flink集群状态"""
        try:
            response = requests.get(f"{FLINK_REST_URL}/overview", timeout=30)
            if response.status_code == 200:
                data = response.json()
                logger.info(f"Flink集群状态: TaskManagers={data.get('taskmanagers', 0)}, "
                           f"运行作业={data.get('jobs-running', 0)}, "
                           f"失败作业={data.get('jobs-failed', 0)}")
                return True
            else:
                logger.error(f"Flink集群检查失败: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Flink集群连接异常: {e}")
            return False
    
    def check_job_status(self):
        """检查作业状态"""
        try:
            response = requests.get(f"{FLINK_REST_URL}/jobs/{JOB_ID}", timeout=30)
            if response.status_code == 200:
                job_data = response.json()
                current_state = job_data.get('state', 'UNKNOWN')
                job_name = job_data.get('name', JOB_NAME)
                duration = job_data.get('duration', 0)
                
                logger.info(f"作业状态: {current_state}, 运行时长: {duration}ms")
                
                # 检查状态变化
                last_state = self.last_status.get('job_state')
                if last_state != current_state:
                    if current_state == 'RUNNING':
                        message = f"user_interests CDC作业已启动\n作业名称: {job_name}\n作业ID: {JOB_ID}"
                        self.send_alert(message, is_error=False)
                    elif current_state in ['FAILED', 'CANCELED']:
                        message = f"user_interests CDC作业异常\n状态: {current_state}\n作业ID: {JOB_ID}"
                        self.send_alert(message, is_error=True)
                
                return {
                    'status': 'ok',
                    'job_state': current_state,
                    'duration': duration,
                    'job_name': job_name
                }
            else:
                logger.error(f"作业状态检查失败: {response.status_code}")
                if response.status_code == 404:
                    message = f"user_interests CDC作业未找到\n作业ID: {JOB_ID}\n可能已停止或失败"
                    self.send_alert(message, is_error=True)
                return {'status': 'error', 'job_state': 'NOT_FOUND'}
                
        except Exception as e:
            logger.error(f"作业状态检查异常: {e}")
            return {'status': 'error', 'job_state': 'ERROR'}
    
    def check_job_metrics(self):
        """检查作业指标"""
        try:
            response = requests.get(f"{FLINK_REST_URL}/jobs/{JOB_ID}/vertices", timeout=30)
            if response.status_code == 200:
                vertices = response.json().get('vertices', [])
                
                total_records = 0
                total_bytes = 0
                
                for vertex in vertices:
                    metrics = vertex.get('metrics', {})
                    records = metrics.get('read-records', 0)
                    bytes_read = metrics.get('read-bytes', 0)
                    
                    total_records += records
                    total_bytes += bytes_read
                
                logger.info(f"数据指标: 读取记录数={total_records}, 读取字节数={total_bytes}")
                
                return {
                    'total_records': total_records,
                    'total_bytes': total_bytes
                }
            else:
                logger.warning(f"指标获取失败: {response.status_code}")
                return {}
                
        except Exception as e:
            logger.error(f"指标检查异常: {e}")
            return {}
    
    def run_monitor(self):
        """执行监控"""
        logger.info(f"开始监控user_interests CDC作业: {JOB_ID}")
        
        # 检查Flink集群
        if not self.check_flink_cluster():
            message = "Flink集群连接失败，请检查集群状态"
            self.send_alert(message, is_error=True)
            return
        
        # 检查作业状态
        job_status = self.check_job_status()
        
        # 检查作业指标
        metrics = self.check_job_metrics()
        
        # 合并状态信息
        current_status = {
            **job_status,
            **metrics,
            'check_time': datetime.datetime.now().isoformat()
        }
        
        # 保存状态
        self.save_status(current_status)
        
        logger.info("监控检查完成")

def main():
    """主函数"""
    try:
        monitor = UserInterestsMonitor()
        monitor.run_monitor()
    except Exception as e:
        logger.error(f"监控脚本异常: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 