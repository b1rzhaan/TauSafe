import {test} from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {buildDrones} from './drones.js';
test('drone animation tolerates initial RAF timestamp and both complete routes',()=>{
  globalThis.document={createElement:()=>({style:{},setAttribute(){}})};
  const scene=new THREE.Scene(), labels=[], messages=[];
  const root={clientWidth:1000,clientHeight:700,appendChild:e=>labels.push(e)};
  const geo=(lon,lat,y=0)=>new THREE.Vector3((lon-77)*80,y,(43.2-lat)*111);
  const camera=new THREE.PerspectiveCamera(37,1.4,.1,150);camera.position.set(12,20,-28);camera.lookAt(0,2,0);camera.updateMatrixWorld();
  const fleet=buildDrones(scene,root,geo,m=>messages.push(m));
  for(const mode of ['patrol','search']){
    fleet.setMode(mode,77.05,43.13);
    for(const elapsed of [-.04,0,.01,69.99,70,94.99,95,180,10000]){
      fleet.update(elapsed,camera);
      for(let i=0;i<3;i++)assert.ok(fleet.focusPosition(i).toArray().every(Number.isFinite));
    }
  }
  assert.equal(labels.length,3);assert.ok(messages.length>0);assert.ok(messages.every(m=>m.demo===true&&m.drones.length===3));
  fleet.setVisible(false);assert.ok(labels.every(l=>l.style.display==='none'));
  delete globalThis.document;
});
