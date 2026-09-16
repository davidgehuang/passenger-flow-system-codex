'use strict';
const {rawQuery,poolEnd}=require('../config/database');
const {TRACKED_TABLES}=require('../models/statsModel');
const {dbName}=require('../config/settings');
async function main(){
  const rows=await rawQuery('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=?',[dbName()]);
  const missing=TRACKED_TABLES.filter(t=>!rows.some(r=>r.TABLE_NAME===t));
  if(missing.length)throw new Error('数据库缺表: '+missing.join(', '));
  console.log('数据库可连接，8 张业务表存在');
}
main().catch(e=>{console.error(e.code||e.message);process.exitCode=1;}).finally(poolEnd);
