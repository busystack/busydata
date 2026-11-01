import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;

/// JDBC-shaped metadata, including values which must never be inferred as NULL.
List<rpc.SchemaObject> customerColumns() => [
  for (final (position, name, type, jdbc, nullable, defaultValue) in [
    (1, 'id', 'bigint unsigned', '-5', 'NO', ''),
    (2, 'name', 'varchar(120)', '12', 'NO', ''),
    (3, 'email', 'varchar(255)', '12', 'NO', ''),
    (4, 'status', 'char(8)', '1', 'NO', "'active'"),
    (5, 'created_at', 'timestamp', '93', 'NO', 'CURRENT_TIMESTAMP'),
  ])
    rpc.SchemaObject(
      kind: rpc.ObjectKind.COLUMN,
      name: name,
      properties: {
        'ordinal': '$position',
        'type': type,
        'jdbcType': jdbc,
        'nullable': nullable,
        'default': defaultValue,
        'autoIncrement': position == 1 ? 'YES' : 'NO',
        'generated': 'NO',
        'remarks': position == 3
            ? 'Optional contact address; verified separately by the application'
            : '',
        'collation': position == 2 || position == 3 ? 'default' : '',
      }.entries,
    ),
];

List<rpc.SchemaObject> schemaSectionFixture(
  rpc.ObjectKind kind,
) => switch (kind) {
  rpc.ObjectKind.COLUMN => customerColumns(),
  rpc.ObjectKind.INDEX => [
    rpc.SchemaObject(
      kind: kind,
      name: 'customers_pkey',
      properties: {
        'nonUnique': 'false',
        'column': 'id',
        'ordinal': '1',
        'type': '3',
      }.entries,
    ),
    rpc.SchemaObject(
      kind: kind,
      name: 'customers_email_idx',
      properties: {
        'nonUnique': 'true',
        'column': 'email',
        'ordinal': '1',
        'type': '3',
      }.entries,
    ),
  ],
  rpc.ObjectKind.CONSTRAINT => [
    rpc.SchemaObject(
      kind: kind,
      name: 'customers_pkey',
      properties: {'type': 'PRIMARY KEY', 'columns': 'id'}.entries,
    ),
  ],
  rpc.ObjectKind.FOREIGN_KEY => [
    rpc.SchemaObject(
      kind: kind,
      name: 'customers_account_fkey',
      properties: {
        'column': 'id',
        'referencedSchema': 'public',
        'referencedTable': 'accounts',
        'referencedColumn': 'customer_id',
      }.entries,
    ),
  ],
  rpc.ObjectKind.TRIGGER => [
    rpc.SchemaObject(
      kind: kind,
      name: 'customers_audit',
      properties: {
        'event': 'UPDATE',
        'timing': 'AFTER',
        'orientation': 'ROW',
      }.entries,
      definition:
          'CREATE TRIGGER customers_audit AFTER UPDATE ON public.customers\nFOR EACH ROW EXECUTE FUNCTION public.audit_customer();',
    ),
  ],
  _ => [],
};
