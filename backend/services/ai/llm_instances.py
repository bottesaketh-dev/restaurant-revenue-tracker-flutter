import os
import sys
import traceback
from pathlib import Path
from typing import Dict

from dotenv import load_dotenv

# Always resolve .env relative to this file so it loads correctly
# even when the app is launched from another working directory.
_ENV_PATH = "./.env"
load_dotenv(_ENV_PATH, override=True)

# Ensure current path is in sys.path
if os.getcwd() not in sys.path:
    sys.path.append(os.getcwd())

from langchain_openai import ChatOpenAI

try:
    # GitHub Models uses a single endpoint and your GitHub PAT for all models
    GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN', 'dummy-token-to-allow-startup')
    GITHUB_ENDPOINT = "https://models.inference.ai.azure.com"

    LLM_INSTANCES = {
        "GPT_4_1": {
            "MODEL": ChatOpenAI(
                model="gpt-4.1",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "GPT_4O": {
            "MODEL": ChatOpenAI(
                model="gpt-4o",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "GPT_4O_MINI": {
            "MODEL": ChatOpenAI(
                model="gpt-4o-mini",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "LLAMA_3_1_70B": {
            "MODEL": ChatOpenAI(
                model="Meta-Llama-3.1-70B-Instruct",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "MISTRAL_LARGE": {
            "MODEL": ChatOpenAI(
                model="Mistral-large",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "MISTRAL_SMALL_3_1": {
            "MODEL": ChatOpenAI(
                # GitHub allows either the shortname or publisher/model formatting
                model="mistralai/Mistral-Small-3.1",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "COHERE_COMMAND_R": {
            "MODEL": ChatOpenAI(
                model="cohere-command-r",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
        "DEEPSEEK_R1_0528": {
            "MODEL": ChatOpenAI(
                model="DeepSeek-R1-0528",
                openai_api_key=GITHUB_TOKEN,
                openai_api_base=GITHUB_ENDPOINT,
                temperature=0,
                max_tokens=None,
                timeout=None,
                max_retries=2,
            )
        },
    }
except Exception as _exp:
    print("Exception occurred while loading LLM instances:")
    traceback.print_exc()
