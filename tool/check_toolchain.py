#!/usr/bin/env python3
"""Fail if development, CI or Windows toolchain selection diverges."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]


def check(root=ROOT):
    baseline = json.loads((root / 'config/toolchain.json').read_text())
    pins = re.findall(r"flutter-version:\s*['\"]([^'\"]+)",
                      (root / '.github/workflows/verify.yml').read_text())
    if len(pins) != 2 or any(pin != baseline['flutter'] for pin in pins):
        raise ValueError('Linux and Windows CI must select config/toolchain.json Flutter baseline')
    routine_pins = re.findall(r"flutter-version:\s*['\"]([^'\"]+)",
                             (root / '.github/workflows/ci.yml').read_text())
    if routine_pins != [baseline['flutter']]:
        raise ValueError('Routine CI must select config/toolchain.json Flutter baseline')
    for relative in ('tool/verify.sh', 'tool/windows/build_release.ps1',
                     'tool/windows/check_prerequisites.ps1'):
        text = (root / relative).read_text()
        if 'toolchain.json' not in text or '--expected-flutter' in text or '--expected-dart' in text:
            raise ValueError(f'{relative} must use the common minimum toolchain configuration')
    development = (root / 'docs/development.md').read_text()
    if f"Flutter **{baseline['flutter']}**" not in development or f"Dart **{baseline['dart']}**" not in development:
        raise ValueError('Documented development baseline differs from toolchain configuration')
    return baseline


if __name__ == '__main__':
    print(json.dumps({'configuredMinimum': check()}))
