import urllib.request,urllib.parse,pathlib
query='[out:json];relation["natural"="water"](around:2000,43.0506,76.985);out geom;'
url='https://overpass-api.de/api/interpreter?'+urllib.parse.urlencode({'data':query})
raw=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'TauSafe-MVP/0.1'}),timeout=40).read()
pathlib.Path('assets/data/water.json').write_bytes(raw)
print(raw[:300])
