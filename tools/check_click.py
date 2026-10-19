"""Checks for the fully printed click module (cad/click_module.scad).

1. Inside one module, over the whole stroke: the plunger may only touch the plate
   at the click fins (that contact is what bends them); nothing else may overlap.
2. Whole cube: frame + six modules (plates, plungers at rest and fully pressed,
   the space the springs sweep through, printed keycaps), every face in every
   rotation against every other face. Nothing may overlap.
3. Force curve: fin bending from the tooth geometry, spring rate from the beam
   model in spring_fe.py, friction both ways. The spring must always beat the
   fins on the way back up, or the key would stay stuck down.

Usage: OPENSCAD=/path/to/openscad python3 tools/check_click.py [--plot out.png]
"""

import itertools
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
import trimesh
from manifold3d import Manifold, Mesh

sys.path.insert(0, os.path.dirname(__file__))
from spring_fe import solve as spring_solve  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
SCAD = os.path.join(ROOT, "cad", "click_module.scad")
FRAME_SCAD = os.path.join(ROOT, "cad", "frame_cube.scad")
KEYCAP = os.path.join(ROOT, "stl", "keycap_dsa_fit0.2.stl")
OPENSCAD = os.environ.get("OPENSCAD", "openscad")
TOL = 0.01  # mm^3

E_PETG = 2000.0  # MPa, printed PETG (PLA is ~3000; both parts scale together)
FRICTION = (0.25, 0.4)  # plastic on plastic, range checked


def params():
    """Top-level numeric assignments from the .scad file."""
    out = {}
    for line in open(SCAD):
        m = re.match(r"^(\w+)\s*=\s*([-\d.]+)\s*;", line)
        if m:
            out[m.group(1)] = float(m.group(2))
    return out


def render(expr, **defs):
    """Render an OpenSCAD expression in the click module's scope to a Manifold."""
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "w.scad")
        out = os.path.join(d, "w.stl")
        with open(src, "w") as f:
            f.write(f"use <{os.path.abspath(SCAD)}>\n{expr}\n")
        args = [OPENSCAD, "--backend=manifold", "--export-format=binstl", "-q", "-o", out]
        for k, v in defs.items():
            args += ["-D", f"{k}={v}"]
        subprocess.run(args + [src], check=True)
        return load(out)


def load(path):
    tm = trimesh.load(path)
    return Manifold(Mesh(vert_properties=np.asarray(tm.vertices, dtype=np.float32),
                         tri_verts=np.asarray(tm.faces, dtype=np.uint32)))


def rot(axis, deg):
    return trimesh.transformations.rotation_matrix(math.radians(deg), axis)


FACES = [np.eye(4), rot([1, 0, 0], 180), rot([0, 1, 0], 90), rot([0, 1, 0], -90),
         rot([1, 0, 0], -90), rot([1, 0, 0], 90)]


def place(m, face, spin, half):
    t = FACES[face] @ trimesh.transformations.translation_matrix([0, 0, half]) @ rot([0, 0, 1], spin)
    return m.transform(t[:3, :4])


