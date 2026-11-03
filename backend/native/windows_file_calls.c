/* First-party FFI boundary: retain Win32 errors before returning to Dart.
 * No file policy, path resolution, retry, handle ownership or fallback lives here. */
#define BUSYDATA_WINDOWS_FILES_BUILD
#include "windows_file_calls.h"

HANDLE busydata_create_file_w(LPCWSTR name, DWORD access, DWORD share,
    LPSECURITY_ATTRIBUTES security, DWORD disposition, DWORD flags, HANDLE template_file,
    DWORD *error) {
  HANDLE result = CreateFileW(name, access, share, security, disposition, flags, template_file);
  *error = result == INVALID_HANDLE_VALUE ? GetLastError() : ERROR_SUCCESS;
  return result;
}
BOOL busydata_file_information(HANDLE file, LPBY_HANDLE_FILE_INFORMATION info, DWORD *error) {
  BOOL result = GetFileInformationByHandle(file, info);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
BOOL busydata_read_file(HANDLE file, void *buffer, DWORD size, DWORD *read,
    LPOVERLAPPED overlapped, DWORD *error) {
  BOOL result = ReadFile(file, buffer, size, read, overlapped);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
BOOL busydata_write_file(HANDLE file, const void *buffer, DWORD size, DWORD *written,
    LPOVERLAPPED overlapped, DWORD *error) {
  BOOL result = WriteFile(file, buffer, size, written, overlapped);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
BOOL busydata_flush_file(HANDLE file, DWORD *error) {
  BOOL result = FlushFileBuffers(file);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
BOOL busydata_move_file_w(LPCWSTR source, LPCWSTR destination, DWORD flags, DWORD *error) {
  BOOL result = MoveFileExW(source, destination, flags);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
DWORD busydata_final_path_w(HANDLE file, LPWSTR buffer, DWORD size, DWORD flags, DWORD *error) {
  DWORD result = GetFinalPathNameByHandleW(file, buffer, size, flags);
  *error = result ? ERROR_SUCCESS : GetLastError();
  return result;
}
