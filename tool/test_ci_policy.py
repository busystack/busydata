import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from check_toolchain import check


ROOT = Path(__file__).resolve().parents[1]


class CiPolicyTest(unittest.TestCase):
    def test_logged_routine_steps_propagate_failures_and_preserve_logs(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        defaults = re.search(r'^        shell: (\S+)$', workflow.split('    steps:', 1)[0], re.M)
        for name, executable, log in (
                ('Java unit tests and protocol generation', 'backend/mvnw', 'java.log'),
                ('Complete Flutter unit and widget suite', 'bin/flutter', 'flutter-tests.jsonl'),
                ('Python tooling unit suite', 'bin/python3', 'python-tests.log')):
            step = re.search(r'^      - name: ' + re.escape(name) + r'\n((?:        .*\n)*)',
                             workflow, re.M).group(1)
            run = re.search(r'^        run: (.*)\n', step, re.M)
            if run.group(1) == '|':
                script = '\n'.join(line[10:] for line in step[run.end():].splitlines()
                                   if line.startswith('          ')) + '\n'
            else:
                script = run.group(1) + '\n'
            shell = re.search(r'^        shell: (\S+)$', step, re.M) or defaults
            self.assertIn(shell.group(1) if shell else None, (None, 'bash'))
            # GitHub's unspecified Linux shell lacks pipefail; explicit Bash includes it.
            invocation = ['bash', '--noprofile', '--norc', '-e', '-o', 'pipefail'] if shell else ['bash', '-e']
            for status in (7, 0):
                with self.subTest(step=name, status=status), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    (root / 'bin').mkdir()
                    (root / 'build/routine').mkdir(parents=True)
                    command = root / executable
                    command.parent.mkdir(parents=True, exist_ok=True)
                    command.write_text('#!/bin/sh\necho stdout\necho stderr >&2\nexit ' + str(status) + '\n')
                    command.chmod(0o755)
                    if executable == 'backend/mvnw':
                        protocol = root / 'bin/python3'
                        protocol.write_text('#!/bin/sh\ntouch protocol-generated\n')
                        protocol.chmod(0o755)
                    script_path = root / 'step.sh'
                    script_path.write_text(script)
                    environment = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'])
                    reply = subprocess.run(invocation + [str(script_path)], cwd=root, env=environment,
                                           capture_output=True, text=True, timeout=10)
                    self.assertEqual('stdout\nstderr\n', (root / 'build/routine' / log).read_text())
                    self.assertEqual(status, reply.returncode, reply.stdout + reply.stderr)
                    if executable == 'backend/mvnw':
                        self.assertEqual(status == 0, (root / 'protocol-generated').exists())

    def test_routine_events_run_complete_source_and_unit_checks_without_release_workloads(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        events, jobs = workflow.split('jobs:', 1)
        self.assertRegex(events, r'push:\s+branches:')
        self.assertIn('pull_request:', events)
        self.assertNotIn('tags:', events)
        for command in ('tool/check_toolchain.py', 'tool/verify_flutter_sdk.dart',
                        'flutter pub get --enforce-lockfile', 'tool/verify_official_dependencies.py', 'PUB_CACHE=', 'TMPDIR=', 'flutter gen-l10n',
                        'backend/mvnw -f backend/pom.xml verify', 'tool/generate_protocol.py',
                        'dart format --output=none --set-exit-if-changed', 'flutter analyze',
                        'tool/check_platform_boundaries.dart', 'flutter test --machine --no-pub',
                        "python3 -m unittest discover -s tool -p 'test_*.py'"):
            self.assertIn(command, jobs)
        for command in ('-Pdatabase-it', 'verify_pipeline.py', 'snapcraft',
                        'verify_database_ui.sh', 'verify_release_performance.py',
                        'build_release.ps1', 'build_linux_release.py', 'docker pull'):
            self.assertNotIn(command, jobs)
        self.assertNotRegex(jobs, r'continue-on-error:\s*true')

    def test_native_windows_source_gate_uses_owned_cache_and_restores_the_callers_environment(self):
        script = (ROOT / 'tool/windows/build_release.ps1').read_text()
        self.assertLess(script.index("'flutter-dependencies'"), script.index("'official-dependencies'"))
        self.assertLess(script.index("'official-dependencies'"), script.index("'localizations'"))
        self.assertIn("'build/official-dependencies/pub-cache'", script)
        self.assertIn("'build/t'", script)
        self.assertIn('finally {', script)
        self.assertIn('$env:PUB_CACHE=$previousPubCache', script)
        self.assertIn('$env:TMPDIR=$previousTemporaryDirectory', script)
        self.assertIn('flutter-dependencies official-dependencies localizations', script)

    def test_full_events_and_snap_upstream_gates_remain_deliberate(self):
        workflow = (ROOT / '.github/workflows/verify.yml').read_text()
        events, jobs = workflow.split('jobs:', 1)
        self.assertIn('workflow_dispatch:', events)
        self.assertIn("tags: ['v[0-9]*']", events)
        self.assertNotIn('pull_request', events)
        self.assertNotIn('branches:', events)
        self.assertIn('needs: [database, linux]', jobs)
        for command in ('postgres:17.11', 'mysql:8.4.10', 'mariadb:11.8.9',
                        '--scope database', '--scope linux', 'tool/build_snap_acceptance.py',
                        'tool/verify_snap_distribution.py', 'tool/verify_installed_snap.py',
                        'tool/windows/build_release.ps1'):
            self.assertIn(command, jobs)
        self.assertEqual(2, jobs.count('uses: snapcore/action-build@v1'))
        self.assertIn('tar -C build/linux/x64/release -czf build/busydata-linux-x64.tar.gz bundle', jobs)
        self.assertIn('Ordinary product-Snap installed acceptance is unavailable', jobs)
        self.assertIn('unavailable --stage msix', jobs)
        self.assertNotRegex(jobs, r'continue-on-error:\s*true')
        recipe = (ROOT / 'snap/snapcraft.yaml').read_text()
        self.assertIn('confinement: strict', recipe)
        self.assertIn('grade: devel', recipe)
        self.assertIn('source: build/linux/x64/release/bundle', recipe)

    def test_routine_flutter_pin_cannot_diverge_from_release_toolchains(self):
        check()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('config/toolchain.json', '.github/workflows/verify.yml',
                         '.github/workflows/ci.yml', 'tool/verify.sh',
                         'tool/windows/build_release.ps1', 'tool/windows/check_prerequisites.ps1',
                         'docs/development.md'):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            routine = root / '.github/workflows/ci.yml'
            routine.write_text(re.sub(r"flutter-version: '[^']+'", "flutter-version: '0.0.0'",
                                      routine.read_text()))
            with self.assertRaisesRegex(ValueError, 'Routine CI'):
                check(root)
