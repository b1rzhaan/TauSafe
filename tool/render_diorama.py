"""Render a QA frame from the exported GLB itself."""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/almaty_diorama.glb'))

world=bpy.data.worlds.new('TauSafe sky')
bpy.context.scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(0.72,0.84,0.86,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7

def point_at(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

bpy.ops.object.light_add(type='SUN',location=(-12,-8,25))
bpy.context.object.data.energy=2.1
bpy.context.object.rotation_euler=(math.radians(24),math.radians(-22),math.radians(-32))
bpy.ops.object.light_add(type='AREA',location=(16,18,24))
bpy.context.object.data.energy=1200
bpy.context.object.data.shape='DISK'
bpy.context.object.data.size=18
point_at(bpy.context.object,(0,0,2))

bpy.ops.object.camera_add(location=(5,31,15))
camera=bpy.context.object
camera.data.lens=58
point_at(camera,(-4.5,7.5,1.1))
bpy.context.scene.camera=camera

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.render.resolution_x=1280
scene.render.resolution_y=760
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT.parents[1]/'work/diorama-city-preview.png')
scene.render.film_transparent=False
scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.render.render(write_still=True)
print('Rendered',scene.render.filepath)
