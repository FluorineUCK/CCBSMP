"""Import a reviewed Test snapshot; no downloads, deletions or runtime changes."""
import argparse
import hashlib
import json
import re
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'pack'
CONTENT_FOLDERS = ('config', 'defaultconfigs', 'kubejs', 'hotai', 'oei', 'oeb', 'oef')

def sha(data):
    return hashlib.sha256(data).hexdigest()

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode('utf-8'))

def reviewed_patches(source, records):
    """Never infer a patch's target from an unrelated installed mod."""
    known = {r['path']: r for r in records}
    result = []
    for p in sorted((source / 'hotai').rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(source).as_posix()
        row = known.get(rel)
        if not row or sha(p.read_bytes()) != row['sha256']:
            raise ValueError('Hotai patch requires review: ' + rel)
        target = (source / 'mods' / row['target_file']).resolve()
        if not target.is_relative_to((source / 'mods').resolve()) or not target.is_file():
            raise ValueError('Missing Hotai target: ' + rel)
        if sha(target.read_bytes()) != row['target_jar_sha256']:
            raise ValueError('Hotai target changed: ' + rel)
        if target.name.endswith('.jar') != row['target_enabled']:
            raise ValueError('Hotai target enabled state changed: ' + rel)
        result.append(dict(row))
    return result

def validate_resources(source, rows):
    for row in rows:
        p = (source / row['path']).resolve()
        if (not p.is_relative_to(source.resolve())
                or Path(row['path']).parts[0] not in {'resourcepacks', 'shaderpacks'}
                or not p.is_file() or sha(p.read_bytes()) != row['sha256']):
            raise ValueError('Resource changed or unsafe path: ' + row['path'])

def reference_text(row):
    data = f'# Imported version: {row["version"]}\n'
    for key in ('name', 'filename', 'side'):
        data += f'{key} = {json.dumps(row[key], ensure_ascii=False)}\n'
    data += '\n[download]\n' + f'url = {json.dumps(row["url"])}\nhash-format = "sha256"\nhash = "{row["sha256"]}"\n'
    for provider in ('modrinth', 'curseforge'):
        if row.get(provider):
            data += f'\n[update.{provider}]\n'
            data += ''.join(f'{k} = {json.dumps(v)}\n' for k, v in row[provider].items())
    return data

def refresh():
    entries = []
    for p in sorted(PACK.rglob('*')):
        if not p.is_file() or p.name in {'.gitkeep', '.packwizignore', 'pack.toml', 'index.toml'}:
            continue
        entries.append({'file': p.relative_to(PACK).as_posix(), 'hash': sha(p.read_bytes()),
                        'metafile': p.name.endswith('.pw.toml')})
    text = 'hash-format = "sha256"\n'
    for e in entries:
        text += '\n[[files]]\n' + '\n'.join(f'{k} = {json.dumps(v, ensure_ascii=False)}' for k, v in e.items()) + '\n'
    write(PACK / 'index.toml', text)
    p = PACK / 'pack.toml'
    text = re.sub(r'(?m)^hash = "[0-9a-f]+"$', f'hash = "{sha(text.encode())}"', p.read_text(encoding='utf-8'))
    write(p, text)
    return len(entries)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    if source == PACK.resolve() or PACK.resolve().is_relative_to(source):
        raise ValueError('Source must be a separate runtime instance')
    rows = json.loads((ROOT / 'tools/test-mods.lock.json').read_text(encoding='utf-8'))
    actual = {p.name for p in (source / 'mods').glob('*.jar')}
    assert actual == {r['filename'] for r in rows}, 'Test changed: refresh inventory first'
    for row in rows:
        assert sha((source / 'mods' / row['filename']).read_bytes()) == row['sha256'], row['filename']
    patches = reviewed_patches(source, json.loads((ROOT / 'tools/hotai/patches.lock.json').read_text(encoding='utf-8')))
    resource_lock = ROOT / 'tools/resources.lock.json'
    resources = json.loads(resource_lock.read_text(encoding='utf-8')) if resource_lock.exists() else []
    validate_resources(source, resources)
    unresolved = []
    slugs = set()
    for row in rows:
        if not row['url']:
            unresolved.append({'filename': row['filename'], 'sha256': row['sha256'],
                               'reason': 'Exact published file has not yet been matched; not replaced or omitted from audit.'})
            continue
        slug = row['ids'][0] if row['ids'] else Path(row['filename']).stem
        slug = re.sub(r'[^a-z0-9_-]', '-', slug.lower())
        assert slug not in slugs, slug
        slugs.add(slug)
        write(PACK / 'mods' / (slug + '.pw.toml'), reference_text(row))
    for row in resources:
        write(PACK / Path(row['path']).parent / (row['slug'] + '.pw.toml'), reference_text(row))

    excluded, copied = [], []
    disabled = {'hexcasting', 'hexdebug', 'hexcessible', 'paucal', 'inline', 'patchouli', 'caelus',
                'clientsort', 'create_cyber_goggles', 'createfurnitureseats'}
    disabled -= {i for row in rows for i in row['ids']}
    private_prefixes = ('config/spark/', 'config/xaero/', 'config/zstdnet/stats/',
                        'config/zstdnet/reports/', 'config/net_music/')
    personal = {'config/sodium-fingerprint.json', 'config/resourceful-config-web.json',
                'config/xaeropatreon.txt', 'config/iris.properties', 'config/iris-excluded.json',
                'config/sodium-options.json', 'config/sodium-extra-options.json',
                'config/voicechat/username-cache.json', 'config/voicechat/player-volumes.properties',
                'config/voicechat/category-volumes.properties', 'config/voicechat/voicechat-client.properties',
                'config/xaerohud.txt', 'config/yacl.json5', 'kubejs/config/web_server.json'}
    for folder in CONTENT_FOLDERS:
        for p in sorted((source / folder).rglob('*')):
            if not p.is_file():
                continue
            rel = p.relative_to(source).as_posix()
            reason = None
            if rel in personal or rel.startswith(private_prefixes):
                reason = 'personal settings, cache, statistics or local web service'
            elif p.suffix.lower() in {'.bak', '.log', '.tmp', '.db', '.sqlite'}:
                reason = 'runtime or backup file'
            elif folder == 'config' and any(re.match(r'config/' + re.escape(i) + r'[/.-]', rel.lower()) for i in disabled):
                reason = 'disabled mod configuration'
            data = p.read_bytes()
            if not reason and p.suffix.lower() not in {'.class', '.badiff', '.png'}:
                text = data.decode('utf-8', errors='replace')
                active = '\n'.join(l for l in text.splitlines() if not l.lstrip().startswith(('#', '//')))
                if re.search(r'(?i)(?:password|api[_-]?key|access[_-]?token|secret|authorization)\s*["\']?\s*[:=]', active):
                    reason = 'credential-like configuration requires manual review'
                elif re.search(r'(?i)FluorineUCK|[CD]:[\\/]|CCBSMP\s+Preliminary', active):
                    reason = 'personal identity or absolute path requires manual review'
            if reason:
                excluded.append({'path': rel, 'reason': reason})
                continue
            write(PACK / rel, data)
            copied.append({'path': rel, 'sha256': sha(data)})
    write(ROOT / 'tools/hotai/patches.lock.json', json.dumps(patches, ensure_ascii=False, indent=2) + '\n')
    report = {'active_mods_in_test': len(rows), 'resolved_mods': len(slugs),
              'unresolved_mods': unresolved, 'copied_files': copied, 'excluded_files': excluded,
              'runtime_tested': False, 'resourcepacks_imported': bool(resources),
              'resource_references': len(resources),
              'side_policy': 'Reviewed existing sides plus published environment; user client-only overrides retained. Not a server runtime validation.'}
    report['indexed_files'] = refresh()
    write(ROOT / 'tools/import-report.json', json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('active_mods_in_test', 'resolved_mods', 'unresolved_mods', 'indexed_files')}, ensure_ascii=False))

if __name__ == '__main__':
    main()
