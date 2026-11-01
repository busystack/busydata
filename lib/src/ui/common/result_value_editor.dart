import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/workbench_failure.dart';
import '../../features/results/structured_value.dart';
import '../../features/results/value_document.dart';
import '../../features/results/complete_value.dart';
import '../../features/results/hexadecimal_display.dart';
import '../../features/results/text_value_draft.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'bounded_text_controller.dart';
import 'result_extractors.dart';
import 'exact_text_clipboard.dart';
import 'paged_selectable_text.dart';
import 'workbench_presentation.dart';

/// A native bounded inspector. The caller binds every read/stage to the captured
/// retained result and rejects stale backend/row/document owners before apply.
class ResultValueEditor extends StatefulWidget {
  const ResultValueEditor({
    super.key,
    required this.controls,
    required this.value,
    required this.column,
    this.readChunk,
    required this.retainDraft,
    required this.cancelRead,
    this.initialDraft,
    this.initialPresentation,
    this.stage,
    this.stageNull,
    this.stageDefault,
    this.initialBinaryDraft,
    this.retainBinaryDraft,
  });
  final DesktopControls controls;
  final rpc.Value value;
  final rpc.Column column;
  final String? initialDraft, initialPresentation;
  final Future<rpc.ValueChunk> Function(int offset)? readChunk;
  final VoidCallback cancelRead;
  final void Function(String, String) retainDraft;
  final Future<void> Function(rpc.Value value)? stage;
  final Future<void> Function()? stageNull, stageDefault;
  final BinaryDraftSnapshot? initialBinaryDraft;
  final void Function(BinaryDraftSnapshot draft)? retainBinaryDraft;
  @override
  State<ResultValueEditor> createState() => _ResultValueEditorState();
}

class _ResultValueEditorState extends State<ResultValueEditor> {
  // Popup routes can retire and recreate native semantics objects. This
  // presentation-only identity follows this editor instance, never its value.
  final _semanticsIdentity = 'busydata.value.editor.v1.${const Uuid().v4()}';
  late final document = ValueDocument(widget.value);
  late final input = BoundedTextController(
    text:
        widget.initialBinaryDraft?.input ??
        textDraft?.pageText ??
        (_nativeTextUnsafe
            ? ''
            : _binaryValue
            ? _initialBinaryInput
            : _raw.substring(0, textValuePageEnd(_raw, 0))),
    maxUnits: 262144,
    limit: () => _binaryValue ? 32768 : textValuePageUnits,
    maxUtf8Bytes: 49152,
    rejected: () {
      if (mounted) setState(() => error = strings(context).valuePageEditLimit);
    },
  );
  ValuePresentation mode = ValuePresentation.raw;
  bool loading = false, editing = false, staging = false;
  int draftRevision = 0, editPageEpoch = 0;
  String? error;
  int requestRevision = 0;
  ui.Image? image;
  rpc.Value? completeValue;
  BinaryValueDraft? binaryDraft;
  TextValueDraft? textDraft;
  final expanded = <String>{''};
  final editFocus = FocusNode(debugLabel: 'Value draft');
  String get _raw => _binaryValue
      ? encodeHexDisplay(widget.value.binary)
      : widget.value.hasArray() && widget.value.array.nativeLiteral.isNotEmpty
      ? widget.value.array.nativeLiteral
      : valueText(widget.value.deepCopy()..truncated = false);
  bool get _binaryValue => widget.value.whichData() == rpc.Value_Data.binary;
  bool get _nativeTextUnsafe =>
      !_binaryValue &&
      ((widget.initialDraft?.contains('\u0000') ?? false) ||
          _raw.contains('\u0000') ||
          (completeValue?.text.contains('\u0000') ?? false) ||
          (completeValue?.json.contains('\u0000') ?? false) ||
          (document.chunk?.contains(0) ?? false));
  bool get _fullModelAvailable =>
      completeValue != null || textDraft != null || binaryDraft != null;
  String get _initialBinaryInput => BinaryValueDraft(
    widget.value.binary.take(BinaryValueDraft.pageByteLimit).toList(),
  ).encodedPage(mode);
  bool get _uuidApplicable {
    if (binaryDraft case final draft?) return draft.bytes.length == 16;
    if (_binaryValue && !widget.value.truncated) {
      return widget.value.binary.length == 16;
    }
    return document.chunk != null &&
        document.complete &&
        document.offset == 0 &&
        document.totalBytes == 16;
  }

