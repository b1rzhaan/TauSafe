"""Add the app's location miniatures to the editable Blender scene.

The phone build creates these objects at runtime so the cabins can move.  The
editable deliverable also needs physical copies that can be selected and
changed in Blender, therefore this module creates a complete static scene after
the lightweight runtime GLB has already been exported.
"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector


def add_editable_landmarks(*, xyz, context, water):
    scene_root = bpy.context.scene.collection

    def collection(name, parent=scene_root):
        result = bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if not any(child == result for child in parent.children):
            parent.children.link(result)
        return result

    landmarks = collection("LANDMARKS - editable objects")
    cableways = collection("CABLEWAYS - editable objects")

    def color_material(name, color, roughness=.8, metallic=0.0):
        existing = bpy.data.materials.get(name)
        if existing:
            return existing
        rgba = tuple(int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)) + (1.0,)
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = rgba
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        return mat

    ivory = color_material("Landmark ivory", "#f6eee0")
    roof = color_material("Landmark roofs", "#bf674a")
    dark = color_material("Cable dark", "#254c52", .45)
    blue = color_material("Landmark water", "#5ebdcc", .3, .08)
    gold = color_material("Landmark gold", "#edb547", .5)
    meadow = color_material("Kok Zhailau meadow", "#8aaa5a", .95)
    rock = color_material("Butakovka rock", "#899990", 1.0)

    def relink(obj, target):
        for owner in tuple(obj.users_collection):
            owner.objects.unlink(obj)
        target.objects.link(obj)
        return obj

    def empty(name, location, target):
        obj = bpy.data.objects.new(name, None)
        obj.empty_display_type = "SPHERE"
        obj.empty_display_size = .12
        obj.location = location
        target.objects.link(obj)
        return obj

    def cube(name, parent, location, dimensions, material, target):
        bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0))
        obj = relink(bpy.context.object, target)
        obj.name = name
        obj.parent = parent
        obj.location = location
        obj.dimensions = dimensions
        obj.data.materials.append(material)
        bevel = obj.modifiers.new("Soft edges", "BEVEL")
        bevel.width, bevel.segments = min(dimensions) * .08, 2
        return obj

    def cylinder(name, parent, location, radius, depth, material, target, vertices=24):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0, 0, 0))
        obj = relink(bpy.context.object, target)
        obj.name = name
        obj.parent = parent
        obj.location = location
        obj.data.materials.append(material)
        return obj

    def sphere(name, parent, location, radius, scale, material, target):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=(0, 0, 0))
        obj = relink(bpy.context.object, target)
        obj.name = name
        obj.parent = parent
        obj.location = location
        obj.scale = scale
        obj.data.materials.append(material)
        return obj

    def beam(name, a, b, radius, material, target, parent=None):
        a, b = Vector(a), Vector(b)
        direction = b - a
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=direction.length, location=(a + b) / 2)
        obj = relink(bpy.context.object, target)
        obj.name = name
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
        obj.data.materials.append(material)
        obj.parent = parent
        return obj

    def curve(name, points, material, target, bevel=.008):
        data = bpy.data.curves.new(name, "CURVE")
        data.dimensions = "3D"
        data.resolution_u = 2
        data.bevel_depth = bevel
        data.bevel_resolution = 2
        spline = data.splines.new("POLY")
        spline.points.add(len(points) - 1)
        for item, point in zip(spline.points, points):
            item.co = (*point, 1)
        obj = bpy.data.objects.new(name, data)
        data.materials.append(material)
        target.objects.link(obj)
        return obj

    # Medeu ice stadium.
    medeu_coll = collection("Medeu stadium", landmarks)
    medeu = empty("LANDMARK - Medeu", xyz(77.05861111, 43.1575, .035), medeu_coll)
    medeu.rotation_euler.z = -.35
    cylinder("Medeu ice rink", medeu, (0, 0, .025), 1, .025, blue, medeu_coll, 48).scale = (.16, .27, 1)
    for side in (-1, 1):
        for row in range(3):
            cube(
                f"Medeu stand {side:+d}-{row + 1}", medeu,
                (side * (.205 + row * .027), 0, .035 + row * .035),
                (.026, .56, .035), ivory, medeu_coll,
            )
    cube("Medeu entrance", medeu, (0, -.33, .075), (.22, .08, .15), ivory, medeu_coll)
    cube("Medeu entrance roof", medeu, (0, -.33, .16), (.27, .10, .025), roof, medeu_coll)

    # Shymbulak resort village.
    shym_coll = collection("Shymbulak resort", landmarks)
    shym = empty("LANDMARK - Shymbulak", xyz(77.08083333, 43.12805556, .03), shym_coll)
    for i, (x, y, sx, sy, h) in enumerate([
        (0, 0, .34, .22, .18), (-.27, .12, .18, .15, .12),
        (.28, .10, .20, .16, .14), (-.18, -.20, .16, .13, .11), (.20, -.18, .16, .13, .11),
    ]):
        cube(f"Shymbulak building {i + 1}", shym, (x, y, h / 2), (sx, sy, h), ivory, shym_coll)
        cube(f"Shymbulak roof {i + 1}", shym, (x, y, h + .018), (sx * 1.1, sy * 1.1, .035), roof, shym_coll)

    # Butakovka waterfall with rocks, water curtain and pool.
    falls_coll = collection("Butakovka waterfall", landmarks)
    falls = empty("LANDMARK - Butakovka waterfall", xyz(77.113563, 43.171993, .02), falls_coll)
    for i, (x, y, z, size) in enumerate([(-.12, 0, .14, .19), (.11, .03, .18, .23), (0, .05, .31, .14)]):
        sphere(f"Butakovka rock {i + 1}", falls, (x, y, z), size, (1, .75, 1.35), rock, falls_coll)
    cube("Butakovka water curtain", falls, (0, -.14, .20), (.075, .025, .34), blue, falls_coll)
    cylinder("Butakovka pool", falls, (0, -.15, .018), .16, .018, blue, falls_coll, 36).scale = (1.35, .7, 1)

    # Kok Zhailau meadow and a small camp symbol.
    kok_coll = collection("Kok Zhailau", landmarks)
    kok = empty("LANDMARK - Kok Zhailau", xyz(77.00399, 43.14284194, .025), kok_coll)
    cylinder("Kok Zhailau meadow", kok, (0, 0, .012), .28, .024, meadow, kok_coll, 40).scale = (1.6, 1, 1)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=.085, radius2=0, depth=.12, location=(0, 0, 0))
    tent = relink(bpy.context.object, kok_coll)
    tent.name = "Kok Zhailau tent"
    tent.parent = kok
    tent.location = (0, 0, .075)
    tent.rotation_euler.z = math.radians(45)
    tent.data.materials.append(gold)

    # Accurate lake outline from the same OSM relation used by the app.
    lake_coll = collection("Big Almaty Lake", landmarks)
    pending = [list(member["geometry"]) for relation in water.get("elements", [])
               for member in relation.get("members", [])
               if member.get("role") == "outer" and len(member.get("geometry", [])) >= 2]
    same = lambda a, b: a["lon"] == b["lon"] and a["lat"] == b["lat"]
    lake_index = 0
    while pending:
        ring = pending.pop(0)
        while not same(ring[0], ring[-1]) and pending:
            last = ring[-1]
            match = next((i for i, segment in enumerate(pending)
                          if same(segment[0], last) or same(segment[-1], last)), -1)
            if match < 0:
                break
            segment = pending.pop(match)
            if same(segment[-1], last):
                segment.reverse()
            ring.extend(segment[1:])
        if len(ring) < 4 or not same(ring[0], ring[-1]):
            continue
        vertices = [xyz(point["lon"], point["lat"], .035) for point in ring[:-1]]
        mesh = bpy.data.meshes.new(f"Big Almaty Lake mesh {lake_index + 1}")
        mesh.from_pydata(vertices, [], [tuple(range(len(vertices)))])
        mesh.materials.append(blue)
        lake = bpy.data.objects.new("LANDMARK - Big Almaty Lake", mesh)
        lake_coll.objects.link(lake)
        lake_index += 1

    # Three surveyed cableways, their supports, stations and editable cabins.
    lift_order = [171467770, 173568370, 167106523]
    lift_names = ["Medeu - Shymbulak", "Combi 1", "Combi 2"]
    lift_elements = {element.get("id"): element for element in context.get("elements", [])}

    def sample_polyline(points, fraction):
        distances = [(points[i] - points[i - 1]).length for i in range(1, len(points))]
        total = sum(distances)
        wanted = fraction * total
        for i, length in enumerate(distances, 1):
            if wanted <= length:
                return points[i - 1].lerp(points[i], wanted / max(length, 1e-6))
            wanted -= length
        return points[-1].copy()

    for lift_index, lift_id in enumerate(lift_order):
        lift = lift_elements.get(lift_id)
        if not lift or not lift.get("geometry"):
            continue
        lift_coll = collection(f"Cableway {lift_names[lift_index]}", cableways)
        geographic = lift["geometry"]
        supports = [Vector(xyz(point["lon"], point["lat"], .24)) for point in geographic]
        tangent = supports[-1] - supports[0]
        tangent.z = 0
        tangent.normalize()
        side = Vector((-tangent.y, tangent.x, 0)) * .038
        curve(f"Cable {lift_names[lift_index]} A", [point + side for point in supports], dark, lift_coll)
        curve(f"Cable {lift_names[lift_index]} B", [point - side for point in supports], dark, lift_coll)
        for i, (point, top) in enumerate(zip(geographic, supports)):
            foot = Vector(xyz(point["lon"], point["lat"], .015))
            beam(f"{lift_names[lift_index]} support {i + 1}", foot, top, .012, dark, lift_coll)
            beam(f"{lift_names[lift_index]} crossbar {i + 1}", top - side * 1.6, top + side * 1.6, .013, dark, lift_coll)
        for end_index, point in enumerate((geographic[0], geographic[-1])):
            station_coll = lift_coll
            station = empty(
                f"Station {lift_names[lift_index]} {end_index + 1}",
                xyz(point["lon"], point["lat"], .04), station_coll,
            )
            cube(f"Station building {lift_names[lift_index]} {end_index + 1}", station, (0, 0, .095), (.30, .20, .19), ivory, station_coll)
            cube(f"Station roof {lift_names[lift_index]} {end_index + 1}", station, (0, 0, .205), (.34, .24, .035), roof, station_coll)
        for cabin_index in range(8 if lift_index == 0 else 6):
            fraction = (cabin_index + .5) / (8 if lift_index == 0 else 6)
            point = sample_polyline(supports, fraction) + side * (1 if cabin_index % 2 else -1)
            cabin = empty(f"Gondola {lift_names[lift_index]} {cabin_index + 1}", point, lift_coll)
            body_mat = gold if lift_index == 2 else roof
            cube(f"Cabin body {lift_names[lift_index]} {cabin_index + 1}", cabin, (0, 0, -.045), (.065, .060, .059), body_mat, lift_coll)
            cube(f"Cabin window {lift_names[lift_index]} {cabin_index + 1}", cabin, (0, 0, -.018), (.068, .062, .028), dark, lift_coll)
            cube(f"Cabin hanger {lift_names[lift_index]} {cabin_index + 1}", cabin, (0, 0, .010), (.010, .010, .045), dark, lift_coll)

    bpy.context.scene["editable_landmarks"] = (
        "Medeu, Shymbulak, Butakovka waterfall, Kok Zhailau, Big Almaty Lake, "
        "Medeu-Shymbulak cableway, Combi 1 and Combi 2"
    )

