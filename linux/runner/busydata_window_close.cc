#include "busydata_window_close.h"

#include <cstdint>
#include <limits>

namespace busydata_window_close_detail {

constexpr gsize kCloseReplyMaxBytes = 1024;

struct PendingClose {
  GWeakRef owner;
  GWeakRef window;
  uint64_t generation;
  GCancellable* cancellable = nullptr;
  ~PendingClose() {
    g_weak_ref_clear(&owner);
    g_weak_ref_clear(&window);
    g_clear_object(&cancellable);
  }
};

struct CloseState {
  GWeakRef application;
  GWeakRef window;
  FlBinaryMessenger* messenger = nullptr;
  FlMethodCodec* codec = nullptr;
  PendingClose* pending = nullptr;  // The public send callback owns its lifetime.
  uint64_t generation = 0;
  bool closed = false;
};

}  // namespace busydata_window_close_detail

using busydata_window_close_detail::CloseState;
using busydata_window_close_detail::PendingClose;
using busydata_window_close_detail::kCloseReplyMaxBytes;

struct _BusyDataWindowClose {
  GObject parent_instance;
  CloseState* state;
};

G_DEFINE_TYPE(BusyDataWindowClose, busydata_window_close, G_TYPE_OBJECT)

namespace {

// JSON codec parsing exposes C strings. Require a lossless official roundtrip
// before allowing a reply to authorize exit, including embedded-NUL rejection.
bool close_reply_is_exit(FlMethodCodec* codec, GBytes* bytes) {
  if (bytes == nullptr || g_bytes_get_size(bytes) > kCloseReplyMaxBytes) return false;
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = FL_METHOD_CODEC_GET_CLASS(codec)->decode_response(codec, bytes, &error);
  if (response == nullptr || !FL_IS_METHOD_SUCCESS_RESPONSE(response)) return false;
  FlValue* result = fl_method_success_response_get_result(FL_METHOD_SUCCESS_RESPONSE(response));
  if (result == nullptr || fl_value_get_type(result) != FL_VALUE_TYPE_MAP || fl_value_get_length(result) != 1) return false;
  FlValue* value = fl_value_lookup_string(result, "response");
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) return false;
  const gchar* text = fl_value_get_string(value);
  if (!g_str_equal(text, "exit")) return false;
  g_autoptr(GBytes) encoded = FL_METHOD_CODEC_GET_CLASS(codec)->encode_success_envelope(codec, result, nullptr);
  return encoded != nullptr && g_bytes_equal(encoded, bytes);
}

void close_request_finished(GObject* object, GAsyncResult* result, gpointer user_data) {
  auto* pending = static_cast<PendingClose*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GBytes) response = fl_binary_messenger_send_on_channel_finish(FL_BINARY_MESSENGER(object), result, &error);
  g_autoptr(BusyDataWindowClose) self = BUSYDATA_WINDOW_CLOSE(g_weak_ref_get(&pending->owner));
  if (self != nullptr) {
    CloseState* state = self->state;
    const bool current = !state->closed && state->pending == pending &&
        state->generation == pending->generation && !g_cancellable_is_cancelled(pending->cancellable);
    if (state->pending == pending) state->pending = nullptr;
    if (current && error == nullptr && close_reply_is_exit(state->codec, response)) {
      g_autoptr(GObject) expected_window = G_OBJECT(g_weak_ref_get(&pending->window));
      g_autoptr(GObject) window = G_OBJECT(g_weak_ref_get(&state->window));
      g_autoptr(GApplication) application = G_APPLICATION(g_weak_ref_get(&state->application));
      if (window != nullptr && window == expected_window && application != nullptr &&
          !gtk_widget_in_destruction(GTK_WIDGET(window))) {
        state->closed = true;
        g_application_quit(application);
      }
    }
  }
  delete pending;
}

void close_owner_ended(BusyDataWindowClose* self) {
  self->state->closed = true;
  busydata_window_close_cancel(self);
}

}  // namespace

