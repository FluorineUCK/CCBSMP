"""Read-only regression tests against the imported snapshot."""
import unittest
from pathlib import Path
from unittest.mock import patch
from verify_pack import verify

ROOT = Path(__file__).resolve().parents[1]

class VerificationTests(unittest.TestCase):
    def test_snapshot_audit(self):
        verify(ROOT, allow_incomplete=True)

    def test_incomplete_release_is_blocked(self):
        import json
        report = json.loads((ROOT / 'tools/import-report.json').read_text(encoding='utf-8'))
        if report['unresolved_mods']:
            with self.assertRaisesRegex(ValueError, 'Release blocked'):
                verify(ROOT)
        else:
            verify(ROOT)

    def test_changed_index_is_rejected(self):
        original = Path.read_bytes
        def read(path):
            data = original(path)
            return data + b'\n' if path == ROOT / 'pack/index.toml' else data
        with patch.object(Path, 'read_bytes', read):
            with self.assertRaisesRegex(AssertionError, 'Index hash mismatch'):
                verify(ROOT, allow_incomplete=True)

    def test_changed_payload_is_rejected(self):
        original = Path.read_bytes
        target = next((ROOT / 'pack/mods').glob('*.pw.toml'))
        def read(path):
            data = original(path)
            return data + b'\n' if path.resolve() == target.resolve() else data
        with patch.object(Path, 'read_bytes', read):
            with self.assertRaises(AssertionError):
                verify(ROOT, allow_incomplete=True)

if __name__ == '__main__':
    unittest.main()
