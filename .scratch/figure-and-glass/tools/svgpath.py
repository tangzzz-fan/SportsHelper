"""Minimal SVG path parser: tokenize `d`, sample curves, report bounding box.

Used twice:
  1. now  - compute a tight viewBox for the design comp
  2. later - feed the SwiftUI Path code generator
"""
import re, math

NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
CMD = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])')


def tokenize(d):
    """-> [(cmd_letter, [floats...]), ...] with implicit repeats expanded."""
    out, i, cur = [], 0, None
    for m in re.finditer(r'([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?)', d):
        if m.group(1):
            out.append([m.group(1), []])
        else:
            if not out:
                out.append(['M', []])
            out[-1][1].append(float(m.group(2)))
    # expand repeat groups: c 12 numbers = 2 curve segments, etc.
    arity = 'MmLlTtQqSsCcHhVvAaZz'
    counts = {'M': 2, 'L': 2, 'T': 4, 'Q': 4, 'S': 4, 'C': 6, 'H': 1, 'V': 1, 'A': 7, 'Z': 0}
    expanded = []
    for cmd, nums in out:
        n = counts[cmd.upper()]
        if n == 0:
            expanded.append((cmd, []))
            continue
        if len(nums) == n:
            expanded.append((cmd, nums))
        else:
            first = True
            while nums:
                expanded.append((cmd if first else ('l' if cmd.islower() else 'L') if cmd.upper() in 'ML' else cmd, nums[:n]))
                nums = nums[n:]
                first = False
    return expanded


def sample_cubic(p0, p1, p2, p3, n=12):
    pts = []
    for k in range(1, n + 1):
        t = k / n
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


def sample_quad(p0, p1, p2, n=10):
    pts = []
    for k in range(1, n + 1):
        t = k / n
        u = 1 - t
        pts.append((u*u*p0[0] + 2*u*t*p1[0] + t*t*p2[0], u*u*p0[1] + 2*u*t*p1[1] + t*t*p2[1]))
    return pts


def sample_arc(p0, rx, ry, phi, large, sweep, p1, n=16):
    """Endpoint -> center parameterization, then sample."""
    if p0 == p1:
        return [p1]
    rx, ry = abs(rx), abs(ry)
    if rx == 0 or ry == 0:
        return [p1]
    phi = math.radians(phi)
    dx2, dy2 = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1 = math.cos(phi) * dx2 + math.sin(phi) * dy2
    y1 = -math.sin(phi) * dx2 + math.cos(phi) * dy2
    lam = x1**2 / rx**2 + y1**2 / ry**2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    sign = -1 if large == sweep else 1
    num = rx*rx*ry*ry - rx*rx*y1*y1 - ry*ry*x1*x1
    den = rx*rx*y1*y1 + ry*ry*x1*x1
    co = sign * math.sqrt(max(0.0, num / den)) if den else 0.0
    cx1, cy1 = co * rx * y1 / ry, -co * ry * x1 / rx
    cx = math.cos(phi) * cx1 - math.sin(phi) * cy1 + (p0[0] + p1[0]) / 2
    cy = math.sin(phi) * cx1 + math.cos(phi) * cy1 + (p0[1] + p1[1]) / 2
    def ang(ux, uy, vx, vy):
        dot = ux*vx + uy*vy
        norm = math.hypot(ux, uy) * math.hypot(vx, vy)
        a = math.acos(max(-1, min(1, dot / norm))) if norm else 0
        return -a if ux*vy - uy*vx < 0 else a
    theta1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
    dtheta = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
    if not sweep and dtheta > 0:
        dtheta -= 2 * math.pi
    elif sweep and dtheta < 0:
        dtheta += 2 * math.pi
    pts = []
    for k in range(1, n + 1):
        th = theta1 + dtheta * k / n
        pts.append((
            cx + rx * math.cos(th) * math.cos(phi) - ry * math.sin(th) * math.sin(phi),
            cy + rx * math.cos(th) * math.sin(phi) + ry * math.sin(th) * math.cos(phi),
        ))
    return pts


def bbox(d):
    """Return (minx, miny, maxx, maxy) over sampled geometry."""
    pts = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_ctrl = None
    prev_cmd = ''
    for cmd, a in tokenize(d):
        up, rel = cmd.upper(), cmd.islower()
        if up == 'M':
            cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            start = cur
            pts.append(cur)
            prev_ctrl = None
        elif up == 'L':
            cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            pts.append(cur)
            prev_ctrl = None
        elif up == 'H':
            cur = (cur[0] + a[0], cur[1]) if rel else (a[0], cur[1])
            pts.append(cur)
            prev_ctrl = None
        elif up == 'V':
            cur = (cur[0], cur[1] + a[0]) if rel else (cur[0], a[0])
            pts.append(cur)
            prev_ctrl = None
        elif up == 'C':
            p1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            p2 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
            p3 = (cur[0] + a[4], cur[1] + a[5]) if rel else (a[4], a[5])
            pts += sample_cubic(cur, p1, p2, p3)
            prev_ctrl, cur = p2, p3
        elif up == 'S':
            p1 = prev_ctrl if (prev_cmd in 'CS' and prev_ctrl) else cur
            if prev_ctrl and prev_cmd in 'CS':
                p1 = (2*cur[0] - prev_ctrl[0], 2*cur[1] - prev_ctrl[1])
            p2 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            p3 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
            pts += sample_cubic(cur, p1, p2, p3)
            prev_ctrl, cur = p2, p3
        elif up == 'Q':
            p1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            p2 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
            pts += sample_quad(cur, p1, p2)
            prev_ctrl, cur = p1, p2
        elif up == 'T':
            p1 = (2*cur[0] - prev_ctrl[0], 2*cur[1] - prev_ctrl[1]) if (prev_ctrl and prev_cmd in 'QT') else cur
            p2 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            pts += sample_quad(cur, p1, p2)
            prev_ctrl, cur = p1, p2
        elif up == 'A':
            p = (cur[0] + a[5], cur[1] + a[6]) if rel else (a[5], a[6])
            pts += sample_arc(cur, a[0], a[1], a[2], int(a[3]), int(a[4]), p)
            cur = p
            prev_ctrl = None
        elif up == 'Z':
            cur = start
            pts.append(cur)
            prev_ctrl = None
        prev_cmd = up
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def path_d(svg_text):
    m = re.search(r'<path[^>]*\sd="([^"]+)"', svg_text)
    return m.group(1) if m else None


if __name__ == '__main__':
    import sys, json
    for f in sys.argv[1:]:
        d = path_d(open(f).read())
        x0, y0, x1, y1 = bbox(d)
        print(f'{f}: x[{x0:.1f},{x1:.1f}] y[{y0:.1f},{y1:.1f}] w={x1-x0:.1f} h={y1-y0:.1f}')
