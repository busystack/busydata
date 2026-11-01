// Tests only BusyData-owned types. Including this application's implementation
// gives the fixture access to its parser/publication boundary without creating
// an engine, replacing any upstream class, or exposing a runtime test bypass.
#include "../busydata_accessibility_bridge.cc"
#include "../busydata_window_close.cc"

namespace {

void put_string(FlValue* map, const char* key, const std::string& value) {
  fl_value_set_string_take(map, key, fl_value_new_string_sized(value.data(), value.size()));
}

FlValue* rectangle(double x, double y, double width, double height) {
  FlValue* result = fl_value_new_list();
  for (double number : {x, y, width, height}) fl_value_append_take(result, fl_value_new_float(number));
  return result;
}

void children(FlValue* node, std::initializer_list<int64_t> ids) {
  FlValue* list = fl_value_new_list();
  for (int64_t id : ids) fl_value_append_take(list, fl_value_new_int(id));
  fl_value_set_string_take(node, "children", list);
}

FlValue* fixture_node(int64_t id, int64_t parent, bool text = false) {
  FlValue* result = fl_value_new_map();
  map_int(result, "id", id); map_int(result, "parentId", parent);
  map_int(result, "selectionBase", text ? 0 : -1);
  map_int(result, "selectionExtent", text ? 2 : -1);
  map_int(result, "treeLevel", 0);
  put_string(result, "identifier", text ? "fixture.editor" : "fixture.root");
  put_string(result, "label", text ? "Fixture editor" : "Fixture");
  put_string(result, "value", text ? u8"😀日" : "");
  for (const char* field : {"hint", "tooltip"}) put_string(result, field, "");
  put_string(result, "role", "none");
  put_string(result, "direction", "ltr");
  put_string(result, "textStatus", "available");
  put_string(result, "geometryPrecision", "field-bounds");
  children(result, {});
  FlValue* flags = fl_value_new_map();
  fl_value_set_string_take(flags, "enabled", fl_value_new_bool(true));
  fl_value_set_string_take(flags, "textField", fl_value_new_bool(text));
  fl_value_set_string_take(flags, "readOnly", fl_value_new_bool(false));
  fl_value_set_string_take(result, "flags", flags);
  FlValue* actions = fl_value_new_list();
  if (text) {
    for (const char* action : {"focus", "setText", "setSelection", "copy", "cut", "paste"})
      fl_value_append_take(actions, fl_value_new_string(action));
  }
  fl_value_set_string_take(result, "actions", actions);
  fl_value_set_string_take(result, "rect", text ? rectangle(40, 50, 500, 100) : rectangle(0, 0, 640, 480));
  return result;
}

FlValue* fixture_payload() {
  FlValue* result = fl_value_new_map();
  for (const char* key : {"version", "bridgeEpoch", "ownerEpoch", "revision"}) map_int(result, key, 1);
  map_int(result, "viewId", 0); map_int(result, "rootId", 1);
  put_string(result, "status", "ok"); put_string(result, "reason", "");
  fl_value_set_string_take(result, "viewWidth", fl_value_new_float(640));
  fl_value_set_string_take(result, "viewHeight", fl_value_new_float(480));
  FlValue* nodes = fl_value_new_list();
  FlValue* root = fixture_node(1, -1); children(root, {2});
  fl_value_append_take(nodes, root);
  fl_value_append_take(nodes, fixture_node(2, 1, true));
  fl_value_set_string_take(result, "nodes", nodes);
  return result;
}

FlValue* editor_node(FlValue* payload) {
  return fl_value_get_list_value(fl_value_lookup_string(payload, "nodes"), 1);
}

void glyphs(FlValue* editor) {
  put_string(editor, "geometryPrecision", "glyph-bounds");
  FlValue* geometry = fl_value_new_map();
  map_int(geometry, "start", 0); map_int(geometry, "end", 3);
  FlValue* boxes = fl_value_new_list();
  FlValue* first = fl_value_new_map(); map_int(first, "start", 0); map_int(first, "end", 2);
  fl_value_set_string_take(first, "rect", rectangle(45, 55, 18, 22));
  fl_value_append_take(boxes, first);
  FlValue* second = fl_value_new_map(); map_int(second, "start", 2); map_int(second, "end", 3);
  fl_value_set_string_take(second, "rect", rectangle(63, 55, 14, 22));
  fl_value_append_take(boxes, second);
  fl_value_set_string_take(geometry, "boxes", boxes);
  fl_value_set_string_take(editor, "textGeometry", geometry);
}

std::shared_ptr<const Snapshot> fixture_snapshot() {
  g_autoptr(FlValue) payload = fixture_payload();
  auto result = parse_snapshot(payload);
  g_assert_nonnull(result.get());
  return result;
}

void publish_payload(BusyDataAccessibilityHost* host, FlValue* payload) {
  auto next = parse_snapshot(payload);
  g_assert_nonnull(next.get());
  publish(host, std::move(next));
}

struct ComponentHost {
  GtkWidget* window;
  BusyDataAccessibilityHost* host;
  ComponentHost() {
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(window), 640, 480);
    host = reinterpret_cast<BusyDataAccessibilityHost*>(g_object_new(host_get_type(), nullptr));
    // Coordinate projection needs a real allocated child, not an engine. The
    // production factory still admits only its exact owned FlView.
    host->data->view = gtk_drawing_area_new();
    gtk_container_add(GTK_CONTAINER(host), host->data->view);
    gtk_widget_set_size_request(GTK_WIDGET(host), 640, 480);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(host));
    gtk_widget_show_all(window);
    for (int i = 0; i < 64 && g_main_context_pending(nullptr); ++i) g_main_context_iteration(nullptr, FALSE);
    publish(host, fixture_snapshot());
  }
  ~ComponentHost() {
    gtk_widget_destroy(window);
    for (int i = 0; i < 64 && g_main_context_pending(nullptr); ++i) g_main_context_iteration(nullptr, FALSE);
  }
  AtkObject* editor() { return existing_object(host, 2); }
};

void unicode_boundaries() {
  const std::string text = u8"😀日🧪";
  g_assert_cmpint(utf16_for_character(text, 0), ==, 0);
  g_assert_cmpint(utf16_for_character(text, 1), ==, 2);
  g_assert_cmpint(utf16_for_character(text, 2), ==, 3);
  g_assert_cmpint(utf16_for_character(text, 3), ==, 5);
  g_assert_cmpint(utf16_for_character(text, 4), ==, -1);
  g_assert_cmpint(character_for_utf16(text, 1), ==, -1);
  g_assert_cmpint(character_for_utf16(text, 4), ==, -1);
  g_assert_cmpint(character_for_utf16(text, 2), ==, 1);
  g_assert_cmpint(character_for_utf16(text, 5), ==, 3);
}

void malformed_topology() {
  for (int kind = 0; kind < 5; ++kind) {
    g_autoptr(FlValue) payload = fixture_payload();
    FlValue* root = fl_value_get_list_value(fl_value_lookup_string(payload, "nodes"), 0);
    if (kind == 0) map_int(editor_node(payload), "id", 1);
    if (kind == 1) children(root, {99});
    if (kind == 2) map_int(editor_node(payload), "parentId", -1);
    if (kind == 3) children(root, {2, 2});
    if (kind == 4) children(root, {});
    g_assert_null(parse_snapshot(payload).get());
  }
}

void malformed_text_and_flags() {
  for (int kind = 0; kind < 7; ++kind) {
    g_autoptr(FlValue) payload = fixture_payload();
    FlValue* editor = editor_node(payload);
    if (kind == 0) map_int(editor, "selectionExtent", 1);  // Surrogate interior.
    if (kind == 1) put_string(editor, "value", std::string(kMaxTextUnits + 1, 'x'));
    if (kind == 2) put_string(editor, "direction", "guess");
    if (kind == 3) put_string(editor, "role", "invented-role");
    if (kind == 4) fl_value_set_string_take(fl_value_lookup_string(editor, "flags"), "invented", fl_value_new_bool(true));
    if (kind == 5) fl_value_append_take(fl_value_lookup_string(editor, "actions"), fl_value_new_string("executeSql"));
    if (kind == 6) fl_value_set_string_take(editor, "rect", rectangle(0, 0, NAN, 4));
    g_assert_null(parse_snapshot(payload).get());
  }
}

void bounded_topology() {
  g_autoptr(FlValue) payload = fixture_payload();
  FlValue* too_many = fl_value_new_list();
  for (size_t i = 0; i <= kMaxNodes; ++i) fl_value_append_take(too_many, fl_value_new_null());
  fl_value_set_string_take(payload, "nodes", too_many);
  g_assert_null(parse_snapshot(payload).get());
  for (int count : {129, 130}) {
    g_autoptr(FlValue) deep = fixture_payload();
    map_int(deep, "rootId", 0);
    FlValue* nodes = fl_value_new_list();
    for (int i = 0; i < count; ++i) {
      FlValue* node = fixture_node(i, i - 1);
      if (i + 1 < count) children(node, {i + 1});
      fl_value_append_take(nodes, node);
    }
    fl_value_set_string_take(deep, "nodes", nodes);
    g_assert_cmpint(parse_snapshot(deep) != nullptr, ==, count == 129);
  }
}

void exact_text_and_selection() {
  ComponentHost fixture;
  AtkText* text = ATK_TEXT(fixture.editor());
  g_assert_cmpint(atk_text_get_character_count(text), ==, 2);
  g_assert_cmpint(atk_text_get_caret_offset(text), ==, 1);
  g_assert_cmpint(atk_text_get_n_selections(text), ==, 1);
  gint start = -1, end = -1;
  g_autofree gchar* selected = atk_text_get_selection(text, 0, &start, &end);
  g_assert_cmpstr(selected, ==, u8"😀");
  g_assert_cmpint(start, ==, 0); g_assert_cmpint(end, ==, 1);
  g_assert_cmpuint(atk_text_get_character_at_offset(text, 1), ==, 0x65e5);
  g_assert_null(atk_text_get_text(text, 0, 3));
}

void retained_nodes_release_old_snapshot() {
  ComponentHost fixture;
  AtkObject* original = ATK_OBJECT(g_object_ref(fixture.editor()));
  std::weak_ptr<const Snapshot> previous = fixture.host->data->snapshot;
  g_autoptr(FlValue) payload = fixture_payload();
  map_int(payload, "revision", 2); put_string(editor_node(payload), "value", u8"🧪日");
  publish_payload(fixture.host, payload);
  g_assert_true(previous.expired());
  g_assert_true(fixture.editor() == original);
  g_autofree gchar* text = atk_text_get_text(ATK_TEXT(original), 0, -1);
  g_assert_cmpstr(text, ==, u8"🧪日");
  g_object_unref(original);
}

