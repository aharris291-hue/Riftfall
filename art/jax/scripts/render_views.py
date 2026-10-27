"""Render preview images of a Jax .blend.

Run: python render_views.py <in.blend> <out_dir> [views] [res] [samples]
views: comma list of front,back,side,threequarter,face,hero
"""

import math
import os
import sys

import bpy
from mathutils import Vector


def setup(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.film_transparent = False
    world = sc.world or bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.020, 0.028, 0.040, 1)
    bg.inputs["Strength"].default_value = 1.0


def bounds():
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.hide_render:
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def add_light(name, loc, energy, size, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(lo)
    lo.location = loc
    return lo


def aim(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    blend, out_dir = args[0], args[1]
    views = (args[2] if len(args) > 2 else "front,back,side,threequarter,face").split(",")
    res = int(args[3]) if len(args) > 3 else 1200
    samples = int(args[4]) if len(args) > 4 else 64
    bpy.ops.wm.open_mainfile(filepath=blend)
    setup(samples)
    lo, hi = bounds()
    h = hi.z - lo.z
    mid = (lo + hi) / 2
    s = h  # scene scale (works for meters or studs)
    # Floor.
    bpy.ops.mesh.primitive_plane_add(size=s * 6, location=(mid.x, mid.y, lo.z))
    floor = bpy.context.object
    fm = bpy.data.materials.new("Floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.035, 0.045, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    floor.data.materials.append(fm)
    target = Vector((mid.x, mid.y, mid.z))
    lights = []
    lights.append(add_light("Key", (mid.x - s * 1.2, mid.y - s * 1.4, lo.z + s * 1.3), 150 * s * s / 3, s * 0.8,
                            (1.0, 0.95, 0.88)))
    lights.append(add_light("Fill", (mid.x + s * 1.5, mid.y - s * 0.8, lo.z + s * 0.7), 45 * s * s / 3, s * 1.0,
                            (0.75, 0.85, 1.0)))
    lights.append(add_light("Rim", (mid.x + s * 0.6, mid.y + s * 1.4, lo.z + s * 1.4), 140 * s * s / 3, s * 0.5,
                            (0.55, 0.8, 1.0)))
    lights.append(add_light("Rim2", (mid.x - s * 0.9, mid.y + s * 1.2, lo.z + s * 1.0), 80 * s * s / 3, s * 0.5,
                            (0.7, 0.85, 1.0)))
    for li in lights:
        aim(li, target)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    os.makedirs(out_dir, exist_ok=True)
    for view in views:
        nohair = view.endswith("nohair")
        for o in bpy.context.scene.objects:
            if o.name.startswith("Hair"):
                o.hide_render = nohair
        if view.startswith("face"):
            sc.render.resolution_x, sc.render.resolution_y = res, res
            cam_data.lens = 85
            head = Vector((mid.x, mid.y, lo.z + h * 0.915))
            dirv = Vector((-1.0, -0.02, 0.0)) if "side" in view else Vector((-0.45 if "34" in view else 0.0, -1.0, 0.05))
            cam.location = head + dirv.normalized() * (h * 0.52)
            aim(cam, head)
        else:
            sc.render.resolution_x, sc.render.resolution_y = int(res * 0.75), res
            cam_data.lens = 70
            ang = dict(front=0, back=180, side=90, threequarter=-35, hero=-28).get(view, 0)
            r = h * 2.55
            a = math.radians(ang)
            cam.location = Vector((mid.x + math.sin(a) * r, mid.y - math.cos(a) * r, lo.z + h * 0.56))
            aim(cam, Vector((mid.x, mid.y, lo.z + h * 0.5)))
        sc.render.filepath = os.path.join(out_dir, f"jax_{view}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", view)


main()
