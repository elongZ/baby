# Detection Project

`detection/` 是当前仓库下独立的目标检测模块，用于承接目标检测任务开发。

它与现有的 [vision](/Users/macmain/Documents/baby/vision) 分类项目并列存在，边界明确：

- `vision/`：只放图像分类项目
- `detection/`：只放目标检测项目

当前模块已经完成第一轮可运行闭环：

- 数据组织
- 边界框标注
- YOLOv8n 检测训练
- 测试集评测
- 单图检测推理与可视化
- OpenCV 摄像头实时检测 demo

## 1. 当前目标

本模块第一期的任务是搭建一个最小目标检测闭环，用于识别：

- `diaper`
- `stroller`

当前已完成：

1. 图片准备
2. 边界框标注
3. 检测训练
4. 评测指标输出
5. 单图检测推理

## 2. 目录结构

```text
detection/
├── README.md
├── configs/
├── datasets/
│   ├── images/
│   │   ├── train/
│   │   ├── val/
│   │   └── test/
│   └── labels/
│       ├── train/
│       ├── val/
│       └── test/
├── notebooks/
├── outputs/
└── scripts/
```

目录职责：

- `configs/`
  检测训练和数据配置

- `datasets/images/`
  检测任务图片数据

- `datasets/labels/`
  对应图片的标注文件

- `notebooks/`
  数据检查、可视化和调试 notebook

- `outputs/`
  模型权重、评测结果、推理可视化结果

- `scripts/`
  数据准备、训练、评测、推理脚本入口

## 3. 数据格式建议

建议第一期优先采用 `YOLO` 格式，便于快速起步和训练：

- 每张图片一个同名 `.txt` 标注文件
- 每行一个目标框
- 格式：

```text
class_id x_center y_center width height
```

坐标使用归一化形式，类别建议暂定：

- `0 -> diaper`
- `1 -> stroller`

## 4. 当前状态

### 4.1 当前数据集

当前检测数据集规模如下：

- `train`: `93` 张图片，`93` 个标注文件
- `val`: `10` 张图片，`10` 个标注文件
- `test`: `7` 张图片，`7` 个标注文件
- `rejected`: `7` 张被排除图片

目录位置：

- 训练集图片：[images/train](/Users/macmain/Documents/baby/detection/datasets/images/train)
- 验证集图片：[images/val](/Users/macmain/Documents/baby/detection/datasets/images/val)
- 测试集图片：[images/test](/Users/macmain/Documents/baby/detection/datasets/images/test)
- 被排除图片：[rejected](/Users/macmain/Documents/baby/detection/datasets/rejected)

### 4.2 当前训练方案

当前训练脚本与配置：

- 训练脚本：[train_detector.py](/Users/macmain/Documents/baby/detection/scripts/train_detector.py)
- 评测脚本：[eval_detector.py](/Users/macmain/Documents/baby/detection/scripts/eval_detector.py)
- 推理脚本：[infer_detector.py](/Users/macmain/Documents/baby/detection/scripts/infer_detector.py)
- 配置文件：[detection.yaml](/Users/macmain/Documents/baby/detection/configs/detection.yaml)

当前采用：

- 模型：`YOLOv8n`
- 训练设备：`CPU`
- 输入尺寸：`640`
- batch size：`4`
- epoch：`20`

Detection Playground 当前支持在 UI 中直接调整推理阈值：

- `Confidence` 可通过滑杆和预设按钮（如 `0.50 / 0.70 / 0.85`）临时调整
- 调整后的阈值会作为**运行时参数**直接传给后端推理
- 该行为**不会修改**磁盘上的 [detection.yaml](/Users/macmain/Documents/baby/detection/configs/detection.yaml)

这意味着：

- `detection/configs/detection.yaml` 仍然保存项目默认阈值
- mac app 中的阈值更适合做现场验证、错误分析和不同阈值对比
- 如果某张图在高阈值下没有出框，不一定是模型完全不会，可能只是当前分数低于 UI 设定值

### 4.3 当前结果

当前最优权重位于：

- [best.pt](/Users/macmain/Documents/baby/runs/detect/detection/outputs/exp1/weights/best.pt)

当前测试集评测结果位于：

- [evaluation_summary.json](/Users/macmain/Documents/baby/runs/detect/detection/outputs/exp1/evaluation_summary.json)

当前测试集指标：

- `mAP50 = 0.601`
- `mAP50-95 = 0.374`

分类别结果：

- `diaper mAP50 = 0.525`
- `stroller mAP50 = 0.677`

评测与推理可视化产物位于：

- [exp1](/Users/macmain/Documents/baby/runs/detect/detection/outputs/exp1)
- [exp1_eval](/Users/macmain/Documents/baby/runs/detect/detection/outputs/exp1_eval)
- [predict](/Users/macmain/Documents/baby/runs/detect/detection/outputs/predict)

### 4.4 当前结论

当前检测链路已经完整跑通：

- 数据准备
- 边界框标注
- 检测训练
- 测试集评测
- 单图推理
- 摄像头实时推理 demo

但当前项目仍然存在明显限制：

- 数据规模仍然偏小
- `diaper` 与 `stroller` 的图像风格分布不够稳定
- 小数据集下分数校准偏低，阈值选择会显著影响推理结果

## 5. 摄像头实时检测

当前仓库已经补上一个薄的 OpenCV 工程层，用于把现有单图推理入口接到摄像头视频流：

- 服务层：[opencv_service.py](/Users/macmain/Documents/baby/detection/opencv_service.py)
- demo 脚本：[camera_demo.py](/Users/macmain/Documents/baby/detection/scripts/camera_demo.py)
- 摄像头配置：[camera.yaml](/Users/macmain/Documents/baby/detection/configs/camera.yaml)

