"""Draw a cross-section through the middle of the cube with the stand-in switches.

Usage: python3 tools/render_section.py path/to/cube.stl out.png [cube_size]
"""

import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import trimesh
from matplotlib.patches import Polygon

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from check_fit import keycap_pressed, place, switch_body  # noqa: E402

PLANE = dict(plane_origin=[0, 0.3, 0], plane_normal=[0, 1, 0])


def section_polys(mesh):
    s = mesh.section(**PLANE)
    if s is None:
        return []
    # Project onto the XZ plane directly so the axes stay put.
    polys = []
    for entity in s.entities:
        pts = s.vertices[entity.points]
        polys.append(pts[:, [0, 2]])
    return polys


def manifold_to_trimesh(m):
    mesh = m.to_mesh()
    return trimesh.Trimesh(mesh.vert_properties[:, :3], mesh.tri_verts)


def main():
    stl, out = sys.argv[1], sys.argv[2]
    size = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
    half = size / 2

    fig, ax = plt.subplots(figsize=(7, 7), dpi=150)
    for poly in section_polys(trimesh.load(stl)):
        ax.add_patch(Polygon(poly, closed=True, facecolor="#d9d9d4", edgecolor="#555", lw=0.6))

    sw = switch_body()
    cap = keycap_pressed()
    for face, color in (("+Z", "#2f7fc1"), ("-Z", "#e8692c"), ("+X", "#7a4bb3"), ("-X", "#7cc85a")):
        for poly in section_polys(manifold_to_trimesh(place(sw, face, 0, half))):
            ax.add_patch(Polygon(poly, closed=True, facecolor="#9fd0f5", edgecolor="#2a6c9c",
                                 lw=0.6, alpha=0.85))
        for poly in section_polys(manifold_to_trimesh(place(cap, face, 0, half))):
            ax.add_patch(Polygon(poly, closed=True, facecolor=color, edgecolor="none", alpha=0.35))

    lim = half + 15
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.set_aspect("equal")
    ax.grid(True, color="#eee", lw=0.5)
    ax.set_xlabel("mm")
    ax.set_title(f"{size:g} mm cube, cut through the middle\n"
                 "grey = printed body, blue = switches, tint = keycaps fully pressed", fontsize=10)
    ax.annotate("1.5 mm lip\n(clips snap under it)", xy=(-7.6, half - 0.9), xytext=(-lim + 1, half + 9),
                fontsize=8, arrowprops=dict(arrowstyle="->", lw=0.6))
    ax.annotate("clip pocket", xy=(7.9, half - 3.2), xytext=(half + 1, half + 9),
                fontsize=8, arrowprops=dict(arrowstyle="->", lw=0.6))
    ax.annotate("pins / centre post\nclearance", xy=(-1, half - 9.0), xytext=(-lim + 1, -lim + 3),
                fontsize=8, arrowprops=dict(arrowstyle="->", lw=0.6))
    fig.tight_layout()
    fig.savefig(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
