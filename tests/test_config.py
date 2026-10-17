"""Consistency checks on the configuration and knowledge base.

These guard the invariants that the UI and the API rely on: every class the
model predicts must have a display label, a knowledge-base entry and a
sample photograph.
"""

from __future__ import annotations

from coffee_leaf import config


def test_every_class_has_a_display_label_and_knowledge_entry():
    assert set(config.CLASS_LABELS) == set(config.DISEASE_INFO)


def test_every_class_has_a_sample_photograph():
    assert set(config.SAMPLES) == set(config.CLASS_LABELS)
    for relative in config.SAMPLES.values():
        assert (config.BASE_DIR / "static" / relative).is_file(), relative


def test_knowledge_base_entries_are_complete_and_consistent():
    valid_severities = {"high", "moderate", "none"}
    for key, info in config.DISEASE_INFO.items():
        assert info["severity"] in valid_severities, key
        assert info["label"] == config.CLASS_LABELS[key], key
        assert info["pathogen"]
        assert len(info["summary"]) > 40, key
        assert len(info["symptoms"]) >= 2, key
        assert len(info["treatment"]) >= 3, key


def test_reported_metrics_stay_in_range():
    for name, value in config.MODEL_METRICS.items():
        assert 0 < value <= 100, name


def test_paths_resolve_inside_the_repository():
    assert config.MODELS_DIR.is_dir()
    assert config.MODEL_PATH.is_absolute()
    assert config.DATABASE_PATH.is_absolute()


def test_security_headers_are_declared():
    headers = config.SECURITY_HEADERS
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["X-Frame-Options"] == "DENY"
    assert "frame-ancestors 'none'" in headers["Content-Security-Policy"]
