#include "single_instance.h"


#include <sddl.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <memory>
#include <system_error>
#include <utility>

namespace {

constexpr DWORD kMaximumActivationBytes = 16 * 1024;
constexpr DWORD kActivationConnectTimeoutMilliseconds = 5000;
constexpr wchar_t kPipePrefix[] = L"\\\\.\\pipe\\BusyData-Activation-";
constexpr wchar_t kMutexPrefix[] = L"Local\\BusyData-SingleInstance-";

HANDLE ConnectToActivationPipe(const std::wstring& pipe_name) {
  const ULONGLONG deadline =
      GetTickCount64() + kActivationConnectTimeoutMilliseconds;
  while (true) {
    HANDLE pipe = CreateFileW(pipe_name.c_str(), GENERIC_READ | GENERIC_WRITE,
                              0, nullptr, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) return pipe;

    const DWORD error = GetLastError();
    if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PIPE_BUSY) {
      return INVALID_HANDLE_VALUE;
    }
    const ULONGLONG now = GetTickCount64();
    if (now >= deadline) return INVALID_HANDLE_VALUE;
    const DWORD remaining = static_cast<DWORD>(deadline - now);

    if (error == ERROR_PIPE_BUSY) {
      if (!WaitNamedPipeW(pipe_name.c_str(), remaining)) {
        const DWORD wait_error = GetLastError();
        if (wait_error != ERROR_FILE_NOT_FOUND &&
            wait_error != ERROR_SEM_TIMEOUT) {
          return INVALID_HANDLE_VALUE;
        }
      }
    } else {
      // A newly elected primary owns the mutex before its listener thread has
      // created the first pipe instance. Retry that short startup window.
      Sleep(std::min<DWORD>(remaining, 25));
    }
  }
}

bool ReadExact(HANDLE pipe, void* destination, DWORD bytes) {
  auto* cursor = static_cast<unsigned char*>(destination);
  DWORD total = 0;
  while (total < bytes) {
    DWORD read = 0;
    if (!ReadFile(pipe, cursor + total, bytes - total, &read, nullptr) ||
        read == 0) {
      return false;
    }
    total += read;
  }
  return true;
}

bool WriteExact(HANDLE pipe, const void* source, DWORD bytes) {
  const auto* cursor = static_cast<const unsigned char*>(source);
  DWORD total = 0;
  while (total < bytes) {
    DWORD written = 0;
    if (!WriteFile(pipe, cursor + total, bytes - total, &written, nullptr) ||
        written == 0) {
      return false;
    }
    total += written;
  }
  return true;
}

bool ReadAcknowledgmentWithTimeout(HANDLE pipe, uint8_t* acknowledgment) {
  if (acknowledgment == nullptr) return false;
  const ULONGLONG deadline =
      GetTickCount64() + kActivationConnectTimeoutMilliseconds;
  while (GetTickCount64() < deadline) {
    DWORD available = 0;
    if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) {
      return false;
    }
    if (available >= sizeof(*acknowledgment)) {
      return ReadExact(pipe, acknowledgment, sizeof(*acknowledgment));
    }
    Sleep(10);
  }
  return false;
}

std::wstring CurrentUserSid() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return L"";
  DWORD length = 0;
  if (GetTokenInformation(token, TokenUser, nullptr, 0, &length) ||
      GetLastError() != ERROR_INSUFFICIENT_BUFFER || length == 0) {
    CloseHandle(token);
    return L"";
  }
  std::vector<unsigned char> buffer(length, 0);
  if (!GetTokenInformation(token, TokenUser, buffer.data(), length, &length)) {
    CloseHandle(token);
    return L"";
  }
  CloseHandle(token);
  const auto* user = reinterpret_cast<const TOKEN_USER*>(buffer.data());
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(user->User.Sid, &sid)) return L"";
  std::wstring value(sid);
  LocalFree(sid);
  return value;
}