void owner_replacement_defuncts_old_id() {
  ComponentHost fixture;
  AtkObject* original = ATK_OBJECT(g_object_ref(fixture.editor()));
  g_autoptr(FlValue) payload = fixture_payload(); map_int(payload, "ownerEpoch", 2);
  publish_payload(fixture.host, payload);
  g_assert_true(fixture.editor() != original);
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_DEFUNCT));
  g_assert_null(atk_object_get_parent(original));
  g_assert_null(atk_text_get_text(ATK_TEXT(original), 0, -1));
  g_object_unref(original);
}

void unavailable_retires_presentation() {
  ComponentHost fixture;
  AtkObject* original = ATK_OBJECT(g_object_ref(fixture.editor()));
  g_autoptr(FlValue) payload = fixture_payload();
  map_int(payload, "revision", 2); map_int(payload, "rootId", -1);
  put_string(payload, "status", "limited"); put_string(payload, "reason", "node-limit");
  fl_value_set_string_take(payload, "nodes", fl_value_new_list());
  auto next = parse_snapshot(payload); g_assert_nonnull(next.get());
  publish(fixture.host, std::move(next));
  g_assert_cmpint(atk_object_get_n_accessible_children(gtk_widget_get_accessible(GTK_WIDGET(fixture.host))), ==, 0);
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_DEFUNCT));
  g_object_unref(original);
}

void roles_states_and_readonly_copy() {
  ComponentHost fixture;
  g_autoptr(FlValue) payload = fixture_payload();
  FlValue* editor = editor_node(payload);
  fl_value_set_string_take(fl_value_lookup_string(editor, "flags"), "readOnly", fl_value_new_bool(true));
  auto next = parse_snapshot(payload); g_assert_nonnull(next.get());
  publish(fixture.host, next);
  g_assert_true(ATK_IS_TEXT(fixture.editor()));
  g_assert_true(ATK_IS_EDITABLE_TEXT(fixture.editor()));  // Copy is on this interface.
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(fixture.editor());
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_READ_ONLY));
  g_assert_false(atk_state_set_contains_state(states, ATK_STATE_EDITABLE));
  const Node& readonly = next->nodes.at(2);
  g_assert_true(permits(readonly, "copyRange"));
  for (const char* action : {"setText", "cut", "paste", "insertText", "deleteRange", "cutRange", "pasteAt"})
    g_assert_false(permits(readonly, action));
  Node password = readonly; password.flags[flag_index("password")] = 1;
  g_assert_cmpint(role_of(password), ==, ATK_ROLE_PASSWORD_TEXT);
  g_assert_false(permits(password, "copy")); g_assert_false(permits(password, "copyRange"));
  Node row; row.level = 3; row.flags[flag_index("button")] = 1;
  g_assert_cmpint(role_of(row), ==, ATK_ROLE_TREE_ITEM);
}

void exact_glyph_range_and_coordinates() {
  ComponentHost fixture;
  g_autoptr(FlValue) payload = fixture_payload(); glyphs(editor_node(payload));
  auto next = parse_snapshot(payload); g_assert_nonnull(next.get());
  publish(fixture.host, std::move(next));
  AtkText* text = ATK_TEXT(fixture.editor());
  AtkTextRectangle first, second, combined;
  GtkAllocation allocation;
  gtk_widget_get_allocation(fixture.host->data->view, &allocation);
  g_test_message("Actual view allocation %d x %d, logical snapshot %.0f x %.0f",
                 allocation.width, allocation.height,
                 fixture.host->data->snapshot->view_width,
                 fixture.host->data->snapshot->view_height);
  atk_text_get_range_extents(text, 0, 1, ATK_XY_WINDOW, &first);
  atk_text_get_range_extents(text, 1, 2, ATK_XY_WINDOW, &second);
  atk_text_get_range_extents(text, 0, 2, ATK_XY_WINDOW, &combined);
  g_assert_cmpint(first.width, ==, 18); g_assert_cmpint(second.width, ==, 14);
  g_assert_cmpint(second.x, ==, first.x + 18);
  g_assert_cmpint(combined.width, ==, 32); g_assert_cmpint(combined.height, ==, 22);
  g_assert_cmpint(atk_text_get_offset_at_point(text, first.x + 2, first.y + 2, ATK_XY_WINDOW), ==, 0);
  g_assert_cmpint(atk_text_get_offset_at_point(text, second.x + 2, second.y + 2, ATK_XY_WINDOW), ==, 1);
  g_assert_cmpint(atk_text_get_offset_at_point(text, second.x + 100, second.y + 2, ATK_XY_WINDOW), ==, -1);
  AtkTextRectangle screen; atk_text_get_range_extents(text, 0, 1, ATK_XY_SCREEN, &screen);
  gint x = 0, y = 0; gdk_window_get_origin(gtk_widget_get_window(fixture.window), &x, &y);
  g_assert_cmpint(screen.x, ==, first.x + x); g_assert_cmpint(screen.y, ==, first.y + y);
}

void missing_glyphs_are_not_field_bounds() {
  ComponentHost fixture;
  AtkTextRectangle rectangle;
  atk_text_get_range_extents(ATK_TEXT(fixture.editor()), 0, 1, ATK_XY_WINDOW, &rectangle);
  g_assert_cmpint(rectangle.width, ==, 0); g_assert_cmpint(rectangle.height, ==, 0);
  g_autoptr(FlValue) payload = fixture_payload(); glyphs(editor_node(payload));
  FlValue* geometry = fl_value_lookup_string(editor_node(payload), "textGeometry");
  FlValue* boxes = fl_value_new_list();
  FlValue* second = fl_value_get_list_value(fl_value_lookup_string(geometry, "boxes"), 1);
  fl_value_append(boxes, second); fl_value_set_string_take(geometry, "boxes", boxes);
  publish_payload(fixture.host, payload);
  atk_text_get_range_extents(ATK_TEXT(fixture.editor()), 0, 2, ATK_XY_WINDOW, &rectangle);
  g_assert_cmpint(rectangle.width, ==, 0);
}

void invalid_glyph_boundaries() {
  g_autoptr(FlValue) payload = fixture_payload(); glyphs(editor_node(payload));
  FlValue* geometry = fl_value_lookup_string(editor_node(payload), "textGeometry");
  FlValue* first = fl_value_get_list_value(fl_value_lookup_string(geometry, "boxes"), 0);
  map_int(first, "end", 1);  // Half of an emoji is never a glyph range.
  g_assert_null(parse_snapshot(payload).get());
}

void protected_text_must_be_masked_and_showing() {
  ComponentHost fixture;
  g_autoptr(FlValue) payload = fixture_payload();
  FlValue* editor = editor_node(payload);
  fl_value_set_string_take(fl_value_lookup_string(editor, "flags"), "password", fl_value_new_bool(true));
  g_assert_null(parse_snapshot(payload).get());  // Raw value/copy cannot cross.
  FlValue* actions = fl_value_new_list();
  for (const char* action : {"focus", "setText", "setSelection", "paste"})
    fl_value_append_take(actions, fl_value_new_string(action));
  fl_value_set_string_take(editor, "actions", actions);
  g_assert_null(parse_snapshot(payload).get());  // Still not a masked value.
  put_string(editor, "value", u8"•••");
  auto protected_snapshot = parse_snapshot(payload);
  g_assert_nonnull(protected_snapshot.get());
  publish(fixture.host, std::move(protected_snapshot));
  g_assert_cmpint(atk_object_get_role(fixture.editor()), ==, ATK_ROLE_PASSWORD_TEXT);
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(fixture.editor());
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_VISIBLE));
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_SHOWING));
}

void owned_root_hit_testing() {
  ComponentHost fixture;
  AtkObject* root = gtk_widget_get_accessible(GTK_WIDGET(fixture.host));
  g_assert_true(ATK_IS_COMPONENT(root));
  gint x, y, width, height;
  atk_component_get_extents(ATK_COMPONENT(fixture.editor()), &x, &y, &width, &height, ATK_XY_WINDOW);
  g_autoptr(AtkObject) found = atk_component_ref_accessible_at_point(
      ATK_COMPONENT(root), x + width / 2, y + height / 2, ATK_XY_WINDOW);
  g_assert_true(found == fixture.editor());
  g_assert_true(found != gtk_widget_get_accessible(fixture.host->data->view));
}

void tree_false_is_not_unknown() {
  ComponentHost fixture;
  g_autoptr(FlValue) payload = fixture_payload();
  FlValue* row = editor_node(payload);
  map_int(row, "treeLevel", 3); map_int(row, "selectionBase", -1); map_int(row, "selectionExtent", -1);
  put_string(row, "identifier", "busydata.database.item.3.fixture-row");
  put_string(row, "label", "Fixture tree row"); put_string(row, "value", "");
  FlValue* actions = fl_value_new_list();
  for (const char* action : {"focus", "tap"}) fl_value_append_take(actions, fl_value_new_string(action));
  fl_value_set_string_take(row, "actions", actions);
  FlValue* flags = fl_value_lookup_string(row, "flags");
  fl_value_set_string_take(flags, "textField", fl_value_new_bool(false));
  fl_value_set_string_take(flags, "button", fl_value_new_bool(true));
  fl_value_set_string_take(flags, "selected", fl_value_new_bool(false));
  fl_value_set_string_take(flags, "expanded", fl_value_new_bool(false));
  publish_payload(fixture.host, payload);
  g_assert_cmpint(atk_object_get_role(fixture.editor()), ==, ATK_ROLE_TREE_ITEM);
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(fixture.editor());
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_EXPANDABLE));
  g_assert_false(atk_state_set_contains_state(states, ATK_STATE_EXPANDED));
  g_assert_true(atk_state_set_contains_state(states, ATK_STATE_SELECTABLE));
  g_assert_false(atk_state_set_contains_state(states, ATK_STATE_SELECTED));
}

