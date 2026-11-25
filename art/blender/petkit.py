"""Pet kit, third generation: clay (2026-11-23; see the pets report and reviews/pets/).

History of what went wrong, each fixed here:
  gen 1 (sculpt.py)  stacked balls: lumps, facets, faces made of pieces, flat colours.
  gen 2              one skin from a voxel remesh, painted faces. Lemp: "way better", but "the head of each is just
                     a round bubble" and later "the smoothness of the pets is not there yet". Measured causes: the
                     exported skin was flat-shaded (0 of ~6,500 faces smooth), the joins between balls still showed
                     as lumps and ridges, and collapse-decimation left uneven triangles.
  gen 3 (this)       soft shapes are a DISTANCE FIELD: every ball, cone and limb is a formula, and they are joined
                     with a smooth union, like pressing clay together. No ridges, real fillets, and shapes can be
                     pressed IN (eye sockets, mouths). The field is meshed with OpenVDB (inside Blender), rebuilt as
                     even quads with QuadriFlow, shrink-wrapped back, and shaded with the normals of the dense clay.

Roles
  soft  part of the clay skin.  k = how far it melts into its neighbours (0.04 crisp tuft ... 0.2 one volume).
  cut   pressed into the clay (role="cut"): sockets, mouth, nostrils, the hollow of an ear.
  hard  keeps its own crisp geometry (claws, horns, crystals, wing skins, eyeballs).
  mark  PAINT ONLY: baked onto the skin (irises, mouth, blush, belly, stripes, socks), never a bump.
  glow  separate Neon parts named c_R_G_B, as the game expects (small and few).

The paint is baked from the dense clay (colours blend softly where shapes melt) plus the marks: gradients, a soft
top-left light, tinted shadow in the creases, a little mottling. scripts/pet_paint.py then lays hand-painted
surface on top and leaves the "keep" marks (eyes, mouth) crisp. Front of a pet faces -Y, up is +Z, about 2.2 tall.

Use:  import petkit as K;  K.start();  head = K.head(...);  K.eyes(head, ...);  K.finish("pet_x", out_fbx, 8000)
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Quaternion, Vector

import lib

rad = math.radians
WHITE = (1, 1, 1)
INK = (0.16, 0.09, 0.07)       # warm dark outline colour of the target pictures (never pure black)
_mats = {}
_clay = []                      # the soft and cut shapes, as formulas


def start():
    lib.reset()
    _mats.clear()
    _clay.clear()


def _lin(c):
    return tuple(v ** 2.2 if v <= 1 else v for v in c)


def material(color, color2=None, axis="Z", lit=True, mottle=0.05, linear=False, keep=False, attr=None):
    """Painted colour for baking. color2 = second colour for a gradient along `axis` of the shape (color at the
    low end, color2 at the high end). lit=False keeps the colour exactly (eye shines, pupils). attr = take the
    colour from that colour attribute of the mesh instead (the clay)."""
    key = (tuple(color), tuple(color2) if color2 else None, axis, lit, mottle, linear, keep, attr)
    if key in _mats:
        return _mats[key]
    mat = bpy.data.materials.new(("keep_%d" if keep else "paint_%d") % len(_mats))
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes.new, nt.links.new
    coords = n("ShaderNodeTexCoord")
    if attr:
        a = n("ShaderNodeAttribute")
        a.attribute_name = attr
        base = a.outputs["Color"]
    else:
        rgb = n("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*_lin(color), 1)
        base = rgb.outputs[0]
    if color2 and not attr:
        ga = n("ShaderNodeAttribute")
        ga.attribute_name = "grad"   # 0..1 along the shape's own axis, stored when the shape is made
        smooth = n("ShaderNodeMapRange")
        smooth.interpolation_type = "LINEAR" if linear else "SMOOTHSTEP"
        smooth.inputs["From Min"].default_value = 0.0 if linear else 0.12
        smooth.inputs["From Max"].default_value = 1.0 if linear else 0.88
        link(ga.outputs["Fac"], smooth.inputs["Value"])
        rgb2 = n("ShaderNodeRGB")
        rgb2.outputs[0].default_value = (*_lin(color2), 1)
        mix = n("ShaderNodeMix")
        mix.data_type = "RGBA"
        link(smooth.outputs["Result"], mix.inputs["Factor"])
        link(base, mix.inputs[6])
        link(rgb2.outputs[0], mix.inputs[7])
        base = mix.outputs[2]
    if lit:
        # light from the top, a little from the front-left; undersides fall into a cool violet shade
        geo = n("ShaderNodeNewGeometry")
        dot = n("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        link(geo.outputs["Normal"], dot.inputs[0])
        dot.inputs[1].default_value = Vector((-0.25, -0.3, 0.92)).normalized()
        light = n("ShaderNodeMapRange")
        light.inputs["From Min"].default_value = -1
        light.inputs["From Max"].default_value = 1
        light.inputs["To Min"].default_value = 0.3
        light.inputs["To Max"].default_value = 1.0
        link(dot.outputs["Value"], light.inputs["Value"])
        ao = n("ShaderNodeAmbientOcclusion")
        ao.only_local = True
        ao.samples = 16
        ao.inputs["Distance"].default_value = 0.5
        ao_r = n("ShaderNodeMapRange")
        ao_r.inputs["From Min"].default_value = 0.3
        ao_r.inputs["To Min"].default_value = 0.0
        link(ao.outputs["AO"], ao_r.inputs["Value"])
        both = n("ShaderNodeMath")
        both.operation = "MULTIPLY"
        link(light.outputs["Result"], both.inputs[0])
        link(ao_r.outputs["Result"], both.inputs[1])
        shade = n("ShaderNodeMix")
        shade.data_type = "RGBA"
        link(both.outputs["Value"], shade.inputs["Factor"])
        shade.inputs[6].default_value = (0.46, 0.38, 0.54, 1)   # deepest shadow tint
        shade.inputs[7].default_value = (1.06, 1.04, 1.0, 1)    # lit
        mul = n("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        link(base, mul.inputs[6])
        link(shade.outputs[2], mul.inputs[7])
        base = mul.outputs[2]
        if mottle:
            noise = n("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 3.2
            noise.inputs["Detail"].default_value = 2.0
            link(coords.outputs["Object"], noise.inputs["Vector"])
            nr = n("ShaderNodeMapRange")
            nr.inputs["From Min"].default_value = 0.3
            nr.inputs["From Max"].default_value = 0.7
            nr.inputs["To Min"].default_value = 1 - mottle
            nr.inputs["To Max"].default_value = 1 + mottle
            link(noise.outputs["Fac"], nr.inputs["Value"])
            mul2 = n("ShaderNodeVectorMath")
            mul2.operation = "SCALE"
            link(base, mul2.inputs[0])
            link(nr.outputs["Result"], mul2.inputs["Scale"])
            base = mul2.outputs["Vector"]
    emit = n("ShaderNodeEmission")
    link(base, emit.inputs["Color"])
    out = n("ShaderNodeOutputMaterial")
    link(emit.outputs["Emission"], out.inputs["Surface"])
    _mats[key] = mat
    return mat


def _grad(o, axis):
    """Stores 0..1 along `axis` (a letter or a direction in the shape's own space) on every point, for gradients."""
    d = Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis]) if isinstance(axis, str) else Vector(axis).normalized()
    vals = [v.co.dot(d) for v in o.data.vertices]
    lo, hi = min(vals), max(vals)
    a = o.data.attributes.get("grad") or o.data.attributes.new("grad", "FLOAT", "POINT")
    for i, v in enumerate(vals):
        a.data[i].value = (v - lo) / (hi - lo) if hi > lo else 0.0


