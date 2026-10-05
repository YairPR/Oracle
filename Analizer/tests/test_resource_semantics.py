"""Regression coverage for rates, classification and historical review signals."""
import tempfile
from pathlib import Path
import unittest
from test_oclumon_formats import block
from core.oclumon_model import parse
from core.oclumon_dataset import build
from core.episode_engine import detect_anomalias, build_episodios, build_timeline
from core.html_builder import display_clock, _capture_date


class ResourceSemantics(unittest.TestCase):
    def read(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'source.txt'
            path.write_text(text, encoding='utf-8')
            return parse(path)[0]

    def test_nic_rate_is_not_accumulated_or_assigned_private_role(self):
        text = block().replace('"type","latency[msec]"', '"type","latency[msec]","indiscarded[#/s]","outdiscarded[#/s]"').replace('"PRIVATE",<1', '"",<1,1,0')
        episodes = build_episodios(detect_anomalias(build(self.read(text + text.replace('10.30.00', '10.30.05')))))
        episode = next(e for e in episodes if e['cat'] == 'nic_discards')
        self.assertEqual(episode['peak_value'], 1)
        self.assertEqual(episode['value_kind'], 'rate')
        self.assertEqual(episode['total_value'], 0)
        self.assertIn('paquetes/s', episode['narrativa'])
        self.assertNotIn('acumularon', episode['narrativa'])
        self.assertNotIn('privada', episode['label'])
        from core.component_catalog import resolver_finding_type, resolver_panel_disparador
        self.assertEqual(resolver_finding_type('nic_discards'),'network')
        self.assertIsNone(resolver_panel_disparador('nic_discards'))

    def test_tcp_signal_has_matching_episode_and_timeline(self):
        text = block(counter='0') + block(counter='0',stamp='2026-10-05 10.30.05+0200').replace('100,4', '170,4')
        episodes = build_episodios(detect_anomalias(build(self.read(text))))
        episode = next(e for e in episodes if e['cat'] == 'tcp_retrans')
        self.assertEqual(episode['peak_value'], 70)
        self.assertEqual(episode['total_value'], 70)
        self.assertEqual(episode['sev'], 'warning')
        self.assertTrue(any(t['label'] == episode['label'] for t in build_timeline(episodes)))

    def test_cpu_fields_and_unavailable_legacy_are_distinct(self):
        text = block().replace('"nicErrors[#/s]","extra"', '"nicErrors[#/s]","cpusys[%]","cpuuser[%]","cpuiowait[%]","cpusteal[%]","#procs_blocked","extra"').replace('0,0,0,"a,b"', '0,0,0,3.24,9.34,0,0,2,"a,b"')
        sample = self.read(text)[0]
        self.assertEqual(sample['sys']['cpusys'], 3.24)
        self.assertEqual(sample['sys']['cpuuser'], 9.34)
        self.assertEqual(sample['sys']['procs_blocked'], 2)
        legacy = self.read("Node: old Clock: '09-30-26 02.35.04'\nSYSTEM:\ncpu: 2 physmemfree: 0\n")[0]
        self.assertNotIn('cpuuser', legacy['sys'])
        self.assertIsNone(legacy['sys']['memavl_mb'])

    def test_nic_metadata_runs_preserve_changes_and_capture_gaps(self):
        from core.episode_engine import nic_inventory
        samples = self.read(block() + block(stamp='2026-10-05 10.30.05+0200') + block(stamp='2026-10-05 11.30.00+0200'))
        runs = nic_inventory(build(samples))['host4']['eth0']
        self.assertEqual(len(runs),2)
        self.assertEqual(runs[0]['to']-runs[0]['from'],5)
        self.assertEqual(runs[1]['from'],runs[1]['to'])

    def test_tcp_sql_threshold_is_review_not_global_critical(self):
        from ai.engine import RootCauseEngine
        from unittest.mock import Mock
        engine = RootCauseEngine.__new__(RootCauseEngine)
        engine._query = Mock(side_effect=[[('NET_TCP_RETRA_SEG','host4',70)],[],[]])
        result = engine.calcular_estado_salud()
        self.assertEqual(result['estado'],'WARNING')
        self.assertIn('impacto no demostrado', result['motivos'][0])

    def test_capture_offset_and_unknown_clock_policy(self):
        clock = display_clock({'motor_episodios': {'time_domains': ['+0200']}})
        self.assertEqual(clock['offset_minutes'],120)
        self.assertEqual(_capture_date('2026-10-05T08:30:00',120,'%H:%M:%S'),'10:30:00')
        self.assertEqual(_capture_date('2026-10-05T10:30:00+02:00',120,'%H:%M:%S'),'10:30:00')
        for domains in [['unknown'],['+0200','-0700']]:
            self.assertEqual(display_clock({'motor_episodios':{'time_domains':domains}})['offset_minutes'],0)


if __name__ == '__main__':
    unittest.main()
