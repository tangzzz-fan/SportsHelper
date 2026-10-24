"""八个没有上游素材的动作：参数化线稿坐标。

定位是**兜底**，不是替代素材。素材优先级更高；只有 302 个上游目录里确实搜不到时，
才在这里手写坐标。风格约束见 docs/FIGURE-STYLE.md。

坐标空间 512x512，y 向下。正面视角 x=256 为中线；侧面视角人物朝右。
"""
import math
import draw_lib as L

AXIS = 256


# ---- 站姿骨架（正面） -----------------------------------------------------

def standing_front(**over):
    """返回一套默认站姿关节点，可按需覆盖。"""
    p = {
        "head": (256, 70, 30, 30, 0),
        "neck_top": (256, 99),
        "neck_bottom": (256, 126),
        "shoulder_l": (196, 128),
        "shoulder_r": (316, 128),
        "hip_l": (224, 290),
        "hip_r": (290, 290),
        "elbow_l": (176, 206),
        "wrist_l": (182, 274),
        "elbow_r": (336, 206),
        "wrist_r": (330, 274),
        "knee_l": (228, 380),
        "ankle_l": (226, 458),
        "knee_r": (290, 380),
        "ankle_r": (292, 458),
    }
    p.update(over)
    return p


def front_body(p):
    return L.flat(
        L.head(p["head"][0], p["head"][1], p["head"][2], p["head"][3], p["head"][4]),
        L.neck(p["neck_top"], p["neck_bottom"], 21),
        L.torso((p["shoulder_l"], p["shoulder_r"]), (p["hip_l"], p["hip_r"])),
        L.arm(p["shoulder_l"], p["elbow_l"], p["wrist_l"], 26, 21),
        L.hand(p["wrist_l"], 88, 15),
        L.arm(p["shoulder_r"], p["elbow_r"], p["wrist_r"], 26, 21),
        L.hand(p["wrist_r"], 92, 15),
        L.leg(p["hip_l"], p["knee_l"], p["ankle_l"], 40, 29),
        L.foot(p["ankle_l"], -1, 24, 10),
        L.leg(p["hip_r"], p["knee_r"], p["ankle_r"], 40, 29),
        L.foot(p["ankle_r"], 1, 24, 10),
    )


# ---- 1 原地踏步 -----------------------------------------------------------

def pose_march_in_place():
    frames = []
    for lift in (1, -1):
        if lift > 0:
            p = standing_front(
                elbow_l=(168, 200), wrist_l=(176, 262),
                elbow_r=(344, 198), wrist_r=(330, 250),
                knee_r=(318, 344), ankle_r=(292, 396),
                knee_l=(226, 378), ankle_l=(224, 456),
            )
        else:
            p = standing_front(
                elbow_l=(168, 198), wrist_l=(182, 250),
                elbow_r=(344, 200), wrist_r=(336, 262),
                knee_l=(198, 344), ankle_l=(224, 396),
                knee_r=(292, 378), ankle_r=(294, 456),
            )
        frames.append(front_body(p))
    return frames


# ---- 2 髋绕环（侧面，手扶髋） --------------------------------------------

def side_body(head_pt, spine, hip, knee, ankle, arm_pts, foot_fwd=1, arm2=None):
    """侧面骨架：躯干用一条管（厚度=胸厚），不用正面的左右肩四边形。"""
    shoulder = spine[0]
    waist = spine[1]
    out = L.flat(
        L.head(head_pt[0], head_pt[1], 30, 30, head_pt[2]),
        L.neck((head_pt[0], head_pt[1] + 30), (shoulder[0], shoulder[1] + 4), 21),
        L.tube([shoulder, waist, hip], [58, 50, 56]),
        L.arm(arm_pts[0], arm_pts[1], arm_pts[2], 24, 20),
        L.hand(arm_pts[2], arm_pts[3] if len(arm_pts) > 3 else 80, 14),
        L.leg(hip, knee, ankle, 38, 28),
        L.foot(ankle, foot_fwd, 26, 10),
    )
    if arm2:
        out = out + L.flat(
            L.arm(arm2[0], arm2[1], arm2[2], 23, 19),
            L.hand(arm2[2], arm2[3] if len(arm2) > 3 else 80, 13),
        )
    return out


