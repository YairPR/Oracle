const assert = require("node:assert/strict");
const {epochMs,fitWithin,validRange,axisRange,lowerBound} = require("./dist/temporal-state.cjs");
const a=epochMs("2026-09-30T02:35:04"), b=epochMs("2026-09-30T02:49:59");
assert.equal(a,1790735704000);
assert.equal(epochMs("2026-09-30T01:00"),epochMs("2026-09-30T01:00:00"));
for(const bad of ["", "2026-02-30T00:00:00", "2026-09-30T25:00:00", "garbage"]) assert.equal(epochMs(bad),null);
assert.equal(validRange(b,a),null);
assert.deepEqual(fitWithin([a,b],{from:a-10000,to:b+10000}),{from:a,to:b});
assert.equal(fitWithin([a,b],{from:a+1,to:b-1}),null);
assert.deepEqual(fitWithin([a,b],{from:a,to:a}),{from:a,to:a});
assert.deepEqual(axisRange({from:a,to:a}),{from:a-1000,to:a+1000});
assert.deepEqual(axisRange({from:a,to:b}),{from:a,to:b});
assert.equal(lowerBound([a,b],a),0);
assert.equal(lowerBound([a,b],b+1),2);
console.log("Temporal edge cases OK");

assert.equal(epochMs("2026-10-05T10:30:00+02:00"), epochMs("2026-10-05T08:30:00"));
assert.equal(epochMs("2026-02-30T10:30:00+02:00"), null);
