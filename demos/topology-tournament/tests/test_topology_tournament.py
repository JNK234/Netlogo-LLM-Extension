# ABOUTME: Unit tests for the topology-tournament demo
# ABOUTME: Validates .nlogox structure, code modernization, per-agent decisions, and config

import pathlib
import unittest
import xml.etree.ElementTree as ET


DEMO_DIR = pathlib.Path(__file__).resolve().parents[1]
MODEL_PATH = DEMO_DIR / "topology-tournament.nlogox"
CONFIG_PATH = DEMO_DIR / "config.txt"


def _parse_model() -> ET.Element:
    tree = ET.parse(MODEL_PATH)
    return tree.getroot()


def _model_code() -> str:
    root = _parse_model()
    code_elem = root.find("code")
    return code_elem.text if code_elem is not None and code_elem.text else ""


def _parse_config(path: pathlib.Path) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        parsed[key.strip()] = value.strip()
    return parsed


# --- XML structure tests ---


class NlogoxFormatTests(unittest.TestCase):
    def test_file_is_valid_xml(self) -> None:
        root = _parse_model()
        self.assertEqual(root.tag, "model")

    def test_version_contains_netlogo_7(self) -> None:
        root = _parse_model()
        version = root.get("version", "")
        self.assertIn("NetLogo 7.0.3", version)

    def test_required_sections_exist(self) -> None:
        root = _parse_model()
        for section in ["code", "widgets", "info", "turtleShapes", "linkShapes"]:
            self.assertIsNotNone(root.find(section), f"Missing <{section}> element")

    def test_widgets_include_required_types(self) -> None:
        root = _parse_model()
        widgets = root.find("widgets")
        self.assertIsNotNone(widgets)
        tag_names = {child.tag for child in widgets}
        for required in ["view", "button", "slider", "monitor", "plot", "switch"]:
            self.assertIn(required, tag_names, f"Missing <{required}> widget")

    def test_step_button_exists(self) -> None:
        root = _parse_model()
        widgets = root.find("widgets")
        buttons = widgets.findall("button")
        step_buttons = [b for b in buttons if b.get("display") == "Step"]
        self.assertEqual(len(step_buttons), 1, "Expected exactly one Step button")
        self.assertEqual(step_buttons[0].get("forever"), "false")

    def test_agreement_monitors_exist(self) -> None:
        root = _parse_model()
        widgets = root.find("widgets")
        monitors = widgets.findall("monitor")
        displays = {m.get("display", "") for m in monitors}
        for label in ["Mesh Agreement %", "Hierarchy Agreement %", "Chain Agreement %"]:
            self.assertIn(label, displays, f"Missing monitor: {label}")

    def test_llm_status_monitor_exists(self) -> None:
        root = _parse_model()
        widgets = root.find("widgets")
        monitors = widgets.findall("monitor")
        displays = {m.get("display", "") for m in monitors}
        self.assertIn("LLM Status", displays)


# --- Code modernization tests ---


class CodeModernizationTests(unittest.TestCase):
    def test_no_while_i_loops_remain(self) -> None:
        code = _model_code()
        self.assertNotIn("while [i < length ordered]", code)

    def test_topology_index_uses_position(self) -> None:
        code = _model_code()
        self.assertIn("position name topology-order", code)
        self.assertNotIn("to-report topology-index", code)

    def test_use_llm_referenced_in_decide_belief(self) -> None:
        code = _model_code()
        self.assertIn("use-llm?", code)
        self.assertIn("use-llm? and llm-ready?", code)

    def test_foreach_range_used(self) -> None:
        code = _model_code()
        self.assertIn("foreach (range", code)

    def test_llm_status_reporter_exists(self) -> None:
        code = _model_code()
        self.assertIn("to-report llm-status", code)


# --- Per-agent decision tests ---


class PerAgentDecisionTests(unittest.TestCase):
    def test_llm_choose_exists_in_code(self) -> None:
        code = _model_code()
        self.assertIn("llm:choose", code)

    def test_link_neighbors_used_for_decisions(self) -> None:
        code = _model_code()
        self.assertIn("link-neighbors", code)

    def test_decide_belief_procedure_exists(self) -> None:
        code = _model_code()
        self.assertIn("to decide-belief", code)

    def test_decide_belief_llm_procedure_exists(self) -> None:
        code = _model_code()
        self.assertIn("to decide-belief-llm", code)

    def test_decide_belief_deterministic_procedure_exists(self) -> None:
        code = _model_code()
        self.assertIn("to decide-belief-deterministic", code)

    def test_initialize_agents_procedure_exists(self) -> None:
        code = _model_code()
        self.assertIn("to initialize-agents", code)

    def test_llm_set_history_used(self) -> None:
        code = _model_code()
        self.assertIn("llm:set-history", code)

    def test_belief_count_summary_reporter_exists(self) -> None:
        code = _model_code()
        self.assertIn("to-report belief-count-summary", code)

    def test_no_centralized_coordinator_code_remains(self) -> None:
        code = _model_code()
        self.assertNotIn("apply-coordinator-action", code)
        self.assertNotIn("BROADCAST_MAJORITY", code)
        self.assertNotIn("PAIR_SWAP", code)
        self.assertNotIn("SPLIT_REBALANCE", code)
        self.assertNotIn("coordinate-topology", code)
        self.assertNotIn("parse-action", code)
        self.assertNotIn("llm:chat-with-template", code)

    def test_simultaneous_update_via_previous_belief(self) -> None:
        code = _model_code()
        self.assertIn("previous-belief", code)
        self.assertIn("[previous-belief] of link-neighbors", code)

    def test_coordinator_template_file_deleted(self) -> None:
        template_path = DEMO_DIR / "coordinator-template.yaml"
        self.assertFalse(
            template_path.exists(),
            "coordinator-template.yaml should be deleted",
        )


# --- Model structure tests ---


class TopologyTournamentModelTests(unittest.TestCase):
    def test_required_breeds_exist(self) -> None:
        code = _model_code()
        self.assertIn("breed [mesh-agents mesh-agent]", code)
        self.assertIn("breed [hierarchy-agents hierarchy-agent]", code)
        self.assertIn("breed [chain-agents chain-agent]", code)

    def test_llm_choose_call_exists(self) -> None:
        code = _model_code()
        self.assertIn("llm:choose", code)
        self.assertIn("belief-options", code)

    def test_topology_and_convergence_procedures_exist(self) -> None:
        code = _model_code()
        required_procedures = [
            "to build-mesh-topology",
            "to build-hierarchy-topology",
            "to build-chain-topology",
            "to decide-belief",
            "to check-all-convergence",
            "to-report converged?",
            "to-report convergence-time",
        ]
        for procedure in required_procedures:
            self.assertIn(procedure, code)

    def test_ui_defaults_reference_demo_config(self) -> None:
        content = MODEL_PATH.read_text(encoding="utf-8")
        self.assertIn("demos/topology-tournament/config.txt", content)


class ConfigTests(unittest.TestCase):
    def test_config_has_required_keys(self) -> None:
        config = _parse_config(CONFIG_PATH)
        for key in ["provider", "model", "temperature", "timeout_seconds"]:
            self.assertIn(key, config, f"Missing config key: {key}")


if __name__ == "__main__":
    unittest.main()
