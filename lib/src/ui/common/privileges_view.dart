import '../../l10n/workbench_strings.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'authentication_form.dart';

import 'package:uuid/uuid.dart';

Future<void> showPrivileges(
  BuildContext context,
  WorkbenchModel model,
  DesktopControls ui, {
  WorkbenchDocument? ownerDocument,
}) async {
  final document = ownerDocument ?? model.activeOwner;
  final captured = model.captureTarget(owner: document);
  final session = document.sessionId;
  final profile = document.profileId;
  final schema =
      document.object?.schema ?? model.sessions[session]?.currentSchema ?? '';
  final table = document.object?.name ?? '';
  final target = model.sessions[session];
  if (session == null || target == null) {
    throw StateError('Connect a console before inspecting roles');
  }
  final process = model.backend!;
  final owner = document.id;
  void validateTarget() => model.requireTarget(captured);

  Future<rpc.PrivilegeReply> request(rpc.PrivilegeRequest value) {
    validateTarget();
    return model.ownedRequest(
      captured,
      () => process.client.privilegeTool(
        value
          ..context = process.context()
          ..sessionId = session,
      ),
    );
  }

  Future<void> account(rpc.Principal? principal) async {
    validateTarget();
    await ui.dialog<void>(
      context,
      '${strings(context).accountAuthentication} · ${target.profile.name}',
      WorkbenchDialogBody(
        child: AuthenticationForm(
          controls: ui,
          engine: target.profile.engine,
          principal: principal,
          submit: (value) async {
            validateTarget();
            value
              ..context = process.context()
              ..sessionId = session
              ..executionId = const Uuid().v4();
            final review = await process.client.reviewAuthentication(value);
            if (!context.mounted) return false;
            final accepted = await ui.dialog<bool>(
              context,
              strings(context).reviewAccount,
              SingleChildScrollView(
                child: Text(
                  [...review.statements, ...review.risks].join('\n\n'),
                ),
              ),
              [
                ui.button(
                  strings(context).cancel,
                  () => Navigator.of(context).pop(false),
                ),
                ui.button(
                  strings(context).applyView,
                  () => Navigator.of(context).pop(true),
                ),
              ],
            );
            if (accepted != true) return false;
            validateTarget();
            value.approvalToken = review.token;
            final job = await model.ownedRequest(
              captured,
              () => process.client.authentication(value),
            );
            if (identical(model.backend, process)) {
              model.track(job, documentId: owner);
            }
            return true;
          },
        ),
      ),
      [ui.button(strings(context).close, () => Navigator.of(context).pop())],
      bodyScrolls: true,
    );
  }

  final principals = await request(rpc.PrivilegeRequest());
  if (!context.mounted) return;
  validateTarget();
  model.openTask(
    WorkbenchDocumentKind.administration,
    '${strings(context).usersAndRoles} · ${target.profile.name}',
    profileId: profile,
    payload: PrivilegesDocumentData(
      target.profile.engine,
      principals,
      schema,
      table,
      !target.profile.readOnly,
      request,
      account,
      (reply) {
        validateTarget();
        model.newDocument(
          text: '-- ${reply.risks.join('\n-- ')}\n${reply.sql.join('\n')}',
        );
        model.document.profileId = profile;
      },
      target: captured,
    ),
  );
}

class PrivilegesDocumentData {
  const PrivilegesDocumentData(
    this.engine,
    this.initial,
    this.schema,
    this.table,
    this.writable,
    this.request,
    this.account,
    this.openSql, {
    this.target,
  });
  final rpc.Engine engine;
  final rpc.PrivilegeReply initial;
  final String schema, table;
  final bool writable;
  final Future<rpc.PrivilegeReply> Function(rpc.PrivilegeRequest) request;
  final Future<void> Function(rpc.Principal?) account;
  final void Function(rpc.PrivilegeReply) openSql;
  final CapturedWorkbenchTarget? target;
}

