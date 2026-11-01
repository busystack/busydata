"""Bound and verify the real JDK image operation, including zero-exit errors."""
import json
import os
from pathlib import Path
import signal
import subprocess
from bounded_process_log import BoundedProcessLog


def build_image(executable, modules, runtime, temporary, log_file, timeout=300):
    runtime, temporary, log_file = map(Path, (runtime, temporary, log_file))
    temporary.mkdir(parents=True, exist_ok=True, mode=0o700)
    command = [str(executable), '-J-Djava.io.tmpdir=' + str(temporary.resolve()),
               '--add-modules', ','.join(modules), '--strip-debug',
               '--no-header-files', '--no-man-pages', '--compress=zip-6',
               '--output', str(runtime)]
    child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             start_new_session=os.name != 'nt')
    log = BoundedProcessLog(child, log_file, 1024 * 1024)
    failure = None
    try:
        child.wait(timeout=timeout)
    except BaseException as interrupted:
        failure = type(interrupted).__name__
        if child.poll() is None:
            if os.name == 'nt':
                child.terminate()
            else:
                os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                if os.name == 'nt':
                    child.kill()
                else:
                    os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
    receipt = log.finish()
    # The strip-native-debug-symbols plugin can report a fatal operation error
    # while jlink itself returns zero. Retain that report and reject the image.
    diagnostics = log_file.read_text(errors='replace')
    reported_error = any(line.lstrip().startswith(('Error:', 'objcopy:'))
                         for line in diagnostics.splitlines())
    passed = child.returncode == 0 and receipt['complete'] and not reported_error and failure is None
    record = {'command': command, 'commandExitCode': child.returncode,
              'passed': passed, 'reportedError': reported_error, 'failureType': failure,
              'temporaryDirectory': str(temporary.resolve()), 'log': receipt}
    log_file.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n')
    if not passed:
        raise RuntimeError('Jlink image verification failed; inspect its retained bounded log/record')
    return record
