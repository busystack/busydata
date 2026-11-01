#ifndef BUSYDATA_WINDOW_CLOSE_H_
#define BUSYDATA_WINDOW_CLOSE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE(BusyDataWindowClose, busydata_window_close, BUSYDATA,
                    WINDOW_CLOSE, GObject)

// Owns only a cancellable close request. No SDK channel handler is registered.
BusyDataWindowClose* busydata_window_close_new(GApplication* application,
                                              GtkWindow* window,
                                              FlBinaryMessenger* messenger);
void busydata_window_close_request(BusyDataWindowClose* self);
void busydata_window_close_cancel(BusyDataWindowClose* self);

G_END_DECLS

#endif  // BUSYDATA_WINDOW_CLOSE_H_
