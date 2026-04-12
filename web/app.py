from __future__ import annotations

import os

import requests
import streamlit as st
from dotenv import load_dotenv

load_dotenv()

default_api_port = os.getenv("BABY_APP_API_PORT", "8765").strip() or "8765"
API_BASE = os.getenv("API_BASE", f"http://127.0.0.1:{default_api_port}")


def fetch_generation_mode() -> str:
    try:
        resp = requests.get(f"{API_BASE}/health", timeout=10)
        if resp.ok:
            return resp.json().get("generation_mode", "unknown")
    except requests.RequestException:
        pass
    return "unknown"

st.set_page_config(page_title="Pediatrics RAG", page_icon="👶", layout="wide")
st.markdown(
    """
    <style>
    :root {
        --bg-panel: linear-gradient(180deg, rgba(18, 24, 38, 0.96), rgba(12, 17, 28, 0.98));
        --bg-soft: rgba(24, 31, 48, 0.82);
        --border-soft: rgba(130, 146, 178, 0.22);
        --border-strong: rgba(255, 106, 106, 0.28);
        --accent: #ff6a6a;
        --text-dim: #9aa4b2;
    }

    .stApp {
        background:
            radial-gradient(circle at top left, rgba(255, 106, 106, 0.08), transparent 28%),
            radial-gradient(circle at top right, rgba(66, 153, 225, 0.08), transparent 24%),
            #0b0f17;
    }

    .block-container {
        max-width: 1380px;
        padding-top: 2.2rem;
        padding-bottom: 2.5rem;
    }

    .app-shell {
        margin-top: 0.5rem;
    }

    .panel-card,
    .answer-card,
    .question-card {
        background: var(--bg-panel);
        border: 1px solid var(--border-soft);
        border-radius: 24px;
        padding: 1.25rem 1.25rem 1.1rem 1.25rem;
        box-shadow: 0 24px 60px rgba(0, 0, 0, 0.24);
        backdrop-filter: blur(12px);
    }

    .panel-card {
        position: sticky;
        top: 1rem;
        border-color: var(--border-strong);
    }

    .question-card {
        margin-bottom: 1rem;
    }

    .answer-card {
        margin-top: 1rem;
        border-color: rgba(96, 165, 250, 0.22);
    }

    .card-kicker {
        display: inline-block;
        margin-bottom: 0.55rem;
        padding: 0.22rem 0.6rem;
        border-radius: 999px;
        background: rgba(255, 106, 106, 0.12);
        border: 1px solid rgba(255, 106, 106, 0.22);
        color: #ff9b9b;
        font-size: 0.76rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .answer-card .card-kicker {
        background: rgba(96, 165, 250, 0.12);
        border-color: rgba(96, 165, 250, 0.24);
        color: #8fc4ff;
    }

    .panel-card h3,
    .question-card h3,
    .answer-card h3 {
        margin: 0;
        font-size: 1.15rem;
        font-weight: 700;
    }

    .card-note {
        margin: 0.45rem 0 0.2rem 0;
        color: var(--text-dim);
        font-size: 0.95rem;
        line-height: 1.55;
    }

    .answer-body {
        margin-top: 0.5rem;
        padding: 1rem 1.05rem;
        border-radius: 18px;
        background: var(--bg-soft);
        border: 1px solid rgba(130, 146, 178, 0.16);
        line-height: 1.8;
    }

    .metrics-strip {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
        margin: 0.85rem 0 0.25rem;
    }

    .metric-chip {
        padding: 0.55rem 0.8rem;
        border-radius: 14px;
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(130, 146, 178, 0.18);
        font-size: 0.9rem;
    }

    .metric-chip strong {
        display: block;
        margin-bottom: 0.18rem;
        color: #d7dee8;
        font-size: 0.78rem;
        font-weight: 600;
    }

    div[data-testid="stForm"] {
        border: 0;
        padding: 0;
        background: transparent;
    }

    div[data-testid="stTextInput"] label,
    div[data-testid="stSlider"] label {
        font-weight: 600;
    }

    div[data-testid="stExpander"] {
        border-radius: 18px;
        overflow: hidden;
        border: 1px solid rgba(130, 146, 178, 0.16);
    }

    button[kind="formSubmit"] {
        border-radius: 14px;
        border: 1px solid rgba(255, 106, 106, 0.35);
        background: linear-gradient(135deg, #ff6a6a, #ff875f);
        color: white;
        font-weight: 700;
        padding: 0.1rem 1.2rem;
        box-shadow: 0 12px 32px rgba(255, 106, 106, 0.22);
    }
    </style>
    """,
    unsafe_allow_html=True,
)
st.title("儿科知识问答（RAG）")
st.caption("数据源：《美国儿科协会育儿百科》")
st.info(f"当前生成模式：`{fetch_generation_mode()}`")
st.caption("仅适用于儿童健康、喂养、护理等问题；天气、新闻、股票等实时信息不在当前知识库范围内。")

