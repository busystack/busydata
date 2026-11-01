#!/usr/bin/env python3
"""Own a bounded UTF-8 fixture selection on the isolated test X display.
Never shipped or called by the product. A GTK request and X server round trip
acknowledge delivery; the controller retains ownership until its target confirms
the exact text. An assistive reader's clipboard request is not that confirmation.
"""
import ctypes
import json
import os
import select
import sys
import time


def main():
    value = sys.stdin.buffer.readline(4097)
    if not value.endswith(b'\n') or len(value) > 4096 or b'\0' in value:
        raise ValueError('Native picker fixture byte limit or framing')
    value = value[:-1]
    value.decode('utf-8', errors='strict')
    # The controller owns Xvfb. Do not follow an inherited Wayland desktop.
    os.environ['GDK_BACKEND'] = 'x11'
    gtk = ctypes.CDLL('libgtk-3.so.0')
    gdk = ctypes.CDLL('libgdk-3.so.0')
    gtk.gtk_init_check.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    gtk.gtk_init_check.restype = ctypes.c_int
    if not gtk.gtk_init_check(None, None):
        raise RuntimeError('Owned native test display unavailable')
    gdk.gdk_atom_intern_static_string.argtypes = [ctypes.c_char_p]
    gdk.gdk_atom_intern_static_string.restype = ctypes.c_void_p
    gdk.gdk_display_get_default.restype = ctypes.c_void_p
    gdk.gdk_display_sync.argtypes = [ctypes.c_void_p]
    gtk.gtk_clipboard_get.argtypes = [ctypes.c_void_p]
    gtk.gtk_clipboard_get.restype = ctypes.c_void_p
    gtk.gtk_selection_data_set_text.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    served = False

    class Target(ctypes.Structure):
        _fields_ = [('target', ctypes.c_char_p), ('flags', ctypes.c_uint), ('info', ctypes.c_uint)]

    get_type = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p)
    clear_type = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_void_p)

    @get_type
    def get_selection(clipboard, data, info, user):
        nonlocal served
        gtk.gtk_selection_data_set_text(data, value, len(value))
        served = True

    @clear_type
    def clear_selection(clipboard, user):
        pass

    gtk.gtk_clipboard_set_with_data.argtypes = [ctypes.c_void_p, ctypes.POINTER(Target), ctypes.c_uint, get_type, clear_type, ctypes.c_void_p]
    gtk.gtk_clipboard_set_with_data.restype = ctypes.c_int
    target = Target(b'UTF8_STRING', 0, 0)
    clipboard = gtk.gtk_clipboard_get(gdk.gdk_atom_intern_static_string(b'CLIPBOARD'))
    if not gtk.gtk_clipboard_set_with_data(clipboard, ctypes.byref(target), 1, get_selection, clear_selection, None):
        raise RuntimeError('Native fixture clipboard ownership failed')
    display = gdk.gdk_display_get_default()
    gdk.gdk_display_sync(display)
    print(json.dumps({'ready': True}), flush=True)
    announced = False
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        while gtk.gtk_events_pending():
            gtk.gtk_main_iteration_do(False)
        if served and not announced:
            gdk.gdk_display_sync(display)
            print(json.dumps({'served': True}), flush=True)
            announced = True
        if select.select([sys.stdin], [], [], .01)[0]:
            if os.read(sys.stdin.fileno(), 1):
                raise ValueError('Unexpected native fixture control')
            return 0 if served else 1
    raise TimeoutError('Native fixture clipboard deadline')


if __name__ == '__main__':
    raise SystemExit(main())
