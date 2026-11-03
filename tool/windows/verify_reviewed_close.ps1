# Run with the Windows-provided powershell.exe5.1 Accessibility assembly.
# This is actual UI acceptance, requiring one already-running verified BusyData
# window with the specified number of dirty SQL fixture documents and no pending
# database work. It never launches, force-stops, or retries application actions.
param(
 [Parameter(Mandatory)][int]$ApplicationPid,
 [Parameter(Mandatory)][string]$ExpectedExecutable,
 [Parameter(Mandatory)][string]$BuildEvidencePath,
 [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSourceSha256,
 [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$SourceRevision,
 [Parameter(Mandatory)][ValidateRange(1,32)][int]$ExpectedUnsavedDocuments,
 [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'Use the Windows-provided powershell.exe5.1 for the framework Accessibility assembly; no SDK or package change is needed'}
$r=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');Status='Not run';SourceRevision=$SourceRevision;Scope='Actual native reviewed close: one native request, exactly one approval preserving SQL drafts, normal application and owned backend exit0';ForcedTermination=$false;ActionReplayed=$false;PasswordValuesRead=$false;PowerPlanChanged=$false;VirtualMachineChanged=$false}
$nativeReady=$false;$previousExecution=[uint32]0
try {
 if(-not [Environment]::Is64BitProcess -or [Environment]::OSVersion.Version.Build -lt 26100){throw 'Native x64 Windows11 24H2 or newer is required'}
 $build=Get-Content -LiteralPath $BuildEvidencePath -Raw|ConvertFrom-Json
 if($build.exitCode -ne 0 -or $build.entrypoint -ne 'lib/main_windows.dart' -or $build.buildSourceSha256 -ne $ExpectedSourceSha256){throw 'Exact successful ordinary Windows build evidence required'}
 $r.BuildId=$build.buildId;$r.BuildSourceSha256=$build.buildSourceSha256
 $exe=[IO.Path]::GetFullPath($ExpectedExecutable);$base=Split-Path $exe
 foreach($relative in @('busydata.exe','data/app.so','flutter_windows.dll','backend/native/busydata_windows_files.dll','backend/runtime/bin/java.exe','backend/lib/busydata-backend-0.1.0.jar')) {
  $proof=@($build.files|Where-Object path -eq $relative);$path=Join-Path $base $relative
  if($proof.Count -ne 1 -or -not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $proof[0].bytes -or (Get-FileHash -LiteralPath $path).Hash -ne $proof[0].sha256){throw 'Reviewed-close code/runtime identity differs from the exact build receipt'}
 }
 $app=Get-Process -Id $ApplicationPid -ErrorAction Stop;$null=$app.Handle
 if($app.ProcessName -ne 'busydata' -or $app.Path -ne $exe -or $app.MainWindowHandle -eq [IntPtr]::Zero){throw 'Exact already-running ordinary BusyData process required'}
 $r.ApplicationPid=$app.Id;$r.Executable=$exe;$r.WindowHandle=$app.MainWindowHandle.ToInt64()
 $children=@(Get-CimInstance Win32_Process -Filter ("ParentProcessId="+$app.Id)|Where-Object Name -eq 'java.exe')
 if($children.Count -ne 1 -or $children[0].ExecutablePath -ne (Join-Path $base 'backend/runtime/bin/java.exe')){throw 'One exact owned bundled backend must be alive before close'}
 $backend=Get-Process -Id $children[0].ProcessId;$null=$backend.Handle;$r.BackendPid=$backend.Id
Add-Type -AssemblyName Accessibility
$reference=[Accessibility.IAccessible].Assembly.Location
Add-Type -ReferencedAssemblies $reference -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Accessibility;
public static class BusyDataReviewedCloseNative {
 public delegate bool WindowCallback(IntPtr window,IntPtr context);
 [DllImport("user32.dll")]static extern bool EnumChildWindows(IntPtr parent,WindowCallback callback,IntPtr context);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr window,StringBuilder name,int count);
 [DllImport("oleacc.dll")]static extern int AccessibleObjectFromWindow(IntPtr window,uint id,ref Guid iid,[MarshalAs(UnmanagedType.Interface)]out IAccessible accessible);
 [DllImport("oleacc.dll")]static extern int AccessibleChildren(IAccessible accessible,int start,int count,[Out,MarshalAs(UnmanagedType.LPArray,ArraySubType=UnmanagedType.Struct,SizeParamIndex=2)]object[] children,out int obtained);
 [DllImport("oleacc.dll")]static extern int WindowFromAccessibleObject(IAccessible accessible,out IntPtr window);
 [DllImport("oleacc.dll",CharSet=CharSet.Unicode)]static extern uint GetRoleText(uint role,StringBuilder text,uint length);
 public class Node {public string Path;public string Parent;public string Name;public string Description;public string Role;public int RoleId;public uint State;public string DefaultAction;public bool IsPassword;public bool HasKeyboardFocus;public bool IsUnavailable;public bool IsOffscreen;public long WindowHandle;public int X;public int Y;public int Width;public int Height;public int ChildCount;}
 class Pending {public IAccessible Accessible;public object Child;public string Path;public string Parent;public int Depth;}
 public static IntPtr FlutterChild(IntPtr parent,uint process) {
  uint owner;GetWindowThreadProcessId(parent,out owner);if(owner!=process)throw new InvalidOperationException("BusyData parent owner differs");
  var matches=new List<IntPtr>();WindowCallback callback=delegate(IntPtr window,IntPtr ignored){uint pid;GetWindowThreadProcessId(window,out pid);var name=new StringBuilder(128);GetClassName(window,name,name.Capacity);if(pid==process&&name.ToString()=="FLUTTERVIEW")matches.Add(window);return true;};
  EnumChildWindows(parent,callback,IntPtr.Zero);GC.KeepAlive(callback);
  if(matches.Count!=1)throw new InvalidOperationException("One owned native FLUTTERVIEW expected");return matches[0];
 }
 static string Bound(string text) {if(text==null)return "";return text.Length<=1024?text:text.Substring(0,1024)+" [bounded]";}
 [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
 public static bool LastDispatchAttempted {get;private set;}
 public static string RequiredAncestor;
 public static bool UseMouse;
 [DllImport("kernel32.dll")]public static extern uint SetThreadExecutionState(uint state);
 [DllImport("kernel32.dll")]public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")]static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);

 [StructLayout(LayoutKind.Sequential)]struct Point {public int X;public int Y;}
 [StructLayout(LayoutKind.Sequential)]struct MouseInput {public int X;public int Y;public uint Data;public uint Flags;public uint Time;public UIntPtr Extra;}
 [StructLayout(LayoutKind.Sequential)]struct KeyboardInput {public ushort Key;public ushort Scan;public uint Flags;public uint Time;public UIntPtr Extra;}
 [StructLayout(LayoutKind.Explicit)]struct InputUnion {[FieldOffset(0)]public MouseInput Mouse;[FieldOffset(0)]public KeyboardInput Keyboard;}
 [StructLayout(LayoutKind.Sequential)]struct NativeInput {public uint Type;public InputUnion Data;}
 [DllImport("user32.dll")]static extern int GetSystemMetrics(int index);
 [DllImport("user32.dll")]static extern uint GetDpiForWindow(IntPtr window);
 [DllImport("user32.dll")]static extern IntPtr WindowFromPoint(Point point);
 [DllImport("user32.dll",SetLastError=true)]static extern uint SendInput(uint count,NativeInput[] events,int size);
 static void ClickOwned(IAccessible accessible,object child,uint process,IntPtr window) {
  var previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
  if(previous==IntPtr.Zero)throw new InvalidOperationException("Native physical coordinate context unavailable; no click sent");
  try {
   int x,y,w,h;accessible.accLocation(out x,out y,out w,out h,child);
   int sx=GetSystemMetrics(76),sy=GetSystemMetrics(77),sw=GetSystemMetrics(78),sh=GetSystemMetrics(79);
   if(w<=0||h<=0||sw<=1||sh<=1||x<sx||y<sy||x+w>sx+sw||y+h>sy+sh)throw new InvalidOperationException("Fresh reviewed button must be fully visible; no click sent");
   Point point=new Point{X=x+w/2,Y=y+h/2};uint owner;GetWindowThreadProcessId(WindowFromPoint(point),out owner);
   if(owner!=process)throw new InvalidOperationException("Actual physical target is not owned by the selected BusyData process");
   int ax=(int)Math.Round((point.X-sx)*65535.0/(sw-1)),ay=(int)Math.Round((point.Y-sy)*65535.0/(sh-1));
   var events=new[]{new NativeInput{Type=0,Data=new InputUnion{Mouse=new MouseInput{X=ax,Y=ay,Flags=0xc001}}},new NativeInput{Type=0,Data=new InputUnion{Mouse=new MouseInput{Flags=2}}},new NativeInput{Type=0,Data=new InputUnion{Mouse=new MouseInput{Flags=4}}}};
   int size=Marshal.SizeOf(typeof(NativeInput));if(size!=40||IntPtr.Size!=8)throw new InvalidOperationException("Native Windows x64 input layout differs");
   if(SendInput(3,events,size)!=3)throw new InvalidOperationException("Incomplete one physical approval; do not replay");
  }finally{SetThreadDpiAwarenessContext(previous);}
 }
 public static List<Node> Snapshot(IntPtr window,uint process) {return SnapshotCore(window,process,null,0);}
 public static List<Node> InvokeDefault(IntPtr window,uint process,string caption,int role) {LastDispatchAttempted=false;return SnapshotCore(window,process,caption,role);}
 static List<Node> SnapshotCore(IntPtr window,uint process,string caption,int matchRole) {
  uint owner;GetWindowThreadProcessId(window,out owner);if(owner!=process)throw new InvalidOperationException("BusyData Flutter window owner differs");
  Guid iid=new Guid("618736E0-3C3D-11CF-810C-00AA00389B71");IAccessible root;int hr=AccessibleObjectFromWindow(window,0xFFFFFFFC,ref iid,out root);if(hr<0)Marshal.ThrowExceptionForHR(hr);
  var owned=new HashSet<IAccessible>();var result=new List<Node>();var matches=new List<Pending>();var queue=new Queue<Pending>();owned.Add(root);queue.Enqueue(new Pending{Accessible=root,Child=0,Path="0",Depth=0});
  try {
   while(queue.Count>0) {
    if(result.Count>=5000)throw new InvalidOperationException("Owned MSAA node budget exceeded");var p=queue.Dequeue();if(p.Depth>64)throw new InvalidOperationException("Owned MSAA depth budget exceeded");
    int role=Convert.ToInt32(p.Accessible.get_accRole(p.Child));uint state=Convert.ToUInt32(p.Accessible.get_accState(p.Child));
    var label=new StringBuilder(256);GetRoleText((uint)role,label,(uint)label.Capacity);
    IntPtr native;int windowResult=WindowFromAccessibleObject(p.Accessible,out native);
    if(windowResult>=0&&native!=IntPtr.Zero){GetWindowThreadProcessId(native,out owner);if(owner!=process)throw new InvalidOperationException("MSAA object belongs to another process");}
    int left,top,width,height;p.Accessible.accLocation(out left,out top,out width,out height,p.Child);
    bool simple=Convert.ToInt32(p.Child)!=0;int count=simple?0:p.Accessible.accChildCount;
    if(count<0||count>5000||result.Count+queue.Count+count>5000)throw new InvalidOperationException("Owned MSAA child budget exceeded");
    result.Add(new Node{Path=p.Path,Parent=p.Parent,Name=Bound(p.Accessible.get_accName(p.Child)),Description=Bound(p.Accessible.get_accDescription(p.Child)),Role=label.ToString(),RoleId=role,State=state,DefaultAction=Bound(p.Accessible.get_accDefaultAction(p.Child)),IsPassword=(state&0x20000000)!=0,HasKeyboardFocus=(state&4)!=0,IsUnavailable=(state&1)!=0,IsOffscreen=(state&0x10000)!=0,WindowHandle=native.ToInt64(),X=left,Y=top,Width=width,Height=height,ChildCount=count});
    if(caption!=null&&role==matchRole&&String.Equals(p.Accessible.get_accName(p.Child),caption,StringComparison.Ordinal))matches.Add(p);
    if(count==0)continue;var children=new object[count];int obtained;hr=AccessibleChildren(p.Accessible,0,count,children,out obtained);if(hr<0)Marshal.ThrowExceptionForHR(hr);if(obtained!=count)throw new InvalidOperationException("Native accessibility children changed; reacquire a fresh observation");
    for(int i=0;i<obtained;i++){
     var accessible=children[i] as IAccessible;
     if(accessible!=null){owned.Add(accessible);queue.Enqueue(new Pending{Accessible=accessible,Child=0,Path=p.Path+"/"+i,Parent=p.Path,Depth=p.Depth+1});}
     else if(children[i] is int){queue.Enqueue(new Pending{Accessible=p.Accessible,Child=children[i],Path=p.Path+"/"+i,Parent=p.Path,Depth=p.Depth+1});}
     else throw new InvalidOperationException("Unsupported native MSAA child kind");
    }
   }
   if(caption!=null) {
    if(!String.IsNullOrEmpty(RequiredAncestor)) {
     var byPath=new Dictionary<string,Node>();foreach(var node in result)byPath.Add(node.Path,node);
     matches.RemoveAll(delegate(Pending pending){string path=pending.Parent;for(int i=0;i<65&&path!=null;i++){Node ancestor;if(!byPath.TryGetValue(path,out ancestor))throw new InvalidOperationException("Incomplete native ancestor observation");if(ancestor.Name==RequiredAncestor)return false;path=ancestor.Parent;}return true;});
    }
    if(matches.Count!=1)throw new InvalidOperationException("One exact fresh native caption/role required; no action sent");
    var chosen=matches[0];uint state=Convert.ToUInt32(chosen.Accessible.get_accState(chosen.Child));
    if((state&0x10001)!=0||Convert.ToInt32(chosen.Accessible.get_accRole(chosen.Child))!=matchRole||!String.Equals(chosen.Accessible.get_accName(chosen.Child),caption,StringComparison.Ordinal))throw new InvalidOperationException("Native target changed or became unavailable/offscreen; no action sent");
    uint foreground;GetWindowThreadProcessId(GetForegroundWindow(),out foreground);if(foreground!=process)throw new InvalidOperationException("BusyData does not own foreground input; no action sent");
    LastDispatchAttempted=true;if(UseMouse)ClickOwned(chosen.Accessible,chosen.Child,process,window);else chosen.Accessible.accDoDefaultAction(chosen.Child);
   }
   return result;
  } finally {foreach(var accessible in owned)if(Marshal.IsComObject(accessible))Marshal.FinalReleaseComObject(accessible);}
 }
}
'@

 $nativeReady=$true;$r.ExecutionThreadId=[BusyDataReviewedCloseNative]::GetCurrentThreadId()
 $previousExecution=[BusyDataReviewedCloseNative]::SetThreadExecutionState([uint32]2147483651)
 if($previousExecution -eq 0){throw 'Temporary display-availability request unavailable; no close action sent'}
 $r.TemporaryDisplayRequest=$true
 $child=[BusyDataReviewedCloseNative]::FlutterChild($app.MainWindowHandle,[uint32]$app.Id)
 $before=[BusyDataReviewedCloseNative]::Snapshot($child,[uint32]$app.Id)
 if(@($before|Where-Object Name -eq 'Close BusyData').Count -ne 0){throw 'A close review is already open; no close request or approval replayed'}
 $r.CloseRequests=1;$r.CloseRequested=[bool]$app.CloseMainWindow()
 if(-not $r.CloseRequested){throw 'Native close request was not accepted'}
 $watch=[Diagnostics.Stopwatch]::StartNew();$review=$null
 while($watch.ElapsedMilliseconds -lt 5000) {
  if($app.HasExited){throw 'Application exited without the required dirty-document review'}
  try{$review=[BusyDataReviewedCloseNative]::Snapshot($child,[uint32]$app.Id)}
  catch{if($_.Exception.InnerException.HResult -ne -2147467259){throw};Start-Sleep -Milliseconds 100;continue}
  if(@($review|Where-Object Name -eq 'Close BusyData').Count -ge 1){break}
  Start-Sleep -Milliseconds 100
 }
 if(@($review|Where-Object Name -eq 'Close BusyData').Count -eq 0){throw 'Authored native close review was not observed'}
 $text=$review.Name -join "`n"
 foreach($required in @("Unsaved documents: $ExpectedUnsavedDocuments",'Acknowledgements/connections: 0','Saves in progress: 0','Staged edits: 0','Active jobs: 0','Transactions requiring cleanup: 0','Unknown operation outcomes: 0','Uncertain sessions: 0','SQL drafts will be saved locally.')){if(-not $text.Contains($required)){throw 'Current close review differs from the safe read-only fixture; no approval sent'}}
 $r.Review=$review|Where-Object {$_.Name -eq 'Close BusyData' -or $_.Name -eq 'Save drafts and close' -or $_.Name -eq 'Stay' -or $_.Name.Contains('Unsaved documents:')}
 $r.ReviewedUnsavedDocuments=$ExpectedUnsavedDocuments
 [BusyDataReviewedCloseNative]::UseMouse=$true;$r.ApprovalDispatches=1
 $null=[BusyDataReviewedCloseNative]::InvokeDefault($child,[uint32]$app.Id,'Save drafts and close',43)
 if(-not $app.WaitForExit(20000)) {
  if($backend.HasExited){$r.BackendExitCode=$backend.ExitCode}
  try{$r.RemainingReview=[BusyDataReviewedCloseNative]::Snapshot($child,[uint32]$app.Id)|Where-Object {$_.Name -eq 'Close BusyData' -or $_.Name -eq 'Save drafts and close' -or $_.Name.Contains('Unsaved documents:')}}catch{$r.RemainingReviewReadFailure=$_.Exception.GetType().FullName}
  throw 'Application remained open after one reviewed approval; no second approval or forced termination performed'
 }
 $r.ApplicationExitCode=$app.ExitCode
 if(-not $backend.WaitForExit(15000)){throw 'Owned backend remained after native close; no forced termination performed'}
 $r.BackendExitCode=$backend.ExitCode
 if($r.ApplicationExitCode -ne 0 -or $r.BackendExitCode -ne 0){throw 'Native application/backend shutdown did not exit0'}
 $r.Status='Passed'
} catch {$r.Status='Failed';$r.Error=$_.Exception.Message}
finally {
 if($nativeReady -and $previousExecution -ne 0) {
  $r.ExecutionThreadIdAtRelease=[BusyDataReviewedCloseNative]::GetCurrentThreadId()
  $restored=[BusyDataReviewedCloseNative]::SetThreadExecutionState([uint32]($previousExecution -bor [uint32]2147483648))
  $r.TemporaryDisplayRequestReleased=($restored -ne 0 -and $r.ExecutionThreadIdAtRelease -eq $r.ExecutionThreadId)
  if(-not $r.TemporaryDisplayRequestReleased){$r.Status='Failed';$r.Error='Native display request release was not verified; task process exit releases its thread request'}
 }
 $r.FinishedUtc=[DateTime]::UtcNow.ToString('o')
 $r|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($r.Status -ne 'Passed'){exit 1}
