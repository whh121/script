# MySQL到Doris实时数据同步项目

## 🚀 快速开始

### 生产环境运行
```bash
# 进入项目目录
cd flink_app/mysql2doris

# 启动content_audit_record数据同步
/home/ubuntu/flink/bin/sql-client.sh -f scripts/final_mysql_to_doris_sync.sql

# 启动user_interests CDC同步 (新增)
/home/ubuntu/flink/bin/sql-client.sh -f scripts/mysql2doris_user_interests_prod.sql

# 检查监控状态
./scripts/mysql_doris_sync_monitor.sh health

# 查看实时日志
tail -f logs/monitor_$(date +%Y%m%d).log
tail -f logs/user_interests_monitor_$(date +%Y%m%d).log  # user_interests专用日志
```

### 监控系统
- ✅ **自动监控**: 每5分钟检查作业状态
- ✅ **智能报警**: 只在异常时发送飞书推送
- ✅ **自动恢复**: 故障时自动重启
- ✅ **日志管理**: 按天切割，自动清理
- ✅ **多项目支持**: content_audit_record + user_interests双项目监控

## 📁 项目结构

```
mysql2doris/
├── README.md                           # 项目说明（本文件）
├── scripts/                            # 脚本目录
│   ├── final_mysql_to_doris_sync.sql   # content_audit_record同步脚本
│   ├── mysql2doris_user_interests_prod.sql  # ✅ user_interests CDC同步脚本 (新增)
│   ├── monitor_user_interests.py       # ✅ user_interests专用监控脚本 (新增)
│   ├── setup_user_interests_cron.sh    # ✅ user_interests定时任务配置 (新增)
│   ├── mysql_doris_sync_monitor.sh     # content_audit_record监控脚本  
│   ├── setup_monitor_cron.sh           # content_audit_record定时任务配置
│   └── kafka_to_doris_solution_sample.sql # 参考样例
├── configs/                            # 配置目录
│   └── project.md                      # 项目配置参数
├── logs/                              # 日志目录
│   ├── monitor_YYYYMMDD.log           # content_audit_record监控日志
│   ├── user_interests_monitor_YYYYMMDD.log  # ✅ user_interests监控日志 (新增)
│   ├── user_interests_cron.log        # ✅ user_interests定时任务日志 (新增)
│   ├── user_interests_status.json     # ✅ user_interests状态文件 (新增)
│   ├── cron_YYYYMMDD.log              # 定时任务日志
│   └── alert_state.txt                # 报警状态记录
├── docs/                              # 文档目录
│   ├── 代码说明.md                     # 详细代码说明和分类
│   ├── Monitor_Usage_Guide.md         # 监控使用指南
│   ├── MySQL_to_Doris_Success_Report.md # 项目成功报告
│   └── mysql_to_doris_README.md       # 基础说明文档
├── tests/                             # 测试文件目录(28个文件)
│   ├── README_TEST.md                 # 测试文件索引
│   ├── doris_test_correct_port.sql    # 关键成功测试
│   ├── user_interests_test.sql        # CDC验证测试
│   └── [其他测试文件...]
└── checkpoints/                       # Flink检查点目录
    ├── user_interests/                # ✅ user_interests检查点目录 (新增)
    └── output/                        # 输出文件
```

## ✅ 当前状态

### content_audit_record项目
- **数据同步**: ✅ 正常运行 (MySQL 1971 → Doris 1969)
- **UPDATE支持**: ✅ UNIQUE KEY模型支持MySQL更新操作
- **实时性**: ✅ 秒级延迟，无重复数据
- **监控系统**: ✅ 7×24小时运行

### user_interests项目 (新增)
- **数据同步**: ✅ 正常运行 (MySQL CDC → Doris)
- **作业ID**: 275a6f22da1f5bdf896b9341028b2de0
- **源表**: content_behavior.user_interests (特殊数据库连接)
- **目标表**: xme_dw_ods.xme_ods_user_rds_user_interests_di
- **同步模式**: Stream (MySQL CDC实时同步)
- **监控频率**: 每5分钟检查一次
- **告警系统**: ✅ 飞书机器人推送
- **分区字段**: ✅ 自动生成partition_day字段

### 通用状态
- **智能报警**: ✅ 异常时飞书推送（30分钟防重复）
- **日志管理**: ✅ 按天切割，7天自动清理

## 🔧 核心配置

### content_audit_record - MySQL源配置
```sql
'connector' = 'mysql-cdc'
'hostname' = 'xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com'
'server-time-zone' = 'UTC'  -- 关键配置
```

