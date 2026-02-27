# ABOUTME: Unit tests for ordering-matters analysis script.
# ABOUTME: Validates CSV parsing, metric computation, effect size, and report generation.

import csv
import os
import tempfile

import pytest

# Import module under test (parent directory)
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import analysis


@pytest.fixture
def sample_csv(tmp_path):
    """Create a minimal simulation output CSV for testing."""
    filepath = tmp_path / "sim_output.csv"
    rows = [
        ["tick", "group_a_food", "group_b_food", "group_c_food",
         "group_a_energy", "group_b_energy", "group_c_energy"],
        [0, 0, 0, 0, 100.0, 100.0, 100.0],
        [1, 2, 0, 1, 98.5, 99.0, 97.0],
        [2, 5, 1, 2, 96.0, 98.0, 94.5],
        [3, 9, 3, 4, 93.0, 96.5, 92.0],
        [4, 14, 5, 7, 90.0, 95.0, 89.5],
        [5, 20, 8, 10, 87.0, 93.5, 87.0],
    ]
    with open(filepath, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    return str(filepath)


@pytest.fixture
def sample_df(sample_csv):
    """Load the sample CSV as a DataFrame."""
    return analysis.load_simulation_data(sample_csv)


# ── load_simulation_data ─────────────────────────────────────

class TestLoadSimulationData:
    def test_loads_valid_csv(self, sample_csv):
        df = analysis.load_simulation_data(sample_csv)
        assert len(df) == 6
        assert "tick" in df.columns
        assert "group_a_food" in df.columns

    def test_raises_on_missing_file(self):
        with pytest.raises(FileNotFoundError):
            analysis.load_simulation_data("/nonexistent/file.csv")

    def test_column_types_are_numeric(self, sample_csv):
        df = analysis.load_simulation_data(sample_csv)
        assert df["tick"].dtype in ("int64", "float64")
        assert df["group_a_food"].dtype in ("int64", "float64")
        assert df["group_a_energy"].dtype == "float64"

    def test_raises_on_missing_columns(self, tmp_path):
        filepath = tmp_path / "bad.csv"
        with open(filepath, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["tick", "unrelated"])
            writer.writerow([0, 1])
        with pytest.raises(ValueError, match="Missing required columns"):
            analysis.load_simulation_data(str(filepath))


# ── compute_group_metrics ────────────────────────────────────

class TestComputeGroupMetrics:
    def test_returns_all_groups(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        for grp in ("a", "b", "c"):
            assert grp in metrics

    def test_final_food_values(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        assert metrics["a"]["final_food"] == 20
        assert metrics["b"]["final_food"] == 8
        assert metrics["c"]["final_food"] == 10

    def test_food_rate_positive(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        for grp in ("a", "b", "c"):
            assert metrics[grp]["food_rate"] > 0

    def test_energy_efficiency(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        # efficiency = food_collected / energy_spent
        assert metrics["a"]["efficiency"] == pytest.approx(20.0 / 13.0, rel=0.01)

    def test_single_tick_data(self, tmp_path):
        filepath = tmp_path / "single.csv"
        rows = [
            ["tick", "group_a_food", "group_b_food", "group_c_food",
             "group_a_energy", "group_b_energy", "group_c_energy"],
            [0, 5, 3, 4, 95.0, 97.0, 96.0],
        ]
        with open(filepath, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerows(rows)
        df = analysis.load_simulation_data(str(filepath))
        metrics = analysis.compute_group_metrics(df)
        assert metrics["a"]["final_food"] == 5


# ── compute_effect_size ──────────────────────────────────────

class TestComputeEffectSize:
    def test_returns_pairwise_comparisons(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        effects = analysis.compute_effect_size(metrics)
        assert "a_vs_b" in effects
        assert "a_vs_c" in effects
        assert "b_vs_c" in effects

    def test_effect_direction(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        effects = analysis.compute_effect_size(metrics)
        # Group A collected more than B, so a_vs_b should be positive
        assert effects["a_vs_b"]["food_diff"] > 0

    def test_identical_groups_zero_effect(self):
        metrics = {
            "a": {"final_food": 10, "food_rate": 2.0, "efficiency": 1.0,
                   "final_energy": 90.0, "energy_spent": 10.0},
            "b": {"final_food": 10, "food_rate": 2.0, "efficiency": 1.0,
                   "final_energy": 90.0, "energy_spent": 10.0},
            "c": {"final_food": 10, "food_rate": 2.0, "efficiency": 1.0,
                   "final_energy": 90.0, "energy_spent": 10.0},
        }
        effects = analysis.compute_effect_size(metrics)
        assert effects["a_vs_b"]["food_diff"] == 0
        assert effects["a_vs_b"]["efficiency_diff"] == pytest.approx(0.0)


# ── generate_report ──────────────────────────────────────────

class TestGenerateReport:
    def test_report_contains_all_sections(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        effects = analysis.compute_effect_size(metrics)
        report = analysis.generate_report(metrics, effects)
        assert "Group A" in report
        assert "Group B" in report
        assert "Group C" in report
        assert "Effect" in report or "Comparison" in report

    def test_report_is_string(self, sample_df):
        metrics = analysis.compute_group_metrics(sample_df)
        effects = analysis.compute_effect_size(metrics)
        report = analysis.generate_report(metrics, effects)
        assert isinstance(report, str)
        assert len(report) > 100


# ── plot_comparison (smoke test) ─────────────────────────────

class TestPlotComparison:
    def test_creates_output_file(self, sample_df, tmp_path):
        outpath = str(tmp_path / "plot.png")
        analysis.plot_comparison(sample_df, outpath)
        assert os.path.exists(outpath)
        assert os.path.getsize(outpath) > 0
