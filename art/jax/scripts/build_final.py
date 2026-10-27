"""Stage 2: skin weights, studs scale, UVs, PBR bake, R15 rig, split, export.

Run: python build_final.py <geo.blend> <out_dir> [texture_size]
Writes <out_dir>/Jax_Mercer.blend, Jax_Mercer_R15.fbx and Jax_*.png textures.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402, I001
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from jaxbody import J  # noqa: E402
from jaxlib import smooth  # noqa: E402

HEIGHT_STUDS = 5.6
SOURCE_HEIGHT = 1.80
K = HEIGHT_STUDS / SOURCE_HEIGHT
ORIGIN = Vector((0, 0, J["LowerTorso"].z))

BONES = [  # name, parent
    ("Root", None),
    ("HumanoidRootNode", "Root"),
    ("LowerTorso", "HumanoidRootNode"),
    ("UpperTorso", "LowerTorso"),
    ("Head", "UpperTorso"),
    ("LeftUpperArm", "UpperTorso"),
    ("LeftLowerArm", "LeftUpperArm"),
    ("LeftHand", "LeftLowerArm"),
    ("RightUpperArm", "UpperTorso"),
    ("RightLowerArm", "RightUpperArm"),
    ("RightHand", "RightLowerArm"),
    ("LeftUpperLeg", "LowerTorso"),
    ("LeftLowerLeg", "LeftUpperLeg"),
    ("LeftFoot", "LeftLowerLeg"),
    ("RightUpperLeg", "LowerTorso"),
    ("RightLowerLeg", "RightUpperLeg"),
    ("RightFoot", "RightLowerLeg"),
]
PARTS = [b for b, _ in BONES if b not in ("Root", "HumanoidRootNode")]


def to_studs(p):
    return (Vector(p) - ORIGIN) * K


# ---------------------------------------------------------------------------
# Skin weights (computed in meters, before scaling). Limbs hang straight down
# in this I-pose, so height-based blends across each joint are reliable.
# ---------------------------------------------------------------------------

def weights_for(region, p):
    x, y, z = p
    side = "Left" if x >= 0 else "Right"
    w = {}
    if region == "head":
        h = smooth(1.47, 1.54, z)
        w = {"Head": h, "UpperTorso": 1 - h}
    elif region == "collar":
        w = {"UpperTorso": 1.0}
    elif region == "torso":
        ut = smooth(1.00, 1.12, z)
        w = {"UpperTorso": ut, "LowerTorso": 1 - ut}
        arm = smooth(0.15, 0.205, abs(x)) * smooth(1.30, 1.40, z) * 0.5
        if arm > 0:
            w = {k: v * (1 - arm) for k, v in w.items()}
            w[side + "UpperArm"] = arm
    elif region == "pelvis":
        leg = smooth(0.96, 0.86, z) * smooth(0.01, 0.06, abs(x))
        w = {"LowerTorso": 1 - leg, side + "UpperLeg": leg}
    elif region.startswith("leg"):
        side = "Left" if region.endswith("L") else "Right"
        f = smooth(0.13, 0.07, z)
        u = smooth(0.46, 0.55, z)
        lt = smooth(0.87, 0.96, z) * 0.6
        w = {side + "UpperLeg": u * (1 - lt), side + "LowerLeg": (1 - u) * (1 - f),
             side + "Foot": f * (1 - u), "LowerTorso": u * lt}
    elif region.startswith("arm"):
        side = "Left" if region.endswith("L") else "Right"
        hand = smooth(0.905, 0.875, z)
        u = smooth(1.10, 1.17, z)
        t = smooth(1.40, 1.47, z) * 0.5
        w = {side + "UpperArm": u * (1 - t), side + "LowerArm": (1 - u) * (1 - hand),
             side + "Hand": hand * (1 - u), "UpperTorso": u * t}
    elif region.startswith("hand"):
        side = "Left" if region.endswith("L") else "Right"
        hand = smooth(0.905, 0.875, z)
        w = {side + "Hand": hand, side + "LowerArm": 1 - hand}
    else:
        raise ValueError(f"unknown region {region}")
    w = {k: v for k, v in w.items() if v > 0.01}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(v for _, v in top)
    return {k: v / s for k, v in top}


def assign_weights(obj):
    region = obj.get("region")
    groups = {}
    for vtx in obj.data.vertices:
        for bone, wt in weights_for(region, vtx.co).items():
            g = groups.get(bone) or obj.vertex_groups.new(name=bone)
            groups[bone] = g
            g.add([vtx.index], wt, "REPLACE")


# ---------------------------------------------------------------------------
# Baking
# ---------------------------------------------------------------------------

def new_image(name, size, non_color):
    img = bpy.data.images.new(name, size, size, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def set_bake_target(mats, img):
    for m in mats:
        nt = m.node_tree
        node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = img
        nt.nodes.active = node


def bake(obj, mats, kind, img, **kw):
    set_bake_target(mats, img)
    bpy.ops.object.bake(type=kind, margin=8, margin_type="EXTEND", use_clear=True, **kw)


def bake_metallic(obj, mats, img):
    """Bake metallic by temporarily routing it through an emission shader."""
    saved = []
    for m in mats:
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        em = nt.nodes.new("ShaderNodeEmission")
        src = bsdf.inputs["Metallic"]
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, em.inputs["Color"])
        else:
            v = src.default_value
            em.inputs["Color"].default_value = (v, v, v, 1)
        old = out.inputs["Surface"].links[0].from_socket
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        saved.append((nt, out, old, em))
    bake(obj, mats, "EMIT", img)
    for nt, out, old, em in saved:
        nt.links.new(old, out.inputs["Surface"])
        nt.nodes.remove(em)


def save_png(img, path):
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def final_material(paths):
    m = bpy.data.materials.new("Jax_Mercer")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(path, non_color):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(path)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        return n

    nt.links.new(tex(paths["ALB"], False).outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex(paths["RGH"], True).outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(tex(paths["MTL"], True).outputs["Color"], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(paths["NOR"], True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


# ---------------------------------------------------------------------------

def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def tri_count(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    geo, out_dir = args[0], args[1]
    tex_size = int(args[2]) if len(args) > 2 else 2048
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=geo)
    sc = bpy.context.scene

    meshes = [o for o in sc.objects if o.type == "MESH"]
    for o in meshes:
        assign_weights(o)
    select_only(meshes)
    bpy.ops.object.join()
    jax = bpy.context.view_layer.objects.active
    jax.name = "Jax"
    me = jax.data
    # Meters -> studs, LowerTorso joint at the origin.
    me.transform(Matrix.Translation(-ORIGIN * K) @ Matrix.Scale(K, 4))
    me.update()

    # Lock in smooth normals so the 15 split parts shade seamlessly.
    vnorm = [tuple(v.normal) for v in me.vertices]
    me.normals_split_custom_set_from_vertices(vnorm)

    # UVs: one shared atlas; face and hair get more texels.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0015, scale_to_bounds=False)
    bm = bmesh.from_edit_mesh(me)
    uv = bm.loops.layers.uv.active
    boost = {}
    for i, m in enumerate(me.materials):
        boost[i] = {"M_Skin": 2.6, "M_Eye": 3.0, "M_Lid": 2.6, "M_Brow": 2.6, "M_Hair": 1.3,
                    "M_Glow": 1.5}.get(m.name, 1.0)
    for f in bm.faces:
        s = boost.get(f.material_index, 1.0)
        if s != 1.0:
            for loop in f.loops:
                loop[uv].uv *= s
    bmesh.update_edit_mesh(me)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Bake PBR maps from the procedural materials.
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.bake.use_selected_to_active = False
    mats = [m for m in me.materials]
    select_only([jax])
    imgs = {
        "ALB": new_image("Jax_ALB", tex_size, False),
        "AO": new_image("Jax_AO", tex_size, True),
        "RGH": new_image("Jax_RGH", tex_size // 2, True),
        "MTL": new_image("Jax_MTL", tex_size // 2, True),
        "NOR": new_image("Jax_NOR", tex_size, True),
    }
    sc.cycles.samples = 4
    bake(jax, mats, "DIFFUSE", imgs["ALB"], pass_filter={"COLOR"})
    bake(jax, mats, "ROUGHNESS", imgs["RGH"])
    bake_metallic(jax, mats, imgs["MTL"])
    bake(jax, mats, "NORMAL", imgs["NOR"], normal_space="TANGENT")
    sc.cycles.samples = 48
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = 0.45
    bake(jax, mats, "AO", imgs["AO"])
    # Multiply ambient occlusion into the color map for depth under Roblox lighting.
    alb = np.array(imgs["ALB"].pixels[:]).reshape(-1, 4)
    ao = np.array(imgs["AO"].pixels[:]).reshape(-1, 4)[:, :1]
    alb[:, :3] *= 0.30 + 0.70 * ao
    imgs["ALB"].pixels[:] = alb.ravel()
    paths = {}
    for key in ("ALB", "NOR", "RGH", "MTL"):
        paths[key] = os.path.join(out_dir, f"Jax_{key}.png")
        save_png(imgs[key], paths[key])
    save_png(imgs["AO"], os.path.join(out_dir, "Jax_AO.png"))

    final = final_material(paths)
    me.materials.clear()
    me.materials.append(final)
    for p in me.polygons:
        p.material_index = 0

    # R15 armature. Every bone points straight up (+Z) with no roll, so each
    # joint exports with zero rotation.
    arm_data = bpy.data.armatures.new("JaxRig")
    arm = bpy.data.objects.new("Jax_Mercer", arm_data)
    sc.collection.objects.link(arm)
    select_only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for name, parent in BONES:
        b = arm_data.edit_bones.new(name)
        head = to_studs(J["LowerTorso"] if name in ("Root", "HumanoidRootNode") else J[name])
        b.head = head
        b.tail = head + Vector((0, 0, 0.4 if name not in ("Root", "HumanoidRootNode") else 0.3))
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
        eb[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")

    # Split the mesh into the 15 R15 body parts by dominant bone per face.
    gidx = {g.index: g.name for g in jax.vertex_groups}
    vw = []
    for v in me.vertices:
        d = {}
        for g in v.groups:
            d[gidx[g.group]] = g.weight
        vw.append(d)
    owner = []
    for p in me.polygons:
        acc = {}
        for vi in p.vertices:
            for k, w in vw[vi].items():
                acc[k] = acc.get(k, 0) + w
        owner.append(max(acc.items(), key=lambda kv: kv[1])[0])
    parts = []
    for part in PARTS:
        dup = jax.copy()
        dup.data = jax.data.copy()
        dup.name = part + "_Geo"
        dup.data.name = part + "_Geo"
        sc.collection.objects.link(dup)
        bm = bmesh.new()
        bm.from_mesh(dup.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if owner[f.index] != part]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(dup.data)
        bm.free()
        if len(dup.data.polygons) == 0:
            raise RuntimeError(f"part {part} is empty")
        # Remove empty or unused vertex groups (never weight the Root).
        used = set()
        for v in dup.data.vertices:
            for g in v.groups:
                if g.weight > 0:
                    used.add(dup.vertex_groups[g.group].name)
        for g in list(dup.vertex_groups):
            if g.name not in used:
                dup.vertex_groups.remove(g)
        dup.parent = arm
        mod = dup.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        parts.append(dup)
        print(f"{dup.name}: {tri_count(dup.data)} tris, groups {sorted(used)}")
    bpy.data.objects.remove(jax)

    total = sum(tri_count(p.data) for p in parts)
    print("TOTAL tris", total)
    over = [p.name for p in parts if tri_count(p.data) > 20000]
    if over:
        raise RuntimeError(f"parts over Roblox's 20,000 triangle limit: {over}")

    blend_path = os.path.join(out_dir, "Jax_Mercer.blend")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    sc.unit_settings.system = "NONE"
    sc.unit_settings.scale_length = 1.0
    select_only([arm] + parts, arm)
    fbx_path = os.path.join(out_dir, "Jax_Mercer_R15.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        use_custom_props=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
        use_armature_deform_only=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
    )
    print("wrote", fbx_path)


main()
