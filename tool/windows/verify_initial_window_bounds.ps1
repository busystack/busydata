# Run immediately after an ordinary product launch, before moving, resizing,
# minimizing or maximizing its window. This test only reads native geometry.
param(
 [Parameter(Mandatory)][int]$ApplicationPid,
 [Parameter(Mandatory)][string]$ExpectedExecutable,
 [Parameter(Mandatory)][string]$BuildEvidencePath,
 [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSourceSha256,
 [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$SourceRevision,
 [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference='Stop';$r=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');Status='Not run';Scope='Read-only actual native initial window bounds versus its monitor work area; no window movement or OS/VM settings changed';ApplicationPid=$ApplicationPid;SourceRevision=$SourceRevision;GuestSettingsChanged=$false}
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class BusyDataWindowBoundsProbe {
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo {public uint Size;public Rect Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr window,out Rect bounds);
 [DllImport("user32.dll")]public static extern IntPtr MonitorFromWindow(IntPtr window,uint flags);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern bool GetMonitorInfo(IntPtr monitor,ref MonitorInfo info);
 [DllImport("user32.dll")]public static extern uint GetDpiForWindow(IntPtr window);
 [DllImport("user32.dll")]public static extern bool IsZoomed(IntPtr window);
 [DllImport("user32.dll")]public static extern bool IsIconic(IntPtr window);
 [DllImport("user32.dll")]public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")]public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")]public static extern bool AreDpiAwarenessContextsEqual(IntPtr first,IntPtr second);
 [DllImport("kernel32.dll")]public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr window,out uint owner);
 [DllImport("dwmapi.dll")]public static extern int DwmGetWindowAttribute(IntPtr window,uint attribute,out Rect bounds,int size);
}
'@
$previous=[IntPtr]::Zero
try {
 $app=Get-Process -Id $ApplicationPid -ErrorAction Stop
 if($app.ProcessName -ne 'busydata' -or $app.Path -ne [IO.Path]::GetFullPath($ExpectedExecutable) -or $app.MainWindowHandle -eq [IntPtr]::Zero){throw 'Exact already-running ordinary Windows BusyData required'}
 $build=Get-Content -LiteralPath $BuildEvidencePath -Raw|ConvertFrom-Json
 if($build.exitCode -ne 0 -or $build.entrypoint -ne 'lib/main_windows.dart' -or $build.buildSourceSha256 -ne $ExpectedSourceSha256){throw 'Exact successful current-source ordinary Windows build proof required'}
 $proof=@($build.files|Where-Object path -eq 'busydata.exe');if($proof.Count -ne 1 -or (Get-FileHash $app.Path).Hash -ne $proof[0].sha256 -or (Get-Item $app.Path).Length -ne $proof[0].bytes){throw 'Actual runner executable differs from build receipt'}
 $r.BuildId=$build.buildId;$r.BuildSourceSha256=$build.buildSourceSha256
 $window=$app.MainWindowHandle;[uint32]$owner=0;$null=[BusyDataWindowBoundsProbe]::GetWindowThreadProcessId($window,[ref]$owner);if($owner -ne $app.Id){throw 'Native HWND owner differs'}
 $r.NativeThreadId=[BusyDataWindowBoundsProbe]::GetCurrentThreadId();$previous=[BusyDataWindowBoundsProbe]::SetThreadDpiAwarenessContext([IntPtr](-4));if($previous -eq [IntPtr]::Zero){throw 'Physical coordinate context unavailable'}
 $rect=[BusyDataWindowBoundsProbe+Rect]::new();if(-not[BusyDataWindowBoundsProbe]::GetWindowRect($window,[ref]$rect)){throw 'Native bounds query failed'}
 $monitor=[BusyDataWindowBoundsProbe]::MonitorFromWindow($window,2);$info=[BusyDataWindowBoundsProbe+MonitorInfo]::new();$info.Size=[Runtime.InteropServices.Marshal]::SizeOf($info);if(-not[BusyDataWindowBoundsProbe]::GetMonitorInfo($monitor,[ref]$info)){throw 'Native monitor query failed'}
 $visible=[BusyDataWindowBoundsProbe+Rect]::new();$hr=[BusyDataWindowBoundsProbe]::DwmGetWindowAttribute($window,9,[ref]$visible,16);if($hr -ne 0){throw 'Visible native frame query failed'}
 $r.Executable=$app.Path;$r.WindowHandle=$window.ToInt64();$r.NativeWindowRect=$rect;$r.VisibleFrame=$visible;$r.Monitor=$info.Monitor;$r.WorkArea=$info.Work;$r.Dpi=[BusyDataWindowBoundsProbe]::GetDpiForWindow($window);$r.Maximized=[BusyDataWindowBoundsProbe]::IsZoomed($window);$r.Minimized=[BusyDataWindowBoundsProbe]::IsIconic($window)
 $r.VisibleFrameWithinWorkArea=($visible.Left -ge $info.Work.Left -and $visible.Top -ge $info.Work.Top -and $visible.Right -le $info.Work.Right -and $visible.Bottom -le $info.Work.Bottom)
 $r.Status=if($r.VisibleFrameWithinWorkArea -and -not$r.Maximized -and -not$r.Minimized){'Passed'}else{'Failed'}
} catch {$r.Status='Failed';$r.Error=$_.Exception.Message}
finally {if($previous -ne [IntPtr]::Zero){$restored=[BusyDataWindowBoundsProbe]::SetThreadDpiAwarenessContext($previous);$r.NativeThreadIdAtRelease=[BusyDataWindowBoundsProbe]::GetCurrentThreadId();$r.CallingThreadDpiContextRestored=($restored -ne [IntPtr]::Zero -and $r.NativeThreadId -eq $r.NativeThreadIdAtRelease -and [BusyDataWindowBoundsProbe]::AreDpiAwarenessContextsEqual([BusyDataWindowBoundsProbe]::GetThreadDpiAwarenessContext(),$previous));if(-not$r.CallingThreadDpiContextRestored){$r.Status='Failed';$r.Error='Calling thread DPI coordinate context restoration was not verified'}};$r.FinishedUtc=[DateTime]::UtcNow.ToString('o');$r|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8}
if($r.Status -ne 'Passed'){exit 1}
