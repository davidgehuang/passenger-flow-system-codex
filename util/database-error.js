'use strict';
function databaseErrorDetail(err) {
  const code = err && err.code ? String(err.code) : 'DATABASE_ERROR';
  const source = String((err && (err.sqlMessage || err.message)) || '未知数据库错误');
  const message = source.replace(/(password\s*[:=]\s*)\S+/ig, '$1[redacted]');
  return '[ERROR] ' + code + ': ' + message;
}
function databaseErrorHint(err) {
  if (!err || err.code !== 'ER_ACCESS_DENIED_ERROR') return '';
  return '认证被拒绝：核对 DB_USER、DB_PASSWORD、RDS 中该账号允许的 Host，以及密码中 #、空格或引号是否已正确引用。不要在日志中输出密码。';
}
module.exports = { databaseErrorDetail, databaseErrorHint };
