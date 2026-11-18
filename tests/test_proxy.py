"""Rate limiting behind a reverse proxy (Hugging Face Spaces, Render, ...).

Behind a proxy every request arrives from the proxy's address, so without
help all users would share one quota. ``TRUSTED_PROXIES`` tells the app how
many proxy hops to trust when reading ``X-Forwarded-For``.
"""

from __future__ import annotations

import pytest

from tests.conftest import FakeDetector


@pytest.fixture()
def make_app(tmp_path, monkeypatch):
    import coffee_leaf

    monkeypatch.setattr(coffee_leaf, "LeafDetector", FakeDetector)
    created = []

    def build(trusted_proxies: int):
        application = coffee_leaf.create_app(
            {
                "DATABASE_PATH": tmp_path / f"proxy{trusted_proxies}.sqlite3",
                "TESTING": True,
                "TRUSTED_PROXIES": trusted_proxies,
                "RATE_LIMIT_MAX": 1,
                "RATE_LIMIT_WINDOW": 60,
            }
        )
        created.append(application)
        return application.test_client()

    yield build
    for application in created:
        application.extensions["store"].close()


def _predict(client, forwarded_for: str, leaf_jpeg: bytes):
    import io

    return client.post(
        "/api/v1/predict",
        data={"file": (io.BytesIO(leaf_jpeg), "leaf.jpg")},
        content_type="multipart/form-data",
        headers={"X-Forwarded-For": forwarded_for},
    )


def test_trusted_proxy_gives_each_client_its_own_quota(make_app, leaf_jpeg):
    client = make_app(trusted_proxies=1)

    assert _predict(client, "203.0.113.1", leaf_jpeg).status_code == 200
    assert _predict(client, "203.0.113.2", leaf_jpeg).status_code == 200
    assert _predict(client, "203.0.113.1", leaf_jpeg).status_code == 429


def test_forwarded_header_is_ignored_without_a_trusted_proxy(make_app, leaf_jpeg):
    """Otherwise anyone could dodge the limit by inventing the header."""
    client = make_app(trusted_proxies=0)

    assert _predict(client, "203.0.113.1", leaf_jpeg).status_code == 200
    assert _predict(client, "203.0.113.2", leaf_jpeg).status_code == 429


def test_only_the_hops_we_trust_are_read(make_app, leaf_jpeg):
    """A client cannot prepend a fake address in front of the real one."""
    client = make_app(trusted_proxies=1)

    assert _predict(client, "198.51.100.9, 203.0.113.1", leaf_jpeg).status_code == 200
    assert _predict(client, "198.51.100.10, 203.0.113.1", leaf_jpeg).status_code == 429
