#include "my_application.h"
#include "busydata_accessibility_bridge.h"
#include "busydata_window_close.h"
#include "gtk_header_icons.h"
#include "gtk_search_entry_theme.h"
#include "gtk_window_preferences.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include <handy.h>
#include <langinfo.h>
#include <pango/pango.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <memory>
#include "flutter/generated_plugin_registrant.h"

constexpr char kApplicationDisplayName[] = "BusyData";
constexpr char kNativeMenuChannel[] = "busydata/native_menus";
constexpr char kNativeMenuActionNamespace[] = "busydata-native-menu";
constexpr char kNativeMenuActionIndexKey[] = "busydata-native-menu-index";
constexpr char kWindowChannel[] = "io.busystack.busydata/window";
constexpr char kGtkSettingsChannel[] = "io.busystack.busydata/gtk_settings";
constexpr char kGtkHeaderIconsChannel[] =
    "io.busystack.busydata/gtk_header_icons";
constexpr char kGtkHeaderIconsChangedEventChannel[] =
    "io.busystack.busydata/gtk_header_icons_changed";
constexpr char kGtkThemeColorsEventChannel[] =
    "io.busystack.busydata/gtk_theme_colors";
constexpr char kGtkAnimationSettingsEventChannel[] =
    "io.busystack.busydata/gtk_animation_settings";
constexpr char kGtkWindowPreferencesEventChannel[] =
    "io.busystack.busydata/gtk_window_preferences";
constexpr char kGtkFontSettingsEventChannel[] = "io.busystack.busydata/gtk_font_settings";
constexpr gint kMainWindowDefaultWidth = 1280;
constexpr gint kMainWindowDefaultHeight = 720;
constexpr char kDefaultWindowBackgroundColor[] = "#2C2C2C";
constexpr char kDefaultDialogOutlineColor[] = "rgba(255,255,255,0.07)";
constexpr char kDefaultTooltipBackground[] = "rgba(0,0,0,0.8)";
constexpr char kDefaultTooltipForeground[] = "#FFFFFF";
constexpr char kDefaultTooltipBorder[] = "rgba(255,255,255,0.1)";
constexpr gdouble kDefaultTooltipRadius = 8.0;
constexpr gdouble kDefaultTooltipFontSize = 14.0;
constexpr gdouble kDefaultTooltipHorizontalPadding = 10.0;
constexpr gdouble kDefaultTooltipVerticalPadding = 6.0;
constexpr gdouble kDefaultTooltipMinimumHeight = 30.0;
constexpr gdouble kTooltipBorderWidth = 1.0;
// GtkTooltipWindow applies a private GtkContainer border-width of 6 px around
// its content. Compensate for it so retained GTK hints have the same visible
// border-to-text padding as Flutter tooltips.
constexpr gdouble kGtkTooltipContainerInset = 6.0;
constexpr char kMenuAccelAttribute[] = "accel";
constexpr char kNativeDialogStyleClass[] = "busydata-native-dialog";
// Mirrors Yaru's shared window/dialog radius used by the Flutter fallback.
constexpr gint kNativeDialogCornerRadius = 14;
constexpr char kNativeTimeZoneDialogStyleClass[] =
    "busydata-time-zone-dialog";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  gboolean start_minimized;
  FlMethodChannel* native_menu_channel;
  FlMethodChannel* window_channel;
  BusyDataWindowClose* window_close;
  FlMethodChannel* gtk_settings_channel;
  FlMethodChannel* gtk_header_icons_channel;
  FlEventChannel* gtk_font_settings_event_channel;
  FlEventChannel* gtk_theme_colors_event_channel;
  FlEventChannel* gtk_animation_settings_event_channel;
  FlEventChannel* gtk_window_preferences_event_channel;
  FlEventChannel* gtk_header_icons_changed_event_channel;
  BusyDataGtkWindowPreferencesWatcher* gtk_window_preferences;
  BusyDataGtkHeaderIcons* gtk_header_icons;
  gulong gtk_font_settings_signal_id;
  gulong gtk_theme_name_signal_id;
  gulong gtk_theme_dark_signal_id;
  gulong gtk_animation_settings_signal_id;
  gboolean gtk_font_settings_listening;
  gboolean gtk_theme_colors_listening;
  gboolean gtk_animation_settings_listening;
  gboolean gtk_window_preferences_listening;
  gboolean gtk_header_icons_listening;
  gint64 gtk_header_icons_revision;
  GtkCssProvider* native_surface_css_provider;
  gchar* native_surface_window_background_color;
  gchar* native_surface_dialog_background_color;
  gchar* native_surface_dialog_outline_color;
  gchar* native_surface_tooltip_background_color;
  gchar* native_surface_tooltip_foreground_color;
  gchar* native_surface_tooltip_border_color;
  gdouble native_surface_tooltip_radius;
  gdouble native_surface_tooltip_font_size;
  gdouble native_surface_tooltip_horizontal_padding;
  gdouble native_surface_tooltip_vertical_padding;
  gdouble native_surface_tooltip_minimum_height;
  gboolean native_surface_high_contrast;
  gboolean native_surface_theme_received;
  GtkWindow* main_window;
  GtkWidget* flutter_view;
  gboolean hide_on_close;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* gtk_accelerator_from_shortcut_label(const gchar* shortcut) {
  if (shortcut == nullptr || shortcut[0] == '\0') {
    return nullptr;
  }

  guint key = 0;
  GdkModifierType modifiers = static_cast<GdkModifierType>(0);
  gtk_accelerator_parse(shortcut, &key, &modifiers);
  if (key != 0) {
    return g_strdup(shortcut);
  }

  gchar** parts = g_strsplit(shortcut, "+", -1);
  const gsize part_count = g_strv_length(parts);
  GString* accelerator = g_string_new(nullptr);
  gboolean valid = part_count > 0;
  for (gsize index = 0; valid && index + 1 < part_count; index++) {
    const gchar* part = g_strstrip(parts[index]);
    if (g_strcmp0(part, "Ctrl") == 0 ||
        g_strcmp0(part, "Control") == 0) {
      g_string_append(accelerator, "<Control>");
    } else if (g_strcmp0(part, "Alt") == 0) {
      g_string_append(accelerator, "<Alt>");
    } else if (g_strcmp0(part, "Shift") == 0) {
      g_string_append(accelerator, "<Shift>");
    } else if (g_strcmp0(part, "Super") == 0) {
      g_string_append(accelerator, "<Super>");
    } else if (g_strcmp0(part, "Meta") == 0) {
      g_string_append(accelerator, "<Meta>");
    } else {
      valid = FALSE;
    }
  }
  if (valid) {
    const gchar* key_label = g_strstrip(parts[part_count - 1]);
    g_string_append(accelerator,
                    g_strcmp0(key_label, "Esc") == 0 ? "Escape" : key_label);
    key = 0;
    modifiers = static_cast<GdkModifierType>(0);
    gtk_accelerator_parse(accelerator->str, &key, &modifiers);
    valid = key != 0;
  }

  g_strfreev(parts);
  return g_string_free(accelerator, !valid);
}

static void set_menu_item_accelerator(GMenuItem* item,
                                      const gchar* shortcut) {
  g_autofree gchar* accelerator =
      gtk_accelerator_from_shortcut_label(shortcut);
  if (accelerator != nullptr) {
    g_menu_item_set_attribute(item, kMenuAccelAttribute, "s", accelerator);
  }
}

static GdkPixbuf* load_application_icon() { return nullptr; }

static void set_gtk_theme_preference(gboolean prefer_dark) {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) {
    return;
  }

  // Express the app preference through GTK. Do not replace the user's GTK or
  // icon theme: GTK remains responsible for resolving the installed theme's
  // light/dark presentation and its native assets.
  g_object_set(settings, "gtk-application-prefer-dark-theme", prefer_dark,
               nullptr);
}

static const gchar* fl_lookup_string_arg(FlValue* args, const gchar* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}



static gboolean fl_lookup_optional_bool_arg(FlValue* args,
                                            const gchar* key,
                                            gboolean* value_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return FALSE;
  }
  *value_out = fl_value_get_bool(value);
  return TRUE;
}



static gboolean fl_lookup_double_arg(FlValue* args,
                                     const gchar* key,
                                     gdouble* value_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) {
    return FALSE;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
    *value_out = fl_value_get_float(value);
    return TRUE;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    *value_out = static_cast<gdouble>(fl_value_get_int(value));
    return TRUE;
  }
  return FALSE;
}

static void update_bounded_double_arg(FlValue* args,
                                      const gchar* key,
                                      gdouble minimum,
                                      gdouble maximum,
                                      gdouble* target) {
  gdouble value = 0;
  if (fl_lookup_double_arg(args, key, &value) && value >= minimum &&
      value <= maximum) {
    *target = value;
  }
}

static void respond_bool(FlMethodCall* call, gboolean value) {
 g_autoptr(FlValue) result = fl_value_new_bool(value);
 g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
 fl_method_call_respond(call,response,nullptr);
}

struct NativeMenuHandlerData;

struct NativeMenuSession {
  NativeMenuHandlerData* owner;
  gint64 id;
  size_t entry_count;
  GtkWidget* menu;
  GMenu* model;
  GSimpleActionGroup* action_group;
  FlMethodCall* method_call;
  gulong deactivate_signal_id;
  gulong key_release_signal_id;
  guint cleanup_source_id;
  gint pending_selected_index;
};

struct NativeMenuHandlerData {
  GtkWidget* view;
  NativeMenuSession* active;
  GdkEvent* trigger_event;
  gulong trigger_event_signal_id;
  // GdkEventKey uses a 16-bit hardware keycode. One bounded bitmap belongs to
  // the existing view; popup navigation keys never enter this ledger.
  guint64 view_keys_down[1024];
};

static void native_menu_event_after_cb(GtkWidget*,
                                       GdkEvent* event,
                                       gpointer user_data) {
  auto* data = static_cast<NativeMenuHandlerData*>(user_data);
  if (event->type == GDK_FOCUS_CHANGE && !event->focus_change.in &&
      data->active == nullptr) {
    memset(data->view_keys_down, 0, sizeof(data->view_keys_down));
  }
  if (event->type == GDK_KEY_PRESS || event->type == GDK_KEY_RELEASE) {
    const guint code = event->key.hardware_keycode;
    const guint64 bit = G_GUINT64_CONSTANT(1) << (code % 64);
    if (event->type == GDK_KEY_PRESS) {
      data->view_keys_down[code / 64] |= bit;
    } else {
      data->view_keys_down[code / 64] &= ~bit;
    }
  }
  switch (event->type) {
    case GDK_BUTTON_PRESS:
    case GDK_BUTTON_RELEASE:
    case GDK_KEY_PRESS:
    case GDK_KEY_RELEASE:
    case GDK_TOUCH_BEGIN:
    case GDK_TOUCH_END:
      break;
    default:
      return;
  }
  g_clear_pointer(&data->trigger_event, gdk_event_free);
  data->trigger_event = gdk_event_copy(event);
}

static gboolean native_menu_key_release_cb(GtkWidget*, GdkEventKey* event,
                                            gpointer user_data) {
  auto* session = static_cast<NativeMenuSession*>(user_data);
  auto* owner = session->owner;
  if (owner == nullptr || owner->active != session || owner->view == nullptr ||
      !gtk_widget_get_realized(owner->view)) {
    return FALSE;
  }
  const guint code = event->hardware_keycode;
  const guint64 bit = G_GUINT64_CONSTANT(1) << (code % 64);
  if ((owner->view_keys_down[code / 64] & bit) == 0) {
    return FALSE;
  }
  owner->view_keys_down[code / 64] &= ~bit;
  // GtkMenu's grab can consume the release of Menu, F10 or an opening
  // modifier after FlView received its press. Return only that actual physical
  // release to the same view, retaining keycode, state, group and timestamp.
  // Otherwise the next Menu press becomes a repeat in Flutter. Do not forward
  // popup navigation presses/releases or synthesize an activation/focus event.
  GdkEvent* forwarded = gdk_event_copy(reinterpret_cast<GdkEvent*>(event));
  g_clear_object(&forwarded->key.window);
  forwarded->key.window =
      GDK_WINDOW(g_object_ref(gtk_widget_get_window(owner->view)));
  gtk_widget_event(owner->view, forwarded);
  gdk_event_free(forwarded);
  return FALSE;
}

