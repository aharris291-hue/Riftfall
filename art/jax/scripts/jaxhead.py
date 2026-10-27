"""Jax's head: face sculpt, eyes, brows, ears and messy dark hair."""

import math

import jaxlib as L
from jaxlib import V

HEAD = [  # z, cy, a, bf, bb, n
    (1.440, 0.010, 0.051, 0.049, 0.054, 2.0),
    (1.500, 0.012, 0.050, 0.048, 0.054, 2.0),
    (1.540, 0.010, 0.054, 0.053, 0.058, 2.0),
    (1.558, 0.004, 0.058, 0.078, 0.064, 2.2),
    (1.574, -0.002, 0.059, 0.093, 0.068, 2.5),
    (1.600, -0.004, 0.069, 0.097, 0.077, 2.6),
    (1.625, -0.002, 0.076, 0.099, 0.089, 2.5),
    (1.650, 0.000, 0.081, 0.099, 0.099, 2.3),
    (1.675, 0.000, 0.081, 0.097, 0.105, 2.2),
    (1.700, 0.000, 0.081, 0.098, 0.107, 2.2),
    (1.730, 0.002, 0.078, 0.091, 0.105, 2.1),
    (1.760, 0.004, 0.070, 0.076, 0.097, 2.0),
    (1.785, 0.006, 0.053, 0.054, 0.075, 2.0),
    (1.800, 0.008, 0.024, 0.026, 0.032, 2.0),
]

EYE_X, EYE_Z = 0.034, 1.676


def head_brushes():
    b = []
    # Nose bridge to tip (forward = -Y), growing toward the tip.
    for z, amp, rx in ((1.700, 0.003, 0.010), (1.686, 0.005, 0.009), (1.672, 0.008, 0.009),
                       (1.658, 0.012, 0.010), (1.646, 0.016, 0.012), (1.637, 0.016, 0.014)):
        b.append(((0, -0.09, z), (rx, 0.05, 0.010), (0, -amp, 0)))
    for s in (-1, 1):
        b.append(((s * 0.015, -0.09, 1.634), (0.008, 0.05, 0.007), (s * 0.003, -0.011, 0)))  # nostril wings
        b.append(((s * EYE_X, -0.09, EYE_Z), (0.019, 0.05, 0.012), (0, 0.014, 0)))  # eye sockets
        b.append(((s * EYE_X, -0.09, EYE_Z + 0.013), (0.015, 0.05, 0.003), (0, 0.003, 0)))  # lid crease
        b.append(((s * 0.022, -0.09, 1.6065), (0.004, 0.05, 0.004), (0, 0.003, 0)))  # mouth corners
        b.append(((s * 0.030, -0.09, 1.622), (0.004, 0.05, 0.012), (0, 0.0015, 0)))  # smile lines
        b.append(((s * 0.031, -0.09, 1.699), (0.024, 0.05, 0.006), (0, -0.004, 0.001)))  # brow ridge
        b.append(((s * 0.056, -0.06, 1.652), (0.016, 0.03, 0.012), (s * 0.004, -0.004, 0)))  # cheekbones
        b.append(((s * 0.063, 0.02, 1.574), (0.014, 0.03, 0.012), (s * 0.006, 0, -0.002)))  # jaw angle
        b.append(((s * 0.074, -0.01, 1.712), (0.012, 0.03, 0.02), (-s * 0.003, 0, 0)))  # temples
        b.append(((s * 0.048, -0.08, 1.612), (0.012, 0.04, 0.018), (0, 0.003, 0)))  # cheek hollows
    b.append(((0, -0.09, 1.614), (0.019, 0.05, 0.0055), (0, -0.006, 0)))  # upper lip
    b.append(((0, -0.09, 1.6065), (0.021, 0.05, 0.0018), (0, 0.003, 0)))  # mouth line
    b.append(((0, -0.09, 1.599), (0.017, 0.05, 0.005), (0, -0.0055, 0)))  # lower lip
    b.append(((0, -0.09, 1.589), (0.016, 0.05, 0.004), (0, 0.003, 0)))  # under lip groove
    b.append(((0, -0.09, 1.576), (0.020, 0.05, 0.011), (0, -0.009, -0.002)))  # chin
    b.append(((0, -0.09, 1.624), (0.006, 0.05, 0.006), (0, -0.002, 0)))  # philtrum
    b.append(((0, -0.09, 1.640), (0.010, 0.05, 0.007), (0, -0.004, -0.001)))  # nose tip ball
    for s in (-1, 1):
        for k in range(5):
            t = k / 4
            b.append(((s * (0.022 + 0.045 * t), -0.075 + 0.085 * t, 1.566 + 0.012 * t), (0.012, 0.012, 0.006),
                      (s * 0.002, 0, -0.003)))  # jaw line
    return b


