# ABOUTME: Analyzes ordering-matters simulation CSV output to quantify how
# ABOUTME: rule execution order affects emergent agent behavior across groups.

"""
Ordering-Matters Analysis
=========================
Parses NetLogo simulation exports and computes per-group metrics,
pairwise effect sizes, and summary reports. Optionally generates
comparison plots.

Usage:
    python3 analysis.py <csv_file> [--plot output.png]
"""

import argparse
import sys
from pathlib import Path

import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

REQUIRED_COLUMNS = {
    "tick", "group_a_food", "group_b_food", "group_c_food",
    "group_a_energy", "group_b_energy", "group_c_energy",
}

GROUP_LABELS = {
    "a": "Group A (sense→move→share)",
    "b": "Group B (share→sense→move)",
    "c": "Group C (move→share→sense)",
}


def load_simulation_data(filepath: str) -> pd.DataFrame:
    """Load and validate a simulation output CSV.

    Raises FileNotFoundError if path is invalid, ValueError if required
    columns are absent.
    """
    path = Path(filepath)
    if not path.exists():
        raise FileNotFoundError(f"No such file: {filepath}")

    df = pd.read_csv(filepath)
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    for col in df.columns:
        df[col] = pd.to_numeric(df[col])

    return df


def compute_group_metrics(df: pd.DataFrame) -> dict:
    """Compute per-group summary metrics from simulation data.

    Returns dict keyed by group letter ("a", "b", "c") with fields:
        final_food, food_rate, final_energy, energy_spent, efficiency
    """
    last = df.iloc[-1]
    num_ticks = max(int(last["tick"]), 1)
    initial_energy = float(df.iloc[0]["group_a_energy"])  # same start

    metrics = {}
    for grp in ("a", "b", "c"):
        food = float(last[f"group_{grp}_food"])
        energy = float(last[f"group_{grp}_energy"])
        spent = initial_energy - energy
        metrics[grp] = {
            "final_food": food,
            "food_rate": food / num_ticks,
            "final_energy": energy,
            "energy_spent": spent,
            "efficiency": food / spent if spent > 0 else 0.0,
        }
    return metrics


def compute_effect_size(metrics: dict) -> dict:
    """Compute pairwise differences between groups.

    Returns dict with keys "a_vs_b", "a_vs_c", "b_vs_c", each containing
    food_diff, efficiency_diff, and energy_diff.
    """
    pairs = [("a", "b"), ("a", "c"), ("b", "c")]
    effects = {}
    for g1, g2 in pairs:
        m1, m2 = metrics[g1], metrics[g2]
        effects[f"{g1}_vs_{g2}"] = {
            "food_diff": m1["final_food"] - m2["final_food"],
            "efficiency_diff": m1["efficiency"] - m2["efficiency"],
            "energy_diff": m1["energy_spent"] - m2["energy_spent"],
        }
    return effects


def generate_report(metrics: dict, effects: dict) -> str:
    """Produce a human-readable summary report."""
    lines = []
    lines.append("=" * 60)
    lines.append("  Ordering-Matters Simulation Analysis Report")
    lines.append("=" * 60)
    lines.append("")

    # Per-group results
    for grp in ("a", "b", "c"):
        m = metrics[grp]
        lines.append(f"--- {GROUP_LABELS[grp]} ---")
        lines.append(f"  Food collected : {m['final_food']:.0f}")
        lines.append(f"  Food rate      : {m['food_rate']:.2f} /tick")
        lines.append(f"  Energy spent   : {m['energy_spent']:.1f}")
        lines.append(f"  Efficiency     : {m['efficiency']:.3f} food/energy")
        lines.append("")

    # Pairwise comparisons
    lines.append("--- Pairwise Comparison ---")
    for key, eff in effects.items():
        g1, g2 = key.split("_vs_")
        lines.append(f"  {g1.upper()} vs {g2.upper()}:")
        lines.append(f"    Food difference       : {eff['food_diff']:+.0f}")
        lines.append(f"    Efficiency difference : {eff['efficiency_diff']:+.3f}")
        lines.append(f"    Energy difference     : {eff['energy_diff']:+.1f}")
    lines.append("")

    # Verdict
    ranked = sorted(metrics.items(), key=lambda kv: kv[1]["final_food"], reverse=True)
    winner = ranked[0][0]
    lines.append(f"Best performing ordering: {GROUP_LABELS[winner]}")
    lines.append("=" * 60)
    return "\n".join(lines)


def plot_comparison(df: pd.DataFrame, output_path: str) -> None:
    """Generate a multi-panel comparison plot and save to output_path."""
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    # Food over time
    ax = axes[0]
    ax.plot(df["tick"], df["group_a_food"], "r-", label="A: sense→move→share")
    ax.plot(df["tick"], df["group_b_food"], "b-", label="B: share→sense→move")
    ax.plot(df["tick"], df["group_c_food"], "g-", label="C: move→share→sense")
    ax.set_xlabel("Tick")
    ax.set_ylabel("Cumulative Food Collected")
    ax.set_title("Food Collection by Rule Ordering")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    # Energy over time
    ax = axes[1]
    ax.plot(df["tick"], df["group_a_energy"], "r-", label="A: sense→move→share")
    ax.plot(df["tick"], df["group_b_energy"], "b-", label="B: share→sense→move")
    ax.plot(df["tick"], df["group_c_energy"], "g-", label="C: move→share→sense")
    ax.set_xlabel("Tick")
    ax.set_ylabel("Average Energy")
    ax.set_title("Energy Expenditure by Rule Ordering")
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


def main(argv=None):
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Analyze ordering-matters simulation output."
    )
    parser.add_argument("csv_file", help="Path to simulation CSV export")
    parser.add_argument("--plot", metavar="FILE", help="Save comparison plot to FILE")
    args = parser.parse_args(argv)

    df = load_simulation_data(args.csv_file)
    metrics = compute_group_metrics(df)
    effects = compute_effect_size(metrics)
    report = generate_report(metrics, effects)
    print(report)

    if args.plot:
        plot_comparison(df, args.plot)
        print(f"\nPlot saved to {args.plot}")


if __name__ == "__main__":
    main()
