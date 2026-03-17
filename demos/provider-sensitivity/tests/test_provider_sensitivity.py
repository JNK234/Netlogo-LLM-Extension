# ABOUTME: Test suite for the Telephone Game provider-sensitivity demo.
# ABOUTME: Validates XML structure, procedures, widgets, seed messages, and thinking mode support.

import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


DEMO_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = DEMO_DIR / "provider-sensitivity.nlogox"
CONFIG_PATH = DEMO_DIR / "config-multi-provider.txt"
README_PATH = DEMO_DIR / "README.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_model() -> ET.Element:
    """Parse the .nlogox model file as XML and return the root element."""
    return ET.parse(MODEL_PATH).getroot()


def model_code_only() -> str:
    """Extract the NetLogo code from the <code> CDATA section using XML parsing."""
    root = parse_model()
    code_elem = root.find("code")
    if code_elem is None or code_elem.text is None:
        raise AssertionError("unable to extract <code> content from model XML")
    return code_elem.text


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


class TestRequiredFiles(unittest.TestCase):
    """Validate that all required demo files exist."""

    def test_required_files_exist(self) -> None:
        required = [MODEL_PATH, CONFIG_PATH, README_PATH]
        for path in required:
            self.assertTrue(path.exists(), f"missing file: {path}")


class TestModelXmlParsing(unittest.TestCase):
    """Validate the .nlogox file using proper XML parsing."""

    def setUp(self) -> None:
        self.root = parse_model()

    def test_model_parses_as_valid_xml(self) -> None:
        self.assertEqual(self.root.tag, "model")

    def test_netlogo_version_is_7_0_3(self) -> None:
        version = self.root.get("version")
        self.assertEqual(version, "NetLogo 7.0.3")

    def test_code_element_contains_cdata_content(self) -> None:
        code_elem = self.root.find("code")
        self.assertIsNotNone(code_elem, "missing <code> element")
        self.assertIsNotNone(code_elem.text, "<code> element has no text content")
        self.assertIn("extensions [llm]", code_elem.text)

    def test_raw_file_preserves_cdata_wrapping(self) -> None:
        raw = read(MODEL_PATH)
        self.assertIn("<code><![CDATA[", raw)
        self.assertIn("]]></code>", raw)

    def test_required_top_level_sections_exist(self) -> None:
        required_sections = [
            "code", "widgets", "info", "turtleShapes", "linkShapes",
            "previewCommands",
        ]
        present = {child.tag for child in self.root}
        for section in required_sections:
            self.assertIn(section, present, f"missing top-level section: {section}")

    def test_info_section_not_empty(self) -> None:
        info = self.root.find("info")
        self.assertIsNotNone(info, "missing <info> section")
        self.assertTrue(
            info.text and len(info.text.strip()) > 0,
            "<info> section is empty",
        )

    def test_preview_commands_present(self) -> None:
        preview = self.root.find("previewCommands")
        self.assertIsNotNone(preview)
        self.assertIn("setup", preview.text)


class TestWidgets(unittest.TestCase):
    """Validate widget structure and types."""

    def setUp(self) -> None:
        self.widgets = parse_model().find("widgets")
        self.assertIsNotNone(self.widgets, "missing <widgets> section")

    def test_has_view(self) -> None:
        views = self.widgets.findall("view")
        self.assertEqual(len(views), 1, "expected exactly 1 view")

    def test_view_has_no_wrapping(self) -> None:
        view = self.widgets.find("view")
        self.assertEqual(view.get("wrappingAllowedX"), "false")
        self.assertEqual(view.get("wrappingAllowedY"), "false")

    def test_has_buttons(self) -> None:
        buttons = self.widgets.findall("button")
        displays = [b.get("display") for b in buttons]
        for expected in ["setup", "step", "go-all", "Show Results", "Provider Status"]:
            self.assertIn(expected, displays, f"missing button: {expected}")

    def test_has_forever_button(self) -> None:
        buttons = self.widgets.findall("button")
        forever_buttons = [b for b in buttons if b.get("forever") == "true"]
        self.assertGreaterEqual(len(forever_buttons), 1, "expected at least 1 forever button")

    def test_has_chooser(self) -> None:
        choosers = self.widgets.findall("chooser")
        self.assertEqual(len(choosers), 1, "expected 1 chooser")
        chooser = choosers[0]
        self.assertEqual(chooser.get("variable"), "message-type")
        choices = [c.get("value") for c in chooser.findall("choice")]
        for cat in ["factual", "nuanced", "instructional", "creative", "controversial", "custom"]:
            self.assertIn(cat, choices, f"missing choice: {cat}")

    def test_has_slider(self) -> None:
        sliders = self.widgets.findall("slider")
        self.assertGreaterEqual(len(sliders), 1, "expected at least 1 slider")
        variables = [s.get("variable") for s in sliders]
        self.assertIn("chain-length", variables)

    def test_has_switches(self) -> None:
        switches = self.widgets.findall("switch")
        variables = [s.get("variable") for s in switches]
        self.assertIn("show-labels?", variables)
        self.assertIn("thinking-mode?", variables)

    def test_has_monitors(self) -> None:
        monitors = self.widgets.findall("monitor")
        self.assertGreaterEqual(len(monitors), 3, "expected at least 3 monitors")

    def test_has_plots(self) -> None:
        plots = self.widgets.findall("plot")
        self.assertGreaterEqual(len(plots), 2, "expected at least 2 plots")
        displays = [p.get("display") for p in plots]
        self.assertTrue(
            any("drift" in d.lower() for d in displays),
            "expected a drift plot",
        )

    def test_has_input(self) -> None:
        inputs = self.widgets.findall("input")
        self.assertGreaterEqual(len(inputs), 1, "expected at least 1 input")
        variables = [i.get("variable") for i in inputs]
        self.assertIn("custom-message", variables)

    def test_has_output_area(self) -> None:
        outputs = self.widgets.findall("output")
        self.assertGreaterEqual(len(outputs), 1, "expected at least 1 output widget")


