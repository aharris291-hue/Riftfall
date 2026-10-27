"""Jax Mercer geometry: body, clothing, gear, head and hair (meters)."""

import math

from mathutils import Vector

import jaxlib as L
from jaxlib import V

# Joint positions (meters, feet at z = 0, facing -Y, left = +X).
J = dict(
    LowerTorso=V((0, 0, 0.97)),
    UpperTorso=V((0, 0, 1.07)),
    Head=V((0, 0, 1.50)),
    LeftUpperArm=V((0.205, 0.0, 1.42)),
    LeftLowerArm=V((0.226, 0.006, 1.135)),
    LeftHand=V((0.240, 0.0, 0.885)),
    LeftUpperLeg=V((0.095, 0.0, 0.92)),
    LeftLowerLeg=V((0.100, -0.005, 0.50)),
    LeftFoot=V((0.103, 0.015, 0.085)),
)
for k in list(J):
    if k.startswith("Left"):
        p = J[k]
        J["Right" + k[4:]] = V((-p.x, p.y, p.z))


def _lerp_line(a, b, z):
    t = (z - a.z) / (b.z - a.z)
    return a.lerp(b, t)


def limb_center(chain, z):
    """Point on a joint chain (list of Vectors, descending z) at height z."""
    for a, b in zip(chain, chain[1:]):
        if b.z <= z <= a.z:
            return _lerp_line(a, b, z)
    if z > chain[0].z:
        return _lerp_line(chain[0], chain[1], z)
    return _lerp_line(chain[-2], chain[-1], z)


# ---------------------------------------------------------------------------
# Torso: shirt, jacket shell, collar, rolled hood
# ---------------------------------------------------------------------------

TORSO = [  # z, cy, a, bf, bb, n
    (0.93, 0.004, 0.158, 0.094, 0.104, 2.2),
    (0.99, 0.0, 0.160, 0.092, 0.100, 2.2),
    (1.06, 0.0, 0.150, 0.088, 0.090, 2.3),
    (1.16, -0.004, 0.160, 0.096, 0.090, 2.4),
    (1.27, -0.010, 0.176, 0.108, 0.094, 2.5),
    (1.36, -0.008, 0.184, 0.104, 0.098, 2.6),
    (1.415, -0.004, 0.174, 0.090, 0.094, 2.6),
    (1.46, 0.0, 0.128, 0.070, 0.080, 2.4),
    (1.50, 0.004, 0.072, 0.058, 0.062, 2.0),
]


def torso_sections(grow=0.0, zmin=0.0, zmax=9.0, gaps=None):
    out = []
    for z, cy, a, bf, bb, n in TORSO:
        if z < zmin or z > zmax:
            continue
        g = gaps(z) if gaps else 0.0
        out.append(dict(c=(0, cy, z), a=a + grow, bf=bf + grow, bb=bb + grow, n=n, g=g))
    return out


def build_torso(M):
    parts = []
    shirt = L.loft("Shirt", torso_sections(), seg=36, steps=3, mat=M["shirt"], region="torso")
    parts.append(shirt)

    def gap(z):
        # Open jacket: wide at the chest (lapels), narrower toward the hem.
        return 20 + 18 * L.smooth(1.18, 1.46, z) - 4 * L.smooth(1.15, 1.0, z)

    secs = torso_sections(0.014, 0.99, 1.47, gap)
    # Flare the hem a little and drop the back of the jacket lower.
    secs.insert(0, dict(c=(0, 0.006, 0.975), a=0.180, bf=0.112, bb=0.122, n=2.2, g=18))

    def hem(t, ang, p, c):
        # Back of the hem hangs lower than the front.
        if t < 0.08:
            back = max(0.0, math.sin(ang))
            p = p - V((0, 0, 0.025 * back * (1 - t / 0.08)))
        return p

    jacket = L.loft("Jacket", secs, seg=48, steps=4, mat=M["jacket"], region="torso", shape=hem)
    L.solidify(jacket, 0.008, 1.0)
    parts.append(jacket)

    # Stand-up collar, open at the front.
    collar = L.loft(
        "Collar",
        [
            dict(c=(0, 0.006, 1.455), a=0.100, bf=0.085, bb=0.090, n=2.2, g=46),
            dict(c=(0, 0.010, 1.500), a=0.088, bf=0.078, bb=0.084, n=2.2, g=50),
            dict(c=(0, 0.016, 1.545), a=0.090, bf=0.080, bb=0.086, n=2.2, g=56),
            dict(c=(0, 0.020, 1.575), a=0.096, bf=0.086, bb=0.092, n=2.2, g=62),
        ],
        seg=40, steps=3, mat=M["jacket"], region="collar",
    )
    L.solidify(collar, 0.007, 1.0)
    parts.append(collar)

    # Rolled hood resting behind the neck and on the shoulders.
    pts = []
    for k in range(11):
        t = math.radians(-100 + 200 * k / 10)  # around the back
        pts.append(V((0.115 * math.sin(t), 0.035 + 0.075 * math.cos(t), 1.47 + 0.012 * math.cos(t))))
    widths = [0.020 + 0.018 * math.cos(math.radians(-100 + 200 * k / 10)) ** 2 for k in range(11)]
    thick = [w * 1.4 for w in widths]
    hood = L.tube("Hood", pts, widths, thick, seg=14, steps=3, mat=M["jacket"], region="collar", hint=(0, 0, 1))
    parts.append(hood)
    return parts


