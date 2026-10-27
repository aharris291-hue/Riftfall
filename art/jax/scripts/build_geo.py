"""Stage 1: build Jax's geometry with procedural materials.

Run: python build_geo.py <out.blend>
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import jaxlib as L  # noqa: E402
import jaxmats  # noqa: E402
from jaxbody import build_arm, build_hand, build_legs, build_torso  # noqa: E402
from jaxgear import build_gear  # noqa: E402
from jaxhead import build_hair, build_head  # noqa: E402


def mirror_side(objs, suffix_from="L", suffix_to="R"):
    out = []
    for o in objs:
        name = o.name[:-1] + suffix_to if o.name.endswith(suffix_from) else o.name + suffix_to
        region = o.get("region", "").replace("L", "R") if o.get("region", "").endswith("L") else o.get("region")
        out.append(L.mirror_obj(o, name, region))
    return out


def main(out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = jaxmats.all_materials()
    T = {}
    for o in build_torso(M):
        T[o.name] = o
    legs, legL, shaftL, pelvis = build_legs(M)
    for o in legs:
        T[o.name] = o
    for o in mirror_side([T["PantsLegL"], T["BootShaftL"], T["BootFootL"], T["SoleL"]]):
        T[o.name] = o
    sleeve = build_arm(M)
    T[sleeve.name] = sleeve
    T["SleeveR"] = mirror_side([sleeve])[0]
    hand = build_hand(M)
    mirror_side(hand)
    head, head_parts = build_head(M)
    hair = build_hair(M, head)
    # Slightly heroic game proportions: a touch more head.
    pivot = L.V((0, 0.0, 1.545))
    for o in head_parts + hair:
        for vtx in o.data.vertices:
            vtx.co = pivot + (vtx.co - pivot) * 1.07
    build_gear(M, T)
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            L.ensure_mask(o)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects
               if o.type == "MESH")
    print("objects", len(bpy.context.scene.objects), "tris", tris)
    bpy.ops.wm.save_as_mainfile(filepath=out)


if __name__ == "__main__":
    main(sys.argv[-1])
