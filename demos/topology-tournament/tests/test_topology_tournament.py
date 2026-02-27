import pathlib
import unittest


DEMO_DIR = pathlib.Path(__file__).resolve().parents[1]
MODEL_PATH = DEMO_DIR / "topology-tournament.nlogo"
TEMPLATE_PATH = DEMO_DIR / "coordinator-template.yaml"
CONFIG_PATH = DEMO_DIR / "config.txt"


def _model_code() -> str:
    content = MODEL_PATH.read_text(encoding="utf-8")
    return content.split("@#$#@#$#@")[0]


def _parse_config(path: pathlib.Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        parsed[key.strip()] = value.strip()
    return parsed


class TopologyTournamentModelTests(unittest.TestCase):
    def test_required_breeds_exist(self) -> None:
        code = _model_code()
        self.assertIn("breed [mesh-agents mesh-agent]", code)
        self.assertIn("breed [hierarchy-agents hierarchy-agent]", code)
        self.assertIn("breed [chain-agents chain-agent]", code)

    def test_llm_template_call_exists(self) -> None:
        code = _model_code()
        self.assertIn("llm:chat-with-template", code)
        self.assertIn("demos/topology-tournament/coordinator-template.yaml", code)

    def test_topology_and_convergence_procedures_exist(self) -> None:
        code = _model_code()
        required_procedures = [
            "to build-mesh-topology",
            "to build-hierarchy-topology",
            "to build-chain-topology",
            "to coordinate-topology",
            "to-report converged?",
            "to-report convergence-time",
        ]
        for procedure in required_procedures:
            self.assertIn(procedure, code)

    def test_supported_actions_are_parseable(self) -> None:
        code = _model_code()
        for action in [
            "ACTION:BROADCAST_MAJORITY",
            "ACTION:MAJORITY_PUSH",
            "ACTION:PAIR_SWAP",
            "ACTION:SPLIT_REBALANCE",
            "ACTION:HOLD",
        ]:
            self.assertIn(action, code)

    def test_ui_defaults_reference_demo_config(self) -> None:
        content = MODEL_PATH.read_text(encoding="utf-8")
        self.assertIn("demos/topology-tournament/config.txt", content)


class CoordinatorTemplateTests(unittest.TestCase):
    def test_template_contains_required_placeholders(self) -> None:
        template = TEMPLATE_PATH.read_text(encoding="utf-8")
        for variable in [
            "{topology}",
            "{tick}",
            "{agent_count}",
            "{belief_summary}",
            "{majority_belief}",
        ]:
            self.assertIn(variable, template)

    def test_template_enforces_action_protocol(self) -> None:
        template = TEMPLATE_PATH.read_text(encoding="utf-8")
        self.assertIn("ACTION:<ONE_ACTION_FROM_LIST>", template)
        self.assertIn("RATIONALE:<ONE_SHORT_SENTENCE>", template)


class ConfigTests(unittest.TestCase):
    def test_config_matches_requested_provider_settings(self) -> None:
        config = _parse_config(CONFIG_PATH)
        self.assertEqual(config.get("provider"), "openai")
        self.assertEqual(config.get("model"), "gpt-4o-mini")
        self.assertEqual(config.get("temperature"), "0.3")
        self.assertEqual(config.get("timeout_seconds"), "30")


if __name__ == "__main__":
    unittest.main()
