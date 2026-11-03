/* Private named-pipe relay for one unmodified official native client.
 * Uses documented IPC and process APIs only. SPDX-License-Identifier: Apache-2.0 */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <aclapi.h>
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/* Windows C runtime quoting, preserving each reviewed argument literally. */
static int append_argument(wchar_t *out,size_t *length,const wchar_t *argument) {
  if(*length+3>=32767)return 0;
  if(*length)out[(*length)++]=L' ';out[(*length)++]=L'"';
  size_t slashes=0;
  for(const wchar_t *at=argument;;at++){
    if(*at==L'\\'){slashes++;continue;}
    size_t emitted=(*at==L'"'||!*at)?slashes*2:slashes;
    if(*length+emitted+4>=32767)return 0;
    while(emitted--)out[(*length)++]=L'\\';slashes=0;
    if(!*at)break;if(*at==L'"')out[(*length)++]=L'\\';out[(*length)++]=*at;
  }
  out[(*length)++]=L'"';out[*length]=0;return 1;
}

struct relay { HANDLE pipe; SOCKET socket; volatile LONG failed; };
/* One event and OVERLAPPED per direction: a synchronous pipe handle serializes
 * ReadFile and WriteFile, which can deadlock a full-duplex client. */
static BOOL pipe_io(HANDLE pipe,OVERLAPPED *operation,BOOL writing,void *bytes,DWORD size,DWORD *count) {
  HANDLE event=operation->hEvent;ZeroMemory(operation,sizeof(*operation));operation->hEvent=event;
  if(!ResetEvent(event))return FALSE;
  BOOL complete=writing?WriteFile(pipe,bytes,size,count,operation):ReadFile(pipe,bytes,size,count,operation);
  if(!complete&&GetLastError()==ERROR_IO_PENDING)complete=GetOverlappedResult(pipe,operation,count,TRUE);
  return complete;
}
static DWORD WINAPI pipe_to_socket(void *value) {
  struct relay *relay=value;char bytes[65536];DWORD count;OVERLAPPED operation={0};
  operation.hEvent=CreateEventW(NULL,TRUE,FALSE,NULL);
  if(!operation.hEvent){InterlockedExchange(&relay->failed,1);goto done;}
  while(pipe_io(relay->pipe,&operation,FALSE,bytes,sizeof(bytes),&count)&&count) {
    DWORD at=0;while(at<count){int sent=send(relay->socket,bytes+at,(int)(count-at),0);if(sent<=0){InterlockedExchange(&relay->failed,1);goto done;}at+=(DWORD)sent;}
  }
done:
  if(operation.hEvent)CloseHandle(operation.hEvent);
  SecureZeroMemory(bytes,sizeof(bytes));shutdown(relay->socket,SD_SEND);return 0;
}
static DWORD WINAPI socket_to_pipe(void *value) {
  struct relay *relay=value;char bytes[65536];int count;OVERLAPPED operation={0};
  operation.hEvent=CreateEventW(NULL,TRUE,FALSE,NULL);
  if(!operation.hEvent){InterlockedExchange(&relay->failed,1);goto done;}
  while((count=recv(relay->socket,bytes,sizeof(bytes),0))>0) {
    DWORD at=0;while(at<(DWORD)count){DWORD written;if(!pipe_io(relay->pipe,&operation,TRUE,bytes+at,(DWORD)count-at,&written)||!written){InterlockedExchange(&relay->failed,1);goto done;}at+=written;}
  }
  if(count<0)InterlockedExchange(&relay->failed,1);
done:
  if(operation.hEvent)CloseHandle(operation.hEvent);
  SecureZeroMemory(bytes,sizeof(bytes));return 0;
}
static int hex(wchar_t ch){return ch>=L'0'&&ch<=L'9'?ch-L'0':ch>=L'a'&&ch<=L'f'?ch-L'a'+10:-1;}
int wmain(int argc,wchar_t **argv) {
  if(argc<2)return 2;
  wchar_t name[128],port_text[8],token_text[65];BYTE token[32];
  DWORD n=GetEnvironmentVariableW(L"BUSYDATA_NATIVE_PIPE",name,128);
  if(!n||n>=128||wcsncmp(name,L"BusyData.Native.",wcslen(L"BusyData.Native."))!=0)return 4;
  const size_t prefix=wcslen(L"BusyData.Native.");
  if(wcslen(name)!=prefix+32)return 4;
  for(size_t i=prefix;i<prefix+32;i++)if(hex(name[i])<0)return 4;
  n=GetEnvironmentVariableW(L"BUSYDATA_NATIVE_PORT",port_text,8);if(!n||n>=8)return 4;
  wchar_t *end=NULL;unsigned long port=wcstoul(port_text,&end,10);if(!end||*end||port<1||port>65535)return 4;
  n=GetEnvironmentVariableW(L"BUSYDATA_NATIVE_TOKEN",token_text,65);if(n!=64)return 4;
  for(size_t i=0;i<32;i++){int a=hex(token_text[i*2]),b=hex(token_text[i*2+1]);if(a<0||b<0)return 4;token[i]=(BYTE)((a<<4)|b);}
  SetEnvironmentVariableW(L"BUSYDATA_NATIVE_PIPE",NULL);SetEnvironmentVariableW(L"BUSYDATA_NATIVE_PORT",NULL);SetEnvironmentVariableW(L"BUSYDATA_NATIVE_TOKEN",NULL);SecureZeroMemory(token_text,sizeof(token_text));
  int code=9;HANDLE access_token=NULL,pipe=INVALID_HANDLE_VALUE,job=NULL,connected_event=NULL,threads[2]={NULL,NULL};
  OVERLAPPED connection_operation={0};int connection_pending=0;
  PACL acl=NULL;PTOKEN_USER user=NULL;PROCESS_INFORMATION process={0};HANDLE streams[3]={NULL,NULL,NULL};
  STARTUPINFOEXW startup={0};startup.StartupInfo.cb=sizeof(startup);SIZE_T attribute_bytes=0;int attributes_ready=0;
  struct relay relay={INVALID_HANDLE_VALUE,INVALID_SOCKET,0};WSADATA winsock;int socket_ready=0;
  if(!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&access_token))goto cleanup;
  DWORD bytes=0;GetTokenInformation(access_token,TokenUser,NULL,0,&bytes);if(!bytes)goto cleanup;
  user=malloc(bytes);if(!user||!GetTokenInformation(access_token,TokenUser,user,bytes,&bytes))goto cleanup;
  EXPLICIT_ACCESSW access={0};access.grfAccessPermissions=GENERIC_ALL;access.grfAccessMode=SET_ACCESS;access.grfInheritance=NO_INHERITANCE;
  access.Trustee.TrusteeForm=TRUSTEE_IS_SID;access.Trustee.TrusteeType=TRUSTEE_IS_USER;access.Trustee.ptstrName=(LPWSTR)user->User.Sid;
  if(SetEntriesInAclW(1,&access,NULL,&acl)!=ERROR_SUCCESS)goto cleanup;
  SECURITY_DESCRIPTOR descriptor;if(!InitializeSecurityDescriptor(&descriptor,SECURITY_DESCRIPTOR_REVISION)||!SetSecurityDescriptorDacl(&descriptor,TRUE,acl,FALSE))goto cleanup;
  SECURITY_ATTRIBUTES security={sizeof(security),&descriptor,FALSE};
  wchar_t full_name[160];if(swprintf_s(full_name,160,L"\\\\.\\pipe\\%s",name)<0)goto cleanup;
  pipe=CreateNamedPipeW(full_name,PIPE_ACCESS_DUPLEX|FILE_FLAG_OVERLAPPED|FILE_FLAG_FIRST_PIPE_INSTANCE,PIPE_TYPE_BYTE|PIPE_READMODE_BYTE|PIPE_WAIT|PIPE_REJECT_REMOTE_CLIENTS,1,65536,65536,30000,&security);
  if(pipe==INVALID_HANDLE_VALUE)goto cleanup;relay.pipe=pipe;
  job=CreateJobObjectW(NULL,NULL);if(!job)goto cleanup;
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits={0};limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if(!SetInformationJobObject(job,JobObjectExtendedLimitInformation,&limits,sizeof(limits)))goto cleanup;
  wchar_t *command=calloc(32768,sizeof(wchar_t));if(!command)goto cleanup;size_t length=0;
  for(int i=1;i<argc;i++)if(!append_argument(command,&length,argv[i])){free(command);goto cleanup;}
  DWORD standard_ids[3]={STD_INPUT_HANDLE,STD_OUTPUT_HANDLE,STD_ERROR_HANDLE};
  for(size_t i=0;i<3;i++){
    HANDLE original=GetStdHandle(standard_ids[i]);
    if(!original||original==INVALID_HANDLE_VALUE||!DuplicateHandle(GetCurrentProcess(),original,GetCurrentProcess(),&streams[i],0,TRUE,DUPLICATE_SAME_ACCESS)){free(command);goto cleanup;}
  }
  startup.StartupInfo.dwFlags=STARTF_USESTDHANDLES;startup.StartupInfo.hStdInput=streams[0];startup.StartupInfo.hStdOutput=streams[1];startup.StartupInfo.hStdError=streams[2];
  InitializeProcThreadAttributeList(NULL,1,0,&attribute_bytes);if(!attribute_bytes){free(command);goto cleanup;}startup.lpAttributeList=malloc(attribute_bytes);
  if(!startup.lpAttributeList||!InitializeProcThreadAttributeList(startup.lpAttributeList,1,0,&attribute_bytes)){free(command);goto cleanup;}attributes_ready=1;
  if(!UpdateProcThreadAttribute(startup.lpAttributeList,0,PROC_THREAD_ATTRIBUTE_HANDLE_LIST,streams,sizeof(streams),NULL,NULL)){free(command);goto cleanup;}
  if(!CreateProcessW(argv[1],command,NULL,NULL,TRUE,CREATE_SUSPENDED|CREATE_NO_WINDOW|EXTENDED_STARTUPINFO_PRESENT,NULL,NULL,&startup.StartupInfo,&process)){free(command);goto cleanup;}free(command);
  if(!AssignProcessToJobObject(job,process.hProcess)){TerminateProcess(process.hProcess,9);goto cleanup;}
  connected_event=CreateEventW(NULL,TRUE,FALSE,NULL);if(!connected_event)goto cleanup;
  connection_operation.hEvent=connected_event;
  BOOL connected=ConnectNamedPipe(pipe,&connection_operation);DWORD connection_error=connected?ERROR_SUCCESS:GetLastError();
  if(!connected&&connection_error!=ERROR_IO_PENDING&&connection_error!=ERROR_PIPE_CONNECTED)goto cleanup;
  if(!connected&&connection_error==ERROR_IO_PENDING)connection_pending=1;else SetEvent(connected_event);
  if(ResumeThread(process.hThread)==(DWORD)-1)goto cleanup;
  HANDLE waiting[2]={process.hProcess,connected_event};DWORD ready=WaitForMultipleObjects(2,waiting,FALSE,30000);
  if(ready==WAIT_OBJECT_0){DWORD status;if(GetExitCodeProcess(process.hProcess,&status))code=(int)status;goto cleanup;}
  if(ready!=WAIT_OBJECT_0+1)goto cleanup;
  if(connection_pending){DWORD transferred;if(!GetOverlappedResult(pipe,&connection_operation,&transferred,FALSE))goto cleanup;connection_pending=0;}
  ULONG client_pid;if(!GetNamedPipeClientProcessId(pipe,&client_pid)||client_pid!=process.dwProcessId)goto cleanup;
  if(WSAStartup(MAKEWORD(2,2),&winsock))goto cleanup;socket_ready=1;
  relay.socket=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);if(relay.socket==INVALID_SOCKET)goto cleanup;
  struct sockaddr_in address={0};address.sin_family=AF_INET;address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);address.sin_port=htons((u_short)port);
  if(connect(relay.socket,(struct sockaddr *)&address,sizeof(address)))goto cleanup;
  int at=0;while(at<32){int sent=send(relay.socket,(const char *)token+at,32-at,0);if(sent<=0)goto cleanup;at+=sent;}SecureZeroMemory(token,sizeof(token));
  threads[0]=CreateThread(NULL,0,pipe_to_socket,&relay,0,NULL);threads[1]=CreateThread(NULL,0,socket_to_pipe,&relay,0,NULL);
  if(!threads[0]||!threads[1])goto cleanup;
  HANDLE completion[3]={process.hProcess,threads[0],threads[1]};
  DWORD ended=WaitForMultipleObjects(3,completion,FALSE,INFINITE);
  if(ended!=WAIT_OBJECT_0) {
    if(pipe!=INVALID_HANDLE_VALUE)DisconnectNamedPipe(pipe);
    if(WaitForSingleObject(process.hProcess,30000)!=WAIT_OBJECT_0)goto cleanup;
  }
  DWORD status;if(GetExitCodeProcess(process.hProcess,&status))code=(int)status;
  if(code==0&&InterlockedCompareExchange(&relay.failed,0,0))code=9;