/// Shared database interaction; every field and action uses native composition.
class PrivilegesForm extends StatefulWidget {
  const PrivilegesForm({
    super.key,
    required this.controls,
    required this.engine,
    required this.initial,
    required this.request,
    required this.openSql,
    this.schema = '',
    this.table = '',
    this.writable = true,
    this.account,
    this.target,
  });
  final DesktopControls controls;
  final rpc.Engine engine;
  final rpc.PrivilegeReply initial;
  final Future<rpc.PrivilegeReply> Function(rpc.PrivilegeRequest) request;
  final ValueChanged<rpc.PrivilegeReply> openSql;
  final String schema, table;
  final bool writable;
  final Future<void> Function(rpc.Principal?)? account;
  final CapturedWorkbenchTarget? target;
  @override
  State<PrivilegesForm> createState() => _PrivilegesFormState();
}

class _PrivilegesFormState extends State<PrivilegesForm> {
  final search = TextEditingController();
  final privileges = TextEditingController(text: 'SELECT');
  late final schema = TextEditingController(text: widget.schema);
  late final table = TextEditingController(text: widget.table);
  late rpc.PrivilegeReply inspected = widget.initial.deepCopy();
  rpc.Principal? grantee, role;
  rpc.PrivilegeScope scope = rpc.PrivilegeScope.TABLE_PRIVILEGE;
  bool revoke = false, delegation = false, busy = false;
  String error = '';