static void native_menu_session_respond(NativeMenuSession* session,
                                        gint selected_index) {
  if (session->method_call == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = selected_index < 0
                                  ? fl_value_new_null()
                                  : fl_value_new_int(selected_index);
  fl_method_call_respond_success(session->method_call, result, nullptr);
  g_clear_object(&session->method_call);
}

static void native_menu_session_dispose(NativeMenuSession* session) {
  if (session == nullptr) {
    return;
  }
  g_log("BusyDataNativeMenu", G_LOG_LEVEL_DEBUG,
        "dispose id=%" G_GINT64_FORMAT " selected=%d", session->id,
        session->pending_selected_index);

  NativeMenuHandlerData* owner = session->owner;
  if (owner != nullptr && owner->active == session) {
    owner->active = nullptr;
  }

  if (session->cleanup_source_id != 0) {
    g_source_remove(session->cleanup_source_id);
    session->cleanup_source_id = 0;
  }
  if (session->menu != nullptr) {
    if (session->key_release_signal_id != 0) {
      g_signal_handler_disconnect(session->menu, session->key_release_signal_id);
      session->key_release_signal_id = 0;
    }
    if (session->deactivate_signal_id != 0) {
      g_signal_handler_disconnect(session->menu,
                                  session->deactivate_signal_id);
      session->deactivate_signal_id = 0;
    }
    if (gtk_widget_get_visible(session->menu)) {
      gtk_menu_popdown(GTK_MENU(session->menu));
    }
  }
  if (owner != nullptr && owner->view != nullptr) {
    gtk_widget_insert_action_group(owner->view,
                                   kNativeMenuActionNamespace, nullptr);
  }
  if (session->menu != nullptr && GTK_IS_MENU(session->menu) &&
      gtk_menu_get_attach_widget(GTK_MENU(session->menu)) != nullptr) {
    gtk_menu_detach(GTK_MENU(session->menu));
  }
  if (session->menu != nullptr) {
    gtk_widget_destroy(session->menu);
  }
  g_clear_object(&session->menu);
  if (owner != nullptr && owner->view != nullptr) {
    if (gtk_widget_get_realized(owner->view)) {
      gtk_widget_grab_focus(owner->view);
    }
  }
  g_clear_object(&session->model);
  g_clear_object(&session->action_group);
  // Resolve the Dart future only after the native session is fully retired.
  // A resumed caller may immediately open another menu.
  native_menu_session_respond(session, session->pending_selected_index);
  g_free(session);
}

static gboolean native_menu_cleanup_idle_cb(gpointer user_data) {
  auto* session = static_cast<NativeMenuSession*>(user_data);
  session->cleanup_source_id = 0;
  native_menu_session_dispose(session);
  return G_SOURCE_REMOVE;
}

static void native_menu_deactivate_cb(GtkMenuShell*, gpointer user_data) {
  auto* session = static_cast<NativeMenuSession*>(user_data);
  g_log("BusyDataNativeMenu", G_LOG_LEVEL_DEBUG,
        "deactivate id=%" G_GINT64_FORMAT, session->id);
  if (session->cleanup_source_id == 0) {
    // GtkMenu deactivates before it invokes the selected GAction. Resolve the
    // Dart result after GTK has released its grab and the action has run.
    session->cleanup_source_id = g_idle_add_full(
        G_PRIORITY_DEFAULT_IDLE, native_menu_cleanup_idle_cb, session, nullptr);
  }
}

static void native_menu_finish_selection(NativeMenuSession* session) {
  // Accessibility activation can invoke GAction without GtkMenuShell's normal
  // pointer/key deactivation. Retire the popup before acknowledging the choice.
  if (gtk_widget_get_visible(session->menu)) {
    gtk_menu_popdown(GTK_MENU(session->menu));
  }
  if (session->cleanup_source_id == 0) {
    session->cleanup_source_id = g_idle_add_full(
        G_PRIORITY_DEFAULT_IDLE, native_menu_cleanup_idle_cb, session, nullptr);
  }
}

static void native_menu_action_activated_cb(GSimpleAction* action,
                                            GVariant*,
                                            gpointer user_data) {
  auto* session = static_cast<NativeMenuSession*>(user_data);
  g_autoptr(GVariant) state = g_action_get_state(G_ACTION(action));
  if (state != nullptr &&
      g_variant_is_of_type(state, G_VARIANT_TYPE_BOOLEAN)) {
    g_simple_action_set_state(
        action, g_variant_new_boolean(!g_variant_get_boolean(state)));
  }
  session->pending_selected_index =
      GPOINTER_TO_INT(
          g_object_get_data(G_OBJECT(action), kNativeMenuActionIndexKey)) -
      1;
  native_menu_finish_selection(session);
}

static gboolean native_menu_dismiss_active(NativeMenuHandlerData* data,
                                           gint64 session_id) {
  NativeMenuSession* session = data->active;
  g_log("BusyDataNativeMenu", G_LOG_LEVEL_DEBUG,
        "dismiss-request id=%" G_GINT64_FORMAT " active=%" G_GINT64_FORMAT,
        session_id, session == nullptr ? 0 : session->id);
  if (session == nullptr || session->id != session_id) {
    return FALSE;
  }

  if (session->menu != nullptr && gtk_widget_get_visible(session->menu)) {
    gtk_menu_shell_deactivate(GTK_MENU_SHELL(session->menu));
  } else {
    native_menu_session_dispose(session);
  }
  return TRUE;
}

static gboolean fl_lookup_number_arg(FlValue* args,
                                     const gchar* key,
                                     gdouble* value_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) {
    return FALSE;
  }
  switch (fl_value_get_type(value)) {
    case FL_VALUE_TYPE_FLOAT:
      *value_out = fl_value_get_float(value);
      return std::isfinite(*value_out);
    case FL_VALUE_TYPE_INT:
      *value_out = static_cast<gdouble>(fl_value_get_int(value));
      return TRUE;
    default:
      return FALSE;
  }
}

static gboolean fl_lookup_optional_bool_arg(FlValue* args,
                                            const gchar* key,
                                            gboolean fallback,
                                            gboolean* value_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) {
    *value_out = fallback;
    return TRUE;
  }
  if (fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
    return FALSE;
  }
  *value_out = fl_value_get_bool(value);
  return TRUE;
}

static gboolean fl_lookup_positive_int64_arg(FlValue* args,
                                             const gchar* key,
                                             gint64* value_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return FALSE;
  }
  const gint64 parsed = fl_value_get_int(value);
  if (parsed <= 0) {
    return FALSE;
  }
  *value_out = parsed;
  return TRUE;
}

static void respond_native_menu_argument_error(FlMethodCall* method_call,
                                               const gchar* message) {
  fl_method_call_respond_error(method_call, "invalid-arguments", message,
                               nullptr, nullptr);
}

static gboolean parse_native_menu_anchor(FlValue* args,
                                         GdkRectangle* rectangle_out) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* anchor = fl_value_lookup_string(args, "anchor");
  if (anchor == nullptr || fl_value_get_type(anchor) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  gdouble x = 0;
  gdouble y = 0;
  gdouble width = 0;
  gdouble height = 0;
  const gboolean has_x = fl_lookup_number_arg(anchor, "x", &x) ||
                         fl_lookup_number_arg(anchor, "left", &x);
  const gboolean has_y = fl_lookup_number_arg(anchor, "y", &y) ||
                         fl_lookup_number_arg(anchor, "top", &y);
  if (!has_x || !has_y ||
      !fl_lookup_number_arg(anchor, "width", &width) ||
      !fl_lookup_number_arg(anchor, "height", &height) || width < 0 ||
      height < 0 || !std::isfinite(x + width) ||
      !std::isfinite(y + height)) {
    return FALSE;
  }

  const gdouble left = std::floor(x);
  const gdouble top = std::floor(y);
  const gdouble right = std::ceil(x + width);
  const gdouble bottom = std::ceil(y + height);
  const gdouble pixel_width = std::max(1.0, right - left);
  const gdouble pixel_height = std::max(1.0, bottom - top);
  if (left < G_MININT || left > G_MAXINT || top < G_MININT ||
      top > G_MAXINT || right < G_MININT || right > G_MAXINT ||
      bottom < G_MININT || bottom > G_MAXINT || pixel_width > G_MAXINT ||
      pixel_height > G_MAXINT) {
    return FALSE;
  }

  rectangle_out->x = static_cast<gint>(left);
  rectangle_out->y = static_cast<gint>(top);
  rectangle_out->width = static_cast<gint>(pixel_width);
  rectangle_out->height = static_cast<gint>(pixel_height);
  return TRUE;
}

static GIcon* create_native_menu_icon(const gchar* icon_name, FlValue* entry) {
  if (icon_name == nullptr || icon_name[0] == '\0') {
    return nullptr;
  }

  FlValue* packed_color = fl_value_lookup_string(entry, "iconColor");
  GdkRGBA foreground = {0.5, 0.5, 0.5, 1.0};
  if (packed_color != nullptr &&
      fl_value_get_type(packed_color) == FL_VALUE_TYPE_INT) {
    const guint32 argb = static_cast<guint32>(fl_value_get_int(packed_color));
    foreground = {
        static_cast<gdouble>((argb >> 16) & 0xff) / 255.0,
        static_cast<gdouble>((argb >> 8) & 0xff) / 255.0,
        static_cast<gdouble>(argb & 0xff) / 255.0,
        static_cast<gdouble>((argb >> 24) & 0xff) / 255.0,
    };
  }

  if (packed_color != nullptr &&
      fl_value_get_type(packed_color) == FL_VALUE_TYPE_INT) {
    GtkIconInfo* icon_info = gtk_icon_theme_lookup_icon(
        gtk_icon_theme_get_default(), icon_name, 16,
        static_cast<GtkIconLookupFlags>(GTK_ICON_LOOKUP_FORCE_SIZE |
                                        GTK_ICON_LOOKUP_FORCE_SYMBOLIC));
    if (icon_info != nullptr) {
      gboolean was_symbolic = FALSE;
      g_autoptr(GError) error = nullptr;
      GdkPixbuf* pixbuf = gtk_icon_info_load_symbolic(
          icon_info, &foreground, nullptr, nullptr, nullptr, &was_symbolic,
          &error);
      g_object_unref(icon_info);
      if (pixbuf != nullptr) {
        return G_ICON(pixbuf);
      }
    }
  }

  return g_themed_icon_new(icon_name);
}

