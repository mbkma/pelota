# Builds the tennis kit garments (shirt, shorts, socks, shoes, wristbands, headband) every player
# wears and saves each as an MPFB clothes asset (.mhclo + .obj) in pelota-files/player/kit/, from
# where MPFB fits it onto any body (see generate_players.py).
#
# Shirt, shorts and shoes are adopted from MakeHuman community assets (see ADOPTED; install their
# asset packs in MPFB first): fitted to the default body, reworked (cut, subdivided or decimated)
# and saved under the kit's name, keeping their author and license. Their UV layout stays, so kit
# designs paint them on the source asset's texture layout.
# Socks are cut out of the body (the faces of the lower shins and the ankles), lifted off the skin
# with a straight, turned-in cuff. Wristbands and the headband are rings cast around the limb or
# the head, their UVs running around (u) and across (v) the band.
#
# Usage (from anywhere):
#   blender -b --python tools/blender/make_player_kit.py [-- garment ...]
#
#   garment  builds only the listed garments (default: all)

import math
import os
import shutil
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(__file__))
import mpfb_setup  # noqa: E402

## Body the garments are made on: MPFB fits them onto every other body from this one.
AUTHOR_MACROS = {
    "gender": 1.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "proportions": 0.5, "height": 0.5,
    "cupsize": 0.5, "firmness": 0.5, "race": {"asian": 0.33, "caucasian": 0.33, "african": 0.33},
}

## Garments adopted from MakeHuman assets: the source asset (MPFB clothes), how often its mesh
## is subdivided, what share of its faces is kept (decimated, as triangles), the part of its UV
## layout cut off (u_min, u_max, v_min, v_max; e.g. the jeans of a suit, the sock in the shoes'
## mesh) and which body vertices it hides (the source's own, those of them it still covers after
## the cut, or the feet).
ADOPTED = {
    "shirt": {"from": "male_casualsuit06", "subdivide": 0, "keep": 1.0, "cut_uv": (0.0, 1.0, 0.0, 0.57), "hides": "covered"},
    "shorts": {"from": "mindfront_male_swimming_trunks_01", "subdivide": 1, "keep": 1.0, "cut_uv": None, "hides": "source"},
    "shoes": {"from": "shoes06", "subdivide": 0, "keep": 1.0, "cut_uv": (0.75, 1.0, 0.0, 0.17), "hides": "feet"},
}
## Garments cut out of the body: how far (m) they stand off the skin, how much they are smoothed
## (iterations) and how deep (m) their cuff is turned in.
CUT = {"socks": {"offset": 0.002, "smooth": 2, "turn_in": 0.012}}
## Ring garments: the bone segment they wrap, where along it (shares), how far they stand off the
## skin and how thick they are (m).
RINGS = {
    "wristband_left": {"ring": ("l-elbow", "l-hand"), "span": (0.80, 0.93), "offset": 0.004, "thickness": 0.007},
    "wristband_right": {"ring": ("r-elbow", "r-hand"), "span": (0.80, 0.93), "offset": 0.004, "thickness": 0.007},
    "headband": {"ring": "head", "offset": 0.004, "thickness": 0.003},
}
GARMENTS = list(ADOPTED) + list(CUT) + list(RINGS)
## Socks: from this share down the shin, and over the ankle (share of the foot)
SOCK_TOP = 0.70
SOCK_HEEL = 0.45
## How far (m) out and in from the cloth the skin is looked for (see CutGarment.keep_outside)
PUSH_REACH = 0.05
## Segments around the ring garments, rings across them
RING_SEGMENTS = 32
RING_ROWS = 6
## Author and license of the garments made here
AUTHOR = "Pelota"
LICENSE = "CC0"