if "last_payload" not in st.session_state:
    st.session_state.last_payload = None

if "last_error" not in st.session_state:
    st.session_state.last_error = None

st.markdown('<div class="app-shell">', unsafe_allow_html=True)
main_col, side_col = st.columns([1.8, 1], gap="large")

with side_col:
    st.markdown(
        """
        <div class="panel-card">
            <div class="card-kicker">Control Panel</div>
            <h3>参数设置</h3>
            <p class="card-note">把检索范围、召回强度和放行阈值集中放在这里，便于边试边调。</p>
        """,
        unsafe_allow_html=True,
    )
    top_k = st.slider("检索片段数 Top-K", min_value=1, max_value=10, value=3)
    st.caption("越大：最终展示并用于回答的片段越多，信息更全，但也更容易混入噪声。")
    retrieve_k = st.slider("初召回数量 Retrieve-K", min_value=1, max_value=30, value=9)
    st.caption("越大：先召回的候选片段越多，可能提高命中率，但速度更慢，也可能带来更多无关片段。")
    relevance_threshold = st.slider("相关性阈值", min_value=0.0, max_value=1.0, value=0.42, step=0.01)
    st.caption("越大：系统越严格，只有相关性更高的问题才会回答；越小：更容易放行，但误答风险更高。")
    st.markdown("</div>", unsafe_allow_html=True)

with main_col:
    st.markdown(
        """
        <div class="question-card">
            <div class="card-kicker">Ask</div>
            <h3>提问区</h3>
            <p class="card-note">问题输入、触发操作和回答结果保持在同一条工作流里，减少视线来回跳转。</p>
        """,
        unsafe_allow_html=True,
    )
    with st.form("ask_form", clear_on_submit=False):
        question = st.text_input("请输入问题", placeholder="例如：宝宝几个月可以吃辅食？")
        submitted = st.form_submit_button("提问", use_container_width=False)
    st.markdown("</div>", unsafe_allow_html=True)

    if submitted:
        if question.strip():
            st.session_state.last_error = None
            try:
                with st.spinner("正在检索并生成答案..."):
                    resp = requests.get(
                        f"{API_BASE}/ask",
                        params={
                            "question": question.strip(),
                            "top_k": top_k,
                            "retrieve_k": retrieve_k,
                            "relevance_threshold": relevance_threshold,
                        },
                        timeout=120,
                    )
            except requests.RequestException as exc:
                st.session_state.last_payload = None
                st.session_state.last_error = f"无法连接后端服务：{exc}"
            else:
                if resp.ok:
                    st.session_state.last_payload = resp.json()
                    st.session_state.last_error = None
                else:
                    st.session_state.last_payload = None
                    st.session_state.last_error = f"请求失败：{resp.status_code} {resp.text}"
        else:
            st.session_state.last_payload = None
            st.session_state.last_error = "请输入问题后再提问。"

    if st.session_state.last_error:
        st.error(st.session_state.last_error)

    payload = st.session_state.last_payload
    if payload:
        st.markdown(
            """
            <div class="answer-card">
                <div class="card-kicker">Answer</div>
                <h3>回答结果</h3>
                <p class="card-note">把最终结论放在视觉中心，相关模式和通过状态作为辅助信息贴在上方。</p>
            """,
            unsafe_allow_html=True,
        )
        st.markdown(
            (
                '<div class="metrics-strip">'
                f'<div class="metric-chip"><strong>生成模式</strong>{payload.get("generation_mode", "unknown")}</div>'
                f'<div class="metric-chip"><strong>最高相关性</strong>{payload.get("best_relevance_score", 0.0):.4f}</div>'
                f'<div class="metric-chip"><strong>阈值</strong>{payload.get("relevance_threshold", relevance_threshold):.2f}</div>'
                f'<div class="metric-chip"><strong>是否通过</strong>{payload.get("evidence_passed", False)}</div>'
                "</div>"
            ),
            unsafe_allow_html=True,
        )
        st.markdown('<div class="answer-body">', unsafe_allow_html=True)
        st.write(payload.get("answer", ""))
        st.markdown("</div>", unsafe_allow_html=True)

        contexts = payload.get("contexts", [])
        if contexts:
            with st.expander("检索片段", expanded=False):
                for i, chunk in enumerate(contexts, 1):
                    st.markdown(
                        f"**片段 {i}** "
                        f"(source={chunk.get('source')}, page={chunk.get('page')}, "
                        f"chunk_id={chunk.get('chunk_id')}, "
                        f"method={chunk.get('retrieval_method', 'dense')}, "
                        f"dense={chunk.get('dense_score', 0):.4f}, "
                        f"keyword={chunk.get('keyword_score', 0):.4f}, "
                        f"relevance={chunk.get('relevance_score', 0):.4f})"
                    )
                    st.write(chunk.get("text", ""))
        st.markdown("</div>", unsafe_allow_html=True)

st.markdown("</div>", unsafe_allow_html=True)
