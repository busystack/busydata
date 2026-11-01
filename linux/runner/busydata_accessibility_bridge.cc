#include "busydata_accessibility_bridge.h"

#include <gtk/gtk-a11y.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

// These limits bound the presentation retained by this application adapter.
// Engine objects, engine classes and their ATK interfaces remain untouched.
constexpr size_t kMaxNodes = 16384;
constexpr size_t kMaxTextUnits = 1048576;
constexpr size_t kMaxDepth = 128;
constexpr size_t kMaxPendingActions = 32;
constexpr size_t kMaxBytes = 8 * 1024 * 1024;
constexpr size_t kMaxModelBytes = 32 * 1024 * 1024;
constexpr size_t kMaxTextBytes = 4 * kMaxTextUnits;
constexpr size_t kMaxActions = 32;
constexpr char kChannel[] = "io.busystack.busydata/accessibility";

struct Rect {
  double x = 0, y = 0, width = 0, height = 0;
};
struct TextBox { int start, end; Rect rect; };

struct Node {
  int64_t id = 0, parent = -1;
  std::vector<int64_t> children;
  std::string identifier, label, value, hint, tooltip, role, direction;
  std::vector<std::string> actions;
  std::array<int8_t, 17> flags = {{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}};
  std::string text_status, geometry_precision;
  int selection_base = -1, selection_extent = -1, level = 0;
  Rect rect;
  std::vector<TextBox> text_boxes;
  int geometry_start = -1, geometry_end = -1;
};

struct Snapshot {
  int64_t bridge_epoch = 0, owner_epoch = 0, view_id = 0, revision = 0;
  int64_t root = -1;
  bool available = false;
  std::string status, reason;
  double view_width = 0, view_height = 0;
  std::unordered_map<int64_t, Node> nodes;
};

struct BusyDataAccessibilityHost;
struct BusyDataAccessibilityHostClass;
struct BusyDataAccessibilityRoot;
struct BusyDataAccessibilityRootClass;
struct BusyDataAccessibilityNode;
struct BusyDataAccessibilityNodeClass;
struct BusyDataAccessibilityCodec;
struct BusyDataAccessibilityCodecClass;
struct BusyDataAccessibilityTextNode;
struct BusyDataAccessibilityTextNodeClass;
struct BusyDataAccessibilityEditableNode;
struct BusyDataAccessibilityEditableNodeClass;

GType host_get_type();
GType accessible_get_type();
GType accessible_node_get_type();
GType bounded_codec_get_type();
GType text_node_get_type();
GType editable_node_get_type();

struct NodeOwner {
  GWeakRef host;
  int64_t id, bridge_epoch, owner_epoch;
  bool defunct = false;
};

struct ActionOutcome {
  uint64_t sequence = 0;
  int64_t node_id = -1, bridge_epoch = 0, owner_epoch = 0, view_id = -1;
  int64_t request_revision = 0, reply_revision = 0;
  std::string name;  // Only a validated fixed protocol action name.
  const char* status = "none";
};

struct HostData {
  GtkWidget* view = nullptr;  // The FlView widget, owned by GtkBin.
  FlMethodChannel* channel = nullptr;
  std::shared_ptr<const Snapshot> snapshot;
  std::unordered_map<int64_t, AtkObject*> objects;
  bool disposed = false;
  int64_t bridge_epoch = 0, view_id = -1;
  uint64_t next_action = 0;
  std::unordered_map<uint64_t, std::pair<GCancellable*, guint>> pending;
  ActionOutcome action;
  uint64_t action_replies = 0, action_stale = 0, action_timeouts = 0;
};

struct BusyDataAccessibilityHost { GtkBin parent_instance; HostData* data; };
struct BusyDataAccessibilityHostClass { GtkBinClass parent_class; };
struct BusyDataAccessibilityRoot { GtkContainerAccessible parent_instance; };
struct BusyDataAccessibilityRootClass { GtkContainerAccessibleClass parent_class; };
struct BusyDataAccessibilityNode { AtkObject parent_instance; NodeOwner* owner; };
struct BusyDataAccessibilityNodeClass { AtkObjectClass parent_class; };
struct BusyDataAccessibilityCodec { FlMethodCodec parent_instance; FlStandardMethodCodec* delegate; };
struct BusyDataAccessibilityCodecClass { FlMethodCodecClass parent_class; };
struct BusyDataAccessibilityTextNode { BusyDataAccessibilityNode parent_instance; };
struct BusyDataAccessibilityTextNodeClass { BusyDataAccessibilityNodeClass parent_class; };
struct BusyDataAccessibilityEditableNode { BusyDataAccessibilityTextNode parent_instance; };
struct BusyDataAccessibilityEditableNodeClass { BusyDataAccessibilityTextNodeClass parent_class; };

void node_component_init(AtkComponentIface* iface);
void node_action_init(AtkActionIface* iface);
void node_text_init(AtkTextIface* iface);
void node_editable_init(AtkEditableTextIface* iface);
void node_selection_init(AtkSelectionIface* iface);
void root_component_init(AtkComponentIface* iface);

G_DEFINE_TYPE(BusyDataAccessibilityHost, host, GTK_TYPE_BIN)
G_DEFINE_TYPE_WITH_CODE(BusyDataAccessibilityRoot, accessible, GTK_TYPE_CONTAINER_ACCESSIBLE,
    G_IMPLEMENT_INTERFACE(ATK_TYPE_COMPONENT, root_component_init))
G_DEFINE_TYPE(BusyDataAccessibilityCodec, bounded_codec, fl_method_codec_get_type())
G_DEFINE_TYPE_WITH_CODE(BusyDataAccessibilityNode, accessible_node, ATK_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(ATK_TYPE_COMPONENT, node_component_init)
    G_IMPLEMENT_INTERFACE(ATK_TYPE_ACTION, node_action_init)
    G_IMPLEMENT_INTERFACE(ATK_TYPE_SELECTION, node_selection_init))
G_DEFINE_TYPE_WITH_CODE(BusyDataAccessibilityTextNode, text_node, accessible_node_get_type(),
    G_IMPLEMENT_INTERFACE(ATK_TYPE_TEXT, node_text_init))
G_DEFINE_TYPE_WITH_CODE(BusyDataAccessibilityEditableNode, editable_node, text_node_get_type(),
    G_IMPLEMENT_INTERFACE(ATK_TYPE_EDITABLE_TEXT, node_editable_init))

void text_node_class_init(BusyDataAccessibilityTextNodeClass*) {}
void text_node_init(BusyDataAccessibilityTextNode*) {}
void editable_node_class_init(BusyDataAccessibilityEditableNodeClass*) {}
void editable_node_init(BusyDataAccessibilityEditableNode*) {}

bool wire_size(GBytes* bytes, GError** error) {
  if (bytes != nullptr && g_bytes_get_size(bytes) <= kMaxBytes) return true;
  g_set_error_literal(error, g_quark_from_static_string("busydata-accessibility-codec"), 1,
                      "Accessibility message exceeds its bound");
  return false;
}

GBytes* bounded_encoded(GBytes* bytes, GError** error) {
  if (bytes == nullptr || wire_size(bytes, error)) return bytes;
  g_bytes_unref(bytes);
  return nullptr;
}

bool lossless_standard_bytes(GBytes* received, GBytes* encoded, GError** error) {
  if (encoded != nullptr && g_bytes_equal(received, encoded)) return true;
  if (error == nullptr || *error == nullptr)
    g_set_error_literal(error, g_quark_from_static_string("busydata-accessibility-codec"), 2,
                        "Accessibility message is not a lossless canonical standard message");
  return false;
}

void bounded_codec_finalize(GObject* object) {
  auto* self = reinterpret_cast<BusyDataAccessibilityCodec*>(object);
  g_clear_object(&self->delegate);
  G_OBJECT_CLASS(bounded_codec_parent_class)->finalize(object);
}

void bounded_codec_class_init(BusyDataAccessibilityCodecClass* klass) {
  // FlMethodCodec is an officially derivable application extension. Each
  // documented operation delegates unchanged to the official standard codec;
  // only this owned class adds the wire admission before decoding.
  auto* codec = FL_METHOD_CODEC_CLASS(klass);
  codec->encode_method_call = [](FlMethodCodec* base, const gchar* name, FlValue* args, GError** error) {
    auto* delegate = FL_METHOD_CODEC(reinterpret_cast<BusyDataAccessibilityCodec*>(base)->delegate);
    return bounded_encoded(FL_METHOD_CODEC_GET_CLASS(delegate)->encode_method_call(delegate, name, args, error), error);
  };
  codec->decode_method_call = [](FlMethodCodec* base, GBytes* bytes, gchar** name, FlValue** args, GError** error) -> gboolean {
    if (!wire_size(bytes, error)) return FALSE;
    auto* delegate = FL_METHOD_CODEC(reinterpret_cast<BusyDataAccessibilityCodec*>(base)->delegate);
    g_autofree gchar* decoded_name = nullptr;
    g_autoptr(FlValue) decoded_args = nullptr;
    auto* standard = FL_METHOD_CODEC_GET_CLASS(delegate);
    if (!standard->decode_method_call(delegate, bytes, &decoded_name, &decoded_args, error)) return FALSE;
    // The public Linux FlValue string API is C-string based. Reject a lossy
    // decode (including embedded NUL) before any application parser sees it.
    // This uses only the official codec, not a copy of its wire decoder.
    g_autoptr(GBytes) encoded = standard->encode_method_call(delegate, decoded_name, decoded_args, error);
    if (!lossless_standard_bytes(bytes, encoded, error)) return FALSE;
    if (name != nullptr) *name = g_steal_pointer(&decoded_name);
    if (args != nullptr) *args = g_steal_pointer(&decoded_args);
    return TRUE;
  };
  codec->encode_success_envelope = [](FlMethodCodec* base, FlValue* result, GError** error) {
    auto* delegate = FL_METHOD_CODEC(reinterpret_cast<BusyDataAccessibilityCodec*>(base)->delegate);
    return bounded_encoded(FL_METHOD_CODEC_GET_CLASS(delegate)->encode_success_envelope(delegate, result, error), error);
  };
  codec->encode_error_envelope = [](FlMethodCodec* base, const gchar* code, const gchar* message, FlValue* details, GError** error) {
    auto* delegate = FL_METHOD_CODEC(reinterpret_cast<BusyDataAccessibilityCodec*>(base)->delegate);
    return bounded_encoded(FL_METHOD_CODEC_GET_CLASS(delegate)->encode_error_envelope(delegate, code, message, details, error), error);
  };
  codec->decode_response = [](FlMethodCodec* base, GBytes* bytes, GError** error) -> FlMethodResponse* {
    if (!wire_size(bytes, error)) return nullptr;
    auto* delegate = FL_METHOD_CODEC(reinterpret_cast<BusyDataAccessibilityCodec*>(base)->delegate);
    auto* standard = FL_METHOD_CODEC_GET_CLASS(delegate);
    g_autoptr(FlMethodResponse) response = standard->decode_response(delegate, bytes, error);
    if (response == nullptr) return nullptr;
    g_autoptr(GBytes) encoded = nullptr;
    if (FL_IS_METHOD_SUCCESS_RESPONSE(response)) {
      encoded = standard->encode_success_envelope(delegate,
          fl_method_success_response_get_result(FL_METHOD_SUCCESS_RESPONSE(response)), error);
    } else if (FL_IS_METHOD_ERROR_RESPONSE(response)) {
      auto* failure = FL_METHOD_ERROR_RESPONSE(response);
      encoded = standard->encode_error_envelope(delegate, fl_method_error_response_get_code(failure),
          fl_method_error_response_get_message(failure), fl_method_error_response_get_details(failure), error);
    } else if (FL_IS_METHOD_NOT_IMPLEMENTED_RESPONSE(response)) {
      encoded = g_bytes_new_static("", 0);
    }
    if (!lossless_standard_bytes(bytes, encoded, error)) return nullptr;
    return FL_METHOD_RESPONSE(g_steal_pointer(&response));
  };
  G_OBJECT_CLASS(klass)->finalize = bounded_codec_finalize;
}