void bounded_codec_rejects_lossy_nul_wire() {
  g_autoptr(FlMethodCodec) codec = FL_METHOD_CODEC(g_object_new(bounded_codec_get_type(), nullptr));
  g_autoptr(FlStandardMethodCodec) standard = fl_standard_method_codec_new();
  g_autoptr(FlValue) value = fl_value_new_string(u8"日😀");
  g_autoptr(GError) error = nullptr;
  g_autoptr(GBytes) valid = FL_METHOD_CODEC_GET_CLASS(standard)->encode_success_envelope(FL_METHOD_CODEC(standard), value, &error);
  g_assert_no_error(error);
  g_autoptr(FlMethodResponse) response = FL_METHOD_CODEC_GET_CLASS(codec)->decode_response(codec, valid, &error);
  g_assert_no_error(error); g_assert_nonnull(response);

  // Official StandardMethodCodec fixtures: success envelope/string and a
  // method-call/map containing a sized UTF-8 string with an embedded NUL.
  // The official-only reproduction shows decode/re-encode loses its suffix.
  const guint8 raw_response[] = {0, 7, 12, 'b','e','f','o','r','e',0,'a','f','t','e','r'};
  g_autoptr(GBytes) bytes = g_bytes_new_static(raw_response, sizeof raw_response);
  g_autoptr(FlMethodResponse) rejected = FL_METHOD_CODEC_GET_CLASS(codec)->decode_response(codec, bytes, &error);
  g_assert_null(rejected); g_assert_nonnull(error); g_clear_error(&error);

  const guint8 raw_method[] = {7,7,'p','u','b','l','i','s','h',13,1,7,3,'k','e','y',7,12,'b','e','f','o','r','e',0,'a','f','t','e','r'};
  g_autoptr(GBytes) method = g_bytes_new_static(raw_method, sizeof raw_method);
  gchar* name = nullptr; FlValue* args = nullptr;
  g_assert_false(FL_METHOD_CODEC_GET_CLASS(codec)->decode_method_call(codec, method, &name, &args, &error));
  g_assert_nonnull(error); g_free(name); if (args != nullptr) fl_value_unref(args); g_clear_error(&error);

  std::vector<guint8> oversized(kMaxBytes + 1, 0);
  g_autoptr(GBytes) large = g_bytes_new(oversized.data(), oversized.size());
  g_autoptr(FlMethodResponse) too_large = FL_METHOD_CODEC_GET_CLASS(codec)->decode_response(codec, large, &error);
  g_assert_null(too_large); g_assert_nonnull(error);
}

void exact_two_times_allocation_mapping() {
  ComponentHost fixture;
  g_autoptr(FlValue) payload = fixture_payload(); glyphs(editor_node(payload));
  fl_value_set_string_take(payload, "viewWidth", fl_value_new_float(320));
  fl_value_set_string_take(payload, "viewHeight", fl_value_new_float(240));
  fl_value_set_string_take(editor_node(payload), "rect", rectangle(20, 25, 280, 100));
  publish_payload(fixture.host, payload);
  GtkAllocation allocation; gtk_widget_get_allocation(fixture.host->data->view, &allocation);
  g_assert_cmpint(allocation.width, ==, 640); g_assert_cmpint(allocation.height, ==, 480);
  AtkTextRectangle first;
  atk_text_get_range_extents(ATK_TEXT(fixture.editor()), 0, 1, ATK_XY_WINDOW, &first);
  g_assert_cmpint(first.width, ==, 36); g_assert_cmpint(first.height, ==, 44);
  g_assert_cmpint(first.x, ==, 90); g_assert_cmpint(first.y, ==, 110);
  g_assert_cmpint(atk_text_get_offset_at_point(ATK_TEXT(fixture.editor()), 92, 112, ATK_XY_WINDOW), ==, 0);
}

void reused_objects_notify_current_properties() {
  ComponentHost fixture;
  AtkObject* root = existing_object(fixture.host, 1);
  AtkObject* editor = fixture.editor();
  struct Observations {
    BusyDataAccessibilityHost* host;
    int role = 0, parent = 0, description = 0;
  } observed{fixture.host};
  g_signal_connect(root, "notify::accessible-role", G_CALLBACK(+[](GObject* object, GParamSpec*, gpointer data) {
    auto* state = static_cast<Observations*>(data);
    g_assert_cmpint(atk_object_get_role(ATK_OBJECT(object)), ==, ATK_ROLE_TABLE);
    ++state->role;
  }), &observed);
  g_signal_connect(editor, "notify::accessible-parent", G_CALLBACK(+[](GObject* object, GParamSpec*, gpointer data) {
    auto* state = static_cast<Observations*>(data);
    g_assert_true(atk_object_get_parent(ATK_OBJECT(object)) == existing_object(state->host, 3));
    ++state->parent;
  }), &observed);
  g_signal_connect(editor, "notify::accessible-description", G_CALLBACK(+[](GObject* object, GParamSpec*, gpointer data) {
    auto* state = static_cast<Observations*>(data);
    g_assert_cmpstr(atk_object_get_description(ATK_OBJECT(object)), ==, "Changed helper");
    ++state->description;
  }), &observed);
  g_autoptr(FlValue) payload = fixture_payload();
  map_int(payload, "revision", 2);
  FlValue* root_node = fl_value_get_list_value(fl_value_lookup_string(payload, "nodes"), 0);
  put_string(root_node, "role", "table"); children(root_node, {3});
  map_int(editor_node(payload), "parentId", 3);
  put_string(editor_node(payload), "hint", "Changed helper");
  FlValue* branch = fixture_node(3, 1); children(branch, {2});
  put_string(branch, "identifier", "fixture.branch");
  fl_value_append_take(fl_value_lookup_string(payload, "nodes"), branch);
  publish_payload(fixture.host, payload);
  g_assert_true(existing_object(fixture.host, 1) == root);
  g_assert_true(fixture.editor() == editor);
  g_assert_cmpint(observed.role, ==, 1);
  g_assert_cmpint(observed.parent, ==, 1);
  g_assert_cmpint(observed.description, ==, 1);
  // Tooltip is not the effective description while an explicit hint exists.
  map_int(payload, "revision", 3);
  put_string(editor_node(payload), "tooltip", "Secondary tooltip");
  publish_payload(fixture.host, payload);
  g_assert_cmpint(observed.role, ==, 1);
  g_assert_cmpint(observed.parent, ==, 1);
  g_assert_cmpint(observed.description, ==, 1);
  g_signal_handlers_disconnect_by_data(root, &observed);
  g_signal_handlers_disconnect_by_data(editor, &observed);
}

struct TestMessage { GTask* task; FlValue* arguments; };
struct TestMessengerData {
  std::vector<TestMessage> pending;
  size_t sent = 0;
  size_t handler_sets = 0;
  gpointer handler_data = nullptr;
  GDestroyNotify handler_destroy = nullptr;
};
struct BusyDataTestAccessibilityMessenger { GObject parent_instance; TestMessengerData* data; };
struct BusyDataTestAccessibilityMessengerClass { GObjectClass parent_class; };
void test_messenger_interface(FlBinaryMessengerInterface* iface);
G_DEFINE_TYPE_WITH_CODE(BusyDataTestAccessibilityMessenger, test_messenger, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(fl_binary_messenger_get_type(), test_messenger_interface))

void test_messenger_class_init(BusyDataTestAccessibilityMessengerClass* klass) {
  G_OBJECT_CLASS(klass)->finalize = [](GObject* object) {
    auto* self = reinterpret_cast<BusyDataTestAccessibilityMessenger*>(object);
    g_assert_true(self->data->pending.empty());
    if (self->data->handler_destroy != nullptr) self->data->handler_destroy(self->data->handler_data);
    delete self->data;
    G_OBJECT_CLASS(test_messenger_parent_class)->finalize(object);
  };
}
void test_messenger_init(BusyDataTestAccessibilityMessenger* self) { self->data = new TestMessengerData; }
void test_messenger_interface(FlBinaryMessengerInterface* iface) {
  iface->set_message_handler_on_channel = [](FlBinaryMessenger* messenger, const gchar*, FlBinaryMessengerMessageHandler,
                                              gpointer data, GDestroyNotify destroy) {
    auto* self = reinterpret_cast<BusyDataTestAccessibilityMessenger*>(messenger);
    ++self->data->handler_sets;
    if (self->data->handler_destroy != nullptr) self->data->handler_destroy(self->data->handler_data);
    self->data->handler_data = data; self->data->handler_destroy = destroy;
  };
  iface->send_on_channel = [](FlBinaryMessenger* messenger, const gchar* channel, GBytes* message,
                                GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data) {
    const bool close = g_str_equal(channel, "flutter/platform");
    g_assert_true(close || g_str_equal(channel, kChannel));
    auto* self = reinterpret_cast<BusyDataTestAccessibilityMessenger*>(messenger);
    g_autoptr(FlMethodCodec) codec = close ? FL_METHOD_CODEC(fl_json_method_codec_new()) : FL_METHOD_CODEC(fl_standard_method_codec_new());
    g_autofree gchar* name = nullptr;
    FlValue* arguments = nullptr;
    g_autoptr(GError) error = nullptr;
    g_assert_true(FL_METHOD_CODEC_GET_CLASS(codec)->decode_method_call(FL_METHOD_CODEC(codec), message, &name, &arguments, &error));
    g_assert_no_error(error); g_assert_cmpstr(name, ==, close ? "System.requestAppExit" : "action");
    if (close) {
      g_assert_cmpuint(fl_value_get_length(arguments), ==, 1);
      g_assert_cmpstr(fl_value_get_string(fl_value_lookup_string(arguments, "type")), ==, "cancelable");
    }
    self->data->pending.push_back({g_task_new(messenger, cancellable, callback, user_data), arguments});
    ++self->data->sent;
  };
  iface->send_on_channel_finish = [](FlBinaryMessenger*, GAsyncResult* result, GError** error) {
    return static_cast<GBytes*>(g_task_propagate_pointer(G_TASK(result), error));
  };
}

void drain_callbacks() {
  for (int index = 0; index < 128 && g_main_context_pending(nullptr); ++index)
    g_main_context_iteration(nullptr, FALSE);
}

