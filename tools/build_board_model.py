"""
Builds the game-ready 3D board model for Royal India Ludo.

Inputs
  reference image (path below): the Royal India Ludo board render.

Outputs (in assets/board/)
  board_top_2048.jpg       the reference image rectified to a straight top-down
                           texture (the board's own colours, pavilions and lotus)
  royal_ludo_board.glb     glTF 2.0 binary, Y-up, metres, 0.5 m wide board
                           - "board_top":   textured top, UVs 0..1 over the board
                           - "board_rim":   bevelled gold edge
                           - "board_base":  deep red underside

Run:  python3 tools/build_board_model.py [reference.png]
Needs: numpy, pillow, shapely, mapbox_earcut, trimesh
"""
import sys
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image
from shapely.geometry import Polygon, box
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_REF = Path('/root/.claude/uploads/850c1ab3-e712-52c0-9a6a-8fb55f6a0e41/c97e3835-image.png')
OUT_DIR = ROOT / 'assets' / 'board'

# Outer frame corners in the reference image, pixels: TL, TR, BR, BL.
FRAME_CORNERS = np.array([[158, 14], [1522, 14], [1666, 930], [6, 930]], dtype=float)
TEX_SIZE = 2048

BOARD_CELLS = 17.4        # board width in grid cells (playfield 15 + frame)
CORNER_RADIUS = 0.7
BASE_DEPTH = 0.9          # underside depth in cells
BEVEL = 0.16              # top edge chamfer in cells
RING_POINTS = 192
BOARD_METRES = 0.5        # final width in metres


def homography(src, dst):
    a = []
    for (x, y), (u, v) in zip(src, dst):
        a.append([-x, -y, -1, 0, 0, 0, u * x, u * y, u])
        a.append([0, 0, 0, -x, -y, -1, v * x, v * y, v])
    _, _, vt = np.linalg.svd(np.array(a))
    h = vt[-1].reshape(3, 3)
    return h / h[2, 2]


def rectify(reference: Path) -> Image.Image:
    """Warps the reference so the frame becomes an axis-aligned square."""
    img = Image.open(reference).convert('RGB')
    dst = np.array([[0, 0], [TEX_SIZE, 0], [TEX_SIZE, TEX_SIZE], [0, TEX_SIZE]], dtype=float)
    # PIL needs output->input, which is the homography from the square to the image.
    h = homography(dst, FRAME_CORNERS)
    coeffs = h.flatten()[:8]
    return img.transform((TEX_SIZE, TEX_SIZE), Image.Transform.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)


def rounded_square(size, radius):
    half = size / 2
    # Shrink then grow a square: rounds every convex corner with the given radius.
    return box(-half, -half, half, half).buffer(-radius, join_style=1).buffer(radius, quad_segs=12, join_style=1)


def resample(poly: Polygon, n: int) -> np.ndarray:
    ring = poly.exterior
    pts = [ring.interpolate(i / n * ring.length).coords[0] for i in range(n)]
    return np.array(pts, dtype=float)


def loft_rings(rings):
    """Connects consecutive rings (each with the same point count). rings: list of (N,3) arrays."""
    n = len(rings[0])
    verts, faces = [], []
    for ring in rings:
        verts.append(ring)
    verts = np.vstack(verts)
    for k in range(len(rings) - 1):
        for i in range(n):
            a = k * n + i
            b = k * n + (i + 1) % n
            c = (k + 1) * n + i
            d = (k + 1) * n + (i + 1) % n
            faces.append([a, b, d])
            faces.append([a, d, c])
    return verts, np.array(faces)


def orient_outward(verts, faces, centre_xz):
    """Flips faces whose normal points towards the centre (the rim and base are convex)."""
    tri = verts[faces]
    normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    centroids = tri.mean(axis=1)
    radial = centroids.copy()
    radial[:, 1] = 0
    radial[:, 0] -= centre_xz[0]
    radial[:, 2] -= centre_xz[1]
    flip = np.einsum('ij,ij->i', normals, radial) < 0
    faces = faces.copy()
    faces[flip] = faces[flip][:, ::-1]
    return faces


