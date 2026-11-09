// Protected Windows secret entry through public Win32 and Flutter APIs.
#ifndef BUSYDATA_WINDOWS_SECRET_INPUT_H_
#define BUSYDATA_WINDOWS_SECRET_INPUT_H_
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/binary_messenger.h>
#include <windows.h>
#include <map>
#include <memory>
#include <string>
class WindowsSecretInput {
 public:
  WindowsSecretInput(HWND root, HWND view, flutter::BinaryMessenger* messenger);
  ~WindowsSecretInput();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam, LRESULT* result);
 private:
  struct Field;
  static LRESULT CALLBACK EditProcedure(HWND, UINT, WPARAM, LPARAM);
  void Emit(Field& field);
  void Destroy(int64_t id);
  std::string owner_;
  HWND root_, view_;
  std::map<int64_t, std::unique_ptr<Field>> fields_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
