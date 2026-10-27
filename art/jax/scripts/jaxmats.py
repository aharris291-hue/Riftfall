"""Procedural materials for Jax. They are baked to PBR textures for Roblox."""

import bpy


def _base(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m, nt, bsdf


def _noise(nt, scale, detail=6.0, rough=0.6, coord="Object"):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = detail
    nz.inputs["Roughness"].default_value = rough
    nt.links.new(tc.outputs[coord], nz.inputs["Vector"])
    return nz


def _ramp(nt, fac_socket, c0, c1, p0=0.3, p1=0.7):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position = p0
    r.color_ramp.elements[0].color = (*c0, 1)
    r.color_ramp.elements[1].position = p1
    r.color_ramp.elements[1].color = (*c1, 1)
    nt.links.new(fac_socket, r.inputs["Fac"])
    return r


def _bump(nt, bsdf, height_socket, strength, distance=0.02):
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    b.inputs["Distance"].default_value = distance
    nt.links.new(height_socket, b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    return b


def _mask(nt):
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "mask"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(a.outputs["Color"], sep.inputs["Color"])
    return sep


def _mix(nt, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    if isinstance(fac, float):
        m.inputs[0].default_value = fac
    else:
        nt.links.new(fac, m.inputs[0])
    for sock, val in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(val, tuple):
            sock.default_value = (*val, 1) if len(val) == 3 else val
        else:
            nt.links.new(val, sock)
    return m.outputs[2]


def fabric(name, c0, c1, rough=0.85, scale=90.0, bump=0.25, sheen=0.0):
    m, nt, bsdf = _base(name)
    nz = _noise(nt, scale, 8, 0.7)
    big = _noise(nt, scale / 12, 4, 0.5)
    r = _ramp(nt, big.outputs["Fac"], c0, c1, 0.35, 0.65)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    _bump(nt, bsdf, nz.outputs["Fac"], bump, 0.01)
    return m


def leather(name, c0, c1, rough=0.55, scale=40.0):
    m, nt, bsdf = _base(name)
    nz = _noise(nt, scale, 10, 0.75)
    big = _noise(nt, scale / 8, 3, 0.5)
    r = _ramp(nt, big.outputs["Fac"], c0, c1, 0.3, 0.7)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    rr = _ramp(nt, nz.outputs["Fac"], (rough - 0.12,) * 3, (rough + 0.12,) * 3)
    nt.links.new(rr.outputs["Color"], bsdf.inputs["Roughness"])
    _bump(nt, bsdf, nz.outputs["Fac"], 0.35, 0.01)
    return m


def metal(name, c0, c1, rough=0.35, metallic=1.0):
    m, nt, bsdf = _base(name)
    nz = _noise(nt, 25.0, 12, 0.8)
    r = _ramp(nt, nz.outputs["Fac"], c0, c1, 0.25, 0.75)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metallic
    rr = _ramp(nt, nz.outputs["Fac"], (rough - 0.15,) * 3, (rough + 0.2,) * 3)
    nt.links.new(rr.outputs["Color"], bsdf.inputs["Roughness"])
    _bump(nt, bsdf, nz.outputs["Fac"], 0.15, 0.005)
    return m


def glow(name, color, strength=8.0):
    m, nt, bsdf = _base(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Roughness"].default_value = 0.2
    return m


def skin(name):
    """Skin with hair-cap (R), lips (G) and stubble (B) from the mask attribute."""
    m, nt, bsdf = _base(name)
    sep = _mask(nt)
    nz = _noise(nt, 120.0, 6, 0.6)
    base = _ramp(nt, nz.outputs["Fac"], (0.47, 0.29, 0.20), (0.55, 0.35, 0.25), 0.3, 0.7)
    col = _mix(nt, sep.outputs["Green"], base.outputs["Color"], (0.40, 0.17, 0.14))
    col = _mix(nt, sep.outputs["Blue"], col, (0.27, 0.18, 0.14))
    col = _mix(nt, sep.outputs["Red"], col, (0.030, 0.019, 0.013))
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Subsurface Weight"].default_value = 0.15
    bsdf.inputs["Subsurface Radius"].default_value = (0.4, 0.15, 0.08)
    _bump(nt, bsdf, nz.outputs["Fac"], 0.08, 0.003)
    return m


def eye(name):
    """Sclera / iris (G) / pupil (B)."""
    m, nt, bsdf = _base(name)
    sep = _mask(nt)
    col = _mix(nt, sep.outputs["Green"], (0.78, 0.76, 0.72), (0.16, 0.09, 0.045))
    col = _mix(nt, sep.outputs["Blue"], col, (0.01, 0.01, 0.01))
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Coat Weight"].default_value = 0.5
    return m


def lid(name):
    """Eyelid skin with a dark lash line (R)."""
    m, nt, bsdf = _base(name)
    sep = _mask(nt)
    col = _mix(nt, sep.outputs["Red"], (0.45, 0.28, 0.20), (0.025, 0.017, 0.012))
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def hair(name):
    """Dark brown hair, lighter toward the tips (mask R)."""
    m, nt, bsdf = _base(name)
    sep = _mask(nt)
    nz = _noise(nt, 300.0, 4, 0.5)
    stripes = nt.nodes.new("ShaderNodeTexWave")
    stripes.inputs["Scale"].default_value = 260.0
    stripes.inputs["Distortion"].default_value = 6.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], stripes.inputs["Vector"])
    root = _ramp(nt, stripes.outputs["Fac"], (0.020, 0.013, 0.009), (0.050, 0.032, 0.020), 0.2, 0.9)
    col = _mix(nt, sep.outputs["Red"], root.outputs["Color"], (0.085, 0.056, 0.034))
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.42
    _bump(nt, bsdf, stripes.outputs["Fac"], 0.08, 0.002)
    return m


def all_materials():
    return dict(
        skin=skin("M_Skin"),
        eye=eye("M_Eye"),
        lid=lid("M_Lid"),
        hair=hair("M_Hair"),
        brow=fabric("M_Brow", (0.025, 0.016, 0.011), (0.04, 0.026, 0.017), 0.6, 400, 0.1),
        jacket=leather("M_Jacket", (0.030, 0.034, 0.042), (0.055, 0.060, 0.072), 0.5, 30),
        sleeve=fabric("M_Sleeve", (0.028, 0.032, 0.040), (0.050, 0.055, 0.066), 0.75, 80, 0.3),
        shirt=fabric("M_Shirt", (0.16, 0.16, 0.17), (0.24, 0.24, 0.25), 0.9, 120, 0.2),
        pants=fabric("M_Pants", (0.026, 0.030, 0.042), (0.048, 0.054, 0.070), 0.82, 110, 0.35),
        leather=leather("M_Leather", (0.11, 0.058, 0.030), (0.20, 0.11, 0.055), 0.55, 35),
        darkleather=leather("M_DarkLeather", (0.045, 0.028, 0.018), (0.08, 0.05, 0.03), 0.6, 35),
        webbing=fabric("M_Webbing", (0.07, 0.045, 0.028), (0.12, 0.075, 0.045), 0.8, 200, 0.4),
        glove=leather("M_Glove", (0.020, 0.020, 0.023), (0.040, 0.040, 0.045), 0.5, 60),
        metal=metal("M_Metal", (0.30, 0.31, 0.33), (0.52, 0.53, 0.55), 0.38),
        gunmetal=metal("M_Gunmetal", (0.08, 0.085, 0.09), (0.16, 0.165, 0.17), 0.45),
        sole=fabric("M_Sole", (0.015, 0.014, 0.013), (0.03, 0.028, 0.026), 0.92, 60, 0.4),
        pack=fabric("M_Pack", (0.07, 0.10, 0.105), (0.11, 0.15, 0.155), 0.8, 90, 0.35),
        glow=glow("M_Glow", (0.10, 0.75, 1.0), 10.0),
    )
