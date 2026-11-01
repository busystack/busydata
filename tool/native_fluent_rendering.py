"""Actual Fluent product rendering on Linux; never Win32 acceptance."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

from bounded_process_log import BoundedProcessLog
from application_exception_log import validate as validate_application_logs
from native_runtime_cleanup import remove_native_runtime
from desktop_build_evidence import verify_existing_bundle
from verification_evidence import ROOT, digest, source_hash

ENTRYPOINT = 'integration_test/fluent_composition_linux.dart'
REQUIRED = (
    'nativeStartupCommandPaletteVerified',
    'nativeInlineOwnedEditReviewApplyAndCommitVerified',
    'nativeObjectIndexesWithoutDataQueryVerified',
    'nativeObjectDefinitionVerified',
    'nativeRetainedSortFilterWithoutExecutionVerified',
    'nativeRetainedViewDetailsCapturedCountVerified',
    'nativeAttachedAndIndependentPlanProvenanceVerified',
    'nativeActivityBlockerAndCapturedReviewVerified',
    'nativeConcurrentDifferentTargetsPreserveFocusVerified',
    'nativeSchemaDiagramActualForeignKeyScopeVerified',
    'nativeCurrentDesiredComparisonAndSaveSqlVerified',
    'nativeRetainedExportAfterDisconnectVerified',
    'nativeProductionUnknownOutcomeQuarantineVisibleVerified',
)


def validate_composition(receipt):
    expected = {'entrypoint': ENTRYPOINT, 'composition': 'Linux-host Fluent',
        'hostPlatform': 'linux', 'releaseMode': True, 'actualWindowsWorkspaceShell': True,
        'actualFluentTheme': True, 'actualPinnedBackend': True, 'windowsNativeAcceptance': False}
    box = receipt.get('workspaceRenderBox', {})
    if (any(receipt.get(key) != value for key, value in expected.items()) or
            not isinstance(box, dict) or box.get('width', 0) < 100 or box.get('height', 0) < 30 or
            receipt.get('textScale', 0) <= 0 or receipt.get('direction') not in ('ltr', 'rtl')):
        raise RuntimeError('Actual Linux-host Fluent composition evidence is incomplete')
    return receipt


def verify(source, ordinary_build, directory, base_environment):
    ordinary = ROOT / 'build/linux/x64/release/bundle'
    verify_existing_bundle('linux', ordinary_build, ordinary, source)
    evidence = directory / 'fluent-rendering'
    evidence.mkdir()
    backup, private = evidence / 'ordinary-bundle', evidence / 'bundle'
    report = {'version': 1, 'sourceSha256': source, 'passed': False,
        'composition': 'Linux-host Fluent', 'windowsNativeAcceptance': False,
        'entrypoint': ENTRYPOINT, 'ordinaryBuildId': ordinary_build['buildId'],
        'ordinaryBundleRestored': False, 'cleanupConfirmed': False}
    output = evidence / 'rendering.json'
    shutil.copytree(ordinary, backup, symlinks=True)
    controller = log = None
    runtime = Path(tempfile.mkdtemp(prefix='bdna-', dir='/tmp'))
    try:
        argv = ['flutter', 'build', 'linux', '--release', '--no-pub', '-t', ENTRYPOINT]
        report['buildCommand'] = argv
        subprocess.run(argv, cwd=ROOT, check=True, timeout=600)
        if source_hash() != source:
            raise RuntimeError('Source changed during Fluent rendering build')
        shutil.copytree(ordinary, private, symlinks=True)
        report['privateArtifactHashes'] = {name: digest(private / name) for name in (
            'busydata', 'lib/libapp.so', 'backend/lib/busydata-backend-0.1.0.jar', 'backend/runtime/bin/java')}
        environment = dict(base_environment, XDG_RUNTIME_DIR=str(runtime),
            XDG_DATA_HOME=str(evidence / 'data'), XDG_CONFIG_HOME=str(evidence / 'config'),
            XDG_CACHE_HOME=str(runtime / 'cache'),
            BUSYDATA_NATIVE_ACCEPTANCE_EXECUTABLE=str(private / 'busydata'),
            BUSYDATA_NATIVE_COMPOSITION_OUTPUT=str(evidence / 'composition.json'))
        argv = ['/usr/bin/xvfb-run', '-a', '-s', '-screen 0 1920x1080x24 -noreset',
            '/usr/bin/dbus-run-session', '--', '/usr/bin/python3',
            str(ROOT / 'tool/verify_native_accessibility.py'), '--owned-session', str(evidence)]
        report['command'] = argv
        controller = subprocess.Popen(argv, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, start_new_session=True)
        log = BoundedProcessLog(controller, evidence / 'controller.log', 2 * 1024 * 1024)
        controller.wait(timeout=600)
        receipt = json.loads((evidence / 'report.json').read_text())
        validate_application_logs(receipt, source, directory=evidence)
        validate_composition(receipt.get('actualComposition', {}))
        if controller.returncode or receipt.get('exitCode') or not all(receipt.get(key) is True for key in REQUIRED):
            raise RuntimeError('Actual Fluent product workflow rendering failed')
        report['passed'] = True
    except Exception as failure:
        report['failureType'] = type(failure).__name__
    finally:
        if controller is not None and controller.poll() is None:
            os.killpg(controller.pid, signal.SIGTERM)
            try: controller.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(controller.pid, signal.SIGKILL)
                controller.wait(timeout=5)
        if log is not None:
            report['controllerLog'] = log.finish()
            report['controllerLog']['sha256'] = digest(evidence / 'controller.log')
            if not report['controllerLog']['complete']: report['passed'] = False
        for name in ('report.json', 'composition.json'):
            path = evidence / name
            if path.is_file(): report[name] = {'file': str(path), 'bytes': path.stat().st_size, 'sha256': digest(path)}
        secret = (Path(base_environment['BUSYDATA_NATIVE_FIXTURE_DIRECTORY']) / 'password').read_bytes()
        paths = [path for path in evidence.rglob('*') if path.is_file() and path.suffix in ('.json', '.txt', '.log')]
        report['fixtureCredentialAbsentFromDiagnostics'] = all(
            path.stat().st_size <= 4 * 1024 * 1024 and secret not in path.read_bytes() for path in paths)
        report['cleanupConfirmed'] = controller is None or controller.poll() is not None
        remove_native_runtime(runtime)
        shutil.rmtree(ordinary)
        shutil.copytree(backup, ordinary, symlinks=True)
        verify_existing_bundle('linux', ordinary_build, ordinary, source)
        shutil.rmtree(backup)
        report['ordinaryBundleRestored'] = True
        report['sourceUnchanged'] = source_hash() == source
        report['passed'] = report['passed'] and report['cleanupConfirmed'] and report['sourceUnchanged'] and report['fixtureCredentialAbsentFromDiagnostics']
        output.write_text(json.dumps(report, indent=2) + '\n')
    return {'file': str(output), 'bytes': output.stat().st_size, 'sha256': digest(output),
        'passed': report['passed'], 'windowsNativeAcceptance': False}
