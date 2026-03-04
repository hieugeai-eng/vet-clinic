[Setup]
AppName=Okada Vet Clinic
AppVersion=1.0
DefaultDirName={pf}\OkadaVetClinic
DefaultGroupName=Okada Vet Clinic
OutputBaseFilename=OkadaVetClinicInstaller
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableDirPage=no

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Okada Vet Clinic"; Filename: "{app}\okada_vet_clinic.exe"
Name: "{commondesktop}\Okada Vet Clinic"; Filename: "{app}\okada_vet_clinic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\okada_vet_clinic.exe"; Description: "Launch Okada Vet Clinic"; Flags: nowait postinstall skipifsilent
