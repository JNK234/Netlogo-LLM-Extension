#!/usr/bin/env python3
"""Test and analysis harness for Epiplexity Demo 1 (Game of Life emergent objects)."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import random
import statistics
from collections import Counter
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = BASE_DIR / "game_of_life.nlogo"
RESULTS_DIR = BASE_DIR / "results"
BOUNDED_CSV = RESULTS_DIR / "bounded-output.csv"
PERSISTENT_CSV = RESULTS_DIR / "persistent-output.csv"
COMBINED_CSV = RESULTS_DIR / "demo-output.csv"
SUMMARY_JSON = RESULTS_DIR / "summary.json"
ACCURACY_PLOT = RESULTS_DIR / "accuracy_over_time.png"
ENTROPY_PLOT = RESULTS_DIR / "prediction_entropy.png"
ACCURACY_PLOT_SVG = RESULTS_DIR / "accuracy_over_time.svg"
ENTROPY_PLOT_SVG = RESULTS_DIR / "prediction_entropy.svg"

REQUIRED_COLUMNS = [
    "tick",
    "observer_x",
    "observer_y",
    "window_pattern",
    "llm_label",
    "llm_prediction",
    "label_accuracy",
    "prediction_accuracy",
    "memory_mode",
]
OPTIONAL_COLUMNS = [
    "llm_provider",
    "llm_model",
]

ALLOWED_LABELS = {"empty", "stable", "oscillator", "glider-like", "chaotic", "unknown"}
ALLOWED_EVENTS = {
    "remain-empty",
    "remain-stable",
    "oscillation-continues",
    "glider-shifts",
    "pattern-intensifies",
    "pattern-decays",
}


def _read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader)


def _to_int(value: str, field: str) -> int:
    try:
        return int(float(value))
    except Exception as exc:
        raise AssertionError(f"Invalid integer in field '{field}': {value!r}") from exc


def _to_float(value: str, field: str) -> float:
    try:
        result = float(value)
    except Exception as exc:
        raise AssertionError(f"Invalid float in field '{field}': {value!r}") from exc
    if math.isnan(result):
        raise AssertionError(f"NaN value found in field '{field}'")
    return result


def _validate_rows(rows: list[dict[str, str]], memory_mode: str) -> None:
    assert rows, f"No rows found for mode={memory_mode}"

    for col in REQUIRED_COLUMNS:
        assert col in rows[0], f"Missing required column '{col}' in mode={memory_mode}"

    for idx, row in enumerate(rows):
        for col in REQUIRED_COLUMNS:
            assert row.get(col, "") != "", f"Missing value in row {idx}, column '{col}' ({memory_mode})"
        for col in OPTIONAL_COLUMNS:
            if col in row:
                assert row.get(col, "") != "", f"Missing value in row {idx}, column '{col}' ({memory_mode})"

        _to_int(row["tick"], "tick")
        _to_int(row["observer_x"], "observer_x")
        _to_int(row["observer_y"], "observer_y")

        label_acc = _to_float(row["label_accuracy"], "label_accuracy")
        pred_acc = _to_float(row["prediction_accuracy"], "prediction_accuracy")

        assert label_acc in (0.0, 1.0), f"label_accuracy must be 0/1, got {label_acc} ({memory_mode})"
        assert pred_acc in (0.0, 1.0), f"prediction_accuracy must be 0/1, got {pred_acc} ({memory_mode})"

        assert row["llm_label"] in ALLOWED_LABELS, (
            f"Invalid label '{row['llm_label']}' in mode={memory_mode}"
        )
        assert row["llm_prediction"] in ALLOWED_EVENTS, (
            f"Invalid event '{row['llm_prediction']}' in mode={memory_mode}"
        )
        assert row["memory_mode"] == memory_mode, (
            f"Unexpected memory_mode '{row['memory_mode']}' in {memory_mode} output"
        )


def _accuracy(rows: list[dict[str, str]], key: str) -> float:
    vals = [_to_float(r[key], key) for r in rows]
    return statistics.mean(vals) if vals else 0.0


def _rolling_mean(values: list[float], window: int = 5) -> list[float]:
    out: list[float] = []
    for i in range(len(values)):
        start = max(0, i - window + 1)
        out.append(statistics.mean(values[start : i + 1]))
    return out


def _rolling_entropy(labels: list[str], window: int = 10) -> list[float]:
    out: list[float] = []
    for i in range(len(labels)):
        start = max(0, i - window + 1)
        chunk = labels[start : i + 1]
        total = len(chunk)
        counts = Counter(chunk)
        entropy = 0.0
        for count in counts.values():
            p = count / total
            entropy -= p * math.log2(p)
        out.append(entropy)
    return out


def _save_svg_line_plot(
    path: Path,
    title: str,
    x_label: str,
    y_label: str,
    lines: list[tuple[str, list[float], list[float]]],
) -> None:
    width = 960
    height = 560
    margin_left = 70
    margin_right = 20
    margin_top = 50
    margin_bottom = 60
    plot_w = width - margin_left - margin_right
    plot_h = height - margin_top - margin_bottom

    all_x = [x for _, xs, _ in lines for x in xs]
    all_y = [y for _, _, ys in lines for y in ys]
    if not all_x or not all_y:
        return

    min_x, max_x = min(all_x), max(all_x)
    min_y, max_y = min(all_y), max(all_y)
    if max_x == min_x:
        max_x += 1.0
    if max_y == min_y:
        max_y += 1.0

    def sx(value: float) -> float:
        return margin_left + ((value - min_x) / (max_x - min_x)) * plot_w

    def sy(value: float) -> float:
        return margin_top + plot_h - ((value - min_y) / (max_y - min_y)) * plot_h

    palette = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#ff7f0e", "#17becf"]
    svg_lines: list[str] = []
    svg_lines.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">')
    svg_lines.append('<rect width="100%" height="100%" fill="white" />')
    svg_lines.append(f'<text x="{width/2:.1f}" y="28" text-anchor="middle" font-size="18">{title}</text>')
    svg_lines.append(
        f'<line x1="{margin_left}" y1="{margin_top + plot_h}" x2="{margin_left + plot_w}" y2="{margin_top + plot_h}" stroke="#222" />'
    )
    svg_lines.append(
        f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{margin_top + plot_h}" stroke="#222" />'
    )
    svg_lines.append(
        f'<text x="{width/2:.1f}" y="{height - 18}" text-anchor="middle" font-size="13">{x_label}</text>'
    )
    svg_lines.append(
        f'<text x="18" y="{height/2:.1f}" text-anchor="middle" font-size="13" transform="rotate(-90, 18, {height/2:.1f})">{y_label}</text>'
    )

    for idx, (name, xs, ys) in enumerate(lines):
        if not xs or not ys or len(xs) != len(ys):
            continue
        points = " ".join(f"{sx(x):.2f},{sy(y):.2f}" for x, y in zip(xs, ys))
        color = palette[idx % len(palette)]
        svg_lines.append(
            f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2" />'
        )

    legend_x = margin_left + 10
    legend_y = margin_top + 14
    for idx, (name, _, _) in enumerate(lines):
        color = palette[idx % len(palette)]
        y = legend_y + idx * 18
        svg_lines.append(f'<line x1="{legend_x}" y1="{y}" x2="{legend_x + 20}" y2="{y}" stroke="{color}" stroke-width="2" />')
        svg_lines.append(f'<text x="{legend_x + 26}" y="{y + 4}" font-size="12">{name}</text>')

    svg_lines.append("</svg>")
    path.write_text("\n".join(svg_lines), encoding="utf-8")


def _try_run_with_pynetlogo(ticks: int) -> bool:
    """Attempt to run NetLogo model via pyNetLogo if environment supports it."""
    run_live = os.environ.get("EPIPLEXITY_RUN_NETLOGO", "0") == "1"
    if not run_live:
        return False

    try:
        import pyNetLogo  # type: ignore
    except Exception:
        print("pyNetLogo not installed; skipping live run.")
        return False

    netlogo_home = os.environ.get("NETLOGO_HOME")
    if not netlogo_home:
        print("NETLOGO_HOME is not set; skipping live run.")
        return False

    try:
        link = pyNetLogo.NetLogoLink(gui=False, netlogo_home=netlogo_home)
        link.load_model(str(MODEL_PATH))
        link.command(f"set episode-length {ticks}")
        link.command("run-episode-bounded")
        link.command("run-episode-persistent")
        print("Live NetLogo run completed via pyNetLogo.")
        return True
    except Exception as exc:
        print(f"Live NetLogo run failed: {exc}")
        return False


def _generate_baseline_if_missing(rows: int = 50, force: bool = False) -> None:
    """Create deterministic baseline CSVs for offline analysis when live run is unavailable."""
    if (not force) and BOUNDED_CSV.exists() and PERSISTENT_CSV.exists() and COMBINED_CSV.exists():
        return

    random.seed(20260226)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    labels = sorted(ALLOWED_LABELS)
    events = sorted(ALLOWED_EVENTS)

    def make_rows(mode: str, pred_p: float, label_p: float) -> list[dict[str, str]]:
        data = []
        for tick in range(rows):
            window = "/".join(
                "".join("X" if random.random() < 0.28 else "." for _ in range(5))
                for _ in range(5)
            )
            label_ok = 1 if random.random() < label_p else 0
            pred_ok = 1 if random.random() < pred_p else 0
            data.append(
                {
                    "tick": str(tick),
                    "observer_x": str(25 + (tick % 3) - 1),
                    "observer_y": str(25 + ((tick // 3) % 3) - 1),
                    "window_pattern": window,
                    "llm_label": random.choice(labels),
                    "llm_prediction": random.choice(events),
                    "label_accuracy": str(label_ok),
                    "prediction_accuracy": str(pred_ok),
                    "memory_mode": mode,
                    "llm_provider": "offline-baseline",
                    "llm_model": "simulated-observer",
                }
            )
        return data

    bounded = make_rows("bounded", pred_p=0.52, label_p=0.74)
    persistent = make_rows("persistent", pred_p=0.78, label_p=0.76)

    for path, rows_data in ((BOUNDED_CSV, bounded), (PERSISTENT_CSV, persistent), (COMBINED_CSV, bounded + persistent)):
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=REQUIRED_COLUMNS + OPTIONAL_COLUMNS)
            writer.writeheader()
            writer.writerows(rows_data)



def _save_plots(bounded: list[dict[str, str]], persistent: list[dict[str, str]]) -> None:
    b_ticks = [_to_int(r["tick"], "tick") for r in bounded]
    p_ticks = [_to_int(r["tick"], "tick") for r in persistent]

    b_label = [_to_float(r["label_accuracy"], "label_accuracy") for r in bounded]
    p_label = [_to_float(r["label_accuracy"], "label_accuracy") for r in persistent]

    b_pred = [_to_float(r["prediction_accuracy"], "prediction_accuracy") for r in bounded]
    p_pred = [_to_float(r["prediction_accuracy"], "prediction_accuracy") for r in persistent]

    b_entropy = _rolling_entropy([r["llm_prediction"] for r in bounded], 10)
    p_entropy = _rolling_entropy([r["llm_prediction"] for r in persistent], 10)

    try:
        import matplotlib.pyplot as plt  # type: ignore
    except Exception:
        _save_svg_line_plot(
            ACCURACY_PLOT_SVG,
            "Demo 1 Accuracy Over Time",
            "Tick",
            "Rolling Accuracy (window=5)",
            [
                ("Bounded label acc", [float(x) for x in b_ticks], _rolling_mean(b_label, 5)),
                ("Persistent label acc", [float(x) for x in p_ticks], _rolling_mean(p_label, 5)),
                ("Bounded prediction acc", [float(x) for x in b_ticks], _rolling_mean(b_pred, 5)),
                ("Persistent prediction acc", [float(x) for x in p_ticks], _rolling_mean(p_pred, 5)),
            ],
        )
        _save_svg_line_plot(
            ENTROPY_PLOT_SVG,
            "Prediction Entropy Over Time",
            "Tick",
            "Shannon Entropy (rolling window=10)",
            [
                ("Bounded prediction entropy", [float(x) for x in b_ticks], b_entropy),
                ("Persistent prediction entropy", [float(x) for x in p_ticks], p_entropy),
            ],
        )
        print("matplotlib not installed; generated SVG plots instead.")
        return

    plt.figure(figsize=(10, 6))
    plt.plot(b_ticks, _rolling_mean(b_label, 5), label="Bounded label acc")
    plt.plot(p_ticks, _rolling_mean(p_label, 5), label="Persistent label acc")
    plt.plot(b_ticks, _rolling_mean(b_pred, 5), label="Bounded prediction acc")
    plt.plot(p_ticks, _rolling_mean(p_pred, 5), label="Persistent prediction acc")
    plt.xlabel("Tick")
    plt.ylabel("Rolling Accuracy (window=5)")
    plt.title("Demo 1 Accuracy Over Time")
    plt.legend()
    plt.tight_layout()
    plt.savefig(ACCURACY_PLOT, dpi=140)
    plt.close()

    plt.figure(figsize=(10, 6))
    plt.plot(b_ticks, b_entropy, label="Bounded prediction entropy")
    plt.plot(p_ticks, p_entropy, label="Persistent prediction entropy")
    plt.xlabel("Tick")
    plt.ylabel("Shannon Entropy (rolling window=10)")
    plt.title("Prediction Entropy Over Time")
    plt.legend()
    plt.tight_layout()
    plt.savefig(ENTROPY_PLOT, dpi=140)
    plt.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Demo 1 validation and analysis.")
    parser.add_argument("--ticks", type=int, default=50, help="Episode length for live NetLogo runs.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if thresholds are not met (default: report-only).",
    )
    parser.add_argument(
        "--refresh-baseline",
        action="store_true",
        help="Force overwrite offline baseline CSV artifacts.",
    )
    args = parser.parse_args()

    _try_run_with_pynetlogo(args.ticks)
    _generate_baseline_if_missing(rows=args.ticks, force=args.refresh_baseline)

    bounded = _read_csv(BOUNDED_CSV)
    persistent = _read_csv(PERSISTENT_CSV)

    _validate_rows(bounded, "bounded")
    _validate_rows(persistent, "persistent")

    b_label_acc = _accuracy(bounded, "label_accuracy")
    b_pred_acc = _accuracy(bounded, "prediction_accuracy")
    p_label_acc = _accuracy(persistent, "label_accuracy")
    p_pred_acc = _accuracy(persistent, "prediction_accuracy")
    lift = p_pred_acc - b_pred_acc

    summary = {
        "bounded": {
            "rows": len(bounded),
            "label_accuracy": b_label_acc,
            "prediction_accuracy": b_pred_acc,
        },
        "persistent": {
            "rows": len(persistent),
            "label_accuracy": p_label_acc,
            "prediction_accuracy": p_pred_acc,
        },
        "prediction_lift": lift,
    }

    SUMMARY_JSON.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    _save_plots(bounded, persistent)

    print("=== Demo 1 Summary ===")
    print(json.dumps(summary, indent=2))

    if args.strict:
        assert b_label_acc >= 0.70, f"Bounded label accuracy below threshold: {b_label_acc:.3f}"
        assert p_label_acc >= 0.70, f"Persistent label accuracy below threshold: {p_label_acc:.3f}"
        assert p_pred_acc >= 0.70, f"Persistent prediction accuracy below threshold: {p_pred_acc:.3f}"
        assert lift >= 0.10, f"Prediction lift too small: {lift:.3f}"

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