def _finish_piece(o, name, color, role, color2=None, axis="Z", lit=True, flat=False, linear=False, keep=False):
    o.name = name
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if axis is not None:
        _grad(o, axis)
    if flat:
        bpy.ops.object.shade_flat()
    else:
        bpy.ops.object.shade_smooth()
    o["role"] = role
    if role == "glow":
        o["htd_color"] = list(color)
    else:
        o.data.materials.clear()
        o.data.materials.append(material(color, color2, axis, lit, linear=linear, keep=keep))
    return o


# ---- clay: shapes as formulas ------------------------------------------------------------------------------------
K_BALL, K_CONE, K_LIMB, K_HEAD = 0.10, 0.05, 0.08, 0.2


def _clay_add(kind, role, k, color, color2, **p):
    # color None (cuts only): the pressed-in area keeps the colour of the clay around it
    _clay.append({"kind": kind, "cut": role == "cut", "k": k, "c1": _lin(color) if color else None, "c2": _lin(color2) if color2 else None, **p})


def _matrix(rot):
    """local-to-world rotation as a 3x3 numpy array, from Euler angles or a quaternion"""
    m = rot.to_matrix() if isinstance(rot, Quaternion) else Euler(rot, "XYZ").to_matrix()
    return np.array([list(r) for r in m], dtype=np.float64)


def ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=32, role="soft", color2=None, axis="Z", lit=True, k=None):
    """An egg / ball. Returns a handle with its centre and half-sizes so eyes and patches can be put ON it (on())."""
    half = [radius * s for s in scale]
    if role in ("soft", "cut"):
        _clay_add("ell", role, K_BALL if k is None else k, color, color2, c=list(pos), r=half, M=_matrix(rot), axis="XYZ".index(axis))
        return {"center": list(pos), "half": half, "name": name}
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=seg, ring_count=max(6, seg // 2), location=pos, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    o["center"] = list(pos)
    o["half"] = half
    return _finish_piece(o, name, color, role, color2, axis, lit)


def rock(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), role="hard", seed=0, color2=None):
    """A chunky faceted stone (flat shaded, a few big planes)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    import random
    rnd = random.Random(seed * 7919 + 13)
    for v in o.data.vertices:
        v.co *= 0.86 + rnd.random() * 0.28
    o["center"] = list(pos)
    o["half"] = [radius * s for s in scale]
    o = _finish_piece(o, name, color, role, color2, flat=True)
    bev = o.modifiers.new("b", "BEVEL")
    bev.width = radius * 0.07
    bev.segments = 1
    bpy.ops.object.modifier_apply(modifier=bev.name)
    return o


def cone(name, pos, r, h, color, rot=(0, 0, 0), top=0.0, verts=16, scale=(1, 1, 1), role="soft", color2=None, flat=False, k=None):
    """A cone standing on its base (radius r) with its tip (radius top) h higher, before rot and scale."""
    if role in ("soft", "cut"):
        _clay_add("cone", role, K_CONE if k is None else k, color, color2, c=list(pos), M=_matrix(rot), s=list(scale),
                  z0=-h / 2, z1=h / 2, r0=r, r1=max(top, 0.012), linear=False)
        return {"center": list(pos), "half": [r * scale[0], r * scale[1], h / 2 * scale[2]], "name": name}
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish_piece(o, name, color, role, color2, flat=flat)


def limb(name, a, b, r0, r1, color, verts=16, role="soft", color2=None, cap=True, linear=False, k=None):
    """A tapered tube from a to b with round ends."""
    va, vb = Vector(a), Vector(b)
    d = vb - va
    q = d.to_track_quat("Z", "Y")
    if role in ("soft", "cut"):
        _clay_add("cone", role, K_LIMB if k is None else k, color, color2, c=list(va), M=_matrix(q), s=[1, 1, 1],
                  z0=0.0, z1=d.length, r0=r0, r1=r1, linear=linear)
        return {"center": list((va + vb) / 2), "half": [max(r0, r1)] * 3, "name": name}
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length, vertices=verts, location=(va + vb) / 2)
    o = bpy.context.active_object
    o.rotation_euler = q.to_euler()
    _finish_piece(o, name, color, role, color2, linear=linear)
    if cap:
        ball(name + "A", a, r0, color, seg=verts, role=role)
        ball(name + "B", b, r1, color2 or color, seg=verts, role=role)
    return o


def chain(name, points, radii, color, verts=16, role="soft", color2=None, k=None):
    """A bending limb (tail, neck, horn): tapered tubes through the points. color2 = colour at the far end."""
    n = len(points) - 1
    for i in range(n):
        if color2:
            c0 = tuple(color[j] + (color2[j] - color[j]) * i / n for j in range(3))
            c1 = tuple(color[j] + (color2[j] - color[j]) * (i + 1) / n for j in range(3))
        else:
            c0 = c1 = color
        limb(f"{name}{i}", points[i], points[i + 1], radii[i], radii[i + 1], c0, verts, role, c1 if color2 else None, cap=role != "soft", linear=True, k=k)


def _spline(vals, t):
    n = len(vals) - 1
    i = min(int(t * n), n - 1)
    u = t * n - i
    p0, p1, p2, p3 = vals[max(i - 1, 0)], vals[i], vals[i + 1], vals[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def rope(name, points, radii, color, color2=None, n=26, role="soft", squash=(1, 1, 1), k=None):
    """A fat soft tail, neck or lock of hair: one flowing shape along a smooth curve through the points, thick as
    given by radii. color2 = colour at the far end. squash flattens it along the world axes."""
    pts, rr = [], []
    for j in range(n):
        t = j / (n - 1)
        pts.append(tuple(_spline([p[i] for p in points], t) for i in range(3)))
        rr.append(max(0.02, _spline(radii, t)))
    if squash == (1, 1, 1) and role == "soft":
        chain(name, pts, rr, color, role=role, color2=color2, k=K_LIMB if k is None else k)
        return
    for j in range(n):
        t = j / (n - 1)
        c = tuple(color[i] + (color2[i] - color[i]) * t for i in range(3)) if color2 else color
        ball(f"{name}{j}", pts[j], rr[j], c, squash, seg=24, role=role, k=K_LIMB if k is None else k)


def head(name, pos, r, color, color2=None, wide=1.12, cheeks=0.6, cheek_drop=0.36, jaw=0.5, brow=0.32, flat_top=0.0,
         cheek_color=None, back=0.25, k=K_HEAD):
    """A real head instead of a bubble (Lemp 2026-11-23): a skull with full cheeks set low and wide, a jaw, a soft
    brow over the eyes and a rounder back, all melted into ONE volume (k). Sizes are fractions of r.
      wide        how wide the skull is            cheeks / cheek_drop   cheek size and how low they sit
      jaw         chin size (0 = none)             brow                  brow ridge size (0 = none)
      flat_top    0..0.3 flattens the crown        back                  how far the skull reaches back
    Returns the skull handle: eyes(), patch() and smile() are aimed with it and then pressed onto the real surface."""
    x, y, z = pos
    skull = ball(name, pos, r, color, (wide, 1.0, 0.94 - flat_top), color2=color2, k=k)
    ball(name + "Back", (x, y + r * back, z + r * 0.08), r * 0.86, color, (wide * 0.96, 1.0, 0.9), color2=color2, k=k)
    cc = cheek_color or color
    for s in (-1, 1):
        if cheeks:
            ball(f"{name}Cheek{s}", (x + s * r * 0.5 * wide, y - r * 0.3, z - r * cheek_drop), r * cheeks, cc, (1.0, 0.95, 0.86),
                 color2=color2 if not cheek_color else None, k=k)
        if brow:
            ball(f"{name}Brow{s}", (x + s * r * 0.42 * wide, y - r * 0.6, z + r * 0.42), r * brow, color2 or color, (1.5, 0.8, 0.62),
                 rot=(0, rad(s * -10), 0), k=k)
    if jaw:
        ball(name + "Jaw", (x, y - r * 0.42, z - r * 0.62), r * jaw, cc, (1.25, 1.0, 0.66), k=k)
    return skull


def on(body, direction):
    """The point on a ball in a direction (x, y, z as seen from its centre) and the surface normal there."""
    c, h = Vector(body["center"]), body["half"]
    u = Vector(direction).normalized()
    # scale the direction so the point really lies in that direction on the ellipsoid
    t = 1 / math.sqrt((u.x / h[0]) ** 2 + (u.y / h[1]) ** 2 + (u.z / h[2]) ** 2)
    p = c + u * t
    nrm = Vector(((p.x - c.x) / h[0] ** 2, (p.y - c.y) / h[1] ** 2, (p.z - c.z) / h[2] ** 2)).normalized()
    return p, nrm


def patch(body, direction, radius, color, stretch=(1, 1), roll=0.0, lift=0.03, role="mark", name="Patch", color2=None,
          axis="Z", lit=True, bulge=0.5, seg=24, cut=None, keep=False, wrap=True, k=None, depth=None):
    """An area on a ball at `direction`. stretch = (sideways, up) factors, roll = turn in degrees.
    role="mark"  paint only: a thin sheet `lift` above the skin (higher marks paint over lower ones); wrap=False
                 keeps it exactly on the given ball (marks on a hard eyeball) instead of pressing it on the clay.
    role="soft"  a soft bump (muzzle, cheek).      role="cut"  pressed in (socket, mouth), `depth` deep."""
    p, nrm = on(body, direction)
    if role == "mark":
        c = Vector(body["center"])
        up = (Vector((0, 0, 1)) - nrm * nrm.z)
        up = up.normalized() if up.length > 1e-4 else Vector((0, -1, 0))
        right = up.cross(nrm).normalized()
        ca, sa = math.cos(rad(roll)), math.sin(rad(roll))
        ax, ay = right * ca + up * sa, up * ca - right * sa
        rings = 6
        pts = [tuple(p + nrm * lift)]
        for i in range(1, rings + 1):
            for j in range(seg):
                t = 2 * math.pi * j / seg
                yy = math.sin(t) * radius * stretch[1] * i / rings
                if cut is not None:   # a flat top edge: the upper part of the oval is cut off (smiles)
                    yy = min(yy, cut * radius * stretch[1])
                flat_pt = p + ax * (math.cos(t) * radius * stretch[0] * i / rings) + ay * yy
                q, qn = on(body, flat_pt - c)
                pts.append(tuple(q + qn * lift))
        faces = [(0, 1 + j, 1 + (j + 1) % seg) for j in range(seg)]
        for i in range(1, rings):
            a0, b0 = 1 + (i - 1) * seg, 1 + i * seg
            faces += [(a0 + j, b0 + j, b0 + (j + 1) % seg, a0 + (j + 1) % seg) for j in range(seg)]
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(pts, [], faces)
        mesh.update()
        o = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(o)
        o["center"] = list(p)
        if wrap:
            o["lift"] = lift
        _finish_piece(o, name, color, role, color2, None, lit, keep=keep)
        _grad(o, ay if axis == "Y" else ax if axis == "X" else Vector((0, 0, 1)))
        return o
    # a lens lying on (soft) or pressed into (cut) the surface: local Z along the normal, local Y "up" on the surface
    q = nrm.to_track_quat("Z", "Y") @ Quaternion((0, 0, 1), rad(roll))
    if role == "cut":
        d = depth if depth is not None else radius * 0.3
        centre = p + nrm * (d * 0.15)
        half = [radius * stretch[0], radius * stretch[1], d]
    else:
        d = max(radius * bulge * 0.35, lift * 2.2)
        centre = p + nrm * (lift - d)
        half = [radius * stretch[0], radius * stretch[1], d]
    _clay_add("ell", role, (K_BALL if role == "soft" else 0.06) if k is None else k, color, color2, c=list(centre), r=half, M=_matrix(q), axis=2)
    return {"center": list(centre), "half": half, "name": name}


def eye(body, direction, r, iris=(0.86, 0.50, 0.10), iris_dark=(0.36, 0.16, 0.05), side=1, tall=1.18, look=(0.0, 0.0),
        lash=False, name="Eye"):
    """One big glossy painted eye in the style of the target pictures: dark warm outline, amber iris that is dark at
    the top and bright at the bottom, a big pupil and two white shines (big one top-left, small one bottom-right).
    side = -1 for the pet's right eye (mirrors the roll). All paint, no bumps."""
    roll = side * 5   # tops lean a little outwards: open and friendly (leaning inwards reads as worried)
    patch(body, direction, r, INK, (1.0, tall), roll, 0.016, name=name + "Rim", lit=False, keep=True)
    patch(body, direction, r * 0.91, iris, (1.0, tall), roll, 0.022, name=name + "Iris", color2=iris_dark, axis="Y", lit=False, keep=True)
    p, nrm = on(body, direction)
    # directions on the surface: right (screen right when seen from the front) and up
    up = (Vector((0, 0, 1)) - nrm * nrm.z).normalized()
    right = up.cross(nrm).normalized()

    def at(dx, dz):
        q = p + right * dx * r + up * dz * r * tall
        return tuple(q - Vector(body["center"]))

    patch(body, at(look[0] * 0.2, 0.14 + look[1] * 0.2), r * 0.60, (0.07, 0.04, 0.05), (1.0, tall), roll, 0.028, name=name + "Pupil", lit=False, keep=True)
    patch(body, at(-0.36, 0.44), r * 0.36, WHITE, (1.0, 1.2), -24, 0.036, name=name + "Shine", lit=False, keep=True)
    patch(body, at(0.36, -0.44), r * 0.17, WHITE, (1.0, 1.0), 0, 0.036, name=name + "Shine2", lit=False, keep=True)
    if lash:
        patch(body, at(side * 0.98, 0.62), r * 0.3, INK, (1.2, 0.3), side * -35, 0.02, name=name + "Lash", lit=False, keep=True)