设计原则：

- 继续复用 [service.py](/Users/macmain/Documents/baby/detection/service.py) 的 YOLO 推理逻辑
- 摄像头层只负责读帧、BGR/RGB 转换、周期性推理、结果叠加
- 当前阶段不改 mac app UI，不引入网络传输

运行前请先确保当前 Python 环境至少安装：

- `PyYAML`
- `numpy`
- `opencv-python`
- `ultralytics`

示例命令：

```bash
python -m detection.scripts.camera_demo \
  --config detection/configs/detection.yaml \
  --camera-config detection/configs/camera.yaml
```

默认行为：

- 打开 `camera_index=0`
- 按 `inference_interval` 每隔 N 帧做一次推理
- 窗口中显示 bbox、label、confidence、推理 FPS
- 按 `q` 或 `Esc` 退出

## 6. 后续计划

下一步建议按这个顺序推进：

1. 明确检测类别和标注口径
2. 准备第一批图片
3. 完成框标注
4. 引入检测模型训练脚本
5. 增加评测和可视化输出

更贴近当前状态的下一步建议是：

1. 继续扩充 `diaper` 检测样本
2. 保持 `test` 集类别定义稳定，避免混入成人纸尿裤、说明图等噪声样本
3. 在更稳定的数据分布上继续重训

## 7. 标注规范

本项目第一期只标注两个类别：

- `0 -> diaper`
- `1 -> stroller`

除这两个类别之外，其余物体均视为背景，不单独标注，不设置 `other` 检测类。

### 7.1 标注目标

标注任务的目标是让模型学习在图片中定位并识别：

- `diaper`
- `stroller`

第一期只关注主体清晰、类别明确的目标，不追求覆盖所有复杂边界情况。

### 7.2 总体原则

标注时遵循以下原则：

- 只标清晰可识别的目标
- 框尽量贴近目标主体外边缘
- 不要留过多无关背景
- 不要标极小、极模糊、极难判断的目标
- 多个目标可分别标注多个框

### 7.3 diaper 标注规则

以下情况标注为 `diaper`：

- 单片尿布主体清晰可见
- 整包纸尿裤包装清晰可见，且商品主体明确是尿布
- 图片中有多个独立尿布目标时，可分别标注

以下情况不标：

- 只露出很小一部分，无法明确判断
- 图中只是宣传海报或远处小图
- 主体过小、过模糊或被严重遮挡

### 7.4 stroller 标注规则

以下情况标注为 `stroller`：

- 婴儿推车整车主体清晰可见
- 推车在图中占据主要区域
- 图中有多个清晰可见的推车时，可分别标注

以下情况不标：

- 只有局部配件，无法判断为完整推车
- 推车太小或严重遮挡
- 背景里只有极小目标，接近不可辨认

### 5.5 框选规则

标注框采用目标的外接矩形，要求如下：

- 尽量完整包住目标主体
- 不要裁掉目标主要结构
- 不要包含大面积无关背景
- 同一类目标的框选风格尽量一致

建议：

- `diaper`：框住整片尿布或整包包装
- `stroller`：框住整车主体，不要求极端贴边，但整体要完整

### 5.6 遮挡与截断

对于遮挡或截断目标，按以下规则处理：

- 轻微遮挡但仍能清楚判断类别：可以标
- 中度截断但主体大部分可见：可以标
- 严重遮挡或只剩很小一部分：不标

### 5.7 小目标处理

第一期建议不标极小目标。

经验规则：

- 如果目标宽或高明显小于整张图的 `5%`
- 或者人工观察已接近无法稳定辨认

则先不标，避免增加噪声标注。

### 5.8 多目标处理

一张图片中允许存在多个标注框。

例如：

- 多个 `diaper`：分别标多个框
- 多个 `stroller`：分别标多个框
- 同时存在 `diaper` 和 `stroller`：都要标

### 5.9 背景与非目标物体

以下内容不单独标注：

- 奶瓶
- 玩具
- 湿巾
- 衣物
- 家具
- 文字海报
- 普通家居物品

这些内容统一作为背景处理。

### 5.10 模糊图与脏图处理

以下图片建议剔除，不进入检测数据集：

- 模糊严重
- 分辨率过低
- 主体不可辨认
- 大面积水印或文字遮挡
- 重复度过高的近重复图

### 5.11 标注文件格式

第一期采用 `YOLO` 标注格式。

每张图片对应一个同名 `.txt` 文件，每行格式为：

```text
class_id x_center y_center width height
```

要求：

- 坐标归一化到 `0-1`
- 每行对应一个目标框
- 图片和标注文件同名

示例：

```text
0 0.512500 0.468750 0.325000 0.412500
1 0.710938 0.540625 0.421875 0.568750
```

### 5.12 文件命名要求

建议统一使用英文和数字命名，不使用中文、空格或特殊字符。

例如：

```text
images/train/img_0001.jpg
labels/train/img_0001.txt
```

### 5.13 标注一致性要求

开始大规模标注前，建议先抽取 `20-30` 张图片试标，统一以下口径：

- 类别定义是否一致
- 框是否过松或过紧
- 小目标是否都按同一标准处理
- 遮挡目标是否采用统一规则

只有标注口径统一后，再继续扩充数据集。

### 5.14 当前建议

第一期检测任务的重点不是标很多，而是先保证：

- 类别清晰
- 框标得准
- 规则一致
- 能顺利训练和评测

宁可少量高质量标注，也不要一开始堆很多不稳定样本。