# ---------------------------------------------------------------------------
# Legs, pelvis, boots
# ---------------------------------------------------------------------------

LEG = [  # z, a, bf, bb
    (0.92, 0.088, 0.086, 0.094),
    (0.82, 0.083, 0.080, 0.086),
    (0.70, 0.074, 0.071, 0.077),
    (0.60, 0.064, 0.062, 0.067),
    (0.52, 0.057, 0.060, 0.057),
    (0.45, 0.056, 0.056, 0.064),
    (0.37, 0.054, 0.053, 0.064),
    (0.29, 0.048, 0.047, 0.054),
    (0.24, 0.046, 0.045, 0.050),
]


def build_legs(M):
    parts = []
    pelvis = L.loft(
        "Pelvis",
        [
            dict(c=(0, 0.004, 0.80), a=0.120, bf=0.070, bb=0.080, n=2.2),
            dict(c=(0, 0.006, 0.86), a=0.152, bf=0.090, bb=0.104, n=2.3),
            dict(c=(0, 0.006, 0.93), a=0.160, bf=0.093, bb=0.106, n=2.3),
            dict(c=(0, 0.004, 1.00), a=0.157, bf=0.091, bb=0.098, n=2.3),
            dict(c=(0, 0.002, 1.04), a=0.150, bf=0.088, bb=0.092, n=2.3),
        ],
        seg=32, steps=3, mat=M["pants"], region="pelvis",
    )
    parts.append(pelvis)

    chain = [J["LeftUpperLeg"], J["LeftLowerLeg"], J["LeftFoot"]]
    secs = []
    for z, a, bf, bb in LEG:
        c = limb_center(chain, z)
        c.x -= 0.006 if z > 0.85 else 0.0
        secs.append(dict(c=c, a=a, al=a * 0.96, bf=bf, bb=bb, n=2.15))
    legL = L.loft("PantsLegL", secs, seg=30, steps=3, mat=M["pants"], region="legL")
    parts.append(legL)

    # Boot shaft + foot + sole.
    shaft = []
    for z, a, bf, bb in ((0.31, 0.056, 0.055, 0.061), (0.25, 0.052, 0.051, 0.057),
                         (0.18, 0.048, 0.050, 0.053), (0.12, 0.047, 0.053, 0.055),
                         (0.075, 0.048, 0.060, 0.062)):
        c = limb_center(chain, z)
        shaft.append(dict(c=c, a=a, bf=bf, bb=bb, n=2.3))
    bshaft = L.loft("BootShaftL", shaft, seg=30, steps=3, mat=M["leather"], region="legL")
    parts.append(bshaft)

    fx = J["LeftFoot"].x
    foot = []
    for y, z, a, bot, top in ((0.070, 0.058, 0.040, 0.048, 0.045), (0.040, 0.058, 0.047, 0.050, 0.052),
                              (-0.020, 0.050, 0.052, 0.040, 0.046), (-0.080, 0.040, 0.053, 0.030, 0.036),
                              (-0.130, 0.034, 0.046, 0.024, 0.026), (-0.160, 0.030, 0.030, 0.020, 0.016)):
        foot.append(dict(c=(fx, y, z), u=(1, 0, 0), v=(0, 0, 1), a=a, bf=bot, bb=top, n=2.6))
    bfoot = L.loft("BootFootL", foot, seg=32, steps=3, mat=M["leather"], region="legL")
    parts.append(bfoot)

    sole = []
    for y, a in ((0.078, 0.042), (0.040, 0.050), (-0.020, 0.056), (-0.080, 0.057), (-0.130, 0.050),
                 (-0.165, 0.033)):
        sole.append(dict(c=(fx, y, 0.013), u=(1, 0, 0), v=(0, 0, 1), a=a, bf=0.013, bb=0.012, n=5))
    bsole = L.loft("SoleL", sole, seg=40, steps=3, mat=M["sole"], region="legL")
    parts.append(bsole)
    return parts, legL, bshaft, pelvis


