// Focus-delivery reproduction only. This entrypoint performs no database or RPC
// work and cannot substitute for the ordinary native acceptance workflow.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:busydata/src/ui/common/object_designer.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _targetLabel = 'Object / column name';
const _prepareLabel = 'Prepare focus baseline';
const _preparedLabel = 'Focus baseline prepared';

void main() {
  LinuxAccessibilityBinding.ensureInitialized();
  final variant = Platform.environment['BUSYDATA_DESIGNER_FOCUS_VARIANT'];
  final output = Platform.environment['BUSYDATA_DESIGNER_FOCUS_OUTPUT'];
  if (!Platform.isLinux ||
      !const ['A', 'B'].contains(variant) ||
      output == null ||
      !output.startsWith('/')) {
    throw StateError('An owned Linux focus fixture variant/output is required');
  }
  runApp(
    LinuxAccessibilityBridgeScope(
      child: fluent.FluentApp(
        title: 'BusyData designer focus reproduction',
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        themeMode: fluent.ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: DesignerFocusLinuxFixture(
          variant: variant!,
          output: File(output),
        ),
      ),
    ),
  );
}

/// Retains only a public first-party field controller and focus node. Rendering
/// and all field semantics/actions remain the unchanged WindowsControls path.
class _FixtureControls extends WindowsControls {
  _FixtureControls(this.capture);
  final _FieldCapture capture;

  @override
  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    bool enabled = true,
    FocusNode? focusNode,
    bool showLabel = true,
    bool readOnly = false,
    bool technical = false,
    Widget? trailing,
    String? errorText,
  }) {
    if (label == _targetLabel) {
      capture.bind(controller);
      if (focusNode != null && !identical(focusNode, capture.focus)) {
        throw StateError(
          'The focus fixture cannot replace an owned focus node',
        );
      }
      focusNode = capture.focus;
    }
    return super.field(
      controller,
      label,
      secret: secret,
      enabled: enabled,
      focusNode: focusNode,
      showLabel: showLabel,
      readOnly: readOnly,
      technical: technical,
      trailing: trailing,
      errorText: errorText,
    );
  }
}

class _FieldCapture {
  final focus = FocusNode(debugLabel: 'designer-focus-reproduction');
  TextEditingController? controller;
  VoidCallback? changed;

  void bind(TextEditingController next) {
    if (controller != null && !identical(controller, next)) {
      throw StateError('The focus fixture target controller was replaced');
    }
    if (identical(controller, next)) return;
    controller = next;
    next.addListener(_changed);
  }

  void _changed() => changed?.call();

  void dispose() {
    controller?.removeListener(_changed);
    focus.dispose();
  }
}

class DesignerFocusLinuxFixture extends StatefulWidget {
  const DesignerFocusLinuxFixture({
    super.key,
    required this.variant,
    this.output,
  });
  final String variant;
  // The native entrypoint requires an owned receipt file. A debug layout test
  // can omit file IO while pumping this exact diagnostic-only widget.
  final File? output;

  @override
  State<DesignerFocusLinuxFixture> createState() =>
      _DesignerFocusFixtureState();
}

class _DesignerFocusFixtureState extends State<DesignerFocusLinuxFixture> {
  final capture = _FieldCapture();
  late final controls = _FixtureControls(capture);
  Future<void> writes = Future<void>.value();
  bool prepared = false;
  int records = 0, generationAttempts = 0, openAttempts = 0;

  @override
  void initState() {
    super.initState();
    capture.changed = _record;
    capture.focus.addListener(_record);
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  void _record() {
    if (!mounted) return;
    if (++records > 64) {
      throw StateError('Focus fixture observation budget exceeded');
    }
    final controller = capture.controller;
    final receipt = {
      'version': 1,
      'diagnosticOnly': true,
      'rootAcceptance': false,
      'liveDatabaseAcceptance': false,
      'entrypoint': 'integration_test/designer_focus_linux.dart',
      'variant': widget.variant,
      'hostPlatform': Platform.operatingSystem,
      'releaseMode': kReleaseMode,
      'actualObjectDesignerForm': true,
      'actualWindowsControlsField': controller != null,
      'record': records,
      'prepared': prepared,
      'focused': capture.focus.hasFocus,
      'fixtureValueMatches': controller?.text == 'n',
      'selectionBase': controller?.selection.baseOffset,
      'selectionExtent': controller?.selection.extentOffset,
      'generationAttempts': generationAttempts,
      'openAttempts': openAttempts,
    };
    final output = widget.output;
    if (output == null) return;
    writes = writes.then((_) async {
      final temporary = File('${output.path}.tmp');
      await temporary.writeAsString('${jsonEncode(receipt)}\n', flush: true);
      await temporary.rename(output.path);
    });
    unawaited(writes);
  }

  void _prepare() {
    final controller = capture.controller;
    if (prepared ||
        controller == null ||
        controller.text != 'n' ||
        capture.focus.hasFocus) {
      throw StateError(
        'The native unfocused fixture baseline is required once',
      );
    }
    if (widget.variant == 'B') {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
    setState(() => prepared = true);
    _record();
  }

  @override
  void dispose() {
    capture.changed = null;
    capture.focus.removeListener(_record);
    capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => fluent.ScaffoldPage(
    header: const fluent.PageHeader(title: Text('Designer focus reproduction')),
    content: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          controls.button(_prepareLabel, _prepare),
          if (prepared) const Text(_preparedLabel),
          Expanded(
            child: ObjectDesignerForm(
              key: const ValueKey('designer-focus-form'),
              controls: controls,
              inspected: rpc.SchemaToolResult(
                snapshot: jsonEncode({
                  'engine': 'POSTGRESQL',
                  'schema': 'public',
                  'tables': {
                    'fixture_table': {
                      'columns': {
                        'n': {'type': 'integer', 'nullable': true},
                      },
                      'indexes': {},
                      'constraints': {},
                      'triggers': {},
                    },
                  },
                  'views': {},
                  'routines': {},
                }),
              ),
              target: rpc.SchemaToolRequest(
                schema: 'public',
                table: 'fixture_table',
              ),
              generate: (_) {
                generationAttempts++;
                _record();
                throw StateError(
                  'Focus reproduction must not generate SQL or call RPC',
                );
              },
              openSql: (_) {
                openAttempts++;
                _record();
                throw StateError('Focus reproduction must not open SQL');
              },
            ),
          ),
        ],
      ),
    ),
  );
}
