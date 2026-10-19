// Printable 1u MX keycap, generated with the KeyV2 library (GPL-3.0,
// https://github.com/rsheldiii/KeyV2), which is pulled in as a git submodule:
//   git submodule update --init
// Needs a recent OpenSCAD (2025 or a nightly); 2021.01 can't run KeyV2.
//
//   openscad -o keycap.stl -D stem_slop=0.4 keycap.scad
//
// Print it upright (skirt on the bed); the thin "tines" under the stem are
// KeyV2's built-in support and snap off.
include <lib/KeyV2/includes.scad>

// Keycap profile. DSA is short and the same on every row, which suits a cube.
profile = "dsa"; // [dsa, cherry, oem, sa, dcs, g20]
row = 3;
// Extra clearance in the stem's cross slot, in mm. Too tight on the switch: go up.
// Falls off by itself: go down.
stem_slop = 0.35;
// Optional engraved legend, e.g. "A" or "♥". Leave empty for a blank cap.
legend_text = "";

key_profile(profile, row)
    cherry(stem_slop)
        legend(legend_text)
            key();
