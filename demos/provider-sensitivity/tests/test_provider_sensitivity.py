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


class TestProviderSensitivityArtifacts(unittest.TestCase):
    """Validate that all required demo files exist and contain expected content."""

    def test_required_files_exist(self) -> None:
        required = [MODEL_PATH, CONFIG_PATH, README_PATH]
        for path in required:
            self.assertTrue(path.exists(), f"missing file: {path}")

    def test_model_contains_required_procedures(self) -> None:
        code = model_code_only()
        procedures = [
            "to setup",
            "to go",
            "to run-single-provider",
            "to show-results",
            "to compare-choose",
            "to compare-single",
            "to show-provider-status",
            "to activate-provider",
            "to use-openai",
            "to use-anthropic",
            "to use-gemini",
            "to use-ollama",
            "to cycle-provider",
            "to-report build-prompt-bank",
            "to-report get-default-model",
            "to-report truncate-string",
            "to-report estimate-cost-usd",
            "to-report score-response",
        ]
        for proc in procedures:
            self.assertIn(proc, code, f"missing procedure: {proc}")

    def test_config_has_required_keys(self) -> None:
        config = parse_config(CONFIG_PATH)
        for key in ["provider", "model", "temperature", "max_tokens", "timeout_seconds"]:
            self.assertIn(key, config, f"missing key in config: {key}")

    def test_readme_has_core_sections(self) -> None:
        readme = read(README_PATH)
        for text in [
            "Provider Sensitivity",
            "Setup",
            "Test suite",
        ]:
            self.assertIn(text, readme)


class TestModelXmlParsing(unittest.TestCase):
    """Validate the .nlogox file using proper XML parsing."""

    def setUp(self) -> None:
        self.root = parse_model()

    def test_model_parses_as_valid_xml(self) -> None:
        self.assertEqual(self.root.tag, "model")

    def test_code_element_contains_cdata_content(self) -> None:
        code_elem = self.root.find("code")
        self.assertIsNotNone(code_elem, "missing <code> element")
        self.assertIsNotNone(code_elem.text, "<code> element has no text content")
        self.assertIn("extensions [llm]", code_elem.text)

    def test_raw_file_preserves_cdata_wrapping(self) -> None:
        raw = read(MODEL_PATH)
        self.assertIn("<code><![CDATA[", raw)
        self.assertIn("]]></code>", raw)

    def test_widgets_section_has_expected_children(self) -> None:
        widgets = self.root.find("widgets")
        self.assertIsNotNone(widgets, "missing <widgets> section")
        child_tags = [child.tag for child in widgets]
        self.assertIn("view", child_tags)
        self.assertIn("button", child_tags)
        self.assertIn("chooser", child_tags)
        self.assertIn("input", child_tags)

    def test_widgets_button_count(self) -> None:
        widgets = self.root.find("widgets")
        buttons = widgets.findall("button")
        self.assertEqual(
            len(buttons), 12,
            f"expected 12 buttons, got {len(buttons)}: "
            + str([b.get("display") for b in buttons]),
        )

    def test_widgets_has_chooser(self) -> None:
        widgets = self.root.find("widgets")
        choosers = widgets.findall("chooser")
        self.assertEqual(len(choosers), 1, "expected 1 chooser (prompt-category)")
        chooser = choosers[0]
        self.assertEqual(chooser.get("variable"), "prompt-category")
        choices = [c.get("value") for c in chooser.findall("choice")]
        self.assertEqual(choices, ["factual", "creative", "reasoning", "decision"])

    def test_widgets_has_inputbox(self) -> None:
        widgets = self.root.find("widgets")
        inputs = widgets.findall("input")
        self.assertGreaterEqual(len(inputs), 1, "expected at least 1 input (custom-prompt)")
        variables = [i.get("variable") for i in inputs]
        self.assertIn("custom-prompt", variables)