  @override
  void initState() {
    super.initState();
    mode =
        ValuePresentation.values
            .where((mode) => mode.name == widget.initialPresentation)
            .firstOrNull ??
        (_binaryValue ? ValuePresentation.hexadecimal : ValuePresentation.raw);
    final binary = widget.initialBinaryDraft;
    if (binary != null) {
      binaryDraft = BinaryValueDraft(binary.bytes)..offset = binary.offset;
      mode = binary.mode;
    } else if (widget.initialDraft case final draft? when !_nativeTextUnsafe) {
      textDraft = TextValueDraft(draft);
    }
    if (_nativeTextUnsafe) mode = ValuePresentation.hexadecimal;
    editing =
        !_nativeTextUnsafe && (widget.initialDraft != null || binary != null);
    input.addListener(_draftChanged);
  }

  void _draftChanged() {
    if (_nativeTextUnsafe) return;
    draftRevision++;
    try {
      final binary = binaryDraft;
      if (binary != null) {
        widget.retainBinaryDraft?.call(
          binary.snapshot(
            input.text,
            mode == ValuePresentation.base64 || mode == ValuePresentation.uuid
                ? mode
                : ValuePresentation.hexadecimal,
          ),
        );
      } else {
        widget.retainDraft(
          textDraft?.projected(input.text) ?? input.text,
          mode.name,
        );
      }
      if (mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) setState(() => error = strings(context).valueDraftLimit);
    }
  }