void bounded_codec_init(BusyDataAccessibilityCodec* self) { self->delegate = fl_standard_method_codec_new(); }

bool is_host(gpointer object) {
  return object != nullptr && G_TYPE_CHECK_INSTANCE_TYPE(object, host_get_type());
}

BusyDataAccessibilityHost* host_of(AtkObject* object) {
  if (G_TYPE_CHECK_INSTANCE_TYPE(object, accessible_get_type())) {
    GtkWidget* widget = gtk_accessible_get_widget(GTK_ACCESSIBLE(object));
    return is_host(widget) ? static_cast<BusyDataAccessibilityHost*>(reinterpret_cast<void*>(widget)) : nullptr;
  }
  return nullptr;
}

struct Current {
  BusyDataAccessibilityHost* host = nullptr;
  std::shared_ptr<const Snapshot> snapshot;
  const Node* node = nullptr;
  explicit Current(AtkObject* object) {
    if (!G_TYPE_CHECK_INSTANCE_TYPE(object, accessible_node_get_type())) return;
    auto* owned = reinterpret_cast<BusyDataAccessibilityNode*>(object)->owner;
    if (owned == nullptr || owned->defunct) return;
    host = reinterpret_cast<BusyDataAccessibilityHost*>(g_weak_ref_get(&owned->host));
    if (host == nullptr || host->data == nullptr || host->data->disposed) return;
    auto member = host->data->objects.find(owned->id);
    if (member == host->data->objects.end() || member->second != object) return;
    snapshot = host->data->snapshot;
    if (!snapshot || !snapshot->available ||
        snapshot->bridge_epoch != owned->bridge_epoch ||
        snapshot->owner_epoch != owned->owner_epoch) return;
    auto found = snapshot->nodes.find(owned->id);
    if (found != snapshot->nodes.end()) node = &found->second;
  }
  ~Current() { if (host != nullptr) g_object_unref(host); }
  Current(const Current&) = delete;
  Current& operator=(const Current&) = delete;
};

int flag_index(const char* name) {
  static constexpr const char* names[] = {"enabled", "focusable", "focused", "selected", "checked", "mixed", "expanded", "readOnly", "textField", "password", "multiline", "hidden", "link", "button", "liveRegion", "header", "toggled"};
  for (size_t index = 0; index < G_N_ELEMENTS(names); ++index) if (g_str_equal(name, names[index])) return static_cast<int>(index);
  return -1;
}

bool flag(const Node& node, const char* name) {
  int index = flag_index(name);
  return index >= 0 && node.flags[index] == 1;
}

bool has_action(const Node& node, const char* name) {
  return std::find(node.actions.begin(), node.actions.end(), name) != node.actions.end();
}

bool known(const Node& node, const char* name) {
  int index = flag_index(name);
  return index >= 0 && node.flags[index] >= 0;
}

bool editable_state(const Node& node) {
  return flag(node, "textField") && known(node, "readOnly") && !flag(node, "readOnly");
}

bool permits(const Node& node, const char* name) {
  if (flag(node, "readOnly") && (g_str_equal(name, "setText") || g_str_equal(name, "cut") ||
      g_str_equal(name, "paste") || g_str_equal(name, "cutRange") || g_str_equal(name, "pasteAt") ||
      g_str_equal(name, "insertText") || g_str_equal(name, "deleteRange"))) return false;
  if (node.text_status != "available" && (g_str_equal(name, "setText") || g_str_equal(name, "setSelection") ||
      g_str_equal(name, "copy") || g_str_equal(name, "cut") || g_str_equal(name, "paste") ||
      g_str_equal(name, "copyRange") || g_str_equal(name, "cutRange") || g_str_equal(name, "pasteAt") ||
      g_str_equal(name, "insertText") || g_str_equal(name, "deleteRange"))) return false;
  if (flag(node, "password") && (g_str_equal(name, "copy") || g_str_equal(name, "cut") ||
      g_str_equal(name, "copyRange") || g_str_equal(name, "cutRange"))) return false;
  if (g_str_equal(name, "copyRange")) return has_action(node, "setSelection") && has_action(node, "copy");
  if (g_str_equal(name, "cutRange")) return !flag(node, "readOnly") && has_action(node, "setSelection") && has_action(node, "cut");
  if (g_str_equal(name, "pasteAt")) return !flag(node, "readOnly") && has_action(node, "setSelection") && has_action(node, "paste");
  if (g_str_equal(name, "insertText") || g_str_equal(name, "deleteRange"))
    return !flag(node, "password") && !flag(node, "readOnly") && has_action(node, "setText") && node.text_status == "available";
  return has_action(node, name);
}

AtkObject* existing_object(BusyDataAccessibilityHost* self, int64_t id) {
  auto found = self->data->objects.find(id);
  return found == self->data->objects.end() ? nullptr : found->second;
}

AtkRole role_of(const Node& node) {
  const auto& role = node.role;
  if (node.identifier == "busydata.database.tree") return ATK_ROLE_TREE;
  if (node.level > 0) return ATK_ROLE_TREE_ITEM;
  if (flag(node, "button")) return ATK_ROLE_PUSH_BUTTON;
  if (flag(node, "link")) return ATK_ROLE_LINK;
  if (flag(node, "textField")) return flag(node, "password") ? ATK_ROLE_PASSWORD_TEXT : ATK_ROLE_ENTRY;
  if (role == "checkBox") return ATK_ROLE_CHECK_BOX;
  if (role == "radio") return ATK_ROLE_RADIO_BUTTON;
  if (role == "switch") return ATK_ROLE_TOGGLE_BUTTON;
  if (role == "slider") return ATK_ROLE_SLIDER;
  if (role == "tab") return ATK_ROLE_PAGE_TAB;
  if (role == "tabBar") return ATK_ROLE_PAGE_TAB_LIST;
  if (role == "tabPanel") return ATK_ROLE_PANEL;
  if (role == "menu") return ATK_ROLE_MENU;
  if (role == "menuBar") return ATK_ROLE_MENU_BAR;
  if (role == "menuItem") return ATK_ROLE_MENU_ITEM;
  if (role == "menuItemCheckbox") return ATK_ROLE_CHECK_MENU_ITEM;
  if (role == "menuItemRadio") return ATK_ROLE_RADIO_MENU_ITEM;
  if (role == "dialog") return ATK_ROLE_DIALOG;
  if (role == "alertDialog") return ATK_ROLE_ALERT;
  if (role == "image") return ATK_ROLE_IMAGE;
  if (role == "table") return ATK_ROLE_TABLE;
  if (role == "row") return ATK_ROLE_TABLE_ROW;
  if (role == "cell") return ATK_ROLE_TABLE_CELL;
  if (role == "columnHeader") return ATK_ROLE_COLUMN_HEADER;
  if (role == "rowHeader") return ATK_ROLE_ROW_HEADER;
  if (role == "header") return ATK_ROLE_HEADING;
  if (role == "list") return ATK_ROLE_LIST;
  if (role == "listItem") return ATK_ROLE_LIST_ITEM;
  if (role == "scrollBar") return ATK_ROLE_SCROLL_BAR;
  if (role == "status") return ATK_ROLE_STATUSBAR;
  if (role == "alert") return ATK_ROLE_ALERT;
  if (role == "spinButton") return ATK_ROLE_SPIN_BUTTON;
  if (role == "comboBox") return ATK_ROLE_COMBO_BOX;
  if (role == "form") return ATK_ROLE_FORM;
  if (role == "tooltip") return ATK_ROLE_TOOL_TIP;
  if (role == "progressBar" || role == "loadingSpinner") return ATK_ROLE_PROGRESS_BAR;
  if (role == "text") return ATK_ROLE_STATIC;
  if (flag(node, "header")) return ATK_ROLE_HEADING;
  if (known(node, "checked")) return ATK_ROLE_CHECK_BOX;
  if (known(node, "toggled")) return ATK_ROLE_TOGGLE_BUTTON;
  if (node.children.empty() && !node.label.empty()) return ATK_ROLE_STATIC;
  return ATK_ROLE_PANEL;
}

GType node_type(const Node& node) {
  // Like GtkEntryAccessible, a text field's interfaces describe the control,
  // not its momentary mutation permissions. IME/read-only callbacks may be
  // unavailable without invalidating a reader's live text/focus reference.
  if (flag(node, "textField")) return editable_node_get_type();
  AtkRole role = role_of(node);
  bool text = role == ATK_ROLE_STATIC || role == ATK_ROLE_HEADING || role == ATK_ROLE_TABLE_CELL ||
      role == ATK_ROLE_COLUMN_HEADER || role == ATK_ROLE_ROW_HEADER || role == ATK_ROLE_STATUSBAR;
  if (!text) return accessible_node_get_type();
  // GTK's EditableText interface also owns Copy. Readonly text may expose that
  // interface for a verified Copy callback while every mutation is refused.
  return has_action(node, "setText") || has_action(node, "copy") || has_action(node, "cut") || has_action(node, "paste")
      ? editable_node_get_type() : text_node_get_type();
}

// Flutter text selections use UTF-16; ATK offsets count Unicode scalars.
// Conversion is exact at scalar boundaries and rejects surrogate interiors.
int utf16_for_character(const std::string& text, int characters) {
  if (characters < 0) return -1;
  int current = 0, units = 0;
  const char* end = text.data() + text.size();
  for (const char* p = text.data(); p < end; p = g_utf8_next_char(p)) {
    if (current == characters) return units;
    units += g_utf8_get_char(p) > 0xffff ? 2 : 1;
    ++current;
  }
  return current == characters ? units : -1;
}

int character_for_utf16(const std::string& text, int units) {
  if (units < 0) return -1;
  int characters = 0, consumed = 0;
  const char* end = text.data() + text.size();
  for (const char* p = text.data(); p < end; p = g_utf8_next_char(p)) {
    if (consumed == units) return characters;
    consumed += g_utf8_get_char(p) > 0xffff ? 2 : 1;
    if (consumed > units) return -1;
    ++characters;
  }
  return consumed == units ? characters : -1;
}

const std::string& text_of(const Node& node) {
  return flag(node, "textField") ? node.value : node.label;
}

void map_int(FlValue* map, const char* key, int64_t value) {
  fl_value_set_string_take(map, key, fl_value_new_int(value));
}

struct PendingAction {
  GWeakRef host;
  uint64_t id;
  int64_t bridge_epoch, owner_epoch, view_id, revision;
  bool settled = false;
};

void increment_counter(uint64_t* value) {
  if (*value < std::numeric_limits<uint64_t>::max()) ++*value;
}

void action_state(BusyDataAccessibilityHost* host, const PendingAction& pending,
                  const char* status, int64_t reply_revision = 0) {
  if (g_str_equal(status, "stale")) increment_counter(&host->data->action_stale);
  if (host->data->action.sequence == pending.id) {
    host->data->action.status = status;
    host->data->action.reply_revision = reply_revision;
  }
  g_signal_emit_by_name(gtk_widget_get_accessible(GTK_WIDGET(host)), "visible-data-changed");
}

