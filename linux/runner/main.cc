#include "my_application.h"

#include <malloc.h>
#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
  // Set before GTK/Flutter start their worker threads. Keep freed large buffers
  // independently releasable rather than letting glibc's adaptive thresholds
  // retain them in an increasing number of thread arenas.
  if (mallopt(M_ARENA_MAX, 2) == 0 ||
      mallopt(M_MMAP_THRESHOLD, 128 * 1024) == 0 ||
      mallopt(M_TRIM_THRESHOLD, 128 * 1024) == 0) {
    std::fputs("BusyData native allocation policy initialization failed.\n",
               stderr);
    return EXIT_FAILURE;
  }
  // Prefer the native GNOME Wayland path. Compact Agenda positioning is exact
  // only when the process is actually running on X11/XWayland; Mutter may
  // center normal GTK top-level windows on Wayland.
  gdk_set_allowed_backends("wayland,x11");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
