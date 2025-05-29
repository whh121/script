# MySQL到Doris同步监控系统使用指南

## 📋 概述

本监控系统为MySQL到Doris实时数据同步提供全方位监控，包括：
- 🔍 Flink作业状态监控
- 📊 数据一致性校验
- ⏱️ 同步延迟检测
- 💾 系统资源监控
- 🔧 自动故障恢复
- 📢 飞书报警通知

## 🚀 快速开始

### 1. 基本用法

```bash
# 执行完整监控检查
./mysql_doris_sync_monitor.sh monitor

# 快速健康检查
./mysql_doris_sync_monitor.sh health

# 手动重启Flink作业
./mysql_doris_sync_monitor.sh restart

# 测试飞书报警
./mysql_doris_sync_monitor.sh test-alert
```

### 2. 定时任务配置

已自动配置以下定时任务：
```bash
# 每5分钟执行完整监控
*/5 * * * * /home/ubuntu/work/script/mysql_doris_sync_monitor.sh monitor

# 每小时执行健康检查  
1 * * * * /home/ubuntu/work/script/mysql_doris_sync_monitor.sh health

# 每天8点发送日报
0 8 * * * /home/ubuntu/work/script/mysql_doris_sync_monitor.sh monitor
```

## 🔧 配置参数

### 监控阈值配置

```bash
# 在脚本中可调整的参数
MAX_DATA_DIFF=100          # 允许的最大数据差异（条）
MAX_DELAY_MINUTES=10       # 允许的最大延迟（分钟）
```

### 数据库连接配置

```bash
# MySQL配置
MYSQL_HOST="xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com"
MYSQL_USER="bigdata-user-interests"
MYSQL_DB="content_behavior"
MYSQL_TABLE="user_interests"

# Doris配置  
DORIS_HOST="10.10.41.243"
DORIS_PORT="9030"
DORIS_DB="test_flink"
DORIS_TABLE="user_interests_sync"
```

### 飞书Webhook配置

```bash
FEISHU_WEBHOOK="https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"
```

## 📊 监控指标

### 1. Flink作业监控

| 检查项 | 描述 | 异常处理 |
|--------|------|----------|
| 集群连接 | 检查Flink集群是否可访问 | 发送报警 |
| 作业状态 | 检查同步作业是否RUNNING | 自动重启 |
| 作业健康 | 验证作业正常执行 | 报警+重启 |

### 2. 数据一致性监控

| 检查项 | 描述 | 阈值 |
|--------|------|------|
| 数据量对比 | MySQL vs Doris记录数 | 差异>100条报警 |
| 数据完整性 | 验证关键字段同步 | 字段缺失报警 |
| 数据新鲜度 | 检查最近数据活跃度 | 10分钟无新数据报警 |

### 3. 系统资源监控

| 检查项 | 阈值 | 处理 |
|--------|------|------|
| 磁盘使用率 | >85% | 发送告警 |
| 内存使用率 | >90% | 发送告警 |
| CPU负载 | >80% | 发送告警 |

## 🚨 报警级别

### 📗 Info (绿色)
- 日常健康报告
- 成功恢复通知
- 系统状态正常

### 📙 Warning (黄色)  
- 数据同步延迟
- 资源使用率告警
- 作业状态异常

### 📕 Error (红色)
- 作业停止
- 数据库连接失败
- 自动恢复失败

## 🔧 故障处理

### 自动恢复流程

1. **检测异常** → 发送报警通知
2. **尝试重启** → 停止异常作业
3. **重新启动** → 执行同步脚本
4. **验证恢复** → 确认作业正常
5. **结果通知** → 发送恢复状态

### 手动干预场景

以下情况需要人工处理：
- 连续3次自动恢复失败
- 数据库连接持续异常
- 系统资源严重不足
- 配置文件损坏

## 📂 日志文件

### 监控日志
```bash
# 主监控日志
tail -f /home/ubuntu/work/script/monitor.log

# 定时任务日志
tail -f /home/ubuntu/work/script/cron.log

# Flink作业日志
tail -f /home/ubuntu/flink/log/flink-ubuntu-taskexecutor-*.log
```

### 日志格式
```bash
[2025-05-27 08:13:46] ========== 开始监控检查 ==========
[2025-05-27 08:13:46] 检查Flink作业状态...
[2025-05-27 08:13:52] 作业运行正常: insert-into_default_catalog.default_database.doris_user_interests_sink
[2025-05-27 08:13:52] 数据量对比 - MySQL: 1781, Doris: 1778, 差异: 3
[2025-05-27 08:13:52] 所有检查项正常通过
```

## 🛠️ 维护操作

### 重启服务
```bash
# 重启Flink集群
/home/ubuntu/flink/bin/stop-cluster.sh
/home/ubuntu/flink/bin/start-cluster.sh

# 重启同步作业
./mysql_doris_sync_monitor.sh restart
```

### 查看状态
```bash
# 查看当前作业
/home/ubuntu/flink/bin/flink list

# 查看系统资源
htop
df -h
```

### 更新配置
```bash
# 编辑监控脚本
vim mysql_doris_sync_monitor.sh

# 重新配置定时任务
./setup_monitor_cron.sh
```

## 📈 性能优化建议

### 1. 监控频率调整
- 生产环境建议每5分钟检查
- 测试环境可增加到每分钟
- 夜间可适当降低频率

### 2. 阈值优化
- 根据业务特点调整数据差异阈值
- 考虑业务高峰期调整延迟阈值
- 定期回顾告警准确性

### 3. 资源预留
- 监控脚本本身占用极少资源
- 建议预留充足磁盘空间存储日志
- 确保网络连接稳定

## 📞 联系方式

如遇问题，请查看：
1. 📋 监控日志：`monitor.log`
2. 🔧 Flink日志：`flink/log/`
3. 📢 飞书群组：自动报警推送
4. 📚 本文档：详细操作指南

---

**监控系统已就绪，保障数据同步7×24小时稳定运行！** 🚀 