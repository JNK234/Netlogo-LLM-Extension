#!/usr/bin/env python3
"""
Validation test suite for flocking-boids.nlogox conversion.

Tests cover:
- XML structure and parsing
- Code section integrity
- Widget definitions and defaults
- Data type preservation
- Behavior regression
"""

import unittest
import xml.etree.ElementTree as ET
import os
from pathlib import Path


class TestFlockingBoidsNLOGOX(unittest.TestCase):
    """Test suite for flocking-boids.nlogox format conversion."""

    @classmethod
    def setUpClass(cls):
        """Load the .nlogox file once for all tests."""
        test_dir = Path(__file__).parent
        cls.nlogox_path = test_dir / "flocking-boids.nlogox"
        cls.nlogo_path = test_dir / "flocking-boids.nlogo"
        
        # Parse XML
        try:
            cls.tree = ET.parse(str(cls.nlogox_path))
            cls.root = cls.tree.getroot()
        except ET.ParseError as e:
            raise RuntimeError(f"Failed to parse {cls.nlogox_path}: {e}")

    def test_file_exists(self):
        """Test that flocking-boids.nlogox exists."""
        self.assertTrue(self.nlogox_path.exists(), 
                       f"File {self.nlogox_path} does not exist")

    def test_file_is_valid_xml(self):
        """Test that the file is valid, well-formed XML."""
        try:
            ET.parse(str(self.nlogox_path))
        except ET.ParseError as e:
            self.fail(f"Invalid XML: {e}")

    def test_root_element_is_model(self):
        """Test that root element is <model>."""
        self.assertEqual(self.root.tag, 'model',
                        f"Root element should be 'model', got '{self.root.tag}'")

    def test_model_version_attribute(self):
        """Test that model has a version attribute."""
        version = self.root.get('version')
        self.assertIsNotNone(version, "Model must have a version attribute")
        self.assertTrue(version.startswith('NetLogo 7'),
                       f"Version should be NetLogo 7+, got {version}")

    def test_model_snaptogrid_attribute(self):
        """Test that model has snapToGrid attribute."""
        snap = self.root.get('snapToGrid')
        self.assertIsNotNone(snap, "Model must have snapToGrid attribute")
        self.assertIn(snap.lower(), ['true', 'false'],
                     f"snapToGrid must be true/false, got {snap}")

    def test_code_section_exists(self):
        """Test that model contains a <code> section."""
        code = self.root.find('code')
        self.assertIsNotNone(code, "Model must have a <code> section")

    def test_code_section_not_empty(self):
        """Test that code section has content."""
        code = self.root.find('code')
        self.assertIsNotNone(code.text, "Code section must not be empty")
        self.assertGreater(len(code.text.strip()), 0,
                          "Code section must have non-empty content")

    def test_code_contains_breed_definition(self):
        """Test that code contains breed definition for boids."""
        code = self.root.find('code').text
        self.assertIn('breed [boids boid]', code,
                     "Code must contain breed definition for boids")

    def test_code_contains_setup_procedure(self):
        """Test that code contains setup procedure."""
        code = self.root.find('code').text
        self.assertIn('to setup', code,
                     "Code must contain setup procedure")
        self.assertIn('create-boids', code,
                     "Setup must create boids")

    def test_code_contains_go_procedure(self):
        """Test that code contains go procedure."""
        code = self.root.find('code').text
        self.assertIn('to go', code,
                     "Code must contain go procedure")

    def test_code_contains_boids_variables(self):
        """Test that code defines boid variables."""
        code = self.root.find('code').text
        for var in ['vx', 'vy', 'next-vx', 'next-vy']:
            self.assertIn(var, code,
                         f"Code must define boid variable '{var}'")

    def test_code_contains_flocking_rules(self):
        """Test that code contains all three flocking rules."""
        code = self.root.find('code').text
        for rule in ['boids-separation', 'boids-alignment', 'boids-cohesion']:
            self.assertIn(rule, code,
                         f"Code must contain {rule} procedure")

    def test_widgets_section_exists(self):
        """Test that model contains widgets section."""
        widgets = self.root.find('widgets')
        self.assertIsNotNone(widgets, "Model must have <widgets> section")

    def test_graphics_window_exists(self):
        """Test that widgets contain a graphics/view widget."""
        widgets = self.root.find('widgets')
        view = widgets.find(".//*[@tag='graphics-window']")
        self.assertIsNotNone(view, "Widgets must contain graphics-window")

    def test_graphics_window_has_scale(self):
        """Test that graphics window has scale element."""
        widgets = self.root.find('widgets')
        view = widgets.find(".//*[@tag='graphics-window']")
        scale = view.find('scale')
        self.assertIsNotNone(scale, "Graphics window must have scale element")
        self.assertIsNotNone(scale.text, "Scale must have a value")

    def test_required_sliders_exist(self):
        """Test that all required sliders are defined."""
        widgets = self.root.find('widgets')
        required_sliders = [
            'num-boids-slider',
            'max-speed-slider',
            'separation-radius-slider',
            'alignment-radius-slider',
            'cohesion-radius-slider',
            'separation-weight-slider',
            'alignment-weight-slider',
            'cohesion-weight-slider'
        ]
        for slider_tag in required_sliders:
            slider = widgets.find(f".//*[@tag='{slider_tag}']")
            self.assertIsNotNone(slider,
                               f"Widgets must contain {slider_tag}")

    def test_slider_has_variable_name(self):
        """Test that sliders have variable name elements."""
        widgets = self.root.find('widgets')
        sliders = widgets.findall(".//*[@type='slider']")
        self.assertGreater(len(sliders), 0, "Must have at least one slider")
        for slider in sliders:
            varname = slider.find('varname')
            self.assertIsNotNone(varname,
                               "Slider must have varname element")
            self.assertIsNotNone(varname.text,
                               "Slider varname must have text")

    def test_slider_has_value_and_range(self):
        """Test that sliders have value, min, max, and step."""
        widgets = self.root.find('widgets')
        sliders = widgets.findall(".//*[@type='slider']")
        for slider in sliders:
            elements = ['value', 'min', 'max', 'step']
            for elem in elements:
                e = slider.find(elem)
                self.assertIsNotNone(e, f"Slider must have {elem}")
                self.assertIsNotNone(e.text, f"Slider {elem} must have value")

    def test_buttons_exist(self):
        """Test that setup and go buttons are defined."""
        widgets = self.root.find('widgets')
        buttons = widgets.findall(".//*[@type='button']")
        self.assertGreaterEqual(len(buttons), 2,
                              "Must have at least setup and go buttons")
        
        button_commands = [b.find('commands').text for b in buttons]
        self.assertIn('setup', button_commands,
                     "Must have setup button")
        self.assertIn('go', button_commands,
                     "Must have go button")

    def test_monitors_exist(self):
        """Test that monitors are defined."""
        widgets = self.root.find('widgets')
        monitors = widgets.findall(".//*[@type='monitor']")
        self.assertGreaterEqual(len(monitors), 2,
                              "Must have at least 2 monitors")
        
        monitor_labels = [m.find('label').text for m in monitors]
        self.assertIn('avg-speed', monitor_labels,
                     "Must have avg-speed monitor")
        self.assertIn('flock-size', monitor_labels,
                     "Must have flock-size monitor")

    def test_preview_commands_exist(self):
        """Test that preview commands are defined."""
        preview = self.root.find('previewCommands')
        self.assertIsNotNone(preview,
                            "Model must have previewCommands")
        commands = preview.findall('command')
        self.assertGreater(len(commands), 0,
                          "Must have at least one preview command")

    def test_info_section_exists(self):
        """Test that info/documentation section exists."""
        info = self.root.find('info')
        self.assertIsNotNone(info, "Model must have <info> section")
        self.assertIsNotNone(info.text, "Info must have content")

    def test_info_contains_description(self):
        """Test that info section contains model description."""
        info = self.root.find('info').text
        self.assertIn('boids', info.lower(),
                     "Info must mention boids")
        self.assertIn('flock', info.lower(),
                     "Info must mention flocking")

    def test_turtle_shapes_exist(self):
        """Test that turtle shapes are defined."""
        shapes = self.root.find('turtleShapes')
        self.assertIsNotNone(shapes, "Model must have turtleShapes")
        shape_list = shapes.findall('turtleShape')
        self.assertGreater(len(shape_list), 0,
                          "Must have at least one turtle shape")

    def test_triangle_shape_exists(self):
        """Test that triangle shape is defined (used for boids)."""
        shapes = self.root.find('turtleShapes')
        triangle = shapes.find(".//*[name='triangle']")
        self.assertIsNotNone(triangle,
                            "Must have triangle shape for boids")

    def test_shape_has_polygon(self):
        """Test that shapes have polygon definitions."""
        shapes = self.root.find('turtleShapes')
        for shape in shapes.findall('turtleShape'):
            polygon = shape.find('polygon')
            self.assertIsNotNone(polygon,
                               f"Shape {shape.find('name').text} must have polygon")
            points = polygon.findall('point')
            self.assertGreater(len(points), 0,
                             "Polygon must have points")

    def test_linkshapes_section_exists(self):
        """Test that linkShapes section exists."""
        linkshapes = self.root.find('linkShapes')
        self.assertIsNotNone(linkshapes, "Model must have <linkShapes> section")

    def test_xml_encoding_is_utf8(self):
        """Test that XML declares UTF-8 encoding."""
        with open(str(self.nlogox_path), 'r') as f:
            first_line = f.readline()
            self.assertIn('utf-8', first_line.lower(),
                         "XML must declare UTF-8 encoding")

    def test_code_section_uses_cdata(self):
        """Test that code section properly uses CDATA."""
        with open(str(self.nlogox_path), 'r') as f:
            content = f.read()
            self.assertIn('<![CDATA[', content,
                         "Code should use CDATA section")
            self.assertIn(']]>', content,
                         "CDATA section must be properly closed")

    def test_minimum_speed_calculation_preserved(self):
        """Test that minimum-speed calculation is preserved."""
        code = self.root.find('code').text
        self.assertIn('minimum-speed', code)
        self.assertIn('max-speed * 0.35', code,
                     "Minimum-speed formula must use max-speed * 0.35")

    def test_vector_speed_calculation_preserved(self):
        """Test that vector-speed calculation is preserved."""
        code = self.root.find('code').text
        self.assertIn('vector-speed', code)
        self.assertIn('sqrt', code,
                     "Vector-speed must use sqrt function")

    def test_wrapping_functions_preserved(self):
        """Test that world-wrapping functions are preserved."""
        code = self.root.find('code').text
        for func in ['wrapped-x', 'wrapped-y']:
            self.assertIn(func, code,
                         f"Code must preserve {func} function")

    def test_slider_values_match_original(self):
        """Test that default slider values match original .nlogo."""
        widgets = self.root.find('widgets')
        
        # Check num-boids default
        num_boids = widgets.find(".//*[@tag='num-boids-slider']")
        self.assertEqual(num_boids.find('value').text, '120',
                        "num-boids default should be 120")
        
        # Check max-speed default
        max_speed = widgets.find(".//*[@tag='max-speed-slider']")
        self.assertEqual(max_speed.find('value').text, '1.4',
                        "max-speed default should be 1.4")

    def test_file_size_reasonable(self):
        """Test that converted file size is reasonable (not corrupted)."""
        size = os.path.getsize(str(self.nlogox_path))
        # Original .nlogo was ~6500 bytes, XML should be larger due to markup
        self.assertGreater(size, 6000,
                          f"File size {size} seems too small")
        self.assertLess(size, 50000,
                       f"File size {size} seems too large")

    def test_conversion_completeness(self):
        """Integration test: verify all major components converted."""
        checks = {
            'code': self.root.find('code') is not None,
            'widgets': self.root.find('widgets') is not None,
            'info': self.root.find('info') is not None,
            'turtleShapes': self.root.find('turtleShapes') is not None,
            'preview': self.root.find('previewCommands') is not None,
        }
        
        for component, exists in checks.items():
            self.assertTrue(exists,
                          f"Missing critical component: {component}")