class TestCoreProcedures(unittest.TestCase):
    """Validate required procedures exist in the NetLogo code."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_required_procedures_exist(self) -> None:
        procedures = [
            "to setup",
            "to go",
            "to process-chain-step",
            "to process-thinking-chain-step",
            "to show-final-results",
            "to show-provider-status",
            "to update-all-visuals",
            "to refresh-ready-providers",
            "to-report get-seed-message",
            "to-report get-default-model",
            "to-report compute-drift",
            "to-report to-word-set",
            "to-report split-on-spaces",
            "to-report replace-all-chars",
            "to-report count-intersection",
            "to-report count-union",
            "to-report truncate-string",
        ]
        for proc in procedures:
            self.assertIn(proc, self.code, f"missing procedure: {proc}")

    def test_all_procedure_blocks_are_closed(self) -> None:
        opens = len(re.findall(r"^to(?:-report)?\s", self.code, re.MULTILINE))
        closes = len(re.findall(r"^end\s*$", self.code, re.MULTILINE))
        self.assertEqual(
            opens, closes,
            f"mismatched procedure blocks: {opens} opens vs {closes} ends",
        )

    def test_extensions_declaration_present(self) -> None:
        self.assertIn("extensions [llm]", self.code)

    def test_directed_link_breed_declared(self) -> None:
        self.assertIn("directed-link-breed [chain-links chain-link]", self.code)

    def test_turtles_own_has_expected_vars(self) -> None:
        self.assertIn("turtles-own", self.code)
        for var in ["provider-name", "chain-position", "current-message",
                     "original-message", "drift-score", "processed?",
                     "error?", "thinking-trace"]:
            self.assertIn(var, self.code, f"missing turtle variable: {var}")

    def test_globals_declared(self) -> None:
        self.assertIn("globals [", self.code)
        for g in ["ready-providers-list", "current-step", "seed-message",
                   "all-chains-complete?", "active-provider", "thinking-provider"]:
            self.assertIn(g, self.code, f"missing global: {g}")


class TestSeedMessages(unittest.TestCase):
    """Validate seed message categories."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_all_message_categories_present(self) -> None:
        for category in ["factual", "nuanced", "instructional",
                         "creative", "controversial", "custom"]:
            self.assertIn(
                f'message-type = "{category}"',
                self.code,
                f"missing message category: {category}",
            )

    def test_factual_message_has_numbers(self) -> None:
        self.assertIn("13,000", self.code)

    def test_nuanced_message_has_hedging(self) -> None:
        self.assertIn("some studies suggest", self.code.lower())

    def test_instructional_message_has_steps(self) -> None:
        self.assertIn("omelette", self.code.lower())

    def test_creative_message_has_imagery(self) -> None:
        self.assertIn("lighthouse", self.code.lower())

    def test_controversial_message_has_dual_view(self) -> None:
        code_lower = self.code.lower()
        self.assertIn("universal basic income", code_lower)
        self.assertIn("critics", code_lower)


class TestThinkingMode(unittest.TestCase):
    """Validate thinking mode support."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_thinking_primitives_used(self) -> None:
        self.assertIn("llm:set-thinking", self.code)
        self.assertIn("llm:chat-with-thinking", self.code)

    def test_thinking_provider_global(self) -> None:
        self.assertIn("thinking-provider", self.code)

    def test_thinking_chain_step_procedure(self) -> None:
        self.assertIn("to process-thinking-chain-step", self.code)

    def test_thinking_trace_stored(self) -> None:
        self.assertIn("thinking-trace", self.code)


class TestNoDeprecatedPrimitives(unittest.TestCase):
    """Guard against usage of removed or renamed LLM extension primitives."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_no_deprecated_primitives(self) -> None:
        deprecated = ["llm:ask", "llm:send", "llm:query", "llm:prompt"]
        for prim in deprecated:
            self.assertNotIn(prim, self.code, f"deprecated primitive: {prim}")


class TestConfigFile(unittest.TestCase):
    """Validate config file structure."""

    def test_config_has_required_keys(self) -> None:
        config = parse_config(CONFIG_PATH)
        for key in ["provider", "model", "temperature", "max_tokens", "timeout_seconds"]:
            self.assertIn(key, config, f"missing key in config: {key}")


class TestReadme(unittest.TestCase):
    """Validate README content."""

    def test_readme_has_core_sections(self) -> None:
        readme = read(README_PATH)
        for text in ["Telephone Game", "Setup", "Thinking Mode", "Test Suite"]:
            self.assertIn(text, readme, f"missing README section: {text}")


if __name__ == "__main__":
    unittest.main()