class Landmarks:
    """Joint positions of the body (the centers of MakeHuman's joint helper cubes) and the bone
    segments between them, each with the body part it belongs to."""

    def __init__(self, basemesh, mesh):
        self.joints = {}
        members = {group.index: [] for group in basemesh.vertex_groups}
        for vertex in basemesh.data.vertices:
            for element in vertex.groups:
                members[element.group].append(vertex.index)
        for group in basemesh.vertex_groups:
            if group.name.startswith("joint-"):
                points = [mesh.vertices[i].co for i in members[group.index]]
                self.joints[group.name[6:]] = sum(points, Vector()) / len(points)
        self.segments = []
        spine = ["pelvis", "spine-4", "spine-3", "spine-2", "spine-1", "neck"]
        for a, b in zip(spine, spine[1:]):
            self._add("torso", "", a, b)
        self._add("head", "", "neck", "head")
        self._add("head", "", "head", "head-2")
        for side in ("l", "r"):
            self._add("torso", side, "neck", side + "-shoulder")
            self._add("torso", side, "pelvis", side + "-upper-leg")
            self._add("upperarm", side, side + "-shoulder", side + "-elbow")
            self._add("forearm", side, side + "-elbow", side + "-hand")
            self._add("hand", side, side + "-hand", side + "-hand-2")
            self._add("thigh", side, side + "-upper-leg", side + "-knee")
            self._add("shin", side, side + "-knee", side + "-ankle")
            self._add("foot", side, side + "-ankle", side + "-foot-2")

    def _add(self, part, side, a, b):
        self.segments.append((part, side, self.joints[a], self.joints[b]))

    def __getitem__(self, name):
        return self.joints[name]

    def locate(self, point):
        """Body part, side and share t in [0, 1] along its segment nearest to `point`."""
        best = None
        for part, side, a, b in self.segments:
            axis = b - a
            t = max(0.0, min(1.0, (point - a).dot(axis) / axis.length_squared))
            distance = (a + axis * t - point).length
            if best is None or distance < best[0]:
                best = (distance, part, side, t)
        return best[1:]


def evaluated_body(basemesh):
    """The body's mesh with its shape (shape keys) applied and the helpers kept, so its vertex
    indices are the basemesh's."""
    mask = basemesh.modifiers["Hide helpers"]
    mask.show_viewport = False
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(basemesh.evaluated_get(depsgraph))
    mask.show_viewport = True
    return mesh


def body_faces(basemesh, mesh):
    """Indices of the faces of the skin (not of the helpers)."""
    body_group = basemesh.vertex_groups["body"].index
    in_body = [any(g.group == body_group for g in v.groups) for v in basemesh.data.vertices]
    return [f.index for f in mesh.polygons if all(in_body[v] for v in f.vertices)]