def build_geometry():
    outer = rounded_square(BOARD_CELLS, CORNER_RADIUS)
    inner = rounded_square(BOARD_CELLS - 2 * BEVEL, CORNER_RADIUS - BEVEL * 0.5)
    base_poly = rounded_square(BOARD_CELLS, CORNER_RADIUS)

    n = RING_POINTS
    o = resample(outer, n)
    i_ = resample(inner, n)
    # Rings in (x, y, z): y is height, z is the board's depth axis (0 at the centre).
    def at(ring, y):
        return np.column_stack([ring[:, 0], np.full(len(ring), y), ring[:, 1]])

    # Rim: from the base edge up through the chamfer to the top surface.
    rings = [at(o, -BASE_DEPTH), at(o, -BEVEL), at(i_, 0.0)]
    rim_v, rim_f = loft_rings(rings)
    rim_f = orient_outward(rim_v, rim_f, (0, 0))
    rim = trimesh.Trimesh(rim_v, rim_f, process=False)

    # Base: flat bottom cap.
    base_v = at(resample(base_poly, n), -BASE_DEPTH)
    base_cap_v, base_cap_f = triangulate(base_poly, -BASE_DEPTH)
    base_cap = trimesh.Trimesh(base_cap_v, base_cap_f, process=False)
    if base_cap.face_normals[:, 1].mean() > 0:
        base_cap.invert()

    # Top: the textured cap at height 0 over the inner (chamfer-inset) outline.
    top_v, top_f = triangulate(inner, 0.0)
    top = trimesh.Trimesh(top_v, top_f, process=False)
    if top.face_normals[:, 1].mean() < 0:
        top.invert()

    return top, rim, base_cap


def triangulate(poly: Polygon, height: float):
    from trimesh.creation import triangulate_polygon
    verts2d, faces = triangulate_polygon(poly, engine='earcut')
    v3 = np.column_stack([verts2d[:, 0], np.full(len(verts2d), height), verts2d[:, 1]])
    return v3, faces


def make_uv(mesh: trimesh.Trimesh):
    """Planar projection over the top surface's own bounds (v=0 at the far edge, matching the image)."""
    v = mesh.vertices
    lo, hi = v[:, [0, 2]].min(axis=0), v[:, [0, 2]].max(axis=0)
    u = (v[:, 0] - lo[0]) / (hi[0] - lo[0])
    # The image's first row must sit at the far edge (min Z). trimesh and glTF viewers
    # disagree on the V origin, so V is flipped here. Verified by rendering the model.
    vv = 1.0 - (v[:, 2] - lo[1]) / (hi[1] - lo[1])
    return np.column_stack([u, vv])


def scale_to_metres(meshes):
    s = BOARD_METRES / BOARD_CELLS
    for m in meshes:
        m.apply_scale(s)


def embed_jpeg(glb_path: Path, texture: Image.Image):
    """trimesh embeds textures as PNG (about 4x larger). Re-embed the board texture as JPEG."""
    import io
    import pygltflib

    gltf = pygltflib.GLTF2().load(str(glb_path))
    buf = io.BytesIO()
    texture.convert('RGB').save(buf, 'JPEG', quality=92)
    data = buf.getvalue()
    blob = bytearray(gltf.binary_blob())
    image = gltf.images[0]
    view = gltf.bufferViews[image.bufferView]
    view.byteOffset = len(blob)
    view.byteLength = len(data)
    blob += data + b'\0' * ((-len(data)) % 4)
    image.mimeType = 'image/jpeg'
    for b in gltf.buffers:
        b.byteLength = len(blob)
    gltf.set_binary_blob(bytes(blob))
    gltf.save(str(glb_path))


def main():
    reference = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_REF
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    tex_img = rectify(reference)
    tex_path = OUT_DIR / 'board_top_2048.jpg'
    tex_img.save(tex_path, quality=95)

    top, rim, base_cap = build_geometry()

    top.visual = TextureVisuals(
        uv=make_uv(top),
        material=PBRMaterial(
            name='board_top',
            baseColorTexture=tex_img,
            baseColorFactor=[255, 255, 255, 255],
            metallicFactor=0.0,
            roughnessFactor=0.42,
        ),
    )
    rim.visual = trimesh.visual.ColorVisuals(rim, vertex_colors=np.tile([217, 164, 65, 255], (len(rim.vertices), 1)))
    base_cap.visual = trimesh.visual.ColorVisuals(base_cap, vertex_colors=np.tile([125, 26, 34, 255], (len(base_cap.vertices), 1)))

    scale_to_metres([top, rim, base_cap])

    scene = trimesh.Scene()
    scene.add_geometry(top, geom_name='board_top', node_name='board_top')
    scene.add_geometry(rim, geom_name='board_rim', node_name='board_rim')
    scene.add_geometry(base_cap, geom_name='board_base', node_name='board_base')

    glb_path = OUT_DIR / 'royal_ludo_board.glb'
    scene.export(glb_path)
    embed_jpeg(glb_path, tex_img)
    print(f'wrote {tex_path.relative_to(ROOT)} and {glb_path.relative_to(ROOT)}')
    print(f'triangles: top={len(top.faces)} rim={len(rim.faces)} base={len(base_cap.faces)}')


if __name__ == '__main__':
    main()
