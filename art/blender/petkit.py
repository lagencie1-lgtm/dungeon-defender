"""Pet kit, second generation (2026-11-23, the "top tier pets" cycles; see reviews/pets/WORKFLOW.md).

What the first kit (sculpt.py) got wrong, measured against Pet Simulator 99 / Adopt Me and our own target pictures:
lumps where shapes overlap, facets, faces built from stacked balls (reads as startled or sad), flat single colours.
This kit keeps "models as code" but changes how the model is finished:

  soft  shapes are melted into ONE smooth skin (voxel remesh + smoothing), so there are no seams, lumps or hidden
        inside faces eating triangles and texture space;
  hard  shapes keep their own crisp geometry (claws, horns, crystals, whiskers, wing skins);
  mark  shapes are PAINT ONLY: they exist while baking and leave colour on the skin (eyes, mouth, blush, belly,
        stripes, socks, spots), never a bump;
  glow  shapes stay separate Neon parts named c_R_G_B, as the game expects (keep them small and few).

The paint is baked from the full-detail shapes onto the finished skin: colour gradients, a soft top-left light,
tinted shadows in the creases and a little painted mottling. Front of a pet faces -Y, up is +Z, about 2.2 tall.

Use:  import petkit as K;  K.start();  head = K.ball(...);  K.eye(head, ...);  K.finish("pet_x", out_fbx, 7000)
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

import lib

rad = math.radians
WHITE = (1, 1, 1)
INK = (0.16, 0.09, 0.07)       # warm dark outline colour of the target pictures (never pure black)
_mats = {}


def start():
    lib.reset()
    _mats.clear()


def _lin(c):
    return tuple(v ** 2.2 if v <= 1 else v for v in c)


def material(color, color2=None, axis="Z", lit=True, mottle=0.05, linear=False):
    """Painted colour for baking. color2 = second colour for a gradient along `axis` of the shape (color at the
    low end, color2 at the high end). lit=False keeps the colour exactly (eye shines, pupils)."""
    key = (tuple(color), tuple(color2) if color2 else None, axis, lit, mottle, linear)
    if key in _mats:
        return _mats[key]
    mat = bpy.data.materials.new("paint_%d" % len(_mats))
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes.new, nt.links.new
    rgb = n("ShaderNodeRGB")
    rgb.outputs[0].default_value = (*_lin(color), 1)
    base = rgb.outputs[0]
    coords = n("ShaderNodeTexCoord")
    if color2:
        attr = n("ShaderNodeAttribute")
        attr.attribute_name = "grad"   # 0..1 along the shape's own axis, stored when the shape is made
        smooth = n("ShaderNodeMapRange")
        smooth.interpolation_type = "LINEAR" if linear else "SMOOTHSTEP"
        smooth.inputs["From Min"].default_value = 0.0 if linear else 0.12
        smooth.inputs["From Max"].default_value = 1.0 if linear else 0.88
        link(attr.outputs["Fac"], smooth.inputs["Value"])
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
        light.inputs["To Min"].default_value = 0.25
        light.inputs["To Max"].default_value = 1.0
        link(dot.outputs["Value"], light.inputs["Value"])
        ao = n("ShaderNodeAmbientOcclusion")
        ao.only_local = True
        ao.samples = 16
        ao.inputs["Distance"].default_value = 0.55
        ao_r = n("ShaderNodeMapRange")
        ao_r.inputs["From Min"].default_value = 0.35
        ao_r.inputs["To Min"].default_value = 0.0
        link(ao.outputs["AO"], ao_r.inputs["Value"])
        both = n("ShaderNodeMath")
        both.operation = "MULTIPLY"
        link(light.outputs["Result"], both.inputs[0])
        link(ao_r.outputs["Result"], both.inputs[1])
        shade = n("ShaderNodeMix")
        shade.data_type = "RGBA"
        link(both.outputs["Value"], shade.inputs["Factor"])
        shade.inputs[6].default_value = (0.42, 0.34, 0.50, 1)   # deepest shadow tint
        shade.inputs[7].default_value = (1.08, 1.05, 1.0, 1)    # lit
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


def _finish_piece(o, name, color, role, color2=None, axis="Z", lit=True, flat=False, linear=False):
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
        o.data.materials.append(material(color, color2, axis, lit, linear=linear))
    return o


def ball(name, pos, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=32, role="soft", color2=None, axis="Z", lit=True):
    """An egg / ball. Remembers its centre and half-sizes so eyes and patches can be put ON it (see on())."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=seg, ring_count=max(6, seg // 2), location=pos, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    o["center"] = list(pos)
    o["half"] = [radius * s for s in scale]
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


def cone(name, pos, r, h, color, rot=(0, 0, 0), top=0.0, verts=16, scale=(1, 1, 1), role="soft", color2=None, flat=False):
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=top, depth=h, vertices=verts, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return _finish_piece(o, name, color, role, color2, flat=flat)


