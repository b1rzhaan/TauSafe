"""Render a QA overview from the complete editable Blender scene."""
from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT.parents[1] / "work"


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


world = bpy.data.worlds.get("TauSafe QA sky") or bpy.data.worlds.new("TauSafe QA sky")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.72, .84, .86, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .7

bpy.ops.object.light_add(type="SUN", location=(-12, -8, 25))
bpy.context.object.data.energy = 2.2
bpy.context.object.rotation_euler = (math.radians(24), math.radians(-22), math.radians(-32))
bpy.ops.object.light_add(type="AREA", location=(18, 20, 28))
bpy.context.object.data.energy = 1400
bpy.context.object.data.shape = "DISK"
bpy.context.object.data.size = 20
point_at(bpy.context.object, (0, 0, 2))

bpy.ops.object.camera_add(location=(25, 37, 31))
camera = bpy.context.object
camera.data.lens = 54
point_at(camera, (0, 0, 1.7))
bpy.context.scene.camera = camera

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 1280
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(WORK / "diorama-full-editable-preview.png")
scene.render.film_transparent = False
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)
print("Rendered", scene.render.filepath)