bool reply_number(FlValue* result, const char* name, int64_t* value, int64_t minimum) {
  FlValue* field = fl_value_lookup_string(result, name);
  if (field == nullptr || fl_value_get_type(field) != FL_VALUE_TYPE_INT) return false;
  *value = fl_value_get_int(field);
  return *value >= minimum;
}

const char* action_reply(FlMethodResponse* response, const PendingAction& pending, int64_t* revision) {
  if (response == nullptr || !FL_IS_METHOD_SUCCESS_RESPONSE(response)) return "transport-error";
  FlValue* result = fl_method_success_response_get_result(FL_METHOD_SUCCESS_RESPONSE(response));
  if (result == nullptr || fl_value_get_type(result) != FL_VALUE_TYPE_MAP || fl_value_get_length(result) != 6) return "malformed";
  const char* fields[] = {"version", "status", "bridgeEpoch", "viewId", "ownerEpoch", "revision"};
  for (size_t index = 0; index < fl_value_get_length(result); ++index) {
    FlValue* key = fl_value_get_map_key(result, index);
    if (fl_value_get_type(key) != FL_VALUE_TYPE_STRING) return "malformed";
    bool found = false;
    for (const char* name : fields) found |= g_str_equal(fl_value_get_string(key), name);
    if (!found) return "malformed";
  }
  int64_t version, bridge, view, owner;
  if (!reply_number(result, "version", &version, 1) || version != 1 ||
      !reply_number(result, "bridgeEpoch", &bridge, 0) || !reply_number(result, "viewId", &view, -1) ||
      !reply_number(result, "ownerEpoch", &owner, 0) || !reply_number(result, "revision", revision, 0)) return "malformed";
  FlValue* status = fl_value_lookup_string(result, "status");
  if (status == nullptr || fl_value_get_type(status) != FL_VALUE_TYPE_STRING) return "malformed";
  const char* known = nullptr;
  for (const char* candidate : {"ok", "stale", "malformed", "limited", "disposed", "unavailable", "cancelled"}) {
    if (g_str_equal(candidate, fl_value_get_string(status))) { known = candidate; break; }
  }
  if (known == nullptr) return "malformed";
  if (g_str_equal(known, "ok") && (bridge != pending.bridge_epoch || view != pending.view_id ||
      owner != pending.owner_epoch || *revision < pending.revision)) return "stale";
  return known;
}

gboolean action_timeout(gpointer data) {
  auto* pending = static_cast<PendingAction*>(data);
  auto* host = reinterpret_cast<BusyDataAccessibilityHost*>(g_weak_ref_get(&pending->host));
  if (host == nullptr) return G_SOURCE_REMOVE;
  auto found = host->data->pending.find(pending->id);
  if (found != host->data->pending.end()) {
    auto* cancellable = found->second.first;
    host->data->pending.erase(found);
    pending->settled = true;
    increment_counter(&host->data->action_timeouts);
    action_state(host, *pending, "cancelled");
    g_cancellable_cancel(cancellable);
    g_object_unref(cancellable);
  }
  g_object_unref(host);
  return G_SOURCE_REMOVE;
}

