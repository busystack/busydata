import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart' show ResponseFuture, CallOptions;
import 'package:uuid/uuid.dart';
import '../../backend/connection_failure.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/connection_credentials.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'connection_presentation.dart';

enum _Operation { idle, testing, saving, connecting, cancelling, reviewing }

enum _SshMethod { password, key, agent }

/// Independent mutable source drafts; secrets live only for this modal operation.
class _SourceDraft {
  _SourceDraft(
    rpc.Profile? profile,
    VoidCallback changed, {
    String defaultName = '',
  }) : original = profile?.deepCopy(),
       id = profile?.id ?? const Uuid().v4(),
       engine = profile?.engine ?? rpc.Engine.POSTGRESQL,
       environment = profile?.environment ?? rpc.Environment.DEVELOPMENT,
       tls = profile?.tls.mode ?? rpc.TlsMode.DRIVER_DEFAULT,
       readOnly = profile?.readOnly ?? false,
       remember = profile?.credentialRef.isNotEmpty ?? false,
       keyRemember = profile?.tls.keyCredentialRef.isNotEmpty ?? false,
       ssh = profile?.ssh.enabled ?? false,
       javaTrust = profile?.tls.hasJavaTrust() == true
           ? profile!.tls.javaTrust
           : profile?.tls.caFile.isEmpty ?? true,
       systemTrust = profile?.tls.systemTrust ?? false,
       credentialRef = profile?.credentialRef ?? '',
       keyCredentialRef = profile?.tls.keyCredentialRef ?? '',
       trustRef = profile?.ssh.trustRef ?? '',
       method = profile?.ssh.agent == true
           ? _SshMethod.agent
           : profile?.ssh.privateKey.isNotEmpty == true
           ? _SshMethod.key
           : _SshMethod.password {
    final configured = profile?.tls.hasConfiguredMode() == true
        ? profile!.tls.configuredMode
        : tls;
    if ([
      rpc.TlsMode.INSECURE,
      rpc.TlsMode.VERIFY_CA,
      rpc.TlsMode.VERIFY_FULL,
    ].contains(configured)) {
      retainedTls = configured;
    }
    final defaults = <String, String>{
      'name': profile?.name ?? defaultName,
      'host': profile?.host ?? 'localhost',
      'port': '${profile?.port ?? 5432}',
      'user': profile?.user ?? '',
      'database': profile?.database ?? '',
      'password': '',
      'tlsPassword': '',
      'url': '',
      'ca': profile?.tls.caFile ?? '',
      'cert': profile?.tls.clientCert ?? '',
      'key': profile?.tls.clientKey ?? '',
      'connectTimeout': '${profile?.connectTimeoutSeconds ?? 10}',
      'queryTimeout': '${profile?.queryTimeoutSeconds ?? 60}',
      'sshHost': profile?.ssh.host ?? '',
      'sshPort': '${profile?.ssh.port == 0 ? 22 : profile?.ssh.port ?? 22}',
      'sshUser': profile?.ssh.user ?? '',
      'knownHosts': profile?.ssh.knownHosts ?? '',
      'sshKey': profile?.ssh.privateKey ?? '',
      'agentSocket': profile?.ssh.agentSocket ?? '',
      'agentFingerprint': profile?.ssh.agentKeyFingerprint ?? '',
      'sshPassword': '',
      'passphrase': '',
    };
    for (final e in defaults.entries) {
      fields[e.key] = TextEditingController(text: e.value);
      if (e.key != 'url') fields[e.key]!.addListener(changed);
      if (e.key == 'port') fields[e.key]!.addListener(() => portEdited = true);
      if (e.key == 'ca') fields[e.key]!.addListener(() => rootsEdited = true);
      focus[e.key] = FocusNode(debugLabel: 'Connection ${e.key}');
    }
    dirty = profile == null;
    rootsEdited = profile == null;
    if (profile != null &&
        profile.engine == rpc.Engine.MARIADB &&
        profile.tls.mode == rpc.TlsMode.VERIFY_FULL &&
        profile.tls.caFile.isEmpty &&
        !profile.tls.hasJavaTrust() &&
        !profile.tls.hasSystemTrust()) {
      javaTrust = false;
    }
  }
  rpc.Profile? original;
  final String id;
  final fields = <String, TextEditingController>{},
      focus = <String, FocusNode>{};
  rpc.Engine engine;
  rpc.Environment environment;
  rpc.TlsMode tls, retainedTls = rpc.TlsMode.INSECURE;
  _SshMethod method;
  bool readOnly,
      remember,
      keyRemember,
      ssh,
      javaTrust,
      systemTrust,
      dirty = false;
  String credentialRef, keyCredentialRef, trustRef;
  String feedback = '', details = '', savedName = '';
  bool feedbackError = false;
  bool testSucceeded = false, sshTestSucceeded = false, saved = false;
  String sshFeedback = '', sshDetails = '';
  bool portEdited = false;
  bool rootsEdited = false;
  int fieldRevision = 0;
  rpc.ConnectionDescription? description;
  void dispose(VoidCallback changed) {
    for (final c in fields.values) {
      c.removeListener(changed);
      c.dispose();
    }
    for (final f in focus.values) {
      f.dispose();
    }
  }
}

