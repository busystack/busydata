import '../../l10n/workbench_strings.dart';
import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

/// Passwords remain in this modal and its private typed command, never SQL tabs.
class AuthenticationForm extends StatefulWidget {
  const AuthenticationForm({
    super.key,
    required this.controls,
    required this.engine,
    required this.submit,
    this.principal,
  });
  final DesktopControls controls;
  final rpc.Engine engine;
  final rpc.Principal? principal;
  final Future<bool> Function(rpc.AuthenticationRequest) submit;
  @override
  State<AuthenticationForm> createState() => _AuthenticationFormState();
}

class _AuthenticationFormState extends State<AuthenticationForm> {
  late final name = TextEditingController(text: widget.principal?.name ?? '');
  late final host = TextEditingController(text: widget.principal?.host ?? '');
  final password = TextEditingController(), repeated = TextEditingController();
  late rpc.AuthenticationAction action = widget.principal == null
      ? rpc.AuthenticationAction.CREATE_LOGIN
      : rpc.AuthenticationAction.SET_PASSWORD;
  bool busy = false;
  String error = '';
  bool get creates =>
      action == rpc.AuthenticationAction.CREATE_LOGIN ||
      action == rpc.AuthenticationAction.CREATE_ROLE;
  bool get needsPassword =>
      action == rpc.AuthenticationAction.CREATE_LOGIN ||
      action == rpc.AuthenticationAction.SET_PASSWORD;
  @override
  void dispose() {
    for (final controller in [name, host, password, repeated]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (needsPassword &&
        (password.text.isEmpty || password.text != repeated.text)) {
      setState(() => error = strings(context).passwordsMismatch);
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    final request = rpc.AuthenticationRequest(
      action: action,
      principal: rpc.Principal(
        name: name.text,
        host:
            widget.engine == rpc.Engine.POSTGRESQL ||
                widget.engine == rpc.Engine.MARIADB &&
                    action == rpc.AuthenticationAction.CREATE_ROLE
            ? ''
            : host.text,
      ),
      password: needsPassword ? password.text : '',
    );
    try {
      final accepted = await widget.submit(request);
      if (accepted && mounted) {
        password.clear();
        repeated.clear();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = strings(context).accountSubmitFailed);
      }
    } finally {
      request.clearPassword();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls;
    return AbsorbPointer(
      absorbing: busy,
      child: FocusScope(
        canRequestFocus: !busy,
        child: WorkbenchFormList(
          controls: ui,
          children: [
            Text(strings(context).authReviewNote),
            ui.comboRow(
              strings(context).actionsCategory,
              action,
              {
                if (widget.principal == null)
                  rpc.AuthenticationAction.CREATE_LOGIN: strings(
                    context,
                  ).createLogin,
                if (widget.principal == null)
                  rpc.AuthenticationAction.CREATE_ROLE: strings(
                    context,
                  ).createRole,
                if (widget.principal != null) ...{
                  rpc.AuthenticationAction.SET_PASSWORD: strings(
                    context,
                  ).setPassword,
                  rpc.AuthenticationAction.LOCK_LOGIN: strings(
                    context,
                  ).preventLogin,
                  rpc.AuthenticationAction.UNLOCK_LOGIN: strings(
                    context,
                  ).allowLogin,
                  rpc.AuthenticationAction.DROP_PRINCIPAL: strings(
                    context,
                  ).dropPrincipal,
                },
              },
              (value) => setState(() {
                action = value;
                password.clear();
                repeated.clear();
                error = '';
              }),
            ),
            ui.field(name, strings(context).principalName, enabled: creates),
            if (widget.engine != rpc.Engine.POSTGRESQL &&
                !(widget.engine == rpc.Engine.MARIADB &&
                    action == rpc.AuthenticationAction.CREATE_ROLE))
              ui.field(host, strings(context).accountHost, enabled: creates),
            if (needsPassword) ...[
              ui.field(password, strings(context).newPassword, secret: true),
              ui.field(repeated, strings(context).repeatPassword, secret: true),
            ],
            if (error.isNotEmpty) ui.status(error, error: true),
            ui.button(strings(context).reviewAccount, busy ? null : submit),
          ],
        ),
      ),
    );
  }
}
