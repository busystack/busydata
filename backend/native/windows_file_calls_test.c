#include "windows_file_calls.h"
#include <stdio.h>
#include <wchar.h>
#include <string.h>
#define REQUIRE(condition) do { if (!(condition)) { fprintf(stderr, "failure at line %d\n", __LINE__); return 1; } } while (0)
int main(void) {
  WCHAR directory[MAX_PATH], first[MAX_PATH], second[MAX_PATH];
  DWORD error, count;
  BY_HANDLE_FILE_INFORMATION info;
  char data[4] = {0};
  REQUIRE(GetTempPathW(MAX_PATH, directory) > 0);
  REQUIRE(GetTempFileNameW(directory, L"bdf", 0, first) != 0);
  REQUIRE(GetTempFileNameW(directory, L"bdf", 0, second) != 0);
  REQUIRE(DeleteFileW(first));
  HANDLE missing = busydata_create_file_w(first, FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL, &error);
  SetLastError(ERROR_SUCCESS); /* Dart/runtime work cannot change the returned error. */
  REQUIRE(missing == INVALID_HANDLE_VALUE && error == ERROR_FILE_NOT_FOUND);
  HANDLE file = busydata_create_file_w(first, GENERIC_READ | GENERIC_WRITE, 0,
      NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL, &error);
  REQUIRE(file != INVALID_HANDLE_VALUE && error == ERROR_SUCCESS);
  HANDLE denied = busydata_create_file_w(first, GENERIC_READ, FILE_SHARE_READ,
      NULL, OPEN_EXISTING, 0, NULL, &error);
  SetLastError(ERROR_SUCCESS);
  REQUIRE(denied == INVALID_HANDLE_VALUE && error == ERROR_SHARING_VIOLATION);
  REQUIRE(busydata_write_file(file, "abc", 3, &count, NULL, &error));
  REQUIRE(count == 3 && error == ERROR_SUCCESS);
  REQUIRE(busydata_flush_file(file, &error) && error == ERROR_SUCCESS);
  REQUIRE(busydata_file_information(file, &info, &error) && error == ERROR_SUCCESS);
  REQUIRE(info.nFileSizeHigh == 0 && info.nFileSizeLow == 3);
  REQUIRE(SetFilePointer(file, 0, NULL, FILE_BEGIN) != INVALID_SET_FILE_POINTER);
  REQUIRE(busydata_read_file(file, data, 3, &count, NULL, &error));
  REQUIRE(count == 3 && memcmp(data, "abc", 3) == 0 && error == ERROR_SUCCESS);
  WCHAR final_path[32768];
  REQUIRE(busydata_final_path_w(file, final_path, 32768, 0, &error) > 0 && error == ERROR_SUCCESS);
  REQUIRE(CloseHandle(file));
  REQUIRE(!busydata_move_file_w(first, second, MOVEFILE_WRITE_THROUGH, &error));
  SetLastError(ERROR_SUCCESS);
  REQUIRE(error == ERROR_ALREADY_EXISTS || error == ERROR_FILE_EXISTS);
  REQUIRE(DeleteFileW(second));
  REQUIRE(busydata_move_file_w(first, second, MOVEFILE_WRITE_THROUGH, &error) && error == ERROR_SUCCESS);
  REQUIRE(DeleteFileW(second));
  REQUIRE(!busydata_file_information(INVALID_HANDLE_VALUE, &info, &error));
  SetLastError(ERROR_SUCCESS); REQUIRE(error == ERROR_INVALID_HANDLE);
  puts("Win32 file results/errors, no-clobber, exact bytes and owned handle cleanup passed");
  return 0;
}