struct ActionHost {
  ComponentHost component;
  BusyDataTestAccessibilityMessenger* messenger;
  ActionHost() {
    messenger = reinterpret_cast<BusyDataTestAccessibilityMessenger*>(g_object_new(test_messenger_get_type(), nullptr));
    g_autoptr(FlMethodCodec) codec = FL_METHOD_CODEC(g_object_new(bounded_codec_get_type(), nullptr));
    component.host->data->channel = fl_method_channel_new(FL_BINARY_MESSENGER(messenger), kChannel, codec);
  }
  ~ActionHost() {
    while (!messenger->data->pending.empty()) {
      auto message = messenger->data->pending.back(); messenger->data->pending.pop_back();
      g_task_return_new_error(message.task, G_IO_ERROR, G_IO_ERROR_CANCELLED, "Owned fixture closed");
      g_object_unref(message.task); fl_value_unref(message.arguments);
    }
    drain_callbacks();
    g_object_unref(messenger);
  }
  void send() { atk_editable_text_set_text_contents(ATK_EDITABLE_TEXT(component.editor()), "fixture-value-not-for-diagnostics"); }
  FlValue* reply(size_t index, const char* status = "ok") {
    auto* arguments = messenger->data->pending.at(index).arguments;
    FlValue* result = fl_value_new_map();
    for (const char* key : {"version", "bridgeEpoch", "viewId", "ownerEpoch", "revision"})
      fl_value_set_string(result, key, fl_value_lookup_string(arguments, key));
    put_string(result, "status", status);
    return result;
  }
  void finish(size_t index, FlValue* reply, bool error = false) {
    auto message = messenger->data->pending.at(index);
    messenger->data->pending.erase(messenger->data->pending.begin() + index);
    if (error) g_task_return_new_error(message.task, G_IO_ERROR, G_IO_ERROR_FAILED, "Private fixture failure text");
    else {
      g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
      GBytes* bytes = FL_METHOD_CODEC_GET_CLASS(codec)->encode_success_envelope(FL_METHOD_CODEC(codec), reply, nullptr);
      g_task_return_pointer(message.task, bytes, +[](gpointer value) { g_bytes_unref(static_cast<GBytes*>(value)); });
    }
    g_object_unref(message.task); fl_value_unref(message.arguments);
    drain_callbacks();
  }
  void expect(const char* key, const char* expected) {
    const auto actual = attribute(key);
    g_assert_cmpstr(actual.c_str(), ==, expected);
  }
  std::string attribute(const char* key) {
    AtkAttributeSet* attrs = atk_object_get_attributes(gtk_widget_get_accessible(GTK_WIDGET(component.host)));
    std::string value;
    for (GSList* item = attrs; item != nullptr; item = item->next) {
      auto* attribute = static_cast<AtkAttribute*>(item->data);
      if (g_str_equal(attribute->name, key)) value = attribute->value;
      g_assert_null(strstr(attribute->value, "fixture-value-not-for-diagnostics"));
      g_assert_null(strstr(attribute->value, "Private fixture failure text"));
    }
    atk_attribute_set_free(attrs);
    return value;
  }
};

FlValue* hidden_reveal_payload() {
  FlValue* payload = fixture_payload();
  map_int(payload, "revision", 2);
  auto* editor = editor_node(payload);
  fl_value_set_string_take(fl_value_lookup_string(editor, "flags"), "hidden", fl_value_new_bool(true));
  fl_value_set_string_take(editor, "rect", rectangle(40, 800, 500, 100));
  auto* actions = fl_value_new_list();
  fl_value_append_take(actions, fl_value_new_string("showOnScreen"));
  fl_value_set_string_take(editor, "actions", actions);
  return payload;
}

void hidden_component_reveals_without_focus_or_edge_placement() {
  ActionHost fixture;
  g_autoptr(FlValue) payload = hidden_reveal_payload();
  publish_payload(fixture.component.host, payload);
  auto* editor = ATK_COMPONENT(fixture.component.editor());
  g_assert_cmpint(atk_action_get_n_actions(ATK_ACTION(editor)), ==, 0);
  g_assert_false(atk_action_do_action(ATK_ACTION(editor), 0));
  g_assert_false(atk_component_grab_focus(editor));
  g_assert_false(atk_component_scroll_to(editor, ATK_SCROLL_TOP_LEFT));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 0);
  g_assert_true(atk_component_scroll_to(editor, ATK_SCROLL_ANYWHERE));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  auto* arguments = fixture.messenger->data->pending.at(0).arguments;
  g_assert_cmpstr(fl_value_get_string(fl_value_lookup_string(arguments, "action")), ==, "showOnScreen");
  g_autoptr(FlValue) reply = fixture.reply(0);
  fixture.finish(0, reply);
  fixture.expect("busydata-action-status", "ok");
  g_assert_false(atk_component_grab_focus(editor));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
}

void component_reveal_requires_current_node_and_capability() {
  ActionHost fixture;
  auto* original = ATK_OBJECT(g_object_ref(fixture.component.editor()));
  g_assert_false(atk_component_scroll_to(ATK_COMPONENT(original), ATK_SCROLL_ANYWHERE));
  g_autoptr(FlValue) payload = hidden_reveal_payload();
  map_int(payload, "ownerEpoch", 2);
  publish_payload(fixture.component.host, payload);
  g_assert_false(atk_component_scroll_to(ATK_COMPONENT(original), ATK_SCROLL_ANYWHERE));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 0);
  g_object_unref(original);
}

void component_reveal_does_not_change_ordinary_action_indices() {
  ActionHost fixture;
  g_autoptr(FlValue) payload = fixture_payload();
  map_int(payload, "revision", 2);
  auto* actions = fl_value_new_list();
  for (const char* name : {"showOnScreen", "focus", "setText", "setSelection", "copy"})
    fl_value_append_take(actions, fl_value_new_string(name));
  fl_value_set_string_take(editor_node(payload), "actions", actions);
  publish_payload(fixture.component.host, payload);
  auto* editor = ATK_ACTION(fixture.component.editor());
  g_assert_cmpint(atk_action_get_n_actions(editor), ==, 4);
  g_assert_cmpstr(atk_action_get_name(editor, 0), ==, "focus");
  g_assert_cmpstr(atk_action_get_name(editor, 1), ==, "setText");
  g_assert_cmpstr(atk_action_get_name(editor, 3), ==, "copy");
  g_assert_null(atk_action_get_name(editor, 4));
  g_assert_true(atk_action_do_action(editor, 0));
  auto* arguments = fixture.messenger->data->pending.at(0).arguments;
  g_assert_cmpstr(fl_value_get_string(fl_value_lookup_string(arguments, "action")), ==, "focus");
  g_autoptr(FlValue) reply = fixture.reply(0);
  fixture.finish(0, reply);
}

void declined_component_reveal_does_not_replay_or_focus() {
  ActionHost fixture;
  g_autoptr(FlValue) payload = hidden_reveal_payload();
  publish_payload(fixture.component.host, payload);
  auto* editor = ATK_COMPONENT(fixture.component.editor());
  g_assert_true(atk_component_scroll_to(editor, ATK_SCROLL_ANYWHERE));
  g_autoptr(FlValue) reply = fixture.reply(0, "unavailable");
  fixture.finish(0, reply);
  fixture.expect("busydata-action-status", "unavailable");
  g_assert_false(atk_component_grab_focus(editor));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  g_assert_cmpuint(fixture.messenger->data->pending.size(), ==, 0);
}

void action_outcome_ok_is_not_an_edit() {
  ActionHost fixture; fixture.send();
  fixture.expect("busydata-action-status", "pending");
  fixture.expect("busydata-action-inflight", "1");
  g_autoptr(FlValue) reply = fixture.reply(0); map_int(reply, "revision", 2);
  fixture.finish(0, reply);
  fixture.expect("busydata-action-status", "ok");
  fixture.expect("busydata-action-name", "setText");
  fixture.expect("busydata-action-sequence", "1");
  fixture.expect("busydata-action-request-revision", "1");
  fixture.expect("busydata-action-reply-revision", "2");
  fixture.expect("busydata-action-reply-count", "1");
  fixture.expect("busydata-action-inflight", "0");
  g_autofree gchar* text = atk_text_get_text(ATK_TEXT(fixture.component.editor()), 0, -1);
  g_assert_cmpstr(text, ==, u8"😀日");  // No acknowledged edit is fabricated.
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
}

void action_stale_and_foreign_owner_never_acknowledge_ok() {
  ActionHost fixture;
  for (const char* field : {"status", "status-advanced", "bridgeEpoch", "viewId", "ownerEpoch", "revision"}) {
    fixture.send(); g_autoptr(FlValue) reply = fixture.reply(0);
    if (g_str_has_prefix(field, "status")) { put_string(reply, "status", "stale"); map_int(reply, "revision", g_str_equal(field, "status") ? 1 : 3); }
    else map_int(reply, field, g_str_equal(field, "revision") ? 0 : 99);
    fixture.finish(0, reply);
    fixture.expect("busydata-action-status", "stale");
  }
  fixture.expect("busydata-action-stale-count", "6");
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 6);
}

void action_malformed_and_transport_failures_are_controlled() {
  ActionHost fixture;
  for (int kind = 0; kind < 6; ++kind) {
    fixture.send(); g_autoptr(FlValue) reply = kind == 4 ? fl_value_new_string("not a reply map") : fixture.reply(0);
    if (kind == 0) map_int(reply, "version", 2);
    if (kind == 1) put_string(reply, "status", "Private fixture failure text");
    if (kind == 2) put_string(reply, "revision", "wrong type");
    if (kind == 3) put_string(reply, "unexpected", "not accepted");
    fixture.finish(0, reply, kind == 5);
    fixture.expect("busydata-action-status", kind == 5 ? "transport-error" : "malformed");
  }
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 6);
}

void older_action_reply_does_not_replace_newer_outcome() {
  ActionHost fixture; fixture.send(); fixture.send();
  std::weak_ptr<const Snapshot> previous = fixture.component.host->data->snapshot;
  g_autoptr(FlValue) replacement = fixture_payload(); map_int(replacement, "revision", 2);
  publish_payload(fixture.component.host, replacement);
  g_assert_true(previous.expired());  // Pending callbacks pin only compact context.
  g_autoptr(FlValue) older = fixture.reply(0, "stale");
  fixture.finish(0, older);
  fixture.expect("busydata-action-sequence", "2");
  fixture.expect("busydata-action-status", "pending");
  g_autoptr(FlValue) current = fixture.reply(0); fixture.finish(0, current);
  fixture.expect("busydata-action-status", "ok");
  fixture.expect("busydata-action-reply-count", "2");
  fixture.expect("busydata-action-stale-count", "1");
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 2);
}

void action_timeout_and_late_reply_do_not_replay() {
  ActionHost fixture; fixture.send();
  gint64 deadline = g_get_monotonic_time() + 3 * G_TIME_SPAN_SECOND;
  while (!fixture.component.host->data->pending.empty() && g_get_monotonic_time() < deadline) {
    drain_callbacks(); g_usleep(1000);
  }
  fixture.expect("busydata-action-status", "cancelled");
  fixture.expect("busydata-action-timeout-count", "1");
  fixture.expect("busydata-action-inflight", "0");
  g_autoptr(FlValue) late = fixture.reply(0); fixture.finish(0, late);
  fixture.expect("busydata-action-status", "cancelled");
  fixture.expect("busydata-action-reply-count", "0");
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
}

