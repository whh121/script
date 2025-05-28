#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import logging
import subprocess
import schedule
from datetime import datetime, timedelta
import requests

class MySQLIncrementalSync:
    def __init__(self):
        self.flink_sql_client = "/opt/flink/bin/sql-client.sh"
        self.sync_sql_template = "/home/ubuntu/work/script/mysql_content_audit_to_doris.sql"
        self.webhook_url = "https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"
        
        # 设置日志
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/home/ubuntu/work/script/mysql_sync.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def send_alert(self, title: str, message: str, is_error: bool = True):
        """发送告警到飞书"""
        try:
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
    
    def create_incremental_sql(self, hours_back: int = 1):
        """创建增量同步SQL文件"""
        now = datetime.now()
        start_time = now - timedelta(hours=hours_back)
        
        sql_content = f"""
-- MySQL content_audit_record 增量同步 - {now.strftime('%Y-%m-%d %H:%M:%S')}

-- 设置checkpoint配置
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'state.backend' = 'filesystem';
SET 'state.checkpoints.dir' = 'file:///home/ubuntu/work/script/flink/checkpoints';

-- 增量数据源 (最近{hours_back}小时的数据)
CREATE TABLE mysql_content_audit_record_incremental (
    id BIGINT,
    content_id BIGINT,
    source STRING,
    language STRING,
    push_time TIMESTAMP(3),
    submit_time BIGINT,
    ai_audit_result INT,
    ai_audit_time BIGINT,
    ai_audit_channel INT,
    ai_audit_id BIGINT,
    manual_audit_result INT,
    manual_audit_time BIGINT,
    manual_audit_channel INT,
    manual_audit_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    partition_day AS CAST(DATE_FORMAT(update_time, 'yyyy-MM-dd') AS DATE),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:mysql://xme-prod-rds-content.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com:3306/content_data_20250114?useSSL=false&serverTimezone=UTC',
    'table-name' = '(SELECT * FROM content_audit_record WHERE update_time >= \\'{start_time.strftime('%Y-%m-%d %H:%M:%S')}\\') AS recent_records',
    'username' = 'content-ro',
    'password' = 'k5**^k12o',
    'driver' = 'com.mysql.cj.jdbc.Driver',
    'scan.fetch-size' = '1000'
);

-- Doris目标表
CREATE TABLE doris_content_audit_record_sink (
    id BIGINT,
    content_id BIGINT,
    source STRING,
    language STRING,
    push_time TIMESTAMP(3),
    submit_time BIGINT,
    ai_audit_result INT,
    ai_audit_time BIGINT,
    ai_audit_channel INT,
    ai_audit_id BIGINT,
    manual_audit_result INT,
    manual_audit_time BIGINT,
    manual_audit_channel INT,
    manual_audit_id BIGINT,
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    partition_day DATE
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8030',
    'table.identifier' = 'test_flink.content_audit_record_sync',
    'username' = 'root',
    'password' = 'doris@123',
    'sink.properties.format' = 'json',
    'sink.enable-2pc' = 'false',
    'sink.buffer-flush.max-rows' = '5000',
    'sink.buffer-flush.interval' = '10s',
    'sink.max-retries' = '3',
    'sink.properties.columns' = 'id, content_id, source, language, push_time, submit_time, ai_audit_result, ai_audit_time, ai_audit_channel, ai_audit_id, manual_audit_result, manual_audit_time, manual_audit_channel, manual_audit_id, create_time, update_time, partition_day',
    'sink.label-prefix' = 'content_audit_incremental_{{{{ now.format('yyyyMMddHHmmss') }}}}'
);

-- 执行增量同步
INSERT INTO doris_content_audit_record_sink
SELECT 
    id,
    content_id,
    source,
    language,
    push_time,
    submit_time,
    ai_audit_result,
    ai_audit_time,
    ai_audit_channel,
    ai_audit_id,
    manual_audit_result,
    manual_audit_time,
    manual_audit_channel,
    manual_audit_id,
    create_time,
    update_time,
    CASE 
        WHEN update_time IS NOT NULL THEN partition_day
        ELSE CURRENT_DATE
    END AS partition_day
FROM mysql_content_audit_record_incremental;
"""
        
        sql_file = f"/tmp/mysql_incremental_sync_{now.strftime('%Y%m%d_%H%M%S')}.sql"
        with open(sql_file, 'w', encoding='utf-8') as f:
            f.write(sql_content)
        
        return sql_file
    
    def run_sync_job(self, hours_back: int = 1):
        """执行增量同步作业"""
        try:
            self.logger.info(f"开始执行增量同步，回溯{hours_back}小时")
            
            # 创建增量同步SQL
            sql_file = self.create_incremental_sql(hours_back)
            
            # 执行Flink SQL
            cmd = f"{self.flink_sql_client} -f {sql_file}"
            result = subprocess.run(
                cmd, 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=1800  # 30分钟超时
            )
            
            if result.returncode == 0:
                self.logger.info("增量同步执行成功")
                self.send_alert(
                    "MySQL增量同步成功", 
                    f"content_audit_record表增量同步完成，回溯{hours_back}小时", 
                    is_error=False
                )
            else:
                self.logger.error(f"增量同步执行失败: {result.stderr}")
                self.send_alert(
                    "MySQL增量同步失败", 
                    f"执行失败: {result.stderr[:500]}"
                )
            
            # 清理临时文件
            if os.path.exists(sql_file):
                os.remove(sql_file)
                
        except subprocess.TimeoutExpired:
            self.logger.error("增量同步执行超时")
            self.send_alert("MySQL增量同步超时", "执行时间超过30分钟")
        except Exception as e:
            self.logger.error(f"增量同步异常: {str(e)}")
            self.send_alert("MySQL增量同步异常", f"异常信息: {str(e)}")
    
    def run_hourly_sync(self):
        """每小时增量同步"""
        self.run_sync_job(hours_back=1)
    
    def run_daily_sync(self):
        """每日全量同步（回溯24小时）"""
        self.run_sync_job(hours_back=24)
    
    def start_scheduler(self):
        """启动定时调度器"""
        self.logger.info("启动MySQL增量同步调度器...")
        
        # 每小时的第5分钟执行增量同步
        schedule.every().hour.at(":05").do(self.run_hourly_sync)
        
        # 每天凌晨2点执行全量同步
        schedule.every().day.at("02:00").do(self.run_daily_sync)
        
        # 立即执行一次
        self.logger.info("执行初始化同步...")
        self.run_hourly_sync()
        
        while True:
            try:
                schedule.run_pending()
                time.sleep(60)  # 每分钟检查一次
            except KeyboardInterrupt:
                self.logger.info("调度器被手动停止")
                break
            except Exception as e:
                self.logger.error(f"调度器异常: {str(e)}")
                time.sleep(300)  # 异常时等待5分钟后继续

if __name__ == "__main__":
    sync = MySQLIncrementalSync()
    sync.start_scheduler() 