# Pediatrics RAG

基于《美国儿科协会育儿百科》PDF 的本地 RAG 知识问答系统，当前提供 `SwiftUI + 本地 FastAPI` 的 mac 原生入口。

## 1. 项目结构

```text
baby/
├── api/
│   └── main.py
├── data/
│   └── .gitkeep
├── docs/
│   └── training_strategy.md
├── mac-app/
│   └── Package.swift
├── rag/
│   ├── __init__.py
│   ├── generator.py
│   ├── pipeline.py
│   └── retriever.py
├── scripts/
│   ├── __init__.py
│   ├── build_kb.py
│   ├── chunk_splitter.py
│   ├── embedding_builder.py
│   ├── pdf_loader.py
│   └── text_cleaner.py
├── vector_db/
│   └── .gitkeep
├── web/
│   └── app.py
├── .env.example
├── .gitignore
└── requirements.txt
```

## 2. 快速开始

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

1. 把要入库的资料放到 `kb_sources/`
   - 当前自动支持：`.pdf`、`.txt`、`.md`
   - 启动 API 时会自动过滤隐藏文件和不支持的文件类型
2. 手动构建/刷新知识库（可选）：

```bash
python -m scripts.build_kb
```

3. 安装桌面运行依赖：

```bash
pip install -r requirements-runtime.txt
```

4. 启动 SwiftUI mac App（默认入口）：

```bash
cd mac-app
swift run
```

SwiftUI App 会自动拉起本地 Python FastAPI 服务，启动时自动扫描 `KB_SOURCE_DIR`（默认 `kb_sources/`），如果检测到新增、删除或修改过的资料文件，就自动重建向量库；如果资料没有变化，则直接复用现有索引。初始化完成后即可直接提问，不需要再单独启动 API 和 Web。

5. 打包成可双击启动的 `.app`：

```bash
chmod +x scripts/build_swiftui_app.sh
./scripts/build_swiftui_app.sh
open dist/PediatricsRAGMacApp.app
```

打包产物位于 `dist/PediatricsRAGMacApp.app`，双击即可启动。

6. 单独启动本地 API（可选）：

```bash
python -m scripts.run_local_api
```

如果需要从 Finder 或其他工作目录运行，可设置：

```bash
export BABY_APP_PROJECT_ROOT=/Users/macmain/Documents/baby
```

7. 启动 Web 入口（可选）：

```bash
python -m scripts.run_local_api
python -m scripts.run_web
```

`scripts.run_web` 会自动读取 `BABY_APP_API_PORT` / `API_BASE`，默认连接 `http://127.0.0.1:8765`，与 SwiftUI App 保持一致。

如果你已经打开 SwiftUI App，它已经拉起了本地 API，这时可以直接执行：

```bash
python -m scripts.run_web
```

## 3. 桌面版说明

- 当前为项目初始化版本，已具备离线建库与在线检索问答主链路。
- 索引中的每个 chunk 默认包含 `chunk_id/source/page/text` 元数据，便于回答引用出处。
- 支持可选重排（Reranker）：可通过 `.env` 中 `ENABLE_RERANKER=true` 启用。
- SwiftUI App 默认保留三个调参项：`top_k`、`retrieve_k`、`relevance_threshold`
- SwiftUI App 会自动拉起本地 FastAPI，并在后台轮询健康检查
- 默认生成器支持两种模式：
  - 配置 OpenAI 兼容接口（如本地 vLLM/Ollama 的兼容网关）
  - 未配置时自动回退到“检索片段拼接回答”模式，便于联调
- 微调路线约定：
  - 工程落地优先使用 `Unsloth` 在本机做 `QLoRA/LoRA`
  - 原理说明按标准 `Transformers + PEFT + bitsandbytes + SFT` 链路表述
  - 微调目标是“回答行为对齐”，不是把儿科知识硬灌进模型

## 4. 检索评估

先准备评测集（JSONL），可参考 `data/eval_set.example.jsonl` 复制为 `data/eval_set.jsonl`。

```bash
cp data/eval_set.example.jsonl data/eval_set.jsonl
```

执行评估：

```bash
python -m scripts.eval_retrieval --dataset data/eval_set.jsonl --top-k 3 --retrieve-k 9
```

启用重排评估：

```bash
python -m scripts.eval_retrieval --dataset data/eval_set.jsonl --top-k 3 --retrieve-k 9 --use-reranker
```

## 5. 训练说明

训练策略、数据格式和面试表达口径见 [training_strategy.md](/Users/macmain/Documents/baby/docs/training_strategy.md)。

训练文件职责区分：

- `data/training_data.sqlite3` 是训练标注主存储，mac app 直接在库里做增删改查
- `data/sft_annotations.done.jsonl` 是从 SQLite 导出的快照，不再是主编辑入口
- `data/sft_train.jsonl` 是从 SQLite 自动转换出的训练产物，用于直接喂给 SFT / Unsloth
- 日常维护应改 SQLite，不要直接手改 `train`

安装训练依赖：

```bash
pip install -r requirements-train.txt
```

启动本地 QLoRA 训练：

```bash
python -m scripts.train_lora \
  --input data/sft_train.jsonl \
  --model-name Qwen/Qwen2.5-7B-Instruct \
  --output-dir outputs/lora-qwen2.5-7b \
  --load-in-4bit \
  --bf16
```

训练输出目录中保存的是 LoRA adapter，不替代向量库；在线推理仍应保持“先检索，再把 `question + contexts` 喂给 base model + adapter”的链路。

MacBook（Apple Silicon）说明：

- 当前 `Unsloth` 在 Apple GPU 上不可用，脚本会自动回退到 `Transformers + PEFT`
- 在 Mac 上建议显式指定较轻模型并关闭 `--load-in-4bit`

示例：

```bash
python -m scripts.train_lora \
  --input data/sft_train.jsonl \
  --model-name Qwen/Qwen2.5-1.5B-Instruct \
  --output-dir outputs/lora-qwen2.5-1.5b-mac \
  --backend transformers \
  --fp16 \
  --batch-size 1 \
  --gradient-accumulation-steps 8
```

接入本地 LoRA 推理：

```bash
export LLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct
export LORA_ADAPTER_PATH=/Users/macmain/Documents/baby/outputs/lora-qwen2.5-0.5b-full
uvicorn api.main:app --reload
```

如果设置了 `LORA_ADAPTER_PATH`，API 会加载本地 `base model + LoRA adapter`；
如果没有设置 adapter，则退回到“仅返回检索片段”的本地回退模式。

开始制作训练数据：

```bash
python -m scripts.build_sft_annotation_set --questions data/sft_questions.example.jsonl --output data/sft_annotations.todo.jsonl --top-k 3
python -m scripts.export_training_snapshot --db-path data/training_data.sqlite3 --output data/sft_annotations.done.jsonl
python -m scripts.build_sft_dataset --input-sqlite data/training_data.sqlite3 --output data/sft_train.jsonl --format messages
```

如果使用根目录的 `yebk.pdf` 作为当前知识源，可直接使用我生成的种子问题：

```bash
python -m scripts.build_sft_annotation_set --questions data/sft_questions.yebk.jsonl --output data/sft_annotations.todo.jsonl --top-k 3
```
