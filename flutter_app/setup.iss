[Setup]
AppId={{5A88B3DE-1C10-4A0B-9BCB-123456789ABC}
AppName=DocuSync
AppVersion=1.0.0
AppPublisher=Minhkt27
DefaultDirName={autopf}\DocuSync
DefaultGroupName=DocuSync
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=DocuSync_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
SetupIconFile=compiler:SetupClassicIcon.ico
UninstallDisplayIcon={app}\docusync_client.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\docusync_client.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DocuSync"; Filename: "{app}\docusync_client.exe"
Name: "{autodesktop}\DocuSync"; Filename: "{app}\docusync_client.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\docusync_client.exe"; Description: "{cm:LaunchProgram,DocuSync}"; Flags: nowait postinstall skipifsilent