# ---------------------------------------------------------------------------
# Arms and hands
# ---------------------------------------------------------------------------

ARM = [  # z, a, bf, bb   (jacket sleeve, slightly loose)
    (1.462, 0.034, 0.040, 0.040),
    (1.43, 0.060, 0.060, 0.060),
    (1.38, 0.062, 0.058, 0.058),
    (1.28, 0.054, 0.053, 0.053),
    (1.18, 0.049, 0.049, 0.049),
    (1.13, 0.047, 0.048, 0.050),
    (1.06, 0.048, 0.047, 0.046),
    (0.98, 0.042, 0.040, 0.039),
    (0.92, 0.038, 0.035, 0.035),
    (0.895, 0.036, 0.034, 0.034),
]


def build_arm(M):
    chain = [J["LeftUpperArm"], J["LeftLowerArm"], J["LeftHand"]]
    secs = []
    for z, a, bf, bb in ARM:
        c = limb_center(chain, z)
        if z > 1.45:
            c.x -= 0.012
        secs.append(dict(c=c, a=a, al=a * 0.95, bf=bf, bb=bb, n=2.1))
    sleeve = L.loft("SleeveL", secs, seg=28, steps=3, mat=M["sleeve"], region="armL")
    return sleeve


def build_hand(M):
    """Left gloved hand hanging down, palm toward the thigh (-X)."""
    w = J["LeftHand"]
    parts = []
    palm = []
    for dz, a, b, dx in ((0.0, 0.032, 0.020, 0.0), (-0.03, 0.040, 0.019, -0.002),
                         (-0.07, 0.043, 0.017, -0.004), (-0.095, 0.040, 0.015, -0.006)):
        palm.append(dict(c=(w.x + dx, w.y, w.z + dz), u=(0, 1, 0), v=(1, 0, 0), a=b, bf=a, bb=a, n=2.6))
    # u along Y? use u = X (thickness) and v = Y (width) for clarity.
    palm = [dict(c=s["c"], u=(1, 0, 0), v=(0, 1, 0), a=s["a"], bf=s["bf"], bb=s["bb"], n=2.6) for s in palm]
    p = L.loft("PalmL", palm, seg=20, steps=2, mat=M["glove"], region="handL")
    L.subsurf(p, 1)
    parts.append(p)
    fingers = ((-0.030, 0.080, 0.0098), (-0.010, 0.088, 0.0102), (0.010, 0.084, 0.0098), (0.029, 0.068, 0.0088))
    for i, (fy, length, r) in enumerate(fingers):
        base = V((w.x - 0.006, w.y + fy, w.z - 0.088))
        pts = []
        for k in range(6):
            t = k / 5
            curl = 0.55 * t * t
            pts.append(base + V((-length * math.sin(curl) * 0.9, 0, -length * t * math.cos(curl * 0.6))))
        widths = [r * (1.0 - 0.18 * k / 5) for k in range(6)]
        f = L.tube(f"FingerL{i}", pts, widths, seg=10, steps=2, mat=M["glove"], region="handL", hint=(1, 0, 0))
        parts.append(f)
    tpts = [V((w.x - 0.012, w.y - 0.036, w.z - 0.025)), V((w.x - 0.020, w.y - 0.050, w.z - 0.050)),
            V((w.x - 0.028, w.y - 0.054, w.z - 0.075)), V((w.x - 0.036, w.y - 0.052, w.z - 0.095))]
    th = L.tube("ThumbL", tpts, [0.012, 0.011, 0.0105, 0.009], seg=10, steps=2, mat=M["glove"],
                region="handL", hint=(1, 0, 0))
    L.subsurf(th, 1)
    parts.append(th)
    # Leather knuckle guard on the back of the hand (+X side).
    kg = L.rbox("KnuckleL", (w.x + 0.016, w.y, w.z - 0.075), (0.012, 0.074, 0.030), M["leather"], "handL",
                bevel=0.005)
    parts.append(kg)
    # Glove cuff.
    cuff = L.loft("GloveCuffL", [dict(c=(w.x - 0.001, w.y, w.z + 0.035), a=0.036, b=0.033, n=2.4),
                                 dict(c=(w.x, w.y, w.z - 0.005), a=0.036, b=0.033, n=2.4)],
                  seg=20, steps=1, mat=M["glove"], region="handL")
    L.subsurf(cuff, 1)
    parts.append(cuff)
    return parts
