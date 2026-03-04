# PLAN-petshop-report

> **Goal**: Enhance the Monthly Report Export (`ExcelExportService`) to include Petshop-specific sheets, matching the templates provided by the user.

## 1. Context Analysis
- **User Request**: "Create report sections for Petshop in the monthly export, based on provided sample files."
- **Current System**:
    - `ExcelExportService` generates `BC Thang` (Clinic Revenue), `Danh muc Chi` (General Expenses), and `BC Vat Tu` (Inventory).
- **Target Formatting**:
    - **Sheet 1: Chi petshop** (Expenses): Needs to isolate Petshop expenses.
    - **Sheet 2: Petshop [Month]** (Sales): Needs to list product sales.

## 2. Solution Strategy
We will modify `ExcelExportService.dart` to add 2 new sheets to the existing `exportMonthlyReport` function.

## 3. Scope of Work

### Phase 1: Database Query Updates
- [ ] **Repository Update**: Ensure `ReportRepository` has methods to:
    - Get Expenses by Category ('Petshop').
    - Get Product Sales by Date Range.

### Phase 2: Excel Export Logic (`ExcelExportService`)
- [ ] **Implement `_buildChiPetshopSheet`**:
    - **Headers**: [Ngày, Nội dung, Số lượng, Đơn vị, Đơn giá, Thành tiền, Người chi, Ghi chú].
    - **Data Source**: `expenses` table where `category = 'Petshop'`.
- [ ] **Implement `_buildPetshopSalesSheet`**:
    - **Headers**: [Ngày, Tên hàng, Số lượng, Đơn giá, Thành tiền, Khách hàng, NV Bán].
    - **Data Source**: `product_sales` table.
- [ ] **Integration**: Call these build methods in `exportMonthlyReport`.

## 4. Technical Specifications

### Sheet 1 Layout: "Chi petshop"
| Column | Data Field |
|--------|------------|
| Ngày | `date` |
| Nội dung | `content` |
| Số lượng | `quantity` |
| Đơn vị | `unit` |
| Đơn giá | `unit_price` |
| Thành tiền | `amount` |
| Người chi | `staff_id` |
| Ghi chú | `notes` |

*Note: Filter `expenses` where `category` LIKE 'petshop' or 'Petshop'.*

### Sheet 2 Layout: "Petshop [Month]"
| Column | Data Field |
|--------|------------|
| Ngày | `sale_date` |
| Tên hàng | `product_name` |
| Số lượng | `quantity` |
| Đơn giá | `unit_price` |
| Thành tiền | `total` |
| Khách hàng | `customer_id` (Look up name) |
| NV Bán | `staff_id` |

## 5. Verification Plan
1.  **Generate Report**: Run Monthly Report for a month with known Petshop data.
2.  **Verify Sheets**: Check if "Chi petshop" and "Petshop [Month]" sheets exist.
3.  **Data Check**: Compare totals with Database.

## 6. Next Steps
1.  **Approval**: Review this updated plan.
2.  **Execution**: Run `/create` to modify `ExcelExportService`.
