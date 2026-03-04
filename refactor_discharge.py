import os

file_path = "lib/modules/hospitalization/views/widgets/hospitalization_dialogs.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add import
if "import '../discharge_checklist_sheet.dart';" not in content:
    content = content.replace(
        "class HospitalizationDialogs {", 
        "import '../discharge_checklist_sheet.dart';\n\nclass HospitalizationDialogs {"
    )

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# 2. Slice from 403 to end and replace
# confirmDischarge starts at line 403 originally, but after adding import it shifts (+2)
start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if "static void confirmDischarge" in line:
        start_idx = i
        break

for i in range(len(lines)-1, -1, -1):
    if lines[i].strip() == "}":
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_lines = lines[:start_idx]
    new_lines.append("  static void confirmDischarge(BuildContext context, HospitalizationController controller, CageOccupant occupant) {\n")
    new_lines.append("    DischargeChecklistSheet.show(\n")
    new_lines.append("      context,\n")
    new_lines.append("      hospitalizationId: occupant.hospitalizationId,\n")
    new_lines.append("      petName: occupant.petName,\n")
    new_lines.append("      controller: controller,\n")
    new_lines.append("    );\n")
    new_lines.append("  }\n")
    new_lines.append("}\n")
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print("Replaced successfully")
else:
    print("Could not find blocks")
