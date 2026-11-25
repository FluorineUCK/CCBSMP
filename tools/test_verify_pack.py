"""Read-only regression tests against the imported snapshot."""
import unittest
from pathlib import Path
from unittest.mock import patch
from verify_pack import verify

ROOT = Path(__file__).resolve().parents[1]

class VerificationTests(unittest.TestCase):
    def test_missing_archived_class_is_rejected(self):
        from verify_pack import verify_patch_sources
        with self.assertRaisesRegex(AssertionError, 'class_source'):
            verify_patch_sources(ROOT, [{'path': 'hotai/example.badiff'}])

    def test_changed_archived_class_is_rejected(self):
        import json
        from verify_pack import verify_patch_sources
        record = json.loads((ROOT / 'tools/hotai/patches.lock.json').read_text(encoding='utf-8'))[0]
        record['class_source']['sha256'] = '0' * 64
        with self.assertRaises(AssertionError):
            verify_patch_sources(ROOT, [record])

    def test_resource_lock_mismatch_is_rejected(self):
        import json
        original = Path.read_text
        def read(path, *args, **kwargs):
            data = original(path, *args, **kwargs)
            if path == ROOT / 'tools/resources.lock.json':
                rows = json.loads(data)
                rows[0]['sha256'] = '0' * 64
                return json.dumps(rows)
            return data
        with patch.object(Path, 'read_text', read):
            with self.assertRaises(AssertionError):
                verify(ROOT)

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
