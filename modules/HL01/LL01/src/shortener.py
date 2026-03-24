"""HL01_LL01: Core shortening and resolution logic — stub implementation.

All methods raise NotImplementedError. Phase 3 will provide the real implementation.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class URLEntry:
    """Internal storage record for a shortened URL."""

    url: str
    clicks: int = 0
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


class URLShortener:
    """In-memory URL shortener engine.

    Implements: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07
    """

    def __init__(self) -> None:
        self._store: dict[str, URLEntry] = {}

    def shorten(self, url: str, alias: str | None = None) -> str:
        """Shorten a URL, optionally with a custom alias.

        Args:
            url: Valid URL with scheme (e.g. "https://example.com").
            alias: Optional custom short code.

        Returns:
            6-char alphanumeric code (or the alias if provided).

        Raises:
            ValueError: If url is empty, invalid, or alias already taken.
        """
        raise NotImplementedError

    def resolve(self, code: str) -> str:
        """Resolve a short code to the original URL. Increments click count.

        Args:
            code: The short code to resolve.

        Returns:
            The original URL.

        Raises:
            KeyError: If code does not exist.
        """
        raise NotImplementedError

    def stats(self, code: str) -> dict:
        """Get statistics for a short code.

        Args:
            code: The short code to query.

        Returns:
            Dict with keys: "url" (str), "clicks" (int), "created_at" (datetime).

        Raises:
            KeyError: If code does not exist.
        """
        raise NotImplementedError
