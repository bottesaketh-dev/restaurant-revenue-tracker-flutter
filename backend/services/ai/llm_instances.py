import json
import logging
import os
import re
import sys
import traceback
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional

from dotenv import load_dotenv

# Always resolve .env relative to this file so it loads correctly
# even when the app is launched from another working directory.
_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
_ENV_PATH = _BACKEND_DIR / ".env"
if _ENV_PATH.exists():
    load_dotenv(_ENV_PATH, override=True)
else:
    load_dotenv("./.env", override=True)

# Ensure current path is in sys.path
if os.getcwd() not in sys.path:
    sys.path.append(os.getcwd())

from langchain_openai import ChatOpenAI

logger = logging.getLogger(__name__)

LLM_INSTANCES: Dict[str, Dict[str, Any]] = {}

# ---------------------------------------------------------
# 1. Groq Cloud Model Configurations
# ---------------------------------------------------------
try:
    GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "dummy-token-to-allow-startup")
    GROQ_ENDPOINT = "https://api.groq.com/openai/v1"

    LLM_INSTANCES["GROQ_GPT_OSS_120B"] = {
        "MODEL": ChatOpenAI(
            model="openai/gpt-oss-120b",
            openai_api_key=GROQ_API_KEY,
            openai_api_base=GROQ_ENDPOINT,
            temperature=0,
            max_tokens=None,
            timeout=None,
            max_retries=2,
        )
    }
except Exception as _exp:
    logger.warning("Exception occurred while loading Groq LLM instance: %s", _exp)
    traceback.print_exc()

# ---------------------------------------------------------
# 2. Local Ollama Model Configurations
# ---------------------------------------------------------
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", os.environ.get("OLLAMA_HOST", "http://localhost:11434"))
OLLAMA_ENDPOINT = f"{OLLAMA_BASE_URL.rstrip('/')}/v1"
OLLAMA_API_KEY = os.environ.get("OLLAMA_API_KEY", "ollama")


def create_ollama_instance(model_name: str, temperature: float = 0) -> Dict[str, Any]:
    """Helper to instantiate a local Ollama ChatOpenAI model wrapper."""
    return {
        "MODEL": ChatOpenAI(
            model=model_name,
            openai_api_key=OLLAMA_API_KEY,
            openai_api_base=OLLAMA_ENDPOINT,
            temperature=temperature,
            max_tokens=None,
            timeout=None,
            max_retries=2,
        )
    }


try:
    # Explicit mapping of local Ollama models (including canonical keys and aliases)
    LOCAL_OLLAMA_MODELS = {
        # Qwen 2.5 VL 3B
        "OLLAMA_QWEN_2_5_VL_3B": "qwen2.5vl:3b",
        "OLLAMA_QWEN2_5_VL_3B": "qwen2.5vl:3b",
        "qwen2.5vl:3b": "qwen2.5vl:3b",

        # Qwen 3.5 4B Hermes
        "OLLAMA_QWEN_3_5_4B_HERMES": "qwen3.5-4b-hermes:latest",
        "OLLAMA_QWEN3_5_4B_HERMES": "qwen3.5-4b-hermes:latest",
        "qwen3.5-4b-hermes:latest": "qwen3.5-4b-hermes:latest",
        "qwen3.5-4b-hermes": "qwen3.5-4b-hermes:latest",

        # Qwen 3.5 9B
        "OLLAMA_QWEN_3_5_9B": "qwen3.5:9b",
        "OLLAMA_QWEN3_5_9B": "qwen3.5:9b",
        "qwen3.5:9b": "qwen3.5:9b",

        # Qwen 3.5 4B
        "OLLAMA_QWEN_3_5_4B": "qwen3.5:4b",
        "OLLAMA_QWEN3_5_4B": "qwen3.5:4b",
        "qwen3.5:4b": "qwen3.5:4b",
    }

    _created_ollama_instances: Dict[str, Dict[str, Any]] = {}
    for key, model_name in LOCAL_OLLAMA_MODELS.items():
        if model_name not in _created_ollama_instances:
            _created_ollama_instances[model_name] = create_ollama_instance(model_name)
        LLM_INSTANCES[key] = _created_ollama_instances[model_name]

    # Dynamic auto-discovery: query running Ollama to register any other installed models
    try:
        req = urllib.request.Request(f"{OLLAMA_BASE_URL.rstrip('/')}/api/tags")
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            data = json.loads(resp.read().decode())
            for item in data.get("models", []):
                tag = item.get("name")
                if tag and tag not in LLM_INSTANCES:
                    sanitized = re.sub(r"[^A-Z0-9]+", "_", tag.upper()).strip("_")
                    key = f"OLLAMA_{sanitized}"
                    inst = create_ollama_instance(tag)
                    if key not in LLM_INSTANCES:
                        LLM_INSTANCES[key] = inst
                    LLM_INSTANCES[tag] = inst
    except Exception:
        # If Ollama service is not running at import time, static instances remain available
        pass

except Exception as _exp:
    logger.warning("Exception occurred while loading Ollama LLM instances: %s", _exp)
    traceback.print_exc()


