/* Exercise the public pipe client API, exact bytes and unmodified resolution.
 * SPDX-License-Identifier: Apache-2.0 */
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
int wmain(int argc,wchar_t **argv) {
  if(argc<3)return 2;
  if(wcscmp(argv[2],L"--child-failure")==0)return 61;
  if(argc!=4||wcscmp(argv[3],L"Unicode 漢 path with \"quote\" and trailing slash\\")!=0)return 7;
  wchar_t secret[2];
  if(GetEnvironmentVariableW(L"BUSYDATA_NATIVE_TOKEN",secret,2)||GetEnvironmentVariableW(L"BUSYDATA_NATIVE_PORT",secret,2)||GetEnvironmentVariableW(L"BUSYDATA_NATIVE_PIPE",secret,2))return 8;
  BOOL owned=FALSE;if(!IsProcessInJob(GetCurrentProcess(),NULL,&owned)||!owned)return 9;
  wchar_t name[256];if(swprintf_s(name,256,L"\\\\.\\pipe\\%s",argv[1])<0)return 3;
  if(!WaitNamedPipeW(name,10000))return 4;
  HANDLE pipe=CreateFileW(name,GENERIC_READ|GENERIC_WRITE,0,NULL,OPEN_EXISTING,0,NULL);if(pipe==INVALID_HANDLE_VALUE)return 5;
  if(wcscmp(argv[2],L"--child-hold")==0){printf("%lu\n",GetCurrentProcessId());fflush(stdout);Sleep(60000);return 0;}
  if(wcscmp(argv[2],L"--child-wait-read")==0){
    printf("%lu\n",GetCurrentProcessId());fflush(stdout);
    unsigned char byte=3;DWORD count;
    if(!WriteFile(pipe,&byte,1,&count,NULL)||count!=1)return 24;
    BOOL read=ReadFile(pipe,&byte,1,&count,NULL);DWORD error=read?ERROR_SUCCESS:GetLastError();
    CloseHandle(pipe);
    return (read&&count==0)||(!read&&(error==ERROR_BROKEN_PIPE||error==ERROR_PIPE_NOT_CONNECTED||error==ERROR_NO_DATA))?23:24;
  }
  unsigned char sent[8192],received[8192];for(size_t i=0;i<sizeof(sent);i++)sent[i]=(unsigned char)i;
  for(int round=0;round<128;round++) {
    DWORD count;if(!WriteFile(pipe,sent,sizeof(sent),&count,NULL)||count!=sizeof(sent))return 10;
    DWORD at=0;while(at<sizeof(received)){if(!ReadFile(pipe,received+at,(DWORD)sizeof(received)-at,&count,NULL)||!count)return 11;at+=count;}
    if(memcmp(sent,received,sizeof(sent)))return 12;
  }
  CloseHandle(pipe);
  WSADATA data;if(WSAStartup(MAKEWORD(2,2),&data))return 13;
  struct addrinfo *result=NULL,hints={0};hints.ai_family=AF_INET;hints.ai_socktype=SOCK_STREAM;
  if(getaddrinfo("192.0.2.3","54321",&hints,&result))return 14;
  struct sockaddr_in *address=(struct sockaddr_in *)result->ai_addr;
  if(ntohl(address->sin_addr.s_addr)!=0xc0000203||ntohs(address->sin_port)!=54321)return 15;freeaddrinfo(result);
  if(getaddrinfo("reviewed.invalid","54321",&hints,&result)==0){freeaddrinfo(result);return 16;}
  WSACleanup();puts("Private pipe bytes, literal Unicode arguments, owned job and unchanged Winsock passed");return 0;
}
