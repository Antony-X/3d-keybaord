// Fully printed click module (EXPERIMENTAL): replaces a face plate + real switch in
// the frame version of the cube (cad/frame_cube.scad uses the same frame).
// Three printed parts per face, no glue, no metal:
//   plate   - face plate with two flexible click fins cut into it, plunger guides,
//             and four posts that hold the spring
//   plunger - MX "+" stem for the keycap, two teeth that snap past the fins (the click)
//   spring  - flat two-arm spiral spring (thick, narrow arms like the PETG springs that
//             survived 200k+ presses in James Stanley's printed switch)
// The keycap landing on the plate is the bottom-out stop.
//
//   openscad -o plate.stl   -D 'part="print_plate"'   click_module.scad
//   openscad -o plunger.stl -D 'part="print_plunger"' click_module.scad
//   openscad -o spring.stl  -D 'part="print_spring"'  click_module.scad
//
// Module coordinates: z points out of the cube, the plate's outer face is z = 0.

/* [What to render] */
part = "assembly"; // [assembly, print_plate, print_plunger, print_spring, plate, plunger, spring, spring_envelope]
// Assembly only: how far the key is pressed (0 .. travel).
press = 0;

/* [Click feel - the main tuning knobs] */
// Fin thickness. Thicker = stronger, louder click, but harder for the spring to return.
fin_t = 0.7;
// How far the plunger's teeth push the fins out (mm).
tooth_h = 0.47;
// Steepness of the tooth's back face (degrees from the press axis). Steeper = sharper
// click on the way down, but more force needed to come back up.
roof_angle = 35;
// Spring arm thickness. Thicker = stiffer spring (heavier key, more reliable return).
arm_t = 2.8;

/* [Frame fit - same as cad/frame_cube.scad] */
switch_span = 30;
bar = 3;
plate_thickness = 1.5;
fit_gap = 0.15;
rib = 0.25;

/* [Hidden] */
$fn = 48;
eps = 0.01;
F = switch_span - 2 * plate_thickness;
W = F - 2 * bar;
ring_out = W - 2 * fit_gap;
ring_depth = bar - 0.2;
plate_size = F - 0.2;
ring_in = 16;

// Plunger column and its guides.
col = [5.0, 4.4];
guide_gap = 0.2;
guide_depth = 1.7;            // guides reach this far behind the plate
sleeve_t = 0.8;
sleeve_half = 1.5;            // half-width of the x guides (and the ears)
z_guide_end = -(plate_thickness + guide_depth);

// Click fins (cut into the plate, printed flat on the bed).
fin_h = 1.0;                  // fins occupy the outer 1 mm of the plate
fin_gap = 0.1;                // fin to column at rest
fin_root = 7.3;               // fin is clamped beyond this x
fin_tip = 0.35;
fin_slot = 1.0;               // room for the fin to bend outwards
fin_clear = 0.6;              // other gaps around the fin (survive a squished first layer)
fin_inner = col[1] / 2 + fin_gap;

// Teeth on the plunger.
tooth_x = [0.4, 2.3];
ramp_angle = 30;              // front face, degrees from the press axis
click_at = 1.5;               // travel at which the click happens
travel = 2.6;                 // keycap lands on the plate here
z_apex = -fin_h + click_at;   // at rest
ramp_len = tooth_h / tan(ramp_angle);
roof_len = tooth_h / tan(roof_angle);

// Ears: stop the plunger from coming out (they hit the guide ends).
ear_out = 0.8;
ear_flat = 0.3;
z_col_bottom = z_guide_end - ear_flat - ear_out - 0.1;
z_col_top = travel;           // the keycap's stem sits on the column top
cross_h = 3.6;

// Spring. The ring and hub are always spring_t thick so every spring fits the same
// posts; only the arms change with arm_t.
spring_t = 2.8;
preload = 0.5;
hub_r = 3.4;
boss_r = 2.2;
boss_h = 0.4;
pin_r = 0.9;
pin_h = 1.0;
spring_size = 14.4;
spring_in_r = 6.4;
arms = 2;
arm_sweep = 330;
arm_w = 0.7;
// Spring position at rest: the hub is pushed in by `preload` relative to the ring.
z_ring_top = z_col_bottom + preload - boss_h;
z_ring_bottom = z_ring_top - spring_t;

// Posts that hold the spring ring.
post_in = spring_size / 2 + 0.1;
post_t = 0.6;
post_span = [0.6, 3.6];       // pinwheel: offset along each side so posts of
                              // neighbouring faces never meet at a cube edge
catch = 0.4;
z_post_end = z_ring_bottom - 0.4;