void action_admission_and_disposal_remain_bounded() {
  ActionHost fixture;
  for (size_t index = 0; index < kMaxPendingActions + 1; ++index) fixture.send();
  g_assert_cmpuint(fixture.messenger->data->sent, ==, kMaxPendingActions);
  fixture.expect("busydata-action-inflight", "32");
  g_autoptr(GObject) held = G_OBJECT(g_object_ref(fixture.component.host));
  g_object_run_dispose(held);
  while (!fixture.messenger->data->pending.empty()) {
    g_autoptr(FlValue) late = fixture.reply(0); fixture.finish(0, late);
  }
  g_assert_true(fixture.component.host->data->disposed);
  g_assert_true(fixture.component.host->data->pending.empty());
  g_assert_cmpuint(fixture.messenger->data->sent, ==, kMaxPendingActions);
}

void official_gtk_entry_keeps_interfaces_when_readonly() {
  // Public upstream reference behavior, without changing any GTK type/object
  // implementation. Editability is a state of the same accessible control.
  g_test_message("Official GTK %u.%u.%u; ATK %s", gtk_get_major_version(), gtk_get_minor_version(),
                 gtk_get_micro_version(), atk_get_version());
  GtkWidget* entry = gtk_entry_new();
  g_object_ref_sink(entry);
  gtk_entry_set_text(GTK_ENTRY(entry), u8"😀日");
  g_autoptr(AtkObject) accessible = ATK_OBJECT(g_object_ref(gtk_widget_get_accessible(entry)));
  g_assert_true(ATK_IS_TEXT(accessible));
  g_assert_true(ATK_IS_EDITABLE_TEXT(accessible));
  gtk_editable_set_editable(GTK_EDITABLE(entry), FALSE);
  g_assert_true(gtk_widget_get_accessible(entry) == accessible);
  g_assert_true(ATK_IS_EDITABLE_TEXT(accessible));
  g_autoptr(AtkStateSet) readonly = atk_object_ref_state_set(accessible);
  g_assert_false(atk_state_set_contains_state(readonly, ATK_STATE_EDITABLE));
  g_autofree gchar* shown = atk_text_get_text(ATK_TEXT(accessible), 0, -1);
  g_assert_cmpstr(shown, ==, u8"😀日");
  gtk_editable_set_editable(GTK_EDITABLE(entry), TRUE);
  g_assert_true(gtk_widget_get_accessible(entry) == accessible);
  g_autoptr(AtkStateSet) editable = atk_object_ref_state_set(accessible);
  g_assert_true(atk_state_set_contains_state(editable, ATK_STATE_EDITABLE));
  gtk_widget_destroy(entry);
  g_object_unref(entry);
}

void textfield_interfaces_survive_composition_callback_changes() {
  ActionHost fixture;
  g_autoptr(AtkObject) original = ATK_OBJECT(g_object_ref(fixture.component.editor()));
  int editability_changes = 0;
  g_signal_connect(original, "state-change::editable", G_CALLBACK(+[](AtkObject*, const gchar*, gboolean, gpointer count) {
    ++*static_cast<int*>(count);
  }), &editability_changes);
  g_autoptr(FlValue) preedit = fixture_payload();
  map_int(preedit, "revision", 2);
  FlValue* node = editor_node(preedit);
  put_string(node, "label", "Fixture editor; input composition active");
  put_string(node, "value", u8"日"); map_int(node, "selectionBase", 1); map_int(node, "selectionExtent", 1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(true));
  FlValue* actions = fl_value_new_list(); fl_value_append_take(actions, fl_value_new_string("focus"));
  fl_value_set_string_take(node, "actions", actions);
  publish_payload(fixture.component.host, preedit);
  g_assert_true(fixture.component.editor() == original);
  g_assert_true(ATK_IS_EDITABLE_TEXT(original));
  g_autoptr(AtkStateSet) composing = atk_object_ref_state_set(original);
  g_assert_false(atk_state_set_contains_state(composing, ATK_STATE_DEFUNCT));
  g_assert_true(atk_state_set_contains_state(composing, ATK_STATE_EDITABLE));
  g_assert_true(atk_state_set_contains_state(composing, ATK_STATE_FOCUSED));
  g_assert_true(atk_state_set_contains_state(composing, ATK_STATE_SHOWING));
  g_autofree gchar* composing_text = atk_text_get_text(ATK_TEXT(original), 0, -1);
  g_assert_cmpstr(composing_text, ==, u8"日");
  g_assert_cmpint(atk_text_get_caret_offset(ATK_TEXT(original)), ==, 1);
  atk_editable_text_set_text_contents(ATK_EDITABLE_TEXT(original), "Must not dispatch during composition");
  gint position = 0;
  atk_editable_text_insert_text(ATK_EDITABLE_TEXT(original), "x", 1, &position);
  atk_editable_text_delete_text(ATK_EDITABLE_TEXT(original), 0, 1);
  g_assert_false(atk_text_set_caret_offset(ATK_TEXT(original), 0));
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 0);
  g_assert_cmpint(position, ==, 0);
  g_assert_cmpint(editability_changes, ==, 0);  // Callback admission is not readonly state.

  map_int(preedit, "revision", 3);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "readOnly", fl_value_new_bool(true));
  publish_payload(fixture.component.host, preedit);
  g_assert_true(fixture.component.editor() == original);
  g_autoptr(AtkStateSet) readonly = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(readonly, ATK_STATE_READ_ONLY));
  g_assert_false(atk_state_set_contains_state(readonly, ATK_STATE_EDITABLE));
  g_assert_cmpint(editability_changes, ==, 1);

  g_autoptr(FlValue) committed = fixture_payload();
  map_int(committed, "revision", 4);
  node = editor_node(committed);
  put_string(node, "value", u8"日"); map_int(node, "selectionBase", 1); map_int(node, "selectionExtent", 1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(true));
  publish_payload(fixture.component.host, committed);
  g_assert_true(fixture.component.editor() == original);
  g_autoptr(AtkStateSet) ready = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(ready, ATK_STATE_EDITABLE));
  g_assert_cmpint(editability_changes, ==, 2);
  atk_editable_text_set_text_contents(ATK_EDITABLE_TEXT(original), "one explicit resumed dispatch");
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  g_autoptr(FlValue) reply = fixture.reply(0); fixture.finish(0, reply);
  fixture.expect("busydata-action-status", "ok");
  g_signal_handlers_disconnect_by_data(original, &editability_changes);
}

void actual_textfield_role_change_retires_old_control() {
  ComponentHost fixture;
  g_autoptr(AtkObject) original = ATK_OBJECT(g_object_ref(fixture.editor()));
  g_autoptr(FlValue) button = fixture_payload();
  map_int(button, "revision", 2);
  FlValue* node = editor_node(button);
  put_string(node, "value", ""); map_int(node, "selectionBase", -1); map_int(node, "selectionExtent", -1);
  FlValue* flags = fl_value_lookup_string(node, "flags");
  fl_value_set_string_take(flags, "textField", fl_value_new_bool(false));
  fl_value_set_string_take(flags, "button", fl_value_new_bool(true));
  FlValue* actions = fl_value_new_list(); fl_value_append_take(actions, fl_value_new_string("tap"));
  fl_value_set_string_take(node, "actions", actions);
  publish_payload(fixture.host, button);
  g_assert_true(fixture.editor() != original);
  g_assert_cmpint(atk_object_get_role(fixture.editor()), ==, ATK_ROLE_PUSH_BUTTON);
  g_assert_false(ATK_IS_TEXT(fixture.editor()));
  g_assert_false(ATK_IS_EDITABLE_TEXT(fixture.editor()));
  g_autoptr(AtkStateSet) old = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(old, ATK_STATE_DEFUNCT));
  g_assert_null(atk_text_get_text(ATK_TEXT(original), 0, -1));
}

void focus_gain_precedes_caret_and_selection_on_an_existing_field() {
  ComponentHost fixture;
  g_autoptr(FlValue) initial = fixture_payload();
  map_int(initial, "revision", 2);
  auto* node = editor_node(initial);
  map_int(node, "selectionBase", -1); map_int(node, "selectionExtent", -1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(false));
  publish_payload(fixture.host, initial);
  auto* original = fixture.editor();
  struct Observation {
    bool has_focus = false;
    int announcements = 0;
    std::vector<std::string> events;
  } observed;
  g_signal_connect(original, "state-change::focused", G_CALLBACK(+[](AtkObject* object, const gchar*, gboolean focused, gpointer data) {
    if (!focused) return;
    auto* observation = static_cast<Observation*>(data);
    g_assert_cmpstr(atk_object_get_name(object), ==, "Fixture editor");
    g_assert_cmpint(atk_text_get_caret_offset(ATK_TEXT(object)), ==, 2);
    observation->events.emplace_back("focus");
    // A text client may adopt focus silently on a caret event. The later
    // redundant focus gain would then fail to announce the field's identity.
    if (!observation->has_focus) ++observation->announcements;
    observation->has_focus = true;
  }), &observed);
  g_signal_connect(original, "text-caret-moved", G_CALLBACK(+[](AtkObject*, gint, gpointer data) {
    auto* observation = static_cast<Observation*>(data);
    observation->events.emplace_back("caret");
    observation->has_focus = true;
  }), &observed);
  g_signal_connect(original, "text-selection-changed", G_CALLBACK(+[](AtkObject*, gpointer data) {
    static_cast<Observation*>(data)->events.emplace_back("selection");
  }), &observed);

  g_autoptr(FlValue) focused = fixture_payload();
  map_int(focused, "revision", 3); node = editor_node(focused);
  map_int(node, "selectionBase", 3); map_int(node, "selectionExtent", 3);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(true));
  publish_payload(fixture.host, focused);
  g_assert_true(fixture.editor() == original);
  g_assert_cmpint(observed.announcements, ==, 1);
  g_assert_true((observed.events == std::vector<std::string>{"focus", "caret", "selection"}));
  g_assert_cmpint(atk_text_get_n_selections(ATK_TEXT(original)), ==, 0);

  map_int(focused, "revision", 4);
  publish_payload(fixture.host, focused);
  g_assert_cmpuint(observed.events.size(), ==, 3);
  map_int(focused, "revision", 5);
  map_int(node, "selectionBase", 2); map_int(node, "selectionExtent", 2);
  publish_payload(fixture.host, focused);
  g_assert_true((observed.events == std::vector<std::string>{"focus", "caret", "selection", "caret", "selection"}));
  g_assert_cmpint(atk_text_get_caret_offset(ATK_TEXT(original)), ==, 1);
  g_assert_cmpint(observed.announcements, ==, 1);
  g_signal_handlers_disconnect_by_data(original, &observed);
}