void action_finished(GObject* channel, GAsyncResult* result, gpointer data) {
  auto* pending = static_cast<PendingAction*>(data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(FL_METHOD_CHANNEL(channel), result, &error);
  // No edit is retried, and an acknowledgement is never reported as success
  // of the operation. Updated public semantics are the only presentation.
  auto* host = reinterpret_cast<BusyDataAccessibilityHost*>(g_weak_ref_get(&pending->host));
  if (host != nullptr) {
    auto found = host->data->pending.find(pending->id);
    if (found != host->data->pending.end()) {
      g_source_remove(found->second.second);
      g_object_unref(found->second.first);
      host->data->pending.erase(found);
    }
    if (!pending->settled && !host->data->disposed) {
      pending->settled = true;
      int64_t revision = 0;
      const char* status = error != nullptr ? "transport-error" : action_reply(response, *pending, &revision);
      if (response != nullptr && error == nullptr) increment_counter(&host->data->action_replies);
      action_state(host, *pending, status, revision);
    }
    g_object_unref(host);
  }
  g_weak_ref_clear(&pending->host);
  delete pending;
}

bool send_action(Current& current, const char* action, FlValue* arguments = nullptr) {
  if (current.node == nullptr || !permits(*current.node, action) ||
      current.host->data->channel == nullptr ||
      current.host->data->pending.size() >= kMaxPendingActions ||
      current.host->data->next_action == std::numeric_limits<uint64_t>::max()) return false;
  g_autoptr(FlValue) message = fl_value_new_map();
  map_int(message, "version", 1);
  map_int(message, "bridgeEpoch", current.snapshot->bridge_epoch);
  map_int(message, "viewId", current.snapshot->view_id);
  map_int(message, "ownerEpoch", current.snapshot->owner_epoch);
  map_int(message, "revision", current.snapshot->revision);
  map_int(message, "nodeId", current.node->id);
  fl_value_set_string_take(message, "action", fl_value_new_string(action));
  fl_value_set_string_take(message, "args", arguments == nullptr ? fl_value_new_null() : fl_value_ref(arguments));
  auto* pending = new PendingAction;
  g_weak_ref_init(&pending->host, current.host);
  pending->id = ++current.host->data->next_action;
  pending->bridge_epoch = current.snapshot->bridge_epoch;
  pending->owner_epoch = current.snapshot->owner_epoch;
  pending->view_id = current.snapshot->view_id;
  pending->revision = current.snapshot->revision;
  current.host->data->action = {pending->id, current.node->id, pending->bridge_epoch, pending->owner_epoch,
      pending->view_id, pending->revision, 0, action, "pending"};
  auto* cancellable = g_cancellable_new();
  guint timeout = g_timeout_add_full(G_PRIORITY_DEFAULT, 2000, action_timeout, pending, nullptr);
  current.host->data->pending.emplace(pending->id, std::make_pair(cancellable, timeout));
  fl_method_channel_invoke_method(current.host->data->channel, "action", message,
                                 cancellable, action_finished, pending);
  return true;
}

const gchar* node_name(AtkObject* object) {
  Current current(object);
  return current.node == nullptr ? "" : current.node->label.c_str();
}

const gchar* node_description(AtkObject* object) {
  Current current(object);
  if (current.node == nullptr) return "";
  return current.node->hint.empty() ? current.node->tooltip.c_str() : current.node->hint.c_str();
}

AtkRole node_role(AtkObject* object) {
  Current current(object);
  return current.node == nullptr ? ATK_ROLE_INVALID : role_of(*current.node);
}

AtkObject* node_parent(AtkObject* object) {
  Current current(object);
  if (current.node == nullptr) return nullptr;
  return current.node->parent < 0
      ? gtk_widget_get_accessible(GTK_WIDGET(current.host))
      : existing_object(current.host, current.node->parent);
}

gint node_children(AtkObject* object) {
  Current current(object);
  return current.node == nullptr ? 0 : static_cast<gint>(current.node->children.size());
}

AtkObject* node_child(AtkObject* object, gint index) {
  Current current(object);
  if (current.node == nullptr || index < 0 ||
      static_cast<size_t>(index) >= current.node->children.size()) return nullptr;
  auto* child = existing_object(current.host, current.node->children[index]);
  return child == nullptr ? nullptr : ATK_OBJECT(g_object_ref(child));
}

gint node_index(AtkObject* object) {
  Current current(object);
  if (current.node == nullptr) return -1;
  if (current.node->parent < 0) return 0;
  auto found = current.snapshot->nodes.find(current.node->parent);
  if (found == current.snapshot->nodes.end()) return -1;
  auto index = std::find(found->second.children.begin(), found->second.children.end(), current.node->id);
  return index == found->second.children.end() ? -1 : static_cast<gint>(index - found->second.children.begin());
}

AtkStateSet* node_states(AtkObject* object) {
  AtkStateSet* states = atk_state_set_new();
  Current current(object);
  if (current.node == nullptr) {
    atk_state_set_add_state(states, ATK_STATE_DEFUNCT);
    return states;
  }
  const Node& node = *current.node;
  bool hidden = flag(node, "hidden");
  int64_t parent = node.parent;
  for (size_t depth = 0; parent >= 0 && depth < kMaxDepth; ++depth) {
    auto ancestor = current.snapshot->nodes.find(parent);
    if (ancestor == current.snapshot->nodes.end()) { hidden = true; break; }
    hidden |= flag(ancestor->second, "hidden");
    parent = ancestor->second.parent;
  }
  if (gtk_widget_get_visible(GTK_WIDGET(current.host)) && !hidden) {
    atk_state_set_add_state(states, ATK_STATE_VISIBLE);
    if (gtk_widget_get_mapped(GTK_WIDGET(current.host)) && node.rect.width > 0 && node.rect.height > 0 &&
        node.rect.x < current.snapshot->view_width && node.rect.y < current.snapshot->view_height &&
        node.rect.x + node.rect.width > 0 && node.rect.y + node.rect.height > 0)
      atk_state_set_add_state(states, ATK_STATE_SHOWING);
  }
  if (known(node, "enabled") && flag(node, "enabled")) {
    atk_state_set_add_state(states, ATK_STATE_ENABLED);
    atk_state_set_add_state(states, ATK_STATE_SENSITIVE);
  }
  if (flag(node, "focusable") || has_action(node, "focus")) atk_state_set_add_state(states, ATK_STATE_FOCUSABLE);
  if (flag(node, "focused")) atk_state_set_add_state(states, ATK_STATE_FOCUSED);
  if (flag(node, "selected")) atk_state_set_add_state(states, ATK_STATE_SELECTED);
  if (known(node, "selected") || node.level > 0) atk_state_set_add_state(states, ATK_STATE_SELECTABLE);
  if (known(node, "checked") || known(node, "toggled")) atk_state_set_add_state(states, ATK_STATE_CHECKABLE);
  if (flag(node, "checked") || flag(node, "toggled")) atk_state_set_add_state(states, ATK_STATE_CHECKED);
  if (known(node, "expanded")) atk_state_set_add_state(states, ATK_STATE_EXPANDABLE);
  if (flag(node, "expanded")) atk_state_set_add_state(states, ATK_STATE_EXPANDED);
  if (flag(node, "mixed")) atk_state_set_add_state(states, ATK_STATE_INDETERMINATE);
  if (flag(node, "readOnly")) atk_state_set_add_state(states, ATK_STATE_READ_ONLY);
  if (flag(node, "textField")) {
    atk_state_set_add_state(states, ATK_STATE_SELECTABLE_TEXT);
    if (editable_state(node)) atk_state_set_add_state(states, ATK_STATE_EDITABLE);
    if (known(node, "multiline")) atk_state_set_add_state(states, flag(node, "multiline") ? ATK_STATE_MULTI_LINE : ATK_STATE_SINGLE_LINE);
  }
  return states;
}

AtkAttributeSet* node_attributes(AtkObject* object) {
  Current current(object);
  AtkAttributeSet* attributes = nullptr;
  if (current.node == nullptr) return attributes;
  auto append = [&attributes](const char* key, const std::string& value) {
    auto* attribute = g_new0(AtkAttribute, 1);
    attribute->name = g_strdup(key);
    attribute->value = g_strdup(value.c_str());
    attributes = g_slist_prepend(attributes, attribute);
  };
  if (!current.node->identifier.empty()) append("id", current.node->identifier);
  if (current.node->level > 0) append("level", std::to_string(current.node->level));
  if (!current.node->direction.empty()) append("direction", current.node->direction);
  append("busydata-text-status", current.node->text_status);
  append("busydata-geometry-precision", current.node->geometry_precision);
  for (const char* state : {"enabled", "selected", "checked", "expanded", "toggled"}) {
    std::string key = std::string("busydata-") + state;
    append(key.c_str(), known(*current.node, state) ? (flag(*current.node, state) ? "true" : "false") : "unknown");
  }
  return attributes;
}

void node_finalize(GObject* object) {
  auto* self = reinterpret_cast<BusyDataAccessibilityNode*>(object);
  if (self->owner != nullptr) {
    g_weak_ref_clear(&self->owner->host);
    delete self->owner;
    self->owner = nullptr;
  }
  G_OBJECT_CLASS(accessible_node_parent_class)->finalize(object);
}

void accessible_node_class_init(BusyDataAccessibilityNodeClass* klass) {
  auto* atk = ATK_OBJECT_CLASS(klass);
  atk->get_name = node_name;
  atk->get_description = node_description;
  atk->get_role = node_role;
  atk->get_parent = node_parent;
  atk->get_n_children = node_children;
  atk->ref_child = node_child;
  atk->get_index_in_parent = node_index;
  atk->ref_state_set = node_states;
  atk->get_attributes = node_attributes;
  G_OBJECT_CLASS(klass)->finalize = node_finalize;
}

void accessible_node_init(BusyDataAccessibilityNode* self) { self->owner = nullptr; }

void projected_extents(Current& current, const Rect& bounds, gint* x, gint* y, gint* width,
                       gint* height, AtkCoordType coordinates) {
  gint left = 0, top = 0, columns = 0, rows = 0;
  if (current.node != nullptr && current.host->data->view != nullptr &&
      current.snapshot->view_width > 0 && current.snapshot->view_height > 0) {
    GtkWidget* widget = GTK_WIDGET(current.host->data->view);
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    const double scale_x = allocation.width / current.snapshot->view_width;
    const double scale_y = allocation.height / current.snapshot->view_height;
    GtkWidget* window = gtk_widget_get_toplevel(widget);
    gint native_x = 0, native_y = 0;
    gtk_widget_translate_coordinates(widget, window, 0, 0, &native_x, &native_y);
    double origin_x = native_x, origin_y = native_y;
    if (coordinates == ATK_XY_SCREEN) {
      GdkWindow* surface = gtk_widget_get_window(window);
      gint screen_x = 0, screen_y = 0;
      if (surface != nullptr) gdk_window_get_origin(surface, &screen_x, &screen_y);
      origin_x += screen_x; origin_y += screen_y;
    } else if (coordinates == ATK_XY_PARENT) {
      origin_x = origin_y = 0;
      if (current.node->parent >= 0) {
        auto parent = current.snapshot->nodes.find(current.node->parent);
        if (parent != current.snapshot->nodes.end()) {
          origin_x = -parent->second.rect.x * scale_x;
          origin_y = -parent->second.rect.y * scale_y;
        }
      }
    }
    left = static_cast<gint>(std::floor(origin_x + bounds.x * scale_x));
    top = static_cast<gint>(std::floor(origin_y + bounds.y * scale_y));
    columns = static_cast<gint>(std::ceil(origin_x + (bounds.x + bounds.width) * scale_x)) - left;
    rows = static_cast<gint>(std::ceil(origin_y + (bounds.y + bounds.height) * scale_y)) - top;
  }
  if (x != nullptr) *x = left;
  if (y != nullptr) *y = top;
  if (width != nullptr) *width = columns;
  if (height != nullptr) *height = rows;
}

void node_extents(AtkComponent* component, gint* x, gint* y, gint* width,
                  gint* height, AtkCoordType coordinates) {
  Current current(ATK_OBJECT(component));
  projected_extents(current, current.node == nullptr ? Rect{} : current.node->rect, x, y, width, height, coordinates);
}

gboolean node_contains(AtkComponent* component, gint x, gint y, AtkCoordType coordinates) {
  gint left, top, width, height;
  node_extents(component, &left, &top, &width, &height, coordinates);
  return width > 0 && height > 0 && x >= left && y >= top && x - left < width && y - top < height;
}

AtkObject* node_at_point(AtkComponent* component, gint x, gint y, AtkCoordType coordinates) {
  Current current(ATK_OBJECT(component));
  if (coordinates == ATK_XY_PARENT) {
    gint window_x, window_y, parent_x, parent_y;
    node_extents(component, &window_x, &window_y, nullptr, nullptr, ATK_XY_WINDOW);
    node_extents(component, &parent_x, &parent_y, nullptr, nullptr, ATK_XY_PARENT);
    x += window_x - parent_x; y += window_y - parent_y;
    coordinates = ATK_XY_WINDOW;
  }
  if (current.node == nullptr || !node_contains(component, x, y, coordinates)) return nullptr;
  for (auto child = current.node->children.rbegin(); child != current.node->children.rend(); ++child) {
    auto* object = existing_object(current.host, *child);
    if (object == nullptr) continue;
    if (node_contains(ATK_COMPONENT(object), x, y, coordinates)) {
      auto* deeper = node_at_point(ATK_COMPONENT(object), x, y, coordinates);
      return deeper == nullptr ? ATK_OBJECT(g_object_ref(object)) : deeper;
    }
  }
  return ATK_OBJECT(g_object_ref(component));
}

gboolean node_grab_focus(AtkComponent* component) {
  Current current(ATK_OBJECT(component));
  if (current.node == nullptr || !has_action(*current.node, "focus")) return FALSE;
  if (!send_action(current, "focus")) return FALSE;
  gtk_widget_grab_focus(current.host->data->view);
  return TRUE;
}

gboolean node_scroll_to(AtkComponent* component, AtkScrollType type) {
  // Flutter's declared showOnScreen action chooses the reveal position. Do not
  // claim support for an exact edge/corner placement that it cannot express.
  if (type != ATK_SCROLL_ANYWHERE) return FALSE;
  Current current(ATK_OBJECT(component));
  if (current.node == nullptr || !has_action(*current.node, "showOnScreen")) return FALSE;
  return send_action(current, "showOnScreen");
}

void node_component_init(AtkComponentIface* iface) {
  iface->get_extents = node_extents;
  iface->contains = node_contains;
  iface->ref_accessible_at_point = node_at_point;
  iface->grab_focus = node_grab_focus;
  iface->scroll_to = node_scroll_to;
  iface->get_layer = [](AtkComponent*) { return ATK_LAYER_WIDGET; };
  iface->get_mdi_zorder = [](AtkComponent*) { return 0; };
}

const std::string* exposed_action(const Node& node, gint index) {
  if (index < 0) return nullptr;
  for (const auto& name : node.actions) {
    // Reveal has a typed Component API. Keep it out of ordinary action indices
    // so an offscreen reveal index cannot become a visible button's Tap index.
    if (name == "showOnScreen") continue;
    if (index-- == 0) return &name;
  }
  return nullptr;
}

gint action_count(AtkAction* action) {
  Current current(ATK_OBJECT(action));
  return current.node == nullptr ? 0 : static_cast<gint>(std::count_if(
      current.node->actions.begin(), current.node->actions.end(),
      [](const std::string& name) { return name != "showOnScreen"; }));
}

const gchar* action_name(AtkAction* action, gint index) {
  Current current(ATK_OBJECT(action));
  const auto* name = current.node == nullptr ? nullptr : exposed_action(*current.node, index);
  return name == nullptr ? nullptr : name->c_str();
}

gboolean action_do(AtkAction* action, gint index) {
  Current current(ATK_OBJECT(action));
  const auto* exposed = current.node == nullptr ? nullptr : exposed_action(*current.node, index);
  if (exposed == nullptr) return FALSE;
  const auto name = *exposed;
  if (name == "focus") return node_grab_focus(ATK_COMPONENT(action));
  // Parameterized actions are exposed through their corresponding ATK APIs.
  if (name == "setText" || name == "setSelection") return FALSE;
  return send_action(current, name.c_str());
}

void node_action_init(AtkActionIface* iface) {
  iface->get_n_actions = action_count;
  iface->get_name = action_name;
  iface->get_localized_name = action_name;
  iface->do_action = action_do;
}

gint text_count(AtkText* text) {
  Current current(ATK_OBJECT(text));
  return current.node == nullptr ? 0 : static_cast<gint>(g_utf8_strlen(text_of(*current.node).c_str(), -1));
}

gchar* text_get(AtkText* text, gint start, gint end) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr) return nullptr;
  const auto& value = text_of(*current.node);
  gint count = static_cast<gint>(g_utf8_strlen(value.c_str(), -1));
  if (end == -1) end = count;
  if (start < 0 || end < start || end > count) return nullptr;
  return g_utf8_substring(value.c_str(), start, end);
}

gunichar text_character(AtkText* text, gint offset) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr || offset < 0) return 0;
  const auto& value = text_of(*current.node);
  return offset >= g_utf8_strlen(value.c_str(), -1) ? 0 : g_utf8_get_char(g_utf8_offset_to_pointer(value.c_str(), offset));
}

gint text_caret(AtkText* text) {
  Current current(ATK_OBJECT(text));
  return current.node == nullptr ? -1 : character_for_utf16(text_of(*current.node), current.node->selection_extent);
}

bool send_selection(Current& current, gint start, gint end) {
  if (current.node == nullptr) return false;
  int first = utf16_for_character(text_of(*current.node), start);
  int last = utf16_for_character(text_of(*current.node), end);
  if (first < 0 || last < 0) return false;
  g_autoptr(FlValue) args = fl_value_new_map();
  map_int(args, "base", first);
  map_int(args, "extent", last);
  return send_action(current, "setSelection", args);
}

gboolean text_set_caret(AtkText* text, gint offset) {
  Current current(ATK_OBJECT(text));
  return send_selection(current, offset, offset);
}

gint text_selection_count(AtkText* text) {
  Current current(ATK_OBJECT(text));
  return current.node != nullptr && current.node->selection_base >= 0 &&
      current.node->selection_extent >= 0 && current.node->selection_base != current.node->selection_extent ? 1 : 0;
}

gchar* text_selection(AtkText* text, gint number, gint* start, gint* end) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr || number != 0 || current.node->selection_base == current.node->selection_extent) return nullptr;
  int first = character_for_utf16(text_of(*current.node), current.node->selection_base);
  int last = character_for_utf16(text_of(*current.node), current.node->selection_extent);
  if (first < 0 || last < 0) return nullptr;
  if (first > last) std::swap(first, last);
  if (start != nullptr) *start = first;
  if (end != nullptr) *end = last;
  return g_utf8_substring(text_of(*current.node).c_str(), first, last);
}

gboolean text_set_selection(AtkText* text, gint number, gint start, gint end) {
  Current current(ATK_OBJECT(text));
  return number == 0 && send_selection(current, start, end);
}

gboolean text_add_selection(AtkText* text, gint start, gint end) {
  Current current(ATK_OBJECT(text));
  return current.node != nullptr && current.node->selection_base == current.node->selection_extent && send_selection(current, start, end);
}

gboolean text_remove_selection(AtkText* text, gint number) {
  Current current(ATK_OBJECT(text));
  return current.node != nullptr && number == 0 && send_selection(current, text_caret(text), text_caret(text));
}

