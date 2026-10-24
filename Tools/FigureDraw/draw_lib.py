"""参数化人体线稿：给没有上游素材的动作画简化图。

坐标空间固定 512x512（与 Everkinetic 素材一致），y 向下。
输出的是**闭合轮廓**，渲染走 stroke —— 每条肢体是一圈线而不是实心，
所以各段重叠不会互相挖空（素材走 fill + evenodd 才需要考虑那个）。

风格约束（与素材对齐的部分）见 docs/FIGURE-STYLE.md：
单色、512 画布、线宽由渲染器按显示尺寸换算、3 帧、side/front 两种视角。
"""
import math

CANVAS = 512
AXIS = CANVAS / 2


# ---- 基础几何 -------------------------------------------------------------

def _arc(cx, cy, r, a0, a1, n=14):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n),
             cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def ellipse(cx, cy, rx, ry, deg=0.0):
    a = math.radians(deg)
    pts = []
    for i in range(72):
        t = 2 * math.pi * i / 72
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(a) - y * math.sin(a),
                    cy + x * math.sin(a) + y * math.cos(a)))
    return pts


def capsule(p0, p1, w0, w1=None):
    """两端圆帽的锥形管轮廓。一段肢体就是一条胶囊。"""
    if w1 is None:
        w1 = w0
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    if L < 1e-6:
        return []
    nx, ny = -dy / L, dx / L
    a0 = math.atan2(ny, nx)
    pts = _arc(p0[0], p0[1], w0 / 2, a0, a0 + math.pi)
    pts.append((p1[0] + nx * w1 / 2, p1[1] + ny * w1 / 2))
    pts += _arc(p1[0], p1[1], w1 / 2, a0 + math.pi, a0 + 2 * math.pi)
    pts.append((p0[0] + nx * w0 / 2, p0[1] + ny * w0 / 2))
    return pts


def chain(points, widths):
    """折线 -> 若干条胶囊（每段独立）。关节处会自然形成两道弧线，读起来像关节。"""
    out = []
    for i in range(len(points) - 1):
        seg = capsule(points[i], points[i + 1], widths[i], widths[i + 1])
        if seg:
            out.append(seg)
    return out


def tube(points, widths):
    """连续管状轮廓：整条肢体一条闭合路径，关节处按角平分线斜接，不会出现香肠串。"""
    n = len(points)
    if n < 2:
        return []
    dirs = []
    for i in range(n - 1):
        dx = points[i + 1][0] - points[i][0]
        dy = points[i + 1][1] - points[i][1]
        L = math.hypot(dx, dy) or 1e-6
        dirs.append((dx / L, dy / L))

    normals = []
    for i in range(n):
        if i == 0:
            nx, ny = -dirs[0][1], dirs[0][0]
        elif i == n - 1:
            nx, ny = -dirs[-1][1], dirs[-1][0]
        else:
            n1 = (-dirs[i - 1][1], dirs[i - 1][0])
            n2 = (-dirs[i][1], dirs[i][0])
            vx, vy = n1[0] + n2[0], n1[1] + n2[1]
            L = math.hypot(vx, vy)
            if L < 1e-6:
                nx, ny = n1
            else:
                nx, ny = vx / L, vy / L
                # 斜接补偿：拐得越急，外侧要沿法向多走一点才不至于变细
                cosh = max(0.35, nx * n1[0] + ny * n1[1])
                normals.append((nx / cosh, ny / cosh))
                continue
        normals.append((nx, ny))

    left = [(points[i][0] + normals[i][0] * widths[i] / 2,
             points[i][1] + normals[i][1] * widths[i] / 2) for i in range(n)]
    right = [(points[i][0] - normals[i][0] * widths[i] / 2,
              points[i][1] - normals[i][1] * widths[i] / 2) for i in range(n)]

    a_start = math.atan2(left[0][1] - points[0][1], left[0][0] - points[0][0])
    a_end = math.atan2(right[-1][1] - points[-1][1], right[-1][0] - points[-1][0])
    cap_start = _arc(points[0][0], points[0][1], widths[0] / 2, a_start, a_start + math.pi)
    cap_end = _arc(points[-1][0], points[-1][1], widths[-1] / 2, a_end, a_end + math.pi)
    return left + cap_end[1:-1] + right[::-1] + cap_start[1:-1]


def head_egg(cx, cy, rx=30, ry=31, tilt=0.0, jaw=0.80):
    """蛋形头：下半收窄，读起来有下巴，不是纯圆。"""
    a = math.radians(tilt)
    pts = []
    for i in range(72):
        t = 2 * math.pi * i / 72
        x, y = rx * math.cos(t), ry * math.sin(t)
        if y > 0:
            x *= jaw
        pts.append((cx + x * math.cos(a) - y * math.sin(a),
                    cy + x * math.sin(a) + y * math.cos(a)))
    return pts