def eyes(body, x, z, r, y=-1.0, socket=0.0, **kw):
    """Both eyes: x = how far apart (direction units), z = height on the head (direction units).
    socket > 0 first presses a shallow dish into the clay for each eye (that deep), so the eye sits IN the face."""
    for s in (-1, 1):
        if socket:
            patch(body, (s * x, y, z), r * 1.25, None, (1.0, kw.get("tall", 1.18)), 0, role="cut", depth=socket, k=0.1, name=f"Socket{s}")
        eye(body, (s * x, y, z), r, side=s, name=f"Eye{s}", **kw)


def brow(body, x, z, r, color=INK, y=-1.0, tilt=12):
    """Small happy eyebrows (raised outwards). Sad or angry brows are the first thing that kills a cute face."""
    for s in (-1, 1):
        patch(body, (s * x, y, z), r, color, (1.0, 0.22), s * -tilt, 0.02, name=f"Brow{s}", lit=False)


def smile(body, z, w, y=-1.0, x=0.0, tongue=(0.96, 0.46, 0.50), inside=(0.42, 0.10, 0.12), skin=None, open_=True):
    """A happy open mouth painted on: a wide D shape (flat on top, round below) with a tongue. Closed: a short
    curved line."""
    if not open_:
        for s in (-1, 1):
            patch(body, (x + s * w * 0.5, y, z), w * 0.55, INK, (1.0, 0.22), s * 18, 0.02, name="SmileLine", lit=False, keep=True)
        return
    # a D shape: an oval with its top cut flat, dark outline, pink tongue at the bottom
    patch(body, (x, y, z), w, INK, (1.0, 0.92), 0, 0.016, name="MouthRim", lit=False, cut=0.30, keep=True)
    patch(body, (x, y, z), w * 0.88, inside, (1.0, 0.90), 0, 0.022, name="Mouth", lit=False, cut=0.22, keep=True)
    p, nrm = on(body, (x, y, z))
    up = (Vector((0, 0, 1)) - nrm * nrm.z).normalized()
    c = Vector(body["center"])
    patch(body, tuple(p - up * w * 0.5 - c), w * 0.52, tongue, (1.0, 0.62), 0, 0.028, name="Tongue", lit=False, keep=True)