def pose_hip_circle():
    frames = []
    # 帧1 骨盆前倾：腰椎前凸，胸略后
    frames.append(side_body(
        head_pt=(248, 72, 6), spine=((252, 130), (258, 205)), hip=(262, 292),
        knee=(256, 382), ankle=(254, 458),
        arm_pts=((252, 130), (232, 206), (262, 272), 150),
        arm2=((252, 130), (280, 206), (262, 272), 150),
        foot_fwd=1,
    ))
    # 帧2 骨盆后倾：腰椎后凸，髋向后
    frames.append(side_body(
        head_pt=(250, 70, -4), spine=((254, 128), (250, 205)), hip=(246, 292),
        knee=(252, 382), ankle=(254, 458),
        arm_pts=((254, 128), (234, 206), (252, 272), 150),
        arm2=((254, 128), (282, 206), (252, 272), 150),
        foot_fwd=1,
    ))
    return frames


# ---- 3 肩胛绕环（正面，肩胛后收） ----------------------------------------

def pose_scapular_circle():
    frames = []
    # 帧1 放松
    frames.append(front_body(standing_front()))
    # 帧2 肩胛后收：肩点向内微收、胸口打开（用肩线变窄 + 手臂略后）
    p = standing_front(
        shoulder_l=(204, 126), shoulder_r=(308, 126), neck_bottom=(256, 124),
        elbow_l=(184, 206), wrist_l=(190, 272),
        elbow_r=(328, 206), wrist_r=(322, 272),
    )
    frames.append(front_body(p))
    return frames


# ---- 4 踝绕环（侧面，单脚点地） ------------------------------------------

def pose_ankle_circle():
    frames = []
    frames.append(side_body(
        head_pt=(250, 70, 0), spine=((254, 130), (256, 205)), hip=(256, 290),
        knee=(254, 380), ankle=(252, 456),
        arm_pts=((254, 130), (232, 198), (250, 250), 150),
        arm2=((254, 130), (280, 198), (256, 226), 150),
        foot_fwd=1,
    ))
    # 第二帧：重心移到左腿，右脚尖点地画圈
    out = side_body(
        head_pt=(250, 70, 0), spine=((254, 130), (256, 205)), hip=(256, 290),
        knee=(254, 380), ankle=(252, 456),
        arm_pts=((254, 130), (232, 198), (250, 250), 150),
        arm2=((254, 130), (280, 198), (256, 226), 150),
        foot_fwd=1,
    )
    out = out + L.flat(
        L.leg((262, 292), (288, 372), (300, 436), 34, 25),
        L.capsule((300, 436), (322, 452), 16, 8),
    )
    frames.append(out)
    return frames


# ---- 5 颈肩拉伸（正面，歪头扶头） ----------------------------------------

def pose_neck_stretch():
    frames = []
    for extra in (0, 6):
        tilt = 16 + extra
        out = L.flat(
            L.head(256 + extra * 0.5, 70 + extra * 0.3, 30, 30, tilt),
            L.neck((258, 99), (252, 126), 21),
            L.torso(((198, 132), (314, 124)), ((224, 290), (290, 290))),
            L.arm((198, 132), (178, 206), (184, 274), 26, 21),
            L.hand((184, 274), 88, 15),
            L.arm((314, 124), (352, 178), (294 + extra, 96), 25, 19),
            L.hand((294 + extra, 96), 200, 14),
            L.leg((228, 290), (226, 380), (224, 456), 40, 29),
            L.foot((224, 456), -1, 24, 10),
            L.leg((288, 290), (290, 380), (292, 456), 40, 29),
            L.foot((292, 456), 1, 24, 10),
        )
        frames.append(out)
    return frames


# ---- 6 穿针式（四点跪，一手穿身下） --------------------------------------