def limb(name, a, b, r0, r1, color, verts=16, role="soft", color2=None, cap=True, linear=False):
    """A tapered tube from a to b with round ends."""
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bpy.ops.mesh.primitive_cone_add(radius1=r0, radius2=r1, depth=d.length, vertices=verts, location=(va + vb) / 2)
    o = bpy.context.active_object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    _finish_piece(o, name, color, role, color2, linear=linear)
    if cap:
        ball(name + "A", a, r0, color, seg=verts, role=role)
        ball(name + "B", b, r1, color2 or color, seg=verts, role=role)
    return o


def chain(name, points, radii, color, verts=16, role="soft", color2=None):
    """A bending limb (tail, neck, horn): tapered tubes through the points. color2 = colour at the far end."""
    n = len(points) - 1
    for i in range(n):
        if color2:
            c0 = tuple(color[k] + (color2[k] - color[k]) * i / n for k in range(3))
            c1 = tuple(color[k] + (color2[k] - color[k]) * (i + 1) / n for k in range(3))
        else:
            c0 = c1 = color
        limb(f"{name}{i}", points[i], points[i + 1], radii[i], radii[i + 1], c0, verts, role, c1 if color2 else None, cap=False, linear=True)
        ball(f"{name}{i}K", points[i], radii[i] * 0.985, c0, seg=verts, role=role)
    ball(f"{name}End", points[-1], radii[-1], color2 or color, seg=verts, role=role)


