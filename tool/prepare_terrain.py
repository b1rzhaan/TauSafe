"""Download a bounded DEM cutout, not map tiles. Run from project root."""
import io, json, math, pathlib, urllib.request
from PIL import Image

OUT = pathlib.Path('assets/terrain')
OUT.mkdir(parents=True, exist_ok=True)
WEST, EAST, SOUTH, NORTH = 76.90, 77.16, 43.025, 43.265
N, Z = 241, 12
cache = {}
urls = []
def pixel(lon, lat):
    x = (lon + 180) / 360 * 2**Z * 256
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * 2**Z * 256
    return x, y
def height(lon, lat):
    x, y = pixel(lon, lat)
    tx, ty = int(x)//256, int(y)//256
    key = (tx, ty)
    if key not in cache:
        url = f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{Z}/{tx}/{ty}.png'
        print(url, flush=True)
        data = urllib.request.urlopen(url, timeout=45).read()
        cache[key] = Image.open(io.BytesIO(data)).convert('RGB')
        urls.append(url)
    r,g,b = cache[key].getpixel((int(x)%256, int(y)%256))
    return round(r*256 + g + b/256 - 32768, 1)
heights = [height(WEST+(EAST-WEST)*i/(N-1), NORTH-(NORTH-SOUTH)*j/(N-1)) for j in range(N) for i in range(N)]
data = dict(width=N, height=N, west=WEST, east=EAST, south=SOUTH, north=NORTH,
            heights=heights, source='Mapzen Terrain Tiles / AWS Open Data',
            attribution='SRTM, USGS, GMTED2010, ETOPO1; Mapzen / AWS Open Data',
            downloaded='2026-09-26', tileUrls=urls)
(OUT/'almaty.json').write_text(json.dumps(data, separators=(',',':')), encoding='utf-8')
print('Saved', len(heights), 'samples; range', min(heights), max(heights))
