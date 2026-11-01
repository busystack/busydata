import '../../backend/generated/busydata.pb.dart' as rpc;

/// Assignment intent is separate from the retained value. An absent assignment
/// means no change; DEFAULT never travels as text or as SQL NULL.
rpc.ValueAssignment assignmentOf(rpc.Value value) => value.hasNullValue()
    ? assignmentNull()
    : rpc.ValueAssignment(value: value.deepCopy());

rpc.ValueAssignment assignmentNull() =>
    rpc.ValueAssignment(nullValue: rpc.Null());

rpc.ValueAssignment assignmentDefault() =>
    rpc.ValueAssignment(defaultValue: rpc.DefaultValue());

rpc.Value? assignmentValue(rpc.ValueAssignment? assignment) =>
    assignment == null
    ? null
    : switch (assignment.whichAssignment()) {
        rpc.ValueAssignment_Assignment.value => assignment.value,
        rpc.ValueAssignment_Assignment.nullValue => rpc.Value(
          nullValue: rpc.Null(),
        ),
        _ => null,
      };
