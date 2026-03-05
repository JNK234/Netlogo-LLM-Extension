import re
import unittest
from pathlib import Path


DEMO_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = DEMO_DIR / "crisis-triage.nlogox"
TRIAGE_TEMPLATE_PATH = DEMO_DIR / "triage-template.yaml"
DISPATCHER_TEMPLATE_PATH = DEMO_DIR / "dispatcher-template.yaml"
CONFIG_PATH = DEMO_DIR / "config.txt"
README_PATH = DEMO_DIR / "README.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def model_code_only() -> str:
    xml = read(MODEL_PATH)
    match = re.search(r"<code><!\[CDATA\[(.*?)\]\]></code>", xml, re.DOTALL)
    if not match:
        raise AssertionError("unable to parse <code><![CDATA[...]]></code> from model")
    return match.group(1)


def parse_config(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in read(path).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip()
    return data


class TestCrisisTriageArtifacts(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        required = [
            MODEL_PATH,
            TRIAGE_TEMPLATE_PATH,
            DISPATCHER_TEMPLATE_PATH,
            CONFIG_PATH,
            README_PATH,
        ]
        for path in required:
            self.assertTrue(path.exists(), f"missing file: {path}")

    def test_model_declares_tiered_breeds(self) -> None:
        code = model_code_only()
        self.assertIn("breed [cases case]", code)
        self.assertIn("breed [basic-agents basic-agent]", code)
        self.assertIn("breed [expert-agents expert-agent]", code)
        self.assertIn("breed [coordinators coordinator]", code)

    def test_model_contains_required_procedures(self) -> None:
        code = model_code_only()
        procedures = [
            "to setup",
            "to setup-llm",
            "to triage-new-cases",
            "to perform-triage",
            "to route-triaged-cases",
            "to dispatch-case",
            "to coordinator-rebalance",
            "to reassign-case",
            "to process-assigned-cases",
            "to finalize-case",
        ]
        for proc in procedures:
            self.assertIn(proc, code, f"missing procedure: {proc}")

    def test_model_uses_llm_templates_and_config(self) -> None:
        code = model_code_only()
        self.assertIn('set config-path "demos/crisis-triage/config.txt"', code)
        self.assertIn('set triage-template-path "demos/crisis-triage/triage-template.yaml"', code)
        self.assertIn('set dispatcher-template-path "demos/crisis-triage/dispatcher-template.yaml"', code)
        self.assertIn("llm:chat-with-template triage-template-path", code)
        self.assertIn("llm:chat-with-template dispatcher-template-path", code)
        self.assertIn("heuristic-severity-report", code)

    def test_triage_template_placeholders_match_model(self) -> None:
        template = read(TRIAGE_TEMPLATE_PATH)
        placeholders = set(re.findall(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}", template))
        self.assertEqual(
            placeholders,
            {"incident", "impact", "elapsed_ticks", "known_context"},
        )
        self.assertIn("SEVERITY: LOW|MODERATE|HIGH|CRITICAL", template)

    def test_dispatcher_template_placeholders_match_model(self) -> None:
        template = read(DISPATCHER_TEMPLATE_PATH)
        placeholders = set(re.findall(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}", template))
        self.assertEqual(
            placeholders,
            {"severity", "incident", "basic_load", "expert_load", "coordinator_load"},
        )
        self.assertIn("ROUTE: BASIC|EXPERT|COORDINATOR", template)

    def test_config_has_required_keys(self) -> None:
        config = parse_config(CONFIG_PATH)
        for key in ["provider", "model", "temperature", "max_tokens", "timeout_seconds"]:
            self.assertIn(key, config, f"missing key in config: {key}")

    def test_readme_has_core_sections(self) -> None:
        readme = read(README_PATH)
        for text in [
            "What it demonstrates",
            "Model architecture",
            "Run instructions",
            "Test suite",
        ]:
            self.assertIn(text, readme)


if __name__ == "__main__":
    unittest.main()
