import * as THREE from 'three';
import context from '../assets/data/context.json';

// Architecture and vegetation are deliberately enlarged miniatures. OSM fixes
// positions and cable alignments; neither motion nor models encode live status.
export function buildDiorama({ scene, geo, altitude, bounds, addLabel, bakedModel=false }) {
  const ivory = new THREE.MeshStandardMaterial({ color: '#f6eee0', roughness: .85 });
  const roof = new THREE.MeshStandardMaterial({ color: '#bf674a', roughness: .8 });
  const dark = new THREE.MeshStandardMaterial({ color: '#254c52', roughness: .45 });
  const blue = new THREE.MeshStandardMaterial({ color: '#5ebdcc', roughness: .3, metalness: .1 });
  const gold = new THREE.MeshStandardMaterial({ color: '#edb547', roughness: .5 });
  const cube = new THREE.BoxGeometry(1, 1, 1);
  const animations = [];
  const staticScenery=new THREE.Group();staticScenery.name='Legacy generated scenery';staticScenery.visible=!bakedModel;scene.add(staticScenery);
  const dummy=new THREE.Object3D();
  let buildings=[],treePositions=[];
  const inside = p => p.lon >= bounds.west && p.lon <= bounds.east && p.lat >= bounds.south && p.lat <= bounds.north;
  function box(parent, material, x, y, z, sx, sy, sz) {
    const m = new THREE.Mesh(cube, material); m.position.set(x,y,z); m.scale.set(sx,sy,sz); m.castShadow = true; m.receiveShadow=true; parent.add(m); return m;
  }
  function beam(parent, a, b, radius, material) {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(radius,radius,a.distanceTo(b),5),material);
    m.position.copy(a).add(b).multiplyScalar(.5);m.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),b.clone().sub(a).normalize());parent.add(m);return m;
  }
  if(!bakedModel){
  const ribbons=new Map();
  function ribbon(points, width, color, offset = .025) {
    if(!ribbons.has(color))ribbons.set(color,[]);
    const vertices=ribbons.get(color);
    for(let i=1;i<points.length;i++) {
      const a=points[i-1], b=points[i];
      const len=Math.hypot((a.lon-b.lon)*81.2,(a.lat-b.lat)*111.195);
      const steps=Math.max(1,Math.ceil(len/.06));
      for(let k=0;k<steps;k++) {
        const p={lon:a.lon+(b.lon-a.lon)*k/steps,lat:a.lat+(b.lat-a.lat)*k/steps};
        const q={lon:a.lon+(b.lon-a.lon)*(k+1)/steps,lat:a.lat+(b.lat-a.lat)*(k+1)/steps};
        if(!inside(p)||!inside(q))continue;
        const u=geo(p.lon,p.lat,offset),v=geo(q.lon,q.lat,offset),d=v.clone().sub(u);d.y=0;d.normalize();
        const normal=new THREE.Vector3(-d.z,0,d.x).multiplyScalar(width/2);
        const left=u.clone().add(normal),right=u.clone().sub(normal),endLeft=v.clone().add(normal),endRight=v.clone().sub(normal);
        for(const t of [left,right,endLeft,right,endRight,endLeft])vertices.push(t.x,t.y,t.z);
      }
    }
  }
  for(const e of context.elements) {
    if(!e.geometry)continue;
    if(e.tags?.waterway==='river')ribbon(e.geometry,.038,'#50bbcb',.038);
    if(e.tags?.highway)ribbon(e.geometry,e.tags.highway==='primary'?.052:.034,'#f4e4c5',.03);
  }
  for(const [color,vertices] of ribbons){
    if(!vertices.length)continue;
    const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));g.computeVertexNormals();
    staticScenery.add(new THREE.Mesh(g,new THREE.MeshStandardMaterial({color,roughness:.8,side:THREE.DoubleSide})));
  }

  // Reuse one instanced mesh for the OSM building centres in central Almaty.
  buildings=context.elements.filter(e=>e.tags?.building && e.geometry?.length>3);
  const city=new THREE.InstancedMesh(cube,ivory,buildings.length);city.castShadow=true;city.receiveShadow=true;
  buildings.forEach((b,i)=>{
    const ring=b.geometry.slice(0,-1),lon=ring.reduce((a,p)=>a+p.lon,0)/ring.length,lat=ring.reduce((a,p)=>a+p.lat,0)/ring.length;
    const sx=Math.max(.027,(Math.max(...ring.map(p=>p.lon))-Math.min(...ring.map(p=>p.lon)))*81.2);
    const sz=Math.max(.027,(Math.max(...ring.map(p=>p.lat))-Math.min(...ring.map(p=>p.lat)))*111.195);
    const h=THREE.MathUtils.clamp(Number.parseFloat(b.tags['building:levels']||3)*.016,.035,.27);
    dummy.position.copy(geo(lon,lat,h/2+.015));dummy.scale.set(sx,h,sz);dummy.updateMatrix();city.setMatrixAt(i,dummy.matrix);
    city.setColorAt(i,new THREE.Color(i%5===0?'#d9c39a':i%3===0?'#b3c8c4':'#f7edd7'));
  });staticScenery.add(city);
  addLabel({id:'city',name:'АЛМАТЫ',subtitle:'Город у подножия',position:geo(76.953,43.246,.55),city:true,
    description:'Центральные кварталы Алматы. Дороги и расположение домов взяты из OpenStreetMap; объёмы зданий упрощены.',distance:7});

  // Decorative groves follow altitude and slope, not an inventory of real trees.
  let seed=347;const rand=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
  treePositions=[];
  for(let i=0;i<6500&&treePositions.length<1600;i++){
    const lon=bounds.west+rand()*(bounds.east-bounds.west),lat=43.065+rand()*.166,h=altitude(lon,lat);
    if(h<1350||h>2850||Math.abs(altitude(lon+.0005,lat)-altitude(lon-.0005,lat))>85)continue;
    if(Math.sin(lon*240)*Math.cos(lat*185)<-.1)continue;
    if(lon>76.972&&lon<76.995&&lat<43.059)continue;
    if(lon>77.075&&lon<77.115&&lat>43.109&&lat<43.13)continue;
    treePositions.push({lon,lat,scale:.75+rand()*.8});
  }
  const trees=new THREE.InstancedMesh(new THREE.ConeGeometry(.055,.19,6),new THREE.MeshStandardMaterial({color:'#ffffff',roughness:1,flatShading:true}),treePositions.length);
  treePositions.forEach((p,i)=>{dummy.position.copy(geo(p.lon,p.lat,p.scale*.105));dummy.scale.setScalar(p.scale);dummy.updateMatrix();trees.setMatrixAt(i,dummy.matrix);trees.setColorAt(i,new THREE.Color(i%3===0?'#48854b':'#2c654c'));});trees.castShadow=true;staticScenery.add(trees);
  }
  if(bakedModel)addLabel({id:'city',name:'АЛМАТЫ',subtitle:'Город у подножия',position:geo(76.953,43.246,.55),city:true,
    description:'Центральные кварталы Алматы встроены в 3D-модель. Дороги и расположение зданий основаны на OpenStreetMap; объёмы упрощены.',distance:7});

  function station(point,name,id,parent,description){
    const group=new THREE.Group();group.position.copy(geo(point.lon,point.lat,.04));scene.add(group);
    box(group,ivory,0,.095,0,.30,.19,.20);box(group,dark,0,.125,-.103,.23,.065,.009);box(group,roof,0,.205,0,.34,.035,.24);
    box(group,gold,0,.065,-.112,.07,.10,.01);
    addLabel({id,name,parent,position:group.position.clone().add(new THREE.Vector3(0,.35,0)),description,distance:2.6});
    return group;
  }
  const liftOrder=[171467770,173568370,167106523];
  const lifts=context.elements.filter(e=>liftOrder.includes(e.id)).sort((a,b)=>liftOrder.indexOf(a.id)-liftOrder.indexOf(b.id));
  const stations=new Set();
  for(const lift of lifts){
    const index=lift.id===171467770?0:lift.id===173568370?1:2;
    const names=['Медеу → Шымбулак','Комби-1','Комби-2'];
    const points=lift.geometry;
    // Each surveyed OSM support gets its own height. Intervening spans sag
    // gently but remain above the DEM even where a coarse terrain ridge rises.
    const supports=points.map(p=>geo(p.lon,p.lat,.24));
    const samples=[];
    for(let i=1;i<supports.length;i++){
      const a=supports[i-1],b=supports[i];
      for(let j=0;j<16;j++){
        const t=j/16,p=a.clone().lerp(b,t),lon=points[i-1].lon+(points[i].lon-points[i-1].lon)*t,lat=points[i-1].lat+(points[i].lat-points[i-1].lat)*t;
        p.y=Math.max(p.y-Math.sin(t*Math.PI)*.025,geo(lon,lat).y+.20);samples.push(p);
      }
    }samples.push(supports.at(-1));
    const curve=new THREE.CurvePath();for(let i=1;i<samples.length;i++)curve.add(new THREE.LineCurve3(samples[i-1],samples[i]));
    const tangent=supports.at(-1).clone().sub(supports[0]);tangent.y=0;tangent.normalize();const side=new THREE.Vector3(-tangent.z,0,tangent.x).multiplyScalar(.038);
    for(const sign of [-1,1]){
      const path=samples.map(p=>p.clone().addScaledVector(side,sign));
      const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints(path),new THREE.LineBasicMaterial({color:'#314841'}));scene.add(line);
    }
    supports.forEach((p,i)=>{
      const foot=geo(points[i].lon,points[i].lat);beam(scene,foot,p,.012,dark);beam(scene,p.clone().addScaledVector(side,-1.6),p.clone().addScaledVector(side,1.6),.013,dark);
    });
    const count=index===0?14:8;
    for(let i=0;i<count;i++){
      const gondola=new THREE.Group();
      box(gondola,index===2?gold:roof,0,-.052,0,.065,.059,.060);
      box(gondola,dark,0,-.033,0,.068,.028,.062);
      box(gondola,ivory,0,-.012,0,.073,.011,.067);
      box(gondola,dark,0,.003,0,.009,.025,.009);
      scene.add(gondola);animations.push({gondola,curve,side,phase:i/count,duration:index===0?70:42});
    }
    const labelPoint=curve.getPoint(.55);labelPoint.y+=.16;
    addLabel({id:'lift-'+index,name:names[index],parent:index===0?'medeu':'shymbulak',position:labelPoint,
      description:index===0?'Канатная дорога от Медеу к базовой станции Шымбулака. Кабинки движутся в двух направлениях.':index===1?'Первая очередь: от курорта к средней станции. Здесь пересаживаются на Комби-2.':'Вторая очередь: от средней станции к Талгарскому перевалу.',distance:index===0?5:3,lift:true});
    const ends=[points[0],points.at(-1)];
    const titles=index===0?['Станция Медеу','Шымбулак · базовая станция']:index===1?['Шымбулак · Комби-1','Средняя станция']:['Средняя · Комби-2','Талгарский перевал'];
    ends.forEach((p,i)=>{
      const key=Math.round(p.lon*1000)+':'+Math.round(p.lat*1000);
      if(stations.has(key))return;stations.add(key);
      station(p,titles[i],'station-'+index+'-'+i,index===0&&i===0?'medeu':'shymbulak',i===1&&index===2?'Верхняя станция Комби-2. Обозначение курорта — 3200 м. Модели построек условные.':'Станция канатной дороги. Нажмите «Курорт», чтобы увидеть обе очереди подъёма.');
    });
  }

  // Recognisable miniature of the Medeu ice stadium.
  const rink=new THREE.Group();rink.position.copy(geo(77.05861111,43.1575,.035));rink.rotation.y=-.35;scene.add(rink);
  box(rink,ivory,0,.015,0,.40,.03,.63);
  const ice=new THREE.Mesh(new THREE.CylinderGeometry(1,1,.025,48),blue);ice.scale.set(.16,1,.27);ice.position.y=.045;rink.add(ice);
  for(let i=0;i<3;i++){
    box(rink,ivory,-.205-i*.025,.035+i*.035,0,.028,.035,.55);
    box(rink,ivory,.205+i*.025,.035+i*.035,0,.028,.035,.55);
  }
  addLabel({id:'rink',name:'Каток Медеу',parent:'medeu',position:rink.position.clone().add(new THREE.Vector3(0,.2,0)),description:'Высокогорный спортивный комплекс. Голубой овал — стилизованная модель катка, не сведения о текущем состоянии льда.',distance:2.2});

  // Small buildings at mapped resort restaurant locations; names are not
  // presented as verified current availability or opening hours.
  for(const e of context.elements.filter(e=>e.type==='node'&&e.tags?.amenity&&e.lat<43.14).filter((e,i,a)=>a.findIndex(p=>p.lon===e.lon&&p.lat===e.lat)===i)){
    const g=new THREE.Group();g.position.copy(geo(e.lon,e.lat,.03));scene.add(g);box(g,ivory,0,.035,0,.055,.07,.055);box(g,roof,0,.075,0,.065,.018,.065);
  }
  addLabel({id:'village',name:'Курортная деревня',parent:'shymbulak',position:geo(77.0804,43.1278,.25),description:'У базовой станции на карте OSM отмечены кафе и рестораны. Названия, открытие и услуги уточняйте у курорта.',distance:1.7});

  // Landmark illustrations anchored to the catalog, not invented routes.
  const falls=new THREE.Group();falls.position.copy(geo(77.113563,43.171993,.02));scene.add(falls);
  const rockMaterial=new THREE.MeshStandardMaterial({color:'#8d9f95',flatShading:true,roughness:1});
  for(const [x,y,z,s] of [[-.10,.11,0,.20],[.09,.15,.04,.23],[0,.28,.04,.12]]){
    const stone=new THREE.Mesh(new THREE.DodecahedronGeometry(s,0),rockMaterial);stone.position.set(x,y,z);stone.scale.set(1,1.3,.7);falls.add(stone);
  }
  const waterFall=box(falls,blue,0,.19,-.14,.075,.34,.025);
  const droplets=new THREE.InstancedMesh(new THREE.SphereGeometry(.009,5,4),new THREE.MeshBasicMaterial({color:'#d2fbff'}),18);falls.add(droplets);
  addLabel({id:'falls',name:'Каскад воды',parent:'butakovka',position:falls.position.clone().add(new THREE.Vector3(0,.5,0)),description:'Анимированная иллюстрация Бутаковского водопада у точки съёмки из каталога. Форма каскада и масштаб условные.',distance:1.6});
  addLabel({id:'meadow',name:'Поляна Кок-Жайляу',parent:'kok',position:geo(77.00399,43.14284194,.27),description:'Открытые поляны среди горных склонов. Зелёные группы елей — декоративное обозначение леса; жёлтая линия остаётся демонстрационным треком.',distance:3});
  addLabel({id:'lake',name:'Чаша озера',parent:'bao',position:geo(76.985,43.0506,.28),description:'Большое Алматинское озеро. Береговая линия из OpenStreetMap; оттенок и движение воды стилизованы.',distance:3.4});
  return {
    update(seconds,motion){
      for(const a of animations){
        const t=(a.phase+(motion?seconds/a.duration:0))%1,up=t<.5,f=up?t*2:(1-t)*2;
        a.gondola.position.copy(a.curve.getPoint(f)).addScaledVector(a.side,up?1:-1);
        const d=a.curve.getTangent(f);a.gondola.rotation.y=Math.atan2(d.x,d.z);
      }
      for(let i=0;i<18;i++){
        const t=(i/18+(motion?seconds*.7:0))%1;
        dummy.position.set(Math.sin(i*17)*.025,.35-t*.31,-.16);dummy.scale.setScalar(.6+Math.sin(i)*.2);dummy.updateMatrix();droplets.setMatrixAt(i,dummy.matrix);
      }droplets.instanceMatrix.needsUpdate=true;
      waterFall.material.emissive.setRGB(0,motion?.03+.01*Math.sin(seconds*2):.03,.04);
    },
    stats:{buildings:bakedModel?3704:buildings.length,trees:bakedModel?1250:treePositions.length,cabins:animations.length,lifts:lifts.length}
  };
}
