'use strict';

// information_schema 与全局统计查询（db:check / migration-check / Migration Lab 使用）

const { rawQuery } = require('../config/database');

const TRACKED_TABLES = [
  'stores',
  'devices',
  'flow_events',
  'flow_hourly',
  'device_status_logs',
  'migration_markers',
  'migration_batches',
  'migration_operation_audit',
];

async function mysqlVersion() {
  const rows = await rawQuery('SELECT VERSION() AS version');
  return rows[0].version;
}

// 表元数据统计的总大小（字节）。DATA_LENGTH / INDEX_LENGTH 在部分托管实例上
// 可能滞后，因此不能将它当作 RDS 实例的实际磁盘占用。
async function databaseSize() {
  const rows = await rawQuery(
    `SELECT COALESCE(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS total_bytes
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = ?`,
    [process.env.DB_NAME || 'passenger_flow_codex']
  );
  return Number(rows[0].total_bytes);
}

// 优先读取 MySQL 8 InnoDB 表空间的已分配字节数。MariaDB 10.3 或权限不足时，
// 保留原有的 metadata 统计作为明确标注的降级值。
async function databaseStorage() {
  const database = process.env.DB_NAME || 'passenger_flow_codex';
  const metadataBytes = await databaseSize();
  try {
    const rows = await rawQuery(
      `SELECT COALESCE(SUM(ts.ALLOCATED_SIZE), 0) AS allocated_bytes
       FROM information_schema.INNODB_TABLES AS it
       JOIN information_schema.INNODB_TABLESPACES AS ts ON ts.SPACE = it.SPACE
       WHERE it.NAME LIKE CONCAT(?, '/%')`,
      [database]
    );
    const allocatedBytes = Number(rows[0].allocated_bytes);
    if (Number.isFinite(allocatedBytes) && allocatedBytes > 0) {
      return { bytes: allocatedBytes, source: 'INNODB_TABLESPACES.ALLOCATED_SIZE', isMetadataFallback: false, metadataBytes };
    }
  } catch (error) {
    // MariaDB 10.3 的列集或普通应用账号的权限可能不支持该查询；使用兼容回退。
  }
  return { bytes: metadataBytes, source: 'information_schema.TABLES.DATA_LENGTH + INDEX_LENGTH', isMetadataFallback: true, metadataBytes };
}

// 每张表：行数 / 数据长度 / 索引长度 / 空闲 / 总计
async function tableStats() {
  const rows = await rawQuery(
    `SELECT TABLE_NAME AS table_name, TABLE_ROWS AS approx_rows,
            COALESCE(DATA_LENGTH, 0) AS data_length,
            COALESCE(INDEX_LENGTH, 0) AS index_length,
            COALESCE(DATA_FREE, 0) AS data_free,
            COALESCE(DATA_LENGTH, 0) + COALESCE(INDEX_LENGTH, 0) AS total_size
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = ?
     ORDER BY TABLE_NAME`,
    [process.env.DB_NAME || 'passenger_flow_codex']
  );
  return rows;
}

// 精确行数（关键表 COUNT(*)）
async function exactRowCounts() {
  const rows = await rawQuery(
    `SELECT
       (SELECT COUNT(*) FROM stores) AS stores,
       (SELECT COUNT(*) FROM devices) AS devices,
       (SELECT COUNT(*) FROM flow_events) AS flow_events,
       (SELECT COUNT(*) FROM flow_hourly) AS flow_hourly,
       (SELECT COUNT(*) FROM device_status_logs) AS device_status_logs,
       (SELECT COUNT(*) FROM migration_markers) AS migration_markers,
       (SELECT COUNT(*) FROM migration_batches) AS migration_batches,
       (SELECT COUNT(*) FROM migration_operation_audit) AS migration_operation_audit`
  );
  return rows[0];
}

async function totalRows() {
  const counts = await exactRowCounts();
  return Object.values(counts).reduce((sum, v) => sum + Number(v), 0);
}

module.exports = { TRACKED_TABLES, mysqlVersion, databaseSize, databaseStorage, tableStats, exactRowCounts, totalRows };
