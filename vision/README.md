# Vision Classification Project

当前 `vision/` 子项目已经从最初的通用草稿收敛为一个可运行的二分类视觉实验：

- 训练类别：`diaper`、`stroller`
- 推理输出：`diaper`、`stroller`、`other`
- `other` 不参与训练，基于拒识策略在推理阶段输出

当前仓库内已经跑通：

- 数据采集
- 数据集划分
- 模型训练
- 测试集评测
- 单图推理
- `manual_checks/` 批量验证
- `embedding` 原型距离拒识

## 1. 当前目标

本项目当前目标不是做完整开放集识别系统，而是基于小规模商品图数据，先完成一个清晰可运行的视觉分类闭环，并验证“目标类 + 拒识”的可行性。

当前任务定义：

- 输入一张图片
- 如果图像更像 `diaper`，输出 `diaper`
- 如果图像更像 `stroller`，输出 `stroller`
- 如果图像不像这两个已知类，输出 `other`

## 2. 当前方案

当前采用的是：

- 训练阶段：标准二分类 `diaper / stroller`
- 推理阶段：拒识策略输出 `other`

目前实现了两种拒识方式：

1. `softmax` 置信度阈值拒识
2. `embedding` 原型距离拒识

当前配置中默认启用的是：

- `prototype` 原型距离拒识

## 3. 当前目录结构

```text
vision/
├── README.md
├── requirements.txt
├── configs/
│   └── classification.yaml
├── datasets/
│   ├── raw/
│   │   ├── diaper/
│   │   └── stroller/
│   ├── processed/
│   ├── splits/
│   │   ├── train/
│   │   ├── val/
│   │   └── test/
│   └── manual_checks/
├── outputs/
│   └── classification_run/
├── scripts/
│   ├── build_prototypes.py
│   ├── eval_classifier.py
│   ├── infer_classifier.py
│   ├── prepare_dataset.py
│   ├── split_dataset.py
│   └── train_classifier.py
└── src/
    ├── data/
    ├── eval/
    ├── infer/
    ├── models/
    └── train/
```

## 4. 当前数据情况

当前原始数据目录：

- [vision/datasets/raw/diaper](/Users/macmain/Documents/baby/vision/datasets/raw/diaper)
- [vision/datasets/raw/stroller](/Users/macmain/Documents/baby/vision/datasets/raw/stroller)

当前已收集样本量大致为：

- `diaper`：约 `150`
- `stroller`：约 `150`

当前划分结果：

- `train`
  - `diaper`: `98`
  - `stroller`: `111`
- `val`
  - `diaper`: `21`
  - `stroller`: `23`
- `test`
  - `diaper`: `22`
  - `stroller`: `25`

划分脚本：

```bash
python -m vision.scripts.split_dataset --config vision/configs/classification.yaml
```

说明：

- 当前划分默认使用软链接，不重复复制原图
- `split_dataset.py` 会按配置里的比例自动重建 `train/val/test`

## 5. 当前训练配置

配置文件：

- [vision/configs/classification.yaml](/Users/macmain/Documents/baby/vision/configs/classification.yaml)

当前关键配置：

- 模型：`resnet18`
- 训练类别：`diaper`、`stroller`
- `batch_size`: `8`
- `epochs`: `5`
- `num_workers`: `0`
- `device`: `auto`

说明：

- `num_workers` 当前固定为 `0`
- 这是为了避免 macOS / Apple Silicon 上 dataloader 多进程卡住

## 6. 当前训练结果

训练输出目录：

- [vision/outputs/classification_run](/Users/macmain/Documents/baby/vision/outputs/classification_run)

当前已产出：

- [best_model.pt](/Users/macmain/Documents/baby/vision/outputs/classification_run/best_model.pt)
- [train_summary.json](/Users/macmain/Documents/baby/vision/outputs/classification_run/train_summary.json)

当前训练结果摘要：

- 最佳验证集准确率：`0.9091`

训练命令：

```bash
python -m vision.scripts.train_classifier --config vision/configs/classification.yaml
```

