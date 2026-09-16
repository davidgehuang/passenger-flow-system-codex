'use strict';
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const root = path.resolve(__dirname, '..');
const envPath = process.env.ENV_FILE ? path.resolve(process.env.ENV_FILE) : path.join(root, '.env');
dotenv.config({ path: envPath });
function integer(value, name, min, max, fallback) {
  const n = value === undefined || value === '' ? fallback : Number(value);
  if (!Number.isSafeInteger(n) || n < min || n > max) {
    const err = new Error(name + ' 必须是 ' + min + ' 到 ' + max + ' 的整数'); err.status = 400; throw err;
  }
  return n;
}
function dbName() {
  const name = process.env.DB_NAME || 'passenger_flow_codex';
  if (!/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(name)) throw new Error('DB_NAME 只能包含英文字母、数字和下划线，且以字母开头');
  return name;
}
function maintenanceFile() { return path.join(root, '.maintenance'); }
function isReadOnly() {
  return fs.existsSync(maintenanceFile()) ||
    String(process.env.MAINTENANCE_MODE).toLowerCase() === 'true' ||
    String(process.env.DB_READ_ONLY).toLowerCase() === 'true';
}
function assertWritable() {
  if (isReadOnly()) {
    const err = new Error('当前处于只读模式，业务写入已停止'); err.status = 503; err.code = 'READ_ONLY'; throw err;
  }
}
function options(withDatabase = true) {
  const timezone = process.env.DB_TIME_ZONE || '+08:00';
  if (!/^[+-](0[0-9]|1[0-3]):[0-5][0-9]$/.test(timezone)) throw new Error('DB_TIME_ZONE 必须使用固定偏移，例如 +08:00');
  const sslEnabled = String(process.env.DB_SSL).toLowerCase() === 'true';
  const caFile = process.env.DB_SSL_CA;
  return {
    host: process.env.DB_HOST || '127.0.0.1',
    port: integer(process.env.DB_PORT, 'DB_PORT', 1, 65535, 3306),
    user: process.env.DB_USER || '', password: process.env.DB_PASSWORD || '',
    database: withDatabase ? dbName() : undefined,
    connectionLimit: integer(process.env.DB_CONNECTION_LIMIT, 'DB_CONNECTION_LIMIT', 1, 100, 20),
    waitForConnections: true, queueLimit: 100, connectTimeout: 10000, charset: 'utf8mb4',
    timezone, dateStrings: true, supportBigNumbers: true, bigNumberStrings: true, enableKeepAlive: true,
    ...(sslEnabled ? { ssl: { rejectUnauthorized: true, ...(caFile ? { ca: fs.readFileSync(path.resolve(root, caFile)) } : {}) } } : {}),
  };
}
function configurePool(pool) {
  pool.on('connection', conn => { conn.query('SET SESSION time_zone = ?', [process.env.DB_TIME_ZONE || '+08:00']); });
  return pool;
}
module.exports = { root, envPath, integer, dbName, options, configurePool, isReadOnly, assertWritable, maintenanceFile };
