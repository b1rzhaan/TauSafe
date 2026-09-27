import json, pathlib, urllib.parse, urllib.request, io, re
from PIL import Image
ROOT=pathlib.Path('assets')
def api(host, params):
    url=f'https://{host}/w/api.php?'+urllib.parse.urlencode(dict(format='json',**params))
    return json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'TauSafe-MVP/0.1 (educational prototype)'}),timeout=30))
specs=[
 ('medeu','Medeu','Медеу','Спорткомплекс','Высокогорный каток в Малоалматинском ущелье.','https://parkmedeu.kz/o-nas/obshchaya-informatsiya?id=30&view=category'),
 ('shymbulak','Shymbulak','Шымбулак','Курорт','Горный курорт над Медеу, связанный с ним канатной дорогой.','https://shymbulak.com/info/?contactTab=address'),
 ('butakovka','Бутаковский водопад','Бутаковский водопад','Водопад','Водопад в Бутаковском ущелье. Состояние подходов требует проверки перед выходом.','https://parkmedeu.kz/o-nas/obshchaya-informatsiya?id=30&view=category'),
 ('kok','Kok Zhailau','Кок-Жайляу','Урочище','Горное урочище с открытыми полянами и видами на Заилийский Алатау.','https://visitalmaty.kz/activity/kok-zhajlyau/'),
 ('bao','Big Almaty Lake','Большое Алматинское озеро','Озеро','Высокогорное озеро в Большом Алматинском ущелье.','https://mountain.visitalmaty.kz/')]
places=[]
for id,title,name,kind,desc,source in specs:
    host='ru.wikipedia.org' if id=='butakovka' else 'en.wikipedia.org'
    raw=api(host,dict(action='query',titles=title,prop='coordinates|pageimages',pithumbsize=1000,redirects=1))
    page=next(iter(raw['query']['pages'].values()))
    coord=next(iter(page.get('coordinates',[])),{})
    photo={}
    if 'pageimage' in page:
        data=api('commons.wikimedia.org',dict(action='query',titles='File:'+page['pageimage'],prop='imageinfo',iiprop='url|extmetadata',iiurlwidth=1000))
        info=next(iter(data['query']['pages'].values()))['imageinfo'][0]
        meta=info['extmetadata']
        photo=dict(page=info['descriptionurl'],author=re.sub('<[^>]+>','',meta.get('Artist',{}).get('value','')),license=meta.get('LicenseShortName',{}).get('value',''),licenseUrl=meta.get('LicenseUrl',{}).get('value',''))
        url=info.get('thumburl',info['url'])
        image=Image.open(io.BytesIO(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'TauSafe-MVP/0.1'}),timeout=45).read())).convert('RGB')
        image.thumbnail((1200,1200)); image.save(ROOT/'images'/f'{id}.jpg',quality=85)
    places.append(dict(id=id,name=name,kind=kind,description=desc,lat=coord.get('lat'),lon=coord.get('lon'),source=source,coordinateSource=f'https://{host}/wiki/'+urllib.parse.quote(title),photo=photo,image=f'assets/images/{id}.jpg' if photo else '',checked='2026-09-26',region='Заилийский Алатау • Алматы',altitude=None))
    print(id,coord,photo.get('license'),flush=True)
(ROOT/'data'/'places.json').write_text(json.dumps(places,ensure_ascii=False,indent=2),encoding='utf-8')
