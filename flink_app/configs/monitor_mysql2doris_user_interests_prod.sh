#!/bin/bash
# 监控配置 - mysql2doris_user_interests_prod
# 自动生成于 2025-05-29 08:03:08

JOB_NAME="mysql2doris_user_interests_prod"
ENVIRONMENT="prod"
CHECK_INTERVAL=60
MAX_FAILURES=3
WEBHOOK_URL="https://open.larksuite.com/open-apis/bot/v2/hook/3bb8fac6-6a02-498e-804f-48b1b38a6089"

# 检查点目录
CHECKPOINT_DIR="./flink_app/mysql2doris/checkpoints"

# Flink Web UI
FLINK_WEB_UI="http://localhost:8081"

echo "监控配置已加载: $JOB_NAME ($ENVIRONMENT)"
