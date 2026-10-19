"""Re-mesh an STL through Manifold to drop the zero-area slivers OpenSCAD can leave
behind (KeyV2 keycaps have dozens). Writes a single watertight binary STL.

Usage: python3 tools/clean_mesh.py in.stl out.stl
"""

import sys

import numpy as np
import trimesh
from manifold3d import Manifold, Mesh

src, dst = sys.argv[1], sys.argv[2]
tm = trimesh.load(src)
m = Manifold(Mesh(vert_properties=np.asarray(tm.vertices, dtype=np.float32),
                  tri_verts=np.asarray(tm.faces, dtype=np.uint32)))
out = m.as_original().simplify(1e-4).to_mesh()
clean = trimesh.Trimesh(out.vert_properties[:, :3], out.tri_verts)
if not clean.is_watertight or len(clean.split(only_watertight=False)) != 1:
    sys.exit(f"{src}: still not a single watertight body after cleaning")
clean.export(dst)
print(f"{dst}: {len(clean.faces)} faces, {clean.volume:.1f} mm^3")
