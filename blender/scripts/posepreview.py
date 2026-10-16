# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
import bpy, sys, math
from mathutils import Vector
name, act, frames = sys.argv[-3], sys.argv[-2], [int(x) for x in sys.argv[-1].split(",")]
bpy.ops.wm.open_mainfile(filepath=f"/home/claude/blender/out/{name}.blend")
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
a=bpy.data.actions[act]; arm.animation_data.action=a
for t in arm.animation_data.nla_tracks: t.mute=True
sc=bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.color_type='VERTEX' if False else 'TEXTURE'
sc.render.resolution_x=300; sc.render.resolution_y=420
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=3.4
for i,fr in enumerate(frames):
    for view,(loc,rot) in {"lado":((6,0,1.3),(math.pi/2,0,math.pi/2)),"frente":((0,-6,1.3),(math.pi/2,0,0))}.items():
        cam.location=loc; cam.rotation_euler=rot
        sc.frame_set(fr)
        sc.render.filepath=f"/home/claude/blender/prev/{name}_{act}_{fr}_{view}.png"
        bpy.ops.render.render(write_still=True)
