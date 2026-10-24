"""Generate DongKe figure data from bryllim/workout-guide SVG assets.

Run manually after dropping a fresh checkout into
  .scratch/figure-and-glass/assets/workout-guide-main
Output is committed; this script is NOT part of the build.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import svgcmd
import svgpath

ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ASSETS = os.path.join(ROOT, '.scratch/figure-and-glass/assets/workout-guide-main/packages/workout-guide/assets')
OUT = os.path.join(ROOT, 'DongKeCore/Figure/GeneratedFigureData.swift')

# catalogId -> upstream asset slug. Verified against the upstream manifest
# (name / equipment / exerciseType), never guessed from the name.
MAPPING = {
    'squat': 'bodyweight-squat',
    'push_up': 'push-up',
    'plank': 'plank',
    'lunge': 'forward-lunge',
    'glute_bridge': 'glute-bridge',
    'dumbbell_row': 'dumbbell-bent-over-row',
    'shoulder_press': 'seated-dumbbell-press',
    'jumping_jack': 'jumping-jack',
    'dead_bug': 'dead-bug',
    'wall_sit': 'wall-sit',
    'side_plank': 'side-plank',
    'calf_raise': 'calf-raise',
    'superman': 'superman',
    'crunch': 'crunch',
    'mountain_climber': 'mountain-climber',
    'high_knees': 'high-knees',
    'bird_dog': 'bird-dog',
    'russian_twist': 'russian-twist',

    # 2026-10-24 动作库扩到 39 个后补的。逐条在 302 个上游素材里按 slug 搜过：
    # 这 14 个是语义精确对应，不含"看起来像"的近似（唯一例外见 NONE 段注释）。
    'arm_circle': 'arm-circles',
    'cat_cow': 'cat-cow-stretch',
    'quad_stretch': 'standing-quad-stretch',
    'hamstring_stretch': 'hamstring-stretch',
    'hip_flexor_stretch': 'kneeling-hip-flexor-stretch',
    'chest_stretch': 'doorway-chest-stretch',
    'calf_stretch': 'wall-calf-stretch',
    'child_pose': 'childs-pose',
    'butterfly': 'butterfly-stretch',
    'dumbbell_bench_press': 'dumbbell-bench-press',
    'dumbbell_rdl': 'dumbbell-romanian-deadlift',
    'lateral_raise': 'lateral-raise',
    'biceps_curl': 'bicep-curl',

    # 2026-10-24 臀部主项扩容（.scratch/exercise-expansion/issues/01）。
    # 四条都是自重动作，取自重版素材；hip-thrust 同族有 dumbbell / banded
    # 两个变式，墨量更稳（6.8-8.1 / 5.3-7.3）但把器械画进了动作本身，
    # 而这条动作定的是自重，所以仍取杠铃版（墨量 6.3-9.7）。
    'hip_thrust': 'hip-thrust',
    'single_leg_glute_bridge': 'single-leg-glute-bridge',
    'clamshell': 'clamshell',
    'side_lying_leg_raise': 'side-lying-leg-raise',
}

# 上游 302 个素材里确实没有的，一律走 _generic 兜底，不做近似替换：
#   hip_circle / scapular_circle / ankle_circle   —— 没有任何绕环类
#   neck_stretch / thread_needle                  —— neck 0 个、thread 0 个
#   back_stretch                                  —— childs-pose 已是另一个动作，不复用
#   dumbbell_floor_press                          —— floor 0 个，与卧推图共用在语义上是错的
#   march_in_place                                —— 唯一的候选 walking 画的是**跑步机**，
#                                                    居家原地踏步的用户看到跑步机会以为走错了
UNMAPPED = [
    'hip_circle', 'scapular_circle', 'ankle_circle',
    'neck_stretch', 'thread_needle', 'back_stretch', 'dumbbell_floor_press',
    'march_in_place',
]

# Explicit whitelist: isometric holds. Do not infer from upstream exerciseType --
# mountain-climber and high-knees are also "duration" but they are dynamic.
STATIC_HOLDS = {
    'plank', 'wall_sit', 'side_plank',
    # 静态拉伸：上游 3 帧是「进入 → 到位 → 保持」，只显示到位那一帧即可，
    # 循环播放会让画面在起始位与拉伸位之间反复跳，反而看不清终点姿势。
    'quad_stretch', 'hamstring_stretch', 'hip_flexor_stretch', 'chest_stretch',
    'calf_stretch', 'child_pose', 'butterfly',
}


def dsl_of(path):
    return svgcmd.normalized(svgpath.path_d(open(path).read()))


def numbers(dsl):
    return [float(t) for t in dsl.split(' ') if not t.isalpha()]


def bounds_of(dsls):
    xs, ys = [], []
    for dsl in dsls:
        n = numbers(dsl)
        xs.extend(n[0::2])
        ys.extend(n[1::2])
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def generic_dsl():
    cmds = []

    def circle(cx, cy, r):
        k = r * 0.5523
        cmds.append(('M', [cx, cy - r]))
        cmds.append(('C', [cx + k, cy - r, cx + r, cy - k, cx + r, cy]))
        cmds.append(('C', [cx + r, cy + k, cx + k, cy + r, cx, cy + r]))
        cmds.append(('C', [cx - k, cy + r, cx - r, cy + k, cx - r, cy]))
        cmds.append(('C', [cx - r, cy - k, cx - k, cy - r, cx, cy - r]))
        cmds.append(('Z', []))

    def poly(points):
        cmds.append(('M', list(points[0])))
        for p in points[1:]:
            cmds.append(('L', list(p)))
        cmds.append(('Z', []))

    circle(256, 112, 44)
    poly([(232, 150), (280, 150), (286, 300), (226, 300)])
    poly([(232, 156), (212, 162), (188, 296), (206, 300), (226, 210)])
    poly([(280, 156), (300, 162), (324, 296), (306, 300), (286, 210)])
    poly([(228, 296), (252, 296), (250, 472), (226, 472)])
    poly([(260, 296), (284, 296), (286, 472), (262, 472)])

    parts = []
    for op, nums in cmds:
        parts.append(op)
        for v in nums:
            s = f'{v:.2f}'
            if '.' in s:
                s = s.rstrip('0').rstrip('.')
            parts.append(s)
    return ' '.join(parts)


def record(catalog_id, motion, dsls, source):
    x, y, w, h = bounds_of(dsls)
    frames = ',\n            '.join(f'"{d}"' for d in dsls)
    return (
        f'        // {catalog_id} <- {source}\n'
        '        FigureRecord(\n'
        f'            catalogId: "{catalog_id}",\n'
        f'            motion: .{motion},\n'
        f'            bounds: FigureBounds(minX: {x:.2f}, minY: {y:.2f}, width: {w:.2f}, height: {h:.2f}),\n'
        '            frames: [\n'
        f'            {frames}\n'
        '            ]\n'
        '        )'
    )


def main():
    assert len(MAPPING) == 35, f'expected 35 catalog ids, got {len(MAPPING)}'
    assert not (set(UNMAPPED) & set(MAPPING)), 'unmapped id leaked into MAPPING'
    blocks = []
    for catalog_id, slug in MAPPING.items():
        folder = os.path.join(ASSETS, slug)
        assert os.path.isdir(folder), f'missing asset folder: {folder}'
        dsls = [dsl_of(os.path.join(folder, f'frame-{i}.svg')) for i in (1, 2, 3)]
        for d in dsls:
            assert d.startswith('M ') and len(d) > 200, f'{catalog_id} frame looks empty'
        motion = 'hold' if catalog_id in STATIC_HOLDS else 'loop'
        blocks.append(record(catalog_id, motion, dsls, slug))

    blocks.append(record('_generic', 'hold', [generic_dsl()], 'placeholder (hand drawn)'))

    src = (
        '// Generated by .scratch/figure-and-glass/tools/gen_figures.py. Do not edit by hand.\n'
        '// Artwork: bryllim/workout-guide, derived from Everkinetic -- CC BY-SA 4.0.\n'
        f'// {len(MAPPING)} catalog ids x 3 frames + 1 generic placeholder.\n'
        'enum GeneratedFigureData {\n'
        '    static let records: [FigureRecord] = [\n'
        + ',\n'.join(blocks) + '\n'
        '    ]\n'
        '}\n'
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w').write(src)
    print(f'wrote {OUT}: {len(src)} bytes, {len(MAPPING)} actions + generic')
    print(f'generic fallback ({len(UNMAPPED)}): {", ".join(UNMAPPED)}')


if __name__ == '__main__':
    main()