BusyDataSingleInstanceNativeHooks DefaultHooks() {
  BusyDataSingleInstanceNativeHooks hooks;
  hooks.current_user_sid = CurrentUserSid;
  hooks.create_mutex = [](const wchar_t* name) {
    return CreateMutexW(nullptr, FALSE, name);
  };
  hooks.last_error = [] { return GetLastError(); };
  hooks.create_pipe = [](const wchar_t* name, SECURITY_ATTRIBUTES* attributes) {
    return CreateNamedPipeW(
        name, PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
            PIPE_REJECT_REMOTE_CLIENTS,
        1, sizeof(uint8_t), kMaximumActivationBytes + sizeof(uint32_t), 5000,
        attributes);
  };
  hooks.close_handle = [](HANDLE handle) { CloseHandle(handle); };
  return hooks;
}

}  // namespace

BusyDataSingleInstanceNativeHooks DefaultBusyDataSingleInstanceNativeHooks() {
  return DefaultHooks();
}

BusyDataSingleInstance::BusyDataSingleInstance()
    : BusyDataSingleInstance(DefaultBusyDataSingleInstanceNativeHooks()) {}

BusyDataSingleInstance::BusyDataSingleInstance(
    BusyDataSingleInstanceNativeHooks hooks)
    : hooks_(std::move(hooks)) {
  if (!hooks_.current_user_sid || !hooks_.create_mutex ||
      !hooks_.last_error || !hooks_.create_pipe || !hooks_.close_handle) {
    initialization_error_ = "single-instance native hooks are incomplete";
    return;
  }
  user_sid_ = hooks_.current_user_sid();
  if (user_sid_.empty()) {
    initialization_error_ = "current-user SID lookup failed";
    return;
  }
  pipe_name_ = std::wstring(kPipePrefix) + user_sid_;
  const std::wstring mutex_name = std::wstring(kMutexPrefix) + user_sid_;
  mutex_ = hooks_.create_mutex(mutex_name.c_str());
  const DWORD mutex_error = hooks_.last_error();
  if (mutex_ == nullptr) {
    initialization_error_ = "per-user mutex creation failed";
    return;
  }
  state_ = mutex_error == ERROR_ALREADY_EXISTS
               ? BusyDataInstanceState::kSecondary
               : BusyDataInstanceState::kPrimary;
}

BusyDataSingleInstance::~BusyDataSingleInstance() {
  Stop();
  if (mutex_ != nullptr) hooks_.close_handle(mutex_);
}

BusyDataInstanceState BusyDataSingleInstance::state() const { return state_; }

bool BusyDataSingleInstance::IsPrimary() const {
  return state_ == BusyDataInstanceState::kPrimary;
}

const std::string& BusyDataSingleInstance::initialization_error() const {
  return initialization_error_;
}

bool BusyDataSingleInstance::ForwardActivation(
    const std::string& activation) const {
  if (state_ != BusyDataInstanceState::kSecondary ||
      !IsValidBusyDataActivation(activation)) {
    return false;
  }
  HANDLE pipe = ConnectToActivationPipe(pipe_name_);
  if (pipe == INVALID_HANDLE_VALUE) return false;
  ULONG server_process_id = 0;
  if (GetNamedPipeServerProcessId(pipe, &server_process_id)) {
    AllowSetForegroundWindow(server_process_id);
  }
  const uint32_t length = static_cast<uint32_t>(activation.size());
  const bool written = WriteExact(pipe, &length, sizeof(length)) &&
                       WriteExact(pipe, activation.data(), length);
  uint8_t acknowledgment = 0;
  const bool acknowledged =
      written && ReadAcknowledgmentWithTimeout(pipe, &acknowledgment);
  hooks_.close_handle(pipe);
  return acknowledged && acknowledgment == 1;
}

