# MySQL到Doris实时数据同步项目

## 🚀 快速开始

### 生产环境运行
```bash
# 进入项目目录
cd flink_app/mysql2doris

# 启动数据同步
/home/ubuntu/flink/bin/sql-client.sh -f scripts/final_mysql_to_doris_sync.sql

# 检查监控状态
./scripts/mysql_doris_sync_monitor.sh health

# 查看实时日志
tail -f logs/monitor_$(date +%Y%m%d).log
```

### 监控系统
- ✅ **自动监控**: 每5分钟检查作业状态
- ✅ **智能报警**: 只在异常时发送飞书推送
- ✅ **自动恢复**: 故障时自动重启
- ✅ **日志管理**: 按天切割，自动清理

## 📁 项目结构

```
mysql2doris/
├── README.md                           # 项目说明（本文件）
├── scripts/                            # 脚本目录
│   ├── final_mysql_to_doris_sync.sql   # 主同步脚本
│   ├── mysql_doris_sync_monitor.sh     # 监控脚本  
│   ├── setup_monitor_cron.sh           # 定时任务配置
│   └── kafka_to_doris_solution_sample.sql # 参考样例
├── configs/                            # 配置目录
│   └── project.md                      # 项目配置参数
├── logs/                              # 日志目录
│   ├── monitor_YYYYMMDD.log           # 监控日志（按天切割）
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
    └── output/                        # 输出文件
```

## ✅ 当前状态

- **数据同步**: ✅ 正常运行 (MySQL 1971 → Doris 1969)
- **UPDATE支持**: ✅ UNIQUE KEY模型支持MySQL更新操作
- **实时性**: ✅ 秒级延迟，无重复数据
- **监控系统**: ✅ 7×24小时运行
- **智能报警**: ✅ 异常时飞书推送（30分钟防重复）
- **日志管理**: ✅ 按天切割，7天自动清理

## 🔧 核心配置

### MySQL源配置
```sql
'connector' = 'mysql-cdc'
'hostname' = 'xme-envtest-rds.chkycqw22fzd.ap-southeast-1.rds.amazonaws.com'
'server-time-zone' = 'UTC'  -- 关键配置
```

### Doris目标配置  
```sql
'connector' = 'doris'
'fenodes' = '10.10.41.243:8030'  -- FE HTTP端口
'sink.buffer-flush.max-rows' = '10000'  -- 最小值10000
-- UNIQUE KEY模型支持UPDATE操作
'table.identifier' = 'test_flink.user_interests_sync'  -- UNIQUE KEY表
```

## 📞 快速支持

- 📋 **查看今日日志**: `tail -f logs/monitor_$(date +%Y%m%d).log`
- 🔧 **手动重启**: `./scripts/mysql_doris_sync_monitor.sh restart`  
- 📢 **测试报警**: `./scripts/mysql_doris_sync_monitor.sh test-alert`
- 🧹 **清理日志**: `./scripts/mysql_doris_sync_monitor.sh cleanup`
- 📚 **详细文档**: 查看 `docs/代码说明.md`

## 🎯 监控优化特性

### 智能报警
- 📮 **减少干扰**: 正常状态不发送报警
- ⏰ **防重复**: 同类型报警30分钟间隔
- 🔄 **恢复通知**: 故障恢复后自动通知
- 📅 **工作日报**: 每天8点发送健康报告（仅工作日）

### 日志管理
- 📅 **按天切割**: `monitor_YYYYMMDD.log`
- 🗑️ **自动清理**: 保留7天，定期清理
- 📂 **统一目录**: 所有日志存放在 `logs/` 目录
- 📝 **分类存储**: 监控日志和定时任务日志分开

## 🚀 部署指南

### 1. 环境准备
- Flink集群运行中
- MySQL CDC权限配置
- Doris集群连接正常

### 2. 配置修改
编辑 `configs/project.md` 中的连接参数

### 3. 启动服务
```bash
# 设置定时监控
./scripts/setup_monitor_cron.sh

# 启动数据同步
/home/ubuntu/flink/bin/sql-client.sh -f scripts/final_mysql_to_doris_sync.sql
```

---

**MySQL到Doris实时数据同步，生产级稳定运行！** 🎉 