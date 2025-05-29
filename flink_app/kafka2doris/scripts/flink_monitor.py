#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import json
import time
import logging
import subprocess
import os
from datetime import datetime
from typing import Dict, List, Optional

class FlinkMonitor:
    def __init__(self, 
                 flink_rest_url: str = "http://localhost:8081",
                 webhook_url: str = "https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089",
                 flink_sql_path: str = "/home/ubuntu/work/script/kafka_to_doris_production.sql",
                 flink_bin_path: str = "/home/ubuntu/work/script/flink/bin/sql-client.sh",
                 check_interval: int = 60):
        """
        初始化Flink监控器
        
        Args:
            flink_rest_url: Flink REST API地址
            webhook_url: 飞书机器人webhook地址
            flink_sql_path: 生产环境SQL文件路径
            flink_bin_path: Flink SQL客户端路径
            check_interval: 检查间隔（秒）
        """
        self.flink_rest_url = flink_rest_url
        self.webhook_url = webhook_url
        self.flink_sql_path = flink_sql_path
        self.flink_bin_path = flink_bin_path
        self.check_interval = check_interval
        
        # 设置日志
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/home/ubuntu/work/script/flink_monitor.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def send_alert(self, title: str, message: str, is_error: bool = True):
        """发送告警到飞书"""
        try:
            color = "red" if is_error else "green"
            payload = {
                "msg_type": "post",
                "content": {
                    "post": {
                        "zh_cn": {
                            "title": title,
                            "content": [
                                [
                                    {
                                        "tag": "text",
                                        "text": message
                                    }
                                ],
                                [
                                    {
                                        "tag": "text",
                                        "text": f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                                    }
                                ]
                            ]
                        }
                    }
                }
            }
            
            response = requests.post(self.webhook_url, json=payload, timeout=10)
            if response.status_code == 200:
                self.logger.info(f"告警发送成功: {title}")
            else:
                self.logger.error(f"告警发送失败: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"发送告警失败: {str(e)}")
    
    def get_flink_jobs(self) -> Optional[List[Dict]]:
        """获取Flink作业列表"""
        try:
            response = requests.get(f"{self.flink_rest_url}/jobs", timeout=10)
            if response.status_code == 200:
                return response.json().get('jobs', [])
            else:
                self.logger.error(f"获取Flink作业列表失败: {response.status_code}")
                return None
        except Exception as e:
            self.logger.error(f"连接Flink REST API失败: {str(e)}")
            return None
    
    def get_job_details(self, job_id: str) -> Optional[Dict]:
        """获取作业详细信息"""
        try:
            response = requests.get(f"{self.flink_rest_url}/jobs/{job_id}", timeout=10)
            if response.status_code == 200:
                return response.json()
            else:
                self.logger.error(f"获取作业详情失败: {response.status_code}")
                return None
        except Exception as e:
            self.logger.error(f"获取作业详情异常: {str(e)}")
            return None
    
    def restart_flink_job(self, job_id: str) -> bool:
        """重启Flink作业"""
        try:
            # 先停止作业
            stop_response = requests.patch(
                f"{self.flink_rest_url}/jobs/{job_id}",
                json={"type": "cancel"},
                timeout=30
            )
            
            if stop_response.status_code in [200, 202]:
                self.logger.info(f"作业 {job_id} 停止成功")
                
                # 等待作业完全停止
                time.sleep(10)
                
                # 重新提交作业
                if self.submit_flink_job():
                    self.logger.info("作业重新提交成功")
                    return True
                else:
                    self.logger.error("作业重新提交失败")
                    return False
            else:
                self.logger.error(f"停止作业失败: {stop_response.status_code}")
                return False
                
        except Exception as e:
            self.logger.error(f"重启作业异常: {str(e)}")
            return False
    
    def submit_flink_job(self) -> bool:
        """提交Flink作业"""
        try:
            if not os.path.exists(self.flink_sql_path):
                self.logger.error(f"SQL文件不存在: {self.flink_sql_path}")
                return False
            
            # 执行SQL文件
            cmd = f"{self.flink_bin_path} -f {self.flink_sql_path}"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                self.logger.info("Flink作业提交成功")
                return True
            else:
                self.logger.error(f"Flink作业提交失败: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error("Flink作业提交超时")
            return False
        except Exception as e:
            self.logger.error(f"提交Flink作业异常: {str(e)}")
            return False
    
    def check_flink_cluster_health(self) -> bool:
        """检查Flink集群健康状态"""
        try:
            response = requests.get(f"{self.flink_rest_url}/overview", timeout=10)
            if response.status_code == 200:
                overview = response.json()
                if overview.get('taskmanagers', 0) > 0:
                    return True
                else:
                    self.logger.warning("没有可用的TaskManager")
                    return False
            else:
                self.logger.error(f"Flink集群状态检查失败: {response.status_code}")
                return False
        except Exception as e:
            self.logger.error(f"检查Flink集群健康状态异常: {str(e)}")
            return False
    
    def monitor_jobs(self):
        """监控Flink作业"""
        self.logger.info("开始监控Flink作业...")
        
        failed_checks = 0
        max_failed_checks = 3
        
        while True:
            try:
                # 检查集群健康状态
                if not self.check_flink_cluster_health():
                    failed_checks += 1
                    if failed_checks >= max_failed_checks:
                        self.send_alert(
                            "Flink集群异常", 
                            f"Flink集群连续{failed_checks}次检查失败，请检查集群状态"
                        )
                        failed_checks = 0
                    time.sleep(self.check_interval)
                    continue
                
                # 获取作业列表
                jobs = self.get_flink_jobs()
                if jobs is None:
                    failed_checks += 1
                    if failed_checks >= max_failed_checks:
                        self.send_alert(
                            "Flink API异常", 
                            f"Flink REST API连续{failed_checks}次无法访问"
                        )
                        failed_checks = 0
                    time.sleep(self.check_interval)
                    continue
                
                # 检查是否有运行中的Kafka to Doris作业
                kafka_doris_jobs = []
                for job in jobs:
                    job_details = self.get_job_details(job['id'])
                    if job_details and 'kafka' in job_details.get('name', '').lower():
                        kafka_doris_jobs.append(job_details)
                
                if not kafka_doris_jobs:
                    self.logger.warning("没有找到Kafka to Doris作业，尝试重新提交")
                    if self.submit_flink_job():
                        self.send_alert(
                            "Flink作业恢复", 
                            "Kafka to Doris作业已重新提交", 
                            is_error=False
                        )
                    else:
                        self.send_alert(
                            "Flink作业提交失败", 
                            "无法重新提交Kafka to Doris作业"
                        )
                else:
                    # 检查作业状态
                    for job in kafka_doris_jobs:
                        job_id = job['jid']
                        job_name = job['name']
                        job_state = job['state']
                        
                        if job_state in ['FAILED', 'CANCELED']:
                            self.logger.warning(f"作业 {job_name} 状态异常: {job_state}")
                            
                            # 尝试重启作业
                            if self.restart_flink_job(job_id):
                                self.send_alert(
                                    "Flink作业自动恢复", 
                                    f"作业 {job_name} 已自动重启", 
                                    is_error=False
                                )
                            else:
                                self.send_alert(
                                    "Flink作业重启失败", 
                                    f"作业 {job_name} 重启失败，需要手动处理"
                                )
                        
                        elif job_state == 'RUNNING':
                            self.logger.info(f"作业 {job_name} 运行正常")
                            failed_checks = 0
                
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                self.logger.info("监控程序被手动停止")
                break
            except Exception as e:
                self.logger.error(f"监控过程中发生异常: {str(e)}")
                time.sleep(self.check_interval)

if __name__ == "__main__":
    # 配置参数
    monitor = FlinkMonitor(
        flink_rest_url="http://localhost:8081",
        webhook_url="https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089",
        flink_sql_path="/home/ubuntu/work/script/kafka_to_doris_production.sql",
        flink_bin_path="/opt/flink/bin/sql-client.sh",  # 根据实际路径调整
        check_interval=60  # 每60秒检查一次
    )
    
    # 启动监控
    monitor.monitor_jobs() 