def pose_thread_needle():
    frames = []
    # 帧1 四点跪
    base = L.flat(
        L.head(196, 214, 28, 28, 12),
        L.neck((212, 236), (232, 250), 20),
        L.torso(((236, 248), (236, 258)), ((300, 262), (300, 272)), 0.02),
        # 支撑手臂
        L.arm((238, 252), (232, 330), (230, 404), 24, 19),
        L.hand((230, 404), 90, 14),
        # 腿（跪姿：大腿水平向后，小腿向后下）
        L.leg((292, 266), (356, 286), (382, 348), 36, 27),
        L.foot((382, 348), 1, 22, 9),
        L.leg((286, 276), (348, 300), (372, 358), 34, 26),
        L.foot((372, 358), 1, 22, 9),
        L.capsule((300, 430), (410, 430), 9),
    )
    frames.append(base)
    # 帧2 右肩下沉、手臂穿过身体下方，肩与耳贴地
    deep = L.flat(
        L.head(186, 244, 28, 27, 34),
        L.neck((208, 258), (230, 264), 20),
        L.torso(((236, 258), (240, 272)), ((302, 266), (306, 280)), 0.02),
        L.arm((240, 262), (204, 300), (156, 316), 24, 19),
        L.hand((156, 316), 175, 14),
        L.arm((244, 268), (232, 336), (230, 404), 23, 18),
        L.hand((230, 404), 90, 14),
        L.leg((292, 270), (356, 288), (382, 348), 36, 27),
        L.foot((382, 348), 1, 22, 9),
        L.leg((288, 280), (348, 302), (372, 358), 34, 26),
        L.foot((372, 358), 1, 22, 9),
        L.capsule((300, 430), (410, 430), 9),
    )
    frames.append(deep)
    return frames


# ---- 7 仰卧抱膝（侧面） --------------------------------------------------

def pose_back_stretch():
    # 头在左，脚在右；背贴地
    out = L.flat(
        L.capsule((110, 452), (420, 452), 10),
        L.head(146, 408, 30, 29, 72),
        L.neck((172, 420), (198, 428), 21),
        L.torso(((200, 424), (204, 448)), ((300, 420), (304, 446)), 0.0),
        # 手臂抱膝
        L.arm((212, 432), (262, 366), (330, 392), 25, 20),
        L.hand((330, 392), 20, 14),
        # 大腿抱向胸口、小腿折叠
        L.leg((300, 428), (352, 350), (300, 300), 40, 29),
        L.foot((300, 300), -1, 24, 10),
        L.leg((306, 436), (360, 360), (312, 312), 38, 27),
        L.foot((312, 312), -1, 22, 9),
    )
    return [out]


# ---- 8 哑铃地板卧推（侧面） ----------------------------------------------

def pose_floor_press():
    frames = []
    for up in (False, True):
        if up:
            arm = ((212, 430), (240, 360), (268, 306))
            wrist = (268, 306)
            db_angle = 90
        else:
            arm = ((212, 430), (266, 404), (306, 386))
            wrist = (306, 386)
            db_angle = 90
        out = L.flat(
            L.capsule((104, 454), (424, 454), 10),
            L.head(142, 412, 30, 29, 74),
            L.neck((168, 424), (196, 430), 21),
            L.torso(((198, 426), (202, 450)), ((300, 424), (304, 448)), 0.0),
            # 屈膝踩地
            L.leg((302, 430), (356, 372), (352, 452), 40, 29),
            L.foot((352, 452), 1, 24, 10),
            L.leg((308, 440), (360, 384), (356, 452), 38, 27),
            # 手臂 + 哑铃
            L.arm(*arm, 25, 20),
            L.hand(wrist, 270, 14),
            L.dumbbell((wrist[0], wrist[1] - 18), db_angle, 26, 13, 7),
        )
        frames.append(out)
    return frames


# ---- 注册表 ---------------------------------------------------------------

POSES = {
    "march_in_place": (pose_march_in_place, "loop"),
    "hip_circle": (pose_hip_circle, "loop"),
    "scapular_circle": (pose_scapular_circle, "loop"),
    "ankle_circle": (pose_ankle_circle, "loop"),
    "neck_stretch": (pose_neck_stretch, "hold"),
    "thread_needle": (pose_thread_needle, "hold"),
    "back_stretch": (pose_back_stretch, "hold"),
    "dumbbell_floor_press": (pose_floor_press, "loop"),
}
