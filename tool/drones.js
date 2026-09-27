import * as THREE from 'three';

// Visible-scale demonstrator, not a flight controller or real telemetry.
export function buildDrones(scene, root, geo, send) {
  const group = new THREE.Group(); group.name = 'Demo drone fleet'; scene.add(group);
  const colors = [0x36c5e5, 0xf5b85c, 0xabbcff];
  const centers = [[77.068,43.154],[77.105,43.129],[77.061,43.121]];
  const fleet = []; let searching=false, enabled=true, tick=-1, origin=[77.068,43.154];
  const lineMat = new THREE.LineDashedMaterial({color:0x4e95b4,transparent:true,opacity:.48,dashSize:.22,gapSize:.16});
  function route(i) {
    const pts=[];
    if(searching){
      for(let row=0;row<6;row++) for(let col=0;col<2;col++) {
        const side=(row%2===0?col:1-col)*2-1;
        pts.push([origin[0]+side*.012,origin[1]+(row-2.5)*.003+(i-1)*.019]);
      }
    } else {
      for(let k=0;k<=72;k++) {const a=k/72*Math.PI*2; pts.push([centers[i][0]+Math.cos(a)*.018,centers[i][1]+Math.sin(a)*.011]);}
    }
    if(searching)pts.push(pts[0]);
    return pts;
  }
  function refreshPaths(){ for(const d of fleet){
    d.path=route(d.i);
    d.trail.geometry.dispose();d.trail.geometry=new THREE.BufferGeometry().setFromPoints(d.path.map(p=>geo(...p,1.05+d.i*.15)));
    d.trail.computeLineDistances();
  }}
  for(let i=0;i<3;i++){
    const model=new THREE.Group();model.name=`Demo drone ${i+1}`;
    const body=new THREE.Mesh(new THREE.BoxGeometry(.24,.11,.35),new THREE.MeshStandardMaterial({color:0xf0f7ff,metalness:.3,roughness:.4}));model.add(body);
    const rotors=[];
    for(const x of [-1,1])for(const z of [-1,1]){
      const arm=new THREE.Mesh(new THREE.BoxGeometry(.46,.045,.045),new THREE.MeshStandardMaterial({color:0x243d52}));
      arm.rotation.y=x*z*Math.PI/4;arm.position.set(x*.14,0,z*.14);model.add(arm);
      const rotor=new THREE.Group();rotor.position.set(x*.29,.06,z*.29);
      const rim=new THREE.Mesh(new THREE.TorusGeometry(.16,.013,5,24),new THREE.MeshStandardMaterial({color:colors[i]}));rim.rotation.x=Math.PI/2;rotor.add(rim);
      const blade=new THREE.Mesh(new THREE.BoxGeometry(.29,.012,.035),new THREE.MeshStandardMaterial({color:0x344e65}));rotor.add(blade);rotors.push(blade);model.add(rotor);
    }
    const lens=new THREE.Mesh(new THREE.SphereGeometry(.07,10,8),new THREE.MeshStandardMaterial({color:colors[i],emissive:colors[i],emissiveIntensity:.35}));lens.position.set(0,-.1,-.13);model.add(lens);
    const ring=new THREE.Mesh(new THREE.RingGeometry(.50,.53,48),new THREE.MeshBasicMaterial({color:colors[i],transparent:true,opacity:.65,side:THREE.DoubleSide,depthWrite:false}));ring.rotation.x=-Math.PI/2;group.add(ring);
    const beam=new THREE.Mesh(new THREE.ConeGeometry(.50,1,24,1,true),new THREE.MeshBasicMaterial({color:colors[i],transparent:true,opacity:.075,side:THREE.DoubleSide,depthWrite:false}));group.add(beam);
    const trail=new THREE.Line(new THREE.BufferGeometry(),lineMat.clone());group.add(trail);group.add(model);
    const label=document.createElement('button');label.className='drone-pin';label.textContent=`D0${i+1}`;label.setAttribute('aria-label',`Демо-дрон ${i+1}`);root.appendChild(label);
    const d={i,model,rotors,ring,beam,trail,label,path:[],lon:0,lat:0};fleet.push(d);
    label.onclick=()=>send({type:'droneSelect',id:i});
  }
  refreshPaths();
  return {
    setMode(mode,lon,lat){searching=mode==='search';if(Number.isFinite(lon)&&Number.isFinite(lat))origin=[lon,lat];refreshPaths();tick=-1;},
    setVisible(value){enabled=value;group.visible=value;for(const d of fleet)d.label.style.display=value?'block':'none';},
    focusPosition(id){return fleet[id]?.model.position.clone();},
    update(elapsed,camera){
      if(!enabled)return;
      elapsed=Math.max(0,elapsed);
      for(const d of fleet){
        const progress=((elapsed/(searching?70:95)+d.i/3)%1)*(d.path.length-1),k=Math.floor(progress),f=progress-k;
        const a=d.path[k],b=d.path[Math.min(k+1,d.path.length-1)];
        d.lon=THREE.MathUtils.lerp(a[0],b[0],f);d.lat=THREE.MathUtils.lerp(a[1],b[1],f);
        const ground=geo(d.lon,d.lat,.12),position=geo(d.lon,d.lat,1.1+d.i*.15+Math.sin(elapsed*2+d.i)*.035);
        d.model.position.copy(position);d.model.rotation.y=Math.atan2(b[0]-a[0],-(b[1]-a[1]));
        for(const rotor of d.rotors)rotor.rotation.y=elapsed*40;
        d.ring.position.copy(ground);d.ring.scale.setScalar(1+.18*Math.sin(elapsed*2+d.i));
        d.beam.scale.y=position.y-ground.y;d.beam.position.copy(ground).lerp(position,.5);
        const v=position.clone().project(camera),x=(v.x*.5+.5)*root.clientWidth,y=(-v.y*.5+.5)*root.clientHeight;
        d.label.style.transform=`translate(${x}px,${y-22}px) translate(-50%,-100%)`;
        d.label.style.visibility=v.z>-1&&v.z<1&&x>25&&x<root.clientWidth-25&&y>120&&y<root.clientHeight-50?'visible':'hidden';
      }
      const next=Math.floor(elapsed/2);
      if(next!==tick){tick=next;send({type:'fleet',demo:true,mode:searching?'search':'patrol',drones:fleet.map(d=>({id:d.i,lon:d.lon,lat:d.lat,battery:96-d.i*7-Math.floor(elapsed/180)%12}))});}
    },
  };
}
