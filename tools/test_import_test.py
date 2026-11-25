"""Importer regressions: keep reviewed patch identity and validate resource inputs."""
import tempfile
import unittest
from pathlib import Path
import import_test as importer


class ImportTests(unittest.TestCase):
    def test_oe_rule_roots_are_managed(self):
        self.assertTrue({'oei', 'oeb', 'oef'}.issubset(importer.CONTENT_FOLDERS))

    def test_preserves_patch_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            (source / 'hotai').mkdir()
            (source / 'mods').mkdir()
            (source / 'hotai/example.badiff').write_bytes(b'patch')
            (source / 'mods/target.jar').write_bytes(b'target')
            row = dict(path='hotai/example.badiff', sha256=importer.sha(b'patch'),
                       target_file='target.jar', target_jar_sha256=importer.sha(b'target'),
                       side='both', target_mod_id='ragdoll', target_enabled=True,
                       runtime_verified=True, note='Limited smoke test only')
            self.assertEqual(importer.reviewed_patches(source, [row]), [row])
            (source / 'hotai/example.badiff').write_bytes(b'changed')
            with self.assertRaises(ValueError):
                importer.reviewed_patches(source, [row])

    def test_unknown_patch_requires_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            (source / 'hotai').mkdir()
            (source / 'hotai/unknown.class').write_bytes(b'patch')
            with self.assertRaises(ValueError):
                importer.reviewed_patches(source, [])

    def test_resource_hash_and_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            (source / 'resourcepacks').mkdir()
            (source / 'resourcepacks/gui.zip').write_bytes(b'resource')
            row = dict(path='resourcepacks/gui.zip', sha256=importer.sha(b'resource'))
            importer.validate_resources(source, [row])
            with self.assertRaises(ValueError):
                importer.validate_resources(source, [row | {'sha256': '0' * 64}])
            with self.assertRaises(ValueError):
                importer.validate_resources(source, [row | {'path': '../gui.zip'}])


if __name__ == '__main__':
    unittest.main()
