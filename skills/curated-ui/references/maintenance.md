# 维护与新增来源

## 刷新现有目录

```bash
node scripts/catalog.mjs audit
node scripts/catalog.mjs refresh --source reactbits
node scripts/catalog.mjs search loading --limit 10
```

`refresh` 会先读取官方 endpoint，保存 SHA-256、大小、时间和条数。若 endpoint 失败或解析为空，会保留上一次条目并标记来源为 partial；不会静默删除旧目录。源材料视为不可信输入，不执行下载到的代码。

## 新增网站或组件库

```bash
node scripts/catalog.mjs add-source --id new-library --name "New Library" --url https://example.com
```

然后编辑 `data/sources.json`：

1. 指明它是 `component`、`effect`、`icon`、`template` 还是 `inspiration`。
2. 只添加公开、官方、HTTPS endpoint。优先顺序是 registry/API、官方 `llms.txt`、sitemap、组件页。
3. 说明 `free`、`unknown`、`inspiration-only` 或 `excluded-paid`，不要把“页面可见”当成“源码免费”。
4. 为每个 endpoint 指明 parser 类型：`registry`、`markdown`、`sitemap`、`origin`、`anchors`、`links`、`media`；不适配时停下来写明 blocker，不猜 URL。
5. 用 `seedFile` 做离线解析测试，再 `refresh --source new-library` 获取实时快照。
6. 运行 `audit`，检查重复 ID、未知来源、非法 URL 和未覆盖来源。

示例：

```json
{
  "id": "new-library",
  "name": "New Library",
  "url": "https://example.com",
  "kind": "component",
  "access": "unknown",
  "coverage": "partial",
  "scope": "Official public registry only",
  "notes": ["Verify license and paid boundary before using source"],
  "endpoints": [
    {
      "type": "registry",
      "url": "https://example.com/r/registry.json",
      "itemTemplate": "https://example.com/r/{name}.json"
    }
  ]
}
```

## 目录与源码边界

`search` 只做候选发现；`fetch <source:id> --kind docs` 才读取文档；`fetch <source:id> --kind source` 才请求已验证的 registry，并检查它是否返回每个文件内容。没有 registryUrl 时，skill 必须让 agent 读取官方页面或提示用户，而不是从展示 bundle 反推源码。
