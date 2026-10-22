# 03: 深蹲一张图端到端（示踪弹）

**What to build:** 构建期生成器能把一个动作的三帧 SVG 转成矢量路径常量，并输出一份含帧数与包围盒的 JSON 镜像

**Blocked by:** Blocked by: 02

**Status:** ready-for-agent

- [ ] 图示模块上线：给定 catalogId 返回帧集、播放规则与包围盒；白名单外与未覆盖动作回退 _generic
- [ ] 训练执行屏能显示深蹲的静态剪影：label 填充、12% tint 光晕、按包围盒等比居中不变形
- [ ] 模拟器启动后肉眼可见深蹲剪影，其余动作显示占位图
