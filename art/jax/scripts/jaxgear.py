"""Jax's gear: belt, pouches, straps, knee pads, backpack, gauntlet, tags."""

import math

import jaxlib as L
from jaxlib import V
from jaxbody import J


def ring(cx, cy, z, r, count=16):
    return [V((cx + r * math.cos(2 * math.pi * k / count), cy + r * math.sin(2 * math.pi * k / count), z))
            for k in range(count)]


def build_gear(M, T):
    """T: dict of target objects by name."""
    parts = []
    add = parts.append

    # Belt with buckle and pouches.
    add(L.strap("Belt", [T["Pelvis"]], ring(0, 0.004, 0.985, 0.25, 24), 0.042, thick=0.006, offset=0.001,
                count=48, closed=True, mat=M["leather"], region="pelvis"))
    add(L.on_surface("Buckle", [T["Pelvis"]], (0, -0.2, 0.985), (0.048, 0.016, 0.040), M["metal"], "pelvis",
                     sink=0.1, bevel=0.004))
    add(L.on_surface("BuckleTongue", [T["Pelvis"]], (0, -0.2, 0.985), (0.030, 0.022, 0.012), M["gunmetal"],
                     "pelvis", sink=0.1, bevel=0.003))
    for name, x, y, dims in (("PouchBeltL", 0.12, -0.12, (0.060, 0.034, 0.075)),
                             ("PouchBeltR", -0.135, -0.09, (0.055, 0.032, 0.070)),
                             ("PouchBeltBack", -0.09, 0.14, (0.075, 0.030, 0.060))):
        loc, nor, fr = L.surface_frame([T["Pelvis"]], (x, y, 0.97))
        c = loc + nor * 0.017 - V((0, 0, 0.012))
        add(L.rbox(name, c, dims, M["leather"], "pelvis", frame=fr, bevel=0.008))
        add(L.rbox(name + "Flap", c + nor * 0.004 + V((0, 0, dims[2] * 0.33)),
                   (dims[0] * 1.06, dims[1] * 1.08, dims[2] * 0.36), M["darkleather"], "pelvis", frame=fr,
                   bevel=0.006))
        add(L.rbox(name + "Snap", c + nor * (dims[1] * 0.56 + 0.004) + V((0, 0, dims[2] * 0.22)),
                   (0.010, 0.006, 0.010), M["metal"], "pelvis", frame=fr, bevel=0.003))

    # Thigh rig on the right leg (holster-style pouch with two straps).
    rl = T["PantsLegR"]
    for z, r in ((0.80, 0.11), (0.71, 0.10)):
        c = J["RightUpperLeg"].lerp(J["RightLowerLeg"], (0.92 - z) / 0.42)
        add(L.strap(f"ThighStrapR{z}", [rl], ring(c.x, c.y, z, r, 16), 0.024, thick=0.004, offset=0.001,
                    count=32, closed=True, mat=M["webbing"], region="legR"))
    loc, nor, fr = L.surface_frame([rl], (-0.20, -0.06, 0.76))
    c = loc + nor * 0.02
    add(L.rbox("ThighPouchR", c, (0.070, 0.040, 0.110), M["leather"], "legR", frame=fr, bevel=0.009))
    add(L.rbox("ThighPouchRFlap", c + nor * 0.004 + V((0, 0, 0.035)), (0.075, 0.044, 0.042), M["darkleather"],
               "legR", frame=fr, bevel=0.007))
    # Drop strap from belt to the thigh rig.
    add(L.strap("DropStrapR", [rl, T["Pelvis"]], [V((-0.15, -0.02, 0.97)), V((-0.17, -0.03, 0.88)),
                                                   V((-0.175, -0.04, 0.80))], 0.022, thick=0.004, count=10,
                mat=M["webbing"], region="legR"))
    # Left thigh: side pocket with one strap.
    ll = T["PantsLegL"]
    c = J["LeftUpperLeg"].lerp(J["LeftLowerLeg"], (0.92 - 0.74) / 0.42)
    add(L.strap("ThighStrapL", [ll], ring(c.x, c.y, 0.74, 0.10, 16), 0.022, thick=0.004, offset=0.001,
                count=32, closed=True, mat=M["webbing"], region="legL"))
    loc, nor, fr = L.surface_frame([ll], (0.20, 0.0, 0.70))
    c = loc + nor * 0.016
    add(L.rbox("CargoPocketL", c, (0.075, 0.030, 0.095), M["pants"], "legL", frame=fr, bevel=0.010))
    add(L.rbox("CargoPocketLFlap", c + nor * 0.004 + V((0, 0, 0.034)), (0.080, 0.034, 0.030), M["pants"],
               "legL", frame=fr, bevel=0.008))

    # Knee pads with straps.
    for side, leg in (("L", ll), ("R", rl)):
        k = J[f"{'Left' if side == 'L' else 'Right'}LowerLeg"]
        loc, nor, fr = L.surface_frame([leg], (k.x, -0.12, 0.50))
        add(L.rbox(f"KneePad{side}", loc + nor * 0.006, (0.078, 0.030, 0.098), M["gunmetal"], f"leg{side}",
                   frame=fr, bevel=0.013))
        add(L.rbox(f"KneePadPlate{side}", loc + nor * 0.019 + V((0, 0, 0.012)), (0.050, 0.010, 0.050),
                   M["metal"], f"leg{side}", frame=fr, bevel=0.005))
        for dz in (0.035, -0.035):
            add(L.strap(f"KneeStrap{side}{dz}", [leg], ring(k.x, k.y, 0.50 + dz, 0.10, 16), 0.016, thick=0.003,
                        offset=0.0005, count=28, closed=True, mat=M["webbing"], region=f"leg{side}"))

    # Boot straps and buckles.
    for side in ("L", "R"):
        shaft = T[f"BootShaft{side}"]
        f = J[f"{'Left' if side == 'L' else 'Right'}Foot"]
        for z in (0.27, 0.19):
            add(L.strap(f"BootStrap{side}{z}", [shaft], ring(f.x, f.y - 0.01, z, 0.09, 16), 0.017, thick=0.004,
                        offset=0.0005, count=28, closed=True, mat=M["darkleather"], region=f"leg{side}"))
            sx = 1 if side == "L" else -1
            add(L.on_surface(f"BootBuckle{side}{z}", [shaft], (f.x + sx * 0.06, f.y - 0.02, z), (0.020, 0.010, 0.020),
                             M["metal"], f"leg{side}", sink=0.0, bevel=0.003))
        # Laces panel on the front of the boot.
        loc, nor, fr = L.surface_frame([T[f"BootFoot{side}"]], (f.x, -0.08, 0.10))
        add(L.rbox(f"BootTongue{side}", loc + nor * 0.002, (0.040, 0.010, 0.070), M["darkleather"],
                   f"leg{side}", frame=(fr[0], fr[1], fr[2]), bevel=0.004))

    # Backpack.
    torso = [T["Jacket"]]
    loc, nor, fr = L.surface_frame(torso, (0, 0.2, 1.24))
    pc = loc + nor * 0.052
    add(L.rbox("Pack", pc, (0.250, 0.095, 0.300), M["pack"], "torso", frame=fr, bevel=0.03))
    add(L.rbox("PackFlap", pc + nor * 0.012 + V((0, 0, 0.10)), (0.258, 0.088, 0.115), M["pack"], "torso",
               frame=fr, bevel=0.025))
    add(L.rbox("PackPocket", pc + nor * 0.050 + V((0, 0, -0.05)), (0.160, 0.030, 0.120), M["pack"], "torso",
               frame=fr, bevel=0.012))
    add(L.rbox("PackPanel", pc + nor * 0.050 + V((0, 0, 0.06)), (0.090, 0.006, 0.040), M["gunmetal"], "torso",
               frame=fr, bevel=0.003))
    add(L.rbox("PackGlow", pc + nor * 0.054 + V((0, 0, 0.06)), (0.070, 0.004, 0.008), M["glow"], "torso",
               frame=fr, bevel=0.0015))
    for sx, name in ((1, "L"), (-1, "R")):
        pts = [V((sx * 0.085, 0.13, 1.36)), V((sx * 0.095, 0.08, 1.46)), V((sx * 0.10, 0.0, 1.49)),
               V((sx * 0.105, -0.08, 1.44)), V((sx * 0.115, -0.11, 1.34)), V((sx * 0.13, -0.10, 1.22)),
               V((sx * 0.16, -0.04, 1.14))]
        add(L.strap(f"PackStrap{name}", torso, pts, 0.045, thick=0.007, offset=0.002, count=28,
                    mat=M["webbing"], region="torso"))
        add(L.on_surface(f"StrapAdjust{name}", torso, (sx * 0.12, -0.11, 1.32), (0.040, 0.012, 0.018), M["metal"],
                         "torso", sink=-0.6, bevel=0.003))
    add(L.strap("SternumStrap", torso, [V((-0.115, -0.13, 1.30)), V((0, -0.15, 1.30)), V((0.115, -0.13, 1.30))],
                0.020, thick=0.004, offset=0.0105, count=12, mat=M["webbing"], region="torso"))
    add(L.on_surface("SternumBuckle", torso, (0, -0.15, 1.30), (0.034, 0.016, 0.026), M["gunmetal"], "torso",
                     sink=-0.75, bevel=0.004))

    # Dog tag on a cord (the expedition ID tags are a story item).
    shirt = [T["Shirt"]]
    cord_pts = [V((-0.05, -0.03, 1.50)), V((-0.045, -0.085, 1.45)), V((-0.02, -0.105, 1.40)),
                V((0, -0.11, 1.385)), V((0.02, -0.105, 1.40)), V((0.045, -0.085, 1.45)), V((0.05, -0.03, 1.50))]
    add(L.strap("TagCord", shirt, cord_pts, 0.003, thick=0.0016, offset=0.001, count=20, mat=M["darkleather"],
                region="torso", n=2))
    add(L.on_surface("DogTag", shirt, (0, -0.2, 1.37), (0.022, 0.004, 0.034), M["metal"], "torso", sink=-0.5,
                     bevel=0.004))

    # Left forearm: Serra's wrist unit, a segmented metal gauntlet with a glow.
    sl = T["SleeveL"]
    a, b = J["LeftLowerArm"], J["LeftHand"]
    for i, (t0, t1) in enumerate(((0.12, 0.38), (0.40, 0.66), (0.68, 0.93))):
        z0 = a.lerp(b, t0)
        z1 = a.lerp(b, t1)
        secs = []
        for c, r in ((z0, 0.050 - 0.006 * t0), (z1, 0.047 - 0.006 * t1)):
            secs.append(dict(c=c, a=r, al=r, bf=r * 0.98, bb=r * 0.98, n=2.2, g=95))
        plate = L.loft(f"GauntletL{i}", secs, seg=16, steps=1, mat=M["metal"], region="armL")
        # Rotate the open side so the plate wraps the outer (+X) half.
        for vtx in plate.data.vertices:
            p = vtx.co
            c = a.lerp(b, (p.z - a.z) / (b.z - a.z))
            dx, dy = p.x - c.x, p.y - c.y
            vtx.co.x, vtx.co.y = c.x - dy, c.y + dx  # 90 degrees: front gap -> inner side
        L.solidify(plate, 0.006, 1.0)
        add(plate)
    loc, nor, fr = L.surface_frame([sl], a.lerp(b, 0.55) + V((0.05, -0.015, 0)))
    dev = loc + nor * 0.018
    add(L.rbox("WristUnitL", dev, (0.040, 0.020, 0.070), M["gunmetal"], "armL", frame=fr, bevel=0.006))
    add(L.rbox("WristGlowL", dev + nor * 0.0105, (0.026, 0.004, 0.048), M["glow"], "armL", frame=fr, bevel=0.004))
    # Shoulder patch with a small glowing emblem.
    loc, nor, fr = L.surface_frame([sl], (0.27, -0.01, 1.33))
    add(L.rbox("ShoulderPatchL", loc + nor * 0.002, (0.050, 0.006, 0.058), M["darkleather"], "armL", frame=fr,
               bevel=0.004))
    add(L.rbox("ShoulderGlowL", loc + nor * 0.0055, (0.020, 0.003, 0.030), M["glow"], "armL", frame=fr,
               bevel=0.0015))
    # Right forearm: worn leather bracer with two straps.
    sr = T["SleeveR"]
    a, b = J["RightLowerArm"], J["RightHand"]
    secs = []
    for t in (0.25, 0.55, 0.92):
        c = a.lerp(b, t)
        r = 0.051 - 0.012 * t
        secs.append(dict(c=c, a=r, bf=r, bb=r, n=2.2))
    bracer = L.loft("BracerR", secs, seg=20, steps=2, cap0=False, cap1=False, mat=M["leather"], region="armR")
    L.solidify(bracer, 0.005, 1.0)
    add(bracer)
    return parts
