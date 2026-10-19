// Keyboard-switch fidget cube, frame + face-plate version (the style of the original).
// An open skeleton cube plus six identical face plates. Each plate holds one MX-style
// switch and presses into a window of the frame. Every part prints flat, no supports.
//
//   openscad -o frame.stl -D 'part="frame"' frame_cube.scad
//   openscad -o plate.stl -D 'part="plate"' frame_cube.scad     (print 6)

/* [What to render] */
part = "frame"; // [frame, plate, assembly]

/* [Size] */
// Distance between the outer faces of opposite plates. 30 mm keeps the pins of
// neighbouring switches apart in every rotation (see tools/check_fit.py).
switch_span = 30;
// Thickness of the frame's bars.
bar = 3;
// Rounding of the frame's outer edges.
frame_round = 1;

/* [Switch fit] */
// Square switch cutout. MX nominal is 14.0; FDM holes usually print a bit small.
hole_size = 14.1;
// Thickness of the plate the switch clips snap under (MX plate spec is 1.5).
plate_thickness = 1.5;
// 45 degree lead-in on the outer edge of the hole.
hole_chamfer = 0.3;
// Opening behind the plate that the switch clips spring out into.
clip_pocket = 15.8;

/* [Plate-to-frame fit] */
// Gap per side between a plate's locating ring and the frame window.
fit_gap = 0.15;
// Crush ribs on the locating ring: how far they stand proud of the gap. 0 = none.
rib = 0.25;

/* [Hidden] */
$fn = 48;
eps = 0.01;
F = switch_span - 2 * plate_thickness;  // frame outer size
W = F - 2 * bar;                         // window size
ring_out = W - 2 * fit_gap;              // plate locating ring, outside
ring_depth = bar - 0.2;                  // stays just inside the frame bar
plate_size = F - 0.2;

face_rotations = [[0, 0, 0], [180, 0, 0], [0, 90, 0], [0, -90, 0], [-90, 0, 0], [90, 0, 0]];

module rounded_cube(size, r) {
    h = size / 2 - r;
    hull()
        for (x = [-1, 1], y = [-1, 1], z = [-1, 1])
            translate([x * h, y * h, z * h]) sphere(r);
}

module frame() {
    difference() {
        rounded_cube(F, frame_round);
        for (r = [[0, 0, 0], [90, 0, 0], [0, 90, 0]])
            rotate(r) cube([W, W, F + 2], center = true);
    }
}

// Plate as printed: outer face on the bed (z = 0), locating ring pointing up.
module plate() {
    c = 0.5;  // chamfer on the plate's outer edges
    difference() {
        union() {
            // Plate with chamfered outer edges.
            hull() {
                linear_extrude(eps) square(plate_size - 2 * c, center = true);
                translate([0, 0, c]) linear_extrude(plate_thickness - c) square(plate_size, center = true);
            }
            // Locating ring that drops into the frame window.
            translate([0, 0, plate_thickness - eps])
                linear_extrude(ring_depth + eps)
                    difference() {
                        square(ring_out, center = true);
                        square(clip_pocket, center = true);
                    }
            // Crush ribs: give a snug press fit that tolerates printer variation.
            if (rib > 0)
                for (a = [0 : 90 : 270], s = [-1, 1])
                    rotate(a) translate([ring_out / 2, s * ring_out / 4, plate_thickness])
                        crush_rib(ring_depth);
        }
        // Switch hole and lead-in chamfer (on the outer face, which is on the bed).
        translate([0, 0, -1]) linear_extrude(plate_thickness + ring_depth + 2)
            square(hole_size, center = true);
        translate([0, 0, -eps])
            linear_extrude(hole_chamfer + eps, scale = hole_size / (hole_size + 2 * hole_chamfer))
                square(hole_size + 2 * hole_chamfer, center = true);
    }
}

// Vertical rib on the outside of the ring, tapered at the top for a lead-in.
module crush_rib(h) {
    w = 0.8;
    lead = min(1, h / 2);
    hull() {
        translate([-eps, -w / 2, 0]) cube([eps + fit_gap + rib, w, h - lead]);
        translate([-eps, -w / 2, 0]) cube([eps, w, h]);
    }
}

module assembly() {
    frame();
    for (r = face_rotations)
        rotate(r) translate([0, 0, switch_span / 2]) mirror([0, 0, 1]) plate();
}

if (part == "frame") {
    frame();
} else if (part == "plate") {
    plate();
} else if (part == "assembly") {
    assembly();
}