class TestBehaviorRegression(unittest.TestCase):
    """Test behavior consistency between .nlogo and .nlogox formats."""

    @classmethod
    def setUpClass(cls):
        """Load both file versions."""
        test_dir = Path(__file__).parent
        cls.nlogox_path = test_dir / "flocking-boids.nlogox"
        cls.nlogo_path = test_dir / "flocking-boids.nlogo"
        
        cls.tree = ET.parse(str(cls.nlogox_path))
        cls.root = cls.tree.getroot()

    def test_all_procedures_preserved(self):
        """Test that all procedures exist in converted code."""
        code = self.root.find('code').text
        required_procedures = [
            'setup', 'go', 'calculate-next-velocity',
            'boids-separation', 'boids-alignment', 'boids-cohesion',
            'apply-motion', 'clamp-speed', 'minimum-speed',
            'vector-speed', 'wrapped-x', 'wrapped-y',
            'avg-speed', 'flock-size'
        ]
        
        for proc in required_procedures:
            # Check for both 'to proc' and 'to-report proc'
            found = f'to {proc}' in code or f'to-report {proc}' in code
            self.assertTrue(found,
                           f"Missing procedure: {proc}")

    def test_all_boid_variables_preserved(self):
        """Test that all boid variables are defined."""
        code = self.root.find('code').text
        self.assertIn('boids-own', code,
                     "Must have boids-own variable definitions")
        
        required_vars = ['vx', 'vy', 'next-vx', 'next-vy']
        for var in required_vars:
            self.assertIn(var, code,
                         f"Missing boid variable: {var}")

    def test_physics_calculations_preserved(self):
        """Test that physics calculations are unchanged."""
        code = self.root.find('code').text
        
        # Test separation uses distance^2 weighting
        self.assertIn('distance myself + 0.05', code,
                     "Separation must use distance + 0.05 offset")
        self.assertIn('^ 2', code,
                     "Distance weighting must use ^2 exponent")
        
        # Test alignment computes mean velocity
        self.assertIn('mean [vx]', code,
                     "Alignment must compute mean vx")
        
        # Test cohesion uses direction averaging
        self.assertIn('towards myself + 180', code,
                     "Cohesion must use opposite direction")

    def test_speed_clamping_logic_preserved(self):
        """Test that speed clamping logic is unchanged."""
        code = self.root.find('code').text
        self.assertIn('if speed = 0', code,
                     "Must handle zero-speed case")
        self.assertIn('if speed > max-speed', code,
                     "Must clamp maximum speed")
        self.assertIn('if speed < minimum-speed', code,
                     "Must clamp minimum speed")

    def test_world_wrapping_logic_preserved(self):
        """Test that world wrapping is preserved."""
        code = self.root.find('code').text
        self.assertIn('max-pxcor', code,
                     "Must use max-pxcor for wrapping")
        self.assertIn('min-pxcor', code,
                     "Must use min-pxcor for wrapping")
        self.assertIn('max-pycor', code,
                     "Must use max-pycor for wrapping")
        self.assertIn('min-pycor', code,
                     "Must use min-pycor for wrapping")


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