void superseded_focus_gain_never_emits_its_pending_text_notifications() {
  ComponentHost fixture;
  g_autoptr(FlValue) initial = fixture_payload();
  map_int(initial, "revision", 2);
  auto* node = editor_node(initial);
  map_int(node, "selectionBase", -1); map_int(node, "selectionExtent", -1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(false));
  publish_payload(fixture.host, initial);

  g_autoptr(FlValue) replacement = fixture_payload();
  map_int(replacement, "revision", 4); node = editor_node(replacement);
  map_int(node, "selectionBase", 3); map_int(node, "selectionExtent", 3);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(false));
  struct Observation {
    BusyDataAccessibilityHost* host;
    FlValue* replacement;
    int focus_gains = 0;
    int caret_events = 0;
    int selection_events = 0;
  } observed{fixture.host, replacement};
  auto* original = fixture.editor();
  g_signal_connect(original, "state-change::focused", G_CALLBACK(+[](AtkObject*, const gchar*, gboolean focused, gpointer data) {
    if (!focused) return;
    auto* observation = static_cast<Observation*>(data);
    ++observation->focus_gains;
    publish_payload(observation->host, observation->replacement);
  }), &observed);
  g_signal_connect(original, "text-caret-moved", G_CALLBACK(+[](AtkObject*, gint, gpointer data) {
    ++static_cast<Observation*>(data)->caret_events;
  }), &observed);
  g_signal_connect(original, "text-selection-changed", G_CALLBACK(+[](AtkObject*, gpointer data) {
    ++static_cast<Observation*>(data)->selection_events;
  }), &observed);
  g_autoptr(FlValue) focused = fixture_payload();
  map_int(focused, "revision", 3); node = editor_node(focused);
  map_int(node, "selectionBase", 3); map_int(node, "selectionExtent", 3);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(true));
  publish_payload(fixture.host, focused);
  g_assert_cmpint(observed.focus_gains, ==, 1);
  g_assert_cmpint(observed.caret_events, ==, 0);
  g_assert_cmpint(observed.selection_events, ==, 0);
  g_assert_cmpuint(fixture.host->data->snapshot->revision, ==, 4);
  g_signal_handlers_disconnect_by_data(original, &observed);
}

void newly_published_focus_notifies_with_complete_ancestry() {
  ComponentHost fixture;
  struct Observation {
    BusyDataAccessibilityHost* host;
    int focus_events = 0;
    int focused_states = 0;
  } observed{fixture.host};
  const guint focus_signal = g_signal_lookup("focus-event", ATK_TYPE_OBJECT);
  const guint state_signal = g_signal_lookup("state-change", ATK_TYPE_OBJECT);
  const gulong focus_hook = g_signal_add_emission_hook(focus_signal, 0,
      +[](GSignalInvocationHint*, guint count, const GValue* values, gpointer data) -> gboolean {
        if (count != 2 || !g_value_get_boolean(&values[1])) return TRUE;
        auto* object = ATK_OBJECT(g_value_get_object(&values[0]));
        auto* observation = static_cast<Observation*>(data);
        Current current(object);
        if (current.host != observation->host || !ATK_IS_TEXT(object)) return TRUE;
        g_autoptr(AtkStateSet) states = atk_object_ref_state_set(object);
        g_assert_true(atk_state_set_contains_state(states, ATK_STATE_FOCUSED));
        g_assert_false(atk_state_set_contains_state(states, ATK_STATE_DEFUNCT));
        bool frame = false;
        AtkObject* parent = object;
        for (size_t depth = 0; parent != nullptr && depth < kMaxDepth + 4;
             parent = atk_object_get_parent(parent), ++depth) {
          if (atk_object_get_role(parent) == ATK_ROLE_FRAME) { frame = true; break; }
        }
        g_assert_true(frame);
        ++observation->focus_events;
        return TRUE;
      }, &observed, nullptr);
  const gulong state_hook = g_signal_add_emission_hook(state_signal, 0,
      +[](GSignalInvocationHint*, guint count, const GValue* values, gpointer data) -> gboolean {
        if (count != 3 || !g_str_equal(g_value_get_string(&values[1]), "focused") ||
            !g_value_get_boolean(&values[2])) return TRUE;
        auto* object = ATK_OBJECT(g_value_get_object(&values[0]));
        auto* observation = static_cast<Observation*>(data);
        Current current(object);
        if (current.host == observation->host && ATK_IS_TEXT(object)) ++observation->focused_states;
        return TRUE;
      }, &observed, nullptr);
  g_assert_cmpuint(focus_hook, !=, 0);
  g_assert_cmpuint(state_hook, !=, 0);

  g_autoptr(FlValue) next = fixture_payload();
  map_int(next, "revision", 2); map_int(next, "ownerEpoch", 2);
  fl_value_set_string_take(fl_value_lookup_string(editor_node(next), "flags"), "focused", fl_value_new_bool(true));
  publish_payload(fixture.host, next);
  g_assert_cmpint(observed.focus_events, ==, 1);
  g_assert_cmpint(observed.focused_states, ==, 1);

  map_int(next, "revision", 3);
  publish_payload(fixture.host, next);
  g_assert_cmpint(observed.focus_events, ==, 1);
  g_assert_cmpint(observed.focused_states, ==, 1);

  map_int(next, "revision", 4); map_int(next, "ownerEpoch", 3);
  publish_payload(fixture.host, next);
  g_assert_cmpint(observed.focus_events, ==, 2);
  g_assert_cmpint(observed.focused_states, ==, 2);
  g_signal_remove_emission_hook(focus_signal, focus_hook);
  g_signal_remove_emission_hook(state_signal, state_hook);
}

struct PublicationTrace {
  struct Event { char kind; AtkObject* object; AtkObject* child; bool focused; };
  BusyDataAccessibilityHost* host;
  std::vector<Event> events;
  std::vector<std::pair<guint, gulong>> hooks;
  std::vector<AtkObject*> watched;

  bool owns(AtkObject* object) {
    Current current(object);
    return current.host == host || std::find(watched.begin(), watched.end(), object) != watched.end();
  }
  explicit PublicationTrace(BusyDataAccessibilityHost* host) : host(host) {
    for (const auto& entry : host->data->objects) watched.push_back(ATK_OBJECT(g_object_ref(entry.second)));
    guint signal = g_signal_lookup("children-changed", ATK_TYPE_OBJECT);
    hooks.emplace_back(signal, g_signal_add_emission_hook(signal, 0,
        +[](GSignalInvocationHint* hint, guint count, const GValue* values, gpointer data) -> gboolean {
          auto* trace = static_cast<PublicationTrace*>(data);
          if (count != 3) return TRUE;
          auto* object = ATK_OBJECT(g_value_get_object(&values[0]));
          if (trace->owns(object)) trace->events.push_back({
              hint->detail == g_quark_from_static_string("add") ? 'a' : 'r', object,
              ATK_OBJECT(g_value_get_pointer(&values[2])), false});
          return TRUE;
        }, this, nullptr));
    signal = g_signal_lookup("state-change", ATK_TYPE_OBJECT);
    hooks.emplace_back(signal, g_signal_add_emission_hook(signal, 0,
        +[](GSignalInvocationHint*, guint count, const GValue* values, gpointer data) -> gboolean {
          auto* trace = static_cast<PublicationTrace*>(data);
          if (count != 3 || !g_str_equal(g_value_get_string(&values[1]), "focused")) return TRUE;
          auto* object = ATK_OBJECT(g_value_get_object(&values[0]));
          if (trace->owns(object)) trace->events.push_back({'s', object, nullptr, !!g_value_get_boolean(&values[2])});
          return TRUE;
        }, this, nullptr));
    signal = g_signal_lookup("focus-event", ATK_TYPE_OBJECT);
    hooks.emplace_back(signal, g_signal_add_emission_hook(signal, 0,
        +[](GSignalInvocationHint*, guint count, const GValue* values, gpointer data) -> gboolean {
          auto* trace = static_cast<PublicationTrace*>(data);
          if (count != 2) return TRUE;
          auto* object = ATK_OBJECT(g_value_get_object(&values[0]));
          if (trace->owns(object)) trace->events.push_back({'f', object, nullptr, !!g_value_get_boolean(&values[1])});
          return TRUE;
        }, this, nullptr));
    for (const auto& hook : hooks) g_assert_cmpuint(hook.second, !=, 0);
  }
  ~PublicationTrace() {
    for (const auto& hook : hooks) g_signal_remove_emission_hook(hook.first, hook.second);
    for (auto* object : watched) {
      g_signal_handlers_disconnect_by_data(object, this);
      g_object_unref(object);
    }
  }
  void watch_name(AtkObject* object) {
    g_signal_connect(object, "notify::accessible-name", G_CALLBACK(+[](GObject* object, GParamSpec*, gpointer data) {
      static_cast<PublicationTrace*>(data)->events.push_back({'p', ATK_OBJECT(object), nullptr, false});
    }), this);
  }
  size_t unique(char kind, AtkObject* object, bool focused = false, AtkObject* child = nullptr) const {
    size_t result = events.size(), count = 0;
    for (size_t i = 0; i < events.size(); ++i) {
      const auto& event = events[i];
      if (event.kind == kind && event.object == object && event.focused == focused && event.child == child) {
        result = i; ++count;
      }
    }
    if (count != 1) {
      g_test_message("Expected event %c object=%p child=%p focused=%d", kind, object, child, focused);
      for (size_t i = 0; i < events.size(); ++i)
        g_test_message("Observed event %zu: %c object=%p child=%p focused=%d", i,
            events[i].kind, events[i].object, events[i].child, events[i].focused);
    }
    g_assert_cmpuint(count, ==, 1);
    return result;
  }
  size_t focus_events() const {
    return std::count_if(events.begin(), events.end(), [](const Event& event) { return event.kind == 's' || event.kind == 'f'; });
  }
};