static gboolean validate_native_menu_entries(FlValue* entries,
                                              FlMethodCall* method_call,
                                              guint depth,
                                              size_t* entry_count) {
  if (depth > 8 || entries == nullptr ||
      fl_value_get_type(entries) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(entries) == 0 ||
      fl_value_get_length(entries) > 4096 - *entry_count) {
    respond_native_menu_argument_error(method_call, "Invalid or excessive submenu entries.");
    return FALSE;
  }
  *entry_count += fl_value_get_length(entries);
  size_t command_count = 0;
  size_t checkable_run_selected_count = 0;
  gboolean in_checkable_run = FALSE;
  for (size_t index = 0; index < fl_value_get_length(entries); index++) {
    FlValue* entry = fl_value_get_list_value(entries, index);
    if (entry == nullptr || fl_value_get_type(entry) != FL_VALUE_TYPE_MAP) {
      respond_native_menu_argument_error(method_call, "Menu entries must be maps.");
      return FALSE;
    }
    FlValue* children = fl_value_lookup_string(entry, "children");
    FlValue* icon_color = entry == nullptr
                              ? nullptr
                              : fl_value_lookup_string(entry, "iconColor");
    gboolean separator = FALSE;
    gboolean enabled = TRUE;
    gboolean checkable = FALSE;
    gboolean selected = FALSE;
    gboolean mutually_exclusive = FALSE;
    if (entry == nullptr || fl_value_get_type(entry) != FL_VALUE_TYPE_MAP ||
        !fl_lookup_optional_bool_arg(entry, "separator", FALSE,
                                              &separator) ||
        !fl_lookup_optional_bool_arg(entry, "enabled", TRUE,
                                              &enabled) ||
        !fl_lookup_optional_bool_arg(entry, "checkable", FALSE,
                                              &checkable) ||
        !fl_lookup_optional_bool_arg(entry, "selected", FALSE,
                                              &selected) ||
        !fl_lookup_optional_bool_arg(entry, "mutuallyExclusive",
                                              FALSE,
                                              &mutually_exclusive) ||
        (!separator && fl_lookup_string_arg(entry, "label") == nullptr) ||
        (fl_value_lookup_string(entry, "icon") != nullptr &&
         fl_value_get_type(fl_value_lookup_string(entry, "icon")) !=
             FL_VALUE_TYPE_STRING) ||
        (icon_color != nullptr &&
         (fl_value_get_type(icon_color) != FL_VALUE_TYPE_INT ||
          fl_value_get_int(icon_color) < 0 ||
          fl_value_get_int(icon_color) >
              static_cast<gint64>(G_MAXUINT32))) ||
        (fl_value_lookup_string(entry, "tooltip") != nullptr &&
         (fl_lookup_string_arg(entry, "tooltip") == nullptr ||
          strlen(fl_lookup_string_arg(entry, "tooltip")) > 4096)) ||
        (selected && !checkable) ||
        (children != nullptr && (separator || checkable)) ||
        (fl_value_lookup_string(entry, "gtkAccelerator") != nullptr &&
         fl_lookup_string_arg(entry, "gtkAccelerator") == nullptr) ||
        (fl_value_lookup_string(entry, "shortcut") != nullptr &&
         fl_lookup_string_arg(entry, "shortcut") == nullptr)) {
      respond_native_menu_argument_error(
          method_call,
          "entries must contain valid command or separator presentation.");
      return FALSE;
    }
    if (children != nullptr &&
        !validate_native_menu_entries(children, method_call, depth + 1, entry_count)) {
      return FALSE;
    }
    if (!separator) {
      command_count++;
    }
    if (!separator && checkable && mutually_exclusive) {
      if (!in_checkable_run) {
        checkable_run_selected_count = 0;
        in_checkable_run = TRUE;
      }
      checkable_run_selected_count += selected ? 1 : 0;
      continue;
    }
    if (in_checkable_run &&
        checkable_run_selected_count > 1) {
      respond_native_menu_argument_error(
          method_call,
          "single-choice groups allow at most one selected entry.");
      return FALSE;
    }
    in_checkable_run = FALSE;
  }
  if (in_checkable_run &&
      checkable_run_selected_count > 1) {
    respond_native_menu_argument_error(
        method_call,
        "single-choice groups allow at most one selected entry.");
    return FALSE;
  }
  if (command_count == 0) {
    respond_native_menu_argument_error(method_call,
                                       "entries must contain a command.");
    return FALSE;
  }

  return TRUE;
}

static gchar* escape_native_menu_label(const gchar* label) {
  GString* literal = g_string_new(nullptr);
  for (const gchar* cursor = label; *cursor != '\0'; cursor++) {
    if (*cursor == '_') {
      g_string_append_c(literal, '_');
    }
    g_string_append_c(literal, *cursor);
  }
  return g_string_free(literal, FALSE);
}

static void build_native_menu_model(FlValue* entries,
                                     NativeMenuSession* session,
                                     GMenu* model,
                                     size_t* next_index,
                                     gboolean ancestors_enabled) {
  GMenu* section = g_menu_new();
  guint section_length = 0;
  auto flush_section = [&]() {
    if (section_length > 0) {
      g_menu_append_section(model, nullptr, G_MENU_MODEL(section));
    }
    g_object_unref(section);
    section = g_menu_new();
    section_length = 0;
  };

  for (size_t index = 0; index < fl_value_get_length(entries); index++) {
    FlValue* entry = fl_value_get_list_value(entries, index);
    gboolean separator = FALSE;
    fl_lookup_optional_bool_arg(entry, "separator", FALSE,
                                         &separator);
    if (separator) {
      flush_section();
      (*next_index)++;
      continue;
    }

    const size_t entry_index = (*next_index)++;
    const gchar* label = fl_lookup_string_arg(entry, "label");
    // GMenu's GtkMenu adapter treats underscores as mnemonic markers. Flutter
    // labels are literal presentation text, so double every underscore only at
    // this native boundary; action indexes and clipboard payloads stay intact.
    g_autofree gchar* literal_label = escape_native_menu_label(label);
    const gchar* icon_name = fl_lookup_string_arg(entry, "icon");
    // Accelerator metadata is generated from logical keys in Dart. GMenu uses
    // it for display; Flutter remains the single command dispatch mechanism.
    const gchar* shortcut = fl_lookup_string_arg(entry, "gtkAccelerator");
    if (shortcut == nullptr) shortcut = fl_lookup_string_arg(entry, "shortcut");
    gboolean enabled = TRUE;
    gboolean checkable = FALSE;
    gboolean selected = FALSE;
    fl_lookup_optional_bool_arg(entry, "enabled", TRUE, &enabled);
    fl_lookup_optional_bool_arg(entry, "checkable", FALSE,
                                         &checkable);
    fl_lookup_optional_bool_arg(entry, "selected", FALSE,
                                         &selected);

    FlValue* children = fl_value_lookup_string(entry, "children");
    if (children != nullptr) {
      g_autoptr(GMenu) submenu = g_menu_new();
      build_native_menu_model(children, session, submenu, next_index,
                              ancestors_enabled && enabled);
      g_autoptr(GMenuItem) item =
          g_menu_item_new_submenu(literal_label, G_MENU_MODEL(submenu));
      g_menu_append_item(section, item);
      section_length++;
      continue;
    }
    g_autofree gchar* action_name = g_strdup_printf("select-%zu", entry_index);
    GSimpleAction* action = checkable
                                ? g_simple_action_new_stateful(
                                      action_name, nullptr,
                                      g_variant_new_boolean(selected))
                                : g_simple_action_new(action_name, nullptr);
    g_simple_action_set_enabled(action, ancestors_enabled && enabled);
    g_object_set_data(G_OBJECT(action), kNativeMenuActionIndexKey,
                      GINT_TO_POINTER(static_cast<gint>(entry_index) + 1));
    g_signal_connect(
        action, "activate",
        G_CALLBACK(native_menu_action_activated_cb),
        session);
    g_action_map_add_action(G_ACTION_MAP(session->action_group),
                            G_ACTION(action));

    g_autofree gchar* detailed_action =
        g_strdup_printf("%s.%s", kNativeMenuActionNamespace, action_name);
    g_autoptr(GMenuItem) item =
        g_menu_item_new(literal_label, detailed_action);
    if (icon_name != nullptr && icon_name[0] != '\0') {
      g_autoptr(GIcon) icon = create_native_menu_icon(icon_name, entry);
      g_menu_item_set_icon(item, icon);
    }
    if (shortcut != nullptr && shortcut[0] != '\0') {
      set_menu_item_accelerator(item, shortcut);
    }
    g_menu_append_item(section, item);
    g_object_unref(action);
    section_length++;
  }
  flush_section();
  g_object_unref(section);

}


// GtkMenu's model adapter does not bind submenu-heading sensitivity to an
// action. Apply availability to those actual GTK widgets, in model order.
// Sections can coalesce separators, so separators never consume a command row.
static gboolean set_native_submenu_availability(GtkWidget* menu,
                                                FlValue* entries,
                                                gboolean ancestors_enabled) {
  GList* rows = gtk_container_get_children(GTK_CONTAINER(menu));
  GList* row = rows;
  gboolean valid = TRUE;
  for (size_t index = 0; index < fl_value_get_length(entries); index++) {
    FlValue* entry = fl_value_get_list_value(entries, index);
    gboolean separator = FALSE;
    gboolean enabled = TRUE;
    fl_lookup_optional_bool_arg(entry, "separator", FALSE, &separator);
    if (separator) continue;
    while (row != nullptr && GTK_IS_SEPARATOR_MENU_ITEM(row->data)) row = row->next;
    if (row == nullptr || !GTK_IS_MENU_ITEM(row->data)) {
      valid = FALSE;
      break;
    }
    fl_lookup_optional_bool_arg(entry, "enabled", TRUE, &enabled);
    const gchar* tooltip = fl_lookup_string_arg(entry, "tooltip");
    if (tooltip != nullptr) {
      GtkWidget* item = GTK_WIDGET(row->data);
      gtk_widget_set_tooltip_text(item, tooltip);
      atk_object_set_description(gtk_widget_get_accessible(item), tooltip);
    }
    FlValue* children = fl_value_lookup_string(entry, "children");
    if (children != nullptr) {
      GtkWidget* submenu = gtk_menu_item_get_submenu(GTK_MENU_ITEM(row->data));
      gtk_widget_set_sensitive(GTK_WIDGET(row->data), ancestors_enabled && enabled);
      if (submenu == nullptr || !GTK_IS_MENU(submenu) ||
          !set_native_submenu_availability(submenu, children, ancestors_enabled && enabled)) {
        valid = FALSE;
        break;
      }
    }
    row = row->next;
  }
  g_list_free(rows);
  return valid;
}

static void set_native_menu_direction(GtkWidget* widget, gpointer data) {
  gtk_widget_set_direction(widget, static_cast<GtkTextDirection>(GPOINTER_TO_INT(data)));
  if (GTK_IS_MENU_ITEM(widget)) {
    GtkWidget* submenu = gtk_menu_item_get_submenu(GTK_MENU_ITEM(widget));
    if (submenu != nullptr) set_native_menu_direction(submenu, data);
  }
  if (GTK_IS_CONTAINER(widget)) {
    gtk_container_foreach(GTK_CONTAINER(widget), set_native_menu_direction, data);
  }
}