def hair_mask(p):
    """1 where the scalp is covered by hair."""
    x, y, z = p
    ax = abs(x)
    front = L.smooth(1.728, 1.742, z)  # forehead hairline
    side = L.smooth(1.690, 1.705, z) * L.smooth(-0.035, -0.015, y) * L.smooth(0.055, 0.07, ax)
    back = L.smooth(1.58, 1.60, z) * L.smooth(0.03, 0.06, y)
    sideburn = L.smooth(1.64, 1.655, z) * L.smooth(0.072, 0.079, ax) * L.smooth(-0.01, 0.005, y) * \
        (1 - L.smooth(0.03, 0.05, y))
    return max(front, side, back, sideburn)


def build_head(M):
    parts = []
    secs = [dict(c=(0, cy, z), a=a, bf=bf, bb=bb, n=n) for z, cy, a, bf, bb, n in HEAD]
    def jaw(t, ang, p, c):
        # V-shaped lower face: narrow the front of the jaw toward the chin.
        taper = 0.42 * L.smooth(1.636, 1.574, p.z) * L.smooth(1.548, 1.566, p.z)
        front = max(0.0, -math.sin(ang)) ** 1.5
        return V((c.x + (p.x - c.x) * (1 - taper * front), p.y, p.z))

    head = L.loft("Head", secs, seg=36, steps=3, mat=M["skin"], region="head", shape=jaw)
    L.subsurf(head, 1)
    L.displace(head, head_brushes())
    dec = head.modifiers.new("Dec", "DECIMATE")
    dec.ratio = 0.55
    dec.use_symmetry = True
    dec.symmetry_axis = "X"
    L.apply_mods(head)
    head.data.polygons.foreach_set("use_smooth", [True] * len(head.data.polygons))

    def mask(p, n):
        lips = 0.0
        if p.y < -0.05:
            q = (p.x / 0.020) ** 2 + ((p.z - 1.6065) / 0.0105) ** 2
            lips = max(0.0, min(1.0, 1.8 - q * 1.3))
        stubble = 0.0
        if p.y < 0.045 and p.z < 1.63 and p.z > 1.53:
            stubble = 0.5 * L.smooth(1.63, 1.605, p.z) * (1 - lips) * L.smooth(1.53, 1.56, p.z)
        dark = 0.0
        if p.y < -0.06:
            for sx in (-1, 1):
                q = ((p.x - sx * 0.0085) / 0.0042) ** 2 + ((p.z - 1.6315) / 0.0024) ** 2
                dark = max(dark, 0.85 * max(0.0, 1 - q))
            q = (p.x / 0.019) ** 2 + ((p.z - 1.6065) / 0.0011) ** 2
            dark = max(dark, 0.55 * max(0.0, 1 - q))
        return max(hair_mask(p), dark), lips, stubble

    L.set_mask(head, mask)
    parts.append(head)

    for s, side in ((1, "L"), (-1, "R")):
        # Eye with brown iris looking forward.
        c = V((s * EYE_X, -0.0725, EYE_Z))
        eye = L.ellipsoid(f"Eye{side}", c, (0.0135, 0.0135, 0.0135), M["eye"], "head", seg=20, rings=12)

        def emask(p, n, c=c):
            d = (p - c).normalized()
            ang = math.degrees(math.acos(max(-1.0, min(1.0, -d.y))))
            return 0.0, 1.0 if ang < 39 else 0.0, 1.0 if ang < 16 else 0.0

        L.set_mask(eye, emask)
        parts.append(eye)
        # Upper eyelid: a cap over the top of the eye, tilted forward.
        lid = L.ellipsoid(f"Lid{side}", c + V((0, -0.0005, 0.0005)), (0.0146, 0.0146, 0.0146), M["lid"], "head",
                          seg=20, rings=12)
        me = lid.data
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        kill = [v for v in bm.verts if (v.co.z - c.z) < 0.0103 + 0.30 * (v.co.y - c.y)]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(me)
        bm.free()
        L.solidify(lid, 0.0015, 1.0)
        L.set_mask(lid, lambda p, n, c=c: (1.0 if (p.z - c.z) < 0.0128 + 0.30 * (p.y - c.y) else 0.0, 0, 0))
        parts.append(lid)
        # Lower lid: a cap under the eye, so the open eye reads as almond shaped.
        low = L.ellipsoid(f"LowerLid{side}", c + V((0, -0.0004, 0)), (0.0145, 0.0145, 0.0145), M["lid"], "head",
                          seg=20, rings=12)
        bm = bmesh.new()
        bm.from_mesh(low.data)
        kill = [v for v in bm.verts if (v.co.z - c.z) > -0.0035 + 0.2 * (v.co.y - c.y)]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(low.data)
        bm.free()
        L.solidify(low, 0.0012, 1.0)
        L.set_mask(low, lambda p, n, c=c: (0.45 if (p.z - c.z) > -0.0052 + 0.2 * (p.y - c.y) else 0.0, 0, 0))
        parts.append(low)
        # Eyebrow lying on the brow ridge.
        brow_pts = [V((s * x, -0.088 + 0.03 * (x - 0.012), z)) for x, z in
                    ((0.014, 1.6995), (0.025, 1.7025), (0.037, 1.7045), (0.048, 1.7025), (0.054, 1.6995))]
        brow = L.strap(f"Brow{side}", [head], brow_pts, 0.0068, thick=0.0012, offset=0.0003, count=12,
                       mat=M["brow"], region="head")
        L.ensure_mask(brow)
        parts.append(brow)
        # Ear.
        ear = L.ellipsoid(f"Ear{side}", (s * 0.080, 0.020, 1.662), (0.010, 0.021, 0.031), M["skin"], "head",
                          seg=24, rings=16, rot=(0, s * math.radians(-12), s * math.radians(14)))
        L.displace(ear, [((s * 0.088, 0.018, 1.662), (0.006, 0.012, 0.016), (-s * 0.004, 0, 0))])
        L.ensure_mask(ear)
        parts.append(ear)
    return head, parts