void text_range_extents(AtkText* text, gint start, gint end, AtkCoordType coordinates, AtkTextRectangle* rectangle) {
  if (rectangle == nullptr) return;
  *rectangle = {0, 0, 0, 0};
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr || start < 0 || end <= start || utf16_for_character(text_of(*current.node), end) < 0) return;
  int first = utf16_for_character(text_of(*current.node), start);
  int last = utf16_for_character(text_of(*current.node), end);
  if (current.node->geometry_precision != "glyph-bounds" || first < current.node->geometry_start || last > current.node->geometry_end) return;
  int covered = first;
  bool present = false;
  Rect united;
  for (const auto& box : current.node->text_boxes) {
    if (box.end <= first || box.start >= last) continue;
    if (box.start > covered) return;
    covered = std::max(covered, box.end);
    if (!present) { united = box.rect; present = true; }
    else {
      double right = std::max(united.x + united.width, box.rect.x + box.rect.width);
      double bottom = std::max(united.y + united.height, box.rect.y + box.rect.height);
      united.x = std::min(united.x, box.rect.x); united.y = std::min(united.y, box.rect.y);
      united.width = right - united.x; united.height = bottom - united.y;
    }
  }
  if (!present || covered < last) return;
  projected_extents(current, united, &rectangle->x, &rectangle->y, &rectangle->width, &rectangle->height, coordinates);
}

gchar* text_string_at(AtkText* text, gint offset, AtkTextGranularity granularity, gint* start, gint* end) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr) return nullptr;
  const auto& value = text_of(*current.node);
  const int count = g_utf8_strlen(value.c_str(), -1);
  if (offset < 0 || offset >= count) return nullptr;
  int first = offset, last = offset + 1;
  if (granularity != ATK_TEXT_GRANULARITY_CHAR) {
    std::vector<PangoLogAttr> attributes(static_cast<size_t>(count) + 1);
    pango_get_log_attrs(value.c_str(), static_cast<int>(value.size()), -1, nullptr, attributes.data(), count + 1);
    auto beginning = [&](int i) {
      if (granularity == ATK_TEXT_GRANULARITY_WORD) return attributes[i].is_word_start != 0;
      if (granularity == ATK_TEXT_GRANULARITY_SENTENCE) return attributes[i].is_sentence_start != 0;
      return i == 0 || attributes[i].is_mandatory_break != 0;
    };
    auto ending = [&](int i) {
      if (granularity == ATK_TEXT_GRANULARITY_WORD) return attributes[i].is_word_end != 0;
      if (granularity == ATK_TEXT_GRANULARITY_SENTENCE) return attributes[i].is_sentence_end != 0;
      return i == count || attributes[i].is_mandatory_break != 0;
    };
    while (first > 0 && !beginning(first)) --first;
    while (last < count && !ending(last)) ++last;
  }
  if (start != nullptr) *start = first;
  if (end != nullptr) *end = last;
  return g_utf8_substring(value.c_str(), first, last);
}

void node_text_init(AtkTextIface* iface) {
  iface->get_text = text_get;
  iface->get_character_count = text_count;
  iface->get_character_at_offset = text_character;
  iface->get_caret_offset = text_caret;
  iface->set_caret_offset = text_set_caret;
  iface->get_n_selections = text_selection_count;
  iface->get_selection = text_selection;
  iface->add_selection = text_add_selection;
  iface->set_selection = text_set_selection;
  iface->remove_selection = text_remove_selection;
  iface->get_range_extents = text_range_extents;
  iface->get_character_extents = [](AtkText* text, gint offset, gint* x, gint* y, gint* width, gint* height, AtkCoordType coordinates) {
    AtkTextRectangle bounds;
    text_range_extents(text, offset, offset + 1, coordinates, &bounds);
    if (x != nullptr) *x = bounds.x;
    if (y != nullptr) *y = bounds.y;
    if (width != nullptr) *width = bounds.width;
    if (height != nullptr) *height = bounds.height;
  };
  iface->get_offset_at_point = [](AtkText* text, gint x, gint y, AtkCoordType coordinates) -> gint {
    Current current(ATK_OBJECT(text));
    if (current.node == nullptr || current.node->geometry_precision != "glyph-bounds") return -1;
    for (const auto& box : current.node->text_boxes) {
      gint left, top, width, height;
      projected_extents(current, box.rect, &left, &top, &width, &height, coordinates);
      if (x >= left && y >= top && x - left < width && y - top < height)
        return character_for_utf16(text_of(*current.node), box.start);
    }
    return -1;
  };
  iface->get_string_at_offset = text_string_at;
}

bool send_text(Current& current, const std::string& text) {
  if (current.node == nullptr || flag(*current.node, "readOnly") || text.size() > kMaxTextBytes ||
      !g_utf8_validate(text.data(), text.size(), nullptr)) return false;
  g_autoptr(FlValue) argument = fl_value_new_string_sized(text.data(), text.size());
  return send_action(current, "setText", argument);
}

void editable_set(AtkEditableText* text, const gchar* value) {
  if (value == nullptr) return;
  size_t length = strnlen(value, kMaxTextBytes + 1);
  if (length > kMaxTextBytes) return;
  Current current(ATK_OBJECT(text));
  send_text(current, std::string(value, length));
}

void editable_insert(AtkEditableText* text, const gchar* inserted, gint length, gint* position) {
  if (inserted == nullptr || position == nullptr || length < -1) return;
  size_t bytes = length == -1 ? strnlen(inserted, kMaxTextBytes + 1) : static_cast<size_t>(length);
  if (bytes > kMaxTextBytes || !g_utf8_validate(inserted, bytes, nullptr) || memchr(inserted, 0, bytes) != nullptr) return;
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr) return;
  const auto& value = text_of(*current.node);
  if (bytes > kMaxTextBytes - std::min(value.size(), kMaxTextBytes) || utf16_for_character(value, *position) < 0) return;
  auto offset = static_cast<size_t>(g_utf8_offset_to_pointer(value.c_str(), *position) - value.c_str());
  (void)offset;
  g_autoptr(FlValue) args = fl_value_new_map();
  int original = utf16_for_character(value, *position);
  map_int(args, "start", original);
  map_int(args, "end", original);
  fl_value_set_string_take(args, "text", fl_value_new_string_sized(inserted, bytes));
  if (send_action(current, "insertText", args)) *position += g_utf8_strlen(inserted, bytes);
}

void editable_delete(AtkEditableText* text, gint start, gint end) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr || start < 0 || end < start || utf16_for_character(text_of(*current.node), end) < 0) return;
  const auto& value = text_of(*current.node);
  g_autoptr(FlValue) args = fl_value_new_map();
  map_int(args, "start", utf16_for_character(value, start));
  map_int(args, "end", utf16_for_character(value, end));
  fl_value_set_string_take(args, "text", fl_value_new_string(""));
  send_action(current, "deleteRange", args);
}

void editable_range(AtkEditableText* text, gint start, gint end, const char* action) {
  Current current(ATK_OBJECT(text));
  if (current.node == nullptr || start < 0 || end < start) return;
  int first = utf16_for_character(text_of(*current.node), start);
  int last = utf16_for_character(text_of(*current.node), end);
  if (first < 0 || last < 0) return;
  g_autoptr(FlValue) args = fl_value_new_map();
  map_int(args, "start", first);
  map_int(args, "end", last);
  fl_value_set_string_take(args, "text", fl_value_new_string(""));
  send_action(current, action, args);
}

void node_editable_init(AtkEditableTextIface* iface) {
  iface->set_text_contents = editable_set;
  iface->insert_text = editable_insert;
  iface->delete_text = editable_delete;
  iface->copy_text = [](AtkEditableText* text, gint start, gint end) { editable_range(text, start, end, "copyRange"); };
  iface->cut_text = [](AtkEditableText* text, gint start, gint end) { editable_range(text, start, end, "cutRange"); };
  iface->paste_text = [](AtkEditableText* text, gint position) { editable_range(text, position, position, "pasteAt"); };
}

gint selected_count(AtkSelection* selection) {
  Current current(ATK_OBJECT(selection));
  gint count = 0;
  if (current.node == nullptr) return count;
  for (auto id : current.node->children) {
    auto found = current.snapshot->nodes.find(id);
    if (found != current.snapshot->nodes.end() && flag(found->second, "selected")) ++count;
  }
  return count;
}

AtkObject* selected_ref(AtkSelection* selection, gint index) {
  Current current(ATK_OBJECT(selection));
  if (current.node == nullptr || index < 0) return nullptr;
  for (auto id : current.node->children) {
    auto found = current.snapshot->nodes.find(id);
    if (found != current.snapshot->nodes.end() && flag(found->second, "selected") && index-- == 0) {
      AtkObject* object = existing_object(current.host, id);
      return object == nullptr ? nullptr : ATK_OBJECT(g_object_ref(object));
    }
  }
  return nullptr;
}

void node_selection_init(AtkSelectionIface* iface) {
  iface->get_selection_count = selected_count;
  iface->ref_selection = selected_ref;
  iface->is_child_selected = [](AtkSelection* selection, gint index) -> gboolean {
    Current current(ATK_OBJECT(selection));
    if (current.node == nullptr || index < 0 || static_cast<size_t>(index) >= current.node->children.size()) return FALSE;
    auto child = current.snapshot->nodes.find(current.node->children[index]);
    return child != current.snapshot->nodes.end() && flag(child->second, "selected");
  };
}

gint root_children(AtkObject* object) {
  BusyDataAccessibilityHost* self = host_of(object);
  return self != nullptr && self->data->snapshot && self->data->snapshot->available && self->data->snapshot->root >= 0 ? 1 : 0;
}

AtkObject* root_child(AtkObject* object, gint index) {
  BusyDataAccessibilityHost* self = host_of(object);
  if (self == nullptr || index != 0 || root_children(object) == 0) return nullptr;
  AtkObject* root = existing_object(self, self->data->snapshot->root);
  return root == nullptr ? nullptr : ATK_OBJECT(g_object_ref(root));
}

void root_extents(AtkComponent* component, gint* x, gint* y, gint* width, gint* height, AtkCoordType coordinates) {
  auto* host = host_of(ATK_OBJECT(component));
  gint left = 0, top = 0, columns = 0, rows = 0;
  if (host != nullptr && !host->data->disposed) {
    GtkWidget* widget = GTK_WIDGET(host);
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);
    columns = allocation.width; rows = allocation.height;
    GtkWidget* destination = coordinates == ATK_XY_PARENT ? gtk_widget_get_parent(widget) : gtk_widget_get_toplevel(widget);
    if (destination != nullptr) gtk_widget_translate_coordinates(widget, destination, 0, 0, &left, &top);
    if (coordinates == ATK_XY_SCREEN) {
      GdkWindow* window = gtk_widget_get_window(gtk_widget_get_toplevel(widget));
      gint screen_x = 0, screen_y = 0;
      if (window != nullptr) gdk_window_get_origin(window, &screen_x, &screen_y);
      left += screen_x; top += screen_y;
    }
  }
  if (x != nullptr) *x = left;
  if (y != nullptr) *y = top;
  if (width != nullptr) *width = columns;
  if (height != nullptr) *height = rows;
}