  Future<void> editComplete() async {
    final read = widget.readChunk;
    if (read == null || _fullModelAvailable) return;
    final revision = ++requestRevision;
    widget.cancelRead();
    setState(() {
      loading = true;
      error = null;
    });
    var active = true;
    try {
      final value =
          await readCompleteValue(
            widget.value,
            read,
            () => active && mounted && revision == requestRevision,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              active = false;
              widget.cancelRead();
              throw TimeoutException('COMPLETE_VALUE_DEADLINE');
            },
          );
      if (!mounted || revision != requestRevision) return;
      setState(() {
        image?.dispose();
        image = null;
        completeValue = value;
        document.reset();
        if (value.hasBinary()) {
          binaryDraft = BinaryValueDraft(value.binary);
          mode = ValuePresentation.hexadecimal;
        } else if (!_nativeTextUnsafe) {
          textDraft = TextValueDraft(value.hasJson() ? value.json : value.text);
          mode = ValuePresentation.raw;
        } else {
          mode = ValuePresentation.hexadecimal;
        }
        editPageEpoch++;
        editing = !_nativeTextUnsafe;
        loading = false;
        input.text =
            binaryDraft?.encodedPage(mode) ?? textDraft?.pageText ?? '';
      });
      if (editing) editFocus.requestFocus();
    } catch (failure) {
      if (mounted && revision == requestRevision) {
        setState(() {
          loading = false;
          final l = strings(context);
          error = failure is CompleteValueLimit
              ? l.completeValueEditLimit
              : failure is RetainedValueOwnerChanged
              ? l.staleContext
              : failure is TimeoutException
              ? l.connectionFailureTimeout
              : WorkbenchFailureReason.fromError(failure)?.localized(l) ??
                    l.retainedUnavailable;
        });
      }
    } finally {
      active = false;
    }
  }

  void moveTextPage(int direction) {
    final draft = textDraft;
    if (draft == null) return;
    try {
      draft.move(direction, input.text);
      setState(() {
        editPageEpoch++;
        input.text = draft.pageText;
        error = null;
      });
      editFocus.requestFocus();
    } on FormatException {
      setState(() => error = strings(context).valuePageEditLimit);
    }
  }

  void appendTextPage() {
    final draft = textDraft;
    if (draft == null) return;
    try {
      draft.appendPage(input.text);
      setState(() {
        editPageEpoch++;
        input.text = draft.pageText;
        error = null;
      });
      editFocus.requestFocus();
    } on FormatException {
      setState(() => error = strings(context).valuePageEditLimit);
    }
  }

  void appendBinaryPage() {
    final draft = binaryDraft;
    if (draft == null) return;
    try {
      draft.appendPage(input.text, mode);
      setState(() {
        editPageEpoch++;
        input.text = draft.encodedPage(mode);
        error = null;
      });
      editFocus.requestFocus();
    } on FormatException {
      setState(() => error = strings(context).binaryInputError);
    }
  }

  void moveBinaryPage(int direction) {
    final binary = binaryDraft;
    if (binary == null) return;
    try {
      binary.replacePage(input.text, mode);
      binary.move(direction);
      setState(() {
        editPageEpoch++;
        input.text = binary.encodedPage(mode);
        error = null;
      });
      editFocus.requestFocus();
    } catch (_) {
      setState(() => error = strings(context).binaryInputError);
    }
  }

  @override
  void dispose() {
    requestRevision++;
    widget.cancelRead();
    input.removeListener(_draftChanged);
    input.dispose();
    editFocus.dispose();
    image?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final read = widget.readChunk;
    if (read == null) return;
    final revision = ++requestRevision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final offset = document.nextOffset;
      final reply = await read(offset);
      if (!mounted || revision != requestRevision) return;
      document.accept(reply, offset);
      image?.dispose();
      image = null;
      setState(() {
        loading = false;
        if (_nativeTextUnsafe) mode = ValuePresentation.hexadecimal;
      });
    } catch (failure) {
      if (mounted && revision == requestRevision) {
        setState(() {
          final l = strings(context);
          error = failure is RetainedValueOwnerChanged
              ? l.staleContext
              : WorkbenchFailureReason.fromError(failure)?.localized(l) ??
                    l.retainedUnavailable;
          loading = false;
        });
      }
    }
  }

  List<int>? get bytes =>
      binaryDraft?.pageBytes ??
      document.chunk ??
      (_binaryValue
          ? widget.value.binary
          : _nativeTextUnsafe
          ? utf8.encode(raw)
          : null);
  String get raw {
    if (binaryDraft != null) {
      return binaryDraft!.encodedPage(ValuePresentation.hexadecimal);
    }
    if (textDraft != null) return textDraft!.fullText;
    if (completeValue != null) {
      return completeValue!.hasJson()
          ? completeValue!.json
          : completeValue!.text;
    }
    final chunk = document.chunk;
    if (chunk == null) return widget.initialDraft ?? _raw;
    if (_binaryValue) {
      return encodeHexDisplay(chunk);
    }
    return utf8.decode(chunk);
  }

  Future<void> changeMode(ValuePresentation selected) async {
    requestRevision++;
    widget.cancelRead();
    setState(() {
      mode = selected;
      error = null;
      loading = false;
      if (binaryDraft != null &&
          (selected == ValuePresentation.hexadecimal ||
              selected == ValuePresentation.base64 ||
              selected == ValuePresentation.raw)) {
        input.text = binaryDraft!.encodedPage(selected);
      }
    });
    if (selected != ValuePresentation.image) return;
    final revision = requestRevision;
    ui.Codec? codec;
    try {
      List<int>? data = _binaryValue && !widget.value.truncated
          ? widget.value.binary
          : null;
      if (data == null &&
          _binaryValue &&
          widget.readChunk != null &&
          widget.value.valueId.isNotEmpty &&
          widget.value.originalBytes > 0 &&
          widget.value.originalBytes <= 1048576) {
        setState(() => loading = true);
        final admitted = ValueDocument(widget.value), collected = <int>[];
        do {
          final reply = await widget.readChunk!(admitted.nextOffset);
          if (!mounted || revision != requestRevision) return;
          admitted.accept(reply, admitted.nextOffset);
          if (collected.length + reply.data.length > 1048576) {
            throw const FormatException('IMAGE_SIZE_LIMIT');
          }
          collected.addAll(reply.data);
        } while (!admitted.complete);
        data = collected;
      }
      final size = data == null ? null : recognizedImageSize(data);
      if (size == null) throw const FormatException('IMAGE_SIZE_LIMIT');
      final scale = math.min(1.0, 1024 / math.max(size.width, size.height));
      codec = await ui.instantiateImageCodec(
        Uint8List.fromList(data!),
        targetWidth: math.max(1, (size.width * scale).round()),
        targetHeight: math.max(1, (size.height * scale).round()),
      );
      final frame = await codec.getNextFrame();
      if (!mounted || revision != requestRevision) {
        frame.image.dispose();
        return;
      }
      setState(() {
        image?.dispose();
        image = frame.image;
        loading = false;
      });
    } catch (_) {
      if (mounted && revision == requestRevision) {
        setState(() {
          error = strings(context).imagePreviewUnavailable;
          loading = false;
        });
      }
    } finally {
      codec?.dispose();
    }
  }

  Future<void> stage() async {
    if (staging) return;
    try {
      rpc.Value value;
      if (binaryDraft case final binary?) {
        binary.replacePage(input.text, mode);
        widget.retainBinaryDraft?.call(binary.snapshot(input.text, mode));
        value = rpc.Value(binary: binary.bytes);
      } else {
        final full = textDraft?.projected(input.text) ?? input.text;
        widget.retainDraft(full, mode.name);
        value = editedValue(widget.value, full, mode);
      }
      await stageOperation(() => widget.stage!(value));
    } catch (failure) {
      if (mounted) {
        setState(
          () => error =
              failure is FormatException &&
                  widget.value.whichData() == rpc.Value_Data.binary
              ? strings(context).binaryInputError
              : failure is RetainedValueOwnerChanged
              ? strings(context).staleContext
              : WorkbenchFailureReason.fromError(
                      failure,
                    )?.localized(strings(context)) ??
                    strings(context).valueDraftPreserved,
        );
      }
    }
  }

  Future<void> stageSpecial(Future<void> Function() operation) async {
    await stageOperation(operation);
  }

  Future<void> stageOperation(Future<void> Function() operation) async {
    if (staging) return;
    final revision = draftRevision;
    setState(() => staging = true);
    try {
      await operation();
      if (mounted) {
        if (revision == draftRevision) {
          Navigator.of(context).pop();
        } else {
          _draftChanged();
          setState(() => error = strings(context).valueChangedDuringStage);
        }
      }
    } catch (failure) {
      if (mounted) {
        final reason = WorkbenchFailureReason.fromError(failure);
        setState(
          () => error = failure is RetainedValueOwnerChanged
              ? strings(context).staleContext
              : reason == WorkbenchFailureReason.valueTruncated
              ? strings(context).completeValueEditLimit
              : reason?.localized(strings(context)) ??
                    strings(context).valueDraftPreserved,
        );
      }
    } finally {
      if (mounted) setState(() => staging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context), controls = widget.controls;
    final available = <ValuePresentation, String>{
      if (!_nativeTextUnsafe) ValuePresentation.raw: l.rawValue,
      if (!_binaryValue && !_nativeTextUnsafe && !widget.value.hasArray()) ...{
        ValuePresentation.json: l.jsonPretty,
        ValuePresentation.tree: l.jsonTree,
        ValuePresentation.xml: l.xmlInterpretation,
      },
      if (widget.value.hasArray()) ValuePresentation.tree: l.structuredTree,
      if (_binaryValue || document.chunk != null || _nativeTextUnsafe) ...{
        ValuePresentation.hexadecimal: _nativeTextUnsafe
            ? l.utf8Hex
            : l.binaryHex,
        ValuePresentation.base64: _nativeTextUnsafe
            ? l.utf8Base64
            : l.binaryBase64,
        if (_uuidApplicable) ValuePresentation.uuid: l.uuidPresentation,
        if (_binaryValue) ValuePresentation.image: l.imagePreview,
      },
    };
    String display = '';
    String? rawSource;
    StructuredJson? json;
    String? parseError;
    var displayScopeLimited = false;
    try {
      final rawText = editing
          ? input.text
          : const {
              ValuePresentation.hexadecimal,
              ValuePresentation.base64,
              ValuePresentation.uuid,
              ValuePresentation.image,
            }.contains(mode)
          ? ''
          : raw;
      rawSource =
          const {
            ValuePresentation.hexadecimal,
            ValuePresentation.base64,
            ValuePresentation.uuid,
            ValuePresentation.image,
          }.contains(mode)
          ? null
          : rawText;
      display = editing
          ? input.text
          : switch (mode) {
              ValuePresentation.json => StructuredJson.parse(rawText).pretty(),
              ValuePresentation.xml => formatXmlDisplay(rawText),
              ValuePresentation.hexadecimal => encodeHexDisplay(bytes!),
              ValuePresentation.base64 => base64Encode(bytes!),
              ValuePresentation.uuid => _uuid(bytes!),
              _ => rawText,
            };
      if (!editing &&
          mode == ValuePresentation.tree &&
          !widget.value.hasArray()) {
        json = StructuredJson.parse(rawText);
      }
    } on HexDisplayLimit {
      displayScopeLimited = true;
    } on FormatException {
      parseError = document.chunk != null && mode == ValuePresentation.raw
          ? l.valueChunkEncoding
          : l.structuredParseError;
      try {
        display = rawSource ?? _raw;
      } on HexDisplayLimit {
        displayScopeLimited = true;
        parseError = null;
      }
    }
    final secondary = <DesktopMenuAction>[
      if (widget.readChunk != null &&
          widget.value.valueId.isNotEmpty &&
          !_fullModelAvailable &&
          !editing) ...[
        DesktopMenuAction(
          l.loadValueChunk,
          load,
          disabledReason: loading || document.chunk != null && document.complete
              ? l.unavailable
              : null,
        ),
        if (document.chunk != null)
          DesktopMenuAction(l.resetValueChunks, () {
            requestRevision++;
            setState(() {
              document.reset();
              loading = false;
              error = null;
              if (!_binaryValue && !_nativeTextUnsafe) {
                mode = ValuePresentation.raw;
              }
            });
          }),
      ],
      DesktopMenuAction(l.copyDisplayedText, () async {
        try {
          final copied = editing && textDraft != null
              ? textDraft!.projected(input.text)
              : display;
          await writeExactTextClipboard(copied);
        } on TextClipboardUnavailable catch (failure) {
          if (mounted) {
            setState(
              () => error =
                  failure.reason == TextClipboardUnavailableReason.embeddedNul
                  ? l.textClipboardNulUnavailable
                  : l.presentationScopeLimit,
            );
          }
        } catch (_) {
          if (mounted) setState(() => error = l.failed);
        }
      }, disabledReason: displayScopeLimited ? l.presentationScopeLimit : null),
      if (widget.stage != null &&
          widget.readChunk != null &&
          completeValueEligible(widget.value) &&
          !editing &&
          !_fullModelAvailable)
        DesktopMenuAction(
          l.editCompleteValue,
          editComplete,
          disabledReason: loading ? l.loading : null,
        ),
      if (editing && binaryDraft != null)
        DesktopMenuAction(
          l.valueAddEditPage,
          appendBinaryPage,
          disabledReason: binaryDraft!.canAppend(input.text, mode)
              ? null
              : binaryDraft!.bytes.length >= completeValueByteLimit
              ? l.completeValueEditLimit
              : l.binaryAppendPageReason,
        ),
      if (textDraft case final draft? when editing)
        DesktopMenuAction(
          l.valueAddEditPage,
          appendTextPage,
          disabledReason: draft.canAppend(input.text)
              ? null
              : l.completeValueEditLimit,
        ),
      if (widget.stageNull != null)
        DesktopMenuAction(
          l.setNull,
          () => stageSpecial(widget.stageNull!),
          disabledReason: staging ? l.loading : null,
        ),
      if (widget.stageDefault != null)
        DesktopMenuAction(
          l.setDefault,
          () => stageSpecial(widget.stageDefault!),
          disabledReason: staging ? l.loading : null,
        ),
    ];
    Widget notice(String value, {bool failure = false}) => controls.tooltip(
      value,
      DefaultTextStyle.merge(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        child: failure ? controls.status(value, error: true) : Text(value),
      ),
    );
    final body = WorkbenchDialogBody(
      maxHeight: 520,
      child: LayoutBuilder(
        builder: (context, bounds) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .4),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        controls.choice(
                          mode,
                          available,
                          changeMode,
                          label: l.modeLabel,
                          enabled: !editing,
                        ),
                        if (widget.stage != null &&
                            !displayScopeLimited &&
                            !_nativeTextUnsafe &&
                            document.chunk == null &&
                            (!widget.value.truncated ||
                                _fullModelAvailable ||
                                widget.initialDraft != null) &&
                            (!widget.value.hasArray() ||
                                mode == ValuePresentation.raw &&
                                    widget
                                        .value
                                        .array
                                        .nativeLiteral
                                        .isNotEmpty) &&
                            (!widget.value.hasEngineValue() ||
                                mode == ValuePresentation.raw) &&
                            mode != ValuePresentation.image &&
                            (mode != ValuePresentation.uuid ||
                                bytes?.length == 16))
                          controls.checkbox(l.editCell, editing, (v) {
                            try {
                              if (!v && editing) {
                                binaryDraft?.replacePage(input.text, mode);
                                textDraft?.replacePage(input.text);
                              }
                              if (v && !editing) {
                                if (_binaryValue) {
                                  binaryDraft ??= BinaryValueDraft(
                                    widget.value.binary,
                                  );
                                  input.text = binaryDraft!.encodedPage(mode);
                                } else {
                                  textDraft ??= TextValueDraft(display);
                                  input.text = textDraft!.pageText;
                                }
                                editPageEpoch++;
                              }
                              setState(() => editing = v);
                            } on FormatException {
                              setState(
                                () => error = _binaryValue
                                    ? l.binaryInputError
                                    : l.valuePageEditLimit,
                              );
                            }
                          }),
                      ],
                    ),
                    notice(
                      completeValue != null || widget.initialBinaryDraft != null
                          ? l.completeValueReady
                          : widget.value.truncated
                          ? l.valueTruncated
                          : l.valueComplete,
                    ),
                    if (_nativeTextUnsafe) notice(l.nativeTextNulUnavailable),
                    if (widget.value.hasArray() &&
                        widget.value.array.nativeLiteral.isNotEmpty)
                      notice(l.arrayEditLimit),
                    if (binaryDraft case final binary?)
                      notice(
                        l.valueChunkRange(
                          '${binary.offset}',
                          '${binary.offset + binary.pageLength}',
                          '${binary.bytes.length}',
                        ),
                      ),
                    if (widget.readChunk == null &&
                        widget.value.valueId.isNotEmpty)
                      notice(l.retainedUnavailable),
                    if (document.chunk != null)
                      notice(
                        l.valueChunkRange(
                          '${document.offset}',
                          '${document.nextOffset}',
                          '${document.totalBytes}',
                        ),
                      ),
                    if (widget.value.truncated &&
                        !completeValueEligible(widget.value))
                      notice(l.completeValueEditLimit),
                    if (error != null) notice(error!, failure: true),
                    if (parseError != null) notice(parseError, failure: true),
                  ],
                ),
              ),
            ),
            Expanded(
              child: editing
                  ? KeyedSubtree(
                      key: ValueKey(editPageEpoch),
                      child: controls.multilineField(
                        input,
                        l.exactValue,
                        focusNode: editFocus,
                        expands: true,
                      ),
                    )
                  : displayScopeLimited
                  ? controls.status(l.presentationScopeLimit)
                  : mode == ValuePresentation.image && image != null
                  ? RawImage(image: image, fit: BoxFit.contain)
                  : mode == ValuePresentation.tree && widget.value.hasArray()
                  ? _arrayTree(widget.value)
                  : json != null
                  ? _jsonTree(json)
                  : PagedSelectableText(
                      controls: controls,
                      text: display,
                      pageUnits: ValueDocument.nativeTextPageUnits,
                    ),
            ),
            if (textDraft case final draft? when editing)
              Semantics(
                container: true,
                liveRegion: true,
                hint: l.textValueEditScope,
                child: controls.tooltip(
                  l.textValueEditScope,
                  Text(
                    l.textValuePage(
                      '${draft.pageIndex + 1}',
                      '${draft.pageCount}',
                    ),
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .4),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (loading)
                      controls.textButton(l.cancel, () {
                        requestRevision++;
                        widget.cancelRead();
                        setState(() => loading = false);
                      }, compact: true),
                    if (editing && binaryDraft != null) ...[
                      controls.textButton(
                        l.binaryPreviousEditPage,
                        binaryDraft!.offset > 0
                            ? () => moveBinaryPage(-1)
                            : null,
                        compact: true,
                      ),
                      controls.textButton(
                        l.binaryNextEditPage,
                        binaryDraft!.hasNext ? () => moveBinaryPage(1) : null,
                        compact: true,
                      ),
                    ],
                    if (textDraft case final draft? when editing) ...[
                      controls.textButton(
                        l.textValuePreviousPage,
                        draft.hasPrevious ? () => moveTextPage(-1) : null,
                        compact: true,
                      ),
                      controls.textButton(
                        l.textValueNextPage,
                        draft.hasNext ? () => moveTextPage(1) : null,
                        compact: true,
                      ),
                    ],
                    if (editing && widget.stage != null)
                      controls.button(l.stageChange, staging ? null : stage),
                    controls.menu(
                      l.valueEditorActions,
                      secondary,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: _semanticsIdentity,
      child: body,
    );
  }

  String _uuid(List<int> data) {
    if (data.length != 16) throw const FormatException('UUID_LENGTH');
    final hex = encodeHexDisplay(data);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Widget _arrayTree(rpc.Value value) {
    final rows = <({rpc.Value value, String key, int depth})>[];
    var limited = false;
    void add(rpc.Value value, String key, int depth) {
      if (rows.length >= 4096 || depth > 16) {
        limited = true;
        return;
      }
      rows.add((value: value, key: key, depth: depth));
      if (value.hasArray() && expanded.contains(key)) {
        for (var i = 0; i < value.array.values.length; i++) {
          add(value.array.values[i], '$key/$i', depth + 1);
        }
      }
    }

    add(value, '', 0);
    return Column(
      children: [
        if (limited) Text(strings(context).structuredValueLimit),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Padding(
                padding: EdgeInsetsDirectional.only(start: row.depth * 16.0),
                child: widget.controls.textButton(
                  row.value.hasArray()
                      ? '${expanded.contains(row.key) ? '▾' : '▸'} ${row.key.isEmpty ? widget.column.typeName : row.key.split('/').last}'
                      : '${row.key.split('/').last}: ${valueText(row.value)}',
                  row.value.hasArray()
                      ? () => setState(() {
                          if (!expanded.remove(row.key)) expanded.add(row.key);
                        })
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _jsonTree(StructuredJson data) {
    final rows = <({JsonValueNode node, String name, String key, int depth})>[];
    void add(JsonValueNode node, String name, String key, int depth) {
      rows.add((node: node, name: name, key: key, depth: depth));
      if (!expanded.contains(key)) return;
      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        add(child.node, child.name, '$key/$i', depth + 1);
      }
    }

    add(data.root, strings(context).valueEditor, '', 0);
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Padding(
          padding: EdgeInsetsDirectional.only(start: row.depth * 16.0),
          child: widget.controls.textButton(
            row.node.branch
                ? '${expanded.contains(row.key) ? '▾' : '▸'} ${row.name}'
                : '${row.name}: ${data.raw(row.node)}',
            row.node.branch
                ? () => setState(() {
                    if (!expanded.remove(row.key)) expanded.add(row.key);
                  })
                : null,
          ),
        );
      },
    );
  }
}
