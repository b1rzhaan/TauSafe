"""Snapshot OSM geometry for the offline diorama; no live operating status."""
import json, pathlib, urllib.parse, urllib.request, sys
sys.stdout.reconfigure(encoding='utf-8')

query = '''[out:json][timeout:120];(
way["aerialway"~"gondola|mixed_lift|chair_lift|cable_car"](43.06,77.03,43.18,77.13);
way["highway"~"^(primary|secondary|tertiary)$"](43.025,76.90,43.265,77.16);
way["waterway"="river"](43.025,76.90,43.265,77.16);
way["building"](43.23,76.93,43.255,76.975);
nwr["amenity"~"restaurant|cafe"]["name"](43.10,77.07,43.135,77.10);
);out geom;'''
request = urllib.request.Request('https://overpass-api.de/api/interpreter',
    data=urllib.parse.urlencode({'data':query}).encode(),
    headers={'User-Agent':'TauSafe-hackathon-offline-demo/1.0'})
data=json.load(urllib.request.urlopen(request, timeout=150))
data['source']='© OpenStreetMap contributors, ODbL 1.0'
data['downloaded']='2026-09-26'
keys={'name','name:ru','aerialway','building','building:levels','highway','waterway','amenity'}
for e in data['elements']:
    e['tags']={k:v for k,v in e.get('tags',{}).items() if k in keys}
    for k in list(e):
        if k not in {'type','id','lat','lon','tags','geometry'}:del e[k]
data['elements']=[e for e in data['elements'] if e['type']!='relation']
pathlib.Path('assets/data/context.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
for e in data['elements']:
    if e.get('tags',{}).get('aerialway'):
        print(e['id'],e['tags'],e['geometry'][0],e['geometry'][-1])
print('Saved',len(data['elements']),'features')