static void show_native_menu(NativeMenuHandlerData* data,
                             FlMethodCall* method_call,
                             FlValue* args) {
  if (data->view == nullptr || !gtk_widget_get_realized(data->view) ||
      gtk_widget_get_window(data->view) == nullptr) {
    fl_method_call_respond_error(method_call, "unavailable",
                                 "The native menu host is unavailable.",
                                 nullptr, nullptr);
    return;
  }
  GdkRectangle anchor = {};
  gint64 session_id = 0;
  if (!fl_lookup_positive_int64_arg(args, "sessionId", &session_id) ||
      !parse_native_menu_anchor(args, &anchor)) {
    respond_native_menu_argument_error(
        method_call,
        "sessionId must be positive and anchor must contain finite geometry.");
    return;
  }

  GtkWidget* toplevel = gtk_widget_get_toplevel(data->view);
  GdkWindow* rect_window =
      GTK_IS_WINDOW(toplevel) ? gtk_widget_get_window(toplevel) : nullptr;
  GdkRectangle window_anchor = anchor;
  if (rect_window == nullptr ||
      !gtk_widget_translate_coordinates(
          data->view, toplevel, anchor.x, anchor.y, &window_anchor.x,
          &window_anchor.y)) {
    fl_method_call_respond_error(
        method_call, "unavailable",
        "GTK could not translate the menu anchor into window coordinates.",
        nullptr, nullptr);
    return;
  }

  FlValue* entries = fl_value_lookup_string(args, "entries");
  const gchar* direction_arg = fl_lookup_string_arg(args, "textDirection");
  if (fl_value_lookup_string(args, "textDirection") != nullptr &&
      g_strcmp0(direction_arg, "ltr") != 0 &&
      g_strcmp0(direction_arg, "rtl") != 0) {
    respond_native_menu_argument_error(method_call, "textDirection must be ltr or rtl.");
    return;
  }
  const GtkTextDirection direction = direction_arg == nullptr
      ? gtk_widget_get_direction(data->view)
      : (g_strcmp0(direction_arg, "rtl") == 0 ? GTK_TEXT_DIR_RTL : GTK_TEXT_DIR_LTR);
  gboolean focus_first = FALSE;
  const gchar* preferred_position_arg =
      fl_lookup_string_arg(args, "preferredPosition");
  GtkPositionType preferred_position = GTK_POS_BOTTOM;
  if (g_strcmp0(preferred_position_arg, "top") == 0) {
    preferred_position = GTK_POS_TOP;
  } else if (preferred_position_arg != nullptr &&
             g_strcmp0(preferred_position_arg, "bottom") != 0) {
    respond_native_menu_argument_error(
        method_call, "preferredPosition must be top or bottom.");
    return;
  }
  if (entries == nullptr ||
      fl_value_get_type(entries) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(entries) == 0 ||
      fl_value_get_length(entries) > static_cast<size_t>(G_MAXINT) ||
      !fl_lookup_optional_bool_arg(args, "focusFirst", FALSE,
                                            &focus_first)) {
    respond_native_menu_argument_error(
        method_call,
        "entries must be non-empty and focusFirst must be boolean.");
    return;
  }

  size_t entry_count = 0;
  if (!validate_native_menu_entries(entries, method_call, 0, &entry_count)) return;
  if (data->active != nullptr) {
    native_menu_session_dispose(data->active);
  }

  auto* session = g_new0(NativeMenuSession, 1);
  session->owner = data;
  session->id = session_id;
  session->entry_count = entry_count;
  session->pending_selected_index = -1;
  session->method_call =
      FL_METHOD_CALL(g_object_ref(G_OBJECT(method_call)));
  session->action_group = g_simple_action_group_new();
  session->model = g_menu_new();
  data->active = session;

  size_t next_index = 0;
  build_native_menu_model(entries, session, session->model, &next_index, TRUE);
  // GtkPopover maps as a Wayland subsurface whose frame callback can stall
  // while Flutter's parent surface is idle. GtkMenu maps as an independent
  // native xdg_popup instead.
  gtk_widget_insert_action_group(
      data->view, kNativeMenuActionNamespace,
      G_ACTION_GROUP(session->action_group));
  session->menu = gtk_menu_new_from_model(G_MENU_MODEL(session->model));
  if (session->menu == nullptr || !GTK_IS_MENU(session->menu)) {
    fl_method_call_respond_error(method_call, "unavailable",
                                 "GTK could not create the native menu.",
                                 nullptr, nullptr);
    g_clear_object(&session->method_call);
    native_menu_session_dispose(session);
    return;
  }
  g_object_ref_sink(session->menu);
  gtk_menu_attach_to_widget(GTK_MENU(session->menu), data->view, nullptr);
  set_native_menu_direction(session->menu, GINT_TO_POINTER(direction));
  gtk_widget_show_all(session->menu);
  if (!set_native_submenu_availability(session->menu, entries, TRUE)) {
    fl_method_call_respond_error(method_call, "invalid-menu",
                                 "GTK menu rows do not match the menu model.",
                                 nullptr, nullptr);
    g_clear_object(&session->method_call);
    native_menu_session_dispose(session);
    return;
  }
  session->deactivate_signal_id = g_signal_connect(
      session->menu, "deactivate", G_CALLBACK(native_menu_deactivate_cb),
      session);

  session->key_release_signal_id = g_signal_connect(
      session->menu, "key-release-event",
      G_CALLBACK(native_menu_key_release_cb), session);

  const gboolean open_above = preferred_position == GTK_POS_TOP;
  const gboolean rtl = direction == GTK_TEXT_DIR_RTL;
  g_object_set(session->menu, "anchor-hints",
               GDK_ANCHOR_FLIP_Y | GDK_ANCHOR_SLIDE | GDK_ANCHOR_RESIZE,
               nullptr);
  if (!open_above) {
    g_object_set(session->menu, "menu-type-hint",
                 GDK_WINDOW_TYPE_HINT_DROPDOWN_MENU, nullptr);
  }
  // Flutter reports view-local coordinates, while FlView is a no-window
  // widget below the native titlebar. Use the translated toplevel rectangle
  // directly instead of a hidden proxy whose GTK allocation is deferred.
  gtk_menu_popup_at_rect(
      GTK_MENU(session->menu), rect_window, &window_anchor,
      open_above ? (rtl ? GDK_GRAVITY_NORTH_EAST : GDK_GRAVITY_NORTH_WEST)
                 : (rtl ? GDK_GRAVITY_SOUTH_EAST : GDK_GRAVITY_SOUTH_WEST),
      open_above ? (rtl ? GDK_GRAVITY_SOUTH_EAST : GDK_GRAVITY_SOUTH_WEST)
                 : (rtl ? GDK_GRAVITY_NORTH_EAST : GDK_GRAVITY_NORTH_WEST),
      data->trigger_event);
  if (focus_first) {
    gtk_menu_shell_select_first(GTK_MENU_SHELL(session->menu), TRUE);
  } else {
    gtk_menu_shell_deselect(GTK_MENU_SHELL(session->menu));
  }
}

static void native_menu_handler_data_free(gpointer user_data) {
  auto* data = static_cast<NativeMenuHandlerData*>(user_data);
  if (data->active != nullptr) {
    native_menu_session_dispose(data->active);
  }
  if (data->view != nullptr) {
    if (data->trigger_event_signal_id != 0) {
      g_signal_handler_disconnect(data->view,
                                  data->trigger_event_signal_id);
    }
    g_object_remove_weak_pointer(
        G_OBJECT(data->view),
        reinterpret_cast<gpointer*>(&data->view));
  }
  g_clear_pointer(&data->trigger_event, gdk_event_free);
  g_free(data);
}

static void native_menu_method_call_cb(FlMethodChannel*,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  auto* data = static_cast<NativeMenuHandlerData*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "show") == 0) {
    show_native_menu(data, method_call, fl_method_call_get_args(method_call));
  } else if (strcmp(method, "dismiss") == 0) {
    gint64 session_id = 0;
    if (!fl_lookup_positive_int64_arg(fl_method_call_get_args(method_call),
                                      "sessionId", &session_id)) {
      respond_native_menu_argument_error(
          method_call, "sessionId must be a positive integer.");
      return;
    }
    respond_bool(method_call,
                 native_menu_dismiss_active(data, session_id));
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static FlMethodChannel* create_native_menu_channel(FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      kNativeMenuChannel, FL_METHOD_CODEC(codec));
  auto* data = g_new0(NativeMenuHandlerData, 1);
  data->view = GTK_WIDGET(view);
  g_object_add_weak_pointer(G_OBJECT(data->view),
                            reinterpret_cast<gpointer*>(&data->view));
  data->trigger_event_signal_id = g_signal_connect(
      data->view, "event-after", G_CALLBACK(native_menu_event_after_cb), data);
  fl_method_channel_set_method_call_handler(
      channel, native_menu_method_call_cb, data,
      native_menu_handler_data_free);
  return channel;
}

static void register_native_menus(MyApplication* self, FlView* view) {
  self->native_menu_channel = create_native_menu_channel(view);
}

static void respond_success(FlMethodCall* method_call) {
  g_autoptr(FlValue) result = fl_value_new_null();
  fl_method_call_respond_success(method_call, result, nullptr);
}

static gboolean fl_method_bool_arg(FlValue* args) {
  return args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL
             ? fl_value_get_bool(args)
             : FALSE;
}

static gboolean is_css_hex_color(const gchar* value) {
  if (value == nullptr || strlen(value) != 7 || value[0] != '#') return FALSE;
  for (int i = 1; i < 7; i++) {
    if (!g_ascii_isxdigit(value[i])) return FALSE;
  }
  return TRUE;
}

static gboolean is_css_rgba_color(const gchar* value) {
  if (value == nullptr || !g_str_has_prefix(value, "rgba(")) return FALSE;
  gint red = -1;
  gint green = -1;
  gint blue = -1;
  gdouble alpha = -1;
  gchar extra = 0;
  if (sscanf(value, "rgba(%d,%d,%d,%lf)%c", &red, &green, &blue, &alpha,
             &extra) != 4) {
    return FALSE;
  }
  return red >= 0 && red <= 255 && green >= 0 && green <= 255 && blue >= 0 &&
         blue <= 255 && alpha >= 0 && alpha <= 1;
}

static gboolean is_css_color_token(const gchar* value) {
  return is_css_hex_color(value) || is_css_rgba_color(value);
}

static const gchar* css_color_or(const gchar* value, const gchar* fallback) {
  return is_css_color_token(value) ? value : fallback;
}

static void set_css_color_field(gchar** target, const gchar* value) {
  if (!is_css_color_token(value)) return;
  g_free(*target);
  *target = g_strdup(value);
}

static void set_main_flutter_view_background(MyApplication* self) {
  if (self->flutter_view == nullptr || !FL_IS_VIEW(self->flutter_view)) return;
  const gchar* color = css_color_or(
      self->native_surface_window_background_color,
      kDefaultWindowBackgroundColor);
  GdkRGBA background;
  if (gdk_rgba_parse(&background, color)) {
    fl_view_set_background_color(FL_VIEW(self->flutter_view), &background);
  }
}

static gboolean current_gtk_theme_uses_legacy_yaru_shadow() {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) return FALSE;
  g_autofree gchar* theme_name = nullptr;
  g_object_get(settings, "gtk-theme-name", &theme_name, nullptr);
  return busydata_gtk_theme_is_standard_yaru(theme_name);
}

