# 01: 冻结文档补丁：一句话生成与语音播报入册

**What to build:** 让「FROZEN + SPEC 是唯一依据」这件事继续成立——把两个新能力写进冻结文档，而不是只活在代码里。

**Blocked by:** None (can start immediately)

**Status:** todo

- [ ] `docs/SPEC.md` §2 增 F11 一句话生成（文字 / 语音输入 → 理解确认 → AI 生成 → 校对）、F12 语音播报（关键节点 + 3-2-1，默认关、仅前台）
- [ ] §7 页面清单补「理解确认」sheet；§9 验收补 AC-37 / AC-38（见下）
- [ ] `docs/FROZEN-BASELINE.md` 增决策 13 / 14：
      13 一句话生成 = 先确认后生成；本次覆盖档案但不写回；伤病只增不减
      14 语音播报 = `AVSpeechSynthesizer`，默认关，仅前台，跟随静音键，VoiceOver 运行时让路
- [ ] `docs/decisions/OPEN-DECISIONS.md` 补两行 RESOLVED（输入方式 / 冲突口径；播报范围 / 默认值）
- [ ] `docs/HANDOFF.md` 功能清单与测试数字同步；新增 §6.13 记录本批
- [ ] 验收：全仓检索「语音播报」不再只指向 VoiceOver；AC-12 的「声音」明确为系统音，不误写成 TTS

**AC-37**：When 用户输入一句描述并点生成，系统必须先展示理解确认页；确认后才发起 AI 请求。

**AC-38**：While 语音播报开启且 App 在前台，When 进入新的一组或休息归零，系统必须朗读对应文案；静音键打开时必须不发声。
