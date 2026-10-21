"""Validate the downloaded data corpus against each repository's own XSD.

Usage: python3 tool/validate_fc5_corpus.py CORPUS_DIR REPORT_JSON
Requires lxml. Does not fetch URLs or resolve external entities.
"""
import hashlib
import json
import sys
from pathlib import Path
from lxml import etree

root = Path(sys.argv[1])
parser = etree.XMLParser(resolve_entities=False, no_network=True)
report = []
for record in json.loads((root / 'manifest.json').read_text()):
    path = root / record['repo'] / record['path']
    if path.suffix != '.xml':
        continue
    document = etree.parse(str(path), parser)
    tag = document.getroot().tag
    result = {**record, 'root': tag,
              'hashMatches': hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']}
    if tag in ('compendium', 'collection'):
        schema = etree.XMLSchema(etree.parse(str(root / record['repo'] / 'Utilities' / f'{tag}.xsd'), parser))
        result['xsdValid'] = schema.validate(document)
        result['xsdErrors'] = [error.message for error in schema.error_log]
    else:
        result['xsdValid'] = None
        result['note'] = 'Source metadata manifest, not a compiled compendium.'
    if tag in ('source', 'collection'):
        includes = document.findall('.//doc')
        result['includes'] = len(includes)
        result['missingLocalIncludes'] = sum(not (path.parent / doc.get('href', '')).is_file() for doc in includes)
    report.append(result)
Path(sys.argv[2]).write_text(json.dumps(report, indent=2))
print(json.dumps({'compendiums': sum(r['root'] == 'compendium' for r in report),
                  'xsdValidated': sum(r['xsdValid'] is True for r in report),
                  'xsdFailures': sum(r['xsdValid'] is False for r in report),
                  'hashMismatches': sum(not r['hashMatches'] for r in report)}))
if any(r['xsdValid'] is False or not r['hashMatches'] for r in report):
    raise SystemExit(1)
