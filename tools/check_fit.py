"""Collision check for the switch cube.

Places a simplified MX switch (with clips, pins, centre post and the two
5-pin PCB pegs) plus a 1u keycap on every face of the printed cube, in all
four rotations, and reports any overlap:

  * switch vs. cube body          (does each switch fit its pocket?)
  * switch vs. switch             (do pins/pegs of neighbouring switches clash?)
  * keycap (bottomed out) vs. cube / neighbouring keycaps

Usage: python3 tools/check_fit.py path/to/cube.stl [cube_size]
Dimensions are deliberately on the generous side of the MX spec.
"""

import itertools
import sys

import numpy as np
import trimesh
from manifold3d import CrossSection, Manifold, Mesh, OpType

# --- simplified MX switch, local frame: z = 0 is the face (plate top), +z outward
HOLE = 14.0          # bottom housing width that passes through the plate
TOP_W = 15.6         # top housing width, sits on the face
TOP_H = 6.6          # top housing height above the plate
BODY_D = 5.0         # housing depth below the plate top
CLIP_W = 15.0        # width across the sprung clips (relaxed)
CLIP_Z = (-2.6, -1.5)
PIN_L = 3.5          # metal pins below the housing (spec 3.3, plus margin)
POST_L = 3.3         # centre post / PCB pegs below the housing
# Both handednesses of the pin layout (datasheets and footprints disagree on the sign).
PINS = [(-3.81, 2.54), (2.54, 5.08), (-3.81, -2.54), (2.54, -5.08)]
PEGS = [(-5.08, 0.0), (5.08, 0.0)]

# --- 1u keycap, bottomed out: skirt is ~2 mm above the plate on common profiles
CAP_W = 18.2
CAP_Z_PRESSED = 2.0
CAP_H = 11.0
CAP_TOP_W = 13.0


def box(sx, sy, z0, z1, cx=0.0, cy=0.0):
    return Manifold.cube([sx, sy, z1 - z0], center=True).translate(
        [cx, cy, (z0 + z1) / 2])


def cyl(d, z0, z1, cx, cy):
    return Manifold.cylinder(z1 - z0, d / 2, d / 2, 32).translate([cx, cy, z0])


def switch_body():
    parts = [
        box(TOP_W, TOP_W, 0.001, TOP_H),               # top housing (sits on the face)
        # Bottom housing. Through the 1.5 mm lip it is drawn slightly narrow: how
        # tightly the hole itself grips is a printer-calibration question (see the
        # fit-test piece), not a geometry one.
        box(HOLE, HOLE, -BODY_D, -1.5),
        box(HOLE - 0.3, HOLE - 0.3, -1.5, 0.001),
        box(4.0, CLIP_W, *CLIP_Z),                     # clips on north/south
        cyl(4.0, -BODY_D - POST_L, -BODY_D + 0.01, 0, 0),
    ]
    parts += [cyl(1.5, -BODY_D - PIN_L, -BODY_D + 0.01, x, y) for x, y in PINS]
    parts += [cyl(1.75, -BODY_D - POST_L, -BODY_D + 0.01, x, y) for x, y in PEGS]
    return Manifold.batch_boolean(parts, OpType.Add)


def keycap_pressed():
    # Truncated pyramid from the skirt up.
    k = CAP_TOP_W / CAP_W
    return Manifold.extrude(CrossSection.square([CAP_W, CAP_W], center=True),
                            CAP_H, scale_top=[k, k]).translate([0, 0, CAP_Z_PRESSED])


# Rotation matrices taking local +Z to each face normal (matches face_rotations in the .scad).
def rot(axis, deg):
    return trimesh.transformations.rotation_matrix(np.radians(deg), axis)


FACES = {
    "+Z": np.eye(4),
    "-Z": rot([1, 0, 0], 180),
    "+X": rot([0, 1, 0], 90),
    "-X": rot([0, 1, 0], -90),
    "+Y": rot([1, 0, 0], -90),
    "-Y": rot([1, 0, 0], 90),
}


def place(m, face, spin, half):
    """Spin about the switch axis, push out to the face, then orient onto it."""
    t = rot([0, 0, 1], spin) @ np.eye(4)
    t = trimesh.transformations.translation_matrix([0, 0, half]) @ t
    t = FACES[face] @ t
    return m.transform(t[:3, :4])


def to_manifold(path):
    tm = trimesh.load(path)
    mesh = Mesh(vert_properties=np.asarray(tm.vertices, dtype=np.float32),
                tri_verts=np.asarray(tm.faces, dtype=np.uint32))
    return Manifold(mesh)


def overlap(a, b):
    return (a ^ b).volume()


def main():
    path = sys.argv[1]
    size = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
    half = size / 2
    body = to_manifold(path)
    sw, cap = switch_body(), keycap_pressed()
    tol = 0.01  # mm^3; anything above is a real clash
    problems = 0

    worst = 0.0
    for face in FACES:
        for spin in (0, 90, 180, 270):
            v = overlap(body, place(sw, face, spin, half))
            worst = max(worst, v)
            if v > tol:
                problems += 1
                print(f"switch {face} rot {spin}: overlaps cube body by {v:.3f} mm^3")
    print(f"switch vs body: worst overlap {worst:.4f} mm^3")

    worst = 0.0
    for (fa, fb) in itertools.combinations(FACES, 2):
        for sa, sb in itertools.product((0, 90, 180, 270), repeat=2):
            v = overlap(place(sw, fa, sa, half), place(sw, fb, sb, half))
            worst = max(worst, v)
            if v > tol:
                problems += 1
                print(f"switch {fa}@{sa} vs {fb}@{sb}: {v:.3f} mm^3")
    print(f"switch vs switch (all 240 rotation pairs): worst overlap {worst:.4f} mm^3")

    worst = 0.0
    for face in FACES:
        c = place(cap, face, 0, half)
        worst = max(worst, overlap(body, c))
        for other in FACES:
            if other != face:
                worst = max(worst, overlap(c, place(cap, other, 0, half)))
                worst = max(worst, overlap(c, place(sw, other, 0, half)))
    print(f"pressed keycap vs body/neighbours: worst overlap {worst:.4f} mm^3")
    if worst > tol:
        problems += 1

    print("RESULT:", "OK - everything fits" if problems == 0 else f"{problems} problem(s)")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
