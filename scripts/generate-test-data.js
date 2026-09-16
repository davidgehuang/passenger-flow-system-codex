'use strict';
const {parseArgs,runScript}=require('./lib/common');
const {integer,assertWritable}=require('../config/settings');
const {rawQuery,transaction,poolEnd}=require('../config/database');
const {seed}=require('./seed');
const lab=require('../services/migrationLabService');
async function main(){
  try{
    assertWritable();
    const args=parseArgs(process.argv.slice(2));
    if(args.rows!==undefined&&args['target-mb']!==undefined)throw new Error('--rows 和 --target-mb 只能选择一个');
    const mb=args['target-mb']===undefined?null:integer(args['target-mb'],'target-mb',1,5000,10);
    const total=mb===null?integer(args.rows,'rows',1,10000000,2000):Math.ceil(mb*1048576/512);
    const days=integer(args.days,'days',0,365,7),stores=integer(args.stores,'stores',5,500,5);
    const perStore=integer(args['devices-per-store'],'devices-per-store',1,5,4);
    await seed();
    if(stores>5)await transaction(async()=>{
      for(let i=1;i<=stores-5;i++){
        const code='SIM-ST-'+String(i).padStart(5,'0');
        await rawQuery('INSERT INTO stores (store_code,store_name,city,status) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE store_id=store_id',[code,'模拟门店'+i,['北京','上海','广州','成都'][i%4],'ACTIVE']);
        const [s]=await rawQuery('SELECT store_id FROM stores WHERE store_code=?',[code]);
        for(let d=1;d<=perStore;d++)await rawQuery('INSERT INTO devices (device_code,store_id,device_name,status) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE device_id=device_id',['SIM-DV-'+i+'-'+d,s.store_id,'模拟设备'+d,'ONLINE']);
      }
    });
    let done=0;
    console.log('有界生成 '+total+' 条事件；过去 '+days+' 天；容量为估算值');
    while(done<total){
      const n=Math.min(5000,total-done);
      const r=await lab.insertRows(n,{label:'GENERATE',historyDays:days});done+=r.insertedRows;
      console.log('已完成 '+done+'/'+total);
    }
    console.log('生成完成；不承诺物理数据库增长精度。');
  }finally{await poolEnd();}
}
runScript(main);