def check_internal(p):
    print("1. plunger vs plate over the stroke")
    plate = render("click_plate();")
    ok = True
    fin_y0 = p["col"] if "col" in p else None  # noqa: F841 (documented below)
    for x in np.linspace(0, p["travel"], 14):
        plunger = render(f"translate([0, 0, {-x}]) click_plunger();")
        inter = plate ^ plunger
        v = inter.volume()
        if v < TOL:
            continue
        lo, hi = np.array(inter.bounding_box()[:3]), np.array(inter.bounding_box()[3:])
        # Allowed: only inside the fins' footprint (|y| between fin face and fin back,
        # z within the fin height, x within the tooth span).
        fin_face = 4.4 / 2 + p["fin_gap"]
        inside_fins = (min(abs(lo[1]), abs(hi[1])) >= fin_face - 1e-3 and
                       max(abs(lo[1]), abs(hi[1])) <= fin_face + p["fin_t"] + 1e-3 and
                       lo[2] >= -p["fin_h"] - 1e-3 and hi[2] <= 1e-3)
        both_sides = lo[1] < 0 < hi[1]
        if both_sides:
            # Two separate fin contacts; check each half.
            halves = [inter ^ Manifold.cube([40, 40, 40]).translate([-20, s, -20]) for s in (0, -40)]
            inside_fins = all(
                h.volume() < TOL or (
                    min(abs(h.bounding_box()[1]), abs(h.bounding_box()[4])) >= fin_face - 1e-3 and
                    max(abs(h.bounding_box()[1]), abs(h.bounding_box()[4])) <= fin_face + p["fin_t"] + 1e-3 and
                    h.bounding_box()[2] >= -p["fin_h"] - 1e-3 and h.bounding_box()[5] <= 1e-3)
                for h in halves)
        status = "fin contact" if inside_fins else "UNEXPECTED"
        ok &= inside_fins
        print(f"   press {x:4.2f} mm: overlap {v:6.3f} mm^3 ({status})")
    print("   ", "OK" if ok else "PROBLEM: plunger hits something other than the fins")
    return ok


def check_cube(p):
    print("2. whole cube: frame + 6 modules, all rotations")
    half = p["switch_span"] / 2
    T = p["travel"]
    with tempfile.TemporaryDirectory() as d:
        fpath = os.path.join(d, "frame.stl")
        subprocess.run([OPENSCAD, "--backend=manifold", "--export-format=binstl", "-q", "-o", fpath,
                        "-D", 'part="frame"', FRAME_SCAD], check=True)
        frame = load(fpath)
    keycap = load(KEYCAP)
    plate = render("click_plate();", rib=0)
    # Everything a module occupies over its stroke, in module coordinates (outer face z=0).
    sweep = (render("hull() { click_plunger(); translate([0, 0, %f]) click_plunger(); }" % -T) +
             render("spring_envelope();") +
             keycap.translate([0, 0, p["travel"] - T]) + keycap.translate([0, 0, p["travel"]]))
    sweep = sweep.translate([0, 0, 0])
    module = plate + sweep
    # Shift so the module's outer face sits on the cube face (place() adds half).
    ok = True
    worst = 0.0
    for f in range(6):
        v = (frame ^ place(module, f, 0, half)).volume()
        worst = max(worst, v)
    print(f"   frame vs modules: worst overlap {worst:.4f} mm^3")
    ok &= worst < TOL
    worst = 0.0
    for fa, fb in itertools.combinations(range(6), 2):
        for sa, sb in itertools.product((0, 90, 180, 270), repeat=2):
            v = (place(module, fa, sa, half) ^ place(module, fb, sb, half)).volume()
            worst = max(worst, v)
    print(f"   module vs module (15 face pairs x 16 rotations): worst overlap {worst:.4f} mm^3")
    ok &= worst < TOL
    print("   ", "OK" if ok else "PROBLEM")
    return ok


