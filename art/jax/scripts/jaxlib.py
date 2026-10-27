"""Geometry helpers for the procedural Jax Mercer model.

Everything is built directly in world space (meters, feet at z = 0, the
character faces -Y, so his left side is +X). Objects keep identity
transforms so object-space shader coordinates match world space.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

V = Vector
UP = V((0, 0, 1))


def smooth(e0, e1, x):
    """Smoothstep from e0 to e1 (works with e0 > e1 for a falling edge)."""
    if e0 == e1:
        return 1.0 if x >= e0 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def new_obj(name, verts, faces, mat=None, region=None, smooth_shade=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    obj = link(bpy.data.objects.new(name, me))
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if smooth_shade:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if mat:
        me.materials.append(mat)
    if region:
        obj["region"] = region
    return obj


def apply_mods(obj):
    """Bake all modifiers into the mesh data."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)
    return obj


def subsurf(obj, levels=1, apply=True):
    m = obj.modifiers.new("Sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    if apply:
        apply_mods(obj)
    return obj


def solidify(obj, thickness, offset=-1.0):
    m = obj.modifiers.new("Solid", "SOLIDIFY")
    m.thickness = thickness
    m.offset = offset
    m.use_even_offset = True
    apply_mods(obj)
    return obj


# ---------------------------------------------------------------------------
# Lofting: rings of superellipses swept through a list of key sections.
# A section is a dict: c (center), u, v (unit axes of the ring plane),
# a (half width along +u), al (half width along -u, defaults to a),
# bf (half depth along -v, the "front"), bb (half depth along +v),
# n (superellipse exponent, 2 = ellipse), g (front gap in degrees).
# ---------------------------------------------------------------------------

KEYS = ("cx", "cy", "cz", "ux", "uy", "uz", "vx", "vy", "vz", "a", "al", "bf", "bb", "n", "g")


def _pack(s):
    c, u, v = V(s["c"]), V(s.get("u", (1, 0, 0))), V(s.get("v", (0, 1, 0)))
    a = s["a"]
    b = s.get("b")
    bf = s.get("bf", b if b is not None else a)
    bb = s.get("bb", b if b is not None else a)
    return [c.x, c.y, c.z, u.x, u.y, u.z, v.x, v.y, v.z, a, s.get("al", a), bf, bb, s.get("n", 2.0), s.get("g", 0.0)]


def _catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return [
        0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
        for a, b, c, d in zip(p0, p1, p2, p3)
    ]


def _interp(packed, steps, closed):
    if steps <= 1 or len(packed) < 2:
        return packed
    out = []
    n = len(packed)
    count = n if closed else n - 1
    for i in range(count):
        p1 = packed[i]
        p2 = packed[(i + 1) % n]
        p0 = packed[i - 1] if (closed or i > 0) else [2 * x - y for x, y in zip(p1, p2)]
        if closed or i + 2 < n:
            p3 = packed[(i + 2) % n]
        else:
            p3 = [2 * x - y for x, y in zip(p2, p1)]
        for k in range(steps):
            out.append(_catmull(p0, p1, p2, p3, k / steps))
    if not closed:
        out.append(packed[-1])
    return out


def _se(t, n):
    c, s = math.cos(t), math.sin(t)
    e = 2.0 / n
    return math.copysign(abs(c) ** e, c), math.copysign(abs(s) ** e, s)


def loft(name, sections, seg=24, steps=2, cap0=True, cap1=True, closed_path=False,
         mat=None, region=None, shape=None):
    """Sweep rings through key sections. shape(ring_index_fraction, angle,
    point, center) may return a displaced point for extra sculpting."""
    packed = _interp([_pack(s) for s in sections], steps, closed_path)
    gap = max(p[14] for p in packed)
    open_ring = gap > 0.01
    verts, faces = [], []
    ring_n = seg + 1 if open_ring else seg
    for ri, p in enumerate(packed):
        c = V(p[0:3])
        u = V(p[3:6]).normalized()
        v = V(p[6:9])
        v = (v - u * v.dot(u)).normalized()
        a, al, bf, bb, n, g = p[9], p[10], p[11], p[12], max(p[13], 0.5), p[14]
        for j in range(ring_n):
            if open_ring:
                t0 = math.radians(-90 + g)
                t1 = math.radians(270 - g)
                t = t0 + (t1 - t0) * j / seg
            else:
                t = -math.pi / 2 + 2 * math.pi * j / seg
            x, y = _se(t, n)
            x *= a if x >= 0 else al
            y *= bb if y >= 0 else bf
            pt = c + u * x + v * y
            if shape:
                pt = shape(ri / max(1, len(packed) - 1), t, pt, c)
            verts.append(pt)
    rings = len(packed)
    seg_count = seg if not open_ring else seg
    for i in range(rings - 1 + (1 if closed_path else 0)):
        i2 = (i + 1) % rings
        for j in range(seg_count):
            j2 = j + 1 if open_ring else (j + 1) % seg
            faces.append((i * ring_n + j, i * ring_n + j2, i2 * ring_n + j2, i2 * ring_n + j))
    if not open_ring and not closed_path:
        if cap0:
            ci = len(verts)
            verts.append(V(packed[0][0:3]))
            for j in range(seg):
                faces.append((ci, (j + 1) % seg, j))
        if cap1:
            ci = len(verts)
            verts.append(V(packed[-1][0:3]))
            base = (rings - 1) * ring_n
            for j in range(seg):
                faces.append((ci, base + j, base + (j + 1) % seg))
    return new_obj(name, verts, faces, mat, region)


def frames_along(points, hint=None):
    """Rotation-minimizing frames (u, v) along a polyline."""
    pts = [V(p) for p in points]
    tans = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tans.append((b - a).normalized())
    h = V(hint) if hint else V((0, 0, 1))
    if abs(h.normalized().dot(tans[0])) > 0.95:
        h = V((1, 0, 0)) if abs(tans[0].x) < 0.9 else V((0, 1, 0))
    v = (h - tans[0] * h.dot(tans[0])).normalized()
    frames = []
    for i, t in enumerate(tans):
        v = (v - t * v.dot(t)).normalized()
        u = t.cross(v).normalized()
        frames.append((u, v))
    return frames


def tube(name, points, widths, thick=None, seg=10, steps=1, mat=None, region=None,
         hint=None, n=2.0, normals=None, cap0=True, cap1=True, closed_path=False):
    """Tube through points. widths: half width along u per point; thick: half
    depth along v per point (defaults to widths). normals: optional per-point
    v axis (for straps lying on a surface)."""
    pts = [V(p) for p in points]
    if normals:
        frames = []
        for i in range(len(pts)):
            a = pts[i - 1] if (closed_path or i > 0) else pts[i]
            b = pts[(i + 1) % len(pts)] if (closed_path or i + 1 < len(pts)) else pts[i]
            t = (b - a).normalized()
            vv = V(normals[i])
            vv = (vv - t * vv.dot(t)).normalized()
            frames.append((t.cross(vv).normalized(), vv))
    else:
        frames = frames_along(pts, hint)
    thick = thick or widths
    secs = []
    for p, (u, v), w, th in zip(pts, frames, widths, thick):
        secs.append(dict(c=p, u=u, v=v, a=max(w, 1e-4), b=max(th, 1e-4), n=n))
    return loft(name, secs, seg=seg, steps=steps, mat=mat, region=region,
                cap0=cap0, cap1=cap1, closed_path=closed_path)


def bvh_of(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(obj, dg)


def resample(points, count, closed=False):
    pts = [V(p) for p in points]
    if closed:
        pts = pts + [pts[0]]
    lens = [0.0]
    for a, b in zip(pts, pts[1:]):
        lens.append(lens[-1] + (b - a).length)
    total = lens[-1]
    out = []
    n = count if closed else count - 1
    for k in range(count):
        d = total * k / n
        for i in range(len(lens) - 1):
            if lens[i + 1] >= d - 1e-9:
                seg_len = max(lens[i + 1] - lens[i], 1e-9)
                out.append(pts[i].lerp(pts[i + 1], (d - lens[i]) / seg_len))
                break
    return out


def strap(name, targets, points, width, thick=0.004, offset=0.002, count=24, closed=False,
          mat=None, region=None, n=6.0):
    """A flat band lying on the surface of the target objects."""
    trees = [bvh_of(t) for t in targets]
    pts = resample(points, count, closed)
    locs, nors = [], []
    for p in pts:
        best = None
        for tr in trees:
            hit = tr.find_nearest(p)
            if hit[0] is not None and (best is None or hit[3] < best[3]):
                best = hit
        loc, nor = best[0], best[1]
        locs.append(loc)
        nors.append(nor)
    # Smooth normals along the path to avoid twisting.
    sm = []
    m = len(nors)
    for i in range(m):
        acc = V((0, 0, 0))
        for k in (-2, -1, 0, 1, 2):
            j = i + k
            if closed:
                j %= m
            elif j < 0 or j >= m:
                continue
            acc += nors[j]
        sm.append(acc.normalized())
    centers = [loc + nr * (offset + thick) for loc, nr in zip(locs, sm)]
    return tube(name, centers, [width / 2] * len(centers), [thick] * len(centers), seg=12,
                steps=1, mat=mat, region=region, normals=sm, n=n, closed_path=closed)


def rbox(name, center, dims, mat=None, region=None, rot=None, bevel=0.006, segments=3,
         frame=None):
    """Rounded box. frame=(x_axis, y_axis, z_axis) overrides rot (Euler)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vtx in bm.verts:
        vtx.co = V((vtx.co.x * dims[0], vtx.co.y * dims[1], vtx.co.z * dims[2]))
    if frame:
        mat3 = Matrix((frame[0], frame[1], frame[2])).transposed()
    elif rot:
        from mathutils import Euler
        mat3 = Euler(rot).to_matrix()
    else:
        mat3 = Matrix.Identity(3)
    for vtx in bm.verts:
        vtx.co = mat3 @ vtx.co + V(center)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    if bevel > 0:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = min(bevel, min(dims) * 0.45)
        b.segments = segments
        b.limit_method = "NONE"
        apply_mods(obj)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    if mat:
        obj.data.materials.append(mat)
    if region:
        obj["region"] = region
    return obj


def surface_frame(targets, approx, up=(0, 0, 1)):
    """Nearest surface point + a frame whose -Y faces out of the surface."""
    best = None
    for t in targets:
        hit = bvh_of(t).find_nearest(V(approx))
        if hit[0] is not None and (best is None or hit[3] < best[3]):
            best = hit
    loc, nor = best[0], best[1].normalized()
    y = -nor
    z = V(up)
    z = (z - y * z.dot(y)).normalized()
    x = y.cross(z).normalized()
    return loc, nor, (x, y, z)


def on_surface(name, targets, approx, dims, mat=None, region=None, sink=0.3, up=(0, 0, 1),
               bevel=0.006):
    loc, nor, fr = surface_frame(targets, approx, up)
    center = loc + nor * (dims[1] * (0.5 - sink))
    return rbox(name, center, dims, mat, region, frame=fr, bevel=bevel)


def ellipsoid(name, center, radii, mat=None, region=None, seg=24, rings=12, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    from mathutils import Euler
    m3 = Euler(rot).to_matrix() if rot else Matrix.Identity(3)
    for vtx in bm.verts:
        vtx.co = m3 @ V((vtx.co.x * radii[0], vtx.co.y * radii[1], vtx.co.z * radii[2])) + V(center)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if mat:
        me.materials.append(mat)
    if region:
        obj["region"] = region
    return obj


def mirror_obj(src, name, region=None):
    """Mirror across X into a new object (normals recomputed)."""
    me = src.data.copy()
    me.name = name
    for vtx in me.vertices:
        vtx.co.x = -vtx.co.x
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = link(bpy.data.objects.new(name, me))
    for k in src.keys():
        obj[k] = src[k]
    if region:
        obj["region"] = region
    return obj


def displace(obj, brushes):
    """Gaussian sculpt brushes: (center, radii(x,y,z), offset vector)."""
    for vtx in obj.data.vertices:
        p = vtx.co
        d = V((0, 0, 0))
        for c, r, off in brushes:
            q = ((p.x - c[0]) / r[0]) ** 2 + ((p.y - c[1]) / r[1]) ** 2 + ((p.z - c[2]) / r[2]) ** 2
            if q < 9:
                d += V(off) * math.exp(-q)
        vtx.co = p + d


def set_mask(obj, fn):
    """Per-vertex RGBA 'mask' attribute used by the shaders."""
    me = obj.data
    attr = me.color_attributes.get("mask") or me.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
    vals = []
    for vtx in me.vertices:
        r, g, b = fn(vtx.co, vtx.normal)
        vals.extend((r, g, b, 1.0))
    attr.data.foreach_set("color", vals)


def ensure_mask(obj):
    me = obj.data
    if "mask" not in me.color_attributes:
        attr = me.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
        attr.data.foreach_set("color", [0.0, 0.0, 0.0, 1.0] * len(me.vertices))


rng = random.Random(7)
