import 'dart:convert';

/// Accessible presentation identity, never permission to operate on a result.
///
/// A local retained view changes [displayResultId] while keeping
/// [sourceResultId]. A fresh backend result changes [sourceResultId].
String resultCellSemanticsIdentifier({
  required String ownerDocumentId,
  required String sourceResultId,
  required String displayResultId,
  required int row,
  required int column,
}) =>
    'busydata.result.cell.v1:${jsonEncode([ownerDocumentId, sourceResultId, displayResultId, row, column])}';
