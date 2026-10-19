// Printable 1u MX keycap, generated with the KeyV2 library (GPL-3.0,
// https://github.com/rsheldiii/KeyV2), which is pulled in as a git submodule:
//   git submodule update --init
// Needs a recent OpenSCAD (2025 or a nightly); 2021.01 can't run KeyV2.
//
//   openscad -o keycap.stl -D cross_slop=0.2 keycap.scad
//
// Print it upright (skirt on the bed); the thin "tines" under the stem are
// KeyV2's built-in support and snap off.
include <lib/KeyV2/includes.scad>

// Keycap profile. DSA is short and the same on every row, which suits a cube.
profile = "dsa"; // [dsa, cherry, oem, sa, dcs, g20]
row = 3;
// Extra clearance in the "+" hole that grips the switch stem, in mm (KeyV2's
// $stem_inner_slop). Too tight: go up. Falls off: go down.
cross_slop = 0.2;
// Optional engraved legend, e.g. "A" or "♥". Leave empty for a blank cap.
legend_text = "";

// Set in a local scope: a top-level reassignment would take effect where KeyV2's
// settings first define it, before cross_slop exists.
let($stem_inner_slop = cross_slop)
    key_profile(profile, row)
        cherry()
            legend(legend_text)
                key();