def rope(name, points, radii, color, color2=None, n=26, role="soft", squash=(1, 1, 1)):
    """A fat soft tail or neck: many overlapping balls along a smooth curve through the points, so it melts into
    one flowing shape with no joints. color2 = colour at the far end."""
    def spline(vals, t):
        k = len(vals) - 1
        i = min(int(t * k), k - 1)
        u = t * k - i
        p0, p1, p2, p3 = vals[max(i - 1, 0)], vals[i], vals[i + 1], vals[min(i + 2, k)]
        return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)

    for j in range(n):
        t = j / (n - 1)
        pos = tuple(spline([p[k] for p in points], t) for k in range(3))
        r = spline(radii, t)
        c = tuple(color[k] + (color2[k] - color[k]) * t for k in range(3)) if color2 else color
        ball(f"{name}{j}", pos, r, c, squash, seg=24, role=role)


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
          axis="Z", lit=True, bulge=0.5, seg=24, cut=None):
    """A painted area on a ball: a lens lying on the surface at `direction`. stretch = (sideways, up) factors,
    roll = turn in degrees, lift = how far it stands out (higher marks paint over lower ones).
    role="mark" paints only; role="soft" adds a soft bump (muzzle, cheek)."""
    p, nrm = on(body, direction)
    if role == "mark":
        # paint only: a thin sheet that hugs the ball exactly `lift` above it, so stacked marks keep their true
        # outlines (domes used to swallow each other's edges: eyes got a thick dark ring)
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
        _finish_piece(o, name, color, role, color2, None, lit)
        _grad(o, ay if axis == "Y" else ax if axis == "X" else Vector((0, 0, 1)))
        return o
    depth = max(radius * bulge * 0.35, lift * 2.2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=seg, ring_count=seg // 2, location=p + nrm * (lift - depth))
    o = bpy.context.active_object
    o.scale = (radius * stretch[0], radius * stretch[1], depth)
    # local Z along the normal, local Y towards "up" on the surface
    q = nrm.to_track_quat("Z", "Y")
    o.rotation_mode = "QUATERNION"
    from mathutils import Quaternion
    o.rotation_quaternion = q @ Quaternion((0, 0, 1), rad(roll))
    o["center"] = list(p)
    return _finish_piece(o, name, color, role, color2, axis, lit)


def eye(body, direction, r, iris=(0.86, 0.50, 0.10), iris_dark=(0.36, 0.16, 0.05), side=1, tall=1.18, look=(0.0, 0.0),
        lash=False, name="Eye"):
    """One big glossy painted eye in the style of the target pictures: dark warm outline, amber iris that is dark at
    the top and bright at the bottom, a big pupil and two white shines (big one top-left, small one bottom-right).
    side = -1 for the pet's right eye (mirrors the roll). All paint, no bumps."""
    roll = side * 5   # tops lean a little outwards: open and friendly (leaning inwards reads as worried)
    patch(body, direction, r, INK, (1.0, tall), roll, 0.016, name=name + "Rim", lit=False)
    patch(body, direction, r * 0.91, iris, (1.0, tall), roll, 0.022, name=name + "Iris", color2=iris_dark, axis="Y", lit=False)
    p, nrm = on(body, direction)
    # directions on the surface: right (screen right when seen from the front) and up
    up = (Vector((0, 0, 1)) - nrm * nrm.z).normalized()
    right = up.cross(nrm).normalized()

    def at(dx, dz):
        q = p + right * dx * r + up * dz * r * tall
        return tuple(q - Vector(body["center"]))

    patch(body, at(look[0] * 0.2, 0.14 + look[1] * 0.2), r * 0.60, (0.07, 0.04, 0.05), (1.0, tall), roll, 0.028, name=name + "Pupil", lit=False)
    patch(body, at(-0.36, 0.44), r * 0.36, WHITE, (1.0, 1.2), -24, 0.036, name=name + "Shine", lit=False)
    patch(body, at(0.36, -0.44), r * 0.17, WHITE, (1.0, 1.0), 0, 0.036, name=name + "Shine2", lit=False)
    if lash:
        patch(body, at(side * 0.98, 0.62), r * 0.3, INK, (1.2, 0.3), side * -35, 0.02, name=name + "Lash", lit=False)


def eyes(body, x, z, r, y=-1.0, **kw):
    """Both eyes: x = how far apart (direction units), z = height on the head (direction units)."""
    for s in (-1, 1):
        eye(body, (s * x, y, z), r, side=s, name=f"Eye{s}", **kw)


def brow(body, x, z, r, color=INK, y=-1.0, tilt=12):
    """Small happy eyebrows (raised outwards). Sad or angry brows are the first thing that kills a cute face."""
    for s in (-1, 1):
        patch(body, (s * x, y, z), r, color, (1.0, 0.22), s * -tilt, 0.02, name=f"Brow{s}", lit=False)


def smile(body, z, w, y=-1.0, x=0.0, tongue=(0.96, 0.46, 0.50), inside=(0.42, 0.10, 0.12), skin=None, open_=True):
    """A happy open mouth painted on: a wide D shape (flat on top, round below) with a tongue. skin = the colour
    around the mouth (it paints the flat top edge). Closed: a short curved line."""
    if not open_:
        for s in (-1, 1):
            patch(body, (x + s * w * 0.5, y, z), w * 0.55, INK, (1.0, 0.22), s * 18, 0.02, name="SmileLine", lit=False)
        return
    # a D shape: an oval with its top cut flat, dark outline, pink tongue at the bottom
    patch(body, (x, y, z), w, INK, (1.0, 0.92), 0, 0.016, name="MouthRim", lit=False, cut=0.30)
    patch(body, (x, y, z), w * 0.88, inside, (1.0, 0.90), 0, 0.022, name="Mouth", lit=False, cut=0.22)
    p, nrm = on(body, (x, y, z))
    up = (Vector((0, 0, 1)) - nrm * nrm.z).normalized()
    c = Vector(body["center"])
    patch(body, tuple(p - up * w * 0.5 - c), w * 0.52, tongue, (1.0, 0.62), 0, 0.028, name="Tongue", lit=False)


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
        k = i * 3
        faces += [(k, k + 1, k + 4, k + 3), (k + 1, k + 2, k + 5, k + 4)]
    o = sheet(name, pts, faces, color, thick, role, color2, "Z")
    if color2:
        _grad(o, d)
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


def finish(name, out, triangles=7000, size=1024, voxel=0.035, melt=6):
    """Melts the soft shapes into one skin, bakes all paint onto it and exports Body + glow parts as FBX.
    Writes <out>_paint.png next to the model. melt = how much the joins between shapes are rounded."""
    out = os.path.abspath(out)
    scene = bpy.context.scene
    every = [o for o in scene.objects if o.type == "MESH"]
    for o in every:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    soft = [o for o in every if o["role"] == "soft"]
    hard = [o for o in every if o["role"] == "hard"]
    glowing = [o for o in every if o["role"] == "glow"]
    painted = [o for o in every if o["role"] != "glow"]

    # the skin: all soft shapes as one surface
    skin = _join(_copies(soft), "Skin")
    skin.data.materials.clear()
    mod = skin.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if melt:
        sm = skin.modifiers.new("smooth", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = melt
        bpy.ops.object.modifier_apply(modifier=sm.name)
    hard_low = _copies(hard)
    hard_tris = sum(_tris(o) for o in hard_low)
    budget = max(1500, triangles - hard_tris)
    count = _tris(skin)
    if count > budget:
        dec = skin.modifiers.new("decimate", "DECIMATE")
        dec.ratio = budget / count
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for o in hard_low:
        o.data.materials.clear()
    body = _join([skin] + hard_low, "Body")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")

    # the paint source: every painted shape at full detail
    source = _join(painted, "Source")
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
    bpy.data.objects.remove(source, do_unlink=True)

    scene.cursor.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
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
    print("TRIANGLES", lib.triangles(parts), "(skin %d, hard %d)" % (_tris(body) - hard_tris, hard_tris))
    top = max((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
    print("HEIGHT %.2f" % top)
    lib.export_fbx(out)
    print("EXPORTED", out)