void root_component_init(AtkComponentIface* iface) {
  iface->get_extents = root_extents;
  iface->contains = [](AtkComponent* component, gint x, gint y, AtkCoordType coordinates) -> gboolean {
    gint left, top, width, height;
    root_extents(component, &left, &top, &width, &height, coordinates);
    return width > 0 && height > 0 && x >= left && y >= top && x - left < width && y - top < height;
  };
  iface->ref_accessible_at_point = [](AtkComponent* component, gint x, gint y, AtkCoordType coordinates) -> AtkObject* {
    auto* host = host_of(ATK_OBJECT(component));
    if (host == nullptr || host->data->disposed || !host->data->snapshot || !host->data->snapshot->available) return nullptr;
    if (coordinates == ATK_XY_PARENT) {
      gint window_x, window_y, parent_x, parent_y;
      root_extents(component, &window_x, &window_y, nullptr, nullptr, ATK_XY_WINDOW);
      root_extents(component, &parent_x, &parent_y, nullptr, nullptr, ATK_XY_PARENT);
      x += window_x - parent_x; y += window_y - parent_y;
      coordinates = ATK_XY_WINDOW;
    }
    auto* node = existing_object(host, host->data->snapshot->root);
    return node == nullptr ? nullptr : node_at_point(ATK_COMPONENT(node), x, y, coordinates);
  };
  iface->grab_focus = [](AtkComponent* component) -> gboolean {
    auto* host = host_of(ATK_OBJECT(component));
    if (host == nullptr || host->data->disposed || host->data->view == nullptr) return FALSE;
    gtk_widget_grab_focus(host->data->view);
    return gtk_widget_has_focus(host->data->view);
  };
  iface->get_layer = [](AtkComponent*) { return ATK_LAYER_WIDGET; };
  iface->get_mdi_zorder = [](AtkComponent*) { return 0; };
}

void accessible_class_init(BusyDataAccessibilityRootClass* klass) {
  ATK_OBJECT_CLASS(klass)->get_n_children = root_children;
  ATK_OBJECT_CLASS(klass)->ref_child = root_child;
  ATK_OBJECT_CLASS(klass)->get_attributes = [](AtkObject* object) -> AtkAttributeSet* {
    BusyDataAccessibilityHost* self = host_of(object);
    auto snapshot = self == nullptr ? nullptr : self->data->snapshot;
    AtkAttributeSet* attributes = nullptr;
    const std::pair<const char*, const char*> items[] = {
        {"busydata-status", snapshot ? snapshot->status.c_str() : "unavailable"},
        {"busydata-reason", snapshot ? snapshot->reason.c_str() : "semantics-unavailable"}};
    for (const auto& item : items) {
      auto* attribute = g_new0(AtkAttribute, 1);
      attribute->name = g_strdup(item.first); attribute->value = g_strdup(item.second);
      attributes = g_slist_prepend(attributes, attribute);
    }
    if (self != nullptr) {
      auto add = [&attributes](const char* name, const std::string& value) {
        auto* attribute = g_new0(AtkAttribute, 1);
        attribute->name = g_strdup(name); attribute->value = g_strdup(value.c_str());
        attributes = g_slist_prepend(attributes, attribute);
      };
      const auto& action = self->data->action;
      add("busydata-bridge-epoch", std::to_string(snapshot ? snapshot->bridge_epoch : self->data->bridge_epoch));
      add("busydata-owner-epoch", std::to_string(snapshot ? snapshot->owner_epoch : 0));
      add("busydata-revision", std::to_string(snapshot ? snapshot->revision : 0));
      add("busydata-action-sequence", std::to_string(action.sequence));
      add("busydata-action-name", action.name);
      add("busydata-action-status", action.status);
      add("busydata-action-node-id", std::to_string(action.node_id));
      add("busydata-action-request-revision", std::to_string(action.request_revision));
      add("busydata-action-reply-revision", std::to_string(action.reply_revision));
      add("busydata-action-bridge-epoch", std::to_string(action.bridge_epoch));
      add("busydata-action-owner-epoch", std::to_string(action.owner_epoch));
      add("busydata-action-view-id", std::to_string(action.view_id));
      add("busydata-action-reply-count", std::to_string(self->data->action_replies));
      add("busydata-action-stale-count", std::to_string(self->data->action_stale));
      add("busydata-action-timeout-count", std::to_string(self->data->action_timeouts));
      add("busydata-action-inflight", std::to_string(self->data->pending.size()));
    }
    return attributes;
  };
  // Suppress the default container's announcement of its physical FlView.
  // Only this owned accessible's presentation children are exposed to ATK.
  GTK_CONTAINER_ACCESSIBLE_CLASS(klass)->add_gtk = [](GtkContainer*, GtkWidget*, gpointer) { return 0; };
  GTK_CONTAINER_ACCESSIBLE_CLASS(klass)->remove_gtk = [](GtkContainer*, GtkWidget*, gpointer) { return 0; };
}

void accessible_init(BusyDataAccessibilityRoot*) {}

bool integer(FlValue* map, const char* key, int64_t* value, int64_t minimum = 0) {
  FlValue* field = fl_value_lookup_string(map, key);
  if (field == nullptr || fl_value_get_type(field) != FL_VALUE_TYPE_INT) return false;
  *value = fl_value_get_int(field);
  return *value >= minimum;
}

bool string_field(FlValue* map, const char* key, std::string* target, size_t* bytes,
                  size_t* units = nullptr) {
  FlValue* field = fl_value_lookup_string(map, key);
  if (field == nullptr || fl_value_get_type(field) != FL_VALUE_TYPE_STRING) return false;
  const char* text = fl_value_get_string(field);
  size_t length = strnlen(text, kMaxTextBytes + 1);
  if (length > kMaxTextBytes || !g_utf8_validate(text, length, nullptr) || *bytes > kMaxModelBytes - length) return false;
  if (units != nullptr) {
    size_t added = 0;
    for (const char* p = text; *p != 0; p = g_utf8_next_char(p)) added += g_utf8_get_char(p) > 0xffff ? 2 : 1;
    if (added > kMaxTextUnits - *units) return false;
    *units += added;
  }
  *bytes += length;
  target->assign(text, length);
  return true;
}

bool number(FlValue* value, double* target) {
  if (value == nullptr) return false;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) *target = static_cast<double>(fl_value_get_int(value));
  else if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) *target = fl_value_get_float(value);
  else return false;
  return std::isfinite(*target) && std::abs(*target) <= 10000000;
}