face_rotations = [[0, 0, 0], [180, 0, 0], [0, 90, 0], [0, -90, 0], [-90, 0, 0], [90, 0, 0]];

// ---------------------------------------------------------------- plate

module base_plate() {
    c = 0.5;
    hull() {
        translate([0, 0, -eps]) linear_extrude(eps) square(plate_size - 2 * c, center = true);
        translate([0, 0, -plate_thickness]) linear_extrude(plate_thickness - c) square(plate_size, center = true);
    }
    translate([0, 0, -plate_thickness - ring_depth])
        linear_extrude(ring_depth + eps)
            difference() {
                square(ring_out, center = true);
                square(ring_in, center = true);
            }
    if (rib > 0)
        for (a = [0 : 90 : 270], s = [-1, 1])
            rotate(a) translate([ring_out / 2, s * ring_out / 4, -plate_thickness])
                mirror([0, 0, 1]) crush_rib(ring_depth);
}

module crush_rib(h) {
    w = 0.8;
    lead = min(1, h / 2);
    hull() {
        translate([-eps, -w / 2, 0]) cube([eps + fit_gap + rib, w, h - lead]);
        translate([-eps, -w / 2, 0]) cube([eps, w, h]);
    }
}

// One click fin and the slot around it, for the +y side (the -y side is rotated 180).
module fin_cut() {
    x0 = fin_tip - fin_clear;
    y0 = fin_inner - fin_clear;
    translate([x0, y0, -plate_thickness - 1])
        cube([fin_root - x0, fin_inner + fin_t + fin_slot - y0, plate_thickness + 2]);
}
module fin() {
    translate([fin_tip, fin_inner, -fin_h])
        cube([fin_root - fin_tip + eps, fin_t, fin_h]);
}

module post() {
    // Post on the +x side; a ledge above the spring ring and a barb below it.
    translate([post_in, post_span[0], z_post_end])
        cube([post_t, post_span[1] - post_span[0], -plate_thickness - z_post_end + eps]);
    // Ledge (45 degree underside so it prints without support).
    translate([post_in + eps, post_span[0], z_ring_top])
        rotate([-90, 0, 0]) linear_extrude(post_span[1] - post_span[0])
            polygon([[0, 0], [-catch, 0], [-catch, -catch], [0, -2 * catch]]);
    // Barb with a lead-in on the side the spring comes from.
    translate([post_in + eps, post_span[0], z_ring_bottom])
        rotate([-90, 0, 0]) linear_extrude(post_span[1] - post_span[0])
            polygon([[0, 0], [-catch, 0], [0, catch]]);
}

module click_plate() {
    difference() {
        base_plate();
        // Plunger opening (guided on all four sides where there are no fins).
        translate([0, 0, -plate_thickness - 1])
            linear_extrude(plate_thickness + 2)
                square([col[0] + 2 * guide_gap, col[1] + 2 * guide_gap], center = true);
        for (a = [0, 180]) rotate(a) fin_cut();
    }
    for (a = [0, 180]) rotate(a) fin();
    // x guides behind the plate.
    for (a = [0, 180]) rotate(a)
        translate([col[0] / 2 + guide_gap, -sleeve_half, z_guide_end])
            cube([sleeve_t, 2 * sleeve_half, guide_depth + eps]);
    // y guides behind the plate, beside the fins (C2 like the fins).
    for (a = [0, 180]) rotate(a)
        translate([-col[0] / 2 - guide_gap, col[1] / 2 + guide_gap, z_guide_end])
            cube([col[0] / 2 + guide_gap + fin_tip - fin_clear, sleeve_t, guide_depth + eps]);
    for (a = [0 : 90 : 270]) rotate(a) post();
}

// ---------------------------------------------------------------- plunger

module tooth() {
    // On the +y face, profile in (y, z), extruded along x.
    translate([tooth_x[0], 0, 0])
        rotate([90, 0, 90]) linear_extrude(tooth_x[1] - tooth_x[0])
            polygon([[col[1] / 2 - eps, z_apex - ramp_len],
                     [col[1] / 2 + tooth_h, z_apex],
                     [col[1] / 2 - eps, z_apex + roof_len]]);
}

module ear() {
    // On the +x face, profile in (x, z), extruded along y.
    translate([0, -sleeve_half, 0])
        rotate([90, 0, 0]) mirror([0, 0, 1]) linear_extrude(2 * sleeve_half)
            polygon([[col[0] / 2 - eps, z_guide_end],
                      [col[0] / 2 + ear_out, z_guide_end],
                      [col[0] / 2 + ear_out, z_guide_end - ear_flat],
                      [col[0] / 2 - eps, z_guide_end - ear_flat - ear_out]]);
}

