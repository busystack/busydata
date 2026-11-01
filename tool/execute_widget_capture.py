"""Capture asserted production widgets with the pinned engine and real assets.
This is rendering evidence, not the normal Flutter test transport or native
acceptance. It removes test-font overrides and changes no app theme. Native font
fallback is not certified by this headless renderer.
"""
import json, os, subprocess, sys
from pathlib import Path
parser=__import__('argparse').ArgumentParser(description=__doc__)
parser.add_argument('--flutter', default='flutter')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--assets', type=Path, default=Path('build/flutter_assets'))
parser.add_argument('--update-goldens', action='store_true', help='Generate review candidates; inspect every changed image before accepting it')
parser.add_argument('files', nargs='+')
options=parser.parse_args()
import shutil
root=Path.cwd(); output=options.output.resolve(); output.mkdir(parents=True,exist_ok=True)
launcher=shutil.which(options.flutter) or options.flutter
sdk=Path(launcher).resolve().parents[1]
isolated=True; files=options.files
imports='\n'.join(f"import '{(root/f).as_uri()}' as s{i};" for i,f in enumerate(files))
bodies='\n'.join(f"if (Platform.environment['BUSYDATA_TEST_FILE'] == null || Platform.environment['BUSYDATA_TEST_FILE'] == {json.dumps(f)}) await execute({json.dumps(f)}, () => Future.sync(s{i}.main));" for i,f in enumerate(files))

source="""import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart' show goldenFileComparator, LocalFileComparator, ComparisonResult, autoUpdateGoldenFiles;
import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/test.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/operating_system.dart';
@IMPORTS@
final observations = <Map<String, Object?>>[];
final lives = <LiveTest>[];
class CaptureComparator extends LocalFileComparator {
 CaptureComparator(Uri file, this.suite) : super(file);
 final String suite;
 @override
 Future<String> generateFailureOutput(ComparisonResult result, Uri golden, Uri basedir, {String key = ''}) => super.generateFailureOutput(result, golden, Directory('@FAILURES@/${suite.replaceAll('/', '__')}').absolute.uri, key: key);
}
int skipped=0;
Future<void> execute(String file, Future<void> Function() declare) async {
 final d=Declarer();
 await d.declare(declare);
 final suite=Suite(d.build(),SuitePlatform(Runtime.vm,os: OperatingSystem.linux),path:file);
 goldenFileComparator=CaptureComparator(File(file).absolute.uri, file);
 Future<bool> run(Test test,List<Group> groups,{bool hook=false}) async {
  if(test.metadata.skip) { skipped++; print('SKIP $file: ${test.name}'); return true; }
  final live=test.load(suite,groups:groups); lives.add(live);
  live.onError.listen((e) { print('ERROR $file: ${test.name}: ${e.error}\\n${e.stackTrace}'); });
  live.onMessage.listen((m)=>print(m.text));
  await live.run();
  print('${live.state.result.isPassing ? 'PASS' : 'FAIL'} $file: ${test.name}');
  observations.add({'file':file,'name':test.name,'hook':hook,'index':lives.length-1});
  return live.state.result.isPassing;
 }
 Future<void> visit(Group group,List<Group> parents) async {
  final groups=[...parents,group];
  final ready=group.setUpAll==null || await run(group.setUpAll!,groups,hook:true);
  if(ready) { for(final e in group.entries) { if(e is Group) { await visit(e,groups); } else if(e is Test) { await run(e,groups); } } }
  if(group.tearDownAll!=null) await run(group.tearDownAll!,groups,hook:true);
 }
 await visit(suite.group,[]);
}
Future<void> main() async {
 autoUpdateGoldenFiles = @UPDATE_GOLDENS@;
 await Invoker.guard(() async { @BODIES@ });
 for(var i=0;i<20;i++) { await Future<void>.delayed(Duration.zero); }
 var failed=0,passed=0;
 for(final row in observations) {
  final live=lives[row['index'] as int];
  row['passed']=live.state.result.isPassing;
  if(!live.state.result.isPassing) { failed++; } else if(row['hook']!=true) { passed++; }
 }
 File('@REPORT@').writeAsStringSync(jsonEncode({'runner':'real-asset flutter_tester; widget capture only','passed':passed,'failed':failed,'skipped':skipped,'tests':observations}));
 for(final live in lives) { await live.close(); }
 print('ENGINE_TEST_RESULT passed=$passed failed=$failed skipped=$skipped');
 exit(failed==0?0:1);
}
""".replace('@IMPORTS@',imports).replace('@BODIES@',bodies).replace('@REPORT@',str(output/'engine-results.json')).replace('@UPDATE_GOLDENS@', 'true' if options.update_goldens else 'false').replace('@FAILURES@',str(output/'golden-failures'))
runner=output/'engine_runner.dart'; runner.write_text(source)
compile_command=[str(sdk/'bin/cache/dart-sdk/bin/dartaotruntime'),str(sdk/'bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot'),'--sdk-root',str(sdk/'bin/cache/artifacts/engine/common/flutter_patched_sdk/'),'--target=flutter','--packages',str(root/'.dart_tool/package_config.json'),'--output-dill',str(output/'engine_runner.dill'),'--enable-asserts']
with (output/'engine-compile.log').open('w') as log:
 subprocess.run(compile_command,input=f'compile {runner}\n',text=True,stdout=log,stderr=subprocess.STDOUT,check=True)
if not (output/'engine-compile.log').read_text().rstrip().endswith(' 0'):raise SystemExit('Compilation failed; inspect engine-compile.log')
cmd=[str(sdk/'bin/cache/artifacts/engine/linux-x64/flutter_tester'),'--disable-vm-service','--enable-checked-mode','--enable-software-rendering','--skia-deterministic-rendering','--non-interactive','--packages='+str(root/'.dart_tool/package_config.json'),'--flutter-assets-dir='+str(options.assets.resolve()),str(output/'engine_runner.dill')]
if not isolated:
 raise SystemExit(subprocess.run(cmd,env={**os.environ,'FLUTTER_TEST':'true'}).returncode)
receipts=output/'isolated-results'; receipts.mkdir(exist_ok=True)
reports=[]; failures=[]
for file in files:
 print('ISOLATED_SUITE '+file,flush=True)
 (output/'engine-results.json').unlink(missing_ok=True)
 try:
  status=subprocess.run(cmd,env={**os.environ,'FLUTTER_TEST':'true','BUSYDATA_TEST_FILE':file},timeout=900).returncode
 except subprocess.TimeoutExpired:
  status=124
 report=json.loads((output/'engine-results.json').read_text()) if (output/'engine-results.json').exists() else {'passed':0,'failed':1,'skipped':0,'error':'Engine did not produce a completion receipt','tests':[]}
 report['exitCode']=status; report['suite']=file
 (receipts/(file.replace('/','__')+'.json')).write_text(json.dumps(report,indent=2)+'\n')
 reports.append(report)
 if status or report['failed']: failures.append(file)
aggregate={'runner':'pinned flutter_tester without test-font overrides; widget captures, not native acceptance','passed':sum(r['passed'] for r in reports),'failed':sum(r['failed'] for r in reports),'skipped':sum(r['skipped'] for r in reports),'failedSuites':failures,'suites':reports}
(output/'engine-isolated-full-results.json').write_text(json.dumps(aggregate,indent=2)+'\n')
print('ISOLATED_FULL_RESULT '+json.dumps({k:v for k,v in aggregate.items() if k!='suites'}),flush=True)
raise SystemExit(1 if failures else 0)
