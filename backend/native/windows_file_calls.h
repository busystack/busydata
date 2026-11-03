#ifndef BUSYDATA_WINDOWS_FILE_CALLS_H
#define BUSYDATA_WINDOWS_FILE_CALLS_H
#include <windows.h>
#ifdef BUSYDATA_WINDOWS_FILES_BUILD
#define BD_FILES_API __declspec(dllexport)
#else
#define BD_FILES_API __declspec(dllimport)
#endif
BD_FILES_API HANDLE busydata_create_file_w(LPCWSTR name, DWORD access, DWORD share,
    LPSECURITY_ATTRIBUTES security, DWORD disposition, DWORD flags, HANDLE template_file,
    DWORD *error);
BD_FILES_API BOOL busydata_file_information(HANDLE file, LPBY_HANDLE_FILE_INFORMATION info, DWORD *error);
BD_FILES_API BOOL busydata_read_file(HANDLE file, void *buffer, DWORD size, DWORD *read,
    LPOVERLAPPED overlapped, DWORD *error);
BD_FILES_API BOOL busydata_write_file(HANDLE file, const void *buffer, DWORD size, DWORD *written,
    LPOVERLAPPED overlapped, DWORD *error);
BD_FILES_API BOOL busydata_flush_file(HANDLE file, DWORD *error);
BD_FILES_API BOOL busydata_move_file_w(LPCWSTR source, LPCWSTR destination, DWORD flags, DWORD *error);
BD_FILES_API DWORD busydata_final_path_w(HANDLE file, LPWSTR buffer, DWORD size, DWORD flags, DWORD *error);
#endif
