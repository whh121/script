# test目录 - 测试文件索引

## 📁 测试文件分类

### ✅ 成功验证文件（推荐参考）

#### `doris_test_correct_port.sql`
- **关键成功**: 发现并修复Doris端口问题
- **重要配置**: `'fenodes' = '10.10.41.243:8030'`
- **技术要点**: 使用FE HTTP端口8030，非查询端口9030

#### `user_interests_test.sql` 
- **核心验证**: MySQL CDC读取功能完全正常
- **数据验证**: 成功读取1700+条记录
- **技术要点**: binlog实时读取验证成功

### 🔧 重要调试文件

#### `doris_test_working.sql`
- **配置修复**: 正确的Doris缓冲区参数
- **关键参数**: `'sink.buffer-flush.max-rows' = '10000'`
- **技术发现**: 缓冲区最小值要求

#### `mysql_to_doris_timezone_fixed.sql`
- **时区修复**: 解决MySQL时区不匹配问题
- **关键配置**: `'server-time-zone' = 'UTC'`
- **适用场景**: AWS RDS时区为UTC

#### `mysql_to_doris_working.sql`
- **权限修复**: MySQL用户权限问题解决
- **解决方案**: 添加REPLICATION SLAVE, REPLICATION CLIENT权限
- **适用场景**: CDC权限不足时参考

### 🧪 探索性测试文件

#### `simple_test.sql` / `test_clean.sql`
- **用途**: 基础环境验证
- **价值**: 快速检查Flink基本功能

#### `step_by_step_doris_test.sql`
- **用途**: 分步骤诊断问题
- **价值**: 系统性排查故障

#### `test_doris_connection.sql`
- **用途**: 单独测试Doris连接
- **发现**: 暴露了9030端口问题

### ❌ 失败但有价值的文件

#### `user_interests_simple_test.sql`
- **发现**: Flink缺少JDBC连接器
- **价值**: 确认只能使用CDC方式连接MySQL

#### `user_interests_to_doris_sync.sql`
- **问题**: SQL语法错误
- **价值**: 提供了配置思路

### 🛠️ 工具脚本

#### `run_flink_job.sh`
- **功能**: 自动化作业提交
- **使用**: 简化测试流程

#### `test_connections.sh`
- **功能**: 批量连接测试
- **验证**: 确认所有数据库连接正常

### 📚 文档记录

#### `verification_summary.md`
- **内容**: 完整的验证过程记录
- **价值**: 追溯问题解决历程

#### `user_interests_sync_solution.md`
- **内容**: 专项问题分析
- **价值**: 深度技术分析

#### `final_verification_report.md`
- **内容**: 最终测试结果
- **价值**: 项目验证总结

---

## 🎯 测试文件使用建议

### 🔍 故障排查顺序

1. **基础连接**: `simple_test.sql`
2. **MySQL CDC**: `user_interests_test.sql`
3. **Doris连接**: `doris_test_correct_port.sql`
4. **完整同步**: `doris_test_working.sql`

### 📈 配置优化参考

1. **端口配置**: 参考 `doris_test_correct_port.sql`
2. **权限配置**: 参考 `mysql_to_doris_working.sql`
3. **时区配置**: 参考 `mysql_to_doris_timezone_fixed.sql`
4. **性能配置**: 参考 `doris_test_working.sql`

### ⚠️ 常见问题解决

| 问题 | 参考文件 | 解决方案 |
|------|----------|----------|
| Doris连接失败 | `doris_test_correct_port.sql` | 使用8030端口 |
| MySQL权限错误 | `mysql_to_doris_working.sql` | 添加REPLICATION权限 |
| 时区不匹配 | `mysql_to_doris_timezone_fixed.sql` | 设置UTC时区 |
| 缓冲区错误 | `doris_test_working.sql` | max-rows≥10000 |

---

## 💡 关键经验总结

通过这些测试文件验证了关键技术点：

1. **端口发现**: Doris FE端口8030 vs 查询端口9030
2. **权限要求**: MySQL CDC需要特殊权限
3. **时区同步**: 必须与RDS时区一致
4. **参数限制**: Doris连接器的参数要求
5. **环境依赖**: Flink连接器的可用性

**这些测试文件为项目成功提供了坚实的技术基础！** 🚀 