static void refresh_native_surface_css(MyApplication* self) {
  const gchar* window_background = css_color_or(
      self->native_surface_window_background_color,
      kDefaultWindowBackgroundColor);
  const gchar* dialog_background = css_color_or(
      self->native_surface_dialog_background_color, window_background);
  const gchar* dialog_outline = css_color_or(
      self->native_surface_dialog_outline_color, kDefaultDialogOutlineColor);
  const gchar* tooltip_background = css_color_or(
      self->native_surface_tooltip_background_color,
      kDefaultTooltipBackground);
  const gchar* tooltip_foreground = css_color_or(
      self->native_surface_tooltip_foreground_color,
      kDefaultTooltipForeground);
  const gchar* tooltip_border = css_color_or(
      self->native_surface_tooltip_border_color, kDefaultTooltipBorder);
  const gdouble tooltip_horizontal_padding = std::max(
      0.0, self->native_surface_tooltip_horizontal_padding -
               (kGtkTooltipContainerInset - kTooltipBorderWidth));
  const gdouble tooltip_vertical_padding = std::max(
      0.0, self->native_surface_tooltip_vertical_padding -
               (kGtkTooltipContainerInset - kTooltipBorderWidth));
  const gdouble tooltip_minimum_height = std::max(
      0.0, self->native_surface_tooltip_minimum_height -
               kGtkTooltipContainerInset * 2 -
               tooltip_vertical_padding * 2);
  const gboolean legacy_yaru = !self->native_surface_high_contrast &&
                                current_gtk_theme_uses_legacy_yaru_shadow();
  g_autofree gchar* decoration_css = legacy_yaru
      ? g_strdup_printf(
            "window#busydata-window.csd:not(.solid-csd):not(.maximized):"
            "not(.fullscreen):not(.tiled):not(.tiled-top):not(.tiled-right):"
            "not(.tiled-bottom):not(.tiled-left) > decoration {"
            "box-shadow: 0 3px 9px 1px rgba(0,0,0,0.5);"
            "}"
            "window#busydata-window.csd:not(.solid-csd):not(.maximized):"
            "not(.fullscreen):not(.tiled):not(.tiled-top):not(.tiled-right):"
            "not(.tiled-bottom):not(.tiled-left) > decoration:backdrop {"
            "box-shadow: 0 3px 9px 1px transparent,"
            "0 2px 6px 2px rgba(0,0,0,0.2);"
            "}"
            "messagedialog.%s.csd:not(.solid-csd):not(.maximized):"
            "not(.fullscreen) > decoration,"
            "window.%s.%s.csd:not(.solid-csd):not(.maximized):"
            "not(.fullscreen) > decoration {"
            "box-shadow: 0 0 14px 2px rgba(0,0,6,0.03),"
            "0 0 5px 2px rgba(0,0,6,0.10),"
            "0 0 0 1px rgba(0,0,0,0.05);"
            "}",
            kNativeDialogStyleClass, kNativeDialogStyleClass,
            kNativeTimeZoneDialogStyleClass)
      : g_strdup("");
  g_autofree gchar* css = g_strdup_printf(
      "window#busydata-window,window#busydata-window:backdrop {"
      "background-color: %s;background-image: none;"
      "}"
      ".%s,.%s:backdrop {"
      "background-color: %s;background-image: none;"
      "}"
      ".%s headerbar,.%s headerbar:backdrop {"
      "background-color: %s;background-image: none;box-shadow: none;"
      "border-bottom-width: 0;border-bottom-style: none;"
      "}"
      ".%s .busydata-native-dialog-content,"
      ".%s .busydata-native-dialog-content:backdrop {"
      "background-color: %s;background-image: none;border-radius: %dpx;"
      "}"
      ".%s.csd:not(.solid-csd):not(.maximized):not(.fullscreen) {"
      "box-shadow: inset 0 0 0 1px %s;"
      "}"
      "window.%s.%s.csd:not(.solid-csd):not(.maximized):not(.fullscreen),"
      "window.%s.%s.csd:not(.solid-csd):not(.maximized):"
      "not(.fullscreen):backdrop {"
      "background-color: %s;background-image: none;border: none;"
      "border-radius: %dpx;box-shadow: none;"
      "}"
      "window.%s.%s .busydata-native-dialog-content,"
      "window.%s.%s .busydata-native-dialog-content:backdrop {"
      "background-color: %s;background-image: none;"
      "border-radius: 0 0 %dpx %dpx;"
      "}"
      "tooltip,tooltip.background,tooltip box,tooltip.background box {"
      "margin: 0;padding: 0;min-width: 0;min-height: 0;"
      "}"
      "tooltip.background {"
      "background-color: %s;background-image: none;"
      "background-clip: padding-box;border: %.2fpx solid %s;"
      "border-radius: %.2fpx;"
      "}"
      "tooltip decoration,tooltip.csd decoration {"
      "background-color: transparent;border-radius: %.2fpx;box-shadow: none;"
      "}"
      "tooltip * {background-color: transparent;color: %s;}"
      "tooltip label,tooltip.background label {"
      "margin: 0;padding: %.2fpx %.2fpx;min-width: 0;min-height: %.2fpx;"
      "font-size: %.2fpx;font-weight: 400;"
      "}"
      "%s",
      window_background, kNativeDialogStyleClass, kNativeDialogStyleClass,
      dialog_background, kNativeDialogStyleClass, kNativeDialogStyleClass,
      dialog_background, kNativeDialogStyleClass, kNativeDialogStyleClass,
      dialog_background, kNativeDialogCornerRadius, kNativeDialogStyleClass,
      dialog_outline, kNativeDialogStyleClass,
      kNativeTimeZoneDialogStyleClass, kNativeDialogStyleClass,
      kNativeTimeZoneDialogStyleClass, dialog_background,
      kNativeDialogCornerRadius, kNativeDialogStyleClass,
      kNativeTimeZoneDialogStyleClass, kNativeDialogStyleClass,
      kNativeTimeZoneDialogStyleClass, dialog_background,
      kNativeDialogCornerRadius, kNativeDialogCornerRadius,
      tooltip_background, kTooltipBorderWidth, tooltip_border,
      self->native_surface_tooltip_radius,
      self->native_surface_tooltip_radius, tooltip_foreground,
      tooltip_vertical_padding, tooltip_horizontal_padding,
      tooltip_minimum_height, self->native_surface_tooltip_font_size,
      decoration_css);

  g_autoptr(GError) error = nullptr;
  GtkCssProvider* provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(provider, css, -1, &error);
  if (error != nullptr) {
    g_warning("Failed to load native surface CSS: %s", error->message);
    g_object_unref(provider);
    return;
  }
  GdkScreen* screen = gdk_screen_get_default();
  if (screen == nullptr) {
    g_object_unref(provider);
    return;
  }
  if (self->native_surface_css_provider != nullptr) {
    gtk_style_context_remove_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(self->native_surface_css_provider));
    g_clear_object(&self->native_surface_css_provider);
  }
  self->native_surface_css_provider = provider;
  gtk_style_context_add_provider_for_screen(
      screen, GTK_STYLE_PROVIDER(provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

static void set_native_surface_theme(MyApplication* self, FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return;
  self->native_surface_theme_received = TRUE;
  fl_lookup_optional_bool_arg(args, "highContrast",
                              &self->native_surface_high_contrast);
  set_css_color_field(
      &self->native_surface_window_background_color,
      fl_lookup_string_arg(args, "windowBackgroundColor"));
  set_css_color_field(
      &self->native_surface_dialog_background_color,
      fl_lookup_string_arg(args, "dialogBackgroundColor"));
  set_css_color_field(
      &self->native_surface_dialog_outline_color,
      fl_lookup_string_arg(args, "dialogOutlineColor"));
  set_css_color_field(
      &self->native_surface_tooltip_background_color,
      fl_lookup_string_arg(args, "tooltipBackgroundColor"));
  set_css_color_field(
      &self->native_surface_tooltip_foreground_color,
      fl_lookup_string_arg(args, "tooltipForegroundColor"));
  set_css_color_field(
      &self->native_surface_tooltip_border_color,
      fl_lookup_string_arg(args, "tooltipBorderColor"));
  update_bounded_double_arg(args, "tooltipRadius", 0, 64,
                            &self->native_surface_tooltip_radius);
  update_bounded_double_arg(args, "tooltipFontSize", 1, 64,
                            &self->native_surface_tooltip_font_size);
  update_bounded_double_arg(args, "tooltipHorizontalPadding", 0, 64,
                            &self->native_surface_tooltip_horizontal_padding);
  update_bounded_double_arg(args, "tooltipVerticalPadding", 0, 64,
                            &self->native_surface_tooltip_vertical_padding);
  update_bounded_double_arg(args, "tooltipMinimumHeight", 1, 128,
                            &self->native_surface_tooltip_minimum_height);
  set_main_flutter_view_background(self);
  refresh_native_surface_css(self);
}

static FlValue* parse_gtk_font_name(const gchar* font_name) {
  if (font_name == nullptr) {
    return fl_value_new_null();
  }

  PangoFontDescription* desc = pango_font_description_from_string(font_name);
  if (desc == nullptr) {
    return fl_value_new_null();
  }

  const gchar* family = pango_font_description_get_family(desc);
  const gint size = pango_font_description_get_size(desc);
  const double point_size =
      size > 0 ? static_cast<double>(size) / PANGO_SCALE : 0.0;

  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "family",
      fl_value_new_string(family != nullptr ? family : ""));
  fl_value_set_string_take(result, "size", fl_value_new_float(point_size));

  pango_font_description_free(desc);
  return result;
}

static FlValue* get_gtk_font_settings() {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) {
    return fl_value_new_null();
  }

  gchar* font_name = nullptr;
  g_object_get(settings, "gtk-font-name", &font_name, nullptr);
  FlValue* result = parse_gtk_font_name(font_name);
  g_free(font_name);
  return result;
}

static gboolean get_gtk_animations_enabled() {
  GtkSettings* settings = gtk_settings_get_default();
  gboolean enabled = TRUE;
  if (settings != nullptr) {
    g_object_get(settings, "gtk-enable-animations", &enabled, nullptr);
  }
  return enabled;
}

static guint color_channel(double value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 1) {
    return 255;
  }
  return static_cast<guint>(value * 255.0 + 0.5);
}

static gboolean color_is_visible(const GdkRGBA* color) {
  return color != nullptr && color->alpha > 0.01;
}

static gchar* rgba_to_hex(const GdkRGBA* color) {
  const guint red = color_channel(color->red);
  const guint green = color_channel(color->green);
  const guint blue = color_channel(color->blue);
  const guint alpha = color_channel(color->alpha);
  if (alpha < 255) {
    return g_strdup_printf("#%02X%02X%02X%02X", alpha, red, green, blue);
  }
  return g_strdup_printf("#%02X%02X%02X", red, green, blue);
}

static void set_theme_color(FlValue* result,
                            const gchar* key,
                            const GdkRGBA* color) {
  if (!color_is_visible(color)) {
    return;
  }
  g_autofree gchar* hex = rgba_to_hex(color);
  fl_value_set_string_take(result, key, fl_value_new_string(hex));
}

static void set_search_entry_color(FlValue* result,
                                   const gchar* key,
                                   const GdkRGBA* color) {
  g_autofree gchar* hex = rgba_to_hex(color);
  fl_value_set_string_take(result, key, fl_value_new_string(hex));
}

static FlValue* gtk_search_entry_state_to_fl_value(
    const BusyDataGtkSearchEntryState& state) {
  FlValue* result = fl_value_new_map();
  set_search_entry_color(result, "background", &state.background);
  set_search_entry_color(result, "foreground", &state.foreground);
  set_search_entry_color(result, "borderColor", &state.border_color);
  set_search_entry_color(result, "primaryIconForeground",
                         &state.primary_icon_foreground);
  set_search_entry_color(result, "primaryIconForegroundRtl",
                         &state.primary_icon_foreground_rtl);
  set_search_entry_color(result, "secondaryIconForeground",
                         &state.secondary_icon_foreground);
  set_search_entry_color(result, "secondaryIconForegroundRtl",
                         &state.secondary_icon_foreground_rtl);
  fl_value_set_string_take(result, "borderTop",
                           fl_value_new_int(state.border_width.top));
  fl_value_set_string_take(result, "borderRight",
                           fl_value_new_int(state.border_width.right));
  fl_value_set_string_take(result, "borderBottom",
                           fl_value_new_int(state.border_width.bottom));
  fl_value_set_string_take(result, "borderLeft",
                           fl_value_new_int(state.border_width.left));
  fl_value_set_string_take(result, "radius",
                           fl_value_new_int(state.border_radius));
  fl_value_set_string_take(result, "hasInnerFocus",
                           fl_value_new_bool(state.has_inner_focus));
  set_search_entry_color(result, "innerFocusColor",
                         &state.inner_focus_color);
  fl_value_set_string_take(result, "innerFocusWidth",
                           fl_value_new_int(state.inner_focus_width));
  return result;
}

static FlValue* gtk_search_entry_theme_to_fl_value(
    const BusyDataGtkSearchEntryTheme& theme) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "normal", gtk_search_entry_state_to_fl_value(theme.normal));
  fl_value_set_string_take(
      result, "focused", gtk_search_entry_state_to_fl_value(theme.focused));
  fl_value_set_string_take(
      result, "backdrop", gtk_search_entry_state_to_fl_value(theme.backdrop));
  fl_value_set_string_take(
      result, "backdropFocused",
      gtk_search_entry_state_to_fl_value(theme.backdrop_focused));
  return result;
}