def skin_object(mesh, faces):
    """The skin alone, as an object the garments are fitted to."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    keep = set(faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    skin_mesh = bpy.data.meshes.new("Skin")
    bm.to_mesh(skin_mesh)
    bm.free()
    skin = bpy.data.objects.new("Skin", skin_mesh)
    bpy.context.scene.collection.objects.link(skin)
    return skin


def face_islands(faces):
    islands = []
    unvisited = set(faces)
    while unvisited:
        start = unvisited.pop()
        island, stack = {start}, [start]
        while stack:
            face = stack.pop()
            for edge in face.edges:
                for other in edge.link_faces:
                    if other in unvisited:
                        unvisited.remove(other)
                        island.add(other)
                        stack.append(other)
        islands.append(island)
    return sorted(islands, key=len, reverse=True)


def covered_by_socks(landmarks, point):
    part, _side, t = landmarks.locate(point)
    return (part == "shin" and t > SOCK_TOP - 0.03) or (part == "foot" and t < SOCK_HEEL)


def sock_cuff_planes(landmarks):
    """Planes (point, normal out of the sock) the sock cuffs run along."""
    planes = []
    for side in ("l", "r"):
        knee, ankle = landmarks[side + "-knee"], landmarks[side + "-ankle"]
        planes.append((knee + (ankle - knee) * SOCK_TOP, (knee - ankle).normalized()))
    return planes


class CutGarment:
    """A garment cut out of the body's faces it covers (one piece per leg)."""

    def __init__(self, name, spec, mesh, faces, landmarks):
        self.name = name
        self.spec = spec
        self.landmarks = landmarks
        self.bm = bmesh.new()
        self.bm.from_mesh(mesh)
        # The body's vertex groups do not carry over (MPFB gives the garment its weights)
        for layer in list(self.bm.verts.layers.deform.values()):
            self.bm.verts.layers.deform.remove(layer)
        self.bm.faces.ensure_lookup_table()
        skin = {self.bm.faces[i] for i in faces}
        covered = {f for f in skin if covered_by_socks(landmarks, f.calc_center_median())}
        covered = self._closed(covered, skin)
        covered = set().union(*face_islands(covered)[:2])
        ## Body vertices the garment hides, away from its edges (MPFB deletes them under it)
        self.hidden_vertices = self._inner_vertices(covered, rings=2)
        bmesh.ops.delete(self.bm, geom=[f for f in self.bm.faces if f not in covered], context="FACES")
        bmesh.ops.delete(self.bm, geom=[v for v in self.bm.verts if not v.link_faces], context="VERTS")
        self.bm.normal_update()

    @staticmethod
    def _closed(covered, skin, passes=3):
        """`covered` with holes filled and spurs removed: faces with most of their neighbors
        covered join, faces with few leave."""
        for _ in range(passes):
            changed = False
            for face in list(skin):
                neighbors = {o for e in face.edges for o in e.link_faces if o is not face and o in skin}
                share = sum(1 for o in neighbors if o in covered) / max(len(neighbors), 1)
                if face not in covered and share > 0.6:
                    covered.add(face)
                    changed = True
                elif face in covered and share < 0.4:
                    covered.discard(face)
                    changed = True
            if not changed:
                break
        return covered

    @staticmethod
    def _inner_vertices(covered, rings):
        inner = set(covered)
        for _ in range(rings):
            edge_faces = {f for f in inner if any(o not in inner for v in f.verts for o in v.link_faces)}
            inner -= edge_faces
        return sorted({v.index for f in inner for v in f.verts})

    def lift(self):
        offset = self.spec["offset"]
        for vertex in self.bm.verts:
            vertex.co += vertex.normal * offset

    def smooth(self, iterations):
        """Smooths the cloth over the body's small shapes (Taubin smoothing, which does not shrink
        it); the edges keep their cuffs."""
        inner = [v for v in self.bm.verts if not v.is_boundary]
        for _ in range(iterations):
            for factor in (0.5, -0.53):
                targets = [sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges) for v in inner]
                for vertex, target in zip(inner, targets):
                    vertex.co += (target - vertex.co) * factor

    def keep_outside(self, tree):
        """Keeps the cloth at least its offset off the skin, measured along the cloth's own
        normal from the outermost skin it passes through within PUSH_REACH."""
        distance = self.spec["offset"]
        self.bm.normal_update()
        for vertex in self.bm.verts:
            normal = vertex.normal
            hit = tree.ray_cast(vertex.co + normal * PUSH_REACH, -normal, PUSH_REACH * 2)[0]
            if hit is not None:
                height = (vertex.co - hit).dot(normal)
                if height < distance:
                    vertex.co += normal * (distance - height)

    def boundary_loops(self):
        """Open edges of the garment as ordered vertex loops."""
        edges = {e for e in self.bm.edges if e.is_boundary}
        loops = []
        while edges:
            edge = edges.pop()
            loop = [edge.verts[0], edge.verts[1]]
            while True:
                nxt = next((e for e in loop[-1].link_edges if e in edges), None)
                if nxt is None:
                    break
                edges.remove(nxt)
                other = nxt.other_vert(loop[-1])
                if other is loop[0]:
                    break
                loop.append(other)
            loops.append(loop)
        return loops

    def cuffs(self):
        """The open edges at the cuff planes (the others end inside the shoes), each with its
        plane."""
        planes = sock_cuff_planes(self.landmarks)
        cuffs = []
        for loop in self.boundary_loops():
            center = sum((v.co for v in loop), Vector()) / len(loop)
            plane = min(planes, key=lambda p: abs((center - p[0]).dot(p[1])))
            if abs((center - plane[0]).dot(plane[1])) < 0.03:
                cuffs.append((loop, plane))
        return cuffs

    def straighten_cuffs(self):
        """Lays each cuff onto its plane, so it runs straight instead of along the body mesh's
        zigzag, and relaxes the row of faces next to it."""
        for loop, (point, normal) in self.cuffs():
            for vertex in loop:
                vertex.co -= normal * (vertex.co - point).dot(normal)
            on_edge = set(loop)
            row = {e.other_vert(v) for v in loop for e in v.link_edges} - on_edge
            for _ in range(4):
                targets = {v: sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges) for v in row}
                for vertex, target in targets.items():
                    vertex.co = vertex.co.lerp(target, 0.5)

    def turn_in_cuffs(self):
        """Folds the cuffs inward by turn_in (m), so that the cloth shows its thickness: a narrow
        rim toward the skin, then a strip back up inside."""
        depth = self.spec["turn_in"]
        self.bm.normal_update()
        for loop, _plane in self.cuffs():
            inward = {}
            for vertex in loop:
                inner = [e.other_vert(vertex) for e in vertex.link_edges if not e.is_boundary]
                direction = sum((o.co - vertex.co for o in inner), Vector())
                inward[vertex] = direction.normalized() if direction.length > 0 else Vector()
            normals = {v: v.normal.copy() for v in loop}
            edges = [e for e in self.bm.edges if e.is_boundary and e.verts[0] in inward and e.verts[1] in inward]
            rim = bmesh.ops.extrude_edge_only(self.bm, edges=edges)
            rim_verts = [g for g in rim["geom"] if isinstance(g, bmesh.types.BMVert)]
            rim_edges = [g for g in rim["geom"] if isinstance(g, bmesh.types.BMEdge)]
            originals = self._originals(rim_verts, inward)
            for vertex in rim_verts:
                vertex.co -= normals[originals[vertex]] * 0.0025
            inner = bmesh.ops.extrude_edge_only(self.bm, edges=[e for e in rim_edges if e.is_boundary])
            inner_verts = [g for g in inner["geom"] if isinstance(g, bmesh.types.BMVert)]
            rim_originals = self._originals(inner_verts, {v: None for v in rim_verts})
            for vertex in inner_verts:
                vertex.co += inward[originals[rim_originals[vertex]]] * depth
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])

    @staticmethod
    def _originals(new_verts, sources):
        """The vertex each extruded vertex was extruded from (the one it shares an edge with)."""
        return {v: next(e.other_vert(v) for e in v.link_edges if e.other_vert(v) in sources) for v in new_verts}

    def to_object(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def ring_garment(name, spec, landmarks, skin):
    """A band around a limb or the head: RING_ROWS rings of RING_SEGMENTS points each cast out
    from the bone onto the skin, standing off it by offset, closed by rims down to the skin."""
    tree = BVHTree.FromObject(skin, bpy.context.evaluated_depsgraph_get())
    if spec["ring"] == "head":
        # Around the forehead, sloping down toward the back of the head
        up = (landmarks["head-2"] - landmarks["neck"]).normalized()
        axis = (Matrix.Rotation(math.radians(-18.0), 3, "X") @ up).normalized()
        center = landmarks["head"].lerp(landmarks["head-2"], 0.45)
        centers = [center + axis * (s - 0.5) * 0.04 for s in (0.0, 1.0)]
    else:
        a, b = (landmarks[j] for j in spec["ring"])
        axis = (b - a).normalized()
        centers = [a + (b - a) * t for t in spec["span"]]
    side = axis.orthogonal().normalized()
    rows = []
    for row in range(RING_ROWS):
        center = centers[0].lerp(centers[1], row / (RING_ROWS - 1))
        directions = [Matrix.Rotation(2 * math.pi * s / RING_SEGMENTS, 3, axis) @ side for s in range(RING_SEGMENTS)]
        radii = []
        for direction in directions:
            hit = tree.ray_cast(center, direction, 0.3)[0]
            assert hit is not None, "%s: no skin around the ring" % name
            radii.append((hit - center).length)
        rows.append(list(zip([center] * RING_SEGMENTS, directions, _smooth_ring(radii))))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    surface = spec["offset"] + spec["thickness"]
    # The rim at the start, the band's surface, the rim at the end
    layers = [(0, spec["offset"])] + [(r, surface) for r in range(RING_ROWS)] + [(RING_ROWS - 1, spec["offset"])]
    grid = [[bm.verts.new(c + d * (r + lift)) for c, d, r in rows[row]] for row, lift in layers]
    for i in range(len(grid) - 1):
        for s in range(RING_SEGMENTS):
            n = (s + 1) % RING_SEGMENTS
            face = bm.faces.new((grid[i][s], grid[i][n], grid[i + 1][n], grid[i + 1][s]))
            for loop, (u, v) in zip(face.loops, ((s, i), (s + 1, i), (s + 1, i + 1), (s, i + 1))):
                loop[uv].uv = (u / RING_SEGMENTS, v / (len(grid) - 1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _smooth_ring(radii, iterations=6):
    """Radii without the spikes of rays that hit an ear or a tendon: each the median of its
    neighborhood, then smoothed."""
    count = len(radii)
    radii = [sorted(radii[(i + d) % count] for d in range(-3, 4))[3] for i in range(count)]
    for _ in range(iterations):
        radii = [radii[i] * 0.5 + (radii[i - 1] + radii[(i + 1) % count]) * 0.25 for i in range(count)]
    return radii


def adopted_garment(name, spec, basemesh):
    """The MakeHuman clothes spec["from"] fitted to the basemesh and reworked (see ADOPTED), with
    the source's author and license and the body vertices it hides."""
    from bl_ext.blender_org.mpfb.entities.clothes.mhclo import Mhclo
    from bl_ext.blender_org.mpfb.services.assetservice import AssetService
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService

    source = spec["from"]
    path = AssetService.find_asset_absolute_path("%s/%s.mhclo" % (source, source), asset_subdir="clothes")
    assert path, "%s is not installed in MPFB: install the asset pack that has it" % source
    source_mhclo = Mhclo()
    source_mhclo.load(path)
    groups_before = {g.name for g in basemesh.vertex_groups}
    modifiers_before = {m.name for m in basemesh.modifiers}
    fitted = HumanService.add_mhclo_asset(path, basemesh, asset_type="Clothes", subdiv_levels=0, set_up_rigging=False)
    # Leave the basemesh as it was (its xref cache stays valid)
    for modifier in [m for m in basemesh.modifiers if m.name not in modifiers_before]:
        basemesh.modifiers.remove(modifier)
    for group in [g for g in basemesh.vertex_groups if g.name not in groups_before]:
        basemesh.vertex_groups.remove(group)
    bm = bmesh.new()
    bm.from_mesh(fitted.data)
    bpy.data.objects.remove(fitted)
    for layer in list(bm.verts.layers.deform.values()):
        bm.verts.layers.deform.remove(layer)
    if spec["cut_uv"]:
        uv = bm.loops.layers.uv.active
        u_min, u_max, v_min, v_max = spec["cut_uv"]

        def in_cut(face):
            center = sum((loop[uv].uv for loop in face.loops), Vector((0.0, 0.0))) / len(face.loops)
            return u_min < center.x < u_max and v_min < center.y < v_max

        bmesh.ops.delete(bm, geom=[f for f in bm.faces if in_cut(f)], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if spec["subdivide"]:
        obj.modifiers.new("Subdivision", "SUBSURF").levels = spec["subdivide"]
    if spec["keep"] < 1.0:
        obj.modifiers.new("Decimate", "DECIMATE").ratio = spec["keep"]
        obj.modifiers.new("Triangulate", "TRIANGULATE")
    if obj.modifiers:
        depsgraph = bpy.context.evaluated_depsgraph_get()
        obj.data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
        obj.modifiers.clear()
    credits = {
        "author": source_mhclo.author, "license": source_mhclo.license,
        "description": "Pelota tennis kit: %s, adopted from the MakeHuman asset %s" % (name, source),
    }
    return obj, credits, list(source_mhclo.delverts)


def covered_vertices(vertices, garment, mesh, margin=0.03):
    """The body `vertices` still under the garment: above its lowest point (less a margin that
    keeps the skin from showing at its hem)."""
    bottom = min(v.co.z for v in garment.data.vertices) + margin
    return [v for v in vertices if mesh.vertices[v].co.z > bottom]


def foot_vertices(mesh, faces, landmarks):
    """Body vertices inside the shoes."""
    return sorted({v for i in faces if landmarks.locate(mesh.polygons[i].center)[0] == "foot" for v in mesh.polygons[i].vertices})


def build_xref_cache(basemesh):
    """MPFB's cross reference of the basemesh, which matching garments to it needs (as MPFB's
    MakeClothes > Create xref cache does)."""
    from bl_ext.blender_org.mpfb.entities.meshcrossref import MeshCrossRef
    from bl_ext.blender_org.mpfb.services.locationservice import LocationService

    cache_dir = LocationService.get_user_cache("basemesh_xref")
    shutil.rmtree(cache_dir, ignore_errors=True)
    os.makedirs(cache_dir)
    MeshCrossRef(basemesh, after_modifiers=False, build_faces_by_group_reference=True, cache_dir=cache_dir, write_cache=True, read_cache=False)


def save_mhclo(name, obj, basemesh, hidden_vertices, credits):
    """Writes the garment as an MPFB clothes asset matched to the basemesh: KIT_DIR/<name>/.
    MPFB deletes `hidden_vertices` of the body under it."""
    from bl_ext.blender_org.mpfb.services.clothesservice import ClothesService

    obj.vertex_groups.new(name="body").add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    check = ClothesService.mesh_is_valid_as_clothes(obj, basemesh)
    assert check["all_checks_ok"], "%s is not valid as clothes: %s" % (name, check)
    properties = {"name": "pelota_" + name, "uuid": "pelota-kit-" + name, **credits}
    mhclo = ClothesService.create_mhclo_from_clothes_matching(basemesh, obj, properties_dict=properties)
    if hidden_vertices:
        mhclo.delete = True
        mhclo.delete_group = "Delete " + name
        mhclo.delverts = hidden_vertices
    directory = os.path.join(mpfb_setup.KIT_DIR, name)
    os.makedirs(directory, exist_ok=True)
    reference_scale = ClothesService.get_reference_scale(basemesh)
    mhclo.write_mhclo(os.path.join(directory, name + ".mhclo"), reference_scale=reference_scale)


def main():
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else GARMENTS
    mpfb_setup.empty_scene()
    mpfb_setup.enable_mpfb()
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService

    basemesh = HumanService.create_human(macro_detail_dict=AUTHOR_MACROS)
    mesh = evaluated_body(basemesh)
    faces = body_faces(basemesh, mesh)
    landmarks = Landmarks(basemesh, mesh)
    build_xref_cache(basemesh)
    skin = skin_object(mesh, faces)
    skin_tree = BVHTree.FromObject(skin, bpy.context.evaluated_depsgraph_get())
    own = {"author": AUTHOR, "license": LICENSE}
    for name in names:
        if name in ADOPTED:
            spec = ADOPTED[name]
            obj, credits, hidden = adopted_garment(name, spec, basemesh)
            if spec["hides"] == "feet":
                hidden = foot_vertices(mesh, faces, landmarks)
            elif spec["hides"] == "covered":
                hidden = covered_vertices(hidden, obj, mesh)
        elif name in CUT:
            garment = CutGarment(name, CUT[name], mesh, faces, landmarks)
            garment.lift()
            garment.straighten_cuffs()
            garment.smooth(CUT[name]["smooth"])
            garment.keep_outside(skin_tree)
            garment.turn_in_cuffs()
            obj, hidden = garment.to_object(), garment.hidden_vertices
            credits = dict(own, description="Pelota tennis kit: " + name)
        else:
            obj, hidden = ring_garment(name, RINGS[name], landmarks, skin), []
            credits = dict(own, description="Pelota tennis kit: " + name)
        save_mhclo(name, obj, basemesh, hidden, credits)
        print("GARMENT", name, len(obj.data.vertices), len(obj.data.polygons))
    preview = os.environ.get("KIT_PREVIEW_BLEND")
    if preview:
        bpy.ops.wm.save_as_mainfile(filepath=preview)


if __name__ == "__main__":
    main()
