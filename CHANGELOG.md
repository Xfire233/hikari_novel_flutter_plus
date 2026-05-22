# Changelog

## 1.1.5+31

- Android 包名和应用显示名统一改为 Hikari Novel Plus，与当前仓库命名保持一致。
- Yamibo 智能订阅改为深度匹配：候选会检查标题、论坛元信息、首楼简介和楼主正文，命中的用户标签会写入本地书籍信息并在详情刷新后保留。
- 智能书架新增替换 / 增量同步模式；每个书架支持单独同步，并在同步时显示封面或列表遮罩进度。
- 修复 Yamibo / ESJ 登录状态判断：同步前做真实登录校验，登录失效时提示用户，WebView 关闭不再误触发同步或清空智能书架内容。
- 增加 Yamibo 每日 05:30-06:00 论坛备份窗口检测；备份期间无数据返回会显示明确提示。
- Wenku8 增加 Cloudflare / 浏览器辅助 fallback，并修复错误页导致的红屏崩溃。
- 统一来源首页、书架、子书架、列表和下拉菜单样式，改为圆角胶囊 / 卡片布局，并补齐主要页面切换动画。
- About 页 GitHub 链接更新为 `https://github.com/Xfire233/hikari_novel_flutter_plus`，移除 Telegram 入口。
- 增加本地 Android 模拟器与 uiautomator2 MCP 调试流程，减少后续重复配置和人工传包验证。
