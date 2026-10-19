# Makes the textures of the player materials (scenes/player/materials/) in
# assets/textures/players/:
#   skin/    the skin tones (MakeHuman's skin textures, CC0) and a tiling pore normal map
#   eyes/    the eye colors (MakeHuman's eye textures, CC0)
#   kit/     the kit pattern masks every kit design picks from (red: the main color, green: the
#            second color, blue: the trim color; see KitDesign), a tiling knit normal map, the
#            shirt's and the shorts' fold normal maps (from their source assets) and the shoes'
#            mask and detail
#
# A garment's patterns are worked out per texel from where the texel lies on the default body:
# its position, its normal and how far it is from each of the garment's edges (collar, sleeves,
# hem, ...), all baked into the garment's UV layout. A new pattern is a new entry in PATTERNS.
#
# Usage (from anywhere, after make_player_kit.py):
#   blender -b --python tools/blender/make_player_textures.py

import heapq
import os
import shutil
import sys

import bpy
import numpy

sys.path.insert(0, os.path.dirname(__file__))
import mpfb_setup  # noqa: E402

OUTPUT = os.path.join(mpfb_setup.PROJECT_ROOT, "assets", "textures", "players")
## Skin tones by name: their MakeHuman skin
SKINS = {
    "light": "young_caucasian_male",
    "light_2": "young_caucasian_male2",
    "light_mature": "middleage_caucasian_male",
    "olive": "young_asian_male",
    "olive_mature": "middleage_asian_male",
    "dark": "young_african_male",
    "dark_mature": "middleage_african_male",
}
EYES = ["brown", "brownlight", "blue", "lightblue", "green", "grey", "bluegreen"]
MASK_SIZE = 1024
## Width (m) of the trims along the garments' edges
TRIM = 0.016


def main():
    mpfb_setup.empty_scene()
    mpfb_setup.enable_mpfb()
    for directory in ("skin", "eyes", "kit"):
        os.makedirs(os.path.join(OUTPUT, directory), exist_ok=True)
    copy_skins_and_eyes()
    save_png(os.path.join(OUTPUT, "skin", "pores_normal.png"), normal_from_height(pore_height(512), 2.0))
    save_png(os.path.join(OUTPUT, "kit", "knit_normal.png"), normal_from_height(knit_height(256), 1.2))
    make_kit_masks()
    make_shoe_textures()


def asset_file(subdir, name, filename):
    from bl_ext.blender_org.mpfb.services.locationservice import LocationService

    path = os.path.join(LocationService.get_user_data(subdir), name, filename)
    assert os.path.exists(path), "%s is missing: install the MakeHuman asset packs in MPFB" % path
    return path


def copy_skins_and_eyes():
    for tone, skin in SKINS.items():
        directory = os.path.dirname(asset_file("skins", skin, skin + ".mhmat"))
        texture = next(f for f in os.listdir(directory) if f.endswith("_diffuse.png") or "diffuse" in f)
        shutil.copy(os.path.join(directory, texture), os.path.join(OUTPUT, "skin", tone + ".png"))
    for eye in EYES:
        shutil.copy(asset_file("eyes", "materials", eye + "_eye.png"), os.path.join(OUTPUT, "eyes", eye + ".png"))


# Tiling detail maps ------------------------------------------------------------------------------


def tiling_noise(size, cells, seed):
    """Smooth tiling value noise in [0, 1] with `cells` cells across."""
    random = numpy.random.default_rng(seed)
    grid = random.random((cells, cells))
    coordinates = numpy.arange(size) * cells / size
    i0 = numpy.floor(coordinates).astype(int)
    f = coordinates - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    rows = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    rows_next = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows_next * f[:, None]


def pore_height(size):
    """Skin: fine pores and soft unevenness."""
    pores = sum(tiling_noise(size, cells, seed) * weight for cells, seed, weight in ((128, 1, 0.6), (64, 2, 0.3), (16, 3, 0.1)))
    return 1.0 - numpy.clip((pores - 0.35) * 3.0, 0.0, 1.0) ** 2


def knit_height(size):
    """Jersey knit: rows of V-shaped loops."""
    y, x = numpy.mgrid[0:size, 0:size] / size
    columns, rows = 32, 40
    u = (x * columns) % 1.0
    v = (y * rows + numpy.abs(u - 0.5)) % 1.0
    loops = numpy.sin(u * numpy.pi) * numpy.sin(v * numpy.pi)
    return loops * 0.8 + tiling_noise(size, 32, 4) * 0.2