/// The manager owns every draft, validation, request revision and persistent action.
class ConnectionForm extends StatefulWidget {
  const ConnectionForm({
    super.key,
    required this.model,
    required this.controls,
    this.initial,
    required this.connect,
    required this.reviewHost,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final rpc.Profile? initial;
  final Future<void> Function(
    rpc.Profile,
    ConnectionCredentials,
    bool Function(),
  )
  connect;
  final Future<bool> Function(String, String) reviewHost;
  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  final errors = <String, String>{};
  final drafts = <String, _SourceDraft>{};
  final removed = <rpc.Profile>[];
  final detailsKey = GlobalKey();
  final settingsScroll = ScrollController();
  late final backend = widget.model.backend!;
  _SourceDraft? _selected;
  _SourceDraft get selected => _selected!;
  set selected(_SourceDraft? value) => _selected = value;
  final emptyName = TextEditingController();
  String emptyFeedback = '', emptyDetails = '';
  bool emptyFeedbackError = false;
  late final String destinationId;
  String tab = 'General';
  bool detailsOpen = false, dismissed = false, sshEditorOpen = false;
  StateSetter? sshRefresh;
  _Operation operation = _Operation.idle;
  int revision = 0, generation = 0, descriptionGeneration = 0;
  Timer? descriptionTimer;
  ResponseFuture<rpc.ConnectionInfo>? testCall;
  ResponseFuture<rpc.SshTestReply>? sshTestCall;
  DesktopControls get ui => widget.controls;
  Map<String, TextEditingController> get fields => selected.fields;
  Map<String, FocusNode> get focus => selected.focus;
  String get id => selected.id;
  rpc.Engine get engine => selected.engine;
  set engine(rpc.Engine v) => selected.engine = v;
  rpc.Environment get environment => selected.environment;
  set environment(rpc.Environment v) => selected.environment = v;
  rpc.TlsMode get tls => selected.tls;
  set tls(rpc.TlsMode v) => selected.tls = v;
  bool get readOnly => selected.readOnly;
  set readOnly(bool v) => selected.readOnly = v;
  bool get remember => selected.remember;
  set remember(bool v) => selected.remember = v;
  bool get ssh => selected.ssh;
  set ssh(bool v) => selected.ssh = v;
  _SshMethod get method => selected.method;
  set method(_SshMethod v) => selected.method = v;
  String get credentialRef => selected.credentialRef;
  set credentialRef(String v) => selected.credentialRef = v;
  String get trustRef => selected.trustRef;
  set trustRef(String v) => selected.trustRef = v;
  bool get feedbackError => _selected?.feedbackError ?? emptyFeedbackError;
  set feedbackError(bool value) {
    if (_selected != null) {
      selected.feedbackError = value;
    } else {
      emptyFeedbackError = value;
    }
  }

  String get feedback => _selected?.feedback ?? emptyFeedback;
  set feedback(String v) {
    feedbackError = false;
    if (_selected != null) {
      selected.feedback = v;
    } else {
      emptyFeedback = v;
    }
  }

  String get details => _selected?.details ?? emptyDetails;
  set details(String v) {
    if (_selected != null) {
      selected.details = v;
    } else {
      emptyDetails = v;
    }
  }

  String get savedName => selected.savedName;
  set savedName(String v) => selected.savedName = v;
  bool get saved => selected.saved;
  set saved(bool v) => selected.saved = v;
  bool get testSucceeded => selected.testSucceeded;
  set testSucceeded(bool v) => selected.testSucceeded = v;
  String value(String key) => fields[key]!.text;
  bool get idle => operation == _Operation.idle;
  bool get sslEnabled =>
      ![rpc.TlsMode.DISABLED, rpc.TlsMode.DRIVER_DEFAULT].contains(tls);

  @override
  void initState() {
    super.initState();
    for (final profile in widget.model.profiles) {
      final d = _SourceDraft(profile, changed);
      drafts[d.id] = d;
    }
    final initial = widget.initial;
    selected = initial == null
        ? _SourceDraft(null, changed)
        : drafts[initial.id] ?? _SourceDraft(initial, changed);
    if (!widget.model.profiles.any((profile) => profile.id == selected.id)) {
      selected.dirty = true;
    }
    drafts[selected.id] = selected;
    destinationId = selected.id;
    unawaited(loadStoredPassword());
    unawaited(describe());
  }

  bool initializedDefaultName = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initializedDefaultName) {
      initializedDefaultName = true;
      if (widget.initial == null &&
          selected.original == null &&
          selected.fields['name']!.text.isEmpty) {
        selected.fields['name']!.text = strings(context).newConnection;
      }
    }
  }

  Future<void> loadStoredPassword() async {
    if (_selected == null) return;
    final draft = selected, before = revision;
    if (draft.credentialRef.isEmpty && draft.keyCredentialRef.isEmpty ||
        draft.dirty) {
      return;
    }
    try {
      final password = draft.credentialRef.isEmpty
          ? null
          : await widget.model.secrets.read(draft.credentialRef);
      final keyPassword = draft.keyCredentialRef.isEmpty
          ? null
          : await widget.model.secrets.read(draft.keyCredentialRef);
      if (mounted &&
          !dismissed &&
          identical(_selected, draft) &&
          revision == before) {
        if (password != null) {
          fields['password']!.text = password;
        }
        if (keyPassword != null) {
          fields['tlsPassword']!.text = keyPassword;
        }
        draft.dirty = false;
      }
    } catch (_) {
      if (mounted && identical(_selected, draft)) {
        setState(
          () => feedback = strings(context).connectionStorageUnavailable,
        );
      }
    }
  }

