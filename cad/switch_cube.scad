// Keyboard-switch fidget cube
// One-piece body that holds six MX-style plate-mount switches, one per face.
// Print on any face, no supports. Push the switches in from outside, add keycaps.
//
// Render a part from the command line, e.g.:
//   openscad -o cube.stl -D 'part="cube"' switch_cube.scad
//   openscad -o fit_test.stl -D 'part="fit_test"' switch_cube.scad

/* [What to render] */
part = "cube"; // [cube, fit_test, section]

/* [Cube] */
// Outer edge length. 30 mm leaves room for any MX switch (3- or 5-pin) in any rotation.
cube_size = 30;
// Rounding radius of the cube's edges and corners.
edge_radius = 3;

/* [Switch fit] */
// Square switch cutout. MX nominal is 14.0; FDM holes usually print a bit small.
hole_size = 14.1;
// Thickness of the lip the switch clips snap under (MX plate spec is 1.5).
plate_thickness = 1.5;
// 45 degree lead-in on the outer edge of each hole (also hides elephant's foot).
hole_chamfer = 0.3;
// Square pocket under the lip that the switch clips spring out into.
clip_pocket = 15.8;
// Face to bottom of the clip pocket (MX housing reaches 5.0 below the plate top).
body_depth = 5.8;
// Square pocket for the pins, centre post and optional PCB pegs.
pin_pocket = 13.0;
// Face to bottom of the pin pocket (5.0 housing + ~3.3 pins + clearance).
pin_depth = 9.3;

/* [Fit test] */
// Hole sizes to try on the fit-test piece.
test_sizes = [13.9, 14.0, 14.1, 14.2];

/* [Hidden] */
$fn = 64;
A = cube_size / 2;
eps = 0.01;

// Orientation of each face: rotates local +Z (the face normal) onto the face.
face_rotations = [
    [0, 0, 0],      // +Z
    [180, 0, 0],    // -Z
    [0, 90, 0],     // +X
    [0, -90, 0],    // -X
    [-90, 0, 0],    // +Y
    [90, 0, 0],     // -Y
];

module rounded_cube(size, r) {
    h = size / 2 - r;
    hull()
        for (x = [-1, 1], y = [-1, 1], z = [-1, 1])
            translate([x * h, y * h, z * h]) sphere(r);
}

// Everything removed for one switch, for a face whose outer plane is z = face_z.
module switch_cutout(face_z, hole = hole_size) {
    // Through hole in the lip.
    translate([0, 0, face_z - plate_thickness - eps])
        linear_extrude(plate_thickness + 1)
            square(hole, center = true);
    // Lead-in chamfer.
    translate([0, 0, face_z - hole_chamfer])
        linear_extrude(hole_chamfer + eps, scale = (hole + 2 * (hole_chamfer + eps)) / hole)
            square(hole, center = true);
    // Clip pocket directly under the lip.
    translate([0, 0, face_z - body_depth])
        linear_extrude(body_depth - plate_thickness)
            square(clip_pocket, center = true);
    // 45 degree step down to the pin pocket, so no face orientation prints a flat ledge.
    taper = (clip_pocket - pin_pocket) / 2;
    translate([0, 0, face_z - body_depth - taper])
        linear_extrude(taper + eps, scale = clip_pocket / pin_pocket)
            square(pin_pocket, center = true);
    // Pin pocket below that.
    translate([0, 0, face_z - pin_depth])
        linear_extrude(pin_depth - body_depth + eps)
            square(pin_pocket, center = true);
}

module switch_cube() {
    difference() {
        rounded_cube(cube_size, edge_radius);
        for (r = face_rotations)
            rotate(r) switch_cutout(A);
        // The six pin pockets fence off the centre, so hollow it out rather
        // than leave a loose block floating inside.
        cube(2 * (A - pin_depth) + 2 * eps, center = true);
    }
}

// L-shaped coupon: the same lip + pocket geometry in a flat plate (like the
// top/bottom faces) and in an upright wall (like the four side faces).
module fit_test() {
    n = len(test_sizes);
    pitch = 20;
    width = n * pitch;
    plate_depth = 30;
    wall_height = 22;
    base_t = plate_thickness;
    hole_y = plate_depth - 12;  // flat holes sit near the wall
    label_y = 4;

    // Flat plate with holes and raised labels.
    difference() {
        cube([width, plate_depth, base_t]);
        for (i = [0 : n - 1])
            translate([pitch / 2 + i * pitch, hole_y, 0])
                switch_hole_2d_cut(test_sizes[i], base_t);
    }
    for (i = [0 : n - 1])
        translate([pitch / 2 + i * pitch, label_y, base_t - eps])
            linear_extrude(0.6)
                text(one_decimal(test_sizes[i]), size = 3.6, halign = "center",
                     font = "Liberation Sans:style=Bold");

    // Upright wall with holes on the back edge of the plate; switches go in
    // from the front, their bodies stick out behind.
    translate([0, plate_depth, 0])
        difference() {
            cube([width, plate_thickness, wall_height]);
            for (i = [0 : n - 1])
                translate([pitch / 2 + i * pitch, plate_thickness, base_t + 3 + 7.1])
                    rotate([90, 0, 0])
                        switch_hole_2d_cut(test_sizes[i], plate_thickness);
        }
    // Triangular gussets behind the wall, clear of the switch bodies.
    for (x = [0, width - 2])
        translate([x + 2, plate_depth + plate_thickness - eps, 0])
            rotate([0, -90, 0])
                linear_extrude(2)
                    polygon([[0, 0], [wall_height * 0.7, 0], [0, 8]]);
}

// "14" -> "14.0" (OpenSCAD has no printf).
function one_decimal(v) = let(t = round(v * 10)) str(floor(t / 10), ".", t % 10);

// Hole + lead-in chamfer through a plate of thickness t lying on z = 0..t,
// chamfer on the z = t side (the side the switch is pushed in from).
module switch_hole_2d_cut(hole, t) {
    translate([0, 0, -1]) linear_extrude(t + 2) square(hole, center = true);
    translate([0, 0, t - hole_chamfer])
        linear_extrude(hole_chamfer + eps, scale = (hole + 2 * (hole_chamfer + eps)) / hole)
            square(hole, center = true);
}

if (part == "cube") {
    switch_cube();
} else if (part == "fit_test") {
    fit_test();
} else if (part == "section") {
    // Cut-away through the middle, for checking the pockets.
    difference() {
        switch_cube();
        translate([-cube_size, 0, -cube_size]) cube(2 * cube_size);
    }
}
