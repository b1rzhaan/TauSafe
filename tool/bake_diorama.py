"""Bake the offline geographic data into the visible GLB diorama.

The Flutter/Three.js app keeps small JSON datasets only for coordinates and
interactions. Terrain, city blocks, roads and decorative forest are exported
once from Blender and are no longer constructed in the phone at runtime.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
TERRAIN = json.loads((ROOT / "assets/terrain/almaty.json").read_text(encoding="utf-8"))
CONTEXT = json.loads((ROOT / "assets/data/context.json").read_text(encoding="utf-8"))
OUTPUT = ROOT / "assets/models/almaty_diorama.glb"
FULL_OUTPUT = ROOT / "assets/models/almaty_diorama_full.glb"
EDITABLE_OUTPUT = ROOT / "assets/models/almaty_diorama_editable.blend"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

BASE = 700.0
EXAGGERATION = 1.65
CX = (TERRAIN["west"] + TERRAIN["east"]) / 2
CY = (TERRAIN["south"] + TERRAIN["north"]) / 2
CITY_LON, CITY_LAT = 76.953, 43.246
CITY_AREA_SCALE = 1.40
CITY_BUILDING_SCALE = 1.25


def altitude(lon: float, lat: float) -> float:
    n = TERRAIN["width"]
    x = max(0.0, min(n - 1.0, (lon - TERRAIN["west"]) / (TERRAIN["east"] - TERRAIN["west"]) * (n - 1)))
    y = max(0.0, min(n - 1.0, (TERRAIN["north"] - lat) / (TERRAIN["north"] - TERRAIN["south"]) * (n - 1)))
    i, j = min(n - 2, int(x)), min(n - 2, int(y))
    fx, fy = x - i, y - j
    h = TERRAIN["heights"]
    a = h[j * n + i] * (1 - fx) + h[j * n + i + 1] * fx
    b = h[(j + 1) * n + i] * (1 - fx) + h[(j + 1) * n + i + 1] * fx
    return a * (1 - fy) + b * fy


def xyz(lon: float, lat: float, offset: float = 0.0) -> tuple[float, float, float]:
    # Blender uses Z-up. glTF conversion maps this to Three.js Y-up while
    # preserving the coordinate system used by viewer.js.
    x = (lon - CX) * 81.2
    y = (lat - CY) * 111.195
    z = (altitude(lon, lat) - BASE) / 1000 * EXAGGERATION + offset
    return x, y, z


def material(name: str, color: str, roughness: float = 0.88):
    value = tuple(int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)) + (1.0,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = value
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = value
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def mesh_object(name: str, vertices, faces, mats, indices=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for mat in mats:
        mesh.materials.append(mat)
    if indices:
        for polygon, index in zip(mesh.polygons, indices):
            polygon.material_index = index
    return obj


for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

terrain_mats = [
    material("Lowland sand", "#aebe91"),
    material("Forest green", "#43845f"),
    material("Alpine meadow", "#9caf68"),
    material("Mountain stone", "#8f9a98"),
    material("Snow", "#edf3f1", 0.72),
]
base_mat = material("Cut earth", "#7d7160")
plinth_mat = material("Diorama plinth", "#c9b58e")
road_mat = material("Warm roads", "#ead8b6")
river_mat = material("Mountain water", "#50b9c8", 0.38)
city_mats = [material("City ivory", "#f2e8d2"), material("City sage", "#aabfba"), material("City ochre", "#d4b67d")]
tree_mats = [material("Spruce deep", "#245d49"), material("Spruce light", "#39785a")]

# Smooth, moderately dense terrain instead of a faceted runtime grid.
size = 121
vertices = []
height_values = []
for j in range(size):
    lat = TERRAIN["north"] - (TERRAIN["north"] - TERRAIN["south"]) * j / (size - 1)
    for i in range(size):
        lon = TERRAIN["west"] + (TERRAIN["east"] - TERRAIN["west"]) * i / (size - 1)
        point = xyz(lon, lat)
        vertices.append(point)
        height_values.append(altitude(lon, lat))
faces, indices = [], []
for j in range(size - 1):
    for i in range(size - 1):
        a = j * size + i
        face = (a, a + size, a + size + 1, a + 1)
        faces.append(face)
        average = sum(height_values[p] for p in face) / 4
        indices.append(0 if average < 1250 else 1 if average < 2400 else 2 if average < 3100 else 3 if average < 3450 else 4)
terrain_obj = mesh_object("Sculpted terrain", vertices, faces, terrain_mats, indices)
for polygon in terrain_obj.data.polygons:
    polygon.use_smooth = True
terrain_obj["data_source"] = "Mapzen Terrain Tiles / AWS Open Data"
terrain_obj["height_exaggeration"] = EXAGGERATION

# A rounded plinth makes the bounded map read as a physical exhibit.
width = (TERRAIN["east"] - TERRAIN["west"]) * 81.2
depth = (TERRAIN["north"] - TERRAIN["south"]) * 111.195
bpy.ops.mesh.primitive_cube_add(location=(0, 0, -0.33), scale=(width / 2 + .10, depth / 2 + .10, .12))
plinth = bpy.context.object
plinth.name = "Rounded diorama base"
plinth.data.materials.append(plinth_mat)
bevel = plinth.modifiers.new("Softened corners", "BEVEL")
bevel.width, bevel.segments = .12, 4

# City buildings are simplified solids baked into a few material groups.
building_vertices, building_faces, building_indices = [], [], []
buildings = [e for e in CONTEXT["elements"] if e.get("tags", {}).get("building") and len(e.get("geometry", [])) > 3]
for index, building in enumerate(buildings):
    ring = building["geometry"][:-1]
    lon = sum(p["lon"] for p in ring) / len(ring)
    lat = sum(p["lat"] for p in ring) / len(ring)
    lon = CITY_LON + (lon - CITY_LON) * CITY_AREA_SCALE
    lat = CITY_LAT + (lat - CITY_LAT) * CITY_AREA_SCALE
    sx = max(.032, (max(p["lon"] for p in ring) - min(p["lon"] for p in ring)) * 81.2 * CITY_BUILDING_SCALE)
    sy = max(.032, (max(p["lat"] for p in ring) - min(p["lat"] for p in ring)) * 111.195 * CITY_BUILDING_SCALE)
    levels = float(building.get("tags", {}).get("building:levels", 3) or 3)
    height = max(.06, min(.34, levels * .025))
    x, y, z = xyz(lon, lat, .018)
    start = len(building_vertices)
    for dx, dy, dz in [(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
        building_vertices.append((x + dx * sx / 2, y + dy * sy / 2, z + dz * height))
    for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
        building_faces.append(tuple(start + p for p in face))
        building_indices.append(2 if index % 7 == 0 else 1 if index % 4 == 0 else 0)
city = mesh_object("Almaty city blocks", building_vertices, building_faces, city_mats, building_indices)
city["data_source"] = "OpenStreetMap contributors, ODbL"
city["display_scale"] = "City area ×1.40; building footprints ×1.25; heights enlarged for readability"


def ribbons(tag: str, value: str | None, width_value: float, z_offset: float):
    verts, fs = [], []
    for element in CONTEXT["elements"]:
        tags = element.get("tags", {})
        if tag not in tags or (value is not None and tags[tag] != value):
            continue
        points = element.get("geometry", [])
        for a, b in zip(points, points[1:]):
            ax, ay, az = xyz(a["lon"], a["lat"], z_offset)
            bx, by, bz = xyz(b["lon"], b["lat"], z_offset)
            length = math.hypot(bx - ax, by - ay)
            if not length:
                continue
            nx, ny = -(by - ay) / length * width_value / 2, (bx - ax) / length * width_value / 2
            start = len(verts)
            verts.extend([(ax+nx,ay+ny,az),(ax-nx,ay-ny,az),(bx-nx,by-ny,bz),(bx+nx,by+ny,bz)])
            fs.append((start, start+3, start+2, start+1))
    return verts, fs


road_vertices, road_faces = ribbons("highway", None, .030, .028)
road = mesh_object("Road network", road_vertices, road_faces, [road_mat])
river_vertices, river_faces = ribbons("waterway", "river", .038, .040)
river = mesh_object("Mountain rivers", river_vertices, river_faces, [river_mat])
road["data_source"] = river["data_source"] = "OpenStreetMap contributors, ODbL"

# Decorative tree clusters. They are a visual cue, not a surveyed tree layer.
random.seed(347)
tree_vertices, tree_faces, tree_indices = [], [], []
trees = []
for _ in range(7000):
    if len(trees) >= 1250:
        break
    lon = TERRAIN["west"] + random.random() * (TERRAIN["east"] - TERRAIN["west"])
    lat = 43.065 + random.random() * .166
    height = altitude(lon, lat)
    if not 1350 < height < 2850 or abs(altitude(lon + .0005, lat) - altitude(lon - .0005, lat)) > 85:
        continue
    if math.sin(lon * 240) * math.cos(lat * 185) < -.1:
        continue
    if 77.075 < lon < 77.115 and 43.109 < lat < 43.13:
        continue
    trees.append((lon, lat, .72 + random.random() * .72))
for index, (lon, lat, scale) in enumerate(trees):
    x, y, z = xyz(lon, lat, .015)
    start = len(tree_vertices)
    segments, radius, height = 6, .050 * scale, .20 * scale
    tree_vertices.append((x, y, z + height))
    for n in range(segments):
        angle = n / segments * math.tau
        tree_vertices.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius, z))
    for n in range(segments):
        tree_faces.append((start, start + 1 + n, start + 1 + (n + 1) % segments))
        tree_indices.append(index % 3 == 0)
forest = mesh_object("Stylised alpine forest", tree_vertices, tree_faces, tree_mats, tree_indices)
forest["note"] = "Decorative distribution; not an inventory of real trees"

# Export only the baked display layer. Animated lifts and place-specific props
# remain interactive Three.js objects above this model.
for obj in bpy.context.scene.objects:
    obj.select_set(True)
bpy.context.scene["license"] = "Terrain attribution and OSM ODbL details are shown in DATA_SOURCES.md"
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True)

# The app adds these detailed objects at runtime so its cabins can move.  The
# editable deliverable also receives physical copies for normal Blender work.
import sys
sys.path.insert(0, str(ROOT / "tool"))
from editable_landmarks import add_editable_landmarks

WATER = json.loads((ROOT / "assets/data/water.json").read_text(encoding="utf-8"))
add_editable_landmarks(xyz=xyz, context=CONTEXT, water=WATER)
bpy.ops.export_scene.gltf(filepath=str(FULL_OUTPUT), export_format="GLB", export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(EDITABLE_OUTPUT), compress=True)
print(
    f"Saved runtime {OUTPUT} ({OUTPUT.stat().st_size:,} bytes), "
    f"full {FULL_OUTPUT} ({FULL_OUTPUT.stat().st_size:,} bytes) and "
    f"{EDITABLE_OUTPUT} ({EDITABLE_OUTPUT.stat().st_size:,} bytes), "
    f"buildings={len(buildings)}, trees={len(trees)}"
)
