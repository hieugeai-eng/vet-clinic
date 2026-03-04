[Setup]
AppId={{5E0D03EC-D65D-410E-8549-F079F5E5AD28}
AppName=OKADA Vet Clinic
AppVersion=1.0.0
DefaultDirName={autopf}\OKADA Vet Clinic
DisableProgramGroupPage=yes
OutputDir=build\windows\installer
OutputBaseFilename=okada_vet_clinic_setup
Compression=lzma
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\OKADA Vet Clinic"; Filename: "{app}\okada_vet_clinic.exe"
Name: "{autodesktop}\OKADA Vet Clinic"; Filename: "{app}\okada_vet_clinic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\okada_vet_clinic.exe"; Description: "Khởi chạy OKADA Vet Clinic"; Flags: nowait postinstall skipifsilent
