#!/usr/bin/env bash
# Rebuild every STL and preview image, then run the collision check.
# Needs: a recent OpenSCAD (2025 or a nightly; set OPENSCAD=/path/to/it if it isn't
# on PATH), xvfb-run (for PNGs), python3 with trimesh manifold3d matplotlib, and the
# KeyV2 submodule (git submodule update --init).
set -euo pipefail
cd "$(dirname "$0")/.."

OPENSCAD=${OPENSCAD:-openscad}
SIZE=${SIZE:-30}
HOLES=${HOLES:-"13.9 14.0 14.1 14.2"}
FITS=${FITS:-"0.1 0.2 0.3 0.4"}

scad() { "$OPENSCAD" --backend=manifold --export-format=binstl -q "$@"; }

mkdir -p stl images

# Printable keycaps (KeyV2), one per cross-hole clearance. First, because the previews use one.
for s in $FITS; do
    raw=$(mktemp --suffix=.stl)
    scad -o "$raw" -D "cross_slop=$s" cad/keycap.scad
    python3 tools/clean_mesh.py "$raw" "stl/keycap_dsa_fit${s}.stl"
    rm -f "$raw"
done

for h in $HOLES; do
    out="stl/switch_cube_${SIZE}mm_hole${h}.stl"
    echo "-> $out"
    scad -o "$out" -D 'part="cube"' -D "cube_size=$SIZE" -D "hole_size=$h" cad/switch_cube.scad
    python3 tools/check_fit.py "$out" "$SIZE" | tail -1
done

# Frame + face-plate version (the original cube's style): one frame, print the plate 6x.
echo "-> stl/frame_cube_frame.stl"
scad -o stl/frame_cube_frame.stl -D 'part="frame"' -D "switch_span=$SIZE" cad/frame_cube.scad
for h in $HOLES; do
    echo "-> stl/frame_cube_plate_hole${h}.stl"
    scad -o "stl/frame_cube_plate_hole${h}.stl" -D 'part="plate"' -D "switch_span=$SIZE" -D "hole_size=$h" cad/frame_cube.scad
done
asm=$(mktemp --suffix=.stl)
scad -o "$asm" -D 'part="assembly"' -D "switch_span=$SIZE" cad/frame_cube.scad
python3 tools/check_fit.py "$asm" "$SIZE" | tail -1
rm -f "$asm"

# Fully printed click module (experimental), plus the tuning variants.
echo "-> stl/click_*.stl"
scad -o stl/click_plate.stl -D 'part="print_plate"' cad/click_module.scad
scad -o stl/click_plate_soft.stl -D 'part="print_plate"' -D fin_t=0.6 cad/click_module.scad
scad -o stl/click_plunger.stl -D 'part="print_plunger"' cad/click_module.scad
scad -o stl/click_spring.stl -D 'part="print_spring"' cad/click_module.scad
scad -o stl/click_spring_light.stl -D 'part="print_spring"' -D arm_t=2.5 cad/click_module.scad
OPENSCAD="$OPENSCAD" python3 tools/check_click.py --plot images/click_force.png | tail -1

echo "-> stl/switch_fit_test.stl"
scad -o stl/switch_fit_test.stl -D 'part="fit_test"' cad/switch_cube.scad

render() {
    xvfb-run -a "$OPENSCAD" -q -o "images/$1.png" -D "view=\"$1\"" -D "cube_size=$SIZE" \
        --imgsize=1000,1000 --camera="$2" --colorscheme=Tomorrow --projection=p cad/preview.scad
}
render assembled 0,0,0,62,0,38,170
render exploded 0,0,0,62,0,38,245
render frame_assembled 0,0,0,62,0,38,170
render frame_exploded 0,0,0,62,0,38,330
render printed_assembled 0,0,0,62,0,38,170
xvfb-run -a "$OPENSCAD" -q -o images/printed_module.png -D 'view="printed_module"' \
    --imgsize=1000,800 --camera=10,12,0,50,0,25,135 --colorscheme=Tomorrow --projection=p cad/preview.scad
python3 tools/render_section.py "stl/switch_cube_${SIZE}mm_hole14.1.stl" images/section.png "$SIZE"
