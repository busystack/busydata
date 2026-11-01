#include "../single_instance.h"

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void Check(bool condition, const char* description) {
  if (condition) return;
  ++failures;
  std::cerr << "FAILED: " << description << std::endl;
}

void TestActivationValidation() {
  Check(IsValidBusyDataActivation(R"({"version":1,"kind":"normalLaunch"})"), "normal activation");
  Check(!IsValidBusyDataActivation("not-json"), "malformed activation rejected");
  Check(!IsValidBusyDataActivation(std::string(16 * 1024 + 1, 'x')), "oversized activation rejected");
}

void TestFatalInitializationStates() {
  auto sid_failure = DefaultBusyDataSingleInstanceNativeHooks();
  sid_failure.current_user_sid = [] { return std::wstring(); };
  BusyDataSingleInstance no_sid(std::move(sid_failure));
  Check(no_sid.state() ==
            BusyDataInstanceState::kFatalInitializationFailure,
        "SID failure is fatal");

  auto mutex_failure = DefaultBusyDataSingleInstanceNativeHooks();
  mutex_failure.create_mutex = [](const wchar_t*) -> HANDLE { return nullptr; };
  mutex_failure.last_error = [] { return ERROR_ACCESS_DENIED; };
  BusyDataSingleInstance no_mutex(std::move(mutex_failure));
  Check(no_mutex.state() ==
            BusyDataInstanceState::kFatalInitializationFailure,
        "mutex failure is fatal");
}

void TestListenerStartupAcknowledgmentFailure() {
  auto hooks = DefaultBusyDataSingleInstanceNativeHooks();
  hooks.create_pipe = [](const wchar_t*, SECURITY_ATTRIBUTES*) {
    SetLastError(ERROR_ACCESS_DENIED);
    return INVALID_HANDLE_VALUE;
  };
  BusyDataSingleInstance instance(std::move(hooks));
  if (instance.state() != BusyDataInstanceState::kPrimary) {
    Check(false, "test requires an isolated primary-instance identity");
    return;
  }
  Check(!instance.Start([](std::string) {}),
        "listener startup failure is acknowledged");
  Check(instance.state() ==
            BusyDataInstanceState::kFatalInitializationFailure,
        "listener startup failure becomes fatal");
}

void TestSimultaneousStartAndPipeAcknowledgment() {
  BusyDataSingleInstance primary;
  if (primary.state() != BusyDataInstanceState::kPrimary) { Check(false, "primary-instance test environment is not isolated"); return; }
  std::atomic<int> activations = 0;
  std::mutex received_mutex;
  std::vector<std::string> received;
  Check(primary.Start([&](std::string activation) {
          if (IsValidBusyDataActivation(activation)) {
            std::lock_guard<std::mutex> lock(received_mutex);
            received.push_back(activation);
            ++activations;
          }
        }),
        "primary listener starts before application data");

  BusyDataSingleInstance secondary;
  Check(secondary.state() == BusyDataInstanceState::kSecondary,
        "simultaneous process is secondary");
  Check(secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "secondary receives pipe acknowledgment");
  const ULONGLONG deadline = GetTickCount64() + 1000;
  while (activations.load() == 0 && GetTickCount64() < deadline) Sleep(5);
  Check(activations.load() == 1, "primary receives one activation");

  // Repeated launches retain exact forwarding without creating another writer.
  for (int launch = 0; launch < 3; ++launch) {
    Check(secondary.ForwardActivation(R"({"version":1,"kind":"normalLaunch"})"),
          "repeated launch receives native acknowledgment");
    const ULONGLONG launch_deadline = GetTickCount64() + 1000;
    while (activations.load() < launch + 2 && GetTickCount64() < launch_deadline) Sleep(5);
    Check(activations.load() == launch + 2, "one activation per launch");
    std::lock_guard<std::mutex> lock(received_mutex);
    Check(received.back() == R"({"version":1,"kind":"normalLaunch"})",
          "native forwarding preserves the launch payload");
  }
  Check(!secondary.ForwardActivation("not-json"), "malformed activation is rejected");
  Check(!secondary.ForwardActivation(R"({"version":1,"kind":"executeSql","sql":"DROP TABLE t"})"),
        "activation cannot execute SQL");
  Check(activations.load() == 4, "rejected payloads do not reach the primary");

  primary.Stop();
  Check(!secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "terminating primary does not permit a second database writer");
}

void TestForwardingTimeoutIsBounded() {
  const std::wstring sid =
      L"BusyDataNativeTimeoutTest-" + std::to_wstring(GetCurrentProcessId());
  const std::wstring pipe_name = L"\\\\.\\pipe\\BusyData-Activation-" + sid;
  HANDLE server = CreateNamedPipeW(
      pipe_name.c_str(), PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
      1, 1, 16 * 1024 + sizeof(uint32_t), 5000, nullptr);
  Check(server != INVALID_HANDLE_VALUE, "timeout test creates stale pipe");
  if (server == INVALID_HANDLE_VALUE) return;

  std::thread hung_server([server] {
    if (ConnectNamedPipe(server, nullptr) ||
        GetLastError() == ERROR_PIPE_CONNECTED) {
      uint32_t length = 0;
      DWORD read = 0;
      ReadFile(server, &length, sizeof(length), &read, nullptr);
      std::vector<char> body(length);
      if (length > 0 && length <= 16 * 1024) {
        ReadFile(server, body.data(), length, &read, nullptr);
      }
      // Simulate a stale or terminating primary that accepted the activation
      // but never acknowledged it.
      Sleep(5500);
    }
    DisconnectNamedPipe(server);
    CloseHandle(server);
  });

  auto hooks = DefaultBusyDataSingleInstanceNativeHooks();
  hooks.current_user_sid = [sid] { return sid; };
  hooks.create_mutex = [](const wchar_t*) {
    return CreateEventW(nullptr, TRUE, FALSE, nullptr);
  };
  hooks.last_error = [] { return ERROR_ALREADY_EXISTS; };
  BusyDataSingleInstance secondary(std::move(hooks));
  const ULONGLONG started = GetTickCount64();
  Check(!secondary.ForwardActivation(
            R"({"version":1,"kind":"normalLaunch"})"),
        "forwarding without acknowledgment fails");
  const ULONGLONG elapsed = GetTickCount64() - started;
  Check(elapsed >= 4000 && elapsed < 8000,
        "forwarding acknowledgment timeout is bounded");
  hung_server.join();
}

}  // namespace

int main() {
  TestActivationValidation();
  TestFatalInitializationStates();
  TestListenerStartupAcknowledgmentFailure();
  TestSimultaneousStartAndPipeAcknowledgment();
  TestForwardingTimeoutIsBounded();
  if (failures == 0) {
    std::cout << "BusyData single-instance native tests passed." << std::endl;
  }
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