### user_interests - MySQL CDC源配置 (新增)
```sql
'connector' = 'mysql-cdc'
'hostname' = 'xme-prod-rds-analysis-readonly.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com'
'username' = 'prod-bigdata-user-interests'
'password' = 'Dd4.fD3DFDk4.9cc'
'database-name' = 'content_behavior'
'table-name' = 'user_interests'
'server-id' = '5101-5104'
'scan.startup.mode' = 'initial'
```

### Doris目标配置  
```sql
# content_audit_record
'fenodes' = '10.10.41.243:8030'  -- 测试环境
'table.identifier' = 'test_flink.user_interests_sync'

# user_interests (生产环境)
'fenodes' = '172.31.0.82:8030'  -- 生产环境  
'table.identifier' = 'xme_dw_ods.xme_ods_user_rds_user_interests_di'
'username' = 'flink_user'
'password' = 'flink@123'
```

## 📞 快速支持

### content_audit_record项目
- 📋 **查看今日日志**: `tail -f logs/monitor_$(date +%Y%m%d).log`
- 🔧 **手动重启**: `./scripts/mysql_doris_sync_monitor.sh restart`  
- 📢 **测试报警**: `./scripts/mysql_doris_sync_monitor.sh test-alert`

### user_interests项目 (新增)
- 📋 **查看今日日志**: `tail -f logs/user_interests_monitor_$(date +%Y%m%d).log`
- 🔧 **手动监控**: `python3 scripts/monitor_user_interests.py`
- 📊 **作业状态**: `curl http://localhost:8081/jobs/275a6f22da1f5bdf896b9341028b2de0`
- 🔍 **检查点状态**: 检查`checkpoints/`目录

### 通用操作
- 🧹 **清理日志**: `./scripts/mysql_doris_sync_monitor.sh cleanup`
- 📚 **详细文档**: 查看 `docs/代码说明.md`
- 🏠 **Flink Web UI**: http://localhost:8081

## 🎯 监控优化特性

### 智能报警
- 📮 **减少干扰**: 正常状态不发送报警
- ⏰ **防重复**: 同类型报警30分钟间隔
- 🔄 **恢复通知**: 故障恢复后自动通知
- 📅 **工作日报**: 每天8点发送健康报告（仅工作日）
- 🎯 **分项目监控**: 每个项目独立监控和告警

### 日志管理
- 📅 **按天切割**: `monitor_YYYYMMDD.log`
- 🗑️ **自动清理**: 保留7天，定期清理
- 📂 **统一目录**: 所有日志存放在 `logs/` 目录
- 📝 **分类存储**: 每个项目独立日志文件
- 📊 **状态文件**: JSON格式状态追踪

## 🚀 部署指南

### 1. 环境准备
- Flink集群运行中
- MySQL CDC权限配置 (包括SHOW MASTER STATUS权限)
- Doris集群连接正常 (测试环境 + 生产环境)

### 2. 配置修改
编辑 `configs/project.md` 中的连接参数

### 3. 启动服务

#### content_audit_record项目
```bash
# 设置定时监控
./scripts/setup_monitor_cron.sh

# 启动数据同步
/home/ubuntu/flink/bin/sql-client.sh -f scripts/final_mysql_to_doris_sync.sql
```

#### user_interests项目 (新增)
```bash
# 设置定时监控
./scripts/setup_user_interests_cron.sh

# 启动CDC同步 (已完成)
/home/ubuntu/flink/bin/sql-client.sh -f scripts/mysql2doris_user_interests_prod.sql

# 验证作业状态
curl http://localhost:8081/jobs/275a6f22da1f5bdf896b9341028b2de0
```

## 📊 作业信息汇总

| 项目 | 作业ID | 状态 | 监控频率 | 日志文件 |
|------|--------|------|----------|----------|
| content_audit_record | 待查询 | ✅ 运行中 | 5分钟 | monitor_YYYYMMDD.log |
| user_interests | 275a6f22da1f5bdf896b9341028b2de0 | ✅ 运行中 | 5分钟 | user_interests_monitor_YYYYMMDD.log |

## 🔗 相关链接

- **Flink Web UI**: http://localhost:8081
- **飞书告警机器人**: 3bb8fac6-6a02-498e-804f-48b1b38a6089
- **生产Doris**: 172.31.0.82:8030
- **测试Doris**: 10.10.41.243:8030

---

**MySQL到Doris实时数据同步，生产级稳定运行！** 🎉 
**双项目支持: content_audit_record + user_interests** ✨ 