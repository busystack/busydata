#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <cstdlib>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const std::string initial_activation =
      BuildBusyDataActivation(command_line_arguments);
  BusyDataSingleInstance single_instance;
  if (single_instance.state() ==
      BusyDataInstanceState::kFatalInitializationFailure) {
    MessageBoxW(nullptr,
                L"BusyData could not initialize its per-user single-instance "
                L"guard. No application data was opened.",
                L"BusyData startup error", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  if (single_instance.state() == BusyDataInstanceState::kSecondary) {
    return single_instance.ForwardActivation(initial_activation) ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for plugins and packaged Windows
  // APIs such as StartupTask.
  const HRESULT com_result =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(com_result)) {
    MessageBoxW(nullptr, L"BusyData could not initialize Windows COM services.",
                L"BusyData startup error", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  const bool start_hidden = false;
  FlutterWindow window(
      project, {initial_activation}, start_hidden,
      [&single_instance](const std::string& activation) {
        return single_instance.ForwardActivation(activation);
      });
  const DWORD main_thread_id = GetCurrentThreadId();
  // Create the main-thread message queue before the listener can report a
  // fatal post-start failure from its worker thread.
  MSG pending_message{};
  PeekMessageW(&pending_message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  if (single_instance.IsPrimary()) {
    if (!single_instance.Start([&window](std::string activation) {
          window.QueueActivation(std::move(activation));
        }, [main_thread_id] {
          PostThreadMessageW(main_thread_id, WM_QUIT, EXIT_FAILURE, 0);
        })) {
      MessageBoxW(nullptr,
                  L"BusyData could not start its secured activation channel. "
                  L"No application data was opened.",
                  L"BusyData startup error", MB_OK | MB_ICONERROR);
      ::CoUninitialize();
      return EXIT_FAILURE;
    }
  }
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"BusyData", origin, size)) {
    single_instance.Stop();
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg{};
  BOOL message_result = 0;
  while ((message_result = ::GetMessage(&msg, nullptr, 0, 0)) > 0) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
  const int process_result = message_result == -1 || msg.wParam != 0
                                 ? EXIT_FAILURE
                                 : EXIT_SUCCESS;

  single_instance.Stop();
  if (SUCCEEDED(com_result)) {
    ::CoUninitialize();
  }
  return process_result;
}