bool BusyDataSingleInstance::Start(
    std::function<void(std::string)> on_activation,
    std::function<void()> on_listener_failure) {
  if (state_ != BusyDataInstanceState::kPrimary || listener_.joinable()) {
    return false;
  }
  stopping_ = false;
  {
    std::scoped_lock lock(listener_start_mutex_);
    listener_start_complete_ = false;
    listener_start_succeeded_ = false;
    listener_start_error_.clear();
  }
  on_activation_ = std::move(on_activation);
  on_listener_failure_ = std::move(on_listener_failure);
  try {
    listener_ = std::thread(&BusyDataSingleInstance::Listen, this);
  } catch (const std::system_error&) {
    initialization_error_ = "named-pipe listener thread creation failed";
    state_ = BusyDataInstanceState::kFatalInitializationFailure;
    return false;
  }
  std::unique_lock lock(listener_start_mutex_);
  const bool acknowledged = listener_start_condition_.wait_for(
      lock, std::chrono::seconds(5),
      [this] { return listener_start_complete_; });
  if (!acknowledged) {
    initialization_error_ = "named-pipe listener startup timed out";
    lock.unlock();
    Stop();
    state_ = BusyDataInstanceState::kFatalInitializationFailure;
    return false;
  }
  if (!listener_start_succeeded_) {
    initialization_error_ = listener_start_error_;
    lock.unlock();
    if (listener_.joinable()) listener_.join();
    state_ = BusyDataInstanceState::kFatalInitializationFailure;
    return false;
  }
  return true;
}

void BusyDataSingleInstance::Stop() {
  if (!listener_.joinable()) return;
  stopping_ = true;
  HANDLE pipe = CreateFileW(pipe_name_.c_str(), GENERIC_READ | GENERIC_WRITE,
                            0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (pipe != INVALID_HANDLE_VALUE) hooks_.close_handle(pipe);
  CancelSynchronousIo(static_cast<HANDLE>(listener_.native_handle()));
  listener_.join();
}

HANDLE BusyDataSingleInstance::CreateSecuredPipe(
    SECURITY_ATTRIBUTES* attributes) const {
  return hooks_.create_pipe(pipe_name_.c_str(), attributes);
}

void BusyDataSingleInstance::CompleteListenerStartup(bool succeeded,
                                                    std::string error) {
  {
    std::scoped_lock lock(listener_start_mutex_);
    if (listener_start_complete_) return;
    listener_start_succeeded_ = succeeded;
    listener_start_error_ = std::move(error);
    listener_start_complete_ = true;
  }
  listener_start_condition_.notify_one();
}

void BusyDataSingleInstance::Listen() {
  const std::wstring sddl = L"D:P(A;;GA;;;" + user_sid_ + L")";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) {
    CompleteListenerStartup(false,
                            "named-pipe security descriptor creation failed");
    return;
  }
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), descriptor,
                                 FALSE};
  HANDLE pipe = CreateSecuredPipe(&attributes);
  if (pipe == INVALID_HANDLE_VALUE) {
    LocalFree(descriptor);
    CompleteListenerStartup(false, "secured named-pipe creation failed");
    return;
  }
  CompleteListenerStartup(true, "");
  while (!stopping_) {
    const bool connected = ConnectNamedPipe(pipe, nullptr) ||
                           GetLastError() == ERROR_PIPE_CONNECTED;
    uint8_t acknowledgment = 0;
    if (connected && !stopping_) {
      uint32_t length = 0;
      if (ReadExact(pipe, &length, sizeof(length)) && length > 0 &&
          length <= kMaximumActivationBytes) {
        std::string message(length, '\0');
        if (ReadExact(pipe, message.data(), length) &&
            IsValidBusyDataActivation(message)) {
          if (on_activation_) {
            on_activation_(std::move(message));
            acknowledgment = 1;
          }
        }
      }
      WriteExact(pipe, &acknowledgment, sizeof(acknowledgment));
      FlushFileBuffers(pipe);
    }
    DisconnectNamedPipe(pipe);
    hooks_.close_handle(pipe);
    pipe = INVALID_HANDLE_VALUE;
    if (!stopping_) {
      pipe = CreateSecuredPipe(&attributes);
      if (pipe == INVALID_HANDLE_VALUE) {
        MessageBoxW(nullptr,
                    L"BusyData lost its secured activation channel. Close "
                    L"BusyData before starting it again.",
                    L"BusyData activation error", MB_OK | MB_ICONERROR);
        if (on_listener_failure_) on_listener_failure_();
        break;
      }
    }
  }
  if (pipe != INVALID_HANDLE_VALUE) hooks_.close_handle(pipe);
  LocalFree(descriptor);
}

std::string BuildBusyDataActivation(const std::vector<std::string>&) { return R"({"version":1,"kind":"normalLaunch"})"; }
bool IsValidBusyDataActivation(const std::string& activation) { return activation == R"({"version":1,"kind":"normalLaunch"})"; }
