# Đánh giá & Định hướng Module Lưu Trú (Hospitalization)

> **Ngày đánh giá**: 04/02/2026
> **Phiên bản**: Hospitalization 2.0 (Core Logic Implemented)

## 1. Hiện trạng (Current State)
Module hiện tại đã hoàn thiện về mặt **Logic Core** và **Cấu trúc dữ liệu**. Hệ thống đủ khả năng vận hành cho quy trình nội trú cơ bản.

### ✅ Điểm mạnh (Pros)
1.  **Cấu trúc dữ liệu chặt chẽ**:
    *   Mô hình `DailyCare` (Tờ điều trị) cho phép theo dõi chi tiết từng ngày.
    *   `Regimen` (Phác đồ) hỗ trợ mẫu điều trị, giúp bác sĩ tiết kiệm thời gian.
    *   `VitalSignLog` theo dõi sinh hiệu chi tiết (nhiệt độ, tim mạch...).
2.  **Tích hợp tốt (Integration)**:
    *   Gắn liền với Bệnh án (`MedicalCase`).
    *   Tự động trừ kho (`Inventory`) khi thực hiện thuốc/dịch vụ.
    *   **Auto-Billing**: Tự động tính tiền lưu chuồng theo số ngày khi xuất viện.
3.  **Quản lý khoa học**:
    *   Phân tách rõ trạng thái chuồng: Trống / Có khách / Bảo trì.

### ⚠️ Điểm yếu / Còn thiếu (Cons)
1.  **Giao diện quản lý (UI)**:
    *   Vẫn dạng **Danh sách (List View)** hoặc Grid đơn giản. Chưa có **Sơ đồ trực quan (Visual Map)** (nhìn vào biết ngay vị trí chuồng).
    *   Chưa hỗ trợ Drag-and-Drop (Kéo thả) để chuyển chuồng.
2.  **Tính năng Đặt chỗ (Booking)**:
    *   Chưa có hệ thống đặt trước. Chỉ hỗ trợ "Nhập viện ngay".
    *   Không có Calendar View để xem lịch trống trong tương lai.
3.  **Chính sách giá**:
    *   Giá đang cố định theo Chuồng.
    *   Chưa hỗ trợ giá linh động (theo cân nặng, theo ngày lễ, theo gói VIP).

---

## 2. Phương hướng sử dụng (Usage Direction)
Với hiện trạng này, module nên được triển khai theo quy trình:

1.  **Nhập viện**: Từ màn hình Khám bệnh -> Chọn "Nhập viện" -> Chọn Chuồng trống.
2.  **Hàng ngày**:
    *   Bác sĩ: Vào Tờ điều trị -> Lên Phác đồ (thuốc/dịch vụ) cho hôm nay.
    *   Điều dưỡng/Trợ lý: Vào module (trên iPad/Tablet) -> Thực hiện y lệnh -> Tick "Đã làm" (Hệ thống tự trừ kho).
    *   Ghi sinh hiệu: 2-4 lần/ngày.
3.  **Xuất viện**: Bấm "Xuất viện" -> Hệ thống tự cộng tiền lưu chuồng + Thuốc men vào tổng bill -> Thanh toán.

---

## 3. Lộ trình phát triển (Development Roadmap)

Để module trở nên "Pro" và tiện dụng hơn, đề xuất lộ trình nâng cấp:

### 🚀 Giai đoạn 1: Visual Management (Ưu tiên cao)
Biến hệ thống quản lý thành **Bảng điều khiển trực quan**.
*   [ ] **Visual Cage Map**: Vẽ sơ đồ chuồng thực tế lên màn hình.
*   [ ] **Status Indicators**: Dùng màu sắc cảnh báo (Đỏ: Cấp cứu, Vàng: Cần thuốc, Xanh: Ổn).

### 🚀 Giai đoạn 2: Smart Alerts (Cảnh báo thông minh)
Tránh quên sót y lệnh.
*   [ ] **Nhắc thuốc**: Cảnh báo khi quá giờ y lệnh mà chưa tick "Đã làm".
*   [ ] **Cảnh báo sinh hiệu**: Tự động báo động nếu Nhiệt độ > 40°C hoặc < 36°C.

### 🚀 Giai đoạn 3: Reservation & Advanced Pricing
Mở rộng cho mô hình Hotel/Lưu trú cao cấp.
*   [ ] **Booking Calendar**: Lịch đặt chuồng (như đặt phòng khách sạn).
*   [ ] **Dynamic Pricing**: Cấu hình giá theo ngày Tết/Lễ, hoặc phụ thu theo cân nặng.

### 🚀 Giai đoạn 4: Client Connect
*   [ ] **Gửi báo cáo Zalo**: Gửi tình hình thú cưng (ăn uống, ảnh, sinh hiệu) tự động cho chủ nuôi mỗi ngày.

## 4. Kết luận
Module "Lư chuồn" (Lưu trú) hiện tại **ĐÃ SẴN SÀNG** để đưa vào sử dụng thực tế cho mục đích điều trị nội trú. Tuy nhiên, để nâng cao trải nghiệm người dùng (UX), nên ưu tiên triển khai **Giai đoạn 1 (Visual Map)** trong bản cập nhật tới.