std::shared_ptr<const Snapshot> parse_snapshot(FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return nullptr;
  int64_t version;
  auto result = std::make_shared<Snapshot>();
  if (!integer(args, "version", &version) || version != 1 ||
      !integer(args, "bridgeEpoch", &result->bridge_epoch, 1) ||
      !integer(args, "ownerEpoch", &result->owner_epoch, 1) ||
      !integer(args, "viewId", &result->view_id) ||
      !integer(args, "revision", &result->revision, 1) ||
      !integer(args, "rootId", &result->root, -1)) return nullptr;
  FlValue* values = fl_value_lookup_string(args, "nodes");
  size_t bytes = 0, units = 0, edges = 0;
  if (!string_field(args, "status", &result->status, &bytes) ||
      !string_field(args, "reason", &result->reason, &bytes) ||
      (result->status != "ok" && result->status != "limited" && result->status != "unavailable") ||
      (result->status == "ok" && !result->reason.empty()) ||
      !number(fl_value_lookup_string(args, "viewWidth"), &result->view_width) ||
      !number(fl_value_lookup_string(args, "viewHeight"), &result->view_height) ||
      result->view_width < 0 || result->view_height < 0 ||
      values == nullptr || fl_value_get_type(values) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(values) > kMaxNodes) return nullptr;
  const std::unordered_set<std::string> reasons = {"node-limit", "text-limit", "encoded-limit", "invalid-tree", "invalid-geometry", "semantics-unavailable"};
  if (result->status != "ok" && reasons.find(result->reason) == reasons.end()) return nullptr;
  result->available = result->status == "ok";
  if (!result->available && (result->root != -1 || fl_value_get_length(values) != 0)) return nullptr;
  const std::unordered_set<std::string> known_actions = {"tap", "longPress", "focus", "setSelection", "setText", "copy", "cut", "paste", "scrollLeft", "scrollRight", "scrollUp", "scrollDown", "increase", "decrease", "showOnScreen", "dismiss", "moveCursorForwardByCharacter", "moveCursorBackwardByCharacter", "moveCursorForwardByWord", "moveCursorBackwardByWord", "scrollToOffset", "expand", "collapse", "didGainAccessibilityFocus", "didLoseAccessibilityFocus"};
  const std::unordered_set<std::string> roles = {"none", "tab", "tabBar", "tabPanel", "dialog", "alertDialog", "table", "cell", "row", "columnHeader", "dragHandle", "spinButton", "comboBox", "menuBar", "menu", "menuItem", "menuItemCheckbox", "menuItemRadio", "list", "listItem", "form", "tooltip", "loadingSpinner", "progressBar", "hotKey", "radioGroup", "status", "alert", "complementary", "contentInfo", "main", "navigation", "region"};
  for (size_t index = 0; index < fl_value_get_length(values); ++index) {
    FlValue* value = fl_value_get_list_value(values, index);
    if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_MAP || bytes > kMaxModelBytes - sizeof(Node)) return nullptr;
    bytes += sizeof(Node);
    Node node;
    int64_t base, extent, level;
    if (!integer(value, "id", &node.id) || !integer(value, "parentId", &node.parent, -1) ||
        !integer(value, "selectionBase", &base, -1) || !integer(value, "selectionExtent", &extent, -1) ||
        base > static_cast<int64_t>(kMaxTextUnits) || extent > static_cast<int64_t>(kMaxTextUnits) ||
        !integer(value, "treeLevel", &level) || level > 64 ||
        !string_field(value, "identifier", &node.identifier, &bytes, &units) ||
        !string_field(value, "label", &node.label, &bytes, &units) || !string_field(value, "value", &node.value, &bytes, &units) ||
        !string_field(value, "hint", &node.hint, &bytes, &units) || !string_field(value, "tooltip", &node.tooltip, &bytes, &units) ||
        !string_field(value, "role", &node.role, &bytes) || !string_field(value, "direction", &node.direction, &bytes) ||
        !string_field(value, "textStatus", &node.text_status, &bytes) ||
        !string_field(value, "geometryPrecision", &node.geometry_precision, &bytes) ||
        (node.text_status != "available" && node.text_status != "unavailable-nul" && node.text_status != "unavailable-encoding") ||
        (node.geometry_precision != "field-bounds" && node.geometry_precision != "glyph-bounds") ||
        (node.direction != "ltr" && node.direction != "rtl" && node.direction != "unknown")) return nullptr;
    if (roles.find(node.role) == roles.end()) return nullptr;
    if (level > 0) {
      constexpr char prefix[] = "busydata.database.item.";
      if (!g_str_has_prefix(node.identifier.c_str(), prefix)) return nullptr;
      char* after_level = nullptr;
      auto parsed_level = g_ascii_strtoull(node.identifier.c_str() + sizeof(prefix) - 1, &after_level, 10);
      if (parsed_level != static_cast<uint64_t>(level) || after_level == nullptr || *after_level != '.' || after_level[1] == 0) return nullptr;
    }
    node.selection_base = static_cast<int>(base);
    node.selection_extent = static_cast<int>(extent);
    node.level = static_cast<int>(level);
    FlValue* children = fl_value_lookup_string(value, "children");
    FlValue* actions = fl_value_lookup_string(value, "actions");
    FlValue* flags = fl_value_lookup_string(value, "flags");
    FlValue* rect = fl_value_lookup_string(value, "rect");
    if (children == nullptr || fl_value_get_type(children) != FL_VALUE_TYPE_LIST ||
        actions == nullptr || fl_value_get_type(actions) != FL_VALUE_TYPE_LIST || fl_value_get_length(actions) > kMaxActions ||
        flags == nullptr || fl_value_get_type(flags) != FL_VALUE_TYPE_MAP || fl_value_get_length(flags) > 64 ||
        rect == nullptr || fl_value_get_type(rect) != FL_VALUE_TYPE_LIST || fl_value_get_length(rect) != 4 ||
        fl_value_get_length(children) > kMaxNodes - edges) return nullptr;
    edges += fl_value_get_length(children);
    for (size_t child = 0; child < fl_value_get_length(children); ++child) {
      FlValue* id = fl_value_get_list_value(children, child);
      if (fl_value_get_type(id) != FL_VALUE_TYPE_INT || fl_value_get_int(id) < 0) return nullptr;
      node.children.push_back(fl_value_get_int(id));
    }
    for (size_t action = 0; action < fl_value_get_length(actions); ++action) {
      FlValue* name = fl_value_get_list_value(actions, action);
      if (fl_value_get_type(name) != FL_VALUE_TYPE_STRING) return nullptr;
      const char* text = fl_value_get_string(name);
      if (known_actions.find(text) == known_actions.end() || has_action(node, text)) return nullptr;
      node.actions.emplace_back(text);
    }
    for (size_t item = 0; item < fl_value_get_length(flags); ++item) {
      FlValue* key = fl_value_get_map_key(flags, item);
      FlValue* flag_value = fl_value_get_map_value(flags, item);
      if (fl_value_get_type(key) != FL_VALUE_TYPE_STRING ||
          (fl_value_get_type(flag_value) != FL_VALUE_TYPE_BOOL && fl_value_get_type(flag_value) != FL_VALUE_TYPE_NULL) ||
          flag_index(fl_value_get_string(key)) < 0) return nullptr;
      node.flags[flag_index(fl_value_get_string(key))] = fl_value_get_type(flag_value) == FL_VALUE_TYPE_NULL ? -1 : (fl_value_get_bool(flag_value) ? 1 : 0);
    }
    if (flag(node, "password")) {
      if (has_action(node, "copy") || has_action(node, "cut")) return nullptr;
      for (const char* scalar = node.value.c_str(); *scalar != 0; scalar = g_utf8_next_char(scalar)) {
        if (g_utf8_get_char(scalar) != 0x2022) return nullptr;
      }
    }
    if (!number(fl_value_get_list_value(rect, 0), &node.rect.x) || !number(fl_value_get_list_value(rect, 1), &node.rect.y) ||
        !number(fl_value_get_list_value(rect, 2), &node.rect.width) || !number(fl_value_get_list_value(rect, 3), &node.rect.height) ||
        node.rect.width < 0 || node.rect.height < 0) return nullptr;
    if ((base >= 0 && character_for_utf16(text_of(node), node.selection_base) < 0) ||
        (extent >= 0 && character_for_utf16(text_of(node), node.selection_extent) < 0)) return nullptr;
    FlValue* geometry = fl_value_lookup_string(value, "textGeometry");
    if (node.geometry_precision == "glyph-bounds") {
      std::vector<int> scalar_boundaries = {0};
      int text_units = 0;
      const auto& geometry_text = text_of(node);
      for (const char* scalar = geometry_text.c_str(); *scalar != 0; scalar = g_utf8_next_char(scalar)) {
        text_units += g_utf8_get_char(scalar) > 0xffff ? 2 : 1;
        scalar_boundaries.push_back(text_units);
      }
      auto valid_boundary = [&scalar_boundaries](int64_t offset) {
        return offset >= 0 && offset <= static_cast<int64_t>(kMaxTextUnits) &&
            std::binary_search(scalar_boundaries.begin(), scalar_boundaries.end(), static_cast<int>(offset));
      };
      int64_t geometry_start, geometry_end;
      if (geometry == nullptr || fl_value_get_type(geometry) != FL_VALUE_TYPE_MAP ||
          !integer(geometry, "start", &geometry_start) || !integer(geometry, "end", &geometry_end) ||
          geometry_start > geometry_end || geometry_end > static_cast<int64_t>(kMaxTextUnits) ||
          !valid_boundary(geometry_start) || !valid_boundary(geometry_end)) return nullptr;
      node.geometry_start = geometry_start; node.geometry_end = geometry_end;
      FlValue* boxes = fl_value_lookup_string(geometry, "boxes");
      if (boxes == nullptr || fl_value_get_type(boxes) != FL_VALUE_TYPE_LIST || fl_value_get_length(boxes) > 4096) return nullptr;
      int previous_start = -1;
      for (size_t box_index = 0; box_index < fl_value_get_length(boxes); ++box_index) {
        FlValue* raw_box = fl_value_get_list_value(boxes, box_index);
        int64_t start, end;
        if (raw_box == nullptr || fl_value_get_type(raw_box) != FL_VALUE_TYPE_MAP ||
            !integer(raw_box, "start", &start) || !integer(raw_box, "end", &end) || start < previous_start ||
            start < geometry_start || end <= start || end > geometry_end ||
            !valid_boundary(start) || !valid_boundary(end)) return nullptr;
        FlValue* raw_rect = fl_value_lookup_string(raw_box, "rect");
        TextBox box{static_cast<int>(start), static_cast<int>(end), {}};
        if (raw_rect == nullptr || fl_value_get_type(raw_rect) != FL_VALUE_TYPE_LIST || fl_value_get_length(raw_rect) != 4 ||
            !number(fl_value_get_list_value(raw_rect, 0), &box.rect.x) || !number(fl_value_get_list_value(raw_rect, 1), &box.rect.y) ||
            !number(fl_value_get_list_value(raw_rect, 2), &box.rect.width) || !number(fl_value_get_list_value(raw_rect, 3), &box.rect.height) ||
            box.rect.width < 0 || box.rect.height < 0) return nullptr;
        bytes += sizeof(TextBox);
        if (bytes > kMaxModelBytes) return nullptr;
        node.text_boxes.push_back(box);
        previous_start = start;
      }
    } else if (geometry != nullptr && fl_value_get_type(geometry) != FL_VALUE_TYPE_NULL) return nullptr;
    bytes += node.children.size() * sizeof(int64_t) + node.actions.size() * 96 + 160;
    if (bytes > kMaxModelBytes || !result->nodes.emplace(node.id, std::move(node)).second) return nullptr;
  }
  if (!result->available) return result;
  auto root = result->nodes.find(result->root);
  if (root == result->nodes.end() || root->second.parent != -1) return nullptr;
  std::vector<std::pair<int64_t, size_t>> pending = {{result->root, 0}};
  std::unordered_set<int64_t> visited;
  while (!pending.empty()) {
    const auto id = pending.back().first;
    const auto depth = pending.back().second;
    pending.pop_back();
    if (depth > kMaxDepth || !visited.insert(id).second) return nullptr;
    const auto parent = result->nodes.find(id);
    if (parent == result->nodes.end()) return nullptr;
    for (const auto child_id : parent->second.children) {
      auto child = result->nodes.find(child_id);
      if (child == result->nodes.end() || child->second.parent != id) return nullptr;
      pending.emplace_back(child_id, depth + 1);
    }
  }
  return visited.size() == result->nodes.size() ? result : nullptr;
}

void detach(AtkObject* object) {
  auto* self = reinterpret_cast<BusyDataAccessibilityNode*>(object);
  self->owner->defunct = true;
  atk_object_notify_state_change(object, ATK_STATE_DEFUNCT, TRUE);
  g_weak_ref_set(&self->owner->host, nullptr);
}