class TestModelStructure(unittest.TestCase):
    """Structural assertions on the NetLogo 7.x .nlogox format."""

    def setUp(self) -> None:
        self.root = parse_model()

    def test_netlogo_version_is_7_0_3(self) -> None:
        version = self.root.get("version")
        self.assertEqual(version, "NetLogo 7.0.3")

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

    def test_link_shapes_has_default(self) -> None:
        link_shapes = self.root.find("linkShapes")
        self.assertIsNotNone(link_shapes, "missing <linkShapes>")
        names = [s.get("name") for s in link_shapes.findall("shape")]
        self.assertIn("default", names)

    def test_turtle_shapes_has_default(self) -> None:
        shapes = self.root.find("turtleShapes")
        self.assertIsNotNone(shapes, "missing <turtleShapes>")
        names = [s.get("name") for s in shapes.findall("shape")]
        self.assertIn("default", names)


class TestBehaviorRegression(unittest.TestCase):
    """Catch regressions in model syntax and LLM extension usage patterns."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_extensions_declaration_present(self) -> None:
        self.assertIn("extensions [llm]", self.code)

    def test_no_deprecated_primitives(self) -> None:
        """Guard against usage of removed or renamed LLM extension primitives."""
        deprecated = ["llm:ask", "llm:send", "llm:query", "llm:prompt"]
        for prim in deprecated:
            self.assertNotIn(prim, self.code, f"deprecated primitive: {prim}")

    def test_all_procedure_blocks_are_closed(self) -> None:
        """Every 'to' or 'to-report' must have a matching 'end'."""
        opens = len(re.findall(r"^to(?:-report)?\s", self.code, re.MULTILINE))
        closes = len(re.findall(r"^end\s*$", self.code, re.MULTILINE))
        self.assertEqual(
            opens,
            closes,
            f"mismatched procedure blocks: {opens} opens vs {closes} ends",
        )

    def test_globals_declared(self) -> None:
        self.assertIn("globals [", self.code)
        for g in ["prompt-bank", "comparison-results", "ready-providers-list",
                   "run-complete?", "active-provider"]:
            self.assertIn(g, self.code, f"missing global: {g}")

    def test_prompt_bank_covers_all_categories(self) -> None:
        """Verify the prompt bank handles all four prompt categories."""
        for category in ["factual", "creative", "reasoning", "decision"]:
            self.assertIn(
                f'prompt-category = "{category}"',
                self.code,
                f"missing prompt category: {category}",
            )

    def test_provider_switching_procedures_exist(self) -> None:
        """Runtime provider switching is the core feature of this demo."""
        for proc in ["to use-openai", "to use-anthropic", "to use-gemini",
                      "to use-ollama", "to cycle-provider"]:
            self.assertIn(proc, self.code, f"missing provider switching procedure: {proc}")

    def test_score_response_checks_known_prompts(self) -> None:
        """Quality scoring should check for known factual answers."""
        for keyword in ["capital of france", "photosynthesis", "paris",
                         "bat and a ball", "wallet"]:
            self.assertIn(keyword, self.code.lower(),
                          f"score-response missing check for: {keyword}")

    def test_estimate_cost_uses_provider_pricing(self) -> None:
        """Cost estimation needs per-provider pricing data."""
        self.assertIn("to-report provider-pricing", self.code)
        self.assertIn("to-report estimate-cost-usd", self.code)
        for provider in ["openai", "anthropic", "gemini", "ollama"]:
            self.assertIn(
                f'provider-name = "{provider}"',
                self.code,
                f"provider-pricing missing entry for: {provider}",
            )

    def test_runtime_provider_set_calls_are_intentional(self) -> None:
        """This demo intentionally uses llm:set-provider for runtime switching.
        Verify the calls exist in the correct procedures (activate-provider and
        run-single-provider), not in arbitrary locations."""
        self.assertIn("llm:set-provider", self.code)
        self.assertIn("llm:set-model", self.code)
        # Verify they appear within the expected procedures
        lines = self.code.splitlines()
        set_provider_contexts = []
        current_proc = None
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("to ") or stripped.startswith("to-report "):
                current_proc = stripped
            elif stripped == "end":
                current_proc = None
            if "llm:set-provider" in stripped and current_proc:
                set_provider_contexts.append(current_proc)
        # set-provider should only appear in activate-provider, run-single-provider,
        # and compare-choose
        for ctx in set_provider_contexts:
            self.assertTrue(
                any(name in ctx for name in [
                    "activate-provider", "run-single-provider", "compare-choose",
                ]),
                f"llm:set-provider found in unexpected procedure: {ctx}",
            )


if __name__ == "__main__":
    unittest.main()
