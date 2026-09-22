#!/usr/bin/env python3
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
policy=json.loads((root/'config/runtime-policy.json').read_text())
for k,v in policy.items():
    if k!='schema_version' and v is not False: raise SystemExit(f'unsafe gate open: {k}')
for name in ('source.json','source-beta.json'):
    data=json.loads((root/name).read_text())
    apps=data.get('apps')
    if not isinstance(apps,list) or len(apps)!=1: raise SystemExit(f'{name}: expected exactly one app')
    app=apps[0]
    versions=app.get('versions',[])
    seen=set()
    for item in versions:
        version=item.get('version')
        if not version or version in seen: raise SystemExit(f'{name}: duplicate/missing version {version}')
        seen.add(version)
        if not item.get('downloadURL'): raise SystemExit(f'{name}: missing downloadURL for {version}')
        if int(item.get('size',0))<=0: raise SystemExit(f'{name}: invalid size for {version}')
for p in (root/'release-manifests').glob('*.json'):
    m=json.loads(p.read_text())
    if not m.get('version'): raise SystemExit(f'{p}: missing version')
wf=list((root/'.github/workflows').glob('*.*ml'))
if len(wf)!=1 or wf[0].name!='validate.yml': raise SystemExit('unexpected workflow set')
s=wf[0].read_text()
if 'contents: read' not in s or 'contents: write' in s: raise SystemExit('workflow not read-only')
for forbidden in ('gh release create','git tag','git push','publish_version.py --version'):
    if forbidden.lower() in s.lower(): raise SystemExit(f'publishing command active: {forbidden}')
for m in re.finditer(r'uses:\s*([^\s]+)',s):
    if not re.search(r'@[0-9a-f]{40}$',m.group(1)): raise SystemExit(f'unpinned action: {m.group(1)}')
pat=re.compile(r'gh[pousr]_[A-Za-z0-9]{20,}|BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY')
for p in root.rglob('*'):
    if p.is_file() and '.git' not in p.parts:
        try:t=p.read_text(errors='ignore')
        except:continue
        if pat.search(t): raise SystemExit(f'secret-like material: {p.relative_to(root)}')
print('GREENFIELD_IOS_NEXT_RELEASES=PASS')
