#!/usr/bin/env python3
"""Aggregate Topology Tournament BehaviorSpace output and generate plots."""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

NUM_AGENTS_CANDIDATES = ["num-agents", "num_agents", "[num-agents]"]
RUN_CANDIDATES = ["[run number]", "run number", "run-number", "run"]
STEP_CANDIDATES = ["[step]", "step"]

MESH_TICK_CANDIDATES = ["mesh-convergence-tick", "[mesh-convergence-tick]"]
HIERARCHY_TICK_CANDIDATES = ["hierarchy-convergence-tick", "[hierarchy-convergence-tick]"]
CHAIN_TICK_CANDIDATES = ["chain-convergence-tick", "[chain-convergence-tick]"]


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    "csv_path",
    nargs="?",
    type=Path,
    default=Path("results.csv"),
    help="BehaviorSpace CSV path (default: results.csv)",
  )
  parser.add_argument(
    "--output-dir",
    type=Path,
    default=Path("."),
    help="Directory for generated plots and summary CSV.",
  )
  parser.add_argument(
    "--prefix",
    default="topology-tournament",
    help="Output filename prefix (default: topology-tournament).",
  )
  return parser.parse_args()


def _find_header_row(lines: list[str]) -> int:
  for idx, line in enumerate(lines):
    lowered = line.lower()
    if "num-agents" in lowered and "mesh-convergence-tick" in lowered:
      return idx
  return 0


def _select_column(df: pd.DataFrame, candidates: list[str], *, required: bool) -> str | None:
  lookup = {col.lower().strip(): col for col in df.columns}
  for candidate in candidates:
    key = candidate.lower().strip()
    if key in lookup:
      return lookup[key]
  if required:
    raise ValueError(f"Missing required column from candidates: {candidates}")
  return None


def load_results(path: Path) -> pd.DataFrame:
  if not path.exists():
    raise FileNotFoundError(f"CSV not found: {path}")

  lines = path.read_text(encoding="utf-8").splitlines()
  header_row = _find_header_row(lines)
  return pd.read_csv(path, skiprows=header_row)


def normalize_results(df: pd.DataFrame) -> pd.DataFrame:
  num_agents_col = _select_column(df, NUM_AGENTS_CANDIDATES, required=True)
  mesh_col = _select_column(df, MESH_TICK_CANDIDATES, required=True)
  hierarchy_col = _select_column(df, HIERARCHY_TICK_CANDIDATES, required=True)
  chain_col = _select_column(df, CHAIN_TICK_CANDIDATES, required=True)
  run_col = _select_column(df, RUN_CANDIDATES, required=False)
  step_col = _select_column(df, STEP_CANDIDATES, required=False)

  normalized = pd.DataFrame()
  normalized["num_agents"] = pd.to_numeric(df[num_agents_col], errors="coerce")
  normalized["mesh_convergence_tick"] = pd.to_numeric(df[mesh_col], errors="coerce")
  normalized["hierarchy_convergence_tick"] = pd.to_numeric(df[hierarchy_col], errors="coerce")
  normalized["chain_convergence_tick"] = pd.to_numeric(df[chain_col], errors="coerce")
  normalized["source_row"] = range(len(df))

  if run_col is None:
    normalized["run_number"] = 0
  else:
    normalized["run_number"] = pd.to_numeric(df[run_col], errors="coerce").fillna(0)

  if step_col is None:
    normalized["step"] = normalized["source_row"]
  else:
    normalized["step"] = pd.to_numeric(df[step_col], errors="coerce").fillna(normalized["source_row"])

  normalized = normalized.dropna(
    subset=[
      "num_agents",
      "mesh_convergence_tick",
      "hierarchy_convergence_tick",
      "chain_convergence_tick",
    ]
  ).copy()
  if normalized.empty:
    raise ValueError("No valid convergence rows found in CSV")

  normalized["num_agents"] = normalized["num_agents"].astype(int)
  normalized["run_number"] = normalized["run_number"].astype(int)

  return normalized


def select_final_rows_per_run(normalized: pd.DataFrame) -> pd.DataFrame:
  sorted_rows = normalized.sort_values(["num_agents", "run_number", "step", "source_row"])
  final_rows = (
    sorted_rows.groupby(["num_agents", "run_number"], as_index=False)
    .tail(1)
    .reset_index(drop=True)
  )
  return final_rows