module click_plunger() {
    difference() {
        union() {
            translate([0, 0, z_col_bottom])
                linear_extrude(z_col_top - z_col_bottom) square(col, center = true);
            // MX cross stem: 4.0 long, arms 1.25 (x) and 1.15 (y) wide.
            translate([0, 0, z_col_top - eps]) linear_extrude(cross_h + eps) {
                square([4.0, 1.25], center = true);
                square([1.15, 4.0], center = true);
            }
            for (a = [0, 180]) rotate(a) tooth();
            for (a = [0, 180]) rotate(a) ear();
        }
        // Socket for the spring's pin.
        translate([0, 0, z_col_bottom - eps]) cylinder(r = pin_r + 0.2, h = pin_h + 0.3);
    }
}

// ---------------------------------------------------------------- spring

function spiral_pt(t, r0, r1, a0) =
    let(a = a0 + t * arm_sweep, r = r0 + (r1 - r0) * t) [r * cos(a), r * sin(a)];

module spring_arm(a0) {
    r0 = hub_r + arm_w / 2 - 0.3;      // overlap into the hub and ring
    r1 = spring_in_r - arm_w / 2 + 0.3;
    n = 120;
    pts = [for (i = [0 : n]) spiral_pt(i / n, r0, r1, a0)];
    // Offset the centreline by +-w/2 along its normal.
    function nrm(i) = let(p = pts[max(i - 1, 0)], q = pts[min(i + 1, n)], d = q - p)
        [-d[1], d[0]] / norm(d);
    left = [for (i = [0 : n]) pts[i] + nrm(i) * arm_w / 2];
    right = [for (i = [n : -1 : 0]) pts[i] - nrm(i) * arm_w / 2];
    polygon(concat(left, right));
}

module spring_frame_2d() {
    difference() {
        offset(delta = 1.2, chamfer = true) offset(delta = -1.2) square(spring_size, center = true);
        circle(r = spring_in_r, $fn = 96);
    }
    circle(r = hub_r, $fn = 64);
}

// Spring as printed: flat, boss and pin facing up (they face the plate when fitted).
// The arms sit on the bed; when thinner than the ring they are recessed on the plate side.
module spring_flat() {
    linear_extrude(spring_t) spring_frame_2d();
    linear_extrude(arm_t) for (i = [0 : arms - 1]) spring_arm(i * 360 / arms);
    translate([0, 0, spring_t - eps]) cylinder(r = boss_r, h = boss_h + eps);
    translate([0, 0, spring_t + boss_h - eps]) cylinder(r = pin_r, h = pin_h + eps);
}

// Spring fitted in the module, hub pushed in by `extra` beyond its neutral position.
// The hub moves rigidly; the arms are drawn flat (see spring_envelope for collisions).
module spring_fitted(extra = 0) {
    translate([0, 0, z_ring_bottom]) difference() {
        union() {
            linear_extrude(spring_t) spring_frame_2d();
            linear_extrude(arm_t) for (i = [0 : arms - 1]) spring_arm(i * 360 / arms);
        }
        translate([0, 0, -1]) cylinder(r = hub_r + 0.3, h = spring_t + 2);
    }
    translate([0, 0, z_ring_bottom - extra]) {
        cylinder(r = hub_r, h = spring_t);
        translate([0, 0, spring_t - eps]) cylinder(r = boss_r, h = boss_h + eps);
        translate([0, 0, spring_t + boss_h - eps]) cylinder(r = pin_r, h = pin_h + eps);
    }
}

// Everything the spring can sweep through, from rest to full press (for collision checks).
module spring_envelope() {
    hull() {
        translate([0, 0, z_ring_bottom]) linear_extrude(spring_t) square(spring_size, center = true);
        translate([0, 0, z_ring_bottom - preload - travel])
            cylinder(r = hub_r, h = spring_t + boss_h + pin_h);
    }
}

// ---------------------------------------------------------------- output

module module_assembly(p = 0) {
    color("#f4f4f2") click_plate();
    color("#3aa0e8") translate([0, 0, -p]) click_plunger();
    color("#f0b030") spring_fitted(preload + p);
}

if (part == "assembly") {
    module_assembly(press);
} else if (part == "plate") {
    click_plate();
} else if (part == "plunger") {
    click_plunger();
} else if (part == "spring") {
    spring_fitted(preload);
} else if (part == "spring_envelope") {
    spring_envelope();
} else if (part == "print_plate") {
    mirror([0, 0, 1]) click_plate();                         // outer face on the bed
} else if (part == "print_plunger") {
    translate([0, 0, -z_col_bottom]) click_plunger();        // standing on the column
} else if (part == "print_spring") {
    spring_flat();
}