def build_hair(M, head):
    """Messy, layered dark-brown locks swept forward and to the side."""
    rng = L.random.Random(11)
    tree = L.bvh_of(head)
    me = head.data
    roots = []
    for vtx in me.vertices:
        p = vtx.co
        if hair_mask(p) > 0.9 and p.z > 1.605:
            roots.append((p.copy(), vtx.normal.copy()))
    rng.shuffle(roots)
    # Keep roots spread out.
    chosen = []
    for p, n in roots:
        if all((p - q).length > 0.016 for q, _ in chosen):
            chosen.append((p, n))
        if len(chosen) >= 145:
            break
    parts = []
    crown = V((0.012, 0.035, 1.80))
    for i, (p, n) in enumerate(chosen):
        x, y, z = p
        fringe = y < -0.02 and z > 1.70
        flow = p - crown
        if fringe:  # falls forward over the brow, sweeping a little to Jax's left
            flow = V((0.35 + 2.0 * x, -0.6, -0.9))
            length = rng.uniform(0.075, 0.10)
        elif abs(x) > 0.05 and y < 0.06 and z < 1.75:  # sides: down and back over the ear tops
            flow = V((math.copysign(0.2, x), 0.35, -1.0))
            length = rng.uniform(0.08, 0.11)
        elif y > 0.04 and z < 1.74:  # back: down to the nape
            flow = V((x * 2, 0.25, -1.0))
            length = rng.uniform(0.08, 0.11)
        else:  # top: long locks flowing out from the crown
            flow = flow + V((0, -0.03, -0.01))
            length = rng.uniform(0.12, 0.165)
        flow = flow.normalized()
        jitter = V((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), rng.uniform(-0.08, 0.08)))
        steps = 7
        pts = [p - n * 0.006]
        lift_amt = rng.uniform(0.008, 0.018) * (1.0 if z > 1.70 else 0.6)
        flick = rng.uniform(0.004, 0.014) if rng.random() < 0.6 else 0.0
        nrm = n
        for k in range(1, steps + 1):
            t = k / steps
            d = flow + jitter + V((0, 0, -0.5 * t))
            d = (d - nrm * d.dot(nrm)).normalized()  # follow the scalp
            d = (d + nrm * max(0.0, 0.6 - 1.4 * t)).normalized()  # lift at the root
            q = pts[-1] + d * (length / steps)
            hit = tree.find_nearest(q)
            if hit[0] is not None:
                loc, nrm = hit[0], hit[1]
                lift = 0.003 + lift_amt * math.sin(math.pi * min(1.0, 0.2 + t * 0.75)) + flick * t ** 3
                h = (q - loc).dot(nrm)
                if h < lift * 0.7:
                    q = loc + nrm * (lift * 0.7)
                elif h > lift:
                    q = q - nrm * (h - lift)
            pts.append(q)
        w0 = rng.uniform(0.019, 0.027)
        widths = [w0 * (1 - (k / steps) ** 1.25) + 0.0008 for k in range(steps + 1)]
        thick = [w * 0.34 for w in widths]
        strand = L.tube(f"Hair{i}", pts, widths, thick, seg=4, steps=1, mat=M["hair"], region="head",
                        hint=n, cap1=False)
        L.set_mask(strand, lambda pp, nn, p0=p, ln=length: (min(1.0, (pp - p0).length / ln) ** 2, 0, 0))
        parts.append(strand)
    return parts
