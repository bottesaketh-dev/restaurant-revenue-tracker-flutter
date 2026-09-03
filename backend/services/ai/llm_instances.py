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
    GROQ_API_KEY = os.environ.get('GROQ_API_KEY', 'dummy-token-to-allow-startup')
    GROQ_ENDPOINT = "https://api.groq.com/openai/v1"

    LLM_INSTANCES = {
        "GROQ_GPT_OSS_120B": {
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
    }
except Exception as _exp:
    print("Exception occurred while loading LLM instances:")
    traceback.print_exc()
