import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import terrain from '../assets/terrain/almaty.json';
import catalog from '../assets/data/places.json';
import demoRoute from '../assets/data/demo_route.json';
import waterData from '../assets/data/water.json';
import contextData from '../assets/data/context.json';
import { buildDrones } from './drones.js';
import { buildDiorama } from './diorama.js';

const root=document.getElementById('scene');
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
const send=(data)=>{const text=JSON.stringify(data);if(window.TauSafe)window.TauSafe.postMessage(text);else if(window.parent!==window)window.parent.postMessage(text,location.origin);};
try {
const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:'low-power'});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.7));renderer.setClearColor(0xe3edf4,1);
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFShadowMap;
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.0;
root.appendChild(renderer.domElement);
const scene=new THREE.Scene();scene.fog=new THREE.Fog(0xe3edf4,65,130);
const camera=new THREE.PerspectiveCamera(37,1,0.1,150);
camera.position.set(12,20,-28);
const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=!reduced;controls.dampingFactor=.075;controls.minDistance=3;controls.maxDistance=38;controls.maxPolarAngle=Math.PI*.475;controls.target.set(0,2,0);
scene.add(new THREE.HemisphereLight(0xf1faff,0x557563,2.0));
const sun=new THREE.DirectionalLight(0xffefcb,2.3);sun.position.set(-12,25,10);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-18;sun.shadow.camera.right=18;sun.shadow.camera.top=18;sun.shadow.camera.bottom=-18;sun.shadow.normalBias=.04;scene.add(sun);
const fill=new THREE.DirectionalLight(0xc5e0ff,1);fill.position.set(15,9,-20);scene.add(fill);
const n=terrain.width;
const exaggeration=1.65,base=700;
const halfWidth=(terrain.east-terrain.west)*81.2/2;
const halfDepth=(terrain.north-terrain.south)*111.195/2;
function softenModelEdges(object){
 const position=object.geometry.getAttribute('position');
 const colors=new Float32Array(position.count*4);
 for(let i=0;i<position.count;i++){
  const edge=Math.min(halfWidth-Math.abs(position.getX(i)),halfDepth-Math.abs(position.getZ(i)));
  const t=THREE.MathUtils.clamp((edge-.05)/2.4,0,1);
  const alpha=t*t*(3-2*t);
  colors.set([1,1,1,alpha],i*4);
 }
 object.geometry.setAttribute('color',new THREE.Float32BufferAttribute(colors,4));
 for(const material of Array.isArray(object.material)?object.material:[object.material]){
  material.vertexColors=true;
  material.transparent=true;
  material.alphaTest=.015;
  material.depthWrite=true;
  material.needsUpdate=true;
 }
}
const altitude=(lon,lat)=>{
  const x=THREE.MathUtils.clamp((lon-terrain.west)/(terrain.east-terrain.west)*(n-1),0,n-1),z=THREE.MathUtils.clamp((terrain.north-lat)/(terrain.north-terrain.south)*(n-1),0,n-1);
  const i=Math.min(n-2,Math.floor(x)),j=Math.min(n-2,Math.floor(z)),fx=x-i,fz=z-j;
  return THREE.MathUtils.lerp(THREE.MathUtils.lerp(terrain.heights[j*n+i],terrain.heights[j*n+i+1],fx),THREE.MathUtils.lerp(terrain.heights[(j+1)*n+i],terrain.heights[(j+1)*n+i+1],fx),fz);
};
const geo=(lon,lat,offset=0)=>new THREE.Vector3((lon-(terrain.west+terrain.east)/2)*81.2,(altitude(lon,lat)-base)/1000*exaggeration+offset,((terrain.north+terrain.south)/2-lat)*111.195);
const drones=buildDrones(scene,root,geo,send);
const modelReady=new Promise((resolve,reject)=>{
 const url=new URL('../models/almaty_diorama.glb?v=city-scale-2',location.href).href;
 new GLTFLoader().load(url,gltf=>{
 gltf.scene.name='TauSafe GLB diorama';
  gltf.scene.traverse(object=>{
   if(object.name==='Rounded diorama base'){object.visible=false;return;}
   if(object.isMesh){
    object.castShadow=!object.name.includes('Sculpted terrain');
    object.receiveShadow=true;
    softenModelEdges(object);
   }
  });
  scene.add(gltf.scene);resolve(gltf.scene);
 },undefined,reject);
});
// OpenStreetMap water geometry is separate from DEM and carries ODbL attribution.
for(const relation of waterData.elements??[]){
 const pending=(relation.members??[]).filter(m=>m.role==='outer'&&m.geometry?.length>=2).map(m=>[...m.geometry]);
 const same=(a,b)=>a.lon===b.lon&&a.lat===b.lat;
 while(pending.length){
  const ring=pending.shift();
  while(!same(ring[0],ring.at(-1))&&pending.length){
   const last=ring.at(-1);const i=pending.findIndex(s=>same(s[0],last)||same(s.at(-1),last));
   if(i<0)break;
   const segment=pending.splice(i,1)[0];if(same(segment.at(-1),last))segment.reverse();ring.push(...segment.slice(1));
  }
  if(ring.length<4||!same(ring[0],ring.at(-1)))continue;
  const shape=new THREE.Shape(ring.map(p=>{const q=geo(p.lon,p.lat);return new THREE.Vector2(q.x,-q.z);}));
  const wg=new THREE.ShapeGeometry(shape);wg.rotateX(-Math.PI/2);
  const surface=wg.attributes.position;
  // Drape every vertex on the sampled DEM to avoid floating water at cutout edges.
  for(let i=0;i<surface.count;i++){const lon=surface.getX(i)/81.2+(terrain.west+terrain.east)/2,lat=(terrain.north+terrain.south)/2-surface.getZ(i)/111.195;surface.setY(i,(altitude(lon,lat)-base)/1000*exaggeration+.035);}
  wg.computeVertexNormals();const lake=new THREE.Mesh(wg,new THREE.MeshStandardMaterial({color:0x358eaa,roughness:.3,metalness:.1,side:THREE.DoubleSide}));scene.add(lake);
 }
}
const detailLabels=[];
let safetyVisible=false;
function addLabel(p){
 const label=document.createElement('button');label.className=p.city?'pin city':p.safety?'pin safety-pin':'pin detail';label.textContent=p.name;label.setAttribute('aria-label','Подробнее: '+p.name);
 label.onclick=()=>{focus(p.position,p.distance??3);showDetail(p);};root.appendChild(label);p.label=label;detailLabels.push(p);
}
const detailPanel=document.getElementById('detail-card');
function showDetail(p){document.getElementById('detail-title').textContent=p.name;document.getElementById('detail-text').textContent=p.description;detailPanel.hidden=false;}
document.getElementById('close-detail').onclick=()=>{detailPanel.hidden=true;};
const diorama=buildDiorama({scene,geo,altitude,bounds:terrain,addLabel,bakedModel:true});
const safetyGroup=new THREE.Group();safetyGroup.name='Справочные точки безопасности';safetyGroup.visible=false;scene.add(safetyGroup);
const safetyMaterial={
 shelter:new THREE.MeshStandardMaterial({color:'#d8a855',emissive:'#54300a'}),
 medical:new THREE.MeshStandardMaterial({color:'#c8544f',emissive:'#34120f'}),
 orientation:new THREE.MeshStandardMaterial({color:'#3c84a5',emissive:'#102838'})
};
function safetyPoint(id,name,lon,lat,kind,description){
 const position=geo(lon,lat,.20);
 const dot=new THREE.Mesh(new THREE.OctahedronGeometry(.10),safetyMaterial[kind]);dot.position.copy(position);safetyGroup.add(dot);
 const pole=new THREE.Mesh(new THREE.CylinderGeometry(.009,.009,.20,6),safetyMaterial[kind]);pole.position.copy(position).y-=.13;safetyGroup.add(pole);
 addLabel({id:'safety-'+id,name,position:position.clone().add(new THREE.Vector3(0,.22,0)),description,distance:2.8,safety:true});
}
for(const e of contextData.elements){
 const kind=e.tags?.amenity;
 if(!['shelter','hospital','clinic','fire_station'].includes(kind))continue;
 const ring=e.geometry?.length?e.geometry:[e];
 const lon=ring.reduce((sum,p)=>sum+p.lon,0)/ring.length,lat=ring.reduce((sum,p)=>sum+p.lat,0)/ring.length;
 if(!Number.isFinite(lon)||!Number.isFinite(lat))continue;
 const medical=kind==='hospital'||kind==='clinic';
 safetyPoint(e.id,medical?'Медпункт (OSM)':kind==='fire_station'?'Пожарная часть (OSM)':'Городское укрытие (OSM)',lon,lat,
  medical?'medical':'shelter',
  'Справочная точка OpenStreetMap. Доступность, часы работы и возможность укрыться сейчас не проверены.');
}
safetyPoint('medeu','Ориентир: Медеу',77.05861111,43.1575,'orientation','Ориентир на пути к городу и нижней станции канатки. Доступность транспорта не подтверждена.');
safetyPoint('shymbulak','Ориентир: Шымбулак',77.08083333,43.12805556,'orientation','Ориентир у станции канатки. Доступность транспорта и укрытия не подтверждена.');
const markerGroup=new THREE.Group();scene.add(markerGroup);const markers=[];
for(const p of catalog.filter(p=>p.lat!=null)){
 const position=geo(p.lon,p.lat,.42);
 const dot=new THREE.Mesh(new THREE.SphereGeometry(.065,16,10),new THREE.MeshStandardMaterial({color:0xffca72,emissive:0x47300c,roughness:.3}));dot.position.copy(position);dot.userData.id=p.id;markerGroup.add(dot);markers.push(dot);
 const stem=new THREE.Mesh(new THREE.CylinderGeometry(.015,.015,.5,6),new THREE.MeshBasicMaterial({color:0xffffff}));stem.position.copy(position).y-=.27;markerGroup.add(stem);
 const label=document.createElement('button');label.className='pin';label.textContent=p.name;label.onclick=()=>select(p.id,true);label.setAttribute('aria-label','Показать '+p.name);root.appendChild(label);p.label=label;p.position=position;
}
const routeGroup=new THREE.Group(),trackGroup=new THREE.Group();scene.add(routeGroup,trackGroup);
let path=demoRoute.points,fly=false,flyT=0,transition=null,lastTime=performance.now(),selected='kok',twoD=false,motion=!reduced,elapsed=0;
const routeMaterial=new THREE.LineBasicMaterial({color:0xf5b449,depthTest:false});
function clearGroup(g){while(g.children.length){const c=g.children[0];g.remove(c);c.geometry?.dispose();c.material?.dispose();}}
function drawRoute(points){path=points;clearGroup(routeGroup);const list=[];for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i];for(let j=0;j<8;j++){const t=j/8;list.push(geo(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,.045));}}if(points.length)list.push(geo(...points.at(-1),.045));if(list.length>1){const l=new THREE.Line(new THREE.BufferGeometry().setFromPoints(list),routeMaterial.clone());l.renderOrder=2;routeGroup.add(l);}}
drawRoute(path);
const userDot=new THREE.Mesh(new THREE.SphereGeometry(.13,18,12),new THREE.MeshStandardMaterial({color:0x167abe,emissive:0x12394a}));userDot.visible=false;scene.add(userDot);
const alertMarker=new THREE.Mesh(new THREE.RingGeometry(.4,.48,48),new THREE.MeshBasicMaterial({color:0xee9c36,transparent:true,opacity:.85,side:THREE.DoubleSide,depthTest:false,depthWrite:false}));alertMarker.rotation.x=-Math.PI/2;alertMarker.renderOrder=20;alertMarker.visible=false;scene.add(alertMarker);
function focus(target,distance=9){fly=false;document.getElementById('fly').textContent='▷ Облёт';const desired=target.clone().add(new THREE.Vector3(distance*.4,distance*.75,-distance));if(reduced){controls.target.copy(target);camera.position.copy(desired);}else transition={at:performance.now(),from:camera.position.clone(),to:desired,tf:controls.target.clone(),tt:target.clone()};}
function showSpots(id){const list=document.getElementById('spot-list');list.replaceChildren();for(const p of detailLabels.filter(p=>p.parent===id)){const b=document.createElement('button');b.textContent=p.name;b.onclick=()=>{focus(p.position,p.distance);showDetail(p);};list.appendChild(b);}}
function overview(){detailPanel.hidden=true;document.getElementById('spot-list').replaceChildren();focus(new THREE.Vector3(0,1.8,0),camera.aspect<.8?27:23);}
function select(id,notify=false){const p=catalog.find(p=>p.id===id&&p.position);if(!p)return;selected=id;detailPanel.hidden=true;showSpots(id);focus(id==='shymbulak'?geo(77.095,43.121,.3):p.position,id==='shymbulak'?4.8:id==='medeu'?4.5:3.8);if(notify)send({type:'select',id});}
window.tauCommand=(data)=>{
 if(typeof data==='string')data=JSON.parse(data);
 if(data.type==='select'){if(data.overview){selected=data.id;overview();}else select(data.id);}
 if(data.type==='route'){drawRoute(data.points);document.getElementById('route-status').textContent=data.demo?'ДЕМО-ТРЕК · НЕ ДЛЯ НАВИГАЦИИ':'ИМПОРТ · ТРЕК НЕ ПРОВЕРЕН';}
 if(data.type==='position'){if(data.lon==null){userDot.visible=false;return;}const within=data.lon>=terrain.west&&data.lon<=terrain.east&&data.lat>=terrain.south&&data.lat<=terrain.north;userDot.visible=within;if(within){userDot.position.copy(geo(data.lon,data.lat,.2));if(data.focus)focus(userDot.position,7);}else if(data.focus)send({type:'outside'});}
 if(data.type==='track'){clearGroup(trackGroup);const groups=new Map();for(const p of data.points??[]){if(p.lon<terrain.west||p.lon>terrain.east||p.lat<terrain.south||p.lat>terrain.north)continue;const key=p.segment; if(!groups.has(key))groups.set(key,[]);groups.get(key).push(geo(p.lon,p.lat,.07));}for(const points of groups.values()){if(points.length>1)trackGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineBasicMaterial({color:0x2b91db,depthTest:false})));}}
 if(data.type==='droneMode'){drones.setMode(data.mode,data.lon,data.lat);}
 if(data.type==='droneFocus'){const p=drones.focusPosition(data.id);if(p)focus(p,4);}
 if(data.type==='droneVisible'){drones.setVisible(data.visible===true);}
 if(data.type==='alertFocus'||data.type==='alertMark'){alertMarker.position.copy(geo(data.lon,data.lat,.22));alertMarker.visible=true;if(data.type==='alertFocus')focus(alertMarker.position,5);}
 if(data.type==='overview'){overview();}
 if(data.type==='safety'){safetyVisible=data.visible===true;safetyGroup.visible=safetyVisible;}
};
window.addEventListener('message',e=>{if(e.source===window.parent&&e.origin===location.origin){try{window.tauCommand(e.data);}catch(_){}}});
document.getElementById('home').onclick=overview;
document.getElementById('city').onclick=()=>{const p=detailLabels.find(p=>p.city);document.getElementById('spot-list').replaceChildren();focus(p.position,7);showDetail(p);};
document.getElementById('resort').onclick=()=>select('shymbulak',true);
document.getElementById('motion').textContent=motion?'Ⅱ Анимация':'▷ Анимация';
document.getElementById('motion').setAttribute('aria-pressed',String(motion));
document.getElementById('motion').onclick=()=>{motion=!motion;document.getElementById('motion').textContent=motion?'Ⅱ Анимация':'▷ Анимация';document.getElementById('motion').setAttribute('aria-pressed',String(motion));};
document.getElementById('north').onclick=()=>{fly=false;transition=null;camera.position.set(0,24,18);controls.target.set(0,2,0);};
document.getElementById('view').onclick=()=>{fly=false;transition=null;twoD=!twoD;camera.position.set(twoD?0:17,twoD?35:23,twoD?.01:25);controls.target.set(0,2,0);document.getElementById('view').textContent=twoD?'Объём':'Сверху';};
document.getElementById('fly').onclick=()=>{fly=!fly;transition=null;flyT=0;document.getElementById('fly').textContent=fly?'Ⅱ Стоп':'▷ Облёт';};
controls.addEventListener('start',()=>{transition=null;fly=false;document.getElementById('fly').textContent='▷ Облёт';});
function resize(){const w=root.clientWidth,h=root.clientHeight;renderer.setSize(w,h);camera.aspect=w/h;controls.maxDistance=camera.aspect<.8?38:32;camera.updateProjectionMatrix();}new ResizeObserver(resize).observe(root);resize();
function animate(time){requestAnimationFrame(animate);if(document.hidden)return;const dt=Math.max(0,Math.min((time-lastTime)/1000,.1));lastTime=time;
 if(motion)elapsed+=dt;diorama.update(elapsed,true);
 if(transition){const t=Math.min((time-transition.at)/1000,1),s=t*t*(3-2*t);camera.position.lerpVectors(transition.from,transition.to,s);controls.target.lerpVectors(transition.tf,transition.tt,s);if(t===1)transition=null;}
 if(fly&&path.length>1){flyT+=dt*.038;const step=(flyT%1)*(path.length-1),i=Math.floor(step),f=step-i,a=path[i],b=path[Math.min(i+1,path.length-1)],p=geo(a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f);controls.target.lerp(p,.05);camera.position.lerp(p.clone().add(new THREE.Vector3(3.4,4,5)),.035);}
 controls.update();drones.update(elapsed,camera);renderer.render(scene,camera);
 const close=camera.position.distanceTo(controls.target)<17,occupied=[];
 const labels=[...detailLabels.filter(p=>p.city),...catalog.filter(p=>p.label).sort((a,b)=>(b.id===selected)-(a.id===selected)),...detailLabels.filter(p=>!p.city)];
 for(const p of labels){
  const v=p.position.clone().project(camera),x=(v.x*.5+.5)*root.clientWidth,y=(-v.y*.5+.5)*root.clientHeight;
  const detail=detailLabels.includes(p)&&!p.city;
 const wanted=p.safety?safetyVisible&&(close||camera.position.distanceTo(p.position)<9):!detail||(close&&(p.parent===selected||camera.position.distanceTo(p.position)<6));
  const w=p.label.offsetWidth||130,h=p.label.offsetHeight||32,rect={left:x-w/2,right:x+w/2,top:y-h-21,bottom:y-21};
  let visible=wanted&&v.z<1&&v.z>-1&&rect.left>6&&rect.right<root.clientWidth-6&&rect.top>105&&rect.bottom<root.clientHeight-48;
  if(visible&&occupied.some(r=>rect.left<r.right+5&&rect.right>r.left-5&&rect.top<r.bottom+5&&rect.bottom>r.top-5))visible=false;
  if(visible)occupied.push(rect);
  p.label.style.transform=`translate(${x}px,${y-21}px) translate(-50%,-100%)`;p.label.style.visibility=visible?'visible':'hidden';p.label.classList.toggle('selected',p.id===selected);
 }
}
requestAnimationFrame(animate);modelReady.then(()=>{send({type:'ready'});window.__tauReady=true;window.__tauStats={...diorama.stats,model:'GLB',drones:3};window.__tauCamera=()=>({distance:camera.position.distanceTo(controls.target),maxDistance:controls.maxDistance});}).catch(error=>{send({type:'error',message:'Не удалось загрузить 3D-модель: '+error});});
}catch(error){root.innerHTML='<div class="failure">Объёмная карта недоступна на этом устройстве.<br>Каталог и функции похода доступны.<br><small></small></div>';root.querySelector('small').textContent=String(error);send({type:'error',message:String(error)});}
