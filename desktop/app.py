from __future__ import annotations

import os
import queue
import sys
import threading
import traceback
from dataclasses import dataclass
from pathlib import Path
import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

from dotenv import load_dotenv

from rag.pipeline import RagPipeline
from scripts.build_kb import ensure_kb_current


APP_TITLE = "儿科知识问答"


@dataclass
class InitSuccess:
    project_root: Path
    kb_rebuilt: bool
    pipeline: RagPipeline


@dataclass
class AskSuccess:
    payload: dict


@dataclass
class WorkerError:
    stage: str
    message: str
    details: str


def _candidate_roots() -> list[Path]:
    script_dir = Path(__file__).resolve().parent
    executable_path = Path(sys.executable).resolve()
    cwd = Path.cwd().resolve()

    candidates: list[Path] = []
    for base in (cwd, script_dir, executable_path.parent):
        candidates.extend([base, *base.parents])

    seen: set[Path] = set()
    ordered: list[Path] = []
    for item in candidates:
        if item not in seen:
            seen.add(item)
            ordered.append(item)
    return ordered


def discover_project_root() -> Path:
    explicit_root = os.getenv("BABY_APP_PROJECT_ROOT")
    if explicit_root:
        path = Path(explicit_root).expanduser().resolve()
        if path.exists():
            return path

    required_markers = ("rag", "scripts", "requirements.txt")
    optional_markers = ("vector_db", "kb_sources", ".env")

    for candidate in _candidate_roots():
        has_required = all((candidate / marker).exists() for marker in required_markers)
        has_any_optional = any((candidate / marker).exists() for marker in optional_markers)
        if has_required and has_any_optional:
            return candidate

    raise RuntimeError(
        "无法定位项目根目录。请把 .app 放在项目目录附近运行，或设置 BABY_APP_PROJECT_ROOT。"
    )


def bootstrap_pipeline(project_root: Path) -> InitSuccess:
    os.chdir(project_root)
    load_dotenv(project_root / ".env")

    embedding_model = os.getenv("EMBEDDING_MODEL", "BAAI/bge-base-zh-v1.5")
    faiss_index_path = os.getenv("FAISS_INDEX_PATH", "vector_db/faiss.index")
    chunks_path = os.getenv("CHUNKS_PATH", "vector_db/chunks.json")
    llm_model = os.getenv("LLM_MODEL", "qwen2.5:7b-instruct")
    reranker_model = os.getenv("RERANKER_MODEL", "BAAI/bge-reranker-base")
    lora_adapter_path = os.getenv("LORA_ADAPTER_PATH", "")
    enable_reranker = os.getenv("ENABLE_RERANKER", "").strip().lower() in {"1", "true", "yes", "on"}

    kb_rebuilt = ensure_kb_current(
        source_dir=os.getenv("KB_SOURCE_DIR", "kb_sources"),
        embedding_model=embedding_model,
        faiss_index_path=faiss_index_path,
        chunks_path=chunks_path,
        manifest_path=os.getenv("KB_MANIFEST_PATH", "vector_db/source_manifest.json"),
        chunk_size=int(os.getenv("CHUNK_SIZE", "500")),
        chunk_overlap=int(os.getenv("CHUNK_OVERLAP", "100")),
        force=os.getenv("FORCE_REBUILD_KB", "").strip().lower() in {"1", "true", "yes", "on"},
    )

    pipeline = RagPipeline(
        embedding_model=embedding_model,
        faiss_index_path=faiss_index_path,
        chunks_path=chunks_path,
        llm_model=llm_model,
        reranker_model=reranker_model,
        enable_reranker=enable_reranker,
        lora_adapter_path=lora_adapter_path,
    )
    return InitSuccess(project_root=project_root, kb_rebuilt=kb_rebuilt, pipeline=pipeline)


class DesktopApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("1280x860")
        self.root.minsize(1080, 760)

        self.pipeline: RagPipeline | None = None
        self.project_root: Path | None = None
        self.init_in_progress = False
        self.ask_in_progress = False
        self.worker_queue: queue.Queue[InitSuccess | AskSuccess | WorkerError] = queue.Queue()

        self.status_var = tk.StringVar(value="正在初始化知识库与问答管线...")
        self.question_var = tk.StringVar()
        self.top_k_var = tk.IntVar(value=3)
        self.retrieve_k_var = tk.IntVar(value=9)
        self.relevance_threshold_var = tk.DoubleVar(value=0.42)

        self._build_ui()
        self._set_controls_enabled(False)
        self.root.after(150, self._process_worker_events)
        self.start_initialization()

    def _build_ui(self) -> None:
        self.root.columnconfigure(0, weight=3)
        self.root.columnconfigure(1, weight=2)
        self.root.rowconfigure(1, weight=1)

        header = ttk.Frame(self.root, padding=(18, 16, 18, 10))
        header.grid(row=0, column=0, columnspan=2, sticky="nsew")
        header.columnconfigure(0, weight=1)

        ttk.Label(header, text=APP_TITLE, font=("SF Pro Display", 24, "bold")).grid(
            row=0, column=0, sticky="w"
        )
        ttk.Label(
            header,
            text="保留现有 RAG 逻辑，直接在本地桌面窗口里完成问答。",
        ).grid(row=1, column=0, sticky="w", pady=(4, 0))
        ttk.Label(header, textvariable=self.status_var, foreground="#1f4f99").grid(
            row=2, column=0, sticky="w", pady=(10, 0)
        )

        left = ttk.Frame(self.root, padding=(18, 0, 10, 18))
        left.grid(row=1, column=0, sticky="nsew")
        left.rowconfigure(3, weight=1)
        left.columnconfigure(0, weight=1)

        right = ttk.Frame(self.root, padding=(10, 0, 18, 18))
        right.grid(row=1, column=1, sticky="nsew")
        right.rowconfigure(1, weight=1)
        right.columnconfigure(0, weight=1)

        question_frame = ttk.LabelFrame(left, text="提问区", padding=14)
        question_frame.grid(row=0, column=0, sticky="ew")
        question_frame.columnconfigure(0, weight=1)

        ttk.Label(question_frame, text="请输入问题").grid(row=0, column=0, sticky="w")
        self.question_entry = ttk.Entry(
            question_frame,
            textvariable=self.question_var,
            font=("SF Pro Text", 14),
        )
        self.question_entry.grid(row=1, column=0, sticky="ew", pady=(8, 10))
        self.question_entry.bind("<Return>", self._on_submit)

        action_bar = ttk.Frame(question_frame)
        action_bar.grid(row=2, column=0, sticky="ew")
        action_bar.columnconfigure(0, weight=1)

        self.ask_button = ttk.Button(action_bar, text="提问", command=self.submit_question)
        self.ask_button.grid(row=0, column=0, sticky="w")

        self.retry_button = ttk.Button(action_bar, text="重试初始化", command=self.start_initialization)
        self.retry_button.grid(row=0, column=1, sticky="e")

        answer_frame = ttk.LabelFrame(left, text="回答结果", padding=14)
        answer_frame.grid(row=1, column=0, sticky="nsew", pady=(14, 0))
        answer_frame.rowconfigure(1, weight=1)
        answer_frame.columnconfigure(0, weight=1)

        self.metrics_var = tk.StringVar(
            value="生成模式: -    最高相关性: -    阈值: -    是否通过: -"
        )
        ttk.Label(answer_frame, textvariable=self.metrics_var).grid(row=0, column=0, sticky="w")

        self.answer_text = ScrolledText(answer_frame, wrap="word", font=("SF Mono", 13), height=18)
        self.answer_text.grid(row=1, column=0, sticky="nsew", pady=(10, 0))
        self.answer_text.configure(state="disabled")

        error_frame = ttk.LabelFrame(left, text="错误与状态", padding=14)
        error_frame.grid(row=2, column=0, sticky="nsew", pady=(14, 0))
        error_frame.rowconfigure(0, weight=1)
        error_frame.columnconfigure(0, weight=1)

        self.error_text = ScrolledText(error_frame, wrap="word", font=("SF Mono", 12), height=8)
        self.error_text.grid(row=0, column=0, sticky="nsew")
        self.error_text.configure(state="disabled")

        control_frame = ttk.LabelFrame(right, text="参数设置", padding=14)
        control_frame.grid(row=0, column=0, sticky="ew")
        control_frame.columnconfigure(0, weight=1)

        ttk.Label(control_frame, text="检索片段数 Top-K").grid(row=0, column=0, sticky="w")
        self.top_k_scale = ttk.Scale(
            control_frame,
            from_=1,
            to=10,
            variable=self.top_k_var,
            orient="horizontal",
            command=lambda _value: self.top_k_value_var.set(str(self.top_k_var.get())),
        )
        self.top_k_scale.grid(row=1, column=0, sticky="ew", pady=(6, 0))
        self.top_k_value_var = tk.StringVar(value=str(self.top_k_var.get()))
        ttk.Label(control_frame, textvariable=self.top_k_value_var).grid(row=2, column=0, sticky="e")

        ttk.Label(control_frame, text="初召回数量 Retrieve-K").grid(row=3, column=0, sticky="w", pady=(12, 0))
        self.retrieve_k_scale = ttk.Scale(
            control_frame,
            from_=1,
            to=30,
            variable=self.retrieve_k_var,
            orient="horizontal",
            command=lambda _value: self.retrieve_k_value_var.set(str(self.retrieve_k_var.get())),
        )
        self.retrieve_k_scale.grid(row=4, column=0, sticky="ew", pady=(6, 0))
        self.retrieve_k_value_var = tk.StringVar(value=str(self.retrieve_k_var.get()))
        ttk.Label(control_frame, textvariable=self.retrieve_k_value_var).grid(row=5, column=0, sticky="e")

        ttk.Label(control_frame, text="相关性阈值").grid(row=6, column=0, sticky="w", pady=(12, 0))
        self.threshold_scale = ttk.Scale(
            control_frame,
            from_=0.0,
            to=1.0,
            variable=self.relevance_threshold_var,
            orient="horizontal",
            command=lambda _value: self.threshold_value_var.set(
                f"{self.relevance_threshold_var.get():.2f}"
            ),
        )
        self.threshold_scale.grid(row=7, column=0, sticky="ew", pady=(6, 0))
        self.threshold_value_var = tk.StringVar(value=f"{self.relevance_threshold_var.get():.2f}")
        ttk.Label(control_frame, textvariable=self.threshold_value_var).grid(row=8, column=0, sticky="e")

        contexts_frame = ttk.LabelFrame(right, text="检索片段", padding=14)
        contexts_frame.grid(row=1, column=0, sticky="nsew", pady=(14, 0))
        contexts_frame.rowconfigure(0, weight=1)
        contexts_frame.columnconfigure(0, weight=1)

        self.contexts_text = ScrolledText(contexts_frame, wrap="word", font=("SF Mono", 12), height=24)
        self.contexts_text.grid(row=0, column=0, sticky="nsew")
        self.contexts_text.configure(state="disabled")

    def _set_controls_enabled(self, enabled: bool) -> None:
        control_state = "normal" if enabled else "disabled"
        self.question_entry.configure(state=control_state)
        self.ask_button.configure(state=control_state)
        for widget in (self.top_k_scale, self.retrieve_k_scale, self.threshold_scale):
            widget.configure(state=control_state)

    def _set_retry_enabled(self, enabled: bool) -> None:
        self.retry_button.configure(state="normal" if enabled else "disabled")

    def _set_text(self, widget: ScrolledText, text: str) -> None:
        widget.configure(state="normal")
        widget.delete("1.0", tk.END)
        widget.insert("1.0", text)
        widget.configure(state="disabled")

    def _append_error(self, text: str) -> None:
        widget = self.error_text
        widget.configure(state="normal")
        if widget.index("end-1c") != "1.0":
            widget.insert(tk.END, "\n\n")
        widget.insert(tk.END, text)
        widget.see(tk.END)
        widget.configure(state="disabled")

    def _on_submit(self, _event: tk.Event[tk.Misc]) -> None:
        self.submit_question()

    def start_initialization(self) -> None:
        if self.init_in_progress:
            return

        self.pipeline = None
        self.init_in_progress = True
        self.ask_in_progress = False
        self.status_var.set("正在初始化知识库与问答管线...")
        self._set_controls_enabled(False)
        self._set_retry_enabled(False)
        self._set_text(self.answer_text, "")
        self._set_text(self.contexts_text, "")
        self.metrics_var.set("生成模式: -    最高相关性: -    阈值: -    是否通过: -")
        self._set_text(self.error_text, "")

        thread = threading.Thread(target=self._init_worker, daemon=True)
        thread.start()

    def _init_worker(self) -> None:
        try:
            project_root = discover_project_root()
            result = bootstrap_pipeline(project_root)
            self.worker_queue.put(result)
        except Exception as exc:  # pragma: no cover - UI path
            self.worker_queue.put(
                WorkerError(
                    stage="init",
                    message=str(exc),
                    details=traceback.format_exc(),
                )
            )

    def submit_question(self) -> None:
        if self.ask_in_progress or self.init_in_progress:
            return
        if self.pipeline is None:
            self._append_error("问答管线尚未完成初始化。")
            return

        question = self.question_var.get().strip()
        if not question:
            self._append_error("请输入问题后再提问。")
            return

        self.ask_in_progress = True
        self._set_controls_enabled(False)
        self._set_retry_enabled(False)
        self.status_var.set("正在检索并生成答案...")

        params = {
            "question": question,
            "top_k": int(self.top_k_var.get()),
            "retrieve_k": int(self.retrieve_k_var.get()),
            "relevance_threshold": round(float(self.relevance_threshold_var.get()), 2),
        }
        thread = threading.Thread(target=self._ask_worker, args=(params,), daemon=True)
        thread.start()

    def _ask_worker(self, params: dict) -> None:
        try:
            assert self.pipeline is not None
            payload = self.pipeline.ask(**params)
            self.worker_queue.put(AskSuccess(payload=payload))
        except Exception as exc:  # pragma: no cover - UI path
            self.worker_queue.put(
                WorkerError(
                    stage="ask",
                    message=str(exc),
                    details=traceback.format_exc(),
                )
            )

    def _process_worker_events(self) -> None:
        while True:
            try:
                item = self.worker_queue.get_nowait()
            except queue.Empty:
                break

            if isinstance(item, InitSuccess):
                self.project_root = item.project_root
                self.pipeline = item.pipeline
                self.init_in_progress = False
                self.status_var.set(
                    f"初始化完成。项目目录：{item.project_root}；知识库{'已刷新' if item.kb_rebuilt else '已复用现有索引'}。"
                )
                self._append_error("初始化完成，可以开始提问。")
                self._set_controls_enabled(True)
                self._set_retry_enabled(True)
                self.question_entry.focus_set()
            elif isinstance(item, AskSuccess):
                self.ask_in_progress = False
                self.status_var.set("问答完成。")
                self._render_payload(item.payload)
                self._set_controls_enabled(True)
                self._set_retry_enabled(True)
            else:
                assert isinstance(item, WorkerError)
                self.ask_in_progress = False
                self.init_in_progress = False
                stage_label = "初始化" if item.stage == "init" else "问答"
                self.status_var.set(f"{stage_label}失败，请查看下方错误信息。")
                self._append_error(f"{stage_label}失败：{item.message}\n\n{item.details}")
                self._set_retry_enabled(True)
                if self.pipeline is not None:
                    self._set_controls_enabled(True)

        self.root.after(150, self._process_worker_events)

    def _render_payload(self, payload: dict) -> None:
        self.metrics_var.set(
            "生成模式: {mode}    最高相关性: {score:.4f}    阈值: {threshold:.2f}    是否通过: {passed}".format(
                mode=payload.get("generation_mode", "unknown"),
                score=payload.get("best_relevance_score", 0.0),
                threshold=payload.get("relevance_threshold", 0.0),
                passed=payload.get("evidence_passed", False),
            )
        )
        self._set_text(self.answer_text, payload.get("answer", ""))

        contexts = payload.get("contexts", [])
        if not contexts:
            self._set_text(self.contexts_text, "没有可展示的检索片段。")
            return

        lines: list[str] = []
        for idx, chunk in enumerate(contexts, 1):
            lines.append(
                (
                    f"片段 {idx}\n"
                    f"source={chunk.get('source')} | page={chunk.get('page')} | chunk_id={chunk.get('chunk_id')}\n"
                    f"method={chunk.get('retrieval_method', 'dense')} | "
                    f"dense={chunk.get('dense_score', 0.0):.4f} | "
                    f"keyword={chunk.get('keyword_score', 0.0):.4f} | "
                    f"relevance={chunk.get('relevance_score', 0.0):.4f}\n\n"
                    f"{chunk.get('text', '')}"
                )
            )
        self._set_text(self.contexts_text, "\n\n" + ("\n\n" + ("-" * 72) + "\n\n").join(lines))


def main() -> None:
    root = tk.Tk()
    ttk.Style().theme_use("clam")
    DesktopApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
