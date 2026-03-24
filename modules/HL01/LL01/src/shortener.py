"""HL01_LL01: Core shortening and resolution logic."""

from __future__ import annotations

import secrets
import string
from dataclasses import dataclass, field
from datetime import datetime, timezone
from urllib.parse import urlparse


CODE_LENGTH: int = 6
CODE_ALPHABET: str = string.ascii_letters + string.digits
CODE_SPACE: int = len(CODE_ALPHABET) ** CODE_LENGTH


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
        self._validate_url(url)
        if alias is not None:
            if alias in self._store:
                raise ValueError(f"alias '{alias}' is already taken")
            code = alias
        else:
            code = self._generate_code()
        self._store[code] = URLEntry(url=url)
        return code

    def resolve(self, code: str) -> str:
        """Resolve a short code to the original URL. Increments click count.

        Args:
            code: The short code to resolve.

        Returns:
            The original URL.

        Raises:
            KeyError: If code does not exist.
        """
        if code not in self._store:
            raise KeyError(code)
        self._store[code].clicks += 1
        return self._store[code].url

    def stats(self, code: str) -> dict:
        """Get statistics for a short code.

        Args:
            code: The short code to query.

        Returns:
            Dict with keys: "url" (str), "clicks" (int), "created_at" (datetime).

        Raises:
            KeyError: If code does not exist.
        """
        if code not in self._store:
            raise KeyError(code)
        entry = self._store[code]
        return {
            "url": entry.url,
            "clicks": entry.clicks,
            "created_at": entry.created_at,
        }

    def _validate_url(self, url: str) -> None:
        """Validate that url has a scheme and netloc.

        Raises:
            ValueError: If url is empty or missing scheme/netloc.
        """
        if not url:
            raise ValueError("url must not be empty")
        parsed = urlparse(url)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError(f"invalid url: {url!r}")

    def _generate_code(self) -> str:
        """Generate a unique 6-char alphanumeric code.

        Raises:
            ValueError: If the entire code space is exhausted.
        """
        if len(self._store) >= CODE_SPACE:
            raise ValueError("code space exhausted — no unique code found")
        while True:
            code = "".join(
                secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH)
            )
            if code not in self._store:
                return code
