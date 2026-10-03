#ifndef RepoRoot
  #define RepoRoot AddBackslash(SourcePath) + "..\.."
#endif
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#ifndef MinRuntimeMajor
  #error Build this installer using build-installer.ps1 to include the verified Microsoft runtime.
#endif

[Setup]
AppId={{CFC97191-614B-4D8A-8266-C9E86F905954}
AppName=Focusly
AppVersion={#AppVersion}
AppPublisher=Focusly
DefaultDirName={localappdata}\Programs\Focusly
DefaultGroupName={param:GROUP|Focusly}
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#RepoRoot}\dist
OutputBaseFilename=Focusly-Setup-{#AppVersion}-x64
SetupIconFile={#RepoRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\focusly.exe
UninstallDisplayName=Focusly
WizardStyle=modern
Compression=lzma2/normal
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
ShowLanguageDialog=yes
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#RepoRoot}\desktop\out\Focusly-win32-x64\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RepoRoot}\.dart_tool\installer-deps\vc_redist.x64.exe"; Flags: dontcopy

[Registry]
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\Focusly.Focusly"; ValueType: string; ValueName: "DisplayName"; ValueData: "Focusly"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\Focusly.Focusly"; ValueType: string; ValueName: "IconUri"; ValueData: "{app}\resources\app\web\favicon.png"
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\Focusly.Focusly"; ValueType: dword; ValueName: "ShowInSettings"; ValueData: "1"
Root: HKCU; Subkey: "Software\Classes\focusly"; ValueType: string; ValueName: ""; ValueData: "URL:Focusly"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\focusly"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\focusly\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\focusly.exe"" ""%1"""

[Icons]
Name: "{group}\Focusly"; Filename: "{app}\focusly.exe"; WorkingDir: "{app}"; AppUserModelID: "Focusly.Focusly"
Name: "{autodesktop}\Focusly"; Filename: "{app}\focusly.exe"; WorkingDir: "{app}"; AppUserModelID: "Focusly.Focusly"; Tasks: desktopicon

[Run]
Filename: "{app}\focusly.exe"; Description: "{cm:LaunchProgram,Focusly}"; Flags: nowait postinstall skipifsilent

[CustomMessages]
english.VCRuntimeError=Microsoft Visual C++ Runtime could not be installed. Allow its installation and try again.
arabic.VCRuntimeError=تعذر تثبيت مكونات Microsoft Visual C++ اللازمة لتشغيل البرنامج. اسمح بتثبيتها ثم أعد المحاولة.

[Code]
function HasRequiredVCRuntime: Boolean;
var
  Installed, VersionMS, VersionLS: Cardinal;
  Major, Minor, Build, Patch: Cardinal;
begin
  Result := False;
  if not RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
    Exit;
  if Installed <> 1 then
    Exit;
  if not GetVersionNumbers(ExpandConstant('{sys}\msvcp140.dll'), VersionMS, VersionLS) then
    Exit;
  Major := VersionMS shr 16;
  Minor := VersionMS and $FFFF;
  Build := VersionLS shr 16;
  Patch := VersionLS and $FFFF;
  Result := (Major > {#MinRuntimeMajor}) or
    ((Major = {#MinRuntimeMajor}) and (Minor > {#MinRuntimeMinor})) or
    ((Major = {#MinRuntimeMajor}) and (Minor = {#MinRuntimeMinor}) and (Build > {#MinRuntimeBuild})) or
    ((Major = {#MinRuntimeMajor}) and (Minor = {#MinRuntimeMinor}) and (Build = {#MinRuntimeBuild}) and (Patch >= {#MinRuntimePatch}));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  if HasRequiredVCRuntime then
    Exit;

  ExtractTemporaryFile('vc_redist.x64.exe');
  if not ShellExec('runas', ExpandConstant('{tmp}\vc_redist.x64.exe'),
      '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := CustomMessage('VCRuntimeError')
  else if (ResultCode <> 0) and (ResultCode <> 3010) and (ResultCode <> 1638) then
    Result := CustomMessage('VCRuntimeError')
  else if not HasRequiredVCRuntime then
    Result := CustomMessage('VCRuntimeError')
  else if ResultCode = 3010 then
    NeedsRestart := True;
end;
