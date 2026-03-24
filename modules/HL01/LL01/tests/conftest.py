"""Shared fixtures for HL01_LL01 tests."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from modules.HL01.LL01.src.shortener import URLShortener

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture()
def shortener() -> URLShortener:
    """Fresh URLShortener instance per test."""
    return URLShortener()


@pytest.fixture(scope="session")
def url_data() -> dict:
    """Parsed urls.json fixture data."""
    with open(FIXTURES_DIR / "urls.json") as f:
        return json.load(f)