def blob(points):
    return list(points)


# ---- 人体部件 -------------------------------------------------------------

def head(cx, cy, rx=30, ry=30, tilt=0.0):
    return [head_egg(cx, cy, rx, ry, tilt)]


def neck(top, bottom, w=22):
    return [tube([top, bottom], [w, w + 6])]


def torso(shoulders, hips, waist_pull=0.10):
    """shoulders/hips 各为 (左点, 右点)。轻微收腰，避免方块感。"""
    sl, sr = shoulders
    hl, hr = hips
    wl = (sl[0] * 0.42 + hl[0] * 0.58, sl[1] * 0.42 + hl[1] * 0.58)
    wr = (sr[0] * 0.42 + hr[0] * 0.58, sr[1] * 0.42 + hr[1] * 0.58)
    mx = (wl[0] + wr[0]) / 2
    wl = (wl[0] + (mx - wl[0]) * waist_pull, wl[1])
    wr = (wr[0] + (mx - wr[0]) * waist_pull, wr[1])
    return [blob([sl, sr, wr, hr, hl, wl])]


def arm(shoulder, elbow, wrist, w_up=23, w_fore=19, near=True):
    return [tube([shoulder, elbow, wrist], [w_up, w_up * 0.92, w_fore])]


def leg(hip, knee, ankle, w_thigh=36, w_shin=26):
    return [tube([hip, knee, ankle], [w_thigh, w_thigh * 0.82, w_shin])]


def hand(wrist, direction_deg, size=15):
    a = math.radians(direction_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    return [blob([
        (wrist[0] + nx * size * 0.45, wrist[1] + ny * size * 0.45),
        (wrist[0] + dx * size * 0.95 + nx * size * 0.34, wrist[1] + dy * size * 0.95 + ny * size * 0.34),
        (wrist[0] + dx * size * 1.05 - nx * size * 0.34, wrist[1] + dy * size * 1.05 - ny * size * 0.34),
        (wrist[0] - nx * size * 0.45, wrist[1] - ny * size * 0.45),
    ])]


def foot(ankle, forward=1, length=30, height=12):
    x, y = ankle
    return [blob([
        (x - 7, y - 3),
        (x + forward * length * 0.45, y - 5),
        (x + forward * length, y + height * 0.25),
        (x + forward * length * 0.95, y + height),
        (x - 7, y + height - 1),
    ])]


def dumbbell(center, angle_deg, bar=26, plate=13, thickness=7):
    """哑铃：中间横杆 + 两端配重。"""
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    cx, cy = center
    p0 = (cx - dx * bar / 2, cy - dy * bar / 2)
    p1 = (cx + dx * bar / 2, cy + dy * bar / 2)
    out = [capsule(p0, p1, thickness)]
    for p, sign in ((p0, -1), (p1, 1)):
        px, py = p
        out.append(blob([
            (px + nx * plate * 0.55, py + ny * plate * 0.55),
            (px + dx * sign * thickness * 0.9 + nx * plate * 0.55,
             py + dy * sign * thickness * 0.9 + ny * plate * 0.55),
            (px + dx * sign * thickness * 0.9 - nx * plate * 0.55,
             py + dy * sign * thickness * 0.9 - ny * plate * 0.55),
            (px - nx * plate * 0.55, py - ny * plate * 0.55),
        ]))
    return out


def floor_line(y=470, x0=90, x1=430):
    return [blob([(x0, y), (x1, y), (x1, y + 4), (x0, y + 4)])]


def mat_line(y=452, x0=80, x1=432, thickness=9):
    """地面垫子：一条扁长圆角矩形。"""
    return [capsule((x0, y), (x1, y), thickness)]


def wall_line(x=430, y0=80, y1=470):
    return [blob([(x, y0), (x + 4, y0), (x + 4, y1), (x, y1)])]


# ---- 输出 -----------------------------------------------------------------

def to_dsl(contours):
    parts = []
    for c in contours:
        pts = [p for p in c if p is not None]
        if len(pts) < 3:
            continue
        s = f"M {pts[0][0]:.2f} {pts[0][1]:.2f}"
        for x, y in pts[1:]:
            s += f" L {x:.2f} {y:.2f}"
        s += " Z"
        parts.append(s)
    return " ".join(parts)


def bounds_of(frames):
    xs, ys = [], []
    for dsl in frames:
        for tok in dsl.split():
            try:
                v = float(tok)
            except ValueError:
                continue
            (xs if len(xs) == len(ys) else ys).append(v)
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def flat(*groups):
    """把多个部件列表摊平成一串轮廓。"""
    out = []
    for g in groups:
        if g and isinstance(g[0], tuple):
            out.append(g)
        else:
            out.extend(g)
    return out
