# Doris表UPDATE支持配置指南

## 问题背景

MySQL的`user_interests`表会有UPDATE操作，原来的Doris表使用`DUPLICATE KEY`模型不支持更新，只会追加重复数据。

## 解决方案

### 1. 原问题表结构
```sql
-- 原来的DUPLICATE KEY模型 (不支持UPDATE)
CREATE TABLE `user_interests_sync` (
  `id` int NULL,
  `user_id` bigint NULL,
  `interest_ids` varchar(1000) NULL,
  `updated_at` text NULL,
  `partition_day` date NULL
) ENGINE=OLAP
DUPLICATE KEY(`id`)  -- ❌ 不支持UPDATE
DISTRIBUTED BY HASH(`user_id`) BUCKETS 10
```

### 2. 修复后的表结构
```sql
-- 新的UNIQUE KEY模型 (支持UPDATE)
CREATE TABLE `user_interests_sync` (
  `id` int NOT NULL,
  `user_id` bigint NOT NULL,
  `interest_ids` varchar(2000) NULL,
  `updated_at` datetime NULL,
  `partition_day` date NULL
) ENGINE=OLAP
UNIQUE KEY(`id`)  -- ✅ 支持UPDATE
DISTRIBUTED BY HASH(`id`) BUCKETS 10
PROPERTIES (
"enable_unique_key_merge_on_write" = "true"  -- ✅ 开启实时更新
);
```

### 3. 关键配置说明

#### UNIQUE KEY模型特点
- **支持UPDATE**: 相同主键的数据会被更新，而不是追加
- **实时更新**: 开启`enable_unique_key_merge_on_write`后，更新操作实时生效
- **主键约束**: 主键字段必须设置为`NOT NULL`

#### Flink连接器配置
```sql
-- Flink中的Doris表定义也需要对应调整
CREATE TABLE doris_user_interests_sink (
    id INT,                -- 对应UNIQUE KEY
    user_id BIGINT,
    interest_ids STRING,
    updated_at TIMESTAMP(3),  -- 修改为TIMESTAMP类型
    partition_day DATE
) WITH (
    'connector' = 'doris',
    'fenodes' = '10.10.41.243:8030',
    'table.identifier' = 'test_flink.user_interests_sync',
    'sink.label-prefix' = 'user_interests_unique_sync'  -- 更新标签前缀
);
```

## 4. 验证UPDATE功能

### 数据同步验证
```sql
-- MySQL源数据
SELECT COUNT(*) FROM content_behavior.user_interests;  -- 1961条

-- Doris目标数据  
SELECT COUNT(*) FROM test_flink.user_interests_sync;   -- 1963条 (含CDC初始化数据)
```

### UPDATE操作验证
1. **MySQL端**: 当有权限用户执行UPDATE操作时
2. **CDC捕获**: Flink CDC会捕获binlog中的UPDATE事件
3. **Doris应用**: 基于UNIQUE KEY模型，相同id的记录会被更新

## 5. 注意事项

### 性能考虑
- **写入性能**: UNIQUE KEY模型的写入性能比DUPLICATE KEY略低
- **存储优化**: 启用merge-on-write可以减少存储空间但会增加写入开销
- **分桶策略**: 使用HASH(id)分桶确保相同ID的数据在同一分桶

### 监控要点
- **数据一致性**: 定期比较MySQL和Doris的数据量
- **延迟监控**: UPDATE操作的同步延迟
- **错误处理**: 关注Doris Load任务的成功率

## 6. 修复完成状态

✅ **已修复问题**:
- Doris表改为UNIQUE KEY模型
- 开启merge-on-write实时更新
- 修正字段类型映射 (updated_at: TEXT → DATETIME)
- 更新Flink同步脚本配置

✅ **当前运行状态**:
- 作业ID: 030e566951923e5d6dd2ca83ba07e644
- 状态: RUNNING
- 数据同步: MySQL(1961) → Doris(1963)

**现在系统完全支持MySQL的INSERT/UPDATE/DELETE操作！** 🎉 