static gboolean lookup_context_color(GtkStyleContext* context,
                                     const gchar* name,
                                     GdkRGBA* color) {
  if (context == nullptr || name == nullptr || color == nullptr) {
    return FALSE;
  }
  if (!gtk_style_context_lookup_color(context, name, color)) {
    return FALSE;
  }
  return color_is_visible(color);
}

static gboolean sample_widget_background(GtkWidget* widget,
                                         const gchar* style_class,
                                         GtkStateFlags state,
                                         GdkRGBA* color) {
  if (widget == nullptr || color == nullptr) {
    return FALSE;
  }
  GtkStyleContext* context = gtk_widget_get_style_context(widget);
  if (context == nullptr) {
    return FALSE;
  }
  if (style_class != nullptr) {
    gtk_style_context_add_class(context, style_class);
  }
  gtk_style_context_set_state(context, state);
  GValue value = G_VALUE_INIT;
  gtk_style_context_get_property(context, "background-color", state, &value);
  const GdkRGBA* background =
      static_cast<const GdkRGBA*>(g_value_get_boxed(&value));
  if (background != nullptr) {
    *color = *background;
  }
  g_value_unset(&value);
  return color_is_visible(color);
}

static gboolean sample_widget_color(GtkWidget* widget,
                                    const gchar* style_class,
                                    GtkStateFlags state,
                                    GdkRGBA* color) {
  if (widget == nullptr || color == nullptr) {
    return FALSE;
  }
  GtkStyleContext* context = gtk_widget_get_style_context(widget);
  if (context == nullptr) {
    return FALSE;
  }
  if (style_class != nullptr) {
    gtk_style_context_add_class(context, style_class);
  }
  gtk_style_context_set_state(context, state);
  gtk_style_context_get_color(context, state, color);
  return color_is_visible(color);
}

static gboolean sample_widget_color_with_opacity(
    GtkWidget* widget,
    const gchar* style_class,
    GtkStateFlags state,
    GdkRGBA* color) {
  if (!sample_widget_color(widget, style_class, state, color)) {
    return FALSE;
  }
  GtkStyleContext* context = gtk_widget_get_style_context(widget);
  gdouble opacity = 1.0;
  gtk_style_context_get(context, state, "opacity", &opacity, nullptr);
  if (!std::isfinite(opacity)) {
    opacity = 1.0;
  }
  color->alpha *= CLAMP(opacity, 0.0, 1.0);
  return color_is_visible(color);
}

static const gchar* brightness_for_color(const GdkRGBA* color) {
  if (color == nullptr) {
    return "light";
  }
  const double luminance =
      (0.2126 * color->red) + (0.7152 * color->green) +
      (0.0722 * color->blue);
  return luminance < 0.5 ? "dark" : "light";
}

static FlValue* get_gtk_theme_colors() {
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWidget* control = gtk_button_new();
  GtkWidget* separator = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget* dim_label = gtk_label_new(nullptr);

  GdkRGBA window_color = {0, 0, 0, 0};
  GdkRGBA view_color = {0, 0, 0, 0};
  GdkRGBA sidebar_color = {0, 0, 0, 0};
  GdkRGBA secondary_sidebar_color = {0, 0, 0, 0};
  GdkRGBA header_color = {0, 0, 0, 0};
  GdkRGBA card_color = {0, 0, 0, 0};
  GdkRGBA dialog_color = {0, 0, 0, 0};
  GdkRGBA popover_color = {0, 0, 0, 0};
  GdkRGBA control_color = {0, 0, 0, 0};
  GdkRGBA control_hover_color = {0, 0, 0, 0};
  GdkRGBA control_active_color = {0, 0, 0, 0};
  GdkRGBA accent_color = {0, 0, 0, 0};
  GdkRGBA accent_foreground_color = {0, 0, 0, 0};
  GdkRGBA foreground_color = {0, 0, 0, 0};
  GdkRGBA muted_foreground_color = {0, 0, 0, 0};
  GdkRGBA border_color = {0, 0, 0, 0};
  GdkRGBA divider_color = {0, 0, 0, 0};
  GdkRGBA card_shade_color = {0, 0, 0, 0};
  GdkRGBA floating_border_color = {0, 0, 0, 0};
  GdkRGBA sidebar_border_color = {0, 0, 0, 0};
  GdkRGBA shade_color = {0, 0, 0, 0};

  GtkStyleContext* window_context = gtk_widget_get_style_context(window);
  gtk_style_context_add_class(window_context, GTK_STYLE_CLASS_BACKGROUND);
  lookup_context_color(window_context, "window_bg_color", &window_color) ||
      lookup_context_color(window_context, "theme_bg_color", &window_color) ||
      sample_widget_background(window, GTK_STYLE_CLASS_BACKGROUND,
                               GTK_STATE_FLAG_NORMAL, &window_color);
  // Publish only the explicit modern view role. GTK 3's theme_base_color and
  // computed .view background describe editable/list content (normally pure
  // white), not the application workspace. When the named role is absent,
  // Dart keeps its semantic view fallback; application workspaces choose the
  // native window role explicitly.
  lookup_context_color(window_context, "view_bg_color", &view_color);
  lookup_context_color(window_context, "window_fg_color", &foreground_color) ||
      lookup_context_color(window_context, "theme_fg_color",
                           &foreground_color) ||
      sample_widget_color(window, GTK_STYLE_CLASS_BACKGROUND,
                          GTK_STATE_FLAG_NORMAL, &foreground_color);
  sample_widget_color_with_opacity(
      dim_label, GTK_STYLE_CLASS_DIM_LABEL, GTK_STATE_FLAG_NORMAL,
      &muted_foreground_color);
  lookup_context_color(window_context, "borders", &border_color);
  lookup_context_color(window_context, "sidebar_border_color",
                       &sidebar_border_color);
  // `shade_color` is the semantic modal/floating shade. `wm_shadow` is a
  // substantially stronger window-decoration shadow in GTK 3 Yaru and must
  // not be exported under this role. If the theme does not publish the modern
  // name, Dart supplies the matching brightness-aware semantic fallback.
  lookup_context_color(window_context, "shade_color", &shade_color);
  lookup_context_color(window_context, "accent_bg_color", &accent_color) ||
      lookup_context_color(window_context, "theme_selected_bg_color",
                           &accent_color);
  lookup_context_color(window_context, "accent_fg_color",
                       &accent_foreground_color) ||
      lookup_context_color(window_context, "theme_selected_fg_color",
                           &accent_foreground_color);

  // Optional modern surface roles must remain semantic. A classic GTK 3
  // widget-class sample is valid for that widget, but it is not equivalent to
  // Yaru/libadwaita's modern sidebar, card, dialog, or popover role. Omit a
  // role when the theme does not publish its named color so Dart can use the
  // matching modern fallback instead of mislabelling a legacy sample.
  lookup_context_color(window_context, "sidebar_bg_color", &sidebar_color);
  lookup_context_color(window_context, "secondary_sidebar_bg_color",
                       &secondary_sidebar_color);
  if (!color_is_visible(&secondary_sidebar_color) &&
      color_is_visible(&sidebar_color)) {
    secondary_sidebar_color = sidebar_color;
  }
  lookup_context_color(window_context, "headerbar_bg_color", &header_color);
  lookup_context_color(window_context, "card_bg_color", &card_color);
  lookup_context_color(window_context, "card_shade_color", &card_shade_color);
  lookup_context_color(window_context, "dialog_bg_color", &dialog_color);
  lookup_context_color(window_context, "popover_bg_color", &popover_color);
  // Only publish a named floating-surface role. Sampling GTK 3's computed
  // popover border here imports its legacy light rim into the Flutter GTK 4
  // palette, where modern Yaru uses a recessed edge instead.
  lookup_context_color(window_context, "popover_border_color",
                       &floating_border_color) ||
      lookup_context_color(window_context, "floating_border_color",
                           &floating_border_color);
  sample_widget_background(separator, GTK_STYLE_CLASS_SEPARATOR,
                           GTK_STATE_FLAG_NORMAL, &divider_color);

  sample_widget_background(control, nullptr, GTK_STATE_FLAG_NORMAL,
                           &control_color);
  sample_widget_background(control, nullptr, GTK_STATE_FLAG_PRELIGHT,
                           &control_hover_color);
  sample_widget_background(control, nullptr, GTK_STATE_FLAG_ACTIVE,
                           &control_active_color);

  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "brightness",
      fl_value_new_string(brightness_for_color(&window_color)));
  set_theme_color(result, "window", &window_color);
  set_theme_color(result, "view", &view_color);
  set_theme_color(result, "sidebar", &sidebar_color);
  set_theme_color(result, "secondarySidebar", &secondary_sidebar_color);
  set_theme_color(result, "headerbar", &header_color);
  set_theme_color(result, "card", &card_color);
  set_theme_color(result, "dialog", &dialog_color);
  set_theme_color(result, "popover", &popover_color);
  set_theme_color(result, "control", &control_color);
  set_theme_color(result, "controlHover", &control_hover_color);
  set_theme_color(result, "controlActive", &control_active_color);
  set_theme_color(result, "accent", &accent_color);
  set_theme_color(result, "accentForeground", &accent_foreground_color);
  set_theme_color(result, "activeToggle", &control_active_color);
  set_theme_color(result, "foreground", &foreground_color);
  set_theme_color(result, "mutedForeground", &muted_foreground_color);
  set_theme_color(result, "border", &border_color);
  set_theme_color(result, "divider", &divider_color);
  set_theme_color(result, "cardShade", &card_shade_color);
  set_theme_color(result, "floatingBorder", &floating_border_color);
  set_theme_color(result, "sidebarBorder", &sidebar_border_color);
  set_theme_color(result, "shade", &shade_color);
  BusyDataGtkSearchEntryTheme search_entry_theme = {};
  if (busydata_sample_gtk_search_entry_theme(&search_entry_theme)) {
    fl_value_set_string_take(
        result, "searchEntry",
        gtk_search_entry_theme_to_fl_value(search_entry_theme));
  }

  gtk_widget_destroy(dim_label);
  gtk_widget_destroy(separator);
  gtk_widget_destroy(control);
  gtk_widget_destroy(window);
  return result;
}

static void apply_gtk_theme_to_native_surfaces(MyApplication* self) {
  g_autoptr(FlValue) colors = get_gtk_theme_colors();
  const gchar* window_color = fl_lookup_string_arg(colors, "window");

  // Dart sends the complete semantic palette after its first build. Until
  // then, use GTK's resolved active variant for retained GTK surfaces and the
  // Flutter backing surface.
  set_css_color_field(&self->native_surface_window_background_color,
                      window_color);
  set_css_color_field(&self->native_surface_dialog_background_color,
                      fl_lookup_string_arg(colors, "dialog"));
}

static FlValue* gtk_window_preferences_to_fl_value(
    const BusyDataGtkWindowPreferences& preferences) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(
      result, "decorationLayout",
      fl_value_new_string(preferences.decoration_layout.c_str()));
  fl_value_set_string_take(
      result, "doubleClick",
      fl_value_new_string(preferences.double_click.c_str()));
  fl_value_set_string_take(
      result, "middleClick",
      fl_value_new_string(preferences.middle_click.c_str()));
  fl_value_set_string_take(
      result, "rightClick",
      fl_value_new_string(preferences.right_click.c_str()));
  return result;
}

static FlValue* get_gtk_window_preferences(MyApplication* self) {
  return gtk_window_preferences_to_fl_value(
      self->gtk_window_preferences->Read());
}

