"""Actual Linux native settings acceptance; no app theme/provider overrides."""
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
from verification_evidence import ROOT, source_hash, digest


CASES = (
    {'name': 'light', 'gtkTheme': 'Yaru', 'brightness': 'light', 'textScale': 1.0,
     'highContrast': False, 'animations': True, 'direction': 'ltr', 'language': 'en'},
    {'name': 'dark', 'gtkTheme': 'Yaru-dark', 'brightness': 'dark', 'textScale': 1.0,
     'highContrast': False, 'animations': True, 'direction': 'ltr', 'language': 'en'},
    {'name': 'light-125', 'gtkTheme': 'Yaru', 'brightness': 'light', 'textScale': 1.25,
     'highContrast': False, 'animations': True, 'direction': 'ltr', 'language': 'en'},
    {'name': 'light-150', 'gtkTheme': 'Yaru', 'brightness': 'light', 'textScale': 1.5,
     'highContrast': False, 'animations': True, 'direction': 'ltr', 'language': 'en'},
    {'name': 'display-200', 'gtkTheme': 'Yaru', 'brightness': 'light', 'textScale': 1.0,
     'devicePixelRatio': 2.0, 'highContrast': False, 'animations': True, 'direction': 'ltr', 'language': 'en'},
    {'name': 'contrast-200-reduced', 'gtkTheme': 'HighContrast', 'brightness': 'light', 'textScale': 2.0,
     'highContrast': True, 'animations': False, 'direction': 'ltr', 'language': 'en'},
    {'name': 'contrast-dark-200-reduced', 'gtkTheme': 'HighContrastInverse', 'brightness': 'dark', 'textScale': 2.0,
     'highContrast': True, 'animations': False, 'direction': 'ltr', 'language': 'en'},
    {'name': 'de-light-200-reduced', 'gtkTheme': 'Yaru', 'brightness': 'light', 'textScale': 2.0,
     'highContrast': False, 'animations': False, 'direction': 'ltr', 'language': 'de'},
    {'name': 'rtl-dark-200-reduced', 'gtkTheme': 'Yaru-dark', 'brightness': 'dark', 'textScale': 2.0,
     'highContrast': False, 'animations': False, 'direction': 'rtl', 'language': 'ar'},
)


def validate_composed_settings(expected, receipt):
    """An aggregate pass flag cannot certify the actual native UI settings."""
    exact = {'platformBrightness': expected['brightness'],
             'composedThemeBrightness': expected['brightness'],
             'textScale': expected['textScale'], 'highContrast': expected['highContrast'],
             'yaruHighContrast': expected['highContrast'],
             'disableAnimations': not expected['animations'],
             'nativeGtkAnimationsEnabled': expected['animations'],
             'direction': expected['direction']}
    if 'devicePixelRatio' in expected:
        exact['devicePixelRatio'] = expected['devicePixelRatio']
    if (receipt.get('passed') is not True or receipt.get('releaseMode') is not True or
            receipt.get('entrypoint') != 'integration_test/platform_settings_linux.dart' or
            any(receipt.get(key) != value for key, value in exact.items()) or
            not receipt.get('resolvedLocale', '').startswith(expected['language'])):
        raise RuntimeError('Native composed settings do not match this actual platform case')
    font, box = receipt.get('nativeGtkFont', {}), receipt.get('workspaceRenderBox', {})
    if (not font.get('family') or not isinstance(font.get('size'), (int, float)) or font['size'] <= 0 or
            not isinstance(box, dict) or box.get('width', 0) < 100 or box.get('height', 0) < 30 or
            receipt.get('renderedFontSize') != receipt.get('composedFontSize', 0) * expected['textScale']):
        raise RuntimeError('Native platform case lacks usable rendered font/workspace receipts')
    return receipt