void topology_and_properties_precede_focus_across_id_layouts() {
  const int64_t layouts[][4] = {{1, 2, 3, 4}, {97, 5, 53, 2}, {11, 73, 8, 29}, {65, 17, 257, 9}};
  for (const auto& ids : layouts) {
    for (bool reverse : {false, true}) {
      ComponentHost fixture;
      g_autoptr(FlValue) before = fixture_payload();
      map_int(before, "rootId", ids[0]);
      FlValue* nodes = fl_value_new_list();
      FlValue* root = fixture_node(ids[0], -1); children(root, {ids[1], ids[2]});
      FlValue* old_field = fixture_node(ids[1], ids[0], true);
      fl_value_set_string_take(fl_value_lookup_string(old_field, "flags"), "focused", fl_value_new_bool(true));
      FlValue* parent = fixture_node(ids[2], ids[0]);
      put_string(parent, "role", "tabPanel");  // Keep the same container interface when its first child appears.
      if (reverse) { fl_value_append_take(nodes, parent); fl_value_append_take(nodes, old_field); fl_value_append_take(nodes, root); }
      else { fl_value_append_take(nodes, root); fl_value_append_take(nodes, old_field); fl_value_append_take(nodes, parent); }
      fl_value_set_string_take(before, "nodes", nodes);
      publish_payload(fixture.host, before);
      AtkObject* old_focus = existing_object(fixture.host, ids[1]);
      AtkObject* parent_object = existing_object(fixture.host, ids[2]);
      PublicationTrace trace(fixture.host); trace.watch_name(parent_object);
      map_int(before, "revision", 2);
      children(parent, {ids[3]}); put_string(parent, "label", "Changed parent");
      fl_value_set_string_take(fl_value_lookup_string(old_field, "flags"), "focused", fl_value_new_bool(false));
      FlValue* field = fixture_node(ids[3], ids[2], true);
      fl_value_set_string_take(fl_value_lookup_string(field, "flags"), "focused", fl_value_new_bool(true));
      fl_value_append_take(nodes, field);
      publish_payload(fixture.host, before);
      AtkObject* new_focus = existing_object(fixture.host, ids[3]);
      g_assert_nonnull(new_focus);
      const auto topology = trace.unique('a', parent_object, false, new_focus);
      const auto property = trace.unique('p', parent_object);
      for (char kind : {'s', 'f'}) {
        const auto gained = trace.unique(kind, new_focus, true);
        g_assert_cmpuint(topology, <, gained);
        g_assert_cmpuint(property, <, gained);
        g_assert_cmpuint(trace.unique('s', old_focus), <, gained);
        g_assert_cmpuint(trace.unique('f', old_focus), <, gained);
      }
      trace.events.clear();
      map_int(before, "revision", 3); publish_payload(fixture.host, before);
      g_assert_cmpuint(trace.focus_events(), ==, 0);
    }
  }
}

void focused_same_id_interface_replacement_announces_new_object() {
  ComponentHost fixture;
  g_autoptr(FlValue) before = fixture_payload();
  FlValue* node = editor_node(before);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "focused", fl_value_new_bool(true));
  publish_payload(fixture.host, before);
  g_autoptr(AtkObject) original = ATK_OBJECT(g_object_ref(fixture.editor()));
  AtkObject* parent = existing_object(fixture.host, 1);
  PublicationTrace trace(fixture.host);
  map_int(before, "revision", 2);
  put_string(node, "value", ""); map_int(node, "selectionBase", -1); map_int(node, "selectionExtent", -1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "textField", fl_value_new_bool(false));
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "button", fl_value_new_bool(true));
  FlValue* actions = fl_value_new_list(); fl_value_append_take(actions, fl_value_new_string("tap"));
  fl_value_set_string_take(node, "actions", actions);
  publish_payload(fixture.host, before);
  AtkObject* replacement = fixture.editor();
  g_assert_true(replacement != original);
  g_autoptr(AtkStateSet) old_states = atk_object_ref_state_set(original);
  g_assert_true(atk_state_set_contains_state(old_states, ATK_STATE_DEFUNCT));
  const auto topology = trace.unique('a', parent, false, replacement);
  for (char kind : {'s', 'f'}) {
    const auto gained = trace.unique(kind, replacement, true);
    g_assert_cmpuint(topology, <, gained);
    g_assert_cmpuint(trace.unique('s', original), <, gained);
    g_assert_cmpuint(trace.unique('f', original), <, gained);
  }
  trace.events.clear();
  map_int(before, "revision", 3); publish_payload(fixture.host, before);
  g_assert_cmpuint(trace.focus_events(), ==, 0);
}

void superseded_or_disposed_publication_never_emits_late_focus_gain() {
  for (bool dispose : {false, true}) {
    ComponentHost fixture;
    g_autoptr(GObject) keep_host = G_OBJECT(g_object_ref(fixture.host));
    PublicationTrace trace(fixture.host);
    g_autoptr(AtkObject) root = ATK_OBJECT(g_object_ref(gtk_widget_get_accessible(GTK_WIDGET(fixture.host))));
    struct Reentry { BusyDataAccessibilityHost* host; bool dispose; bool armed = true; } reentry{fixture.host, dispose};
    const gulong handler = g_signal_connect(root, "visible-data-changed", G_CALLBACK(+[](AtkObject*, gpointer data) {
      auto* reentry = static_cast<Reentry*>(data);
      if (!reentry->armed) return;
      reentry->armed = false;
      if (reentry->dispose) {
        g_object_run_dispose(G_OBJECT(reentry->host));
      } else {
        auto newer = std::make_shared<Snapshot>(*reentry->host->data->snapshot);
        ++newer->revision;
        for (auto& entry : newer->nodes) entry.second.flags[flag_index("focused")] = 0;
        publish(reentry->host, std::move(newer));
      }
    }), &reentry);
    g_autoptr(FlValue) next = fixture_payload(); map_int(next, "revision", 2);
    fl_value_set_string_take(fl_value_lookup_string(editor_node(next), "flags"), "focused", fl_value_new_bool(true));
    publish_payload(fixture.host, next);
    g_assert_false(reentry.armed);
    for (const auto& event : trace.events)
      if (event.kind == 's' || event.kind == 'f') g_assert_false(event.focused);
    if (dispose) g_assert_true(fixture.host->data->disposed);
    else {
      g_assert_cmpint(fixture.host->data->snapshot->revision, ==, 3);
      g_autoptr(AtkStateSet) states = atk_object_ref_state_set(fixture.editor());
      g_assert_false(atk_state_set_contains_state(states, ATK_STATE_FOCUSED));
    }
    g_signal_handler_disconnect(root, handler);
  }
}

void replaced_object_is_unavailable_inside_topology_callbacks() {
  ActionHost fixture;
  g_autoptr(AtkObject) original = ATK_OBJECT(g_object_ref(fixture.component.editor()));
  AtkObject* parent = existing_object(fixture.component.host, 1);
  struct Observation { AtkObject* original; ActionHost* fixture; int calls = 0; } observed{original, &fixture};
  const gulong handler = g_signal_connect(parent, "children-changed", G_CALLBACK(+[](AtkObject*, guint, gpointer, gpointer data) {
    auto* observed = static_cast<Observation*>(data);
    ++observed->calls;
    g_assert_true(observed->fixture->component.editor() != observed->original);
    g_assert_cmpint(atk_object_get_role(observed->original), ==, ATK_ROLE_INVALID);
    g_assert_null(atk_object_get_parent(observed->original));
    g_autoptr(AtkStateSet) states = atk_object_ref_state_set(observed->original);
    g_assert_true(atk_state_set_contains_state(states, ATK_STATE_DEFUNCT));
    g_assert_null(atk_text_get_text(ATK_TEXT(observed->original), 0, -1));
    g_assert_cmpint(atk_action_get_n_actions(ATK_ACTION(observed->original)), ==, 0);
    g_assert_false(atk_action_do_action(ATK_ACTION(observed->original), 0));
    atk_editable_text_set_text_contents(ATK_EDITABLE_TEXT(observed->original), "Must not reach the replacement");
    g_assert_cmpuint(observed->fixture->messenger->data->sent, ==, 0);
  }), &observed);
  g_autoptr(FlValue) next = fixture_payload(); map_int(next, "revision", 2);
  FlValue* node = editor_node(next);
  put_string(node, "label", "Replacement button"); put_string(node, "value", "");
  map_int(node, "selectionBase", -1); map_int(node, "selectionExtent", -1);
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "textField", fl_value_new_bool(false));
  fl_value_set_string_take(fl_value_lookup_string(node, "flags"), "button", fl_value_new_bool(true));
  FlValue* actions = fl_value_new_list(); fl_value_append_take(actions, fl_value_new_string("tap"));
  fl_value_set_string_take(node, "actions", actions);
  publish_payload(fixture.component.host, next);
  g_assert_cmpint(observed.calls, ==, 2);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 0);
  g_assert_cmpint(atk_object_get_role(fixture.component.editor()), ==, ATK_ROLE_PUSH_BUTTON);
  g_signal_handler_disconnect(parent, handler);
}

struct CloseHost {
  struct WindowPin {
    GtkWidget* value = nullptr;
    ~WindowPin() { if (value != nullptr) g_object_unref(value); }
  } window_pin;
  ComponentHost component;
  GApplication* application;
  BusyDataTestAccessibilityMessenger* messenger;
  BusyDataWindowClose* close;
  CloseHost() {
    window_pin.value = GTK_WIDGET(g_object_ref(component.window));
    application = g_application_new(nullptr, G_APPLICATION_NON_UNIQUE);
    g_autoptr(GError) error = nullptr;
    g_assert_true(g_application_register(application, nullptr, &error));
    g_assert_no_error(error);
    g_signal_connect(application, "activate", G_CALLBACK(+[](GApplication*, gpointer) {}), nullptr);
    g_application_hold(application);
    messenger = reinterpret_cast<BusyDataTestAccessibilityMessenger*>(g_object_new(test_messenger_get_type(), nullptr));
    close = busydata_window_close_new(application, GTK_WINDOW(component.window), FL_BINARY_MESSENGER(messenger));
    g_assert_nonnull(close);
    g_assert_cmpuint(messenger->data->handler_sets, ==, 0);
  }
  ~CloseHost() {
    g_clear_object(&close);
    while (!messenger->data->pending.empty()) finish_bytes(nullptr, true);
    g_assert_cmpuint(messenger->data->handler_sets, ==, 0);
    g_object_unref(messenger);
    g_application_release(application);
    g_object_unref(application);
  }
  void finish_bytes(GBytes* response, bool error = false) {
    g_assert_cmpuint(messenger->data->pending.size(), ==, 1);
    auto message = messenger->data->pending.back(); messenger->data->pending.pop_back();
    if (error) g_task_return_new_error(message.task, G_IO_ERROR, G_IO_ERROR_FAILED, "Owned close fixture failure");
    else g_task_return_pointer(message.task, response == nullptr ? nullptr : g_bytes_ref(response), +[](gpointer value) { if (value != nullptr) g_bytes_unref(static_cast<GBytes*>(value)); });
    g_object_unref(message.task); fl_value_unref(message.arguments);
    drain_callbacks();
  }
  void finish(const char* status) {
    g_autoptr(FlValue) result = fl_value_new_map(); put_string(result, "response", status);
    g_autoptr(FlJsonMethodCodec) codec = fl_json_method_codec_new();
    g_autoptr(GBytes) response = FL_METHOD_CODEC_GET_CLASS(codec)->encode_success_envelope(FL_METHOD_CODEC(codec), result, nullptr);
    finish_bytes(response);
  }
};

