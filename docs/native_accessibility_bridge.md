# Owned Linux accessibility projection

Linux accessibility uses a BusyData-owned GTK host and ATK objects. The host
contains the ordinary FlView without changing its class, interfaces, objects or
private engine behavior. Its accessible traversal exposes the owned projection.
Flutter remains responsible for widget semantics, text, selection, focus and
editing. The projection contains presentation data; Java remains authoritative
for database metadata, values, operations and ownership.

Linux startup installs an owned `WidgetsBinding` before plugins or `runApp` can
initialize a default binding. Its public
[`createSemanticsUpdateBuilder`](https://api.flutter.dev/flutter/semantics/SemanticsBinding/createSemanticsUpdateBuilder.html)
override keeps the complete `SemanticsOwner` tree, listeners and guarded actions
available to the bridge while sending an empty, genuine native
[`SemanticsUpdate`](https://api.flutter.dev/flutter/dart-ui/SemanticsUpdateBuilder-class.html)
to the stock engine. The complete public builder interface retains no node or
text arguments and has one build lifetime. This gives the owned GTK projection
one native event stream; a parallel stock FlView text projection cannot publish
stale focus events from retired controls. An already initialized foreign binding
fails explicitly. Ordinary Linux and Linux-host Fluent use this same startup;
integration bindings use the same factory override. No engine, widget or ATK
object is patched, and no deprecated render/pipeline initialization hook is used.
Native integration tests install that owner in the supported
`integration_test/flutter_test_config.dart` hook, before Flutter's generated
runner calls its own integration-binding initializer. Test entrypoints cannot
replace a binding that the runner has already created.
The native settings entrypoint installs the same owner synchronously before
fixture-file I/O, following ordinary application startup. A foreign binding is
rejected before fixture paths are read or opened.

The Dart producer uses public RenderView and [SemanticsOwner](https://api.flutter.dev/flutter/semantics/SemanticsOwner-class.html) APIs to observe the
current semantic tree. It sends bounded complete snapshots over the private
`io.busystack.busydata/accessibility` method channel. The native consumer validates
the complete candidate before replacing its current snapshot. Stable owned ATK
objects look up current presentation data by identity. Removed nodes become
defunct and cannot retain old values or operate on a new owner.
Topology, text, name and permission notifications finish before focus
notifications. Previous focus loss precedes new focus gain. Focus transitions
precede caret and selection notifications from the same snapshot, so a text
client cannot silently adopt a newly focused field through its caret event and
then discard the focus announcement as redundant. The current text and offsets
are already readable when focus is announced. A newly introduced or replaced
focused object receives its initial focus notifications even when its numeric
node ID survives. Later unchanged publications do not repeat them. Reentrant
publication or disposal stops notifications from the superseded snapshot,
including deferred caret and selection events. Retired objects remain defunct.

A text field keeps its Text and EditableText interfaces when composition or
readonly state temporarily removes mutation callbacks, as does the public
[GtkEntryAccessible interface](https://docs.gtk.org/gtk3/class.EntryAccessible.html).
Changing [GTK editability](https://docs.gtk.org/gtk3/method.Editable.set_editable.html)
changes permissions rather than the control's identity. Each owned action still
checks current callbacks and readonly/protected state; interface presence does
not grant editing. `ATK_STATE_EDITABLE` follows the field's current readonly
state, rather than temporary callback admission during composition. Actual owner
or interface-role replacements retire old nodes.

Owned Fluent menu adapters publish menu scopes around actual popups and menu
item or checkbox roles on the same semantic nodes as the normal focus and tap
callbacks. Enabled and checked states are explicit; keyboard focus does not
invent a selected state. A disabled item's advertised interface cannot grant
permission to invoke it. MenuBar composition uses public item and transition
builders while retaining the official submenu item lists, keys and dismissal
behavior. Widget checks cover these roles and actions; native acceptance still
requires the real popup, keyboard focus and resulting operation.

Protocol version 1 is strict. `attach` binds the view and creates a native-owned
bridge epoch. The Dart owner epoch changes when SemanticsOwner changes. Every
publication and action includes the view, both epochs and a monotonic snapshot
revision. Old publications, replies and actions are rejected. A limited or
unavailable publication retires the old tree explicitly; old data is not presented
as current. `detach` releases the owned projection.

Publication has one bounded handoff candidate. After capturing public semantics
and successfully encoding within 8MiB, Dart issues that candidate immediately
before sending it to native. Native validates and installs the complete snapshot
before it can issue an action for that revision. Such an exact action can arrive
before the publication reply returns to Dart; it still requires the current
epochs, revision, live node data and permitted callback. A valid reply promotes
the same candidate. Changes, failure, timeout, disposal and publication cleanup
retire it. There is no historical-model fallback or editing retry.

Limits are 16,384 nodes, depth 128, 1,048,576 UTF-16 text units, 8MiB encoded data, a separate 32MiB native-model admission bound,
32 pending native actions and a two-second action lifetime. Both sides validate
identities, tree structure, text, finite bounds and action applicability. Cycles,
duplicate nodes, unknown owners and oversized payloads fail explicitly. No
credential value or action text belongs in diagnostics. Obscured fields expose
masked presentation and cannot supply copy/cut operations.

Native ATK character offsets use Unicode scalar indices; Flutter callbacks use
UTF-16. Conversion is exact and bounded. Native requests dispatch existing public
semantic callbacks. Compound text actions preserve selection ordering, current
source and owner checks, typed admission, undo and clipboard behavior. A dispatched
action is not an acknowledgement of an edit or a database operation. The bridge
does not retry editing or invoke database operations independently.
ATK `Component.scroll_to(ANYWHERE)` dispatches the current Flutter
`showOnScreen` operation. Render-object semantics supply its default handler
even without an explicit action bit. An enabled offscreen node retains this
reveal operation; focus and text operations remain unavailable while hidden.
The native focus reader dispatches reveal once and waits for a fresh visible
node before requesting focus, within the existing focus deadline. Unsupported
edge/corner placement requests return false. The same view, epoch, revision and
live-node admission guards apply to reveal. Dispatch alone does not prove that
the node became visible. Reveal is exposed through `Component`, not through
ordinary ATK action indices; bringing a node into view cannot turn a captured
reveal index into a button activation index. See the official
[ATK scrolling contract](https://docs.gtk.org/atk/method.Component.scroll_to.html)
and [placement semantics](https://docs.gtk.org/atk/enum.ScrollType.html).
Native connection-page readiness uses the same reveal reader for an offscreen
page marker, then requires its fresh visible state. Selecting a page once does
not authorize tapping an unseen checkbox, replaying the page selection or
extending the existing readiness deadline.

Native acceptance reacquires a button's current proxy and activation index after
its focus transition, and requires the fresh control to report focus. Focus can
change the available action list; a pre-focus index is not an activation token.
Missing current controls remain pending within the normal wait. Owner failures
propagate, and the verifier dispatches activation once, then checks the resulting
state. An accepted AT-SPI dispatch does not override a stale bridge reply or
authorize an input retry.

Each Explorer row publishes one focused object with its stable tree identity,
selection, expansion and focus action. Its keyboard detector retains the input
focus and shortcuts while the enclosing row supplies focus semantics. This keeps
the screen reader's current object on the named tree item during traversal.
The saved Explorer selection is consumed during initial branch recovery. A live
row choice retires that pending restoration; later metadata replies cannot reset
selection from the older debounced preference. Reconnecting can restore the saved
stable row identity after its branch loads without taking keyboard focus.
Explorer focus checks reacquire rebuilt rows by their published semantic
identifier and application process, before requiring fresh focus and keyboard
acknowledgements. Each dispatched Down key requires a different published row
identifier in the same application before another key. A changed availability
caption or rebuilt native proxy with the same identity cannot acknowledge
movement. Bounded before/after identities are retained for failure inspection;
the key count and original deadlines are unchanged.
Read-only result and Explorer observations keep incomplete
snapshots pending within their original deadline. An incomplete snapshot cannot
prove absence; action dispatch, malformed ownership and resource-limit failures
remain outside that continuation.
Explorer traversal requires the published expanded branch and its loading state
before taking focus. Each subsequent key decision requires a complete focused-row
observation; an unavailable snapshot cannot decide that the target is absent.
The traversal retains its eight-key bound and unchanged acknowledgement deadline.
Independent-console creation captures a complete session inventory within the
bounded read-only wait before dispatching New query. An incomplete capture cannot
be accepted as an empty baseline or cause that action to be replayed.
Value Editor bodies publish a fresh, opaque instance identifier for each editor
State. Native readers capture it inside the exact authored title/role and process,
with the selected result-document owner. Popup routes can temporarily block the
dialog's semantics and retire its native handles. Afterward, readers require the
same body instance and process inside the same authored modal; another editor with
the same title cannot substitute. Missing snapshots wait within the original
deadline; changed owners, malformed identifiers and duplicate identities fail.
Inline-edit traversal also waits for the selected cell's editability hint on the
exact result generation before dispatching F2 once. A pending assessment does not
authorize retrying F2 or changing the product's read-only behavior.
Retained-filter text input captures the authored modal after its column-choice
popup closes, then reacquires the field within that exact modal and process for
focus and acknowledgement. A queued stale focus cannot prove success. The
controller sends one text edit after current focus and the exact original value
are verified; a replacement dialog cannot inherit that admission.

Product photographs use the supported
[GdkPixbuf buffer encoder](https://docs.gtk.org/gdk-pixbuf/method.Pixbuf.save_to_bufferv.html)
and an atomic file writer in the owned evidence directory. Captures preserve all
pixels and the requested physical dimensions, with no alternate image path or
encoder fallback. Input is bounded to 16,777,216 pixels, each dimension to 8192,
and encoded output to 68,157,440 bytes. Encoding, ownership, size and write errors
fail the gate; no partial capture is published.
Initial admission requires the exact published presentation. During an admitted
compound action, a caret or selection change can update the field's descriptive
label. Subsequent steps use the same live owner and node object, identifier,
role, expected value and selection rather than treating that label as identity.
These guards, current permissions, protection state and the original deadline
are checked again immediately before the next callback. A replacement node,
unexpected value or protection change retires the operation without retry.

The owned root exposes bounded action diagnostics through `busydata-action-*`
ATK attributes: the latest sequence, allowlisted action name, node ID, request
epochs/view/revision, reply revision and controlled status, plus reply, stale,
timeout and in-flight counters. No arguments, text, values, labels or error
messages are retained in this record. An `ok` reply must have protocol version 1,
the exact request owner and a non-regressing revision; rejected or malformed
replies remain explicit. Older replies cannot replace the latest action record,
and a settled timeout cannot become successful after a late reply. These are
dispatch diagnostics, never proof that an edit or database operation succeeded.

Bounds come from the current Flutter semantic projection and actual GTK view
allocation/origin. Screen and window coordinates retain the current view and
revision. Conservative field bounds carry explicit geometry precision; they are
not glyph geometry. Role, selected/expanded/focused state, parent relationships
and tree levels remain presentation facts from the current UI.

Owned SQL renderers register text geometry through the public [semantic-node assembly callback](https://api.flutter.dev/flutter/rendering/RenderObject/assembleSemanticsNode.html). The registry holds weak node/provider references and validates
the exact immutable editor value, current viewport and owned scroll position.
Public paragraph rectangles are normalized by their observed scroll epoch; live
movement is applied once. At most 4,096 visible UTF-16 range boxes are projected.
Range queries require complete coverage by actual glyph boxes. Offscreen,
ambiguous or unregistered ranges remain unavailable; a whole-field rectangle
cannot substitute for a glyph result. Ordinary field/component bounds remain
available with their explicit precision.

Only owned GObject class initializers may install ATK implementations, following
[GTK accessible-type registration](https://docs.gtk.org/gtk3/class_method.Widget.set_accessible_type.html).
Text behavior follows the public [ATK Text interface](https://docs.gtk.org/atk/iface.Text.html). Private
Flutter engine headers, pointer signals, runtime class/interface replacement and
upstream object patching are prohibited. Native acceptance must exercise the
ordinary complete release bundle: geometry, Unicode editing, focus and modal
ownership, tree relationships, clipboard, IME, Orca, actual appearance settings
and supported scales. Widget semantics and component fixtures do not certify
those gates. Genuine Windows and installed strict-Snap acceptance remain separate.

Focused GTK/ATK behavior can be checked with:

```sh
python3 tool/verify_native_accessibility_component.py
```

This component fixture does not certify the ordinary application, real database
workflows, Orca, appearance/scale conditions or installed strict-Snap acceptance.
Those source-bound native gates remain required, together with the three-engine
matrix and genuine Windows verification on a Windows runner.
