"""SVG path -> absolute command list. Arcs flattened to lines, quadratics to cubics.

Output op list: [('M',[x,y]), ('L',[x,y]), ('C',[x1,y1,x2,y2,x,y]), ('Z',[])]
"""
import re
import math

NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
CMD = re.compile(r'[MmLlHhVvCcSsQqTtAaZz]')
COUNTS = {'M': 2, 'L': 2, 'T': 4, 'Q': 4, 'S': 4, 'C': 6, 'H': 1, 'V': 1, 'A': 7, 'Z': 0}


def tokenize(d):
    out = []
    for m in re.finditer(r'([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?)', d):
        if m.group(1):
            out.append([m.group(1), []])
        else:
            if not out:
                out.append(['M', []])
            out[-1][1].append(float(m.group(2)))
    expanded = []
    for cmd, nums in out:
        n = COUNTS[cmd.upper()]
        if n == 0:
            expanded.append((cmd, []))
            continue
        first = True
        while nums:
            c = cmd
            if not first and cmd in 'Mm':
                c = 'l' if cmd.islower() else 'L'
            expanded.append((c, nums[:n]))
            nums = nums[n:]
            first = False
    return expanded


def _arc_to_lines(p0, rx, ry, phi, large, sweep, p1, n=16):
    if p0 == p1:
        return []
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
        a = math.acos(max(-1, min(1, dot / norm))) if norm else 0.0
        return -a if ux*vy - uy*vx < 0 else a

    th1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
    dth = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
    if not sweep and dth > 0:
        dth -= 2 * math.pi
    elif sweep and dth < 0:
        dth += 2 * math.pi
    pts = []
    for k in range(1, n + 1):
        th = th1 + dth * k / n
        pts.append((cx + rx * math.cos(th) * math.cos(phi) - ry * math.sin(th) * math.sin(phi),
                    cy + rx * math.cos(th) * math.sin(phi) + ry * math.sin(th) * math.cos(phi)))
    return pts


def ops(d):
    res = []
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_ctrl = None
    prev_cmd = ''
    for cmd, a in tokenize(d):
        up, rel = cmd.upper(), cmd.islower()
        if up == 'M':
            cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            start = cur
            res.append(('M', [cur[0], cur[1]]))
            prev_ctrl = None
        elif up == 'L':
            cur = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            res.append(('L', [cur[0], cur[1]]))
            prev_ctrl = None
        elif up == 'H':
            cur = (cur[0] + a[0], cur[1]) if rel else (a[0], cur[1])
            res.append(('L', [cur[0], cur[1]]))
            prev_ctrl = None
        elif up == 'V':
            cur = (cur[0], cur[1] + a[0]) if rel else (cur[0], a[0])
            res.append(('L', [cur[0], cur[1]]))
            prev_ctrl = None
        elif up in ('C', 'S'):
            if up == 'C':
                p1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                p2 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
                p3 = (cur[0] + a[4], cur[1] + a[5]) if rel else (a[4], a[5])
            else:
                p1 = (2*cur[0] - prev_ctrl[0], 2*cur[1] - prev_ctrl[1]) if (prev_ctrl and prev_cmd in 'CS') else cur
                p2 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
                p3 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
            res.append(('C', [p1[0], p1[1], p2[0], p2[1], p3[0], p3[1]]))
            prev_ctrl, cur = p2, p3
        elif up == 'Q':
            p1 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            p2 = (cur[0] + a[2], cur[1] + a[3]) if rel else (a[2], a[3])
            c1 = (cur[0] + 2/3*(p1[0]-cur[0]), cur[1] + 2/3*(p1[1]-cur[1]))
            c2 = (p2[0] + 2/3*(p1[0]-p2[0]), p2[1] + 2/3*(p1[1]-p2[1]))
            res.append(('C', [c1[0], c1[1], c2[0], c2[1], p2[0], p2[1]]))
            prev_ctrl, cur = p1, p2
        elif up == 'T':
            p1 = (2*cur[0] - prev_ctrl[0], 2*cur[1] - prev_ctrl[1]) if (prev_ctrl and prev_cmd in 'QT') else cur
            p2 = (cur[0] + a[0], cur[1] + a[1]) if rel else (a[0], a[1])
            c1 = (cur[0] + 2/3*(p1[0]-cur[0]), cur[1] + 2/3*(p1[1]-cur[1]))
            c2 = (p2[0] + 2/3*(p1[0]-p2[0]), p2[1] + 2/3*(p1[1]-p2[1]))
            res.append(('C', [c1[0], c1[1], c2[0], c2[1], p2[0], p2[1]]))
            prev_ctrl, cur = p1, p2
        elif up == 'A':
            p = (cur[0] + a[5], cur[1] + a[6]) if rel else (a[5], a[6])
            for pt in _arc_to_lines(cur, a[0], a[1], a[2], int(a[3]), int(a[4]), p):
                res.append(('L', [pt[0], pt[1]]))
            cur = p
            prev_ctrl = None
        elif up == 'Z':
            res.append(('Z', []))
            cur = start
            prev_ctrl = None
        prev_cmd = up
    return res


def normalized(d, prec=2):
    """Compact absolute DSL: M x y L x y C ... Z (no commas, fixed decimals)."""
    parts = []
    for op, nums in ops(d):
        parts.append(op)
        for v in nums:
            s = f'{v:.{prec}f}'
            if '.' in s:
                s = s.rstrip('0').rstrip('.')
            parts.append(s)
    return ' '.join(parts)


if __name__ == '__main__':
    import sys
    print(normalized(open(sys.argv[1]).read())[:200])