void window_close_cancel_coalesces_without_replacing_platform_handler() {
  CloseHost fixture;
  for (int i = 0; i < 64; ++i) busydata_window_close_request(fixture.close);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  g_assert_cmpuint(fixture.messenger->data->pending.size(), ==, 1);
  fixture.finish("cancel");
  g_assert_false(fixture.close->state->closed);
  g_assert_null(fixture.close->state->pending);
  busydata_window_close_request(fixture.close);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 2);
  fixture.finish("cancel");
}

void window_close_current_approval_quits_the_owned_application_once() {
  CloseHost fixture;
  struct Observation { CloseHost* fixture; bool reply = false; bool timed_out = false; int shutdowns = 0; } observed{&fixture};
  g_signal_connect(fixture.application, "shutdown", G_CALLBACK(+[](GApplication*, gpointer data) {
    ++static_cast<Observation*>(data)->shutdowns;
  }), &observed);
  busydata_window_close_request(fixture.close);
  g_idle_add(+[](gpointer data) -> gboolean {
    auto* observed = static_cast<Observation*>(data);
    observed->reply = true; observed->fixture->finish("exit");
    return G_SOURCE_REMOVE;
  }, &observed);
  const guint deadline = g_timeout_add(3000, +[](gpointer data) -> gboolean {
    auto* observed = static_cast<Observation*>(data);
    observed->timed_out = true; g_application_quit(observed->fixture->application);
    return G_SOURCE_REMOVE;
  }, &observed);
  g_assert_cmpint(g_application_run(fixture.application, 0, nullptr), ==, 0);
  if (!observed.timed_out) g_source_remove(deadline);
  g_assert_true(observed.reply); g_assert_false(observed.timed_out);
  g_assert_cmpint(observed.shutdowns, ==, 1);
  g_assert_true(fixture.close->state->closed);
  busydata_window_close_request(fixture.close);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  g_signal_handlers_disconnect_by_data(fixture.application, &observed);
}

void window_close_invalid_reply_and_transport_error_stay_open() {
  const char* invalid[] = {"", "[]", "[null]", "[true]", "[{\"response\":false}]", "[{\"response\":\"other\"}]",
      "[{\"response\":\"exit\",\"extra\":1}]", "[{\"response\":\"exit\\u0000suffix\"}]", "[\"error\",\"failure\",null]"};
  CloseHost fixture;
  for (const char* text : invalid) {
    busydata_window_close_request(fixture.close);
    g_autoptr(GBytes) bytes = g_bytes_new(text, strlen(text));
    fixture.finish_bytes(bytes);
    g_assert_false(fixture.close->state->closed);
    g_assert_null(fixture.close->state->pending);
  }
  busydata_window_close_request(fixture.close); fixture.finish_bytes(nullptr);
  g_assert_false(fixture.close->state->closed);
  busydata_window_close_request(fixture.close); fixture.finish_bytes(nullptr, true);
  g_assert_false(fixture.close->state->closed);
  std::string oversized(kCloseReplyMaxBytes + 1, ' ');
  busydata_window_close_request(fixture.close);
  g_autoptr(GBytes) bytes = g_bytes_new(oversized.data(), oversized.size()); fixture.finish_bytes(bytes);
  g_assert_false(fixture.close->state->closed);
}

void window_close_cancelled_generation_cannot_approve_or_overlap() {
  CloseHost fixture;
  busydata_window_close_request(fixture.close);
  busydata_window_close_cancel(fixture.close);
  busydata_window_close_request(fixture.close);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 1);
  g_assert_true(g_cancellable_is_cancelled(fixture.close->state->pending->cancellable));
  fixture.finish("exit");
  g_assert_false(fixture.close->state->closed);
  busydata_window_close_request(fixture.close);
  g_assert_cmpuint(fixture.messenger->data->sent, ==, 2);
  fixture.finish("cancel");
}

void window_close_destroyed_or_replaced_window_cannot_approve() {
  for (bool destroy : {false, true}) {
    CloseHost fixture;
    busydata_window_close_request(fixture.close);
    g_autoptr(GObject) replacement = nullptr;
    if (destroy) gtk_widget_destroy(fixture.component.window);
    else {
      replacement = G_OBJECT(g_object_ref_sink(gtk_window_new(GTK_WINDOW_TOPLEVEL)));
      g_weak_ref_set(&fixture.close->state->window, replacement);
    }
    fixture.finish("exit");
    if (destroy) g_assert_true(fixture.close->state->closed);
    else g_assert_false(fixture.close->state->closed);
    g_assert_null(fixture.close->state->pending);
    if (replacement != nullptr) gtk_widget_destroy(GTK_WIDGET(replacement));
  }
}

void window_close_disposal_releases_owner_before_late_reply() {
  CloseHost fixture;
  busydata_window_close_request(fixture.close);
  bool finalized = false;
  g_object_weak_ref(G_OBJECT(fixture.close), +[](gpointer data, GObject*) { *static_cast<bool*>(data) = true; }, &finalized);
  g_clear_object(&fixture.close);
  g_assert_true(finalized);
  g_assert_true(g_cancellable_is_cancelled(g_task_get_cancellable(fixture.messenger->data->pending[0].task)));
  fixture.finish("exit");
  g_assert_cmpuint(fixture.messenger->data->pending.size(), ==, 0);
}

}  // namespace

int main(int argc, char** argv) {
  g_test_init(&argc, &argv, nullptr);
  if (!gtk_init_check(&argc, &argv)) {
    g_printerr("A real GTK display is required for component geometry\n");
    return 1;
  }
  g_test_add_func("/bridge/unicode-boundaries", unicode_boundaries);
  g_test_add_func("/bridge/malformed-topology", malformed_topology);
  g_test_add_func("/bridge/malformed-text-flags", malformed_text_and_flags);
  g_test_add_func("/bridge/bounded-topology", bounded_topology);
  g_test_add_func("/bridge/exact-text-selection", exact_text_and_selection);
  g_test_add_func("/bridge/current-nodes-release-old-snapshot", retained_nodes_release_old_snapshot);
  g_test_add_func("/bridge/owner-replacement-defunct", owner_replacement_defuncts_old_id);
  g_test_add_func("/bridge/unavailable-retires", unavailable_retires_presentation);
  g_test_add_func("/bridge/roles-readonly-copy", roles_states_and_readonly_copy);
  g_test_add_func("/bridge/exact-glyph-coordinates", exact_glyph_range_and_coordinates);
  g_test_add_func("/bridge/no-field-glyph-substitution", missing_glyphs_are_not_field_bounds);
  g_test_add_func("/bridge/invalid-glyph-boundaries", invalid_glyph_boundaries);
  g_test_add_func("/bridge/protected-text-masked-showing", protected_text_must_be_masked_and_showing);
  g_test_add_func("/bridge/owned-root-hit-testing", owned_root_hit_testing);
  g_test_add_func("/bridge/tree-false-not-unknown", tree_false_is_not_unknown);
  g_test_add_func("/bridge/bounded-codec-lossless", bounded_codec_rejects_lossy_nul_wire);
  g_test_add_func("/bridge/exact-double-allocation", exact_two_times_allocation_mapping);
  g_test_add_func("/bridge/current-property-notifications", reused_objects_notify_current_properties);
  g_test_add_func("/bridge/action-outcome-private-dispatch-only", action_outcome_ok_is_not_an_edit);
  g_test_add_func("/bridge/hidden-component-reveal-before-focus", hidden_component_reveals_without_focus_or_edge_placement);
  g_test_add_func("/bridge/component-reveal-current-capability", component_reveal_requires_current_node_and_capability);
  g_test_add_func("/bridge/component-reveal-stable-action-indices", component_reveal_does_not_change_ordinary_action_indices);
  g_test_add_func("/bridge/component-reveal-declined-no-replay", declined_component_reveal_does_not_replay_or_focus);
  g_test_add_func("/bridge/action-stale-owner-fence", action_stale_and_foreign_owner_never_acknowledge_ok);
  g_test_add_func("/bridge/action-malformed-transport-status", action_malformed_and_transport_failures_are_controlled);
  g_test_add_func("/bridge/action-order-no-overwrite", older_action_reply_does_not_replace_newer_outcome);
  g_test_add_func("/bridge/action-timeout-no-replay", action_timeout_and_late_reply_do_not_replay);
  g_test_add_func("/bridge/action-admission-disposal", action_admission_and_disposal_remain_bounded);
  g_test_add_func("/bridge/official-entry-readonly-stable-interfaces", official_gtk_entry_keeps_interfaces_when_readonly);
  g_test_add_func("/bridge/composition-keeps-textfield-identity", textfield_interfaces_survive_composition_callback_changes);
  g_test_add_func("/bridge/actual-role-change-retires-control", actual_textfield_role_change_retires_old_control);
  g_test_add_func("/bridge/focus-before-caret-and-selection", focus_gain_precedes_caret_and_selection_on_an_existing_field);
  g_test_add_func("/bridge/superseded-focus-no-pending-text-events", superseded_focus_gain_never_emits_its_pending_text_notifications);
  g_test_add_func("/bridge/initial-focus-complete-ancestry", newly_published_focus_notifies_with_complete_ancestry);
  g_test_add_func("/bridge/topology-properties-before-focus", topology_and_properties_precede_focus_across_id_layouts);
  g_test_add_func("/bridge/focused-same-id-replacement", focused_same_id_interface_replacement_announces_new_object);
  g_test_add_func("/bridge/reentrant-publication-no-late-focus", superseded_or_disposed_publication_never_emits_late_focus_gain);
  g_test_add_func("/bridge/replaced-object-unavailable-during-topology", replaced_object_is_unavailable_inside_topology_callbacks);
  g_test_add_func("/window-close/cancel-coalesce-handler-preserved", window_close_cancel_coalesces_without_replacing_platform_handler);
  g_test_add_func("/window-close/current-approval-quits-once", window_close_current_approval_quits_the_owned_application_once);
  g_test_add_func("/window-close/invalid-transport-remains-open", window_close_invalid_reply_and_transport_error_stay_open);
  g_test_add_func("/window-close/cancelled-generation-no-overlap", window_close_cancelled_generation_cannot_approve_or_overlap);
  g_test_add_func("/window-close/destroyed-replaced-window-no-approval", window_close_destroyed_or_replaced_window_cannot_approve);
  g_test_add_func("/window-close/dispose-before-late-reply", window_close_disposal_releases_owner_before_late_reply);
  return g_test_run();
}
