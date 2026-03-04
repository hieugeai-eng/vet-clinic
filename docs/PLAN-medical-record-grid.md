# [PLAN] Medical Record Compact Grid UI

## Goal
Refactor the **Clinical Examination** (`clinical_exam_view.dart`) and **Diagnosis** (`diagnosis_view.dart`) screens to use a **responsive grid layout**.
**Objective**: "Information Density" - Display more information on a single screen to facilitate a comprehensive overview, reducing the need for scrolling.

## User Review Required
> [!NOTE]
> This refactor changes the visual structure significantly from a vertical list to a dense grid.
> - **Desktop**: Items will be arranged in rows (3-4 items/row).
> - **Mobile**: Items will auto-wrap but attempt to maintain density where possible.

## Proposed Changes

### 1. New Utility Widgets
Create `lib/modules/medical_cases/widgets/dense_grid_layout.dart` (or similar) if needed, or just use `Wrap`/`LayoutBuilder` inline.
- **Concept**: A unified "Medical Card" container that removes excessive outer padding in favor of internal density.

### 2. Physical Examination (`clinical_exam_view.dart`)
#### [MODIFY] `lib/modules/medical_cases/views/clinical_exam_view.dart`
- **Layout Strategy**:
    - **Header**: "Triệu chứng & Lý do" (Full width).
    - **Vitals & Physical Grid**:
        - Use `Wrap` with `runSpacing: 12, spacing: 12`.
        - **Item 1 (Weight & Temp)**: Combine into one compact block or keep adjacent.
        - **Item 2 (Vomit & Stool)**: Move to sit alongside Vitals if space permits.
        - **Item 3 (Mental & Body)**: Move to same row or next row.
        - **Item 4 (Mucosa)**: Compact field.
    - **Implementation Detail**:
        - Remove large `ProInfoCard` wrappers for every small section.
        - Use a **Single Main Card** or **Sectioned Grid** approach.

### 3. Diagnosis (`diagnosis_view.dart`)
#### [MODIFY] `lib/modules/medical_cases/views/diagnosis_view.dart`
- **Layout Strategy**:
    - **Diagnosis Row**:
        - Left (60%): Diagnosis Result Input.
        - Right (40%): Prognosis (Good/Bad/...) & Hospitalization Toggle.
    - **Services Section**:
        - Minimize header height.
        - Use a tighter table layout for selected services.

## Verification Plan

### Manual Verification
1.  **Run App**: `flutter run -d windows`
2.  **Navigate**:
    - Go to **Medical Cases** (Bệnh án).
    - Click **Create** (Tạo mới) or **Edit**.
    - Skip Step 1 (Reception).
    - **Check Step 2 (Clinical Exam)**:
        - Verify "Weight", "Temp", "Stool", "Mental" allow multi-column layout on wide screen.
        - Resize window to check wrapping behavior.
    - **Check Step 3 (Diagnosis)**:
        - Verify Diagnosis & Prognosis sit side-by-side.