## 7. 当前测试评测结果

评测输出：

- [classification_report.json](/Users/macmain/Documents/baby/vision/outputs/classification_run/classification_report.json)
- [confusion_matrix.png](/Users/macmain/Documents/baby/vision/outputs/classification_run/confusion_matrix.png)

评测命令：

```bash
python -m vision.scripts.eval_classifier --config vision/configs/classification.yaml
```

当前测试集结果：

- `accuracy`: `0.9787`
- `macro F1`: `0.9787`

分类别表现：

- `diaper`
  - `precision`: `0.9565`
  - `recall`: `1.0000`
  - `f1`: `0.9778`

- `stroller`
  - `precision`: `1.0000`
  - `recall`: `0.9600`
  - `f1`: `0.9796`

说明：

- 当前数据主要是商品图，场景较干净
- 这些指标更适合说明“链路和模型训练已跑通”
- 不能直接等同于复杂真实场景表现

## 8. 当前拒识方案

### 8.1 Softmax 阈值拒识

逻辑：

- 模型先输出 `diaper / stroller` 的概率
- 如果最高概率低于阈值，则输出 `other`

这是第一版最简单的拒识方式，但存在明显边界：

- 能拒掉低置信度样本
- 不能解决高置信度误判

### 8.2 Prototype 原型距离拒识

当前已经实现更接近开放集思路的方案：

- 从训练好的模型中提取 `embedding`
- 为 `diaper`、`stroller` 生成各自的原型中心
- 推理时计算输入图片与各类原型的余弦相似度
- 如果最高相似度低于阈值，则输出 `other`

原型文件：

- [prototypes.json](/Users/macmain/Documents/baby/vision/outputs/classification_run/prototypes.json)

生成命令：

```bash
python -m vision.scripts.build_prototypes --config vision/configs/classification.yaml
```

当前配置中默认启用：

```yaml
infer:
  rejection_mode: prototype
  prototype_path: vision/outputs/classification_run/prototypes.json
  prototype_similarity_threshold: 0.96
```

## 9. 当前推理方式

单图推理命令：

```bash
python -m vision.scripts.infer_classifier \
  --config vision/configs/classification.yaml \
  --image /absolute/path/to/image.png
```

当前推理输出会包含：

- 最终类别
- 拒识模式
- 最高相似度或最高概率
- 两个已知类的分数

例如：

- `Final prediction: diaper`
- 或 `Final prediction: other`

## 10. Manual Checks

当前专门留了一个人工验证目录：

- [vision/datasets/manual_checks](/Users/macmain/Documents/baby/vision/datasets/manual_checks)

这里用于放：

- 目标类图片
- 非目标类图片
- 需要手工检查拒识效果的图片

当前已生成的汇总文件：

- [inference_summary_prototype.json](/Users/macmain/Documents/baby/vision/datasets/manual_checks/inference_summary_prototype.json)

说明：

- 当前保留的是 `inference_summary_prototype.json`
- 它对应当前默认启用的原型拒识实验

## 11. 当前结论

目前这个 `vision/` 子项目已经不再是纯文档草稿，而是一个已经实际跑通的视觉分类实验模块。

当前已验证的事实：

- 二分类训练链路可运行
- 测试集上可以得到较高精度
- 单纯 softmax 阈值拒识有限
- 原型距离拒识更符合“不训练海量 other”的目标
- 但当前模型仍明显受到训练数据分布影响，尤其对部分非目标图或推车图存在偏向 `diaper` 的情况

## 12. 下一步建议

如果继续往前做，优先级建议如下：

1. 扩充并清洗 `stroller` 数据，减少类别偏差
2. 继续补 `manual_checks/` 验证图，观察拒识稳定性
3. 对 `prototype_similarity_threshold` 做系统扫描
4. 在保持二分类训练的基础上继续优化开放集拒识效果

当前阶段不建议：

- 立刻引入海量 `other` 训练样本
- 立刻扩展到检测、分割、点云

因为现在最重要的是先把这个“已知类分类 + 未知类拒识”的最小闭环打磨稳定。