cleanup:
  SecureZeroMemory(token,sizeof(token));
  if(job)CloseHandle(job);if(process.hProcess)WaitForSingleObject(process.hProcess,5000);
  if(pipe!=INVALID_HANDLE_VALUE)CancelIoEx(pipe,NULL);
  if(connection_pending){
    if(WaitForSingleObject(connected_event,5000)!=WAIT_OBJECT_0)ExitProcess(9);
    DWORD transferred;GetOverlappedResult(pipe,&connection_operation,&transferred,FALSE);
  }
  if(connected_event)CloseHandle(connected_event);
  if(relay.socket!=INVALID_SOCKET)shutdown(relay.socket,SD_BOTH);
  for(size_t i=0;i<2;i++)if(threads[i])CancelSynchronousIo(threads[i]);
  if(pipe!=INVALID_HANDLE_VALUE)DisconnectNamedPipe(pipe);
  for(size_t i=0;i<2;i++)if(threads[i]){if(WaitForSingleObject(threads[i],5000)!=WAIT_OBJECT_0)ExitProcess(9);CloseHandle(threads[i]);}
  if(relay.socket!=INVALID_SOCKET)closesocket(relay.socket);if(socket_ready)WSACleanup();
  if(pipe!=INVALID_HANDLE_VALUE)CloseHandle(pipe);
  if(startup.lpAttributeList){if(attributes_ready)DeleteProcThreadAttributeList(startup.lpAttributeList);free(startup.lpAttributeList);}
  for(size_t i=0;i<3;i++)if(streams[i])CloseHandle(streams[i]);
  if(process.hThread)CloseHandle(process.hThread);if(process.hProcess)CloseHandle(process.hProcess);
  if(acl)LocalFree(acl);free(user);if(access_token)CloseHandle(access_token);return code;
}