def force_curve(p, plot=None):
    print("3. force curve")
    col_y = 4.4
    ramp = math.tan(math.radians(p["ramp_angle"]))
    roof = math.tan(math.radians(p["roof_angle"]))
    h = p["tooth_h"]
    z_apex0 = -p["fin_h"] + p["click_at"]

    def protrusion(z):  # tooth profile at rest, beyond the column face
        if z <= z_apex0:
            return max(0.0, h - (z_apex0 - z) * ramp)
        return max(0.0, h - (z - z_apex0) * roof)

    def deflection(x):  # fin bend at press x: the tooth's highest point along the fin's height
        lo, hi = x - p["fin_h"], x  # fin's z-range, in the tooth's rest frame
        if lo <= z_apex0 <= hi:
            top = h
        else:
            top = protrusion(hi) if z_apex0 > hi else protrusion(lo)
        return max(0.0, top - p["fin_gap"])

    # Fin: cantilever clamped at fin_root, loaded at the middle of the tooth.
    lever = p["fin_root"] - (0.4 + 2.3) / 2
    I = p["fin_h"] * p["fin_t"] ** 3 / 12
    k_fin = 3 * E_PETG * I / lever ** 3
    k_spring, _, shear, _, _ = spring_solve(arms=int(p["arms"]), sweep=p["arm_sweep"],
                                            r_in=p["hub_r"] + p["arm_w"] / 2,
                                            r_out=p["spring_in_r"] - p["arm_w"] / 2,
                                            w=p["arm_w"], t=p["arm_t"], E=E_PETG, travel=1.0)
    xs = np.linspace(0, p["travel"], 261)
    d = np.array([deflection(x) for x in xs])
    slope = np.gradient(d, xs)
    spring = k_spring * (p["preload"] + xs)
    fin_n = 2 * k_fin * d  # both fins, sideways force

    def axial(mu, direction):
        # Axial force the fins put on the plunger, opposing (+) or helping (-) motion.
        s = slope * direction
        return fin_n * (s + mu) / np.maximum(1 - mu * s, 0.2)

    press = spring + axial(FRICTION[0], +1)
    ok = True
    for mu in FRICTION:
        resist_up = fin_n * ((-slope) + mu) / np.maximum(1 - mu * (-slope), 0.2)
        margin = spring - resist_up
        worst = margin.min()
        at = xs[margin.argmin()]
        print(f"   return stroke, friction {mu}: worst spare spring force {worst:+.2f} N at {at:.2f} mm")
        ok &= worst > 0
    peak = press.max()
    i_click = np.argmin(np.where(xs > p["click_at"] - 0.05, np.gradient(press, xs), 1e9))
    print(f"   fin {k_fin:.2f} N/mm each, max bend {d.max():.2f} mm; spring {k_spring:.2f} N/mm, "
          f"peak shear strain {100 * shear * (p['preload'] + p['travel']):.1f} %")
    print(f"   press force: {press[0] * 102:.0f} gf at rest, peak {peak * 102:.0f} gf, "
          f"{spring[-1] * 102:.0f} gf at bottom-out; click at ~{xs[i_click]:.1f} mm")
    print("   ", "OK - the spring always brings the key back" if ok else "PROBLEM: key may stick down")
    if plot:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(7, 4.2), dpi=130)
        ax.plot(xs, press * 102, label="pressing (friction 0.25)", color="#2f7fc1", lw=2)
        for mu, ls in zip(FRICTION, ("-", "--")):
            ret = spring - fin_n * ((-slope) + mu) / np.maximum(1 - mu * (-slope), 0.2)
            ax.plot(xs, ret * 102, ls, color="#e8692c", lw=1.5,
                    label=f"spring's spare push on release (friction {mu})")
        ax.plot(xs, spring * 102, ":", color="#777", label="spring alone")
        ax.axhline(0, color="k", lw=0.6)
        ax.axvline(xs[i_click], color="#7a4bb3", lw=0.8, ls="--")
        ax.text(xs[i_click] + 0.03, peak * 102 * 0.95, "click", color="#7a4bb3")
        ax.set_xlabel("key travel (mm)")
        ax.set_ylabel("force (grams)")
        ax.set_title("Printed click module: estimated force curve (PETG)")
        ax.legend(fontsize=7, loc="upper left")
        ax.grid(True, lw=0.3)
        fig.tight_layout()
        fig.savefig(plot)
        print("   wrote", plot)
    return ok


def main():
    plot = sys.argv[sys.argv.index("--plot") + 1] if "--plot" in sys.argv else None
    p = params()
    results = [check_internal(p), check_cube(p), force_curve(p, plot)]
    print("RESULT:", "OK" if all(results) else "PROBLEM")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
