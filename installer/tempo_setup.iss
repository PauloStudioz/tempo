; Script generated for Tempo Desktop Application
#define MyAppName "Tempo"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Tempo"
#define MyAppExeName "tempo.exe"
#define MyAppIcon "..\windows\runner\resources\app_icon.ico"
#define SourceReleaseDir "..\build\windows\x64\runner\Release"
#define ModelsDir "..\models"

[Setup]
AppId={{5E4C236B-0F88-46E1-817E-97554904C75D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Tempo-Setup-{#MyAppVersion}
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Executable
Source: "{#SourceReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All Required Dynamic Link Libraries (.dll) including record_windows_plugin.dll, flutter_windows.dll, sqlite3.dll, etc.
Source: "{#SourceReleaseDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Native Assets JSON
Source: "{#SourceReleaseDir}\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Flutter Data Directory (Asset bundle, engine runtime, fonts, shaders, licenses)
Source: "{#SourceReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Local STT Models and Helper Scripts
Source: "{#ModelsDir}\*"; DestDir: "{app}\models"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

