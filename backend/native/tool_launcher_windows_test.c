/* Owned process fixture; no networking, injected modules or upstream code.
 * SPDX-License-Identifier: Apache-2.0 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
int wmain(int argc,wchar_t **argv) {
  if(GetConsoleWindow()!=NULL)return 11;
  if(argc>1&&wcscmp(argv[1],L"--child-failure")==0)return 61;
  if(argc==3&&wcscmp(argv[1],L"--try-inherited-event")==0){SetEvent((HANDLE)(uintptr_t)wcstoull(argv[2],NULL,10));return 0;}
  if(argc>1&&wcscmp(argv[1],L"--child-hold")==0){printf("%lu\n",GetCurrentProcessId());fflush(stdout);Sleep(60000);return 0;}
  if(argc>1&&wcscmp(argv[1],L"--stdio")==0){
    HANDLE input=GetStdHandle(STD_INPUT_HANDLE),output=GetStdHandle(STD_OUTPUT_HANDLE);char buffer[4096];DWORD count;
    while(ReadFile(input,buffer,sizeof(buffer),&count,NULL)&&count){DWORD at=0;while(at<count){DWORD written;if(!WriteFile(output,buffer+at,count-at,&written,NULL)||!written)return 12;at+=written;}}
    const char marker[]="owned stderr\n";DWORD written;
    if(!WriteFile(GetStdHandle(STD_ERROR_HANDLE),marker,sizeof(marker)-1,&written,NULL)||written!=sizeof(marker)-1)return 12;
    return 0;
  }
  if(argc!=3||wcscmp(argv[1],L"--assert-child")!=0||wcscmp(argv[2],L"Unicode 漢 path with \"quote\" and trailing slash\\")!=0)return 7;
  puts("Selected native arguments preserved without process modification");return 0;
}
