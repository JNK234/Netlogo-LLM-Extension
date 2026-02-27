# ABOUTME: Quantifies whether inferred behavioral rules change when identical
# ABOUTME: trajectories are presented in forward, reversed, or shuffled order.

"""Ordering Matters analysis.

Given an inference CSV exported from `ordering-matters.nlogo`, this script:
1. Normalizes inferred rule text per ordering.
2. Computes pairwise rule similarity.
3. Produces an order-dependency score.
4. Optionally writes JSON summary and a plot.

Expected CSV columns:
- ordering: forward | reversed | shuffled
- inferred_rule: free text
- confidence: optional numeric 0-100

Example:
    python3 analysis.py results/sample-inference.csv \
      --plot results/rule-similarity.png \
      --json results/analysis-summary.json
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
from dataclasses import dataclass
from difflib import SequenceMatcher
from itertools import combinations
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

EXPECTED_ORDERINGS = ("forward", "reversed", "shuffled")
REQUIRED_COLUMNS = {"ordering", "inferred_rule"}

STOP_WORDS = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "by",
    "for",
    "from",
    "in",
    "into",
    "is",
    "it",
    "of",
    "on",
    "or",
    "that",
    "the",
    "their",
    "then",
    "this",
    "to",
    "with",
}


@dataclass(frozen=True)
class InferenceRow:
    ordering: str
    inferred_rule: str
    confidence: Optional[float] = None


@dataclass(frozen=True)
class PairwiseSimilarity:
    left: str
    right: str
    jaccard: float
    sequence: float
    combined: float


def parse_confidence(value: str) -> Optional[float]:
    if value is None:
        return None
    text = value.strip().replace("%", "")
    if not text:
        return None
    try:
        parsed = float(text)
    except ValueError:
        return None
    if math.isnan(parsed):
        return None
    return parsed


def load_inference_data(path: str) -> List[InferenceRow]:
    csv_path = Path(path)
    if not csv_path.exists():
        raise FileNotFoundError(f"No such file: {path}")

    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError("CSV has no header row")

        missing = REQUIRED_COLUMNS - set(reader.fieldnames)
        if missing:
            raise ValueError(f"Missing required columns: {sorted(missing)}")

        rows: List[InferenceRow] = []
        for raw in reader:
            ordering = (raw.get("ordering") or "").strip().lower()
            rule = (raw.get("inferred_rule") or "").strip()
            confidence = parse_confidence(raw.get("confidence") or "")
            if not ordering or not rule:
                continue
            rows.append(InferenceRow(ordering=ordering, inferred_rule=rule, confidence=confidence))

    if not rows:
        raise ValueError("CSV contains no usable inference rows")

    return dedupe_by_ordering(rows)


def dedupe_by_ordering(rows: Sequence[InferenceRow]) -> List[InferenceRow]:
    """Keep only the first row per ordering to make comparison deterministic."""
    seen: Dict[str, InferenceRow] = {}
    for row in rows:
        if row.ordering not in seen:
            seen[row.ordering] = row

    preferred = [o for o in EXPECTED_ORDERINGS if o in seen]
    extras = sorted(o for o in seen if o not in EXPECTED_ORDERINGS)
    ordered = preferred + extras
    return [seen[o] for o in ordered]


def normalize_rule_text(text: str) -> str:
    cleaned = re.sub(r"[^a-z0-9\s]", " ", text.lower())
    tokens = [tok for tok in cleaned.split() if tok and tok not in STOP_WORDS]
    return " ".join(tokens)


def tokenize_rule(text: str) -> List[str]:
    norm = normalize_rule_text(text)
    if not norm:
        return []
    return norm.split()


def jaccard_similarity(left_tokens: Iterable[str], right_tokens: Iterable[str]) -> float:
    left_set = set(left_tokens)
    right_set = set(right_tokens)
    if not left_set and not right_set:
        return 1.0
    union = left_set | right_set
    if not union:
        return 1.0
    return len(left_set & right_set) / len(union)


def sequence_similarity(left_text: str, right_text: str) -> float:
    return SequenceMatcher(a=left_text, b=right_text).ratio()


def compute_pairwise_similarity(rows: Sequence[InferenceRow]) -> List[PairwiseSimilarity]:
    similarities: List[PairwiseSimilarity] = []
    by_ordering = {r.ordering: r for r in rows}

    for left, right in combinations(by_ordering.keys(), 2):
        left_norm = normalize_rule_text(by_ordering[left].inferred_rule)
        right_norm = normalize_rule_text(by_ordering[right].inferred_rule)
        jac = jaccard_similarity(tokenize_rule(left_norm), tokenize_rule(right_norm))
        seq = sequence_similarity(left_norm, right_norm)
        similarities.append(
            PairwiseSimilarity(
                left=left,
                right=right,
                jaccard=jac,
                sequence=seq,
                combined=(jac + seq) / 2.0,
            )
        )

    return similarities


def similarity_matrix(rows: Sequence[InferenceRow], pairwise: Sequence[PairwiseSimilarity]) -> Dict[str, Dict[str, float]]:
    labels = [r.ordering for r in rows]
    matrix: Dict[str, Dict[str, float]] = {a: {b: 0.0 for b in labels} for a in labels}

    for label in labels:
        matrix[label][label] = 1.0

    for result in pairwise:
        matrix[result.left][result.right] = result.combined
        matrix[result.right][result.left] = result.combined

    return matrix


def confidence_by_ordering(rows: Sequence[InferenceRow]) -> Dict[str, Optional[float]]:
    return {row.ordering: row.confidence for row in rows}


def analyze_dependency(rows: Sequence[InferenceRow], threshold: float = 0.35) -> Dict[str, object]:
    pairwise = compute_pairwise_similarity(rows)
    matrix = similarity_matrix(rows, pairwise)

    avg_similarity = sum(p.combined for p in pairwise) / len(pairwise) if pairwise else 1.0
    dependency_score = 1.0 - avg_similarity

    per_order_mean = {}
    for label, peers in matrix.items():
        vals = [v for peer, v in peers.items() if peer != label]
        per_order_mean[label] = sum(vals) / len(vals) if vals else 1.0

    most_divergent = min(per_order_mean, key=per_order_mean.get) if per_order_mean else None

    summary = {
        "orderings": [r.ordering for r in rows],
        "pairwise": [
            {
                "left": p.left,
                "right": p.right,
                "jaccard": round(p.jaccard, 4),
                "sequence": round(p.sequence, 4),
                "combined": round(p.combined, 4),
            }
            for p in pairwise
        ],
        "similarity_matrix": {
            left: {right: round(value, 4) for right, value in row.items()}
            for left, row in matrix.items()
        },
        "average_similarity": round(avg_similarity, 4),
        "order_dependency_score": round(dependency_score, 4),
        "threshold": threshold,
        "is_order_sensitive": dependency_score >= threshold,
        "most_divergent_ordering": most_divergent,
        "confidences": confidence_by_ordering(rows),
    }
    return summary


def generate_report(rows: Sequence[InferenceRow], summary: Dict[str, object]) -> str:
    by_order = {r.ordering: r for r in rows}
    lines = []
    lines.append("=" * 70)
    lines.append("Ordering Matters: Rule Inference Divergence Report")
    lines.append("=" * 70)
    lines.append("")

    for ordering in summary["orderings"]:
        row = by_order[ordering]
        conf = row.confidence
        conf_txt = "n/a" if conf is None else f"{conf:.2f}"
        lines.append(f"[{ordering}] confidence={conf_txt}")
        lines.append(f"  raw rule: {row.inferred_rule}")
        lines.append(f"  normalized: {normalize_rule_text(row.inferred_rule)}")
        lines.append("")

    lines.append("Pairwise similarities (combined = mean(jaccard, sequence)):")
    for pair in summary["pairwise"]:
        lines.append(
            "  "
            f"{pair['left']} vs {pair['right']}: "
            f"jaccard={pair['jaccard']:.4f}, "
            f"sequence={pair['sequence']:.4f}, "
            f"combined={pair['combined']:.4f}"
        )

    lines.append("")
    lines.append(f"Average similarity: {summary['average_similarity']:.4f}")
    lines.append(f"Order dependency score: {summary['order_dependency_score']:.4f}")
    lines.append(f"Threshold: {summary['threshold']:.2f}")
    lines.append(f"Order-sensitive: {summary['is_order_sensitive']}")
    lines.append(f"Most divergent ordering: {summary['most_divergent_ordering']}")
    lines.append("=" * 70)
    return "\n".join(lines)


def plot_similarity(rows: Sequence[InferenceRow], summary: Dict[str, object], output_path: str) -> None:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception as exc:  # pragma: no cover
        raise RuntimeError("matplotlib is required for --plot") from exc

    labels = summary["orderings"]
    matrix = summary["similarity_matrix"]
    heat_data = [[matrix[left][right] for right in labels] for left in labels]

    confidences = summary["confidences"]
    conf_values = [(confidences.get(label) or 0.0) for label in labels]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))

    ax = axes[0]
    im = ax.imshow(heat_data, vmin=0.0, vmax=1.0, cmap="viridis")
    ax.set_xticks(range(len(labels)), labels)
    ax.set_yticks(range(len(labels)), labels)
    ax.set_title("Rule Similarity Matrix")

    for i in range(len(labels)):
        for j in range(len(labels)):
            value = heat_data[i][j]
            ax.text(j, i, f"{value:.2f}", ha="center", va="center", color="white" if value < 0.5 else "black")

    cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    cbar.set_label("Similarity")

    ax2 = axes[1]
    bars = ax2.bar(labels, conf_values, color=["#1f77b4", "#ff7f0e", "#2ca02c"])
    ax2.set_title("LLM Confidence by Ordering")
    ax2.set_ylabel("Confidence")
    ax2.set_ylim(0, max(100, max(conf_values) * 1.15 if conf_values else 100))
    for bar, value in zip(bars, conf_values):
        ax2.text(bar.get_x() + bar.get_width() / 2, value + 1, f"{value:.1f}", ha="center", va="bottom", fontsize=9)

    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze ordering-sensitivity of inferred rules.")
    parser.add_argument("csv_file", help="CSV with ordering/inferred_rule/confidence columns")
    parser.add_argument("--threshold", type=float, default=0.35, help="order dependency threshold (default: 0.35)")
    parser.add_argument("--json", metavar="FILE", help="write machine-readable summary JSON")
    parser.add_argument("--plot", metavar="FILE", help="write similarity/confidence plot PNG")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    rows = load_inference_data(args.csv_file)
    summary = analyze_dependency(rows, threshold=args.threshold)
    report = generate_report(rows, summary)
    print(report)

    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump(summary, handle, indent=2)
        print(f"JSON summary written to {args.json}")

    if args.plot:
        plot_similarity(rows, summary, args.plot)
        print(f"Plot written to {args.plot}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
