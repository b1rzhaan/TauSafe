import io,json,pathlib,urllib.request,urllib.parse,re
from PIL import Image
def get(url):return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'TauSafe-MVP/0.1 (educational prototype)'}),timeout=40).read()
params=dict(action='query',format='json',pageids='119401909',prop='imageinfo',iiprop='url|extmetadata',iiurlwidth=1000)
raw=json.loads(get('https://commons.wikimedia.org/w/api.php?'+urllib.parse.urlencode(params)))
info=next(iter(raw['query']['pages'].values()))['imageinfo'][0];meta=info['extmetadata']
image=Image.open(io.BytesIO(get(info.get('thumburl',info['url'])))).convert('RGB');image.thumbnail((1200,1200));image.save('assets/images/butakovka.jpg',quality=85)
path=pathlib.Path('assets/data/places.json');places=json.loads(path.read_text(encoding='utf-8'));p=next(p for p in places if p['id']=='butakovka')
p['image']='assets/images/butakovka.jpg';p['photo']=dict(page=info['descriptionurl'],author=re.sub('<[^>]+>','',meta.get('Artist',{}).get('value','')),license=meta.get('LicenseShortName',{}).get('value',''),licenseUrl=meta.get('LicenseUrl',{}).get('value',''))
p['lat']=float(meta['GPSLatitude']['value']);p['lon']=float(meta['GPSLongitude']['value']);p['coordinateSource']=info['descriptionurl'];p['coordinateNote']='Точка съёмки фотографии у водопада, не подтверждённая точка старта.'
print(p['photo']);print('Location metadata',[(k,v) for k,v in meta.items() if 'GPS' in k or 'Location' in k])
path.write_text(json.dumps(places,ensure_ascii=False,indent=2),encoding='utf-8')
fonts=pathlib.Path('assets/fonts');fonts.mkdir(exist_ok=True)
for name in ['manrope','notosans']:
 title='Manrope' if name=='manrope' else 'NotoSans'
 filename=title+('[wght]' if name=='manrope' else '[wdth,wght]')+'.ttf'
 base=f'https://raw.githubusercontent.com/google/fonts/main/ofl/{name}/'
 (fonts/(title+'.ttf')).write_bytes(get(base+urllib.parse.quote(filename)))
 (fonts/(title+'-OFL.txt')).write_bytes(get(base+'OFL.txt'))
print('Fonts saved')
