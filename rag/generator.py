"""回答生成层。

本模块负责把检索到的上下文整理成提示词，并在可用时调用本地 LoRA 模型生成结构化回答。
如果本地生成条件不满足，则退回到上下文展示模式，避免在无模型时伪造答案。
"""

from __future__ import annotations

import os
import re


class AnswerGenerator:
    """基于上下文片段生成最终回答。"""

    def __init__(
        self,
        model: str,
        adapter_path: str | None = None,
    ) -> None:
        self.model = model
        self.adapter_path = adapter_path or os.getenv("LORA_ADAPTER_PATH", "")
        self._local_tokenizer = None
        self._local_model = None
        self._device = None

    def mode_label(self) -> str:
        if self.adapter_path:
            return "local_lora"
        return "context_fallback"

    def _get_local_components(self):
        if self._local_model is not None and self._local_tokenizer is not None:
            return self._local_model, self._local_tokenizer, self._device

        import torch
        from peft import PeftModel
        from transformers import AutoModelForCausalLM, AutoTokenizer

        if torch.backends.mps.is_available():
            device = "mps"
            torch_dtype = torch.float16
        else:
            device = "cpu"
            torch_dtype = torch.float32

        tokenizer = AutoTokenizer.from_pretrained(self.model, trust_remote_code=True)
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token

        base_model = AutoModelForCausalLM.from_pretrained(
            self.model,
            trust_remote_code=True,
            torch_dtype=torch_dtype,
        )
        model = PeftModel.from_pretrained(base_model, self.adapter_path)
        model.to(device)
        model.eval()

        self._local_model = model
        self._local_tokenizer = tokenizer
        self._device = device
        return model, tokenizer, device

    @staticmethod
    def _build_prompt(question: str, contexts: list[dict]) -> str:
        context_block = "\n\n".join(
            (
                f"[片段{i + 1}] "
                f"(chunk_id={c.get('chunk_id')}, source={c.get('source')}, page={c.get('page')})\n"
                f"{c.get('text', '')}"
            )
            for i, c in enumerate(contexts)
        )
        return (
            "你是儿童健康知识助手。请严格基于给定资料回答。\n"
            "如果资料不足，明确说“资料不足”。不要编造。\n\n"
            f"资料：\n{context_block}\n\n"
            f"问题：{question}\n\n"
            "请用中文输出，并严格按下面格式：\n"
            "结论：...\n"
            "依据：...\n"
            "引用：[1][2]\n"
            "提醒：..."
        )

    @staticmethod
    def _normalize_local_answer(answer: str) -> str:
        text = answer.strip()
        if not text:
            return "资料不足。"

        replacements = {
            "Conclusion:": "结论：",
            "Evidence:": "依据：",
            "Citations:": "引用：",
            "Risk note:": "提醒：",
            "Conclusion：": "结论：",
            "Evidence：": "依据：",
            "Citations：": "引用：",
            "Risk note：": "提醒：",
        }
        for source, target in replacements.items():
            text = text.replace(source, target)

        # If the model returned a dense paragraph, wrap it into a readable structure.
        if not any(marker in text for marker in ("结论：", "依据：", "引用：", "提醒：")):
            return f"结论：\n{text}"

        patterns = [
            ("结论：", r"结论[:：]\s*"),
            ("依据：", r"依据[:：]\s*"),
            ("引用：", r"引用[:：]\s*"),
            ("提醒：", r"提醒[:：]\s*"),
        ]

        extracted: dict[str, str] = {}
        for idx, (label, pattern) in enumerate(patterns):
            start_match = re.search(pattern, text)
            if not start_match:
                continue
            start = start_match.end()
            end = len(text)
            for _, next_pattern in patterns[idx + 1 :]:
                next_match = re.search(next_pattern, text[start:])
                if next_match:
                    end = start + next_match.start()
                    break
            extracted[label] = text[start:end].strip()

        ordered_sections = []
        for label, _ in patterns:
            value = extracted.get(label)
            if value:
                ordered_sections.append(f"{label}\n{value}")

        if ordered_sections:
            return "\n\n".join(ordered_sections)

        return text

    def generate(self, question: str, contexts: list[dict]) -> str:
        """根据问题与上下文生成中文回答。

        Args:
            question: 用户问题。
            contexts: 检索与重排后的参考片段列表。

        Returns:
            本地模型生成的结构化回答，或回退模式下的上下文摘要文本。
        """

        if not contexts:
            return "未在资料中检索到相关内容，请换一种问法或补充上下文。"

        prompt = self._build_prompt(question=question, contexts=contexts)

        if self.adapter_path:
            import torch

            model, tokenizer, device = self._get_local_components()
            messages = [{"role": "user", "content": prompt}]
            rendered_prompt = tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=True,
            )
            model_inputs = tokenizer(rendered_prompt, return_tensors="pt")
            if hasattr(model_inputs, "to"):
                model_inputs = model_inputs.to(device)

            input_ids = model_inputs["input_ids"]
            attention_mask = model_inputs.get("attention_mask")
            if attention_mask is None:
                attention_mask = torch.ones_like(input_ids)
            with torch.no_grad():
                output_ids = model.generate(
                    input_ids=input_ids,
                    attention_mask=attention_mask,
                    max_new_tokens=512,
                    temperature=0.2,
                    do_sample=True,
                    pad_token_id=tokenizer.pad_token_id,
                    eos_token_id=tokenizer.eos_token_id,
                )

            generated_ids = output_ids[0][input_ids.shape[-1] :]
            decoded = tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
            return self._normalize_local_answer(decoded)

        return (
            "【本地回退模式：未配置 LLM 接口】\n"
            f"问题：{question}\n\n"
            "可参考资料：\n"
            + "\n\n".join(
                (
                    f"[片段{i + 1}] "
                    f"(chunk_id={c.get('chunk_id')}, source={c.get('source')}, page={c.get('page')})\n"
                    f"{c.get('text', '')}"
                )
                for i, c in enumerate(contexts)
            )
        )
