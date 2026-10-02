; =====================================================================
; Focusly Windows Installer Setup Script (Inno Setup 6+)
; =====================================================================
; Pre-requisite: Run `flutter build windows --release` before compiling
; this installer script with Inno Setup Compiler (ISCC).
; =====================================================================

#define MyAppName "Focusly"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Focusly"
#define MyAppURL "https://focusly.app"
#define MyAppExeName "focusly.exe"
#define MyAppIcon "..\runner\resources\app_icon.ico"
#define MyBuildSource "..\..\build\windows\x64\runner\Release"

[Setup]
; Unique GUID for Focusly - DO NOT change across updates to ensure seamless upgrades
AppId={{A3641FD4-B8C7-4E00-B935-D57A4B43C00E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes

; Privileges & Permission handling
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no

; Output configuration
OutputDir=..\..\build\windows\installer
OutputBaseFilename=Focusly_Setup_v{#MyAppVersion}
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Compression & Modern Visual Styling
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Windows File Metadata & Version Stamp
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Focusly - Smart Productivity & Habit Tracker
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Flutter Windows Executable
Source: "{#MyBuildSource}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Dynamic Link Libraries (Flutter engine, Firebase, plugins, etc.)
Source: "{#MyBuildSource}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Optional Native Assets configuration
Source: "{#MyBuildSource}\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Flutter Data assets, icons, shaders, and packages
Source: "{#MyBuildSource}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu Shortcut
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"

; Optional Desktop Shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Option to launch Focusly immediately after installation completes
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
