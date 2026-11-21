#!/usr/bin/env python3
"""Run the actual endpoint-audit toolkit from the repository root (Python 3.11+).

For full installation use: python -m pip install -e enterprise-endpoint-toolkit
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "enterprise-endpoint-toolkit" / "src"))
from endpoint_toolkit.cli import main

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:] or ["demo"]))