static void gtk_settings_method_call_cb(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (strcmp(method, "getGtkFont") == 0) {
    g_autoptr(FlValue) result = get_gtk_font_settings();
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "getGtkThemeColors") == 0) {
    g_autoptr(FlValue) result = get_gtk_theme_colors();
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "getGtkAnimationsEnabled") == 0) {
    g_autoptr(FlValue) result =
        fl_value_new_bool(get_gtk_animations_enabled());
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "setGtkThemePreference") == 0) {
    set_gtk_theme_preference(fl_method_bool_arg(args));
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "setNativeSurfaceTheme") == 0) {
    set_native_surface_theme(self, args);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "getGtkWindowPreferences") == 0) {
    g_autoptr(FlValue) result = get_gtk_window_preferences(self);
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "lowerWindow") == 0) {
    if (self->main_window != nullptr) {
      GdkWindow* window = gtk_widget_get_window(GTK_WIDGET(self->main_window));
      if (window != nullptr) gdk_window_lower(window);
    }
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void disconnect_gtk_font_settings_signal(MyApplication* self) {
  if (self->gtk_font_settings_signal_id == 0) {
    return;
  }
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_signal_handler_disconnect(settings, self->gtk_font_settings_signal_id);
  }
  self->gtk_font_settings_signal_id = 0;
}

static void send_gtk_font_settings_event(MyApplication* self) {
  if (!self->gtk_font_settings_listening ||
      self->gtk_font_settings_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_font_settings();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_font_settings_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK font settings event: %s", message);
  }
}

static void gtk_font_name_notify_cb(GObject* object,
                                    GParamSpec* pspec,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  send_gtk_font_settings_event(self);
}

static FlMethodErrorResponse* gtk_font_settings_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_font_settings_listening = TRUE;

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_font_settings_signal_id == 0) {
    self->gtk_font_settings_signal_id =
        g_signal_connect(settings, "notify::gtk-font-name",
                         G_CALLBACK(gtk_font_name_notify_cb), self);
  }

  send_gtk_font_settings_event(self);
  return nullptr;
}

static FlMethodErrorResponse* gtk_font_settings_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_font_settings_listening = FALSE;
  disconnect_gtk_font_settings_signal(self);
  return nullptr;
}

static void disconnect_gtk_theme_colors_signals(MyApplication* self) {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_theme_name_signal_id != 0) {
    g_signal_handler_disconnect(settings, self->gtk_theme_name_signal_id);
  }
  if (settings != nullptr && self->gtk_theme_dark_signal_id != 0) {
    g_signal_handler_disconnect(settings, self->gtk_theme_dark_signal_id);
  }
  self->gtk_theme_name_signal_id = 0;
  self->gtk_theme_dark_signal_id = 0;
}

static void send_gtk_theme_colors_event(MyApplication* self) {
  if (!self->gtk_theme_colors_listening ||
      self->gtk_theme_colors_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) result = get_gtk_theme_colors();
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_theme_colors_event_channel, result,
                             nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK theme colors event: %s", message);
  }
}

static void gtk_theme_colors_notify_cb(GObject*,
                                       GParamSpec*,
                                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!self->native_surface_theme_received) {
    apply_gtk_theme_to_native_surfaces(self);
    set_main_flutter_view_background(self);
  }
  refresh_native_surface_css(self);
  send_gtk_theme_colors_event(self);
}

static void connect_gtk_theme_colors_signals(MyApplication* self) {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_theme_name_signal_id == 0) {
    self->gtk_theme_name_signal_id =
        g_signal_connect(settings, "notify::gtk-theme-name",
                         G_CALLBACK(gtk_theme_colors_notify_cb), self);
  }
  if (settings != nullptr && self->gtk_theme_dark_signal_id == 0) {
    self->gtk_theme_dark_signal_id = g_signal_connect(
        settings, "notify::gtk-application-prefer-dark-theme",
        G_CALLBACK(gtk_theme_colors_notify_cb), self);
  }
}

static FlMethodErrorResponse* gtk_theme_colors_listen_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_theme_colors_listening = TRUE;

  connect_gtk_theme_colors_signals(self);
  send_gtk_theme_colors_event(self);
  return nullptr;
}

static FlMethodErrorResponse* gtk_theme_colors_cancel_cb(
    FlEventChannel* channel,
    FlValue* args,
    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_theme_colors_listening = FALSE;
  return nullptr;
}

static void disconnect_gtk_animation_settings_signal(MyApplication* self) {
  if (self->gtk_animation_settings_signal_id == 0) {
    return;
  }
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_signal_handler_disconnect(settings,
                                self->gtk_animation_settings_signal_id);
  }
  self->gtk_animation_settings_signal_id = 0;
}

static void send_gtk_animation_settings_event(MyApplication* self) {
  if (!self->gtk_animation_settings_listening ||
      self->gtk_animation_settings_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) value =
      fl_value_new_bool(get_gtk_animations_enabled());
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_animation_settings_event_channel,
                             value, nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK animation settings event: %s", message);
  }
}

static void gtk_animation_settings_notify_cb(GObject*, GParamSpec*,
                                             gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  send_gtk_animation_settings_event(self);
}

static FlMethodErrorResponse* gtk_animation_settings_listen_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_animation_settings_listening = TRUE;
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr && self->gtk_animation_settings_signal_id == 0) {
    self->gtk_animation_settings_signal_id = g_signal_connect(
        settings, "notify::gtk-enable-animations",
        G_CALLBACK(gtk_animation_settings_notify_cb), self);
  }
  send_gtk_animation_settings_event(self);
  return nullptr;
}

static FlMethodErrorResponse* gtk_animation_settings_cancel_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_animation_settings_listening = FALSE;
  disconnect_gtk_animation_settings_signal(self);
  return nullptr;
}

static void send_gtk_window_preferences_event(
    MyApplication* self,
    const BusyDataGtkWindowPreferences& preferences) {
  if (!self->gtk_window_preferences_listening ||
      self->gtk_window_preferences_event_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) value =
      gtk_window_preferences_to_fl_value(preferences);
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_window_preferences_event_channel,
                             value, nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK window preferences event: %s", message);
  }
}

static FlMethodErrorResponse* gtk_window_preferences_listen_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_window_preferences_listening = TRUE;
  self->gtk_window_preferences->Start(
      [self](const BusyDataGtkWindowPreferences& preferences) {
        send_gtk_window_preferences_event(self, preferences);
      });
  send_gtk_window_preferences_event(
      self, self->gtk_window_preferences->Read());
  return nullptr;
}

static FlMethodErrorResponse* gtk_window_preferences_cancel_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_window_preferences_listening = FALSE;
  if (self->gtk_window_preferences != nullptr) {
    self->gtk_window_preferences->Stop();
  }
  return nullptr;
}

static void send_gtk_header_icons_changed_event(MyApplication* self) {
  if (!self->gtk_header_icons_listening ||
      self->gtk_header_icons_changed_event_channel == nullptr ||
      self->gtk_header_icons == nullptr) {
    return;
  }
  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(
      event, "revision",
      fl_value_new_int(self->gtk_header_icons_revision));
  fl_value_set_string_take(event, "scale",
                           fl_value_new_int(self->gtk_header_icons->scale()));
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(self->gtk_header_icons_changed_event_channel,
                             event, nullptr, &error)) {
    const gchar* message = error != nullptr ? error->message : "unknown error";
    g_warning("Failed to send GTK header-icon invalidation: %s", message);
  }
}

static FlMethodErrorResponse* gtk_header_icons_listen_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_header_icons_listening = TRUE;
  if (self->gtk_header_icons_revision > 0) {
    send_gtk_header_icons_changed_event(self);
  }
  return nullptr;
}

static FlMethodErrorResponse* gtk_header_icons_cancel_cb(
    FlEventChannel*, FlValue*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->gtk_header_icons_listening = FALSE;
  return nullptr;
}

static gboolean parse_gtk_header_icon_request(
    FlValue* request,
    const gchar** key_out,
    std::vector<std::string>* names_out,
    BusyDataGtkIconDirection* direction_out,
    gboolean* allow_missing_out) {
  if (request == nullptr || fl_value_get_type(request) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* key = fl_value_lookup_string(request, "key");
  FlValue* names = fl_value_lookup_string(request, "names");
  FlValue* direction = fl_value_lookup_string(request, "direction");
  FlValue* allow_missing = fl_value_lookup_string(request, "allowMissing");
  if (key == nullptr || fl_value_get_type(key) != FL_VALUE_TYPE_STRING ||
      names == nullptr || fl_value_get_type(names) != FL_VALUE_TYPE_LIST ||
      fl_value_get_length(names) == 0 || direction == nullptr ||
      fl_value_get_type(direction) != FL_VALUE_TYPE_STRING ||
      (allow_missing != nullptr &&
       fl_value_get_type(allow_missing) != FL_VALUE_TYPE_BOOL)) {
    return FALSE;
  }
  names_out->clear();
  for (size_t index = 0; index < fl_value_get_length(names); index++) {
    FlValue* name = fl_value_get_list_value(names, index);
    if (name == nullptr || fl_value_get_type(name) != FL_VALUE_TYPE_STRING) {
      return FALSE;
    }
    names_out->emplace_back(fl_value_get_string(name));
  }
  const gchar* direction_value = fl_value_get_string(direction);
  if (g_strcmp0(direction_value, "ltr") == 0) {
    *direction_out = BusyDataGtkIconDirection::kLtr;
  } else if (g_strcmp0(direction_value, "rtl") == 0) {
    *direction_out = BusyDataGtkIconDirection::kRtl;
  } else {
    return FALSE;
  }
  *allow_missing_out =
      allow_missing == nullptr ? FALSE : fl_value_get_bool(allow_missing);
  *key_out = fl_value_get_string(key);
  return TRUE;
}

static FlValue* gtk_header_icon_asset_to_fl_value(
    const BusyDataGtkHeaderIconAsset& asset) {
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(
      value, "bytes",
      fl_value_new_uint8_list(asset.png_bytes.data(), asset.png_bytes.size()));
  fl_value_set_string_take(
      value, "resolvedName",
      fl_value_new_string(asset.resolved_name.c_str()));
  fl_value_set_string_take(value, "scale", fl_value_new_int(asset.scale));
  fl_value_set_string_take(value, "pixelWidth",
                           fl_value_new_int(asset.pixel_width));
  fl_value_set_string_take(value, "pixelHeight",
                           fl_value_new_int(asset.pixel_height));
  return value;
}

static void gtk_header_icons_method_call_cb(FlMethodChannel*,
                                            FlMethodCall* method_call,
                                            gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (g_strcmp0(fl_method_call_get_name(method_call), "loadIcons") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }
  FlValue* requests = fl_method_call_get_args(method_call);
  if (requests == nullptr ||
      fl_value_get_type(requests) != FL_VALUE_TYPE_LIST) {
    fl_method_call_respond_error(
        method_call, "invalid-arguments",
        "loadIcons requires a list of keyed icon requests.", nullptr,
        nullptr);
    return;
  }

  g_autoptr(FlValue) result = fl_value_new_map();
  for (size_t index = 0; index < fl_value_get_length(requests); index++) {
    const gchar* key = nullptr;
    std::vector<std::string> names;
    BusyDataGtkIconDirection direction = BusyDataGtkIconDirection::kLtr;
    gboolean allow_missing = FALSE;
    if (!parse_gtk_header_icon_request(
            fl_value_get_list_value(requests, index), &key, &names,
            &direction, &allow_missing)) {
      fl_method_call_respond_error(
          method_call, "invalid-arguments",
          "Each icon request requires key, non-empty names, ltr/rtl "
          "direction, and an optional boolean allowMissing.",
          nullptr, nullptr);
      return;
    }
    const auto asset = self->gtk_header_icons->Load(
        names, direction, 0, allow_missing);
    if (asset) {
      fl_value_set_string_take(
          result, key, gtk_header_icon_asset_to_fl_value(*asset));
    } else {
      fl_value_set_string_take(result, key, fl_value_new_null());
    }
  }
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void register_gtk_header_icons(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  self->gtk_header_icons_channel = fl_method_channel_new(
      messenger, kGtkHeaderIconsChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->gtk_header_icons_channel, gtk_header_icons_method_call_cb, self,
      nullptr);
  self->gtk_header_icons_changed_event_channel = fl_event_channel_new(
      messenger, kGtkHeaderIconsChangedEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_header_icons_changed_event_channel,
      gtk_header_icons_listen_cb, gtk_header_icons_cancel_cb, self, nullptr);

  self->gtk_header_icons = new BusyDataGtkHeaderIcons(GTK_WIDGET(view));
  self->gtk_header_icons->Start([self]() {
    self->gtk_header_icons_revision += 1;
    send_gtk_header_icons_changed_event(self);
  });
}

static void register_gtk_settings_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  self->gtk_settings_channel = fl_method_channel_new(
      messenger, kGtkSettingsChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->gtk_settings_channel, gtk_settings_method_call_cb, self, nullptr);




  self->gtk_font_settings_event_channel = fl_event_channel_new(
      messenger, kGtkFontSettingsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_font_settings_event_channel, gtk_font_settings_listen_cb,
      gtk_font_settings_cancel_cb, self, nullptr);

  self->gtk_theme_colors_event_channel = fl_event_channel_new(
      messenger, kGtkThemeColorsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_theme_colors_event_channel, gtk_theme_colors_listen_cb,
      gtk_theme_colors_cancel_cb, self, nullptr);

  self->gtk_animation_settings_event_channel = fl_event_channel_new(
      messenger, kGtkAnimationSettingsEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_animation_settings_event_channel,
      gtk_animation_settings_listen_cb,
      gtk_animation_settings_cancel_cb, self, nullptr);

  self->gtk_window_preferences_event_channel = fl_event_channel_new(
      messenger, kGtkWindowPreferencesEventChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      self->gtk_window_preferences_event_channel,
      gtk_window_preferences_listen_cb,
      gtk_window_preferences_cancel_cb, self, nullptr);
}

static gboolean window_delete_event_cb(GtkWidget* widget,
                                       GdkEvent* event,
                                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->hide_on_close) {
    g_debug(
        "BusyData native hideWindow invocation: source=delete-event "
        "main_window_null=%s",
        self->main_window == nullptr ? "true" : "false");
    gtk_widget_hide(widget);
    return TRUE;
  }
  if (self->window_close != nullptr) busydata_window_close_request(self->window_close);
  return TRUE;
}

