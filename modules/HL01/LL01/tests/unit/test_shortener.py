"""Unit tests for HL01_LL01: Core shortening and resolution logic."""

from __future__ import annotations

from datetime import datetime

import pytest

from modules.HL01.LL01.src.shortener import URLShortener


# ---------------------------------------------------------------------------
# 2.1 Code generation — Covers: AC-01
# ---------------------------------------------------------------------------


class TestShortenCodeGeneration:
    """Tests for 6-char alphanumeric code generation."""

    def test_shorten_returns_6_char_code(self, shortener: URLShortener) -> None:
        # Covers: AC-01
        code = shortener.shorten("https://example.com")
        assert len(code) == 6

    def test_shorten_code_is_alphanumeric(self, shortener: URLShortener) -> None:
        # Covers: AC-01
        code = shortener.shorten("https://example.com")
        assert code.isalnum()

    def test_shorten_different_urls_different_codes(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-01
        code1 = shortener.shorten("https://example.com/a")
        code2 = shortener.shorten("https://example.com/b")
        assert code1 != code2


# ---------------------------------------------------------------------------
# 2.2 Resolution — Covers: AC-02
# ---------------------------------------------------------------------------


class TestResolve:
    """Tests for resolving short codes back to original URLs."""

    def test_resolve_returns_original_url(self, shortener: URLShortener) -> None:
        # Covers: AC-02
        url = "https://example.com"
        code = shortener.shorten(url)
        assert shortener.resolve(code) == url

    def test_resolve_multiple_urls(self, shortener: URLShortener) -> None:
        # Covers: AC-02
        urls = [
            "https://example.com/one",
            "https://example.com/two",
            "https://example.com/three",
        ]
        codes = [shortener.shorten(u) for u in urls]
        for url, code in zip(urls, codes):
            assert shortener.resolve(code) == url


# ---------------------------------------------------------------------------
# 2.3 Click tracking — Covers: AC-03
# ---------------------------------------------------------------------------


class TestClickTracking:
    """Tests for click count tracking on resolve."""

    def test_resolve_increments_click_count(self, shortener: URLShortener) -> None:
        # Covers: AC-03
        code = shortener.shorten("https://example.com")
        shortener.resolve(code)
        shortener.resolve(code)
        shortener.resolve(code)
        assert shortener.stats(code)["clicks"] == 3

    def test_click_count_starts_at_zero(self, shortener: URLShortener) -> None:
        # Covers: AC-03
        code = shortener.shorten("https://example.com")
        assert shortener.stats(code)["clicks"] == 0


# ---------------------------------------------------------------------------
# 2.4 Stats — Covers: AC-04
# ---------------------------------------------------------------------------


class TestStats:
    """Tests for stats() return value."""

    def test_stats_returns_required_keys(self, shortener: URLShortener) -> None:
        # Covers: AC-04
        code = shortener.shorten("https://example.com")
        result = shortener.stats(code)
        assert "url" in result
        assert "clicks" in result
        assert "created_at" in result

    def test_stats_url_matches_original(self, shortener: URLShortener) -> None:
        # Covers: AC-04
        url = "https://example.com"
        code = shortener.shorten(url)
        assert shortener.stats(code)["url"] == url

    def test_stats_created_at_is_datetime(self, shortener: URLShortener) -> None:
        # Covers: AC-04
        code = shortener.shorten("https://example.com")
        assert isinstance(shortener.stats(code)["created_at"], datetime)


# ---------------------------------------------------------------------------
# 2.5 Invalid URL rejection — Covers: AC-05, AC-06
# ---------------------------------------------------------------------------


class TestInvalidURLRejection:
    """Tests for ValueError on invalid URLs."""

    def test_shorten_empty_string_raises_valueerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-05
        with pytest.raises(ValueError):
            shortener.shorten("")

    def test_shorten_no_scheme_raises_valueerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-06
        with pytest.raises(ValueError):
            shortener.shorten("not-a-url")

    def test_shorten_missing_netloc_raises_valueerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-06
        with pytest.raises(ValueError):
            shortener.shorten("http://")


# ---------------------------------------------------------------------------
# 2.6 Non-existent code rejection — Covers: AC-07
# ---------------------------------------------------------------------------


class TestNonExistentCode:
    """Tests for KeyError on non-existent codes."""

    def test_resolve_nonexistent_raises_keyerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-07
        with pytest.raises(KeyError):
            shortener.resolve("nonexistent")

    def test_stats_nonexistent_raises_keyerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-07
        with pytest.raises(KeyError):
            shortener.stats("nonexistent")


# ---------------------------------------------------------------------------
# 2.7 Custom aliases — Covers: AC-08
# ---------------------------------------------------------------------------


class TestCustomAliases:
    """Tests for custom alias support."""

    def test_shorten_with_alias(self, shortener: URLShortener) -> None:
        # Covers: AC-08
        code = shortener.shorten("https://example.com", alias="myalias")
        assert code == "myalias"

    def test_resolve_custom_alias(self, shortener: URLShortener) -> None:
        # Covers: AC-08
        url = "https://example.com"
        shortener.shorten(url, alias="custom")
        assert shortener.resolve("custom") == url


# ---------------------------------------------------------------------------
# 2.8 Alias collision — Covers: AC-09
# ---------------------------------------------------------------------------


class TestAliasCollision:
    """Tests for alias collision detection."""

    def test_shorten_alias_collision_raises_valueerror(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-09
        shortener.shorten("https://example.com/first", alias="taken")
        with pytest.raises(ValueError):
            shortener.shorten("https://example.com/second", alias="taken")
