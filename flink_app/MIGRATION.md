# 项目结构迁移说明

## 🔄 迁移概述

本项目已从原来的 `script` 目录重构为 `flink_app` 目录，以更好地体现这是一个Flink应用集合项目。

## 📂 目录结构变化

### 旧结构
```
script/
├── README.md
├── project.md
├── final_mysql_to_doris_sync.sql
├── mysql_doris_sync_monitor.sh
├── setup_monitor_cron.sh
├── kafka_to_doris_solution_sample.sql
├── log/
├── docs/
├── test/
└── flink/
```

### 新结构
```
flink_app/
├── README.md                    # 主项目说明
├── mysql2doris/                 # MySQL到Doris同步项目
│   ├── README.md                # 子项目说明
│   ├── scripts/                 # 脚本文件
│   │   ├── final_mysql_to_doris_sync.sql
│   │   ├── mysql_doris_sync_monitor.sh
│   │   ├── setup_monitor_cron.sh
│   │   └── kafka_to_doris_solution_sample.sql
│   ├── configs/                 # 配置文件
│   │   └── project.md
│   ├── logs/                    # 日志目录
│   ├── docs/                    # 文档目录
│   ├── tests/                   # 测试文件
│   └── checkpoints/             # Flink检查点
└── [其他Flink应用项目...]
```

## 🔧 已更新的配置

### 1. 监控脚本路径自适应
- `mysql_doris_sync_monitor.sh` 已更新为使用相对路径
- 自动检测脚本所在目录，无需手动修改路径

### 2. 日志目录调整
- 原 `log/` → 新 `mysql2doris/logs/`
- 所有日志路径已自动适配

### 3. 定时任务配置
- `setup_monitor_cron.sh` 已更新为新的目录结构
- crontab任务路径自动适配

### 4. .gitignore 更新
- 适配新的目录结构
- 支持多个Flink应用项目

## 🚀 迁移后的使用方法

### 进入项目目录
```bash
cd flink_app/mysql2doris
```

### 启动数据同步
```bash
/home/ubuntu/flink/bin/sql-client.sh -f scripts/final_mysql_to_doris_sync.sql
```

### 监控管理
```bash
# 检查状态
./scripts/mysql_doris_sync_monitor.sh health

# 查看日志
tail -f logs/monitor_$(date +%Y%m%d).log

# 设置定时任务
./scripts/setup_monitor_cron.sh
```

## ✅ 兼容性说明

1. **现有定时任务**: 需要重新运行 `setup_monitor_cron.sh` 更新路径
2. **监控脚本**: 自动适配新路径，无需修改
3. **Flink作业**: 无需修改，继续正常运行
4. **日志文件**: 建议备份原有日志后清理

## 🎯 未来扩展

新的目录结构支持添加更多Flink应用项目：

```bash
flink_app/
├── mysql2doris/          # 现有项目
├── kafka2elasticsearch/  # 新项目示例
├── redis2doris/          # 新项目示例
└── stream_analytics/     # 新项目示例
```

每个项目都遵循统一的目录结构规范。

---

**重构完成，项目结构更清晰，便于维护和扩展！** 🎉 