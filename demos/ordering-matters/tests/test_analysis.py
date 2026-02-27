# ABOUTME: Unit tests for ordering-matters rule-divergence analysis.
# ABOUTME: Validates loading, normalization, similarity scoring, and outputs.

from __future__ import annotations

import csv
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import analysis


@pytest.fixture
def inference_csv(tmp_path: Path) -> Path:
    path = tmp_path / "inference.csv"
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["ordering", "inferred_rule", "confidence"])
        writer.writerow(["forward", "Agents seek food, avoid crowding, and maintain heading.", "88"])
        writer.writerow(["reversed", "Agents wander first, then correct toward goals late.", "61"])
        writer.writerow(["shuffled", "Movement appears noisy with weak local goal-seeking.", "54"])
    return path


def test_load_inference_data_reads_rows(inference_csv: Path) -> None:
    rows = analysis.load_inference_data(str(inference_csv))
    assert [r.ordering for r in rows] == ["forward", "reversed", "shuffled"]
    assert rows[0].confidence == pytest.approx(88.0)


def test_load_inference_data_missing_columns(tmp_path: Path) -> None:
    path = tmp_path / "bad.csv"
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["ordering", "note"])
        writer.writerow(["forward", "x"])

    with pytest.raises(ValueError, match="Missing required columns"):
        analysis.load_inference_data(str(path))


def test_dedupe_by_ordering_keeps_first() -> None:
    rows = [
        analysis.InferenceRow("forward", "first forward", 50),
        analysis.InferenceRow("forward", "second forward", 99),
        analysis.InferenceRow("reversed", "rev", 30),
    ]
    deduped = analysis.dedupe_by_ordering(rows)
    assert len(deduped) == 2
    assert deduped[0].inferred_rule == "first forward"


def test_normalize_rule_text_removes_noise() -> None:
    value = analysis.normalize_rule_text("The agents, in a line, move TO food!")
    assert value == "agents line move food"


def test_similarity_scores_are_bounded(inference_csv: Path) -> None:
    rows = analysis.load_inference_data(str(inference_csv))
    pairwise = analysis.compute_pairwise_similarity(rows)
    assert len(pairwise) == 3
    for pair in pairwise:
        assert 0.0 <= pair.jaccard <= 1.0
        assert 0.0 <= pair.sequence <= 1.0
        assert 0.0 <= pair.combined <= 1.0


def test_analyze_dependency_detects_order_sensitivity(inference_csv: Path) -> None:
    rows = analysis.load_inference_data(str(inference_csv))
    summary = analysis.analyze_dependency(rows, threshold=0.2)
    assert summary["is_order_sensitive"] is True
    assert summary["order_dependency_score"] > 0


def test_analyze_dependency_not_sensitive_when_same_rule() -> None:
    rows = [
        analysis.InferenceRow("forward", "seek food avoid crowding", 70),
        analysis.InferenceRow("reversed", "seek food avoid crowding", 72),
        analysis.InferenceRow("shuffled", "seek food avoid crowding", 68),
    ]
    summary = analysis.analyze_dependency(rows, threshold=0.2)
    assert summary["is_order_sensitive"] is False
    assert summary["order_dependency_score"] == pytest.approx(0.0)


def test_generate_report_contains_key_fields(inference_csv: Path) -> None:
    rows = analysis.load_inference_data(str(inference_csv))
    summary = analysis.analyze_dependency(rows)
    report = analysis.generate_report(rows, summary)
    assert "Ordering Matters" in report
    assert "Order dependency score" in report
    assert "forward" in report


def test_main_writes_json(inference_csv: Path, tmp_path: Path) -> None:
    out_json = tmp_path / "summary.json"
    exit_code = analysis.main([str(inference_csv), "--json", str(out_json)])
    assert exit_code == 0
    payload = json.loads(out_json.read_text(encoding="utf-8"))
    assert "order_dependency_score" in payload
    assert payload["orderings"] == ["forward", "reversed", "shuffled"]


def test_plot_similarity_smoke(inference_csv: Path, tmp_path: Path) -> None:
    pytest.importorskip("matplotlib")
    rows = analysis.load_inference_data(str(inference_csv))
    summary = analysis.analyze_dependency(rows)
    plot_path = tmp_path / "plot.png"
    analysis.plot_similarity(rows, summary, str(plot_path))
    assert plot_path.exists()
    assert plot_path.stat().st_size > 0
