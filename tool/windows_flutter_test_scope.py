"""Record the Windows suite, retaining every test except Linux renderer goldens."""
import hashlib
import json
from pathlib import Path

from canonical_source import source_hash


LINUX_RENDERER_TESTS = {
    'test/app/busydata_button_visual_test.dart',
    'test/linux_workbench_visual_test.dart',
    'test/ui_reference_gallery_test.dart',
    'test/ui_parity_screen_gallery_test.dart',
}


def test_scope(root):
    root = Path(root)
    paths = {path.relative_to(root).as_posix()
             for path in (root / 'test').rglob('*_test.dart')}
    missing = LINUX_RENDERER_TESTS - paths
    if missing:
        raise ValueError(f'Linux renderer scope requires review: {sorted(missing)}')
    excluded = []
    for name in sorted(LINUX_RENDERER_TESTS):
        data = (root / name).read_bytes()
        if b'!Platform.isLinux' not in data:
            raise ValueError(f'Test is no longer explicitly Linux-only: {name}')
        excluded.append({'path': name, 'sha256': hashlib.sha256(data).hexdigest(),
                         'reason': 'Linux renderer golden; executed by the full Linux suite'})
    selected = sorted(paths - LINUX_RENDERER_TESTS)
    if not selected:
        raise ValueError('Windows test suite cannot be empty')
    return {'schemaVersion': 1, 'platform': 'windows',
            'sourceSha256': source_hash(root), 'selected': selected,
            'excluded': excluded}


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    destination = root / 'build/windows-flutter-test-scope.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(test_scope(root), indent=2) + '\n', encoding='utf-8')
