"""A Snap part must compile its declared checksum-verified publisher archive."""
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import build_snap_native_clients as builder

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / 'snap/snapcraft.yaml'


class SnapDeclaredArchiveTest(unittest.TestCase):
    @unittest.skipUnless(sys.platform == 'linux', 'Snap override execution requires its Linux shell')
    def test_each_override_passes_its_pulled_archive_without_a_second_source(self):
        recipe = RECIPE.read_text()
        records = json.loads((ROOT / 'third_party/native_client_sources.json').read_text())
        for record in records:
            with self.subTest(engine=record['engine']), tempfile.TemporaryDirectory(prefix='busydata-snap-archive-') as temporary:
                root = Path(temporary) / 'project with spaces'
                tool = root / 'tool'
                tool.mkdir(parents=True)
                capture = root / 'arguments.json'
                (tool / 'build_snap_native_clients.py').write_text(
                    'import json,os,pathlib,sys\npathlib.Path(os.environ["BUSYDATA_ARGUMENT_CAPTURE"]).write_text(json.dumps(sys.argv[1:]))\n')
                block = re.search(r'(?ms)^  native-' + re.escape(record['engine']) + r'-client:\n(.*?)(?=^  \S|\Z)', recipe).group(1)
                part = {}
                for name in ('source-type', 'source', 'source-checksum'):
                    part[name] = re.search(r'(?m)^    ' + name + r': ([^\n]+)$', block).group(1)
                override = block.split('    override-build: |\n', 1)[1]
                part['override-build'] = '\n'.join(line[6:] for line in override.splitlines() if line.strip())
                self.assertEqual('file', part['source-type'])
                self.assertEqual(record['url'], part['source'])
                self.assertEqual('sha256/' + record['sha256'], part['source-checksum'])
                environment = dict(os.environ, CRAFT_PROJECT_DIR=str(root),
                    CRAFT_PART_SRC=str(root / 'source with spaces'),
                    CRAFT_PART_BUILD=str(root / 'build with spaces'),
                    CRAFT_PART_INSTALL=str(root / 'install with spaces'),
                    BUSYDATA_ARGUMENT_CAPTURE=str(capture))
                subprocess.run(['/bin/sh', '-eu', '-c', part['override-build']],
                               env=environment, check=True)
                self.assertEqual([record['engine'], '--archive',
                    str(root / 'source with spaces' / record['name']), '--build',
                    str(root / 'build with spaces/clients'), '--install',
                    str(root / 'install with spaces')], json.loads(capture.read_text()))

    def run_archive(self, expected_checksum_matches):
        with tempfile.TemporaryDirectory(prefix='busydata-pulled-archive-') as temporary:
            root = Path(temporary)
            publisher = root / 'publisher-1.0'
            publisher.mkdir()
            (publisher / 'configure').write_text('unchanged publisher input\n')
            archive = root / 'publisher-1.0.tar.gz'
            with tarfile.open(archive, 'w:gz') as content:
                content.add(publisher, arcname=publisher.name)
            record = {'engine': 'postgresql', 'name': archive.name,
                      'url': 'https://example.invalid/should-never-be-fetched',
                      'sha256': builder.sha256(archive) if expected_checksum_matches else '0' * 64}
            (root / 'third_party').mkdir()
            (root / 'third_party/native_client_sources.json').write_text(json.dumps([record]))
            before = archive.read_bytes()
            args = ['build_snap_native_clients.py', 'postgresql', '--archive', str(archive),
                    '--build', str(root / 'build'), '--install', str(root / 'install')]
            class CompilerReached(Exception):
                pass
            def compile_command(arguments, directory=None):
                self.assertEqual('configure', Path(arguments[0]).name)
                source = root / 'build/source/publisher-1.0'
                builder.verify_source_tree(archive, source)
                self.assertEqual('unchanged publisher input\n', (source / 'configure').read_text())
                raise CompilerReached()
            with patch.object(builder, 'ROOT', root), patch.object(sys, 'argv', args), \
                 patch.object(builder.urllib.request, 'urlopen', side_effect=AssertionError('A declared archive must not download again')) as network, \
                 patch.object(builder, 'execute', side_effect=compile_command) as compiler:
                if expected_checksum_matches:
                    with self.assertRaises(CompilerReached):
                        builder.main()
                    self.assertEqual(1, compiler.call_count)
                else:
                    with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                        builder.main()
                    compiler.assert_not_called()
                    self.assertFalse((root / 'build/source').exists())
                network.assert_not_called()
            self.assertEqual(before, archive.read_bytes())

    def test_existing_publisher_archive_extracts_and_verifies_without_network(self):
        self.run_archive(True)

    def test_bad_pulled_checksum_is_rejected_before_extraction_or_compilation(self):
        self.run_archive(False)


if __name__ == '__main__':
    unittest.main()
