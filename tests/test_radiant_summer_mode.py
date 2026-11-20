#!/usr/bin/env python3
"""Static regression checks for the seasonal radiant-heating control path.

These tests do not operate relays or simulate a Raspberry Pi. They verify
important code invariants pending hardware-backed integration tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / "html"


class RadiantSummerModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = (ROOT / "io2db.pl").read_text()
        cls.setup = (ROOT / "setup.html").read_text()
        cls.heating = (ROOT / "heating.html").read_text()

    def test_radiant_controls_run_before_summer_cooling(self):
        backend = self.backend
        self.assertNotIn("if ($summer_time == 1) {goto SUMMER;}", backend)
        self.assertLess(backend.index("HEAT_RELAYS:"), backend.index("if ($summer_time != 1) { goto END; }"))
        self.assertLess(backend.index("if ($summer_time != 1) { goto END; }"), backend.index("SUMMER:"))

    def test_boiler_warmup_is_preserved(self):
        self.assertIn("if ($min_count >= 5)", self.backend)
        self.assertIn("update navien set value = 1", self.backend)
        self.assertIn("update navien set min_count = 0", self.backend)

    def test_cooling_skips_radiant_active_zones(self):
        self.assertIn("select id, value from heat where id between 1 and 5", self.backend)
        self.assertIn("$radiant_active[$i-1] ? 0 : 1", self.backend)

    def test_heating_toggle_has_no_airflow_gate(self):
        self.assertIn("if(um[5] != '1')", self.setup)
        self.assertIn("if(um[5] == '1')", self.setup)
        self.assertNotIn("um[5] != '1' && winter == 1", self.setup)
        self.assertNotIn("um[5] == '1' && winter == 1", self.setup)

    def test_heating_page_uses_radiant_setpoint(self):
        self.assertIn("var winter = 1;", self.heating)
        self.assertIn("RADIANT HEATING:", self.heating)
        self.assertIn("heat[N * k + 2 + (1 - winter)]", self.heating)


if __name__ == "__main__":
    unittest.main()
