import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const gtkHeaderIconsChannelName = 'io.busystack.busydata/gtk_header_icons';
const gtkHeaderIconsChangedChannelName =
    'io.busystack.busydata/gtk_header_icons_changed';

@immutable
final class GtkHeaderIconAsset {
  const GtkHeaderIconAsset({
    required this.bytes,
    required this.resolvedName,
    required this.scale,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final Uint8List bytes;
  final String resolvedName;
  final int scale;
  final int pixelWidth;
  final int pixelHeight;
}

enum BusyDataLinuxHeaderIcon {
  back,
  sidebar,
  previous,
  next,
  search,
  searchEntryFind,
  searchClear,
  mainMenu,
  create,
  refresh,
  viewMenuArrow,
  filter,
  close,
}

extension BusyDataLinuxHeaderIconNames on BusyDataLinuxHeaderIcon {
  List<String> get gtkNames => switch (this) {
    BusyDataLinuxHeaderIcon.back => const ['go-previous-symbolic'],
    BusyDataLinuxHeaderIcon.sidebar => const ['sidebar-show-symbolic'],
    BusyDataLinuxHeaderIcon.previous => const ['go-previous-symbolic'],
    BusyDataLinuxHeaderIcon.next => const ['go-next-symbolic'],
    BusyDataLinuxHeaderIcon.search => const ['system-search-symbolic'],
    BusyDataLinuxHeaderIcon.searchEntryFind => const ['edit-find-symbolic'],
    BusyDataLinuxHeaderIcon.searchClear => const ['edit-clear-symbolic'],
    BusyDataLinuxHeaderIcon.mainMenu => const ['open-menu-symbolic'],
    BusyDataLinuxHeaderIcon.create => const ['list-add-symbolic'],
    BusyDataLinuxHeaderIcon.refresh => const ['view-refresh-symbolic'],
    BusyDataLinuxHeaderIcon.viewMenuArrow => const ['pan-down-symbolic'],
    BusyDataLinuxHeaderIcon.filter => const ['view-filter-symbolic'],
    BusyDataLinuxHeaderIcon.close => const ['window-close-symbolic'],
  };

  bool get directionSensitive => switch (this) {
    BusyDataLinuxHeaderIcon.back ||
    BusyDataLinuxHeaderIcon.sidebar ||
    BusyDataLinuxHeaderIcon.previous ||
    BusyDataLinuxHeaderIcon.next => true,
    _ => false,
  };

  bool get allowMissing => true;
}

final class GtkHeaderIconCatalog {
  GtkHeaderIconCatalog(
    Map<String, GtkHeaderIconAsset> assets, {
    required this.revision,
  }) : assets = UnmodifiableMapView(assets);

  GtkHeaderIconCatalog.empty() : assets = const {}, revision = 0;

  final Map<String, GtkHeaderIconAsset> assets;
  final int revision;

  int? get scale => assets.values.firstOrNull?.scale;

  GtkHeaderIconAsset? assetFor(
    BusyDataLinuxHeaderIcon icon,
    TextDirection direction,
  ) => assets[_catalogKey(icon, direction)];
}

typedef GtkHeaderIconBatchLoader =
    Future<Object?> Function(List<Map<String, Object>> requests);

/// Cached Linux application-header artwork supplied by GTK's active icon
/// theme. A replacement catalog is published only after its full batch loads.
class GtkHeaderIconService extends ChangeNotifier {
  GtkHeaderIconService({
    MethodChannel methodChannel = const MethodChannel(
      gtkHeaderIconsChannelName,
    ),
    EventChannel changedEvents = const EventChannel(
      gtkHeaderIconsChangedChannelName,
    ),
  }) : _loadBatch = ((requests) =>
           methodChannel.invokeMethod<Object?>('loadIcons', requests)),
       _changedEvents = changedEvents.receiveBroadcastStream();

  @visibleForTesting
  GtkHeaderIconService.testing({
    GtkHeaderIconCatalog? initialCatalog,
    GtkHeaderIconBatchLoader? loadBatch,
    Stream<Object?>? changedEvents,
  }) : _catalog = initialCatalog ?? GtkHeaderIconCatalog.empty(),
       _loadBatch = loadBatch,
       _changedEvents = changedEvents;

  GtkHeaderIconService.fallback() : _loadBatch = null, _changedEvents = null;

  static final fallbackInstance = GtkHeaderIconService.fallback();

  final GtkHeaderIconBatchLoader? _loadBatch;
  final Stream<Object?>? _changedEvents;
  GtkHeaderIconCatalog _catalog = GtkHeaderIconCatalog.empty();
  StreamSubscription<Object?>? _subscription;
  bool _reloadRunning = false;
  int? _queuedRevision;
  int _highestSeenRevision = 0;
  int _reloadCount = 0;
  bool _disposed = false;

  GtkHeaderIconCatalog get catalog => _catalog;

  @visibleForTesting
  int get reloadCount => _reloadCount;

  Future<bool> initialize({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final loadBatch = _loadBatch;
    if (loadBatch == null) return false;
    _subscription ??= _changedEvents?.listen(
      _handleInvalidation,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('GTK header-icon invalidation stream failed: $error');
      },
    );
    _reloadRunning = true;
    try {
      var targetRevision = 0;
      while (true) {
        final loaded = await _loadCatalog(targetRevision).timeout(timeout);
        if (_disposed) return false;
        _catalog = loaded;
        notifyListeners();
        final queued = _queuedRevision;
        _queuedRevision = null;
        if (queued == null || queued <= targetRevision) {
          return loaded.assets.isNotEmpty;
        }
        targetRevision = queued;
      }
    } on Object catch (error) {
      debugPrint('GTK header-icon catalog preload failed: $error');
      return false;
    } finally {
      _reloadRunning = false;
    }
  }

  void _handleInvalidation(Object? event) {
    final revision = switch (event) {
      {'revision': final int value} => value,
      _ => _highestSeenRevision + 1,
    };
    if (revision <= _highestSeenRevision) return;
    _highestSeenRevision = revision;
    if (_reloadRunning) {
      _queuedRevision = revision;
      return;
    }
    unawaited(_reloadFromInvalidation(revision));
  }

  Future<void> _reloadFromInvalidation(int revision) async {
    _reloadRunning = true;
    var targetRevision = revision;
    try {
      while (!_disposed) {
        try {
          final replacement = await _loadCatalog(targetRevision);
          if (_disposed) return;
          _catalog = replacement;
          notifyListeners();
        } on Object catch (error) {
          debugPrint('GTK header-icon catalog refresh failed: $error');
        }
        final queued = _queuedRevision;
        _queuedRevision = null;
        if (queued == null || queued <= targetRevision) break;
        targetRevision = queued;
      }
    } finally {
      _reloadRunning = false;
    }
  }

  Future<GtkHeaderIconCatalog> _loadCatalog(int revision) async {
    final loadBatch = _loadBatch;
    if (loadBatch == null) return GtkHeaderIconCatalog.empty();
    _reloadCount += 1;
    final response = await loadBatch(_requests());
    if (response is! Map) {
      throw const FormatException('GTK header-icon response was not a map.');
    }
    final assets = <String, GtkHeaderIconAsset>{};
    for (final entry in response.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) continue;
      final bytes = value['bytes'];
      final resolvedName = value['resolvedName'];
      final scale = value['scale'];
      final pixelWidth = value['pixelWidth'];
      final pixelHeight = value['pixelHeight'];
      if (bytes is! Uint8List ||
          resolvedName is! String ||
          scale is! int ||
          pixelWidth is! int ||
          pixelHeight is! int ||
          bytes.isEmpty ||
          scale < 1 ||
          pixelWidth < 1 ||
          pixelHeight < 1) {
        continue;
      }
      assets[key] = GtkHeaderIconAsset(
        bytes: bytes,
        resolvedName: resolvedName,
        scale: scale,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      );
    }
    if (assets.isEmpty) {
      throw const FormatException('GTK returned no usable header icons.');
    }
    return GtkHeaderIconCatalog(assets, revision: revision);
  }

  static List<Map<String, Object>> _requests() {
    return [
      for (final icon in BusyDataLinuxHeaderIcon.values)
        for (final direction
            in icon.directionSensitive
                ? TextDirection.values
                : const [TextDirection.ltr])
          {
            'key': _catalogKey(icon, direction),
            'names': icon.gtkNames,
            'direction': direction == TextDirection.rtl ? 'rtl' : 'ltr',
            'allowMissing': icon.allowMissing,
          },
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}

String _catalogKey(BusyDataLinuxHeaderIcon icon, TextDirection direction) {
  final effectiveDirection = icon.directionSensitive
      ? direction
      : TextDirection.ltr;
  return '${icon.name}.${effectiveDirection.name}';
}

final gtkHeaderIconServiceProvider = Provider<GtkHeaderIconService>((ref) {
  final service = GtkHeaderIconService.fallback();
  ref.onDispose(service.dispose);
  return service;
});

class GtkHeaderIconScope extends InheritedNotifier<GtkHeaderIconService> {
  const GtkHeaderIconScope({
    super.key,
    required GtkHeaderIconService service,
    required super.child,
  }) : super(notifier: service);

  static GtkHeaderIconService of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<GtkHeaderIconScope>()
            ?.notifier ??
        GtkHeaderIconService.fallbackInstance;
  }
}

String resolvedNativeHeaderIconName(
  BuildContext context,
  BusyDataLinuxHeaderIcon icon,
) {
  final asset = GtkHeaderIconScope.of(
    context,
  ).catalog.assetFor(icon, Directionality.of(context));
  return asset?.resolvedName ?? icon.gtkNames.first;
}
