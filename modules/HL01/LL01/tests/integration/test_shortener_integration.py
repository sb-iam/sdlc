"""Integration tests for HL01_LL01: Core shortening and resolution logic."""

from __future__ import annotations

from datetime import datetime

import pytest

from modules.HL01.LL01.src.shortener import URLShortener


# ---------------------------------------------------------------------------
# 3.1 Full lifecycle — Covers: AC-01, AC-02, AC-03, AC-04
# ---------------------------------------------------------------------------


class TestFullLifecycle:
    """End-to-end shorten → resolve → stats workflow."""

    def test_full_lifecycle_shorten_resolve_stats(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-01, AC-02, AC-03, AC-04
        url = "https://example.com/lifecycle"

        # Shorten — AC-01
        code = shortener.shorten(url)
        assert len(code) == 6
        assert code.isalnum()

        # Resolve 5 times — AC-02, AC-03
        for _ in range(5):
            assert shortener.resolve(code) == url

        # Stats — AC-04
        result = shortener.stats(code)
        assert result["url"] == url
        assert result["clicks"] == 5
        assert isinstance(result["created_at"], datetime)


# ---------------------------------------------------------------------------
# 3.2 Mixed aliases and generated codes — Covers: AC-01, AC-02, AC-08
# ---------------------------------------------------------------------------


class TestMixedAliasAndGenerated:
    """Tests combining custom aliases with auto-generated codes."""

    def test_mixed_alias_and_generated(self, shortener: URLShortener) -> None:
        # Covers: AC-01, AC-02, AC-08
        url_alias = "https://example.com/aliased"
        url_generated = "https://example.com/generated"

        # Shorten with alias — AC-08
        alias_code = shortener.shorten(url_alias, alias="mylink")
        assert alias_code == "mylink"

        # Shorten without alias — AC-01
        gen_code = shortener.shorten(url_generated)
        assert len(gen_code) == 6
        assert gen_code.isalnum()

        # Resolve both — AC-02
        assert shortener.resolve("mylink") == url_alias
        assert shortener.resolve(gen_code) == url_generated


# ---------------------------------------------------------------------------
# 3.3 Error paths interleaved — Covers: AC-05, AC-06, AC-07, AC-09
# ---------------------------------------------------------------------------


class TestErrorPathsIntegration:
    """Error paths do not corrupt valid store state."""

    def test_error_paths_do_not_corrupt_state(
        self, shortener: URLShortener
    ) -> None:
        # Covers: AC-05, AC-06, AC-07, AC-09
        url = "https://example.com/valid"
        code = shortener.shorten(url)

        # AC-05: empty string raises ValueError
        with pytest.raises(ValueError):
            shortener.shorten("")

        # AC-06: no-scheme raises ValueError
        with pytest.raises(ValueError):
            shortener.shorten("not-a-url")

        # Valid resolve still works after errors
        assert shortener.resolve(code) == url

        # AC-07: nonexistent code raises KeyError
        with pytest.raises(KeyError):
            shortener.resolve("nonexistent")

        # AC-09: alias collision raises ValueError
        shortener.shorten("https://example.com/other", alias="taken")
        with pytest.raises(ValueError):
            shortener.shorten("https://example.com/another", alias="taken")

        # Valid resolve still works after all error paths
        assert shortener.resolve(code) == url


# ---------------------------------------------------------------------------
# 3.4 Bulk operations — Covers: AC-01, AC-02
# ---------------------------------------------------------------------------


class TestBulkOperations:
    """Bulk shorten and resolve from fixture data."""

    def test_bulk_shorten_and_resolve(
        self, shortener: URLShortener, url_data: dict
    ) -> None:
        # Covers: AC-01, AC-02
        bulk_urls = url_data["bulk_urls"]
        assert len(bulk_urls) == 100

        codes = []
        for url in bulk_urls:
            code = shortener.shorten(url)
            assert len(code) == 6
            assert code.isalnum()
            codes.append(code)

        # All codes unique — AC-01
        assert len(set(codes)) == 100

        # All resolve correctly — AC-02
        for url, code in zip(bulk_urls, codes):
            assert shortener.resolve(code) == url