def normal_from_height(height, strength):
    dx = (numpy.roll(height, -1, axis=1) - numpy.roll(height, 1, axis=1)) * strength
    dy = (numpy.roll(height, -1, axis=0) - numpy.roll(height, 1, axis=0)) * strength
    normal = numpy.dstack((-dx, dy, numpy.ones_like(height)))
    normal /= numpy.linalg.norm(normal, axis=2, keepdims=True)
    return numpy.dstack((normal * 0.5 + 0.5, numpy.ones_like(height)))


# Kit pattern masks -------------------------------------------------------------------------------


def make_kit_masks():
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService

    sys.path.insert(0, os.path.dirname(__file__))
    import make_player_kit

    basemesh = HumanService.create_human(macro_detail_dict=make_player_kit.AUTHOR_MACROS)
    mesh = make_player_kit.evaluated_body(basemesh)
    joints = make_player_kit.Landmarks(basemesh, mesh)
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 1
    bpy.context.scene.cycles.device = "CPU"
    for garment, patterns in PATTERNS.items():
        path = os.path.join(mpfb_setup.KIT_DIR, garment, garment + ".mhclo")
        obj = HumanService.add_mhclo_asset(path, basemesh, asset_type="Clothes", subdiv_levels=0, set_up_rigging=False)
        edges = edge_distances(obj, EDGES[garment], joints)
        covered = bake(obj, "coverage")[:, :, 0] > 0.5
        surface = Surface(bake(obj, "position"), bake(obj, "normal"), {name: bake(obj, name) for name in edges}, joints, covered)
        for pattern, function in patterns.items():
            green, blue = function(surface)
            # Outside the garment the main color, which its edges blend into from afar
            outside = numpy.isnan(surface.x)
            green, blue = numpy.where(outside, 0.0, green), numpy.where(outside, 0.0, blue)
            mask = numpy.dstack((1.0 - numpy.maximum(green, blue), green, blue, numpy.ones_like(green)))
            save_png(os.path.join(OUTPUT, "kit", "%s_%s.png" % (garment, pattern)), mask)
        bpy.data.objects.remove(obj)
    shutil.copy(
        asset_file("clothes", make_player_kit.ADOPTED["shorts"]["from"], "M_Swimming_trunks_01_NRM.png"),
        os.path.join(OUTPUT, "kit", "shorts_normal.png"),
    )
    shirt = make_player_kit.ADOPTED["shirt"]["from"]
    shutil.copy(asset_file("clothes", shirt, shirt + "_normal.png"), os.path.join(OUTPUT, "kit", "shirt_normal.png"))


## Edges of each garment the patterns measure from, by name: the garment's open edge (where it
## may be folded inside) within a radius (m) of the joints (e.g. the collar around the neck).
EDGES = {
    "shirt": {"collar": (("neck",), 0.15), "hem": (("pelvis",), 0.3), "sleeves": (("l-elbow", "r-elbow"), 0.16)},
    "shorts": {"waist": (("pelvis",), 0.25), "legs": (("l-knee", "r-knee"), 0.22)},
    "socks": {"cuffs": (("l-knee", "r-knee"), 0.32)},
}


def edge_distances(obj, wanted, joints):
    """Stores, for each wanted edge, every vertex's distance (m, along the mesh) to it as a
    color attribute of the same name."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    for name, (around, radius) in wanted.items():
        sources = [
            v for v in bm.verts
            if v.is_boundary and min((v.co - joints[joint]).length for joint in around) < radius
        ]
        assert sources, "%s: no %s edge" % (obj.name, name)
        distance = dijkstra(bm, sources)
        attribute = obj.data.color_attributes.new(name, "FLOAT_COLOR", "POINT")
        for index, value in enumerate(distance):
            attribute.data[index].color = (value, value, value, 1.0)
    bm.free()
    return list(wanted)


def dijkstra(bm, sources):
    bm.verts.ensure_lookup_table()
    distance = [1.0] * len(bm.verts)
    queue = [(0.0, v.index) for v in sources]
    for _, index in queue:
        distance[index] = 0.0
    heapq.heapify(queue)
    while queue:
        d, index = heapq.heappop(queue)
        if d > distance[index]:
            continue
        vertex = bm.verts[index]
        for edge in vertex.link_edges:
            other = edge.other_vert(vertex)
            nd = d + edge.calc_length()
            if nd < distance[other.index]:
                distance[other.index] = nd
                heapq.heappush(queue, (nd, other.index))
    return distance


def bake(obj, quantity):
    """`quantity` ("coverage": 1 on the garment, "position", "normal" or a color attribute) of the
    default body's garment in every texel of its UV layout: an array (size, size, 3)."""
    material = bpy.data.materials.new("Bake")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    links.new(emission.outputs[0], output.inputs[0])
    if quantity == "coverage":
        emission.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    elif quantity in ("position", "normal"):
        geometry = nodes.new("ShaderNodeNewGeometry")
        links.new(geometry.outputs["Position" if quantity == "position" else "Normal"], emission.inputs[0])
    else:
        attribute = nodes.new("ShaderNodeAttribute")
        attribute.attribute_name = quantity
        links.new(attribute.outputs["Color"], emission.inputs[0])
    image = bpy.data.images.new("Bake", MASK_SIZE, MASK_SIZE, alpha=True, float_buffer=True)
    image.generated_color = (0.0, 0.0, 0.0, 1.0)
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    nodes.active = texture
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True)
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(MASK_SIZE, MASK_SIZE, 4)
    values = pixels[:, :, :3].copy()
    bpy.data.images.remove(image)
    bpy.data.materials.remove(material)
    return values


