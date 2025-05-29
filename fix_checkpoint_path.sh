#!/bin/bash

# 修复检查点路径配置脚本
echo "🔧 修复Flink作业检查点路径配置"
echo ""

FLINK_HOME="/home/ubuntu/flink"
JOB_ID="8d0f373f9d777562518adc2c26fb93d1"
NEW_SQL_FILE="./flink_app/mysql2doris/scripts/final_mysql_to_doris_sync.sql"

echo "📋 当前作业状态："
$FLINK_HOME/bin/flink list

echo ""
echo "⚠️  问题：根目录不断生成flink目录"
echo "   原因：作业使用旧的绝对路径配置"
echo "   解决：重启作业应用新的相对路径配置"
echo ""

echo "🛑 停止当前作业..."
$FLINK_HOME/bin/flink cancel $JOB_ID

echo "⏳ 等待作业停止..."
sleep 15

echo "🚀 启动新作业（使用相对路径）..."
$FLINK_HOME/bin/sql-client.sh -f "$NEW_SQL_FILE"

echo ""
echo "✅ 作业重启完成！"
echo "📊 新检查点位置: flink_app/flink/checkpoints/"
echo "�� 根目录不会再自动生成flink目录" 