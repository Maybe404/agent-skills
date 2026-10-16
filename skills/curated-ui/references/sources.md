# 来源与覆盖状态

本 skill 使用 `data/sources.json` 作为来源配置，使用 `data/catalog.json` 作为最近一次目录快照。目录不是把第三方源码全部复制进 skill；它保存可搜索的条目、官方文档地址、registry 地址、依赖、访问级别和覆盖证据。使用时再读取官方页面或 registry。

## 访问级别

- `free`：已确认公开可取，仍须按项目许可证和依赖使用。
- `unknown`：目录可见，但免费源码、登录要求或授权尚未确认。先读文档，不要猜测源码。
- `inspiration-only`：展示、作品或灵感目录，不把页面内容当作可安装源码。
- `excluded-paid`：Pro、付费包或用户明确不购买的内容。不得抓取、重构或推荐为可用源码。

## 当前覆盖

- `shadcn`：官方 registry 与 sitemap；Base UI、Radix、React Aria 等变体需要按项目已有基础选择。
- `obsidian`：74 个官方 registry 条目；Project One 是独立模板仓库，不在组件 registry 中。
- `origin`：组件和 section 目录；`paid: true` 条目排除，缺少 paid 标记仍视为 `unknown`，不能因此宣称免费。
- `bencho`：48 个 Blocks；Finds 是灵感条目，Sounds 是声音资源。组件页的可复制源码优先于压缩 bundle。
- `beautiful`：公开 registry 与 homepage 组件；MIT 页面可从站点 license 核对。读取 registry 时优先安装 foundation，并将 demo 的模拟业务数据替换成真实状态。
- `libraries`：七个免费库的详情页与原始 prompt；Pro Studio、Pro skill 和付费调参不使用。
- `loading`：官方 registry 与组件文档；安装前核对 React、Tailwind、shadcn aliases。
- `reactbits`：852 个 registry 变体，保留 JS/TS × CSS/Tailwind；React Bits Pro 排除。每个条目的依赖需按 registry 取用。
- `lucide`：sitemap 中的图标条目；图标要按语义和可访问名称使用。
- `uiarc`：官方 registry 和 Markdown 文档；仅免费项目，Arc foundation 全局导入一次。
- `designspells`：浏览器核对 340 条作品灵感；CLI/sitemap 被 429 拦截，无公开组件 registry。不要把它当源码库。
- `inspora`：浏览器懒加载观察到 176 条帖子；仍是部分覆盖，且是灵感/作品目录。
- `collectui`：有分类、搜索、Trending 和动态 Latest Designs，但静态页面不能枚举完整条目；按需用站内导航，不声称全量。
- `jakub`：主页作品媒体；不是组件源码目录。
- `getdesign`：公共 DESIGN.md 网站目录；Animated Backgrounds 页面列出 36 个付费效果，用户不购买，全部排除。公共条目逐项检查授权。

## 不能解决的部分

Design Spells、Inspora 和 Collect UI 的全量内容会随站点分页、懒加载或安全策略变化。当前已记录证据与边界，但没有把“看到了首页”冒充成“全量抓取”。若之后网站公开 sitemap、API 或 registry，只需在 `data/sources.json` 增加 endpoint 并运行 `refresh --source <id>`。
