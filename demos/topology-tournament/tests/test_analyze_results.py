import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent.parent / "analyze-results.py"
SPEC = importlib.util.spec_from_file_location("analyze_results", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class TestAnalyzeResults(unittest.TestCase):
    def test_load_results_with_behaviorspace_preface(self):
        content = (
            "BehaviorSpace results (NetLogo)\n"
            "model: topology-tournament.nlogo\n"
            "experiment: topology-tournament\n"
            "num-agents,[run number],[step],mesh-convergence-tick,hierarchy-convergence-tick,chain-convergence-tick\n"
            "10,0,0,-1,-1,-1\n"
            "10,0,1,20,30,40\n"
            "10,1,0,-1,-1,-1\n"
            "10,1,1,22,33,44\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            csv_path = Path(tmp_dir) / "results.csv"
            csv_path.write_text(content, encoding="utf-8")
            raw = MODULE.load_results(csv_path)

        self.assertEqual(len(raw), 4)
        self.assertIn("mesh-convergence-tick", raw.columns)

    def test_select_final_rows_per_run_uses_latest_step(self):
        content = (
            "num-agents,[run number],[step],mesh-convergence-tick,hierarchy-convergence-tick,chain-convergence-tick\n"
            "10,0,0,-1,-1,-1\n"
            "10,0,5,18,29,35\n"
            "10,0,8,20,30,40\n"
            "10,1,0,-1,-1,-1\n"
            "10,1,8,22,32,45\n"
            "30,0,8,31,45,64\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            csv_path = Path(tmp_dir) / "results.csv"
            csv_path.write_text(content, encoding="utf-8")
            raw = MODULE.load_results(csv_path)
            normalized = MODULE.normalize_results(raw)
            final_rows = MODULE.select_final_rows_per_run(normalized)

        self.assertEqual(len(final_rows), 3)
        row = final_rows[
            (final_rows["num_agents"] == 10) & (final_rows["run_number"] == 0)
        ].iloc[0]
        self.assertEqual(row["mesh_convergence_tick"], 20)
        self.assertEqual(row["hierarchy_convergence_tick"], 30)
        self.assertEqual(row["chain_convergence_tick"], 40)

    def test_summarize_final_rows_calculates_means(self):
        content = (
            "num-agents,[run number],[step],mesh-convergence-tick,hierarchy-convergence-tick,chain-convergence-tick\n"
            "10,0,1,20,30,40\n"
            "10,1,1,22,32,44\n"
            "30,0,1,35,50,68\n"
            "30,1,1,37,53,72\n"
        )
        with tempfile.TemporaryDirectory() as tmp_dir:
            csv_path = Path(tmp_dir) / "results.csv"
            csv_path.write_text(content, encoding="utf-8")
            raw = MODULE.load_results(csv_path)
            normalized = MODULE.normalize_results(raw)
            final_rows = MODULE.select_final_rows_per_run(normalized)
            summary = MODULE.summarize_final_rows(final_rows)

        row_10 = summary[summary["num_agents"] == 10].iloc[0]
        self.assertEqual(row_10["runs"], 2)
        self.assertAlmostEqual(row_10["mesh_mean_ticks"], 21.0)
        self.assertAlmostEqual(row_10["hierarchy_mean_ticks"], 31.0)
        self.assertAlmostEqual(row_10["chain_mean_ticks"], 42.0)


if __name__ == "__main__":
    unittest.main()
