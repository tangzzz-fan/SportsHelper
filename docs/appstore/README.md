# 隐私政策与支持页

两个静态文件，没有构建步骤、没有外部依赖（不引用 CDN、字体、统计脚本），丢到任意静态托管即可：

```
privacy.html   隐私政策，ASC 的「隐私政策 URL」
support.html   支持页，ASC 的「支持 URL」
```

## 发布前必须替换

```bash
grep -n "SUPPORT_EMAIL\|待填主体名称" privacy.html support.html
```

替换 `SUPPORT_EMAIL`（共 4 处）与「待填主体名称」，再跑一次上面的命令，应当没有输出。
两个文件里都用黄色高亮标出了占位符，改漏了一眼能看见。

## 托管

Apple 只要求「公开可访问、不需要登录、能打开」。任选一种：

| 方式 | 成本 | 备注 |
|---|---|---|
| GitHub Pages | 免费 | 建议单开一个 public 仓库放这两个文件，不要把主仓库公开 |
| Cloudflare Pages | 免费 | 直接拖文件夹上传，自带 HTTPS |
| 自己的域名 / 对象存储 | 已有就行 | 记得开 HTTPS，别用会弹登录页的分享链接 |

拿到地址后填进 `docs/APPSTORE.md` §2.5，两页的相对链接（`./privacy.html`、`./support.html`）要求**两个文件放在同一目录**。

⚠️ 上传前不要在页面里留真实 API Key、内网地址、个人手机号。

## 本地看一眼

```bash
cd docs/appstore && python3 -m http.server 8765
# 打开 http://127.0.0.1:8765/privacy.html
```

深色模式会自动跟随系统，两页都验一次。