void publish(BusyDataAccessibilityHost* self, std::shared_ptr<const Snapshot> next) {
  g_autoptr(GObject) keep_host = G_OBJECT(g_object_ref(self));
  auto previous = self->data->snapshot;
  auto previous_objects = self->data->objects;
  struct Pins {
    std::vector<AtkObject*> objects;
    void add(AtkObject* object) { objects.push_back(ATK_OBJECT(g_object_ref(object))); }
    ~Pins() { for (auto* object : objects) g_object_unref(object); }
  } pins;
  for (const auto& entry : previous_objects) pins.add(entry.second);
  bool same_owner = previous && previous->bridge_epoch == next->bridge_epoch && previous->owner_epoch == next->owner_epoch;
  struct RetiredObjects {
    std::vector<AtkObject*> objects;
    ~RetiredObjects() {
      for (auto* object : objects) {
        if (!reinterpret_cast<BusyDataAccessibilityNode*>(object)->owner->defunct) detach(object);
        g_object_unref(object);
      }
    }
  } retired;
  auto& removed = retired.objects;
  for (auto iterator = self->data->objects.begin(); iterator != self->data->objects.end();) {
    auto replacement = next->nodes.find(iterator->first);
    if (!same_owner || replacement == next->nodes.end() || G_OBJECT_TYPE(iterator->second) != node_type(replacement->second)) {
      removed.push_back(iterator->second);
      iterator = self->data->objects.erase(iterator);
    } else ++iterator;
  }
  for (const auto& entry : next->nodes) {
    if (existing_object(self, entry.first) != nullptr) continue;
    auto* object = ATK_OBJECT(g_object_new(node_type(entry.second), nullptr));
    auto* owner = new NodeOwner;
    g_weak_ref_init(&owner->host, self);
    owner->id = entry.first;
    owner->bridge_epoch = next->bridge_epoch;
    owner->owner_epoch = next->owner_epoch;
    reinterpret_cast<BusyDataAccessibilityNode*>(object)->owner = owner;
    atk_object_initialize(object, nullptr);
    self->data->objects.emplace(entry.first, object);
  }
  self->data->snapshot = std::move(next);
  g_autoptr(AtkObject) pinned_root = ATK_OBJECT(g_object_ref(gtk_widget_get_accessible(GTK_WIDGET(self))));
  AtkObject* root = pinned_root;
  auto current_snapshot = self->data->snapshot;
  const auto& current = *current_snapshot;
  auto notifications = self->data->objects;
  for (const auto& entry : notifications) pins.add(entry.second);
  auto is_current = [&] { return !self->data->disposed && self->data->snapshot == current_snapshot; };
  auto reused = [&](int64_t id, AtkObject* object) {
    auto old = previous_objects.find(id);
    return same_owner && old != previous_objects.end() && old->second == object;
  };
  // Publish one complete owned model first. Announce all identities, topology
  // and properties before any focus gain, independently of hash-map order.
  for (const auto& entry : notifications) {
    if (!is_current()) return;
    atk_object_set_accessible_id(entry.second, current.nodes.at(entry.first).identifier.c_str());
  }
  auto old_root = previous && previous->available ? previous_objects.find(previous->root) : previous_objects.end();
  auto new_root = current.available ? notifications.find(current.root) : notifications.end();
  if (!same_owner || !previous || previous->root != current.root || previous->available != current.available ||
      (old_root != previous_objects.end() && new_root != notifications.end() && old_root->second != new_root->second)) {
    if (old_root != previous_objects.end()) g_signal_emit_by_name(root, "children-changed::remove", 0, old_root->second, nullptr);
    if (!is_current()) return;
    if (new_root != notifications.end()) g_signal_emit_by_name(root, "children-changed::add", 0, new_root->second, nullptr);
  }
  for (const auto& entry : notifications) {
    if (!is_current()) return;
    auto old = previous ? previous->nodes.find(entry.first) : current_snapshot->nodes.end();
    const auto& node = current_snapshot->nodes.at(entry.first);
    if (!reused(entry.first, entry.second)) continue;
    bool replaced_child = std::any_of(node.children.begin(), node.children.end(), [&](int64_t id) {
      auto before = previous_objects.find(id);
      auto after = self->data->objects.find(id);
      return before != previous_objects.end() && after != self->data->objects.end() && before->second != after->second;
    });
    if (old->second.children != node.children || replaced_child) {
      for (size_t index = old->second.children.size(); index > 0; --index) {
        if (!is_current()) return;
        auto child = previous_objects.find(old->second.children[index - 1]);
        if (child != previous_objects.end()) g_signal_emit_by_name(entry.second, "children-changed::remove", static_cast<gint>(index - 1), child->second, nullptr);
      }
      for (size_t index = 0; index < node.children.size(); ++index) {
        if (!is_current()) return;
        auto child = notifications.find(node.children[index]);
        if (child != notifications.end()) g_signal_emit_by_name(entry.second, "children-changed::add", static_cast<gint>(index), child->second, nullptr);
      }
    }
  }
  for (AtkObject* object : removed) detach(object);
  for (const auto& entry : notifications) {
    if (!is_current()) return;
    auto old = previous ? previous->nodes.find(entry.first) : current_snapshot->nodes.end();
    const auto& node = current.nodes.at(entry.first);
    if (!reused(entry.first, entry.second)) {
      g_signal_emit_by_name(entry.second, "visible-data-changed");
      continue;
    }
    if (old->second.label != node.label) g_object_notify(G_OBJECT(entry.second), "accessible-name");
    if (!is_current()) return;
    if (role_of(old->second) != role_of(node)) g_object_notify(G_OBJECT(entry.second), "accessible-role");
    if (!is_current()) return;
    // Parent lookup is owned and dynamic; no atk_object_set_parent call
    // emits this notification for us.
    if (old->second.parent != node.parent) g_object_notify(G_OBJECT(entry.second), "accessible-parent");
    if (!is_current()) return;
    const auto& old_description = old->second.hint.empty() ? old->second.tooltip : old->second.hint;
    const auto& description = node.hint.empty() ? node.tooltip : node.hint;
    if (old_description != description) g_object_notify(G_OBJECT(entry.second), "accessible-description");
    if (!is_current()) return;
    if (ATK_IS_TEXT(entry.second) && text_of(old->second) != text_of(node)) {
      gint old_count = g_utf8_strlen(text_of(old->second).c_str(), -1);
      gint count = g_utf8_strlen(text_of(node).c_str(), -1);
      if (old_count > 0) g_signal_emit_by_name(entry.second, "text-changed::delete", 0, old_count);
      if (!is_current()) return;
      if (count > 0) g_signal_emit_by_name(entry.second, "text-changed::insert", 0, count);
    }
    const std::pair<const char*, AtkStateType> states[] = {{"selected", ATK_STATE_SELECTED}, {"expanded", ATK_STATE_EXPANDED}, {"checked", ATK_STATE_CHECKED}};
    for (const auto& state : states) {
      if (!is_current()) return;
      if (flag(old->second, state.first) != flag(node, state.first))
        atk_object_notify_state_change(entry.second, state.second, flag(node, state.first));
    }
    if (!is_current()) return;
    if (editable_state(old->second) != editable_state(node))
      atk_object_notify_state_change(entry.second, ATK_STATE_EDITABLE, editable_state(node));
    if (!is_current()) return;
    if (flag(old->second, "readOnly") != flag(node, "readOnly"))
      atk_object_notify_state_change(entry.second, ATK_STATE_READ_ONLY, flag(node, "readOnly"));
  }
  if (!is_current()) return;
  g_signal_emit_by_name(root, "visible-data-changed");
  // Complete every old object's loss before announcing the new focus. A
  // same-ID replacement is a different owned object and needs an initial gain.
  for (const auto& entry : previous_objects) {
    if (!is_current()) return;
    const auto& old = previous->nodes.at(entry.first);
    if (!flag(old, "focused")) continue;
    auto node = current.nodes.find(entry.first);
    if (reused(entry.first, entry.second) && notifications.count(entry.first) &&
        notifications.at(entry.first) == entry.second && node != current.nodes.end() && flag(node->second, "focused")) continue;
    atk_object_notify_state_change(entry.second, ATK_STATE_FOCUSED, FALSE);
    if (!is_current()) return;
    g_signal_emit_by_name(entry.second, "focus-event", FALSE);
  }
  for (const auto& entry : notifications) {
    if (!is_current()) return;
    const auto& node = current.nodes.at(entry.first);
    if (!flag(node, "focused")) continue;
    if (reused(entry.first, entry.second) && flag(previous->nodes.at(entry.first), "focused")) continue;
    atk_object_notify_state_change(entry.second, ATK_STATE_FOCUSED, TRUE);
    if (!is_current()) return;
    g_signal_emit_by_name(entry.second, "focus-event", TRUE);
  }
  // A text client can silently adopt the focused source of a caret event.
  // Announce every focus transition first, so a simultaneous caret/selection
  // update cannot turn the field's initial focus announcement into a duplicate.
  // The complete current text and offsets were already published above.
  for (const auto& entry : notifications) {
    if (!is_current()) return;
    if (!reused(entry.first, entry.second) || !ATK_IS_TEXT(entry.second)) continue;
    const auto& old = previous->nodes.at(entry.first);
    const auto& node = current.nodes.at(entry.first);
    if (old.selection_extent != node.selection_extent)
      g_signal_emit_by_name(entry.second, "text-caret-moved", character_for_utf16(text_of(node), node.selection_extent));
    if (!is_current()) return;
    if (old.selection_base != node.selection_base || old.selection_extent != node.selection_extent)
      g_signal_emit_by_name(entry.second, "text-selection-changed");
  }
}

void clear_presentation(BusyDataAccessibilityHost* self) {
  g_autoptr(GObject) keep_host = G_OBJECT(g_object_ref(self));
  g_autoptr(AtkObject) pinned_root = ATK_OBJECT(g_object_ref(gtk_widget_get_accessible(GTK_WIDGET(self))));
  AtkObject* root = pinned_root;
  AtkObject* old_root = nullptr;
  if (self->data->snapshot && self->data->snapshot->available) {
    old_root = existing_object(self, self->data->snapshot->root);
    if (old_root != nullptr) g_object_ref(old_root);
  }
  self->data->snapshot.reset();
  auto retired = std::move(self->data->objects);
  self->data->objects.clear();
  for (auto& entry : retired) { detach(entry.second); g_object_unref(entry.second); }
  if (old_root != nullptr) {
    g_signal_emit_by_name(root, "children-changed::remove", 0, old_root, nullptr);
    g_object_unref(old_root);
  }
  g_signal_emit_by_name(root, "visible-data-changed");
}

void reply_status(FlMethodCall* call, const char* status, const HostData& data) {
  g_autoptr(FlValue) result = fl_value_new_map();
  map_int(result, "version", 1);
  map_int(result, "bridgeEpoch", data.bridge_epoch);
  fl_value_set_string_take(result, "status", fl_value_new_string(status));
  fl_method_call_respond_success(call, result, nullptr);
}

void method_call(FlMethodChannel*, FlMethodCall* call, gpointer data) {
  auto* self = static_cast<BusyDataAccessibilityHost*>(data);
  g_autoptr(GObject) keep_host = G_OBJECT(g_object_ref(self));
  const char* method = fl_method_call_get_name(call);
  if (self->data->disposed) {
    reply_status(call, "disposed", *self->data);
    return;
  }
  if (self->data->view == nullptr) {
    reply_status(call, "unavailable", *self->data);
    return;
  }
  FlValue* arguments = fl_method_call_get_args(call);
  int64_t version, view_id;
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP ||
      !integer(arguments, "version", &version) || version != 1 ||
      !integer(arguments, "viewId", &view_id)) {
    reply_status(call, "malformed", *self->data);
    return;
  }
  if (g_str_equal(method, "attach")) {
    if (self->data->view == nullptr || !FL_IS_VIEW(self->data->view) || view_id != fl_view_get_id(FL_VIEW(self->data->view))) {
      reply_status(call, "unavailable", *self->data);
      return;
    }
    static int64_t next_epoch = 0;  // All GTK/channel callbacks run on this thread.
    clear_presentation(self);
    self->data->view_id = view_id;
    self->data->bridge_epoch = ++next_epoch;
    reply_status(call, self->data->disposed ? "disposed" : "ok", *self->data);
    return;
  }
  int64_t epoch;
  if (!integer(arguments, "bridgeEpoch", &epoch, 1) ||
      epoch != self->data->bridge_epoch || view_id != self->data->view_id) {
    reply_status(call, "stale", *self->data);
    return;
  }
  if (g_str_equal(method, "publish")) {
    auto snapshot = parse_snapshot(fl_method_call_get_args(call));
    if (!snapshot) {
      reply_status(call, "malformed", *self->data);
      return;
    }
    auto previous = self->data->snapshot;
    if (previous && (snapshot->bridge_epoch < previous->bridge_epoch ||
        (snapshot->bridge_epoch == previous->bridge_epoch && (snapshot->owner_epoch < previous->owner_epoch ||
        (snapshot->owner_epoch == previous->owner_epoch && snapshot->revision <= previous->revision))))) {
      reply_status(call, "stale", *self->data);
      return;
    }
    publish(self, std::move(snapshot));
    reply_status(call, self->data->disposed ? "disposed" : "ok", *self->data);
    return;
  }
  if (g_str_equal(method, "detach")) {
    clear_presentation(self);
    self->data->view_id = -1;
    reply_status(call, "ok", *self->data);
    return;
  }
  fl_method_call_respond_not_implemented(call, nullptr);
}

void host_dispose(GObject* object) {
  auto* self = reinterpret_cast<BusyDataAccessibilityHost*>(object);
  if (self->data != nullptr && !self->data->disposed) {
    self->data->disposed = true;
    if (self->data->channel != nullptr) {
      fl_method_channel_set_method_call_handler(self->data->channel, nullptr, nullptr, nullptr);
      g_clear_object(&self->data->channel);
    }
    for (auto& pending : self->data->pending) {
      g_source_remove(pending.second.second);
      g_cancellable_cancel(pending.second.first);
      g_object_unref(pending.second.first);
    }
    self->data->pending.clear();
    for (auto& entry : self->data->objects) { detach(entry.second); g_object_unref(entry.second); }
    self->data->objects.clear();
    self->data->snapshot.reset();
    self->data->view = nullptr;
  }
  G_OBJECT_CLASS(host_parent_class)->dispose(object);
}

void host_finalize(GObject* object) {
  auto* self = reinterpret_cast<BusyDataAccessibilityHost*>(object);
  delete self->data;
  self->data = nullptr;
  G_OBJECT_CLASS(host_parent_class)->finalize(object);
}

void host_class_init(BusyDataAccessibilityHostClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = host_dispose;
  G_OBJECT_CLASS(klass)->finalize = host_finalize;
  // This changes only BusyData's own type, never the FlView/GTK type.
  gtk_widget_class_set_accessible_type(GTK_WIDGET_CLASS(klass), accessible_get_type());
}

void host_init(BusyDataAccessibilityHost* self) { self->data = new HostData; }

}  // namespace

GtkWidget* busydata_accessibility_bridge_new(FlView* view) {
  g_return_val_if_fail(FL_IS_VIEW(view), nullptr);
  auto* self = reinterpret_cast<BusyDataAccessibilityHost*>(g_object_new(host_get_type(), nullptr));
  self->data->view = GTK_WIDGET(view);
  gtk_container_add(GTK_CONTAINER(self), GTK_WIDGET(view));
  g_autoptr(FlMethodCodec) codec = FL_METHOD_CODEC(g_object_new(bounded_codec_get_type(), nullptr));
  self->data->channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kChannel, codec);
  fl_method_channel_set_method_call_handler(self->data->channel, method_call, self, nullptr);
  g_signal_connect_object(view, "destroy", G_CALLBACK(+[](GtkWidget*, BusyDataAccessibilityHost* host) {
    host->data->view = nullptr;
    host->data->view_id = -1;
    if (!host->data->disposed) clear_presentation(host);
  }), self, static_cast<GConnectFlags>(0));
  gtk_widget_set_name(GTK_WIDGET(self), "busydata-accessibility-host");
  return GTK_WIDGET(self);
}