def blush(body, x, z, r, y=-1.0, color=(1.0, 0.56, 0.50)):
    for s in (-1, 1):
        patch(body, (s * x, y, z), r, color, (1.25, 0.75), 0, 0.018, name=f"Blush{s}")


def sheet(name, points, faces, color, thickness=0.05, role="hard", color2=None, axis="Z"):
    """A thin skin between points (wings, fins, leaves)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    for f in faces:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return _finish_piece(o, name, color, role, color2, axis)


def leaf(name, base, tip, width, color, color2=None, thick=0.07, role="hard", bend=0.15, up=(0, 0, 1)):
    """A leaf / feather / flame tongue from base to tip: pointed at both ends, widest a third along, slightly
    cupped. color at the base, color2 at the tip."""
    a, b = Vector(base), Vector(tip)
    d = b - a
    side = d.cross(Vector(up))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    nrm = side.cross(d).normalized()
    n = 7
    pts, faces = [], []
    for i in range(n + 1):
        t = i / n
        w = width * math.sin(math.pi * t ** 0.7) * (1 - 0.25 * t)
        mid = a + d * t + nrm * bend * d.length * math.sin(math.pi * t)
        pts += [tuple(mid - side * w - nrm * w * 0.25), tuple(mid), tuple(mid + side * w - nrm * w * 0.25)]
    for i in range(n):
        j = i * 3
        faces += [(j, j + 1, j + 4, j + 3), (j + 1, j + 2, j + 5, j + 4)]
    o = sheet(name, pts, faces, color, thick, role, color2, "Z")
    sub = o.modifiers.new("sub", "SUBSURF")   # a smooth blade instead of a folded strip
    sub.levels = 1
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=sub.name)
    if color2:
        _grad(o, d)
    return o


# ---- clay: from formulas to a mesh --------------------------------------------------------------------------------
def _sd_ellipsoid(qx, qy, qz, r):
    k0 = np.sqrt((qx / r[0]) ** 2 + (qy / r[1]) ** 2 + (qz / r[2]) ** 2)
    k1 = np.sqrt((qx / r[0] ** 2) ** 2 + (qy / r[1] ** 2) ** 2 + (qz / r[2] ** 2) ** 2)
    return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -min(r))


def _sd_round_cone(qx, qy, qz, z0, z1, r0, r1):
    """distance to a cone with round ends along local Z: radius r0 at z0, r1 at z1 (exact)"""
    h = z1 - z0
    rr = r0 - r1
    if h * h - rr * rr <= 1e-9:   # one end swallows the other: a ball
        zc = z0 if r0 >= r1 else z1
        return np.sqrt(qx * qx + qy * qy + (qz - zc) ** 2) - max(r0, r1)
    l2 = h * h
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    y = (qz - z0) * h
    z = y - l2
    x2 = l2 * l2 * (qx * qx + qy * qy)
    y2 = y * y * l2
    z2 = z * z * l2
    kk = np.sign(rr) * rr * rr * x2
    d_far = np.sqrt(x2 + z2) * il2 - r1
    d_near = np.sqrt(x2 + y2) * il2 - r0
    d_mid = (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - r0
    return np.where(np.sign(z) * a2 * z2 > kk, d_far, np.where(np.sign(y) * a2 * y2 < kk, d_near, d_mid))


def _clay_field(voxel):
    """Evaluates all shapes on a grid: distance D (negative inside) and colour C. Returns D, C, origin."""
    ext = []
    for p in _clay:
        if p["kind"] == "ell":
            m = np.abs(p["M"]) @ np.array(p["r"])
            c = np.array(p["c"])
        else:
            s = max(p["s"])
            reach = max(abs(p["z0"]), abs(p["z1"])) * s + max(p["r0"], p["r1"]) * s
            m = np.array([reach] * 3)
            c = np.array(p["c"])
        p["_lo"], p["_hi"] = c - m, c + m
        if not p["cut"]:
            ext.append((c - m, c + m))
    pad = 0.3
    lo = np.min([e[0] for e in ext], axis=0) - pad
    hi = np.max([e[1] for e in ext], axis=0) + pad
    dims = np.ceil((hi - lo) / voxel).astype(int) + 1
    D = np.full(dims, 9.0, dtype=np.float32)
    C = np.zeros((*dims, 3), dtype=np.float32)
    axes = [lo[i] + np.arange(dims[i]) * voxel for i in range(3)]
    for cut_pass in (False, True):
        for p in _clay:
            if p["cut"] != cut_pass:
                continue
            k = max(p["k"], 1e-4)
            margin = k + 3 * voxel
            i0 = np.maximum(np.floor((p["_lo"] - margin - lo) / voxel).astype(int), 0)
            i1 = np.minimum(np.ceil((p["_hi"] + margin - lo) / voxel).astype(int) + 1, dims)
            if np.any(i1 <= i0):
                continue
            sl = tuple(slice(i0[i], i1[i]) for i in range(3))
            px = (axes[0][sl[0]] - p["c"][0])[:, None, None]
            py = (axes[1][sl[1]] - p["c"][1])[None, :, None]
            pz = (axes[2][sl[2]] - p["c"][2])[None, None, :]
            M = p["M"]   # columns are the local axes in world space: local = M^T (p - c)
            qx = M[0, 0] * px + M[1, 0] * py + M[2, 0] * pz
            qy = M[0, 1] * px + M[1, 1] * py + M[2, 1] * pz
            qz = M[0, 2] * px + M[1, 2] * py + M[2, 2] * pz
            if p["kind"] == "ell":
                a = _sd_ellipsoid(qx, qy, qz, p["r"])
                t = ((qx, qy, qz)[p["axis"]] / p["r"][p["axis"]] + 1) * 0.5
                smooth_t = True
            else:
                s = p["s"]
                a = _sd_round_cone(qx / s[0], qy / s[1], qz / s[2], p["z0"], p["z1"], p["r0"], p["r1"]) * min(s)
                t = (qz / s[2] - p["z0"]) / (p["z1"] - p["z0"])
                smooth_t = not p["linear"]
            a = a.astype(np.float32)
            if p["c1"] is None:
                col = None
            elif p["c2"] is not None:
                t = np.clip(t, 0, 1)
                if smooth_t:
                    t = np.clip((t - 0.12) / 0.76, 0, 1)
                    t = t * t * (3 - 2 * t)
                col = np.array(p["c1"], dtype=np.float32) * (1 - t[..., None]) + np.array(p["c2"], dtype=np.float32) * t[..., None]
            else:
                col = np.array(p["c1"], dtype=np.float32)
            b = D[sl]
            if not cut_pass:
                h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
                D[sl] = b * (1 - h) + a * h - k * h * (1 - h)
            else:
                h = np.clip(0.5 - 0.5 * (b + a) / k, 0, 1)
                D[sl] = b * (1 - h) - a * h + k * h * (1 - h)
            if col is not None:
                C[sl] = C[sl] * (1 - h[..., None]) + col * h[..., None]
    return D, C, lo


def _clay_mesh(voxel):
    """The clay as a dense quad mesh object with a colour attribute "clay"."""
    import openvdb
    D, C, lo = _clay_field(voxel)
    band = voxel * 3
    grid = openvdb.FloatGrid(background=band)
    grid.copyFromArray(np.clip(D, -band, band).astype(np.float32))
    grid.gridClass = openvdb.GridClass.LEVEL_SET
    pts, tris, quads = grid.convertToPolygons(isovalue=0.0, adaptivity=0.0)
    # colour of each point: blended from the eight grid cells around it (nearest-cell colour gave stair steps)
    top = np.array(D.shape) - 1
    f = np.clip(pts, 0, top - 1e-3)
    i0 = np.floor(f).astype(int)
    w = (f - i0).astype(np.float32)
    colours = np.zeros((len(pts), 3), dtype=np.float32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wt = (w[:, 0] if dx else 1 - w[:, 0]) * (w[:, 1] if dy else 1 - w[:, 1]) * (w[:, 2] if dz else 1 - w[:, 2])
                colours += C[np.minimum(i0[:, 0] + dx, top[0]), np.minimum(i0[:, 1] + dy, top[1]), np.minimum(i0[:, 2] + dz, top[2])] * wt[:, None]
    world = pts * voxel + lo
    faces = [tuple(q) for q in quads.tolist()] + [tuple(t) for t in tris.tolist()]
    mesh = bpy.data.meshes.new("Clay")
    mesh.from_pydata(world.tolist(), [], faces)
    mesh.update()
    # outward faces: the summed signed volume must be positive
    v = world
    vol = 0.0
    for f in (quads[:2000] if len(quads) else tris[:2000]):
        a, b, c = v[f[0]], v[f[1]], v[f[2]]
        vol += float(np.dot(a, np.cross(b, c)))
    o = bpy.data.objects.new("Clay", mesh)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    att = mesh.color_attributes.new("clay", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([colours, np.ones((len(colours), 1), dtype=np.float32)], axis=1)
    att.data.foreach_set("color", rgba.astype(np.float32).ravel())
    bpy.ops.object.shade_smooth()
    o["role"] = "clay"
    return o


# ---------------------------------------------------------------------------------------------------------------
def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def _copies(objs):
    out = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def _tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def _only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def _low_skin(clay, budget, quads=False):
    """The game mesh of the skin: even quads (QuadriFlow) pulled back onto the clay, with the clay's own normals,
    so it shades as smoothly as the dense surface. Falls back to plain decimation if the remesher gives up."""
    low = _copies([clay])[0]
    low.name = "Skin"
    for a in list(low.data.color_attributes):
        low.data.color_attributes.remove(a)
    want = max(700, budget // 2)
    ok = False
    attempts = ("plain", "voxel", "voxel-coarse") if quads else ()
    # QuadriFlow needs a clean closed surface. The clay mesh can have pinched points at thin tips (two cones
    # touching in one point), so: try as it is, then after a pass through Blender's own voxel remesher with a
    # little smoothing, which removes such pinches.
    for attempt in attempts:
        if attempt != "plain":
            bpy.data.objects.remove(low, do_unlink=True)
            low = _copies([clay])[0]
            low.name = "Skin"
            for a in list(low.data.color_attributes):
                low.data.color_attributes.remove(a)
            _only(low)
            rm = low.modifiers.new("remesh", "REMESH")
            rm.mode = "VOXEL"
            rm.voxel_size = 0.02 if attempt == "voxel" else 0.03
            rm.use_smooth_shade = True
            bpy.ops.object.modifier_apply(modifier=rm.name)
            sm = low.modifiers.new("smooth", "SMOOTH")
            sm.factor = 0.5
            sm.iterations = 2
            bpy.ops.object.modifier_apply(modifier=sm.name)
        _only(low)
        try:
            res = bpy.ops.object.quadriflow_remesh(use_mesh_symmetry=False, use_preserve_sharp=False, use_preserve_boundary=False,
                                                   preserve_attributes=False, smooth_normals=True, mode="FACES", target_faces=want, seed=0)
            n = len(low.data.polygons)
            ok = "FINISHED" in res and want * 0.5 < n < want * 2.2
        except RuntimeError as e:
            print("quad remesh failed:", str(e)[:120])
        if ok:
            break
    if not ok:
        bpy.data.objects.remove(low, do_unlink=True)
        low = _copies([clay])[0]
        low.name = "Skin"
        for a in list(low.data.color_attributes):
            low.data.color_attributes.remove(a)
        _only(low)
        dec = low.modifiers.new("decimate", "DECIMATE")
        dec.ratio = budget / max(1, _tris(low))
        bpy.ops.object.modifier_apply(modifier=dec.name)
        print("SKIN decimated" + (" (the quad remesher gave up)" if quads else ""))
    else:
        print("SKIN quads", len(low.data.polygons))
    _only(low)
    sw = low.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = clay
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    bpy.ops.object.modifier_apply(modifier=sw.name)
    bpy.ops.object.shade_smooth()
    dt = low.modifiers.new("normals", "DATA_TRANSFER")
    dt.object = clay
    dt.use_loop_data = True
    dt.data_types_loops = {"CUSTOM_NORMAL"}
    dt.loop_mapping = "POLYINTERP_NEAREST"
    try:
        bpy.ops.object.modifier_apply(modifier=dt.name)
    except RuntimeError as e:
        print("normal transfer skipped:", str(e)[:120])
    return low


def finish(name, out, triangles=8000, size=1024, voxel=0.022, melt=None, quads=False):
    """Builds the clay skin, bakes all paint onto its game mesh and exports Body + glow parts as FBX.
    Writes <out>_paint.png (plain paint) and <out>_keep.png (where eyes and mouth are) next to the model.
    quads=True rebuilds the skin as even quads (QuadriFlow): cleanest surface for big round pets, but it blunts
    thin tips (ears, tufts, flames); the default keeps every tip and takes its smooth shading from the clay."""
    out = os.path.abspath(out)
    scene = bpy.context.scene
    every = [o for o in scene.objects if o.type == "MESH"]
    for o in every:
        _only(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    hard = [o for o in every if o["role"] == "hard"]
    glowing = [o for o in every if o["role"] == "glow"]
    marks = [o for o in every if o["role"] == "mark"]

    clay = _clay_mesh(voxel)
    clay.data.materials.append(material(WHITE, attr="clay"))
    # painted marks were laid out on single balls: press each onto the real clay, floating its own lift above it
    for o in marks:
        if "lift" in o:
            sw = o.modifiers.new("wrap", "SHRINKWRAP")
            sw.target = clay
            sw.wrap_method = "NEAREST_SURFACEPOINT"
            sw.wrap_mode = "ABOVE_SURFACE"
            sw.offset = float(o["lift"])
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=sw.name)
    hard_low = _copies(hard)
    hard_tris = sum(_tris(o) for o in hard_low)
    skin = _low_skin(clay, max(1500, triangles - hard_tris), quads)
    for o in hard_low:
        o.data.materials.clear()
    skin.data.materials.clear()
    body = _join([skin] + hard_low, "Body")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")

    # the paint source: the dense clay, the crisp hard pieces and the marks
    source = _join([clay] + hard + marks, "Source")
    img = bpy.data.images.new(name + "_paint", size, size)
    target = bpy.data.materials.new(name + "_baked")
    target.use_nodes = True
    tex = target.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    target.node_tree.nodes.active = tex
    bsdf = target.node_tree.nodes.get("Principled BSDF")
    target.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    body.data.materials.clear()
    body.data.materials.append(target)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = 0.06
    bake.max_ray_distance = 0.3
    bake.margin = 8
    for g in glowing:
        g.hide_render = True
    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = out[:-4] + "_paint.png"
    img.file_format = "PNG"
    img.save()
    # second bake: where the eyes and mouth are. Later painting (scripts/pet_paint.py) must not touch those texels:
    # in the engine at phone size a repainted face turns muddy, while these crisp shapes stay readable.
    keep = bpy.data.images.new(name + "_keep", size, size)
    for m in source.data.materials:
        em = next(n for n in m.node_tree.nodes if n.type == "EMISSION")
        for ln in list(em.inputs["Color"].links):
            m.node_tree.links.remove(ln)
        v = 1.0 if m.name.startswith("keep_") else 0.0
        em.inputs["Color"].default_value = (v, v, v, 1)
    tex.image = keep
    bake.margin = 1
    bpy.ops.object.bake(type="EMIT")
    keep.filepath_raw = out[:-4] + "_keep.png"
    keep.file_format = "PNG"
    keep.save()
    tex.image = img
    bpy.data.objects.remove(source, do_unlink=True)

    scene.cursor.location = (0, 0, 0)
    _only(body)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    parts = [body]
    groups = {}
    for o in glowing:
        c = [float(v) for v in o["htd_color"]]
        lib._paint(o, (1, 1, 1))   # white vertex colours: Roblox multiplies them with the part's colour
        key = "c_%d_%d_%d" % tuple(round(max(0, min(1, v)) * 255) for v in c[:3])
        groups.setdefault(key, []).append(o)
    for key, objs in groups.items():
        o = _join(objs, key)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        parts.append(o)
    smooth = sum(1 for p in body.data.polygons if p.use_smooth)
    print("TRIANGLES", lib.triangles(parts), "(skin %d, hard %d)  smooth faces %d/%d" % (_tris(body) - hard_tris, hard_tris, smooth, len(body.data.polygons)))
    top = max((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
    print("HEIGHT %.2f" % top)
    lib.export_fbx(out)
    print("EXPORTED", out)