class Surface:
    """Where the garment's texels lie on the default body (see bake), with helpers for patterns:
    all in meters, x to the body's left, y to its back, z up."""

    def __init__(self, position, normal, edges, joints, covered):
        position = numpy.where(covered[:, :, None], position, numpy.nan)
        self.x, self.y, self.z = (position[:, :, i] for i in range(3))
        self.normal = normal
        self.edges = {name: numpy.where(covered, values[:, :, 0], numpy.nan) for name, values in edges.items()}
        self.joints = joints

    def near(self, edge, width=TRIM):
        return soft(width - self.edges[edge])

    def band(self, value, low, high):
        return soft(value - low) * soft(high - value)

    def zeros(self):
        return numpy.zeros_like(self.x)


def soft(value, width=0.002):
    """1 where `value` is above 0, fading over `width` (m), with no hard pixel steps."""
    return numpy.nan_to_num(numpy.clip(value / width + 0.5, 0.0, 1.0))


def smoothed(mask, radius=8):
    """`mask` with smooth, clean edges instead of the jitter of the mesh it was worked out on."""
    return numpy.clip((box_blur(numpy.nan_to_num(mask), radius) - 0.5) * 4.0 + 0.5, 0.0, 1.0)


def shirt_trims(s):
    return numpy.maximum(s.near("collar"), s.near("sleeves"))


def segment_distance(s, a, b):
    """Distance (m) of every texel from the bone segment between joints `a` and `b`."""
    a, b = numpy.array(s.joints[a]), numpy.array(s.joints[b])
    points = numpy.dstack((s.x, s.y, s.z))
    axis = b - a
    t = numpy.clip(((points - a) @ axis) / (axis @ axis), 0.0, 1.0)
    return numpy.linalg.norm(points - (a + t[:, :, None] * axis), axis=2)


def shirt_sleeves(s):
    """1 on the sleeves: nearer an upper arm than the spine."""
    spine = numpy.minimum(segment_distance(s, "pelvis", "spine-1"), segment_distance(s, "spine-1", "neck"))
    arms = numpy.minimum(*(segment_distance(s, side + "-shoulder", side + "-elbow") for side in ("l", "r")))
    return smoothed(soft(spine - arms - 0.02, 0.01), 3)


def torso_sides(s, low, high):
    """1 on the sides of the torso: between `low` and `high` degrees around the spine from the
    front (the body faces -y)."""
    center_y = (s.joints["spine-2"].y + s.joints["l-shoulder"].y) / 2
    angle = numpy.degrees(numpy.arctan2(numpy.abs(s.x), -(s.y - center_y)))
    return smoothed(s.band(angle, low, high) * 1.0, 3)


