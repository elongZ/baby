# Training Strategy

## Goal

This project uses RAG to supply external knowledge and LoRA/QLoRA to stabilize answer behavior.
The fine-tuning target is not to memorize pediatric knowledge. The target is to improve:

1. Answer format consistency
2. Citation formatting
3. Refusal behavior when evidence is insufficient
4. Risk reminder consistency for sensitive questions

## Engineering Choice

For local training on a single RTX 4080, the preferred implementation is:

1. `Unsloth`
2. Base model: `Qwen2.5-7B-Instruct` or `Qwen3-8B`
3. Training method: `QLoRA` with 4-bit loading

Reason:

1. Lower VRAM usage
2. Faster iteration on a single GPU
3. Less setup overhead than a fully manual Hugging Face stack

## Explanation Choice

For interviews and technical writeups, explain the training pipeline as a standard QLoRA stack:

1. `transformers` loads the base model and tokenizer
2. `bitsandbytes` loads the frozen base model in 4-bit
3. `peft` injects LoRA adapters into target linear layers
4. `trl` or `Trainer` runs supervised fine-tuning
5. `accelerate` manages single-GPU execution

This is the conceptual pipeline even if the actual implementation uses `Unsloth`.

## Training Data Contract

Each sample should teach answer behavior instead of domain memorization.

Canonical storage now lives in a local SQLite database at `data/training_data.sqlite3`.
The database is the source of truth for annotation and LoRA preparation workflows.

Required logical fields per sample:

1. `question`
2. `contexts`
3. `answer`

Optional but recommended logical field:

1. `mode`

Supported `mode` values in this repo:

1. `grounded_answer`: answer directly from evidence
2. `insufficient_evidence`: refuse clearly when evidence is not enough
3. `risk_routing`: answer conservatively and add a safety routing note

Recommended answer format:

1. `Conclusion: ...`
2. `Evidence: ...`
3. `Citations: [1][2]`
4. `Risk note: ...`

If the evidence is insufficient, the answer should refuse clearly instead of guessing.

## Architecture Boundary

Online inference should remain:

1. Retrieve relevant contexts from the vector index
2. Send `question + contexts` to the generator
3. Generate the final answer with `base model + LoRA adapter`

The system should not rely on fine-tuning to store pediatric knowledge.
Knowledge should remain in the retrieval layer.

## What To Say In Interviews

Use this line consistently:

`RAG provides external knowledge, while LoRA aligns the model's answering behavior.`

More detailed explanation:

1. RAG solves factual grounding and source traceability
2. LoRA improves response structure, citation stability, and refusal behavior
3. QLoRA makes single-GPU fine-tuning feasible by freezing the base model and training only low-rank adapters on top of 4-bit weights

## Storage Layers

Use three layers with different responsibilities:

1. `data/training_data.sqlite3`
   This is the annotation source of truth.
   The mac app edits this database directly.

2. `data/sft_annotations.done.jsonl`
   This is an exported snapshot for inspection, backup, or external exchange.
   It is derived from SQLite and is no longer the primary editable store.

3. `data/sft_train.jsonl`
   This is the machine-ready SFT artifact generated from SQLite samples.

Rule:

1. Edit SQLite
2. Export snapshot only when needed
3. Regenerate `train` from SQLite
4. Do not treat `done` or `train` as the canonical source of truth

## Next Steps

1. Build a manual annotation set from seed questions and retrieved contexts
2. Fill in high-quality target answers by hand inside the mac app
3. Generate `sft_train.jsonl` from SQLite
4. Add a local training script using `Unsloth`
5. Add answer-quality evaluation before and after fine-tuning

## Practical Workflow In This Repo

1. Prepare seed questions in `data/sft_questions.example.jsonl`
2. Build a todo annotation set:

```bash
python -m scripts.build_sft_annotation_set --questions data/sft_questions.example.jsonl --output data/sft_annotations.todo.jsonl --top-k 3
```

3. Import the todo set into `data/training_data.sqlite3` if needed, or edit samples directly in the mac app.

4. Export a JSONL snapshot when you want a flat-file checkpoint:

```bash
python -m scripts.export_training_snapshot --db-path data/training_data.sqlite3 --output data/sft_annotations.done.jsonl
```

5. Convert SQLite annotations to training format:

```bash
python -m scripts.build_sft_dataset --input-sqlite data/training_data.sqlite3 --output data/sft_train.jsonl --format messages
```

## File Roles

Keep both files. They have different purposes:

1. `data/training_data.sqlite3`
   This is the human-maintained source database.
   It keeps `sample_id`, `question`, `mode`, `annotation_guideline`, `contexts`, `answer`, `annotation_notes`, and sample lifecycle fields.

2. `data/sft_annotations.done.jsonl`
   This is the exported snapshot view of completed annotations.

3. `data/sft_train.jsonl`
   This is the machine-ready training artifact.
   It is generated from SQLite and should be used directly by SFT / Unsloth training code.