  void changed() {
    revision++;
    descriptionGeneration++;
    if (!mounted || dismissed || _selected == null) return;
    setState(() {
      selected.dirty = true;
      selected.fieldRevision++;
      errors.clear();
      if (testSucceeded) {
        testSucceeded = false;
        feedback = strings(context).connectionSettingsChanged;
        details = '';
      }
      if (selected.sshTestSucceeded) {
        selected.sshTestSucceeded = false;
        selected.sshFeedback = strings(context).connectionSettingsChanged;
        selected.sshDetails = '';
      }
    });
    sshRefresh?.call(() {});
    descriptionTimer?.cancel();
    descriptionTimer = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(describe()),
    );
  }

  Future<void> describe() async {
    if (_selected == null) return;
    final token = ++descriptionGeneration, draft = selected;
    final port = int.tryParse(value('port'));
    if (port == null || port < 1 || port > 65535) {
      fields['url']!.clear();
      return;
    }
    try {
      final description = await backend.client.describeConnection(
        rpc.ProfileRequest(
          context: backend.context(),
          profile: rpc.Profile(
            engine: engine,
            host: value('host'),
            port: port,
            database: value('database'),
          ),
        ),
      );
      if (mounted &&
          !dismissed &&
          token == descriptionGeneration &&
          identical(_selected, draft) &&
          identical(widget.model.backend, backend)) {
        setState(() {
          draft.description = description;
          fields['url']!.text = description.jdbcUrl;
        });
      }
    } catch (_) {
      if (mounted &&
          identical(_selected, draft) &&
          token == descriptionGeneration) {
        setState(() => fields['url']!.clear());
      }
    }
  }

  void selectSource(_SourceDraft draft) {
    if (!idle) return;
    setState(() {
      selected = draft;
      revision++;
      errors.clear();
      detailsOpen = false;
    });
    unawaited(loadStoredPassword());
    unawaited(describe());
    revealPageStart();
  }

  void revealPageStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && settingsScroll.hasClients) settingsScroll.jumpTo(0);
    });
  }

  void addSource({bool duplicate = false}) {
    if (!idle) return;
    final source = _selected;
    if (duplicate && source == null) return;
    final draft = _SourceDraft(
      null,
      changed,
      defaultName: strings(context).newConnection,
    );
    if (duplicate && source != null) {
      for (final key in source.fields.keys.where(
        (key) => ![
          'password',
          'tlsPassword',
          'sshPassword',
          'passphrase',
          'url',
        ].contains(key),
      )) {
        draft.fields[key]!.removeListener(changed);
        draft.fields[key]!.text = source.fields[key]!.text;
        draft.fields[key]!.addListener(changed);
      }
      draft.fields['name']!.removeListener(changed);
      draft.fields['name']!.text =
          '${source.fields['name']!.text} · ${strings(context).copy}';
      draft.fields['name']!.addListener(changed);
      draft.engine = source.engine;
      draft.environment = source.environment;
      draft.tls = source.tls;
      draft.retainedTls = source.retainedTls;
      draft.ssh = source.ssh;
      draft.method = source.method;
      draft.javaTrust = source.javaTrust;
      draft.systemTrust = source.systemTrust;
      draft.readOnly = source.readOnly;
      draft.portEdited = source.portEdited;
      draft.rootsEdited = source.rootsEdited;
      // Preserve allowlisted settings without copying identity or consent.
      draft.original = source.original?.deepCopy();
      if (draft.original != null) {
        draft.original!.id = draft.id;
        draft.original!.clearCredentialRef();
        // Absent protobuf submessages are immutable defaults. Copy them before
        // stripping consent/credential references from the independent draft.
        draft.original!.tls = draft.original!.tls.deepCopy();
        draft.original!.ssh = draft.original!.ssh.deepCopy();
        draft.original!.tls.clearKeyCredentialRef();
        draft.original!.ssh.clearTrustRef();
      }
    }
    draft.dirty = true;
    drafts[draft.id] = draft;
    selectSource(draft);
  }

  void removeSource() {
    if (!idle || _selected == null) return;
    final draft = selected;
    if (widget.model.profiles.any((profile) => profile.id == draft.id)) {
      removed.add(draft.original!.deepCopy());
    }
    drafts.remove(draft.id);
    if (drafts.isEmpty) {
      descriptionTimer?.cancel();
      setState(() {
        selected = null;
        revision++;
        descriptionGeneration++;
        errors.clear();
        detailsOpen = false;
      });
    } else {
      selectSource(drafts.values.first);
    }
    draft.dispose(changed);
  }

  rpc.Profile buildProfile() => (selected.original?.deepCopy() ?? rpc.Profile())
    ..id = id
    ..name = value('name')
    ..engine = engine
    ..host = value('host')
    ..port = int.parse(value('port'))
    ..database = value('database')
    ..user = value('user')
    ..environment = environment
    ..readOnly = readOnly
    ..connectTimeoutSeconds = int.parse(value('connectTimeout'))
    ..queryTimeoutSeconds = int.parse(value('queryTimeout'))
    ..credentialRef = credentialRef
    ..tls = buildTls()
    ..ssh = buildSsh();

  rpc.Ssh buildSsh() => rpc.Ssh(
    enabled: ssh,
    host: value('sshHost'),
    port: ssh ? int.parse(value('sshPort')) : selected.original?.ssh.port ?? 22,
    user: value('sshUser'),
    knownHosts: value('knownHosts'),
    trustRef: trustRef,
    privateKey: method == _SshMethod.key ? value('sshKey') : '',
    agent: method == _SshMethod.agent,
    agentSocket: method == _SshMethod.agent ? value('agentSocket') : '',
    agentKeyFingerprint: method == _SshMethod.agent
        ? value('agentFingerprint')
        : '',
  );
  rpc.Tls buildTls() {
    final result = rpc.Tls(
      mode: tls,
      caFile: value('ca'),
      clientCert: value('cert'),
      clientKey: value('key'),
      keyCredentialRef: selected.keyCredentialRef,
      configuredMode: selected.retainedTls,
    );
    if (selected.rootsEdited ||
        selected.original?.tls.hasJavaTrust() == true ||
        selected.original?.tls.hasSystemTrust() == true) {
      result.javaTrust = selected.javaTrust;
      result.systemTrust = selected.systemTrust;
    }
    return result;
  }

  ConnectionCredentials get credentials => ConnectionCredentials(
    password: value('password'),
    sshPassword: ssh && method == _SshMethod.password
        ? value('sshPassword')
        : '',
    keyPassphrase: ssh && method == _SshMethod.key ? value('passphrase') : '',
    tlsKeyPassword: sslEnabled && value('key').isNotEmpty
        ? value('tlsPassword')
        : '',
  );

  bool validate() {
    if (_selected == null) return false;
    // Mirrors JdbcAdapter.validate. Empty database/password are permitted.
    final invalid = <String, String>{};
    void required(String key) {
      if (value(key).trim().isEmpty) {
        invalid[key] = strings(context).connectionRequired;
      }
    }

    void number(String key, int min, int max) {
      final raw = value(key);
      final parsed = RegExp(r'^\d+$').hasMatch(raw) ? int.tryParse(raw) : null;
      if (parsed == null || parsed < min || parsed > max) {
        invalid[key] = strings(context).connectionNumber(min, max);
      }
    }

    for (final key in ['name', 'host', 'user']) {
      required(key);
    }
    final hostPattern = RegExp(r'^[A-Za-z0-9_.:\[\]-]+$');
    if (!hostPattern.hasMatch(value('host'))) {
      invalid['host'] = strings(context).connectionHostname;
    }
    for (final key in ['name', 'host', 'database']) {
      if (value(key).length > 256) {
        invalid[key] = strings(context).connectionMaxLength;
      }
    }
    number('port', 1, 65535);
    number('connectTimeout', 1, 120);
    number('queryTimeout', 0, 3600);
    if (sslEnabled && value('cert').isEmpty != value('key').isEmpty) {
      invalid[value('cert').isEmpty ? 'cert' : 'key'] =
          'Select both client certificate and key';
    }
    if (ssh) {
      number('sshPort', 0, 65535);
      required('sshHost');
      required('sshUser');
      if (!hostPattern.hasMatch(value('sshHost')) ||
          value('sshHost').length > 256) {
        invalid['sshHost'] = strings(context).connectionSshHostname;
      }
      if (method == _SshMethod.key) required('sshKey');
      if (method == _SshMethod.agent) {
        required('agentSocket');
        required('agentFingerprint');
      }
    }
    setState(() {
      errors
        ..clear()
        ..addAll(invalid);
      if (invalid.isNotEmpty) {
        final first = invalid.keys.first;
        tab = ['connectTimeout', 'queryTimeout'].contains(first)
            ? 'Options'
            : first.startsWith('ssh') ||
                  first.startsWith('agent') ||
                  ['ca', 'cert', 'key', 'tlsPassword'].contains(first)
            ? 'SSH/SSL'
            : 'General';
        feedback = strings(context).connectionCorrectFields;
        feedbackError = true;
        details = '';
      }
    });
    if (invalid.isEmpty) return true;
    final draft = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !dismissed && _selected == draft) {
        final first = invalid.keys.first;
        if ((first.startsWith('ssh') || first.startsWith('agent')) &&
            !sshEditorOpen) {
          unawaited(editSsh(invalid: first));
        } else {
          draft.focus[first]!.requestFocus();
        }
      }
    });
    return false;
  }

  bool current(int token) =>
      mounted &&
      !dismissed &&
      token == generation &&
      identical(widget.model.backend, backend);

  bool validateSsh({bool reviewOnly = false}) {
    if (_selected == null || !ssh) return false;
    final invalid = <String, String>{};
    final port = RegExp(r'^\d+$').hasMatch(value('sshPort'))
        ? int.tryParse(value('sshPort'))
        : null;
    if (!RegExp(r'^[A-Za-z0-9_.:\[\]-]+$').hasMatch(value('sshHost')) ||
        value('sshHost').length > 256) {
      invalid['sshHost'] = strings(context).connectionSshHostname;
    }
    if (port == null || port < 0 || port > 65535) {
      invalid['sshPort'] = strings(context).connectionNumber(0, 65535);
    }
    if (!reviewOnly) {
      for (final key in [
        'sshUser',
        if (method == _SshMethod.key) 'sshKey',
        if (method == _SshMethod.agent) ...['agentSocket', 'agentFingerprint'],
      ]) {
        if (value(key).trim().isEmpty) {
          invalid[key] = strings(context).connectionRequired;
        }
      }
    }
    setState(() {
      errors
        ..clear()
        ..addAll(invalid);
      if (invalid.isNotEmpty) {
        selected.sshFeedback = strings(context).connectionCorrectFields;
        selected.sshDetails = '';
      }
    });
    if (invalid.isEmpty) return true;
    final draft = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !dismissed && _selected == draft && sshEditorOpen) {
        draft.focus[invalid.keys.first]!.requestFocus();
      }
    });
    return false;
  }

  void sshFailure(Object error) {
    final failure = ConnectionFailure.from(error);
    setState(() {
      selected.sshFeedback =
          '${strings(context).sshConfigurationLabel}: ${failure.localizedSummary(strings(context))}';
      selected.sshDetails = failure.details;
    });
  }

  Future<void> testSsh() async {
    if (!idle || !validateSsh()) return;
    final draft = selected, testedRevision = revision, token = ++generation;
    final request = rpc.SshTestRequest(
      context: backend.context(),
      profileId: draft.id,
      ssh: buildSsh(),
      sshPassword: method == _SshMethod.password ? value('sshPassword') : '',
      keyPassphrase: method == _SshMethod.key ? value('passphrase') : '',
    );
    setState(() {
      operation = _Operation.testing;
      draft.sshFeedback = strings(context).testRunning;
      draft.sshDetails = '';
      draft.sshTestSucceeded = false;
    });
    try {
      if (!identical(widget.model.backend, backend)) {
        throw StateError('Backend changed; reopen connection settings');
      }
      final call = backend.client.testSshConnection(
        request,
        options: CallOptions(timeout: const Duration(seconds: 15)),
      );
      sshTestCall = call;
      final info = await call;
      if (!current(token) || _selected != draft) return;
      setState(() {
        draft.sshTestSucceeded = testedRevision == revision;
        draft.sshFeedback = testedRevision == revision
            ? '${strings(context).connected} · SSH · ${info.user}@${info.host}:${info.port}'
            : strings(context).connectionTestChanged;
        draft.sshDetails = testedRevision == revision
            ? '${info.algorithm} · ${info.fingerprint}'
            : '';
      });
    } catch (error) {
      if (current(token) && _selected == draft && revision == testedRevision) {
        sshFailure(error);
      }
    } finally {
      if (mounted && !dismissed && token == generation) {
        setState(() {
          operation = _Operation.idle;
          sshTestCall = null;
          if (!identical(widget.model.backend, backend)) {
            draft.sshFeedback = strings(context).connectionTestChanged;
            draft.sshDetails = '';
          }
        });
      }
    }
  }

  void failure(Object error, {bool connectionAttempt = false}) {
    final diagnostic = ConnectionFailure.from(error);
    setState(() {
      final prefix = connectionAttempt && _selected != null && saved
          ? strings(context).connectionSavedFailure(savedName)
          : '${_selected == null ? strings(context).managerTitle : value('name')}: ';
      feedback =
          prefix +
          (error is CredentialStorageFailure ||
                  error is ProfileSaveUncertain ||
                  error is StateError
              ? error.toString().replaceFirst('Bad state: ', '')
              : diagnostic.localizedSummary(strings(context)));
      details = diagnostic.details;
      feedbackError = true;
      detailsOpen = false;
    });
  }

  Future<void> test() async {
    if (!idle || _selected == null || !validate()) return;
    final testedRevision = revision, token = ++generation;
    final p = buildProfile(), secret = credentials;
    setState(() {
      operation = _Operation.testing;
      feedback = strings(context).testRunning;
      details = '';
      testSucceeded = false;
    });
    try {
      if (!identical(widget.model.backend, backend)) {
        throw StateError('Backend changed; reopen connection settings');
      }
      final call = backend.client.testConnection(
        rpc.OpenRequest(
          context: backend.context(),
          profile: p,
          password: secret.password,
          sshPassword: secret.sshPassword,
          keyPassphrase: secret.keyPassphrase,
          tlsKeyPassword: secret.tlsKeyPassword,
        ),
      );
      testCall = call;
      final info = await call;
      if (!mounted || !current(token)) return;
      setState(() {
        testSucceeded = testedRevision == revision;
        feedback = testSucceeded
            ? '${info.product} ${info.version} · ${info.host}:${info.port}/${info.database}'
            : strings(context).connectionTestChanged;
        final l = strings(context);
        details = testSucceeded
            ? '${l.databaseSystem}: ${info.product} ${info.version}\n${l.host}: ${info.host}:${info.port}/${info.database}\n${l.databaseTlsEvidence}: ${info.tlsObserved
                  ? info.tlsCipher.isEmpty
                        ? l.tlsUnencrypted
                        : '${l.tlsEncrypted} · ${info.tlsCipher}'
                  : l.tlsUnobserved}\n${l.encryptionVerificationNote}'
            : '';
      });
    } catch (error) {
      if (current(token)) failure(error);
    } finally {
      if (mounted && !dismissed && token == generation) {
        setState(() {
          operation = _Operation.idle;
          testCall = null;
        });
      }
    }
  }

  Future<void> save(bool complete) async {
    if (!idle) return;
    final savedDraftChanged = strings(context).connectionSavedDraftChanged;
    final previous = _selected;
    for (final draft in drafts.values.where(
      (d) => d.dirty || d.id == destinationId && complete,
    )) {
      selected = draft;
      if (!validate()) {
        setState(() {});
        return;
      }
    }
    selected = previous;
    _SourceDraft? attempted;
    rpc.Profile? attemptedRemoval;
    final acknowledged = <String>[];
    final token = ++generation, savedRevision = revision;
    final capturedSecrets = <String, ConnectionCredentials>{};
    final capturedProfiles = <String, rpc.Profile>{};
    final capturedStorage =
        <String, ({bool database, bool? tlsKey, int revision})>{};
    for (final draft in drafts.values) {
      selected = draft;
      capturedSecrets[draft.id] = credentials;
      capturedProfiles[draft.id] = buildProfile();
      capturedStorage[draft.id] = (
        database: draft.remember,
        tlsKey: sslEnabled && value('key').isNotEmpty
            ? draft.keyRemember
            : draft.keyRemember
            ? null
            : false,
        revision: draft.fieldRevision,
      );
    }
    selected = previous;
    setState(() {
      operation = _Operation.saving;
      feedback = strings(context).connectionSaving;
      details = '';
    });
    try {
      if (!identical(widget.model.backend, backend)) {
        throw StateError('Backend changed; reopen connection settings');
      }
      for (final draft in drafts.values.where((d) => d.dirty).toList()) {
        attempted = draft;
        final result = await widget.model.saveProfileCredentials(
          capturedProfiles[draft.id]!,
          capturedSecrets[draft.id]!.password,
          remember: capturedStorage[draft.id]!.database,
          tlsKeyPassword: capturedSecrets[draft.id]!.tlsKeyPassword,
          rememberTlsKey: capturedStorage[draft.id]!.tlsKey,
        );
        // Each acknowledged baseline survives Cancel and subsequent failures.
        draft.original = result.deepCopy();
        draft.credentialRef = result.credentialRef;
        draft.keyCredentialRef = result.tls.keyCredentialRef;
        draft.saved = true;
        draft.savedName = result.name;
        acknowledged.add(result.name);
        draft.dirty =
            draft.fieldRevision != capturedStorage[draft.id]!.revision;
        if (!current(token)) return;
        if (revision != savedRevision) {
          throw StateError(savedDraftChanged(result.name));
        }
      }
      attempted = null;
      for (final profile in removed.toList()) {
        attemptedRemoval = profile;
        final reply = await backend.client.profiles(
          rpc.ProfileRequest(
            context: backend.context(),
            action: rpc.ProfileAction.DELETE_PROFILE,
            profile: profile,
          ),
        );
        removed.remove(profile);
        // An acknowledged deletion survives cancellation, but not a backend swap.
        if (identical(widget.model.backend, backend)) {
          widget.model.profiles
            ..clear()
            ..addAll(reply.profiles);
          widget.model.updateStatus('Connection removed: ${profile.name}');
        }
        if (!current(token)) return;
      }
      if (!current(token)) return;
      selected = previous;
      setState(() => feedback = strings(context).configurationApplied);
      if (!complete) return;
      final destination = drafts[destinationId];
      if (destination != null) {
        selected = destination;
        setState(() {
          operation = _Operation.connecting;
          feedback = strings(context).connectionConnecting;
        });
        await widget.connect(
          destination.original!.deepCopy(),
          capturedSecrets[destinationId]!,
          () =>
              current(token) &&
              revision == savedRevision &&
              drafts[destinationId] == destination,
        );
        if (!current(token)) return;
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (current(token)) {
        final connecting = operation == _Operation.connecting;
        if (!connecting &&
            attempted != null &&
            drafts[attempted.id] == attempted) {
          selected = attempted;
        }
        failure(error, connectionAttempt: connecting);
        if (attemptedRemoval != null) {
          setState(
            () => feedback =
                '${attemptedRemoval!.name}: ${ConnectionFailure.from(error).localizedSummary(strings(context))}',
          );
        }
        if (!connecting && acknowledged.isNotEmpty) {
          setState(
            () => feedback =
                '${strings(context).configurationApplied}: ${acknowledged.take(3).join(', ')}${acknowledged.length > 3 ? ' …' : ''}. $feedback',
          );
        }
      }
    } finally {
      if (current(token)) setState(() => operation = _Operation.idle);
    }
  }

  Future<void> cancelTest() async {
    if (operation == _Operation.testing) {
      final call = testCall;
      final sshCall = sshTestCall;
      final token = ++generation;
      setState(() {
        operation = _Operation.cancelling;
        if (sshCall != null) {
          selected.sshFeedback = strings(context).connectionCancelling;
        } else {
          feedback = strings(context).connectionCancelling;
        }
        testCall = null;
        sshTestCall = null;
      });
      await call?.cancel();
      await sshCall?.cancel();
      if (mounted && !dismissed && token == generation) {
        setState(() {
          operation = _Operation.idle;
          if (sshCall != null) {
            selected.sshFeedback = strings(context).cancelled;
          } else {
            feedback = strings(context).cancelled;
          }
        });
      }
    } else {
      dismissed = true;
      ++generation;
      Navigator.of(context).pop();
    }
  }

  void cancel() {
    dismissed = true;
    generation++;
    unawaited(testCall?.cancel());
    unawaited(sshTestCall?.cancel());
    testCall = null;
    sshTestCall = null;
    Navigator.of(context).pop();
  }

  Future<void> reviewSsh() async {
    if (!idle || !validateSsh(reviewOnly: true)) return;
    final reviewTargetChanged = strings(context).sshReviewTargetChanged;
    final token = ++generation, reviewedRevision = revision;
    final p = rpc.Profile(id: id, ssh: buildSsh(), connectTimeoutSeconds: 10);
    setState(() {
      operation = _Operation.reviewing;
      selected.sshFeedback = strings(context).connectionSshReviewing;
    });
    try {
      final review = await backend.client.reviewSshHost(
        rpc.SshTrustRequest(context: backend.context(), profile: p),
      );
      if (!mounted || !current(token) || revision != reviewedRevision) return;
      final l = strings(context);
      if (!await widget.reviewHost(
        review.changed ? l.changedSshKey : l.reviewSshKey,
        '${review.host}:${review.port}\n${l.sshAlgorithmLabel}: ${review.algorithm}\n${l.sshFingerprintLabel}: ${review.fingerprint}\n${review.changed ? '${l.sshPreviousFingerprintLabel}: ${review.previousFingerprint}\n${l.sshChangedKeyReview}' : l.verifyFingerprint}\n${l.sshProfileTrustBinding}',
      )) {
        return;
      }
      if (!current(token) || revision != reviewedRevision) {
        throw StateError(reviewTargetChanged);
      }
      final trusted = await backend.client.acceptSshHost(
        rpc.SshTrustRequest(
          context: backend.context(),
          profile: p,
          algorithm: review.algorithm,
          fingerprint: review.fingerprint,
          approvalToken: review.approvalToken,
          replaceChangedKey: review.changed,
        ),
      );
      if (current(token) && revision == reviewedRevision) {
        trustRef = trusted.trustRef;
        changed();
        setState(
          () => selected.sshFeedback =
              '${strings(context).sshReviewedLabel} ${trusted.algorithm} · ${trusted.fingerprint}',
        );
      }
    } catch (error) {
      if (current(token)) sshFailure(error);
    } finally {
      if (current(token)) setState(() => operation = _Operation.idle);
    }
  }

  Widget field(
    String key,
    String label, {
    bool secret = false,
    bool file = false,
    bool enabled = true,
    bool readOnly = false,
  }) {
    final input = ui.field(
      fields[key]!,
      label,
      secret: secret,
      focusNode: focus[key],
      enabled: enabled,
      readOnly: readOnly,
      technical:
          file ||
          const {
            'host',
            'port',
            'url',
            'connectTimeout',
            'queryTimeout',
            'sshHost',
            'sshPort',
            'agentSocket',
            'agentFingerprint',
          }.contains(key),
      errorText: errors[key],
      trailing: file
          ? ui.iconButton(
              DesktopIcon.folder,
              strings(context).chooseFile,
              !enabled || !idle
                  ? null
                  : () async {
                      final draft = selected,
                          fieldRevision = selected.fieldRevision;
                      final chosen = await openFile(confirmButtonText: label);
                      if (mounted &&
                          !dismissed &&
                          identical(_selected, draft) &&
                          draft.fieldRevision == fieldRevision &&
                          chosen != null) {
                        draft.fields[key]!.text = chosen.path;
                      }
                    },
              compact: true,
            )
          : readOnly
          ? ui.iconButton(
              DesktopIcon.copy,
              strings(context).copy,
              () => Clipboard.setData(ClipboardData(text: fields[key]!.text)),
              compact: true,
            )
          : null,
    );
    return KeyedSubtree(
      key: ValueKey('connection-$key'),
      child: revealField(input),
    );
  }

  Object? labelMetricsKey;
  double labelColumnWidth = 0;
  double get measuredLabelWidth {
    final l = strings(context);
    final signature = (
      ui.textStyle(context),
      MediaQuery.textScalerOf(context),
      l.localeName,
      tab,
    );
    if (signature != labelMetricsKey) {
      labelMetricsKey = signature;
      labelColumnWidth = WorkbenchMetrics.labelWidth(context, ui, [
        l.connectionName,
        ...switch (tab) {
          'SSH/SSL' => [
            l.sshConfigurationLabel,
            l.localPortLabel,
            l.caCertificateFile,
            l.useTruststore,
            l.clientCertificateFile,
            l.clientKeyFile,
            l.clientKeyPasswordLabel,
            l.modeLabel,
          ],
          'Options' => [
            l.environmentLabel,
            l.readOnlySettings,
            l.connectionTimeout,
            l.sqlTimeout,
          ],
          _ => [
            l.driverLabel,
            l.connectionTypeLabel,
            l.host,
            l.authenticationLabel,
            l.user,
            l.password,
            l.database,
            'URL',
            l.initialDatabaseLabel,
          ],
        },
      ]);
    }
    return labelColumnWidth;
  }

  Widget formRow(
    String label,
    Widget child, {
    VoidCallback? onLabel,
    double? labelWidth,
    double? minimumValueWidth,
  }) => ui.propertyRow(label, child);

  Widget choice<T>(
    String label,
    T value,
    Map<T, String> choices,
    ValueChanged<T> set, {
    bool enabled = true,
  }) => ui.comboRow(label, value, choices, (value) {
    set(value);
    changed();
  }, enabled: enabled);

  @override
  void dispose() {
    dismissed = true;
    sshRefresh = null;
    generation++;
    unawaited(testCall?.cancel());
    unawaited(sshTestCall?.cancel());
    descriptionTimer?.cancel();
    descriptionGeneration++;
    settingsScroll.dispose();
    emptyName.dispose();
    for (final draft in drafts.values) {
      draft.dispose(changed);
    }
    super.dispose();
  }

  Widget inactive(bool enabled, Widget child) => Semantics(
    enabled: enabled && idle,
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: enabled && idle
            ? ui.appearance(context).foreground
            : ui.appearance(context).disabledForeground,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: enabled && idle
              ? ui.appearance(context).foreground
              : ui.appearance(context).disabledForeground,
        ),
        child: IgnorePointer(
          ignoring: !enabled || !idle,
          child: ExcludeFocus(excluding: !enabled || !idle, child: child),
        ),
      ),
    ),
  );

  Widget revealField(Widget child) => Builder(
    builder: (fieldContext) => Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (fieldContext.mounted) {
              Scrollable.ensureVisible(
                fieldContext,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }
      },
      child: child,
    ),
  );

  Widget passwordRow(
    String key,
    String label,
    bool persisted,
    ValueChanged<bool> change, {
    bool enabled = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KeyedSubtree(
        key: ValueKey('connection-$key'),
        child: revealField(
          ui.field(
            fields[key]!,
            label,
            secret: true,
            enabled: enabled,
            focusNode: focus[key],
            errorText: errors[key],
          ),
        ),
      ),
      ui.comboRow(
        strings(context).passwordStorage,
        persisted,
        {
          false: strings(context).neverStorage,
          true: strings(context).secureStorage,
        },
        (value) {
          change(value);
          changed();
        },
        enabled: enabled,
      ),
    ],
  );

  Future<void> copySshSettings() async {
    if (!idle) return;
    final target = selected;
    final sources = drafts.values
        .where((source) => source != target && source.ssh)
        .toList();
    final source = await ui.dialog<_SourceDraft>(
      context,
      strings(context).copySshSettings,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sources.isEmpty) Text(strings(context).noOtherSshConfig),
          for (final source in sources)
            ui.button(
              source.fields['name']!.text,
              () => Navigator.of(context).pop(source),
            ),
        ],
      ),
      [ui.button(strings(context).cancel, () => Navigator.of(context).pop())],
    );
    if (!mounted ||
        dismissed ||
        !idle ||
        _selected != target ||
        source == null) {
      return;
    }
    for (final key in [
      'sshHost',
      'sshPort',
      'sshUser',
      'knownHosts',
      'sshKey',
      'agentSocket',
      'agentFingerprint',
    ]) {
      target.fields[key]!.text = source.fields[key]!.text;
    }
    target.method = source.method;
    target.trustRef = '';
    target.fields['sshPassword']!.clear();
    target.fields['passphrase']!.clear();
    changed();
  }

  Future<void> editSsh({String? invalid}) async {
    if (!idle || !ssh) return;
    // The nested editor works on the selected profile's independent draft.
    final draft = selected;
    sshEditorOpen = true;
    if (invalid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !dismissed && _selected == draft && sshEditorOpen) {
          draft.focus[invalid]!.requestFocus();
        }
      });
    }
    final before = {
      for (final e in draft.fields.entries)
        if (e.key.startsWith('ssh') ||
            [
              'passphrase',
              'knownHosts',
              'agentSocket',
              'agentFingerprint',
            ].contains(e.key))
          e.key: e.value.text,
    };
    final oldMethod = method, oldTrust = trustRef;
    final accepted = await ui.formDialog<bool>(
      context,
      (context) => StatefulBuilder(
        builder: (context, update) {
          sshRefresh = (change) {
            if (context.mounted) update(change);
          };
          Future<void> runOperation(Future<void> Function() action) async {
            final pending = action();
            update(() {});
            await pending;
            if (context.mounted) update(() {});
          }

          return ui.formShell(
            strings(context).sshConfigurationLabel,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ui.groupedList(
                  children: [
                    field('sshHost', strings(context).sshHost),
                    field('sshPort', strings(context).sshPort),
                    field('sshUser', strings(context).sshUser),
                    choice(
                      strings(context).sshAuthentication,
                      method,
                      {
                        _SshMethod.password: strings(context).sshPassword,
                        _SshMethod.key: strings(context).selectedPrivateKey,
                        _SshMethod.agent: strings(
                          context,
                        ).selectedAgentIdentity,
                      },
                      (v) {
                        method = v;
                        update(() {});
                      },
                    ),
                    if (method == _SshMethod.password)
                      field(
                        'sshPassword',
                        strings(context).sshPassword,
                        secret: true,
                      ),
                    if (method == _SshMethod.key) ...[
                      field(
                        'sshKey',
                        strings(context).selectedPrivateKey,
                        file: true,
                      ),
                      field(
                        'passphrase',
                        strings(context).keyPassphrase,
                        secret: true,
                      ),
                    ],
                    if (method == _SshMethod.agent) ...[
                      field(
                        'agentSocket',
                        strings(context).selectedAgentSocket,
                      ),
                      field(
                        'agentFingerprint',
                        strings(context).selectedKeyFingerprint,
                      ),
                    ],
                    field(
                      'knownHosts',
                      strings(context).reviewedKnownHosts,
                      file: true,
                    ),
                  ],
                ),
                ui.actionRow(
                  title: strings(context).reviewSshKey,
                  leading: ui.icon(DesktopIcon.connection),
                  onPressed: idle ? () => runOperation(reviewSsh) : null,
                ),
                if (trustRef.isNotEmpty)
                  ui.status(
                    strings(context).connectionHostReviewed,
                    success: true,
                  ),
                if (draft.sshFeedback.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: ui.status(
                      draft.sshFeedback,
                      success: draft.sshTestSucceeded,
                      error:
                          !draft.sshTestSucceeded &&
                          draft.sshDetails.isNotEmpty,
                    ),
                  ),
                if (draft.sshDetails.isNotEmpty) ...[
                  SelectableText(draft.sshDetails),
                  ui.textButton(
                    strings(context).copyDetails,
                    () => Clipboard.setData(
                      ClipboardData(text: draft.sshDetails),
                    ),
                  ),
                ],
              ],
            ),
            [
              ui.button(
                operation == _Operation.testing
                    ? strings(context).cancelTest
                    : strings(context).connectionTestAction,
                operation == _Operation.testing
                    ? () => runOperation(cancelTest)
                    : idle
                    ? () => runOperation(testSsh)
                    : null,
              ),
              ui.button(strings(context).cancel, () {
                ++generation;
                unawaited(testCall?.cancel());
                unawaited(sshTestCall?.cancel());
                testCall = null;
                sshTestCall = null;
                setState(() {
                  if (!idle) draft.sshFeedback = strings(context).cancelled;
                  operation = _Operation.idle;
                });
                Navigator.of(context).pop(false);
              }),
              ui.button(
                'OK',
                idle ? () => Navigator.of(context).pop(true) : null,
                primary: true,
              ),
            ],
          );
        },
      ),
    );
    sshRefresh = null;
    sshEditorOpen = false;
    if (mounted && identical(_selected, draft) && accepted != true) {
      for (final e in before.entries) {
        draft.fields[e.key]!.text = e.value;
      }
      method = oldMethod;
      trustRef = oldTrust;
      changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context);
    if (_selected == null) {
      return managerShell(
        SingleChildScrollView(
          controller: settingsScroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ui.groupedList(
                children: [
                  KeyedSubtree(
                    key: const ValueKey('connection-name'),
                    child: ui.field(
                      emptyName,
                      l.connectionName,
                      enabled: false,
                    ),
                  ),
                  ui.comboRow(
                    '',
                    'General',
                    {
                      'General': l.generalSettings,
                      'Options': l.optionsSettings,
                      'SSH/SSL': 'SSH/SSL',
                    },
                    (_) {},
                    enabled: false,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l.noConnections)),
              ),
              ui.textButton(l.connectionTestAction, null),
              if (emptyFeedback.isNotEmpty)
                ui.status(emptyFeedback, error: emptyFeedbackError),
              if (emptyDetails.isNotEmpty) ...[
                WorkbenchCodeEvidence(controls: ui, text: emptyDetails),
                ui.textButton(
                  l.copyDetails,
                  () => Clipboard.setData(ClipboardData(text: emptyDetails)),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final d = selected;
    final general = <Widget>[
      choice(
        l.driverLabel,
        engine,
        const {
          rpc.Engine.POSTGRESQL: 'PostgreSQL',
          rpc.Engine.MYSQL: 'MySQL',
          rpc.Engine.MARIADB: 'MariaDB',
        },
        (next) {
          final previousDefault = engine == rpc.Engine.POSTGRESQL
              ? '5432'
              : '3306';
          if (!d.portEdited && value('port') == previousDefault) {
            fields['port']!.text = next == rpc.Engine.POSTGRESQL
                ? '5432'
                : '3306';
            d.portEdited = false;
          }
          engine = next;
        },
      ),
      LayoutBuilder(
        builder: (context, bounds) {
          final portWidth =
              (WorkbenchMetrics.labelWidth(context, ui, [l.port]) +
                      WorkbenchMetrics.labelWidth(context, ui, ['65535']) +
                      24)
                  .ceilToDouble();
          final stacked =
              bounds.maxWidth <
              measuredLabelWidth +
                  WorkbenchMetrics.labelWidth(context, ui, [l.port]) +
                  WorkbenchMetrics.labelWidth(context, ui, ['65535']) +
                  ui.appearance(context).lineHeight(context) * 8;
          // Keep each editor under the same parents across reflow, including
          // its editing connection, composing range, focus and selection.
          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: stacked
                    ? bounds.maxWidth
                    : bounds.maxWidth - portWidth - 16,
                child: field('host', l.host),
              ),
              SizedBox(
                width: stacked ? bounds.maxWidth : 16,
                height: stacked ? 1 : 0,
                child: stacked
                    ? ColoredBox(color: ui.appearance(context).separator)
                    : null,
              ),
              SizedBox(
                width: stacked ? bounds.maxWidth : portWidth,
                child: field('port', l.port),
              ),
            ],
          );
        },
      ),
      field('user', l.user),
      passwordRow('password', l.password, remember, (v) => remember = v),
      field('database', l.database),
      ui.tooltip(l.generatedUrlHelp, field('url', 'URL', readOnly: true)),
      formRow('', Text(l.generatedUrlHelp)),
      if (engine == rpc.Engine.MARIADB)
        formRow(l.initialDatabaseLabel, Text(value('database'))),
    ];
    final security = <Widget>[
      ui.checkbox(
        l.useSshTunnel,
        ssh,
        idle
            ? (v) {
                ssh = v;
                changed();
              }
            : null,
      ),
      inactive(
        ssh,
        formRow(
          l.sshConfigurationLabel,
          Row(
            children: [
              Expanded(
                child: Text(
                  value('sshHost').isEmpty
                      ? l.createSshConfig
                      : '${value('sshUser')}@${value('sshHost')}:${value('sshPort')}',
                ),
              ),
              ui.iconButton(
                DesktopIcon.settings,
                l.sshConfigurationLabel,
                ssh && idle ? editSsh : null,
                compact: true,
              ),
              ui.iconButton(
                DesktopIcon.copy,
                strings(context).copySshSettings,
                ssh && idle ? copySshSettings : null,
              ),
            ],
          ),
        ),
      ),
      inactive(ssh, formRow(l.localPortLabel, Text(l.dynamicPortLabel))),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: ui.appearance(context).separator),
            ),
          ),
          child: const SizedBox(height: 1),
        ),
      ),
      ui.checkbox(
        l.useSsl,
        sslEnabled,
        idle
            ? (v) {
                tls = v ? d.retainedTls : rpc.TlsMode.DISABLED;
                changed();
              }
            : null,
      ),
      inactive(
        sslEnabled,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field('ca', l.caCertificateFile, file: true, enabled: sslEnabled),
            formRow(
              l.useTruststore,
              Wrap(
                spacing: 16,
                children: [
                  ui.checkbox(
                    'Java',
                    d.javaTrust,
                    sslEnabled && idle
                        ? (v) {
                            d.javaTrust = v;
                            d.rootsEdited = true;
                            changed();
                          }
                        : null,
                  ),
                  ui.checkbox(
                    'System',
                    d.systemTrust,
                    sslEnabled && idle
                        ? (v) {
                            d.systemTrust = v;
                            d.rootsEdited = true;
                            changed();
                          }
                        : null,
                  ),
                ],
              ),
            ),
            field(
              'cert',
              l.clientCertificateFile,
              file: true,
              enabled: sslEnabled,
            ),
            ui.tooltip(
              l.tlsClientKeyHelp,
              field('key', l.clientKeyFile, file: true, enabled: sslEnabled),
            ),
            if (engine == rpc.Engine.MARIADB &&
                tls == rpc.TlsMode.VERIFY_FULL &&
                value('ca').isEmpty &&
                !d.rootsEdited &&
                d.original?.tls.hasJavaTrust() != true &&
                d.original?.tls.hasSystemTrust() != true)
              Text(l.legacyMariaTrustHelp),
            passwordRow(
              'tlsPassword',
              l.clientKeyPasswordLabel,
              d.keyRemember,
              (v) => d.keyRemember = v,
              enabled: sslEnabled && idle,
            ),
            choice(
              l.modeLabel,
              sslEnabled ? tls : d.retainedTls,
              {
                rpc.TlsMode.INSECURE: l.requireTls,
                rpc.TlsMode.VERIFY_CA: l.verifyCa,
                rpc.TlsMode.VERIFY_FULL: l.fullVerification,
              },
              (v) {
                d.retainedTls = v;
                tls = v;
              },
              enabled: sslEnabled && idle,
            ),
          ],
        ),
      ),
      if (tls == rpc.TlsMode.DRIVER_DEFAULT) Text(l.tlsDriverDefaultHelp),
    ];
    final options = <Widget>[
      Text(
        l.connectionSection,
        style: ui.textStyle(context).copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      choice(l.environmentLabel, environment, {
        rpc.Environment.DEVELOPMENT: l.development,
        rpc.Environment.STAGING: l.staging,
        rpc.Environment.PRODUCTION: l.production,
      }, (v) => environment = v),
      choice(l.readOnlySettings, readOnly, {
        false: l.writableProfile,
        true: l.readonlyProfile,
      }, (v) => readOnly = v),
      field('connectTimeout', l.connectionTimeout),
      field('queryTimeout', l.sqlTimeout),
    ];
    final settings = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const ValueKey('connection-page-selector'),
          child: ui.modeSwitcher(
            tab,
            {
              'General': l.generalSettings,
              'SSH/SSL': 'SSH/SSL',
              'Options': l.optionsSettings,
            },
            (page) {
              if (idle) {
                setState(() => tab = page);
                revealPageStart();
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          fit: FlexFit.loose,
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: ui.scrollbar(
              controller: settingsScroll,
              child: SingleChildScrollView(
                key: const ValueKey('connection-settings-body'),
                controller: settingsScroll,
                child: Column(
                  key: const ValueKey('connection-page-content'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (tab) {
                      'SSH/SSL' => [
                        ui.groupedList(
                          title: l.generalSettings,
                          children: [field('name', l.connectionName)],
                        ),
                        ui.groupedList(title: 'SSH / TLS', children: security),
                      ],
                      'Options' => [
                        ui.groupedList(
                          title: l.generalSettings,
                          children: [field('name', l.connectionName)],
                        ),
                        ui.groupedList(
                          title: l.optionsSettings,
                          children: options.skip(2).toList(),
                        ),
                      ],
                      _ => [
                        ui.groupedList(
                          children: [
                            field('name', l.connectionName),
                            general.first,
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${l.connectionTypeLabel}: ${l.defaultTcp}',
                                style: ui.appearance(context).caption,
                              ),
                              Text(
                                '${l.authenticationLabel}: ${l.userPasswordAuth}',
                                style: ui.appearance(context).caption,
                              ),
                            ],
                          ),
                        ),
                        ui.groupedList(
                          children: general.skip(1).take(4).toList(),
                        ),
                        ui.groupedList(children: general.skip(5).toList()),
                      ],
                    },
                    if (detailsOpen && details.isNotEmpty)
                      SelectableText(details, key: detailsKey),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l.saveConnect} · ${sourceDisplayNames[destinationId] ?? ''}',
          style: ui.appearance(context).caption,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ui.textButton(
                  operation == _Operation.testing
                      ? l.cancelTest
                      : l.connectionTestAction,
                  operation == _Operation.testing
                      ? cancelTest
                      : idle
                      ? test
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ui.tooltip(
                    d.description?.driverClass ?? engine.name,
                    Text(
                      '${const {rpc.Engine.POSTGRESQL: 'PostgreSQL', rpc.Engine.MYSQL: 'MySQL', rpc.Engine.MARIADB: 'MariaDB'}[engine]} ${d.description?.driverVersion ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (feedback.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: ui.status(
                    feedback,
                    error: feedbackError,
                    success: testSucceeded,
                  ),
                ),
              ),
            if (details.isNotEmpty)
              Wrap(
                spacing: 12,
                children: [
                  ui.textButton(l.details, () {
                    setState(() => detailsOpen = !detailsOpen);
                    if (detailsOpen) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final target = detailsKey.currentContext;
                        if (mounted && detailsOpen && target != null) {
                          Scrollable.ensureVisible(target);
                        }
                      });
                    }
                  }),
                  ui.textButton(
                    l.copyDetails,
                    () => Clipboard.setData(ClipboardData(text: details)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    return managerShell(settings);
  }

  Map<String, String> get sourceDisplayNames {
    return connectionDisplayNames(context, [
      for (final profile in widget.model.profiles)
        if (drafts[profile.id] case final draft?)
          (draft.id, draft.fields['name']!.text),
      for (final draft in drafts.values)
        if (!widget.model.profiles.any((p) => p.id == draft.id))
          (draft.id, draft.fields['name']!.text),
    ]);
  }

  Widget managerShell(Widget settings) {
    final l = strings(context), d = _selected;
    final sourceNames = sourceDisplayNames;
    return ui.formShell(
      l.managerTitle,
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: l.managerTitle,
        child: LayoutBuilder(
          builder: (context, bounds) => SizedBox(
            width: bounds.maxWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: (bounds.maxWidth * .25).clamp(128.0, 280.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.sourceListTitle),
                      Wrap(
                        spacing: 2,
                        children: [
                          KeyedSubtree(
                            key: const ValueKey('connection-add-source'),
                            child: ui.iconButton(
                              DesktopIcon.add,
                              l.newConnection,
                              idle ? () => addSource() : null,
                            ),
                          ),
                          ui.iconButton(
                            DesktopIcon.close,
                            l.deleteConnection,
                            idle && d != null ? removeSource : null,
                          ),
                          KeyedSubtree(
                            key: const ValueKey('connection-duplicate-source'),
                            child: ui.iconButton(
                              DesktopIcon.copy,
                              l.duplicateConnection,
                              idle && d != null
                                  ? () => addSource(duplicate: true)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: ListView(
                          shrinkWrap: true,
                          key: const ValueKey('connection-source-list'),
                          children: [
                            for (final source in drafts.values)
                              WorkbenchRecord(
                                key: ValueKey(source.id),
                                controls: ui,
                                label:
                                    '${sourceNames[source.id]}${source.dirty ? ' *' : ''}',
                                selected: identical(selected, source),
                                onPressed: idle
                                    ? () => selectSource(source)
                                    : null,
                                child: ui.tooltip(
                                  sourceNames[source.id]!,
                                  Text(
                                    '${sourceNames[source.id]}${source.dirty ? ' *' : ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: settings),
              ],
            ),
          ),
        ),
      ),
      [
        ui.tooltip(
          '${l.saveConnect} · ${sourceDisplayNames[destinationId] ?? ''}',
          ui.button(
            l.saveConnect,
            idle ? () => save(true) : null,
            primary: true,
          ),
        ),
        ui.button(
          operation == _Operation.cancelling
              ? l.connectionCancelling
              : l.cancel,
          operation == _Operation.cancelling ? null : cancel,
        ),
        ui.button(l.applyView, idle ? () => save(false) : null),
      ],
      scrollBody: false,
      maxWidth: 980,
    );
  }
}
