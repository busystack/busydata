#!/usr/bin/env python3
import json, os, pathlib, shutil, subprocess, sys
root=pathlib.Path(__file__).resolve().parents[1]
os.chdir(root)
flutter=pathlib.Path(shutil.which('flutter')).resolve()
dart=flutter.parent/'cache/dart-sdk/bin'/('dart.exe' if os.name=='nt' else 'dart')
config=json.loads((root/'.dart_tool/package_config.json').read_text())
from urllib.parse import urlparse, unquote
plugin=next(p for p in config['packages'] if p['name']=='protoc_plugin')
plugin_root=pathlib.Path(unquote(urlparse(plugin['rootUri']).path))
if os.name=='nt' and str(plugin_root).startswith('\\') and len(str(plugin_root))>2 and str(plugin_root)[2]==':':
 plugin_root=pathlib.Path(str(plugin_root)[1:])
launch=root/'build/protoc-gen-dart'
launch.parent.mkdir(exist_ok=True)
if os.name=='nt':
 launch=launch.with_suffix('.bat');launch.write_text(f'@"{dart}" --packages="{root}/.dart_tool/package_config.json" "{plugin_root}/bin/protoc_plugin.dart" %*\r\n')
else:
 import shlex
 launch.write_text('#!/bin/sh\nexec '+shlex.join([str(dart),'--packages='+str(root/'.dart_tool/package_config.json'),str(plugin_root/'bin/protoc_plugin.dart')])+' "$@"\n');launch.chmod(0o755)
protoc=next((root/'backend/target/protoc-plugins').glob('protoc-4.36.2-*'))
subprocess.run([str(protoc),f'--plugin=protoc-gen-dart={launch}','--dart_out=grpc:lib/src/backend/generated','-I','protocol','protocol/busydata.proto'],check=True)
