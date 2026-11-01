import '../../l10n/workbench_strings.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart' show ResponseFuture;
import '../../backend/generated/busydata.pbgrpc.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

class CapabilityInspectionState {
  rpc.CapabilityList? report;
  String error = '';
  bool loaded = false;
}

class CapabilitiesView extends StatefulWidget {
  const CapabilitiesView({
    super.key,
    required this.model,
    required this.target,
    required this.controls,
    this.inspection,
  });
  final WorkbenchModel model;
  final CapturedWorkbenchTarget target;
  final DesktopControls controls;
  final CapabilityInspectionState? inspection;
  @override
  State<CapabilitiesView> createState() => _CapabilitiesViewState();
}

class _CapabilitiesViewState extends State<CapabilitiesView> {
  rpc.CapabilityList? report;
  ResponseFuture<rpc.CapabilityList>? pending;
  bool busy = false;
  String error = '';
  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      report = null;
      error = '';
    });
    try {
      final model = widget.model, target = widget.target;
      model.requireTarget(target);
      final session = model.sessions[target.sessionId]!;
      final request = rpc.CapabilityRequest(
        context: target.backend.context(),
        sessionId: target.sessionId,
        contextRevision: target.contextRevision,
        sessionRevision: session.sessionRevision,
      );
      final reply = await model.ownedRequest(target, () {
        final response = target.backend.client.capabilities(request);
        pending = response;
        return response;
      });
      model.requireTarget(target);
      if (reply.backendInstance != target.backend.instanceId ||
          reply.sessionId != target.sessionId ||
          reply.contextRevision != request.contextRevision ||
          reply.sessionRevision != request.sessionRevision ||
          model.sessions[target.sessionId]?.sessionRevision !=
              request.sessionRevision) {
        throw StateError('Capability context changed; refresh the inspection');
      }
      if (reply.entries.length > 16 || reply.writeToBuffer().length > 32768) {
        throw StateError('Capability reply exceeds its inspector budget');
      }
      if (mounted) {
        setState(() {
          report = reply;
          widget.inspection?.loaded = true;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      pending = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final saved = widget.inspection;
    if (saved?.loaded == true) {
      report = saved!.report;
      error = saved.error;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(refresh());
      });
    }
  }

  @override
  void dispose() {
    final response = pending;
    if (response != null) {
      unawaited(response.cancel().catchError((Object _) {}));
    }
    final saved = widget.inspection;
    if (saved != null) {
      saved.report = report;
      saved.error = error;
    }
    super.dispose();
  }

  String stateLabel(rpc.Capability value) => switch (value.state) {
    rpc.CapabilityState.CAPABILITY_AVAILABLE =>
      value.dataChecked && value.empty
          ? strings(context).availableEmpty
          : strings(context).available,
    rpc.CapabilityState.CAPABILITY_LIMITED => strings(
      context,
    ).limitedVisibility,
    rpc.CapabilityState.CAPABILITY_DENIED => strings(context).permissionDenied,
    rpc.CapabilityState.CAPABILITY_UNSUPPORTED => strings(
      context,
    ).unsupportedLabel,
    rpc.CapabilityState.CAPABILITY_UNAVAILABLE => strings(context).unavailable,
    rpc.CapabilityState.CAPABILITY_DISABLED => strings(context).profileDisabled,
    _ => strings(context).unknownState,
  };

  String capabilityLabel(rpc.Capability value) => switch (value.id) {
    'transactions' => strings(context).manualTransaction,
    'metadata' => strings(context).databaseExplorer,
    'plans' => strings(context).explain,
    'actual-plans' => strings(context).explainAnalyze,
    'activities' => strings(context).sessionsAndLocks,
    'locks' => strings(context).locks,
    'query-statistics' => strings(context).queryStatistics,
    'index-diagnostics' => strings(context).indexDiagnostics,
    'principals' => strings(context).usersAndRoles,
    'grants' => strings(context).grants,
    'editing' => strings(context).changes,
    'schema-changes' =>
      '${strings(context).objectDesigner} / ${strings(context).compareSchemas}',
    'transfers' =>
      '${strings(context).importData} / ${strings(context).exportRetained}',
    _ => value.label,
  };

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls, value = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkbenchStrip(
          controls: ui,
          minimumHeight: 38,
          child: ui.tooltip(
            workbenchTargetDescription(context, widget.target),
            Text(workbenchTargetCaption(context, widget.target)),
          ),
        ),
        ui.textButton(
          busy
              ? strings(context).inspecting
              : strings(context).refreshCapabilities,
          busy ? null : refresh,
        ),
        if (error.isNotEmpty)
          Semantics(liveRegion: true, child: ui.status(error, error: true)),
        if (value != null) ...[
          Expanded(
            child: WorkbenchFormList(
              controls: ui,
              children: [
                WorkbenchReadOnlyProperty(
                  controls: ui,
                  label: strings(context).databaseSystem,
                  value: '${value.product} ${value.version}',
                ),
                WorkbenchReadOnlyProperty(
                  controls: ui,
                  label: strings(context).activityState,
                  value: value.availability,
                ),
                for (final entry in value.entries)
                  WorkbenchReadOnlyProperty(
                    controls: ui,
                    label: capabilityLabel(entry),
                    value: '${stateLabel(entry)}\n${entry.detail}',
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
