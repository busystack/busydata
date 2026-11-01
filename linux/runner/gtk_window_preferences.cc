#include "gtk_window_preferences.h"

#include <utility>

namespace {

constexpr char kDefaultDecorationLayout[] =
    "menu:minimize,maximize,close";
constexpr char kDefaultDoubleClick[] = "toggle-maximize";
constexpr char kDefaultMiddleClick[] = "none";
constexpr char kDefaultRightClick[] = "menu";

std::string ValueOrDefault(const gchar* value, const char* fallback) {
  return value != nullptr ? value : fallback;
}

}  // namespace

BusyDataGtkWindowPreferencesWatcher::BusyDataGtkWindowPreferencesWatcher(
    GtkSettings* settings)
    : settings_(settings) {}

BusyDataGtkWindowPreferencesWatcher::~BusyDataGtkWindowPreferencesWatcher() {
  Stop();
}

BusyDataGtkWindowPreferences BusyDataGtkWindowPreferencesWatcher::Read() const {
  GtkSettings* settings = ResolveSettings();
  if (settings == nullptr) return Defaults();

  gchar* decoration_layout = nullptr;
  gchar* double_click = nullptr;
  gchar* middle_click = nullptr;
  gchar* right_click = nullptr;
  g_object_get(settings,
               "gtk-decoration-layout", &decoration_layout,
               "gtk-titlebar-double-click", &double_click,
               "gtk-titlebar-middle-click", &middle_click,
               "gtk-titlebar-right-click", &right_click,
               nullptr);
  BusyDataGtkWindowPreferences preferences = {
      ValueOrDefault(decoration_layout, kDefaultDecorationLayout),
      ValueOrDefault(double_click, kDefaultDoubleClick),
      ValueOrDefault(middle_click, kDefaultMiddleClick),
      ValueOrDefault(right_click, kDefaultRightClick),
  };
  g_free(decoration_layout);
  g_free(double_click);
  g_free(middle_click);
  g_free(right_click);
  return preferences;
}

BusyDataGtkWindowPreferences
BusyDataGtkWindowPreferencesWatcher::Defaults() {
  return {
      kDefaultDecorationLayout,
      kDefaultDoubleClick,
      kDefaultMiddleClick,
      kDefaultRightClick,
  };
}

bool BusyDataGtkWindowPreferencesWatcher::Start(ChangedCallback callback) {
  callback_ = std::move(callback);
  if (signal_ids_[0] != 0) return true;

  settings_ = ResolveSettings();
  if (settings_ == nullptr) return false;

  constexpr const char* kSignals[] = {
      "notify::gtk-decoration-layout",
      "notify::gtk-titlebar-double-click",
      "notify::gtk-titlebar-middle-click",
      "notify::gtk-titlebar-right-click",
  };
  for (std::size_t index = 0; index < signal_ids_.size(); index++) {
    signal_ids_[index] =
        g_signal_connect(settings_, kSignals[index],
                         G_CALLBACK(OnSettingChanged), this);
  }
  return true;
}

void BusyDataGtkWindowPreferencesWatcher::Stop() {
  if (settings_ != nullptr) {
    for (gulong signal : signal_ids_) {
      if (signal != 0 && g_signal_handler_is_connected(settings_, signal)) {
        g_signal_handler_disconnect(settings_, signal);
      }
    }
  }
  signal_ids_ = {0, 0, 0, 0};
  callback_ = nullptr;
}

std::array<gulong, 4>
BusyDataGtkWindowPreferencesWatcher::signal_ids() const {
  return signal_ids_;
}

void BusyDataGtkWindowPreferencesWatcher::OnSettingChanged(
    GObject*, GParamSpec*, gpointer user_data) {
  auto* watcher =
      static_cast<BusyDataGtkWindowPreferencesWatcher*>(user_data);
  if (watcher->callback_) watcher->callback_(watcher->Read());
}

GtkSettings* BusyDataGtkWindowPreferencesWatcher::ResolveSettings() const {
  return settings_ != nullptr ? settings_ : gtk_settings_get_default();
}
