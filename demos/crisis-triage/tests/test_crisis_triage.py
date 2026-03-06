import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


DEMO_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = DEMO_DIR / "crisis-triage.nlogox"
TRIAGE_TEMPLATE_PATH = DEMO_DIR / "triage-template.yaml"
DISPATCHER_TEMPLATE_PATH = DEMO_DIR / "dispatcher-template.yaml"
CONFIG_PATH = DEMO_DIR / "config.txt"
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


class TestModelXmlParsing(unittest.TestCase):
    """Validate the .nlogox file using proper XML parsing instead of regex."""

    def setUp(self) -> None:
        self.root = parse_model()

    def test_model_parses_as_valid_xml(self) -> None:
        self.assertEqual(self.root.tag, "model")

    def test_code_element_contains_cdata_content(self) -> None:
        code_elem = self.root.find("code")
        self.assertIsNotNone(code_elem, "missing <code> element")
        self.assertIsNotNone(code_elem.text, "<code> element has no text content")
        self.assertIn("extensions [ llm ]", code_elem.text)

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
        self.assertIn("monitor", child_tags)

    def test_widgets_button_count(self) -> None:
        widgets = self.root.find("widgets")
        buttons = widgets.findall("button")
        self.assertEqual(len(buttons), 3, "expected 3 buttons: setup, go, new-case")

    def test_widgets_monitor_count(self) -> None:
        widgets = self.root.find("widgets")
        monitors = widgets.findall("monitor")
        self.assertGreaterEqual(len(monitors), 7, "expected at least 7 monitors")

    def test_turtle_shapes_defined(self) -> None:
        shapes = self.root.find("turtleShapes")
        self.assertIsNotNone(shapes, "missing <turtleShapes> section")
        shape_names = [s.get("name") for s in shapes.findall("shape")]
        self.assertIn("default", shape_names)
        self.assertIn("circle", shape_names)


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


class TestBehaviorRegression(unittest.TestCase):
    """Catch regressions in model syntax and LLM extension usage patterns."""

    def setUp(self) -> None:
        self.code = model_code_only()

    def test_extensions_declaration_present(self) -> None:
        self.assertIn("extensions [ llm ]", self.code)

    def test_chat_with_template_uses_list_syntax(self) -> None:
        """Ensure llm:chat-with-template uses (list ...) not [...] for variables."""
        lines = self.code.splitlines()
        for line in lines:
            stripped = line.strip()
            if "llm:chat-with-template" not in stripped:
                continue
            # The template call should be followed by (list on the same or next
            # logical line.  It must NOT use bracket syntax like [["key" val]].
            self.assertNotRegex(
                stripped,
                r'llm:chat-with-template\s+\S+\s+\[\[',
                f"bracket syntax found instead of (list ...): {stripped}",
            )

    def test_no_inline_provider_setup_in_procedures(self) -> None:
        """Model should use llm:load-config, not manual set-provider/set-api-key."""
        for deprecated in ["llm:set-provider", "llm:set-api-key", "llm:set-model"]:
            self.assertNotIn(
                deprecated,
                self.code,
                f"deprecated inline primitive found: {deprecated}",
            )

    def test_all_procedure_blocks_are_closed(self) -> None:
        """Every 'to' or 'to-report' must have a matching 'end'."""
        opens = len(re.findall(r"^to(?:-report)?\s", self.code, re.MULTILINE))
        closes = len(re.findall(r"^end\s*$", self.code, re.MULTILINE))
        self.assertEqual(
            opens,
            closes,
            f"mismatched procedure blocks: {opens} opens vs {closes} ends",
        )

    def test_no_deprecated_primitives(self) -> None:
        """Guard against usage of removed or renamed LLM extension primitives."""
        deprecated = [
            "llm:ask",
            "llm:send",
            "llm:query",
            "llm:prompt",
        ]
        for prim in deprecated:
            self.assertNotIn(prim, self.code, f"deprecated primitive: {prim}")

    def test_globals_declared(self) -> None:
        self.assertIn("globals [", self.code)
        for g in ["llm-ready?", "config-path", "triage-template-path",
                   "dispatcher-template-path"]:
            self.assertIn(g, self.code, f"missing global: {g}")

    def test_breed_owns_blocks_present(self) -> None:
        self.assertIn("turtles-own [", self.code)
        self.assertIn("cases-own [", self.code)


if __name__ == "__main__":
    unittest.main()