def summarize_final_rows(final_rows: pd.DataFrame) -> pd.DataFrame:
  summary = (
    final_rows.groupby("num_agents", as_index=False)
    .agg(
      runs=("run_number", "nunique"),
      mesh_mean_ticks=("mesh_convergence_tick", "mean"),
      hierarchy_mean_ticks=("hierarchy_convergence_tick", "mean"),
      chain_mean_ticks=("chain_convergence_tick", "mean"),
      mesh_std_ticks=("mesh_convergence_tick", "std"),
      hierarchy_std_ticks=("hierarchy_convergence_tick", "std"),
      chain_std_ticks=("chain_convergence_tick", "std"),
    )
    .sort_values("num_agents")
    .reset_index(drop=True)
  )
  return summary


def _best_bar_index(agent_counts: list[int]) -> int:
  if not agent_counts:
    raise ValueError("No agent counts available for plotting")
  return min(range(len(agent_counts)), key=lambda idx: abs(agent_counts[idx] - 30))


def generate_plot(summary: pd.DataFrame, output_png: Path, output_pdf: Path) -> None:
  agent_counts = summary["num_agents"].tolist()
  mesh_times = summary["mesh_mean_ticks"].tolist()
  hierarchy_times = summary["hierarchy_mean_ticks"].tolist()
  chain_times = summary["chain_mean_ticks"].tolist()

  mesh_err = summary["mesh_std_ticks"].fillna(0.0).tolist()
  hierarchy_err = summary["hierarchy_std_ticks"].fillna(0.0).tolist()
  chain_err = summary["chain_std_ticks"].fillna(0.0).tolist()

  fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

  ax1.errorbar(
    agent_counts,
    mesh_times,
    yerr=mesh_err,
    fmt="o-",
    color="#4477AA",
    label="Mesh",
    linewidth=2,
    markersize=7,
  )
  ax1.errorbar(
    agent_counts,
    hierarchy_times,
    yerr=hierarchy_err,
    fmt="^-",
    color="#CC6677",
    label="Hierarchy",
    linewidth=2,
    markersize=7,
  )
  ax1.errorbar(
    agent_counts,
    chain_times,
    yerr=chain_err,
    fmt="s-",
    color="#DDCC77",
    label="Chain",
    linewidth=2,
    markersize=7,
  )
  ax1.set_xlabel("Number of Agents", fontsize=12)
  ax1.set_ylabel("Convergence Time (ticks)", fontsize=12)
  ax1.set_title("Topology Tournament: Mean Convergence Time", fontsize=14)
  ax1.legend(fontsize=11)
  ax1.grid(True, alpha=0.3)

  bar_idx = _best_bar_index(agent_counts)
  bar_values = [mesh_times[bar_idx], hierarchy_times[bar_idx], chain_times[bar_idx]]
  bars = ax2.bar(
    ["Mesh", "Hierarchy", "Chain"],
    bar_values,
    color=["#4477AA", "#CC6677", "#DDCC77"],
    edgecolor="black",
  )
  ax2.set_ylabel("Convergence Time (ticks)", fontsize=12)
  ax2.set_title(f"Performance at {agent_counts[bar_idx]} Agents", fontsize=14)
  ax2.grid(True, alpha=0.3, axis="y")

  for bar in bars:
    height = bar.get_height()
    ax2.text(
      bar.get_x() + bar.get_width() / 2.0,
      height + 1,
      f"{height:.1f}",
      ha="center",
      va="bottom",
      fontsize=11,
    )

  fig.tight_layout()
  fig.savefig(output_png, dpi=150, bbox_inches="tight")
  fig.savefig(output_pdf, bbox_inches="tight")
  plt.close(fig)


def main() -> None:
  args = parse_args()
  args.output_dir.mkdir(parents=True, exist_ok=True)

  raw = load_results(args.csv_path)
  normalized = normalize_results(raw)
  final_rows = select_final_rows_per_run(normalized)
  summary = summarize_final_rows(final_rows)

  summary_csv = args.output_dir / f"{args.prefix}-summary.csv"
  output_png = args.output_dir / f"{args.prefix}-results.png"
  output_pdf = args.output_dir / f"{args.prefix}-results.pdf"

  summary.to_csv(summary_csv, index=False)
  generate_plot(summary, output_png, output_pdf)

  print(f"Wrote: {summary_csv}")
  print(f"Wrote: {output_png}")
  print(f"Wrote: {output_pdf}")


if __name__ == "__main__":
  main()