def get_llm(model_key: Optional[str] = None) -> ChatOpenAI:
    """
    Retrieve an LLM instance by name/key, falling back to AI_MODEL env var or GROQ_GPT_OSS_120B.
    """
    key = model_key or os.environ.get("AI_MODEL", "GROQ_GPT_OSS_120B")
    if key in LLM_INSTANCES:
        return LLM_INSTANCES[key]["MODEL"]
    if "GROQ_GPT_OSS_120B" in LLM_INSTANCES:
        return LLM_INSTANCES["GROQ_GPT_OSS_120B"]["MODEL"]
    if LLM_INSTANCES:
        return next(iter(LLM_INSTANCES.values()))["MODEL"]
    raise ValueError(f"No LLM instance found for '{key}' and LLM_INSTANCES is empty.")

# ---------------------------------------------------------
# 2. Local Ollama Model Configurations
# ---------------------------------------------------------
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", os.environ.get("OLLAMA_HOST", "http://localhost:11434"))
OLLAMA_ENDPOINT = f"{OLLAMA_BASE_URL.rstrip('/')}/v1"
OLLAMA_API_KEY = os.environ.get("OLLAMA_API_KEY", "ollama")


def create_ollama_instance(model_name: str, temperature: float = 0) -> Dict[str, Any]:
    """Helper to instantiate a local Ollama ChatOpenAI model wrapper."""
    return {
        "MODEL": ChatOpenAI(
            model=model_name,
            openai_api_key=OLLAMA_API_KEY,
            openai_api_base=OLLAMA_ENDPOINT,
            temperature=temperature,
            max_tokens=None,
            timeout=None,
            max_retries=2,
        )
    }


try:
    # Explicit mapping of local Ollama models (including canonical keys and aliases)
    LOCAL_OLLAMA_MODELS = {
        # Qwen 2.5 VL 3B
        "OLLAMA_QWEN_2_5_VL_3B": "qwen2.5vl:3b",
        "OLLAMA_QWEN2_5_VL_3B": "qwen2.5vl:3b",
        "qwen2.5vl:3b": "qwen2.5vl:3b",

        # Qwen 3.5 4B Hermes
        "OLLAMA_QWEN_3_5_4B_HERMES": "qwen3.5-4b-hermes:latest",
        "OLLAMA_QWEN3_5_4B_HERMES": "qwen3.5-4b-hermes:latest",
        "qwen3.5-4b-hermes:latest": "qwen3.5-4b-hermes:latest",
        "qwen3.5-4b-hermes": "qwen3.5-4b-hermes:latest",

        # Qwen 3.5 9B
        "OLLAMA_QWEN_3_5_9B": "qwen3.5:9b",
        "OLLAMA_QWEN3_5_9B": "qwen3.5:9b",
        "qwen3.5:9b": "qwen3.5:9b",

        # Qwen 3.5 4B
        "OLLAMA_QWEN_3_5_4B": "qwen3.5:4b",
        "OLLAMA_QWEN3_5_4B": "qwen3.5:4b",
        "qwen3.5:4b": "qwen3.5:4b",
    }

    _created_ollama_instances: Dict[str, Dict[str, Any]] = {}
    for key, model_name in LOCAL_OLLAMA_MODELS.items():
        if model_name not in _created_ollama_instances:
            _created_ollama_instances[model_name] = create_ollama_instance(model_name)
        LLM_INSTANCES[key] = _created_ollama_instances[model_name]

    # Dynamic auto-discovery: query running Ollama to register any other installed models
    try:
        req = urllib.request.Request(f"{OLLAMA_BASE_URL.rstrip('/')}/api/tags")
        with urllib.request.urlopen(req, timeout=1.5) as resp:
            data = json.loads(resp.read().decode())
            for item in data.get("models", []):
                tag = item.get("name")
                if tag and tag not in LLM_INSTANCES:
                    sanitized = re.sub(r"[^A-Z0-9]+", "_", tag.upper()).strip("_")
                    key = f"OLLAMA_{sanitized}"
                    inst = create_ollama_instance(tag)
                    if key not in LLM_INSTANCES:
                        LLM_INSTANCES[key] = inst
                    LLM_INSTANCES[tag] = inst
    except Exception:
        # If Ollama service is not running at import time, static instances remain available
        pass

except Exception as _exp:
    logger.warning("Exception occurred while loading Ollama LLM instances: %s", _exp)
    traceback.print_exc()


def get_llm(model_key: Optional[str] = None) -> ChatOpenAI:
    """
    Retrieve an LLM instance by name/key, falling back to AI_MODEL env var or GROQ_GPT_OSS_120B.
    """
    key = model_key or os.environ.get("AI_MODEL", "GROQ_GPT_OSS_120B")
    if key in LLM_INSTANCES:
        return LLM_INSTANCES[key]["MODEL"]
    if "GROQ_GPT_OSS_120B" in LLM_INSTANCES:
        return LLM_INSTANCES["GROQ_GPT_OSS_120B"]["MODEL"]
    if LLM_INSTANCES:
        return next(iter(LLM_INSTANCES.values()))["MODEL"]
    raise ValueError(f"No LLM instance found for '{key}' and LLM_INSTANCES is empty.")

