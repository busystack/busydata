#ifndef RUNNER_BUSYDATA_ACCESSIBILITY_BRIDGE_H_
#define RUNNER_BUSYDATA_ACCESSIBILITY_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// Application-owned GTK host and ATK presentation. The returned host owns the
// supplied FlView as its child. It never changes Flutter/GTK class interfaces.
GtkWidget* busydata_accessibility_bridge_new(FlView* view);

#endif  // RUNNER_BUSYDATA_ACCESSIBILITY_BRIDGE_H_
