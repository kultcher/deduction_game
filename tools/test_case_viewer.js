/* Node's built-ins only. Exercises browser logic with a minimal DOM substitute.
 * Run: node tools/test_case_viewer.js
 * This checks data/interaction logic, not real browser layout or rendering.
 */
"use strict";
const fs=require("node:fs"),path=require("node:path"),vm=require("node:vm"),assert=require("node:assert/strict");
const template=fs.readFileSync(path.join(__dirname,"case_viewer.html"),"utf8");
const script=template.split("<script>")[1].split("</script>")[0];
const fixture=fs.readFileSync(path.join(__dirname,"fixtures/case_viewer.trace.jsonl"),"utf8").trim().split("\n").map(JSON.parse);
class Element {
 constructor(){this.children=[];this.style={};this._value="";this.textContent="";this.selected=false;}
 append(...nodes){this.children.push(...nodes);}
 replaceChildren(...nodes){this.children=nodes;this._value="";}
 setAttribute(k,v){this[k]=v;}
 get options(){return this.children;}
 get selectedOptions(){return this.children.filter(x=>x.selected);}
 get value(){return this._value||this.children[0]?.value||"";}
 set value(v){this._value=String(v);}
 click(){this.clicked=true;}
 getBoundingClientRect(){return {left:0,width:1000};}
}
function boot(events,detailed=true){
 const elements=new Map();
 const document={getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);},
 createElement(){return new Element();},createElementNS(){return new Element();}};
 document.getElementById("case-data").textContent=JSON.stringify({source:"test",detailed,warnings:[],events});
 document.getElementById("mode").value="overview";
 document.getElementById("start").value=1;
 const context=vm.createContext({document,Option:function(text,value){const e=new Element();e.textContent=text;e.value=value;return e;}});
 vm.runInContext(script,context);
 return {context,run:code=>vm.runInContext(code,context)};
}
const {run}=boot(fixture);
assert.equal(run('stateAt("real:agnes",4).state.trust'),.5);
assert.equal(run('stateAt("real:agnes",5).state.trust'),.6);
assert.equal(run('stateAt("shadow:jory",10).state.trust'),.4);
assert.equal(run('stateAt("real:agnes",6).state.ledger["demo:reading"].eff'),.45);
assert.equal(run('stateAt("real:agnes",2).state.ledger["demo:reading"]'),undefined);
run('$("mode").value="suspicion";populate();');
assert.equal(run('series[0].points.at(-1).v'),.235);
run('$("mode").value="ledger";populate();');
assert.equal(run('series[0].points.at(-1).v'),.5);
assert.equal(run('series[1].points.at(-1).v'),.45);
run('$("compare").checked=true;rebuild();seek(7);');
assert.equal(run('series.length'),2);
assert.equal(run('$("decision").children.length'),3);
run('$("search").value="kept a promise";$("search").oninput();');
assert.equal(run('matching.length'),1);
run('seek(0);$("nextMatch").onclick();');
assert.equal(run('cursor'),4);
run('$("start").value=2;$("end").value=5;draw();');
assert.equal(run('range().join(",")'),"1,4");
const legacy=boot([{seq:1,type:"snapshot",data:{npcs:{agnes:{trust:.3,suspicion:{jory:.8}}}}}],false);
assert.equal(legacy.run('stateAt("real:agnes",0).state.trust'),.3);
assert.equal(legacy.run('series[0].points[0].v'),.3);
boot([{seq:1,type:"trust",data:{to:.4}}],false);

const parsed=run('parseCase('+JSON.stringify(fixture.map(JSON.stringify).join("\n"))+',"real.trace.jsonl")');
assert.equal(parsed.detailed,true);
assert.equal(parsed.events.length,11);
assert.throws(()=>run('parseCase("","empty")'),/Empty/);
const corrupt=JSON.parse(JSON.stringify(fixture));corrupt[5].data.changes[0].from=.1;
assert.throws(()=>run('parseCase('+JSON.stringify(corrupt.map(JSON.stringify).join("\n"))+',"bad")'),/previous value mismatch/);
const missing=fixture.filter((_,i)=>i!==4);
assert.throws(()=>run('parseCase('+JSON.stringify(missing.map(JSON.stringify).join("\n"))+',"gap")'),/sequence/);
run('setupCase(parseCase('+JSON.stringify(fixture.map(JSON.stringify).join("\n"))+',"reload.trace.jsonl"));');
assert.equal(run('E.length'),11);
assert.equal(run('cursor'),10);
assert.equal(run('records.size'),2);
assert.equal(run('$("load").disabled'),undefined);
const old=JSON.stringify({seq:1,type:"snapshot",data:{npcs:{agnes:{trust:.3,suspicion:{jory:.8}}}}});
run('setupCase(parseCase('+JSON.stringify(old)+',"old.jsonl"));$("mode").value="suspicion";populate();');
assert.equal(run('$("targets").options.length'),1);
run('$("mode").value="npc_trust";populate();');
assert.equal(run('$("availability").textContent.includes("no recorded")'),true);
assert.equal(run('CASE.warnings[0].includes(".trace.jsonl")'),true);
run('$("load").onclick();');
assert.equal(run('$("file").clicked'),true);
console.log("VIEWER JS: 28 checks passed (DOM substitute; visual browser check still required)");