static void busydata_window_close_dispose(GObject* object) {
  auto* self = BUSYDATA_WINDOW_CLOSE(object);
  close_owner_ended(self);
  g_clear_object(&self->state->messenger);
  g_clear_object(&self->state->codec);
  G_OBJECT_CLASS(busydata_window_close_parent_class)->dispose(object);
}

static void busydata_window_close_finalize(GObject* object) {
  auto* self = BUSYDATA_WINDOW_CLOSE(object);
  g_weak_ref_clear(&self->state->application);
  g_weak_ref_clear(&self->state->window);
  delete self->state;
  G_OBJECT_CLASS(busydata_window_close_parent_class)->finalize(object);
}

static void busydata_window_close_class_init(BusyDataWindowCloseClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = busydata_window_close_dispose;
  G_OBJECT_CLASS(klass)->finalize = busydata_window_close_finalize;
}

static void busydata_window_close_init(BusyDataWindowClose* self) {
  self->state = new CloseState;
  g_weak_ref_init(&self->state->application, nullptr);
  g_weak_ref_init(&self->state->window, nullptr);
}

BusyDataWindowClose* busydata_window_close_new(GApplication* application,
                                              GtkWindow* window,
                                              FlBinaryMessenger* messenger) {
  g_return_val_if_fail(G_IS_APPLICATION(application), nullptr);
  g_return_val_if_fail(GTK_IS_WINDOW(window), nullptr);
  g_return_val_if_fail(FL_IS_BINARY_MESSENGER(messenger), nullptr);
  auto* self = BUSYDATA_WINDOW_CLOSE(g_object_new(busydata_window_close_get_type(), nullptr));
  g_weak_ref_set(&self->state->application, application);
  g_weak_ref_set(&self->state->window, window);
  self->state->messenger = FL_BINARY_MESSENGER(g_object_ref(messenger));
  self->state->codec = FL_METHOD_CODEC(fl_json_method_codec_new());
  g_signal_connect_object(window, "destroy", G_CALLBACK(close_owner_ended), self, G_CONNECT_SWAPPED);
  g_signal_connect_object(application, "shutdown", G_CALLBACK(close_owner_ended), self, G_CONNECT_SWAPPED);
  return self;
}

void busydata_window_close_cancel(BusyDataWindowClose* self) {
  g_return_if_fail(BUSYDATA_IS_WINDOW_CLOSE(self));
  if (self->state->generation != std::numeric_limits<uint64_t>::max()) ++self->state->generation;
  if (self->state->pending != nullptr) g_cancellable_cancel(self->state->pending->cancellable);
}

void busydata_window_close_request(BusyDataWindowClose* self) {
  g_return_if_fail(BUSYDATA_IS_WINDOW_CLOSE(self));
  CloseState* state = self->state;
  if (state->closed || state->pending != nullptr || state->messenger == nullptr ||
      state->generation == std::numeric_limits<uint64_t>::max()) return;
  g_autoptr(GObject) window = G_OBJECT(g_weak_ref_get(&state->window));
  g_autoptr(GObject) application = G_OBJECT(g_weak_ref_get(&state->application));
  if (window == nullptr || application == nullptr || gtk_widget_in_destruction(GTK_WIDGET(window))) return;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "type", fl_value_new_string("cancelable"));
  g_autoptr(GBytes) message = FL_METHOD_CODEC_GET_CLASS(state->codec)->encode_method_call(
      state->codec, "System.requestAppExit", args, nullptr);
  if (message == nullptr) return;
  auto* pending = new PendingClose;
  g_weak_ref_init(&pending->owner, self);
  g_weak_ref_init(&pending->window, window);
  pending->generation = ++state->generation;
  pending->cancellable = g_cancellable_new();
  state->pending = pending;
  // Sending bytes does not register or replace the engine's platform handler.
  fl_binary_messenger_send_on_channel(state->messenger, "flutter/platform", message,
                                     pending->cancellable, close_request_finished, pending);
}