PATTERNS = {
    "shirt": {
        "trims": lambda s: (s.zeros(), shirt_trims(s)),
        "sleeves": lambda s: (shirt_sleeves(s), s.near("collar")),
        "yoke": lambda s: (soft(s.z - (s.joints["l-shoulder"].z - 0.09), 0.006), shirt_trims(s)),
        "chest_band": lambda s: (
            s.band(s.z, s.joints["l-shoulder"].z - 0.17, s.joints["l-shoulder"].z - 0.10),
            numpy.maximum(shirt_trims(s), s.band(numpy.abs(s.z - (s.joints["l-shoulder"].z - 0.135)), 0.035, 0.043)),
        ),
        "side_panels": lambda s: (
            torso_sides(s, 62.0, 118.0) * (1.0 - shirt_sleeves(s)) * soft(s.joints["l-shoulder"].z - 0.12 - s.z, 0.02),
            shirt_trims(s),
        ),
        "sash": lambda s: (s.band(s.z + s.x * 0.9, s.joints["pelvis"].z + 0.25, s.joints["pelvis"].z + 0.36), shirt_trims(s)),
        "fade": lambda s: (numpy.nan_to_num(numpy.clip(1.0 - s.edges["hem"] / 0.35, 0.0, 1.0)) ** 1.5, shirt_trims(s)),
    },
    "shorts": {
        "side_stripe": lambda s: (s.zeros(), smoothed(soft(s.normal[:, :, 0] * numpy.sign(numpy.nan_to_num(s.x)) - 0.93, 0.02))),
        "waistband": lambda s: (s.near("waist", 0.035), s.near("legs")),
        "side_panels": lambda s: (smoothed(soft(s.normal[:, :, 0] * numpy.sign(numpy.nan_to_num(s.x)) - 0.7, 0.05)), s.near("legs")),
    },
    "socks": {
        "stripes": lambda s: (s.zeros(), numpy.maximum(s.band(s.edges["cuffs"], 0.018, 0.026), s.band(s.edges["cuffs"], 0.034, 0.042))),
    },
}


# Shoes ---------------------------------------------------------------------------------------------


def make_shoe_textures():
    """The shoes' mask (red: upper, green: sole, blue: trims) and detail (stitching, mesh, wear
    as brightness around 0.5), from the MakeHuman shoes' photo texture, its logo painted out."""
    import make_player_kit

    source = make_player_kit.ADOPTED["shoes"]["from"]
    image = bpy.data.images.load(asset_file("clothes", source, source + "_diffuse.png"))
    size = image.size[0]
    pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(size, size, 4)[:, :, :3]
    # Rows count from the bottom of the image here
    v = numpy.arange(size)[:, None] / size * numpy.ones((1, size))
    u = numpy.ones((size, 1)) * numpy.arange(size)[None, :] / size
    for u0, v0, u1, v1 in SHOE_LOGOS:
        rows, cols = slice(int(v0 * size), int(v1 * size)), slice(int(u0 * size), int(u1 * size))
        height = rows.stop - rows.start
        pixels[rows, cols] = pixels[rows.start - height : rows.start, cols]
    luminance = pixels @ numpy.array([0.299, 0.587, 0.114], dtype=numpy.float32)
    saturation = pixels.max(axis=2) - pixels.min(axis=2)
    sole = (v > 0.72).astype(numpy.float32)
    trims = ((luminance > 0.55) & (saturation < 0.18) & (v <= 0.72) & (v > 0.0)).astype(numpy.float32)
    trims = box_blur(trims, 2)
    mask = numpy.dstack((1.0 - numpy.maximum(sole, trims), sole, trims * (1.0 - sole), numpy.ones_like(sole)))
    save_png(os.path.join(OUTPUT, "kit", "shoes_mask.png"), mask)
    detail = numpy.zeros_like(luminance)
    for region in (sole, 1.0 - sole):
        selected = region > 0.5
        mean = luminance[selected].mean()
        detail[selected] = numpy.clip(0.5 + (luminance[selected] - mean) * 1.2, 0.0, 1.0)
    save_png(os.path.join(OUTPUT, "kit", "shoes_detail.png"), numpy.dstack((detail, detail, detail, numpy.ones_like(detail))))
    bpy.data.images.remove(image)


## Logos on the source shoes' texture (u0, v0, u1, v1, v up), painted over with the texture just
## below them
SHOE_LOGOS = [(0.45, 0.15, 0.54, 0.21)]


def box_blur(values, radius):
    result = values.copy()
    for axis in (0, 1):
        result = sum(numpy.roll(result, shift, axis=axis) for shift in range(-radius, radius + 1)) / (2 * radius + 1)
    return result


def save_png(path, rgba):
    """Saves an array (height, width, 4) with values in [0, 1], rows from the bottom, as PNG."""
    height, width = rgba.shape[:2]
    image = bpy.data.images.new(os.path.basename(path), width, height, alpha=True)
    image.pixels[:] = numpy.clip(numpy.nan_to_num(rgba), 0.0, 1.0).astype(numpy.float32).ravel()
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    print("SAVED", path)


if __name__ == "__main__":
    main()
