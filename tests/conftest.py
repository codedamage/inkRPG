import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pytest

from env import Env, PLUGIN_DIR, REPO_ROOT

__all__ = ["PLUGIN_DIR", "REPO_ROOT"]


@pytest.fixture
def env():
    """A fresh, isolated Lua runtime for a single test -- see env.py."""
    return Env()
