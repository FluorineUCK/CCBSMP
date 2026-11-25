"""Validate committed content and hashes; refuse incomplete publication by default."""
import argparse
import hashlib
import json
import tomllib
from pathlib import Path

def verify_patch_sources(root, patches):
    """Authoring artifacts are retained outside the runtime Hotai search path."""
    archive = (root / 'tools/hotai/artifacts').resolve()
    for patch in patches:
        assert patch.get('class_source'), 'Missing class_source: ' + patch['path']
        if patch['path'].endswith('.badiff'):
            assert patch.get('diff_source'), 'Missing diff_source: ' + patch['path']
        for key, suffix in (('class_source', '.class'), ('diff_source', '.badiff')):
            if not patch.get(key):
                continue
            row = patch[key]
            p = (root / row['path']).resolve()
            assert p.is_relative_to(archive) and p.is_file() and p.suffix == suffix, key
            payload = p.read_bytes()
            assert hashlib.sha256(payload).hexdigest() == row['sha256'], row['path']
            if suffix == '.class':
                assert payload.startswith(bytes.fromhex('cafebabe')), 'Not JVM bytecode'
            if patch['path'].endswith(suffix):
                assert row['sha256'] == patch['sha256'], 'Runtime/archive artifact differs'

def verify(root, allow_incomplete=False):
    pack = root / 'pack'
    config = tomllib.loads((pack / 'pack.toml').read_text(encoding='utf-8'))
    index = (pack / config['index']['file']).read_bytes()
    assert hashlib.sha256(index).hexdigest() == config['index']['hash'], 'Index hash mismatch'
    entries = tomllib.loads(index.decode())['files']
    seen = set()
    for e in entries:
        p = (pack / e['file']).resolve()
        assert p.is_relative_to(pack.resolve()) and p.is_file(), e['file']
        assert e['file'] not in seen, 'Duplicate index entry'
        seen.add(e['file'])
        assert hashlib.sha256(p.read_bytes()).hexdigest() == e['hash'], e['file']
        if e.get('metafile'):
            m = tomllib.loads(p.read_text(encoding='utf-8'))
            assert m['side'] in {'client', 'server', 'both'}
            assert (p.parent / m['filename']).resolve().is_relative_to(pack.resolve())
            assert m['download']['url'].startswith('https://')
            assert m['download']['hash-format'] == 'sha256' and len(m['download']['hash']) == 64
    actual = {p.relative_to(pack).as_posix() for p in pack.rglob('*') if p.is_file()
              and p.name not in {'.gitkeep', '.packwizignore', 'pack.toml', 'index.toml'}}
    assert actual == seen, 'Unindexed or stale files'
    report = json.loads((root / 'tools/import-report.json').read_text(encoding='utf-8'))
    locks = json.loads((root / 'tools/test-mods.lock.json').read_text(encoding='utf-8'))
    metas = [tomllib.loads(p.read_text(encoding='utf-8')) for p in (pack / 'mods').glob('*.pw.toml')]
    assert len(metas) == report['resolved_mods']
    by_name = {m['filename']: m for m in metas}
    assert len(by_name) == len(metas), 'Duplicate mod filename'
    assert set(by_name) == {r['filename'] for r in locks if r['url']}, 'Mod reference set differs from lock'
    assert len(locks) == report['active_mods_in_test'], 'Inventory count differs'
    for row in locks:
        if row['url']:
            assert by_name[row['filename']]['download']['hash'] == row['sha256']
            assert by_name[row['filename']]['download']['url'] == row['url']
            assert by_name[row['filename']]['side'] == row['side']
    resource_lock = root / 'tools/resources.lock.json'
    resources = json.loads(resource_lock.read_text(encoding='utf-8')) if resource_lock.exists() else []
    resource_metas = {}
    for folder in ('resourcepacks', 'shaderpacks'):
        for p in (pack / folder).glob('*.pw.toml'):
            m = tomllib.loads(p.read_text(encoding='utf-8'))
            rel = folder + '/' + m['filename']
            assert rel not in resource_metas, 'Duplicate resource'
            resource_metas[rel] = m
    assert set(resource_metas) == {r['path'] for r in resources}, 'Resource reference set differs from lock'
    assert len(resources) == report.get('resource_references', 0)
    for row in resources:
        meta = resource_metas[row['path']]
        assert meta['download']['hash'] == row['sha256'], row['path']
        assert meta['download']['url'] == row['url'], row['path']
        assert meta['side'] == row['side'] == 'client', row['path']
    patches = json.loads((root / 'tools/hotai/patches.lock.json').read_text(encoding='utf-8'))
    verify_patch_sources(root, patches)
    assert {p.relative_to(pack).as_posix() for p in (pack / 'hotai').rglob('*') if p.is_file() and p.name != '.gitkeep'} == {p['path'] for p in patches}, 'Unreviewed Hotai payload'
    for patch in patches:
        assert hashlib.sha256((pack / patch['path']).read_bytes()).hexdigest() == patch['sha256']
    if report['unresolved_mods'] and not allow_incomplete:
        raise ValueError('Release blocked: unresolved downloads: ' + ', '.join(x['filename'] for x in report['unresolved_mods']))
    print(f'PASS: {len(entries)} indexed files, {len(metas)} mod references; unresolved={len(report["unresolved_mods"])}')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--allow-incomplete', action='store_true', help='Audit only, not permission to publish')
    args = p.parse_args()
    verify(Path(__file__).resolve().parents[1], args.allow_incomplete)
