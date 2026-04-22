# Atlas 京东手机图采集说明

这份说明用于指导后续对话在 `com.openai.atlas` 中打开京东搜索结果页，并把手机商品图补充到：

- [detection/datasets/images/pending/phone](/Users/macmain/Documents/baby/detection/datasets/images/pending/phone)

适用场景：

- 需要继续补 `phone` 类原始图片
- 不想手工一张张另存
- 希望优先复用 Atlas 已加载网页的本地缓存

## 1. 目标目录与格式要求

默认保存目录：

- [pending/phone](/Users/macmain/Documents/baby/detection/datasets/images/pending/phone)

建议要求：

- 格式：`.jpg`、`.jpeg`、`.png`
- 内容：手机主体清楚
- 背景：尽量不要太杂
- 数量：单次先补 `10` 到 `50` 张
- 文件名：保留默认即可

## 2. 推荐流程

推荐优先走下面这条路径：

1. 用 Computer Use 打开 `com.openai.atlas`
2. 确认是否已有“京东”选项卡，或在新标签页打开京东搜索结果页
3. 搜索关键词 `手机`
4. 加载若干结果页，让商品主图进入 Atlas 本地浏览器缓存
5. 从 Atlas 缓存中提取 `360buyimg.com` 商品图链接
6. 优先下载 `n1/n2/n0`、`s480x480` 一类的商品主图
7. 保存到 `detection/datasets/images/pending/phone`
8. 下载后抽查几张，确认不是图标、晒单图或页面装饰图

## 3. 为什么优先用缓存

直接 `curl` 京东搜索页，容易命中风控或验证页。

更稳的方法是：

- 先让 Atlas 正常打开并渲染京东页
- 再从 Atlas 自己的本地缓存中提取商品图 URL

这样通常比直接脚本抓搜索页更稳定。

## 4. Atlas 本地缓存位置

本机 Atlas 浏览器缓存路径可优先检查：

```text
~/Library/Caches/com.openai.atlas/browser-data/host/<profile>/Cache/Cache_Data
```

当前这台机器上实际用到的路径是：

```text
/Users/macmain/Library/Caches/com.openai.atlas/browser-data/host/user-YZeAULVR3CZqfci3xp8wysJH__2105fe8f-aa83-4894-903a-1619f5fb1062/Cache/Cache_Data
```

如果后续账号或 profile 变化，先重新定位 `browser-data/host/*/Cache/Cache_Data`。

## 5. 链接筛选规则

从缓存中抽出的 URL 不要全下，优先保留这些：

- 域名包含 `360buyimg.com`
- 路径包含 `/n1/`、`/n2/`、`/n0/`
- 分辨率包含 `s480x480`、`s276x276`、`s228x228`
- 后缀为 `.jpg`、`.jpeg`、`.png`

建议排除这些：

- `shaidan/`：晒单图
- `imagetools/`：图标或运营素材
- `s48x48`、`s150x150`、`s160x160`、`s142x142`：太小
- `default.image`：占位图
- `log.gif`：埋点
- `sprite-`：雪碧图
- `umm/`、`babel/`、`seckillcms/`：常见页面素材或小图
- 登录、购物车、反馈等页面资源

## 6. AVIF 包装图的处理

京东缓存里常见这种链接：

```text
...jpg.avif
...png.avif
...jpg.dpg.avif
```

不要直接丢掉。可先还原成原始资源再下载：

- `xxx.jpg.avif` -> `xxx.jpg`
- `xxx.png.avif` -> `xxx.png`
- `xxx.jpg.dpg.avif` -> `xxx.jpg`

这一条非常重要，因为很多可用的手机主图都以这种形式出现在缓存里。

## 7. 推荐执行策略

单轮采集建议：

1. 先统计当前目录已有图片数
2. 先下载缓存中直接可用的 `jpg/png`
3. 若数量不够，再把 `.jpg.avif/.png.avif` 还原后继续下载
4. 若仍不够，再在 Atlas 中翻页到第 `2`、`3`、`5` 页等，扩充缓存
5. 每轮下载后复查总数

经验上，单靠前几页缓存就能补不少图；真正补量时，处理 `.avif` 包装图最有效。

## 8. 保存与去重

保存规则建议如下：

- 默认保留原文件名
- 若同名文件已存在，则自动加 `_1`、`_2` 等后缀
- 不覆盖已有图片
- 只写入 `pending/phone`

## 9. 下载后最少检查项

下载完成后至少检查：

- 总数是否达到目标
- 扩展名是否符合要求
- 随机查看几张图，确认是手机主图
- 没有明显混入页面按钮、图标、晒单图

## 10. 后续对话可直接复用的话术

如果其他对话要继续补图，可以直接按这个意思执行：

```text
打开 com.openai.atlas，找到京东手机搜索结果页。
优先从 Atlas 已加载页面的本地缓存里提取 360buyimg 商品图链接，
把可用的 jpg/png 以及可还原的 jpg.avif/png.avif 主图下载到
detection/datasets/images/pending/phone。
要求优先手机主体清楚、背景不太杂，文件名保留默认即可。
如果数量不够，就继续翻京东结果页扩充缓存，直到补到目标数量。
```

## 11. 当前实践结果

本次已经按这套流程把手机图补到：

- [pending/phone](/Users/macmain/Documents/baby/detection/datasets/images/pending/phone)

实际验证过的关键点：

- 直接抓京东搜索页容易被风控
- 先加载 Atlas 页面再读本地缓存更稳
- `.jpg.avif/.png.avif` 还原成原始图片链接后，可显著提升可下载数量
