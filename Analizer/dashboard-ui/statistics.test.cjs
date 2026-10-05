const assert=require('node:assert/strict');
const {summarize}=require('./dist/statistics.cjs');
const points=[[0,2],[1000,4],[3000,10],[4000,null],[10000,20]];
const result=summarize(points,0,10000,'rate',1000);
assert.equal(result.covered,3);
assert.equal(result.integral,24);
assert.equal(result.mean,8);
assert.equal(result.valid,4);
assert.equal(result.max,20);
assert.equal(result.maxTime,10000);
assert.equal(summarize([[0,0],[1000,0]],0,1000,'counter_increment',1000).total,0);
assert.equal(summarize([[0,null],[1000,0],[2000,3]],0,2000,'counter_increment',1000).total,3);
assert.equal(summarize([[0,1200],[1000,2400]],0,1000,'interval_mean',1000).mean,1800);
assert.equal(summarize([[0,null]],0,1000,'rate',1000).mean,null);
const fullProcess=[null,null,null,0,null,null,9,null,null].map((v,i)=>[i*1000,v]);
const sparseProcess=[0,2,3,4,5,6,7,8].map(i=>fullProcess[i]);
for(let from=0;from<9000;from+=500) for(let to=from;to<9000;to+=500) {
  assert.deepEqual(summarize(sparseProcess,from,to,'instantaneous',1000),summarize(fullProcess,from,to,'instantaneous',1000));
}
console.log('Full-resolution statistics, interval means, gaps and zeros OK');
