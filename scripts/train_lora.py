from __future__ import annotations

import argparse
import json
from pathlib import Path

from datasets import Dataset
from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM, AutoTokenizer, set_seed
from trl import SFTConfig, SFTTrainer


DEFAULT_TARGET_MODULES = [
    "q_proj",
    "k_proj",
    "v_proj",
    "o_proj",
    "gate_proj",
    "up_proj",
    "down_proj",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a LoRA/QLoRA adapter from SFT JSONL")
    parser.add_argument(
        "--input",
        default="data/sft_train.jsonl",
        help="Path to SFT JSONL in messages format",
    )
    parser.add_argument(
        "--model-name",
        default="Qwen/Qwen2.5-7B-Instruct",
        help="Base model name or local path",
    )
    parser.add_argument(
        "--output-dir",
        default="workspace/outputs/lora-qwen2.5-7b",
        help="Directory to save LoRA adapter and tokenizer",
    )
    parser.add_argument(
        "--max-seq-length",
        type=int,
        default=2048,
        help="Maximum sequence length for training",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=2,
        help="Per-device train batch size",
    )
    parser.add_argument(
        "--gradient-accumulation-steps",
        type=int,
        default=4,
        help="Gradient accumulation steps",
    )
    parser.add_argument(
        "--learning-rate",
        type=float,
        default=2e-4,
        help="Learning rate",
    )
    parser.add_argument(
        "--num-train-epochs",
        type=float,
        default=3.0,
        help="Number of training epochs",
    )
    parser.add_argument(
        "--warmup-steps",
        type=int,
        default=10,
        help="Warmup steps",
    )
    parser.add_argument(
        "--logging-steps",
        type=int,
        default=5,
        help="Logging frequency",
    )
    parser.add_argument(
        "--save-steps",
        type=int,
        default=100,
        help="Checkpoint save frequency",
    )
    parser.add_argument(
        "--lora-r",
        type=int,
        default=16,
        help="LoRA rank",
    )
    parser.add_argument(
        "--lora-alpha",
        type=int,
        default=16,
        help="LoRA alpha",
    )
    parser.add_argument(
        "--lora-dropout",
        type=float,
        default=0.0,
        help="LoRA dropout",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed",
    )
    parser.add_argument(
        "--load-in-4bit",
        action="store_true",
        help="Load the base model in 4-bit mode for QLoRA",
    )
    parser.add_argument(
        "--bf16",
        action="store_true",
        help="Force bfloat16 training",
    )
    parser.add_argument(
        "--fp16",
        action="store_true",
        help="Force float16 training",
    )
    parser.add_argument(
        "--backend",
        choices=["auto", "unsloth", "transformers"],
        default="auto",
        help="Training backend. 'auto' tries Unsloth first, then falls back to Transformers + PEFT.",
    )
    return parser.parse_args()


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row.get("messages"), list) or len(row["messages"]) < 2:
            raise ValueError(f"Line {line_no}: expected a messages array")
        rows.append(row)
    if not rows:
        raise ValueError(f"No training samples found in {path}")
    return rows


def render_chat(tokenizer, messages: list[dict]) -> str:
    if hasattr(tokenizer, "apply_chat_template"):
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
        )

    rendered: list[str] = []
    for message in messages:
        role = str(message.get("role", "user")).upper()
        content = str(message.get("content", "")).strip()
        rendered.append(f"{role}:\n{content}")
    return "\n\n".join(rendered)


def build_dataset(rows: list[dict], tokenizer) -> Dataset:
    return Dataset.from_list(
        [
            {
                "text": render_chat(tokenizer, row["messages"]),
                "mode": row.get("mode", "grounded_answer"),
            }
            for row in rows
        ]
    )


def resolve_dtype(args: argparse.Namespace):
    if args.bf16:
        return "bfloat16"
    if args.fp16:
        return "float16"
    return None


def load_model_with_unsloth(args: argparse.Namespace):
    import unsloth
    from unsloth import FastLanguageModel

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.model_name,
        max_seq_length=args.max_seq_length,
        dtype=resolve_dtype(args),
        load_in_4bit=args.load_in_4bit,
    )
    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_r,
        target_modules=DEFAULT_TARGET_MODULES,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=args.seed,
    )
    return model, tokenizer, "unsloth"


def load_model_with_transformers(args: argparse.Namespace):
    tokenizer = AutoTokenizer.from_pretrained(args.model_name, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    torch_dtype = None
    if args.bf16:
        import torch

        torch_dtype = torch.bfloat16
    elif args.fp16:
        import torch

        torch_dtype = torch.float16

    model = AutoModelForCausalLM.from_pretrained(
        args.model_name,
        trust_remote_code=True,
        torch_dtype=torch_dtype,
    )

    peft_config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=DEFAULT_TARGET_MODULES,
    )
    model = get_peft_model(model, peft_config)
    return model, tokenizer, "transformers"


def load_model_and_tokenizer(args: argparse.Namespace):
    if args.backend == "transformers":
        return load_model_with_transformers(args)

    if args.backend in {"auto", "unsloth"}:
        try:
            return load_model_with_unsloth(args)
        except Exception as exc:
            if args.backend == "unsloth":
                raise
            print(f"Unsloth unavailable, falling back to Transformers backend: {type(exc).__name__}: {exc}")

    return load_model_with_transformers(args)


def main() -> None:
    args = parse_args()
    set_seed(args.seed)

    input_path = Path(args.input)
    if not input_path.exists():
        raise FileNotFoundError(f"Training file not found: {input_path}")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading training data from {input_path}")
    rows = read_jsonl(input_path)

    print(f"Loading base model: {args.model_name}")
    model, tokenizer, backend = load_model_and_tokenizer(args)
    print(f"Training backend: {backend}")

    dataset = build_dataset(rows, tokenizer)
    print(f"Loaded {len(dataset)} samples")

    trainer = SFTTrainer(
        model=model,
        train_dataset=dataset,
        processing_class=tokenizer,
        args=SFTConfig(
            output_dir=str(output_dir),
            per_device_train_batch_size=args.batch_size,
            gradient_accumulation_steps=args.gradient_accumulation_steps,
            learning_rate=args.learning_rate,
            num_train_epochs=args.num_train_epochs,
            warmup_steps=args.warmup_steps,
            logging_steps=args.logging_steps,
            save_steps=args.save_steps,
            seed=args.seed,
            bf16=args.bf16,
            fp16=args.fp16,
            report_to="none",
            dataset_text_field="text",
            max_length=args.max_seq_length,
        ),
    )

    trainer.train()
    trainer.save_model(str(output_dir))
    tokenizer.save_pretrained(str(output_dir))

    print(f"Saved adapter to {output_dir}")


if __name__ == "__main__":
    main()