static void restore_main_window(MyApplication* self) {
  g_debug("BusyData native showWindow invoked: main_window_null=%s",
          self->main_window == nullptr ? "true" : "false");
  if (self->main_window == nullptr) {
    return;
  }
  gtk_widget_show(GTK_WIDGET(self->main_window));
  gtk_window_deiconify(self->main_window);
  gtk_window_present_with_time(self->main_window, GDK_CURRENT_TIME);
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (strcmp(method, "setHideOnClose") == 0) {
    if (self->window_close != nullptr) busydata_window_close_cancel(self->window_close);
    self->hide_on_close =
        args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL
            ? fl_value_get_bool(args)
            : FALSE;
    respond_success(method_call);
  } else if (strcmp(method, "hideWindow") == 0) {
    g_debug("BusyData native hideWindow invoked: main_window_null=%s",
            self->main_window == nullptr ? "true" : "false");
    if (self->main_window != nullptr) {
      gtk_widget_hide(GTK_WIDGET(self->main_window));
    }
    respond_success(method_call);
  } else if (strcmp(method, "showWindow") == 0) {
    g_debug("BusyData native showWindow method call received");
    restore_main_window(self);
    respond_success(method_call);
  } else if (strcmp(method, "quitApp") == 0) {
    g_debug("BusyData native quit invocation: method=quitApp");
    self->hide_on_close = FALSE;
    g_application_quit(G_APPLICATION(self));
    respond_success(method_call);
  } else if (strcmp(method, "isWindowVisible") == 0) {
    respond_bool(
        method_call,
        self->main_window != nullptr &&
            gtk_widget_get_visible(GTK_WIDGET(self->main_window)));
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void register_window_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kWindowChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, self, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  if (!self->start_minimized) {
    gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  }
}

// Opt-in diagnostics for non-text function keys only. Never log authored text,
// clipboard contents or credentials while diagnosing native shortcut delivery.
static gboolean function_key_event_cb(GtkWidget* widget,
                                      GdkEventKey* event,
                                      gpointer) {
  if (event->keyval >= GDK_KEY_F1 && event->keyval <= GDK_KEY_F12) {
    g_log("BusyDataKeyboard", G_LOG_LEVEL_DEBUG,
          "function-key type=%u keyval=%u modifiers=%u view-focus=%d",
          event->type, event->keyval, event->state,
          gtk_widget_has_focus(widget));
  }
  return FALSE;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->main_window != nullptr) {
    restore_main_window(self);
    return;
  }

  apply_gtk_theme_to_native_surfaces(self);
  refresh_native_surface_css(self);
  GtkWindow* window = GTK_WINDOW(hdy_application_window_new());
  gtk_application_add_window(GTK_APPLICATION(application), window);
  self->main_window = window;
  gtk_widget_set_name(GTK_WIDGET(window), "busydata-window");

  g_autoptr(GdkPixbuf) application_icon = load_application_icon();
  if (application_icon != nullptr) {
    gtk_window_set_default_icon(application_icon);
    gtk_window_set_icon(window, application_icon);
  }
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  gtk_window_set_wmclass(window, APPLICATION_ID, APPLICATION_ID);
  G_GNUC_END_IGNORE_DEPRECATIONS
  if (application_icon == nullptr) {
    gtk_window_set_icon_name(window, APPLICATION_ID);
  }
  gtk_window_set_default_size(window, kMainWindowDefaultWidth,
                              kMainWindowDefaultHeight);
  gtk_window_set_title(window, kApplicationDisplayName);
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_event_cb),
                   self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // Use the pinned SDK's documented Skia/OpenGL path for every entrypoint.
  fl_dart_project_set_enable_impeller(project, FALSE);
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  g_signal_connect(view, "key-press-event", G_CALLBACK(function_key_event_cb),
                   nullptr);
  g_signal_connect(view, "key-release-event", G_CALLBACK(function_key_event_cb),
                   nullptr);
  self->flutter_view = GTK_WIDGET(view);
  g_object_add_weak_pointer(
      G_OBJECT(view), reinterpret_cast<gpointer*>(&self->flutter_view));
  set_main_flutter_view_background(self);
  gtk_widget_show(GTK_WIDGET(view));

  GtkWidget* accessibility_host = busydata_accessibility_bridge_new(view);
  gtk_widget_show(accessibility_host);
  gtk_container_add(GTK_CONTAINER(window), accessibility_host);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  register_native_menus(self, view);
  register_window_channel(self, view);
  self->window_close = busydata_window_close_new(G_APPLICATION(self), window,
      fl_engine_get_binary_messenger(fl_view_get_engine(view)));
  register_gtk_settings_channel(self, view);
  register_gtk_header_icons(self, view);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application, gchar***, int* exit_status) {
  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Could not register application instance"); *exit_status = 1; return TRUE;
  }
  g_application_activate(application); *exit_status = 0; return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
  hdy_init();
  connect_gtk_theme_colors_signals(MY_APPLICATION(application));
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  disconnect_gtk_theme_colors_signals(self);
  disconnect_gtk_font_settings_signal(self);
  disconnect_gtk_animation_settings_signal(self);
  if (self->gtk_window_preferences != nullptr) {
    self->gtk_window_preferences->Stop();
  }
  if (self->gtk_header_icons != nullptr) {
    self->gtk_header_icons->Stop();
  }
  GdkScreen* screen = gdk_screen_get_default();
  if (screen != nullptr && self->native_surface_css_provider != nullptr) {
    gtk_style_context_remove_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(self->native_surface_css_provider));
  }
  g_clear_object(&self->native_surface_css_provider);
  g_clear_object(&self->native_menu_channel);
  g_clear_object(&self->window_channel);
  g_clear_object(&self->window_close);
  g_clear_object(&self->gtk_settings_channel);
  g_clear_object(&self->gtk_header_icons_channel);
  g_clear_object(&self->gtk_font_settings_event_channel);
  g_clear_object(&self->gtk_theme_colors_event_channel);
  g_clear_object(&self->gtk_animation_settings_event_channel);
  g_clear_object(&self->gtk_window_preferences_event_channel);
  g_clear_object(&self->gtk_header_icons_changed_event_channel);
  delete self->gtk_window_preferences;
  self->gtk_window_preferences = nullptr;
  delete self->gtk_header_icons;
  self->gtk_header_icons = nullptr;
  if (self->flutter_view != nullptr && G_IS_OBJECT(self->flutter_view)) {
    g_object_remove_weak_pointer(
        G_OBJECT(self->flutter_view),
        reinterpret_cast<gpointer*>(&self->flutter_view));
  }
  self->flutter_view = nullptr;
  self->main_window = nullptr;
  g_clear_pointer(&self->native_surface_window_background_color, g_free);
  g_clear_pointer(&self->native_surface_dialog_background_color, g_free);
  g_clear_pointer(&self->native_surface_dialog_outline_color, g_free);
  g_clear_pointer(&self->native_surface_tooltip_background_color, g_free);
  g_clear_pointer(&self->native_surface_tooltip_foreground_color, g_free);
  g_clear_pointer(&self->native_surface_tooltip_border_color, g_free);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);

  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->start_minimized = FALSE;
  self->native_menu_channel = nullptr;
  self->window_channel = nullptr;
  self->window_close = nullptr;
  self->gtk_settings_channel = nullptr;
  self->gtk_header_icons_channel = nullptr;
  self->gtk_font_settings_event_channel = nullptr;
  self->gtk_theme_colors_event_channel = nullptr;
  self->gtk_animation_settings_event_channel = nullptr;
  self->gtk_window_preferences_event_channel = nullptr;
  self->gtk_header_icons_changed_event_channel = nullptr;
  self->gtk_window_preferences =
      new BusyDataGtkWindowPreferencesWatcher();
  self->gtk_header_icons = nullptr;
  self->gtk_font_settings_signal_id = 0;
  self->gtk_theme_name_signal_id = 0;
  self->gtk_theme_dark_signal_id = 0;
  self->gtk_animation_settings_signal_id = 0;
  self->gtk_font_settings_listening = FALSE;
  self->gtk_theme_colors_listening = FALSE;
  self->gtk_animation_settings_listening = FALSE;
  self->gtk_window_preferences_listening = FALSE;
  self->gtk_header_icons_listening = FALSE;
  self->gtk_header_icons_revision = 0;
  self->native_surface_css_provider = nullptr;
  self->native_surface_window_background_color =
      g_strdup(kDefaultWindowBackgroundColor);
  self->native_surface_dialog_background_color = nullptr;
  self->native_surface_dialog_outline_color =
      g_strdup(kDefaultDialogOutlineColor);
  self->native_surface_tooltip_background_color = nullptr;
  self->native_surface_tooltip_foreground_color = nullptr;
  self->native_surface_tooltip_border_color = nullptr;
  self->native_surface_tooltip_radius = kDefaultTooltipRadius;
  self->native_surface_tooltip_font_size = kDefaultTooltipFontSize;
  self->native_surface_tooltip_horizontal_padding =
      kDefaultTooltipHorizontalPadding;
  self->native_surface_tooltip_vertical_padding =
      kDefaultTooltipVerticalPadding;
  self->native_surface_tooltip_minimum_height = kDefaultTooltipMinimumHeight;
  self->native_surface_high_contrast = FALSE;
  self->native_surface_theme_received = FALSE;
  self->main_window = nullptr;
  self->flutter_view = nullptr;
  self->hide_on_close = FALSE;
}

MyApplication* my_application_new() {
  g_set_application_name(kApplicationDisplayName);
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_DEFAULT_FLAGS,
                                     nullptr));
}
