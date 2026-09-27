import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createApp,analyzeFrames,validateFrames} from './server.mjs';
const frame='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aC1sAAAAASUVORK5CYII=';
const pair={place:'Medeu',before:frame,after:frame};
test('validates bytes, rejects remote image URLs and fake MIME',()=>{
  validateFrames(pair);
  assert.throws(()=>validateFrames({...pair,before:'https://example.com/frame.jpg'}));
  assert.throws(()=>validateFrames({...pair,before:frame.replace('png','jpeg')}));
});
test('AI uses ordered images, server credentials, and preserves review requirement',async()=>{
  const result=await analyzeFrames(pair,{key:'test-only',model:'test-model',fetcher:async(url,init)=>{
    assert.equal(url,'https://api.openai.com/v1/responses');
    const request=JSON.parse(init.body);assert.equal(request.store,false);
    assert.equal(request.input[0].content[1].image_url,frame);
    assert.equal(request.text.format.strict,true);
    return {ok:true,json:async()=>({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify({summary:'Uncertain',changes:[]})}]}]})};
  }});
  assert.equal(result.needsReview,true);assert.equal(result.source,'ai_uploaded_frames');
});
test('provider failure never becomes a fake observation',async()=>{
  await assert.rejects(()=>analyzeFrames(pair,{key:'test',model:'test',fetcher:async()=>({ok:false})}));
});
test('unconfigured API reports unavailable and never pretends to be live',async()=>{
  const server=createApp({key:'',model:''});await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const url=`http://127.0.0.1:${server.address().port}/api/`;
    const health=await (await fetch(url+'health')).json();assert.equal(health.aiConfigured,false);assert.equal(health.droneFeed,'demo');
    assert.equal((await fetch(url+'analyze',{method:'POST'})).status,503);
  }finally{await new Promise(r=>server.close(r));}
});
test('cross-origin requests cannot trigger paid inference',async()=>{
  let called=false;const server=createApp({key:'test',model:'test',fetcher:()=>{called=true;throw Error();}});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try{
    const response=await fetch(`http://127.0.0.1:${server.address().port}/api/analyze`,{method:'POST',headers:{Origin:'https://other.example'}});
    assert.equal(response.status,403);assert.equal(called,false);
  }finally{await new Promise(r=>server.close(r));}
});
