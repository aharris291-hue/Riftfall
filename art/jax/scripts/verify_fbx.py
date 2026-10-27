"""Re-import the exported FBX into an empty scene and check it against
Roblox's R15 character requirements, then save a posed copy for a
deformation test render.

Run: python verify_fbx.py <Jax_Mercer_R15.fbx> <posed_out.blend>
"""

import math
import sys

import bpy
from mathutils import Euler, Vector

R15_PARTS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
             "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
             "RightLowerLeg", "RightFoot"]
HIERARCHY = {
    "Root": None, "HumanoidRootNode": "Root", "LowerTorso": "HumanoidRootNode", "UpperTorso": "LowerTorso",
    "Head": "UpperTorso", "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm",
    "LeftHand": "LeftLowerArm", "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm",
    "RightHand": "RightLowerArm", "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg",
    "LeftFoot": "LeftLowerLeg", "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg",
    "RightFoot": "RightLowerLeg",
}

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
fbx, posed = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
problems = []
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print("armatures:", [a.name for a in arms])
if len(arms) != 1:
    problems.append("expected exactly one armature")
arm = arms[0]
bones = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
if bones != HIERARCHY:
    problems.append(f"bone hierarchy mismatch: {bones}")
for b in arm.data.bones:
    if b.name in ("Root", "LowerTorso"):
        print(f"  {b.name} head at {tuple(round(c, 4) for c in arm.matrix_world @ b.head_local)}")
names = sorted(o.name for o in meshes)
want = sorted(p + "_Geo" for p in R15_PARTS)
if names != want:
    problems.append(f"mesh names mismatch: {names}")
lo = Vector((1e9,) * 3)
hi = -lo
total = 0
for o in meshes:
    me = o.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    total += tris
    if tris > 20000:
        problems.append(f"{o.name} has {tris} triangles (> 20000)")
    if not any(m.type == "ARMATURE" for m in o.modifiers):
        problems.append(f"{o.name} is not skinned to the armature")
    gnames = {g.index: g.name for g in o.vertex_groups}
    maxinf = 0
    for v in me.vertices:
        ws = [g for g in v.groups if g.weight > 1e-4]
        maxinf = max(maxinf, len(ws))
        if any(gnames[g.group] == "Root" for g in ws):
            problems.append(f"{o.name} has Root influences")
            break
        s = sum(g.weight for g in ws)
        if abs(s - 1) > 0.02:
            problems.append(f"{o.name} vertex {v.index} weights sum to {s:.3f}")
            break
        w = o.matrix_world @ v.co
        lo = Vector(map(min, lo, w))
        hi = -(Vector(map(min, -hi, -w)))
    if maxinf > 4:
        problems.append(f"{o.name} has vertices with {maxinf} influences")
    mats = [m.name for m in me.materials]
    texs = []
    for m in me.materials:
        if m.use_nodes:
            texs += [n.image.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
    print(f"  {o.name}: {tris} tris, max influences {maxinf}, materials {mats}, textures {len(texs)}")
    if len(texs) < 3:
        problems.append(f"{o.name} is missing embedded textures")
size = hi - lo
print(f"total tris {total}")
print(f"size (Blender units = studs): width {size.x:.2f}, depth {size.y:.2f}, height {size.z:.2f}")
if not (5.0 < size.z < 6.2):
    problems.append(f"unexpected height {size.z:.2f}")
print("PROBLEMS:" if problems else "ALL CHECKS PASSED")
for p in problems:
    print("  -", p)

# A walk-cycle style pose to check the skin weights deform cleanly.
pose = {
    "LeftUpperLeg": (-35, 0, 0), "LeftLowerLeg": (40, 0, 0), "RightUpperLeg": (25, 0, 0),
    "RightLowerLeg": (10, 0, 0), "LeftFoot": (-10, 0, 0),
    "LeftUpperArm": (30, 0, 8), "LeftLowerArm": (-35, 0, 0), "RightUpperArm": (-30, 0, -8),
    "RightLowerArm": (-40, 0, 0), "Head": (0, 0, 15), "UpperTorso": (0, 0, -8),
}
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for name, (x, y, z) in pose.items():
    pb = arm.pose.bones[name]
    pb.rotation_mode = "XYZ"
    # Bones point up (+Y in bone space), so rotate about bone X for swing.
    pb.rotation_euler = Euler((math.radians(x), math.radians(z), math.radians(y)))
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_as_mainfile(filepath=posed)
