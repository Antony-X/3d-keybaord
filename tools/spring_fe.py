"""Beam finite-element estimate for the click module's flat spiral spring.

Each arm is an Archimedean spiral of rectangular section (width w in the plane,
thickness t out of it), clamped to the outer ring. The hub is pushed straight
in by delta: it may twist about the press axis (the plunger's pin is round)
but not tilt or shift sideways. Prints the spring rate and the peak strain.

Usage: python3 tools/spring_fe.py [arms sweep_deg r_in r_out w t E travel]
Defaults match cad/click_module.scad.
"""

import sys

import numpy as np


def frame_element(p0, p1, E, G, A, Iy, Iz, J, up):
    """12x12 stiffness of a 3D Euler-Bernoulli beam, in global coordinates."""
    L = np.linalg.norm(p1 - p0)
    ex = (p1 - p0) / L
    ey = np.cross(up, ex)
    ey /= np.linalg.norm(ey)
    ez = np.cross(ex, ey)
    k = np.zeros((12, 12))
    a, t = E * A / L, G * J / L
    k[0, 0] = k[6, 6] = a
    k[0, 6] = k[6, 0] = -a
    k[3, 3] = k[9, 9] = t
    k[3, 9] = k[9, 3] = -t
    # Bending in the local x-y plane (about local z), uses Iz.
    for (v, r, I) in ((1, 5, Iz), (2, 4, Iy)):
        s = 1 if v == 1 else -1
        c1, c2, c3, c4 = 12 * E * I / L**3, 6 * E * I / L**2, 4 * E * I / L, 2 * E * I / L
        idx = [v, r, v + 6, r + 6]
        m = np.array([[c1, s * c2, -c1, s * c2],
                      [s * c2, c3, -s * c2, c4],
                      [-c1, -s * c2, c1, -s * c2],
                      [s * c2, c4, -s * c2, c3]])
        for i in range(4):
            for j in range(4):
                k[idx[i], idx[j]] = m[i, j]
    R = np.vstack([ex, ey, ez])
    T = np.kron(np.eye(4), R)
    return T.T @ k @ T, T, k


def solve(arms=3, sweep=240.0, r_in=3.7, r_out=6.1, w=0.7, t=1.0, E=2000.0, travel=2.9,
          nseg=60, nu=0.35):
    G = E / (2 * (1 + nu))
    A, Iy, Iz = w * t, w * t**3 / 12, t * w**3 / 12  # Iy: out-of-plane bending
    a, b = max(w, t), min(w, t)
    J = a * b**3 * (1 / 3 - 0.21 * b / a * (1 - b**4 / (12 * a**4)))
    up = np.array([0.0, 0.0, 1.0])

    th = np.linspace(0, np.radians(sweep), nseg + 1)
    r = r_in + (r_out - r_in) * th / th[-1]
    pts = np.c_[r * np.cos(th), r * np.sin(th), np.zeros_like(th)]
    n = len(pts)
    K = np.zeros((6 * n, 6 * n))
    elems = []
    for e in range(nseg):
        ke, T, kl = frame_element(pts[e], pts[e + 1], E, G, A, Iy, Iz, J, up)
        dof = np.r_[6 * e:6 * e + 6, 6 * (e + 1):6 * (e + 1) + 6]
        K[np.ix_(dof, dof)] += ke
        elems.append((dof, T, kl))

    # Unknowns: free DOFs of nodes 1..n-2, plus the hub twist theta.
    # Node 0 (hub end): ux=-theta*y0, uy=theta*x0, uz=delta, rx=ry=0, rz=theta.
    # Node n-1 (ring end): clamped.
    free = list(range(6, 6 * (n - 1)))
    x0, y0 = pts[0][:2]
    hub_theta = np.zeros(6 * n)
    hub_theta[[0, 1, 5]] = [-y0, x0, 1.0]
    hub_delta = np.zeros(6 * n)
    hub_delta[2] = 1.0
    # u = Bf @ q + hub_theta*theta + hub_delta*delta ; minimise energy over q, theta.
    m = len(free) + 1
    B = np.zeros((6 * n, m))
    B[free, np.arange(len(free))] = 1.0
    B[:, -1] = hub_theta
    Kr = B.T @ K @ B
    fr = -B.T @ K @ hub_delta
    q = np.linalg.solve(Kr, fr)
    u = B @ q + hub_delta          # displacement field for delta = 1 mm
    force_per_mm = (K @ u)[2]      # axial reaction at the hub end, per arm
    k_total = arms * force_per_mm

    u_max = u * travel
    eps_max, gamma_max = 0.0, 0.0
    for dof, T, kl in elems:
        f = kl @ (T @ u_max[dof])  # local end forces
        for end in (0, 6):
            N, Tq, My, Mz = f[end], f[end + 3], f[end + 4], f[end + 5]
            eps = abs(N) / (E * A) + abs(My) * (t / 2) / (E * Iy) + abs(Mz) * (w / 2) / (E * Iz)
            eps_max = max(eps_max, eps)
            gamma_max = max(gamma_max, abs(Tq) * b / (G * J))
    length = np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1))
    return k_total, eps_max, gamma_max, length, q[-1] * travel


if __name__ == "__main__":
    args = [float(v) for v in sys.argv[1:]]
    names = ["arms", "sweep", "r_in", "r_out", "w", "t", "E", "travel"]
    kw = dict(zip(names, args))
    if "arms" in kw:
        kw["arms"] = int(kw["arms"])
    k, eps, gam, L, twist = solve(**kw)
    print(f"arm length {L:.1f} mm, spring rate {k:.2f} N/mm, "
          f"peak strain {100 * eps:.2f} %, peak shear {100 * gam:.2f} %, "
          f"hub twist {np.degrees(twist):.1f} deg at full travel")
