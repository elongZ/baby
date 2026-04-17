# Detection Trial Batch Checklist

当前这份清单用于确认第一批检测数据是否已经达到“可进入训练实现阶段”的最低要求。

## 1. 当前状态

- 图片目录：[detection/datasets/images/train](/Users/macmain/Documents/baby/detection/datasets/images/train)
- 标注目录：[detection/datasets/labels/train](/Users/macmain/Documents/baby/detection/datasets/labels/train)
- 排除目录：[detection/datasets/rejected](/Users/macmain/Documents/baby/detection/datasets/rejected)
- 类别文件：[detection/predefined_classes.txt](/Users/macmain/Documents/baby/detection/predefined_classes.txt)

## 2. 当前统计

- 有效训练图片：`18`
- 有效标注文件：`18`
- 总标注框数：`26`

类别框数统计：

- `0 -> diaper`：`18`
- `1 -> stroller`：`8`

## 3. 已确认有效的试标图片

| 图片 | 标注文件 | 框数 | 类别 |
|---|---:|---:|---|
| `diaper_025.jpg` | 是 | 4 | `0` |
| `diaper_026.jpg` | 是 | 1 | `0` |
| `diaper_027.jpg` | 是 | 3 | `0` |
| `diaper_028.jpg` | 是 | 3 | `0` |
| `diaper_029.jpg` | 是 | 1 | `0` |
| `diaper_030.png` | 是 | 1 | `0` |
| `diaper_031.jpg` | 是 | 1 | `0` |
| `diaper_032.jpg` | 是 | 1 | `0` |
| `diaper_033.png` | 是 | 2 | `0` |
| `diaper_034.png` | 是 | 1 | `0` |
| `jd_stroller_001.png` | 是 | 1 | `1` |
| `jd_stroller_002.jpg` | 是 | 1 | `1` |
| `jd_stroller_004.jpg` | 是 | 1 | `1` |
| `jd_stroller_005.jpg` | 是 | 1 | `1` |
| `jd_stroller_006.jpg` | 是 | 1 | `1` |
| `jd_stroller_008.jpg` | 是 | 1 | `1` |
| `jd_stroller_009.jpg` | 是 | 1 | `1` |
| `jd_stroller_010.jpg` | 是 | 1 | `1` |

## 4. 已排除图片

以下图片已确认不包含当前检测目标，已移出训练目录：

- [jd_stroller_003.png](/Users/macmain/Documents/baby/detection/datasets/rejected/jd_stroller_003.png)
- [jd_stroller_007.jpg](/Users/macmain/Documents/baby/detection/datasets/rejected/jd_stroller_007.jpg)

## 5. 当前检查结论

已完成以下核对：

- 每张有效训练图片都有同名 `.txt` 标注文件
- 标注文件均为标准 YOLO 五列格式
- 类别 id 只出现 `0` 和 `1`
- 坐标均在 `0-1` 范围内
- `classes.txt` 已从 `labels/train/` 移除，避免影响后续训练

## 6. 当前不足

这批数据已足够作为试标集，但还不够正式训练检测模型。

当前主要不足：

- 总图数偏少
- `stroller` 的样本量明显少于 `diaper`
- 目前大多是商品图，场景分布较单一

## 7. 建议下一步

在接入检测训练脚本之前，建议优先做下面两件事：

1. 再补一批 `stroller` 检测样本，尽量让类别更平衡
2. 再补一批更干净、主体明确的图片，减少拼图图和复杂广告图占比

如果只是做“检测训练代码第一轮冒烟测试”，当前这批数据已经可以作为最小可用样本集。