def verify(source, ordinary_build, directory, base_environment, *, case_name=None):
    """Retain ordinary acceptance and restore its exact bundle after testing."""
    ordinary = ROOT / 'build/linux/x64/release/bundle'
    verify_existing_bundle('linux', ordinary_build, ordinary, source)
    evidence = directory / 'platform-matrix'
    evidence.mkdir()
    backup = evidence / 'ordinary-bundle'
    private = evidence / 'bundle'
    report = {'version': 1, 'sourceSha256': source, 'passed': False, 'cases': [],
              'entrypoint': 'integration_test/platform_settings_linux.dart',
              'ordinaryBuildId': ordinary_build['buildId'], 'ordinaryBundleRestored': False,
              'display': 'owned Xvfb 1920x1080x24; native Handy/Flutter; real portal/GSettings; no presentation overrides'}
    cases = CASES if case_name is None else tuple(case for case in CASES if case['name'] == case_name)
    if not cases:
        raise ValueError('Unknown native platform diagnostic case')
    report['scope'] = 'complete-nine-case-matrix' if case_name is None else 'single-case-diagnostic'
    report['requestedCases'] = [case['name'] for case in cases]
    output = evidence / 'matrix.json'
    shutil.copytree(ordinary, backup, symlinks=True)
    try:
        command = ['flutter', 'build', 'linux', '--release', '--no-pub', '-t', report['entrypoint']]
        report['buildCommand'] = command
        subprocess.run(command, cwd=ROOT, check=True, timeout=600)
        if source_hash() != source:
            raise RuntimeError('Source changed while building native platform matrix')
        shutil.copytree(ordinary, private, symlinks=True)
        report['privateArtifactHashes'] = {name: digest(private / name) for name in (
            'busydata', 'lib/libapp.so', 'backend/lib/busydata-backend-0.1.0.jar', 'backend/runtime/bin/java')}
        for expected in cases:
            case = evidence / expected['name']
            case.mkdir()
            (case / 'expected.json').write_text(json.dumps(expected) + '\n')
            runtime = Path(tempfile.mkdtemp(prefix='bdna-', dir='/tmp'))
            environment = dict(base_environment, XDG_RUNTIME_DIR=str(runtime),
                XDG_DATA_HOME=str(case / 'data'), XDG_CONFIG_HOME=str(case / 'config'),
                XDG_CACHE_HOME=str(runtime / 'cache'), LANGUAGE=expected['language'], GSETTINGS_BACKEND='dconf',
                BUSYDATA_NATIVE_ACCEPTANCE_EXECUTABLE=str(private / 'busydata'),
                BUSYDATA_NATIVE_SETTINGS_INPUT=str(case / 'expected.json'),
                BUSYDATA_NATIVE_SETTINGS_OUTPUT=str(case / 'composed-settings.json'))
            # A host override must not supersede the private real GTK settings.
            environment.pop('GTK_THEME', None)
            environment.pop('GTK_RC_FILES', None)
            environment.pop('GDK_SCALE', None)
            if 'devicePixelRatio' in expected:
                environment['GDK_SCALE'] = str(int(expected['devicePixelRatio']))
            controller = log = None
            record = {'name': expected['name'], 'exitCode': 1, 'cleanupConfirmed': False}
            try:
                display = '3840x2160x24' if expected.get('devicePixelRatio') == 2 else '1920x1080x24'
                argv = ['/usr/bin/xvfb-run', '-a', '-s', '-screen 0 ' + display + ' -noreset',
                    '/usr/bin/dbus-run-session', '--', '/usr/bin/python3',
                    str(ROOT / 'tool/verify_native_accessibility.py'), '--owned-session', str(case)]
                record['command'] = argv
                controller = subprocess.Popen(argv, env=environment, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, start_new_session=True)
                log = BoundedProcessLog(controller, case / 'controller.log', 2 * 1024 * 1024)
                controller.wait(timeout=600)
                receipt = json.loads((case / 'report.json').read_text())
                validate_application_logs(receipt, source, directory=case)
                from native_result_editor_acceptance import validate as validate_result_editor
                validate_result_editor(receipt.get('nativeP0ResultEditorVerified'))
                required = ('nativeRapidOwnedSessionsPaletteVerified',
                    'nativeStructurePropertyNameValueAndReaderVerified',
                    'nativeAuthenticationPasswordRoleVerified',
                    'nativeTransactionKeyboardCancelAndOriginFocusVerified',
                    'nativeTablePointerAndKeyboardFilterAfterReplacementVerified',
                    'nativeStartupCommandPaletteVerified',
                    'nativeSearchClearActionAndFocusVerified',
                    'nativeRetainedViewDetailsCapturedCountVerified',
                    'nativeTransactionReviewContainmentAndRollbackStateVerified',
                    'nativeGridExactSelectedServerCellClipboardVerified',
                    'nativeSchemaObjectFocusRoleAndSpeechVerified',
                    'nativeMulticaretImeBothLinesAndAtomicUndoVerified',
                    'nativePlanFocusAndKeyboardNavigationVerified',
                    'nativeDesignerDefinitionNestedModalAndKeyboardCloseVerified',
                    'nativeAttachedAndIndependentPlanProvenanceVerified',
                    'nativeObjectIndexesWithoutDataQueryVerified',
                    'nativeObjectDefinitionVerified',
                    'nativeRetainedSortFilterWithoutExecutionVerified',
                    'nativeInlineEditTextFieldFocusVerified',
                    'nativeInlineOwnedEditReviewApplyAndCommitVerified',
                    'nativeCommittedChangesPreservePreChangeSnapshotVerified',
                    'nativeExplicitPostChangeRefreshVerified',
                    'nativeFixtureRestoredThroughReviewedUiVerified')
                if (controller.returncode != 0 or receipt.get('exitCode') != 0 or
                        not all(receipt.get(item) is True for item in required) or
                        receipt.get('actualComposedSettings', {}).get('passed') is not True):
                    raise RuntimeError('Actual native settings/workflow case failed')
                record['exitCode'] = 0
            except Exception as failure:
                record['failureType'] = type(failure).__name__
            finally:
                if controller is not None and controller.poll() is None:
                    os.killpg(controller.pid, signal.SIGTERM)
                    try: controller.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(controller.pid, signal.SIGKILL)
                        controller.wait(timeout=5)
                if log is not None:
                    record['controllerLog'] = log.finish()
                    record['controllerLog']['sha256'] = digest(case / 'controller.log')
                    if not record['controllerLog']['complete']: record['exitCode'] = 1
                for name in ('report.json', 'progress.json', 'composed-settings.json', 'portal-settings.txt'):
                    path = case / name
                    if path.is_file():
                        record[name] = {'file': str(path), 'bytes': path.stat().st_size, 'sha256': digest(path)}
                secret_path = Path(base_environment['BUSYDATA_NATIVE_FIXTURE_DIRECTORY']) / 'password'
                secret = secret_path.read_bytes()
                diagnostics = [path for path in case.rglob('*') if path.is_file() and
                               (path.suffix in ('.json', '.txt', '.log'))]
                record['fixtureCredentialAbsentFromDiagnostics'] = all(
                    path.stat().st_size <= 4 * 1024 * 1024 and secret not in path.read_bytes()
                    for path in diagnostics)
                if not record['fixtureCredentialAbsentFromDiagnostics']: record['exitCode'] = 1
                remove_native_runtime(runtime)
                record['cleanupConfirmed'] = controller is None or controller.poll() is not None
                report['cases'].append(record)
        report['passed'] = all(case['exitCode'] == 0 and case['cleanupConfirmed'] for case in report['cases'])
    except Exception as failure:
        report['failureType'] = type(failure).__name__
        if isinstance(failure, OSError):
            report['failureErrno'] = failure.errno
    finally:
        # Restore exact verified ordinary bytes, then check the complete bundle
        # inventory. A private entrypoint cannot satisfy ordinary acceptance.
        shutil.rmtree(ordinary)
        shutil.copytree(backup, ordinary, symlinks=True)
        verify_existing_bundle('linux', ordinary_build, ordinary, source)
        report['ordinaryBundleRestored'] = True
        report['sourceUnchanged'] = source_hash() == source
        report['passed'] = report['passed'] and report['sourceUnchanged']
        output.write_text(json.dumps(report, indent=2) + '\n')
        shutil.rmtree(backup)
    return {'file': str(output), 'bytes': output.stat().st_size, 'sha256': digest(output),
            'passed': report['passed']}