  @override
  void dispose() {
    for (final controller in [search, privileges, schema, table]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> inspect({bool searching = false}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final reply = await widget.request(
        rpc.PrivilegeRequest(
          grantee: searching ? null : grantee,
          search: search.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        inspected = reply;
        if (searching) {
          grantee = null;
          role = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> generate() async {
    if (grantee == null || inspected.definition.isEmpty) {
      setState(() => error = strings(context).inspectPrincipalFirst);
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final reply = await widget.request(
        rpc.PrivilegeRequest(
          action: rpc.PrivilegeAction.DESIGN_PRIVILEGE,
          grantee: grantee,
          scope: scope,
          schema: schema.text,
          table: table.text,
          role: role,
          privileges:
              const {
                rpc.PrivilegeScope.ROLE_MEMBERSHIP,
                rpc.PrivilegeScope.DEFAULT_ROLE,
              }.contains(scope)
              ? const []
              : privileges.text.split(',').map((p) => p.trim()).toList(),
          revoke: revoke,
          delegation: delegation,
        ),
      );
      if (mounted) widget.openSql(reply);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String label(rpc.Principal principal) =>
      '${principal.name}${principal.host.isEmpty ? '' : '@${principal.host}'} · ${principal.kind}';

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls;
    final principals = inspected.principals;
    final roles = principals
        .where((p) => widget.engine != rpc.Engine.MARIADB || p.kind == 'role')
        .toList();
    Widget formAction(
      String label,
      VoidCallback? callback, {
      bool primary = false,
    }) => Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: ui.button(label, callback, primary: primary),
    );
    return AbsorbPointer(
      absorbing: busy,
      child: FocusScope(
        canRequestFocus: !busy,
        child: WorkbenchForm(
          maxWidth: ui.formContentWidth,
          footer: WorkbenchStrip(
            controls: ui,
            topBorder: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            error,
                            style: ui
                                .appearance(context)
                                .body
                                .copyWith(color: ui.appearance(context).error),
                          ),
                        ),
                      ),
                    ),
                  ),
                formAction(
                  strings(context).openPrivilegeSql,
                  busy || !widget.writable ? null : generate,
                  primary: true,
                ),
              ],
            ),
          ),
          child: WorkbenchFormList(
            controls: ui,
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.target case final target?)
                WorkbenchStrip(
                  controls: ui,
                  minimumHeight: 42,
                  child: ui.tooltip(
                    workbenchTargetDescription(context, target),
                    Text(workbenchTargetCaption(context, target)),
                  ),
                ),
              Text(strings(context).privilegeReviewNote),
              WorkbenchFormHeading(
                controls: ui,
                label: strings(context).usersAndRoles,
              ),
              ui.field(search, strings(context).findPrincipal),
              formAction(
                strings(context).searchPrincipals,
                busy ? null : () => inspect(searching: true),
              ),
              if (inspected.limited) Text(strings(context).inspectionLimited),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ui.choice<int>(
                    grantee == null ? -1 : principals.indexOf(grantee!),
                    {
                      -1: strings(context).choosePrincipal,
                      for (var i = 0; i < principals.length; i++)
                        i: label(principals[i]),
                    },
                    (value) {
                      setState(() {
                        grantee = value < 0 ? null : principals[value];
                        inspected.definition = '';
                      });
                    },
                  ),
                  formAction(
                    strings(context).inspectGrants,
                    busy || grantee == null ? null : () => inspect(),
                  ),
                ],
              ),
              if (inspected.definition.isNotEmpty)
                WorkbenchCodeEvidence(controls: ui, text: inspected.definition),
              WorkbenchFormHeading(
                controls: ui,
                label: strings(context).grants,
              ),
              ui.comboRow(
                strings(context).grants,
                scope,
                {
                  rpc.PrivilegeScope.TABLE_PRIVILEGE: strings(
                    context,
                  ).tablePrivileges,
                  if (widget.engine == rpc.Engine.POSTGRESQL)
                    rpc.PrivilegeScope.SCHEMA_PRIVILEGE: strings(
                      context,
                    ).schemaPrivileges,
                  rpc.PrivilegeScope.DATABASE_PRIVILEGE: strings(
                    context,
                  ).databasePrivileges,
                  rpc.PrivilegeScope.ROLE_MEMBERSHIP: strings(
                    context,
                  ).roleMembership,
                  if (widget.engine != rpc.Engine.POSTGRESQL)
                    rpc.PrivilegeScope.DEFAULT_ROLE: strings(
                      context,
                    ).defaultRole,
                },
                (value) {
                  setState(() {
                    scope = value;
                    if (scope == rpc.PrivilegeScope.DEFAULT_ROLE) {
                      delegation = false;
                    }
                    privileges.text =
                        value == rpc.PrivilegeScope.SCHEMA_PRIVILEGE
                        ? 'USAGE'
                        : value == rpc.PrivilegeScope.DATABASE_PRIVILEGE &&
                              widget.engine == rpc.Engine.POSTGRESQL
                        ? 'CONNECT'
                        : 'SELECT';
                  });
                },
              ),
              if (const {
                rpc.PrivilegeScope.ROLE_MEMBERSHIP,
                rpc.PrivilegeScope.DEFAULT_ROLE,
              }.contains(scope))
                ui.comboRow<int>(
                  strings(context).chooseGrantRole,
                  role == null ? -1 : roles.indexOf(role!),
                  {
                    -1: strings(context).chooseGrantRole,
                    for (var i = 0; i < roles.length; i++) i: label(roles[i]),
                  },
                  (value) =>
                      setState(() => role = value < 0 ? null : roles[value]),
                )
              else ...[
                ui.field(
                  schema,
                  scope == rpc.PrivilegeScope.DATABASE_PRIVILEGE
                      ? strings(context).database
                      : widget.engine == rpc.Engine.POSTGRESQL
                      ? strings(context).schema
                      : strings(context).database,
                ),
                if (scope == rpc.PrivilegeScope.TABLE_PRIVILEGE)
                  ui.field(table, strings(context).tableView),
                ui.field(privileges, strings(context).explicitPrivileges),
              ],
              ui.comboRow(
                strings(context).actionsCategory,
                revoke,
                scope == rpc.PrivilegeScope.DEFAULT_ROLE
                    ? {
                        false: strings(context).setDefaultRole,
                        true: strings(context).clearDefaultRole,
                      }
                    : {
                        false: strings(context).grantAccess,
                        true: strings(context).revokeAccess,
                      },
                (value) {
                  setState(() {
                    revoke = value;
                    if (revoke) delegation = false;
                  });
                },
              ),
              if (!revoke && scope != rpc.PrivilegeScope.DEFAULT_ROLE)
                ui.switchRow(
                  strings(context).allowDelegation,
                  delegation,
                  (value) => setState(() => delegation = value),
                ),
              if (!widget.writable) Text(strings(context).readonlyChanges),
              if (widget.account != null && widget.writable) ...[
                WorkbenchFormHeading(
                  controls: ui,
                  label: strings(context).accountAuthentication,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    formAction(
                      strings(context).createPrincipal,
                      busy ? null : () => widget.account!(null),
                    ),
                    formAction(
                      strings(context).manageAuthentication,
                      busy || grantee == null
                          ? null
                          : () => widget.account!(grantee),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
