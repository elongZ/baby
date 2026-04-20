# Robotics Demo Module

`robotics/` 是当前仓库下独立的机器人演示模块，用于承接基于 `OpenCV + PyTorch + 工业视觉流程` 的机械臂应用层表达。

它和现有模块的边界如下：

- `vision/`：图像分类实验与拒识原型
- `detection/`：目标检测训练、评测、推理闭环
- `robotics/`：复用视觉结果，构建机械臂任务时间线、执行阶段和工业视觉演示页面

## 1. 模块目标

第一版目标不是做真实机械臂控制，而是做一个可在 mac app 中展示的“视觉引导机械臂演示”应用层模块：

- 展示输入图像与检测结果
- 展示任务计时器和阶段推进
- 展示 `OpenCV -> PyTorch -> Industrial Vision Logic -> Robot Action` 这条技术链
- 为后续半真实机械臂 demo 预留扩展点

## 2. 第一版范围

当前已落地：

- `Robotics / Playground`
  - 复用 `Detection` 已选图片与推理结果
  - 展示输入画面、检测渲染图、目标锁定、抓取点和任务状态
  - 提供 `Mission Timer` 与 `Detect -> Target Lock -> Path Plan -> Pick -> Place` 阶段推进
  - 提供 `Target Lock Reasoning` 与 `Sorting Logic` 两张解释卡
- `Robotics / Workflow`
  - 展示 OpenCV、PyTorch 和工业视觉逻辑在整条链路中的分工
  - 动态显示当前 `model / device / confidence / IoU / target`
  - 展示运行时快照，包括当前图片、抓取点、分拣决策和任务阶段

第一版仍然保持：

- 机械臂动作为模拟时间线，不接真实控制器
- 分拣决策采用规则路由，不做真实路径规划
- 视觉主能力来自现有 `detection/` 模块

第一版明确不做：

- 真实机械臂控制
- 相机与机械臂坐标标定
- PLC / 控制器 / 串口通信
- 真实抓取规划与避障

## 3. 技术口径

在当前实现里各技术的表达口径约定如下：

- `OpenCV`
  - 图像读写
  - 预处理
  - 检测结果绘制
  - 目标点位提取

- `PyTorch`
  - 视觉分类 / 检测模型推理
  - 输出解析
  - 置信度评分

- `Industrial Vision Logic`
  - 目标选择
  - 任务编排
  - 分拣流程模拟

## 4. 当前页面结构

### 4.1 Playground

当前页面由以下区域组成：

- `Robotics Controls`
  - 直接复用 Detection 的选图、运行推理、刷新状态入口
- `Scene and Detection`
  - 展示输入图或渲染结果图
  - 展示目标类别、置信度、抓取点
- `Mission Timer`
  - 展示当前阶段与下一步动作
- `Task Stages`
  - 按阶段推进机械臂任务时间线
- `Technology Stack`
  - 概述 `OpenCV / PyTorch / Industrial Vision Logic`
- `Action Summary`
  - 汇总最终分拣决策与当前运行状态
- `Target Lock Reasoning`
  - 解释为什么选中当前目标与抓取点如何计算
- `Sorting Logic`
  - 解释类别如何映射到目标 bin

### 4.2 Workflow

当前页面由以下区域组成：

- `Pipeline Overview`
  - 固定展示 `Input -> OpenCV -> PyTorch -> Decision -> Robot Action`
- 5 张技术说明卡
  - `Input Acquisition`
  - `OpenCV Processing`
  - `PyTorch Inference`
  - `Industrial Vision Logic`
  - `Robot Action Demo`
- `Runtime Snapshot`
  - 展示当前图片、目标、抓取点、决策、阶段与下一步动作

## 5. 目录规划

```text
robotics/
├── README.md
├── configs/
├── scripts/
└── outputs/
```

当前先立目录边界，后续逐步补充：

- `configs/`：场景、阶段、演示参数配置
- `scripts/`：演示数据生成、状态流模拟脚本
- `outputs/`：可视化截图、演示产物
- `models.py`：结构化视觉框、抓取点、机器人决策数据模型
- `vision_logic.py`：目标选择、抓取点计算、bin 路由与决策输出

## 6. 与 Detection 的关系

`robotics/` 当前不单独维护模型与训练状态，而是站在 `detection/` 之上做应用层表达：

- `detection/` 负责模型、权重、推理结果与评测能力
- `robotics/` 负责把检测结果转成任务时间线、抓取点和分拣决策展示
- mac app 中 `Robotics` 与 `Detection` 平级，但运行时直接复用 Detection 状态

当前已补上的最小逻辑层包括：

- 默认选择最高置信度目标作为当前任务目标
- 默认使用 bbox 中心点作为 `pick_point`
- 默认分拣规则：
  - `diaper -> bin A`
  - `stroller -> bin B`
- 输出统一结构，便于后续给 mac app 或 API 直接消费

## 7. 当前决策输出

当前 `robotics/vision_logic.py` 输出的统一结果包含：

- `target`
- `pick_point`
- `destination_bin`
- `planner`
- `route_rule`
- `selection_reason`

这层的职责是把检测结果从“看到了什么”转成“机器人下一步应该做什么”。

## 8. 后续演进

建议按以下顺序推进：

1. 为 `Mission Timer` 补更细的阶段动画与更稳定的时间轴
2. 在 `robotics/configs/` 中抽出场景、bin 路由和阶段配置
3. 为 `outputs/` 增加演示截图与录屏产物
4. 最后再考虑半真实机械臂 demo
