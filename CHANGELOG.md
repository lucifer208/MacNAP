# Changelog

## [Unreleased] - 2026-10-28

### [12:46] feat: redesign App Update Center, separate Auto-Check & Auto-Install toggles & set author VPBank donate
- **Thiết kế lại toàn diện Trung tâm Cập nhật Ứng dụng (`UpdateSettingsSheetView` trong `AppUpdateAndDonateService.swift`)**:
  - Giao diện trung tâm cập nhật chuẩn macOS: Hiển thị App Icon, phiên bản hiện tại `v1.0.0 (Build 100)`, huy hiệu trạng thái (Bản mới nhất / Đang kiểm tra / Phát hiện bản mới kèm ghi chú phát hành / Đang cài đặt).
  - Tách biệt rõ ràng **2 công tắc cập nhật độc lập**:
    1. **`Tự động kiểm tra bản mới` (`autoCheckUpdateEnabled`)**: Chạy ngầm kiểm tra GitHub Releases khi mở app hoặc định kỳ.
    2. **`Tự động cài đặt bản mới` (`autoInstallUpdateEnabled`)**: Khi phát hiện bản mới, tự động tải về, cập nhật và khởi động lại MacNAP.
  - Các nút hành động: **Kiểm tra bản cập nhật ngay**, **Tải & Cài đặt bản mới**, và **Xem GitHub Releases**.
- **Cập nhật chính xác tài khoản thụ hưởng tác giả MacNAP (`AuthorDonateInfo`, `DonateSheetView`)**:
  - **Ngân hàng**: `VPBank` (Ngân hàng TMCP Việt Nam Thịnh Vượng).
  - **Số tài khoản (STK)**: `8888071992` (kèm nút bấm 1 chạm **Copy STK** to rõ).
  - **Chủ tài khoản**: `HUỲNH TUẤN HUY` (kèm nút **Copy Tên**).
  - **Nội dung chuyển khoản mặc định**: `MacNAP Donate` (kèm nút **Copy Nội dung**).
  - Tự động sinh mã **VietQR thực tế** cập nhật động theo mức ủng hộ (`30.000đ ☕️`, `50.000đ 🍜`, `100.000đ 🚀`, `200.000đ 💎` hoặc `Tuỳ tâm ❤️`), người dùng chỉ cần mở bất kỳ ứng dụng ngân hàng nào quét mã là tự điền đúng tên, số tài khoản và nội dung.

### [12:38] fix: remove duplicate update/donate buttons, add Report Issue sheet & allow custom user donate info with real VietQR
- **Xoá trùng lặp nút Update & Donate (`DashboardView.swift`, `MenuBarPopoverView.swift`)**:
  - Gỡ bỏ hoàn toàn nút kiểm tra update và donate bị trùng ở thanh Toolbar trên cùng.
  - Thanh Toolbar trên cùng giờ chỉ giữ lại nút **`Báo cáo lỗi / Góp ý`** và bộ chọn ngôn ngữ, tập trung nút Update & Donate tại thanh Sidebar và Menu Bar.
- **Bổ sung Cửa sổ Báo cáo Lỗi & Chẩn đoán (`ReportIssueSheetView` trong `AppUpdateAndDonateService.swift`, `AppState.swift`)**:
  - Tổng hợp sẵn toàn bộ thông số phần cứng, chip CPU, macOS, công suất live, thiết bị ngoại vi, tiến trình chặn sleep, trích xuất log gần nhất và đường dẫn file log.
  - Hỗ trợ nút **Copy toàn bộ báo cáo chẩn đoán** và mở trực tiếp trang GitHub Issues.
- **Tự do nhập & lưu thông tin Donate cá nhân kèm tạo mã VietQR thực tế (`DonateConfig`, `DonateSheetView`)**:
  - Không hardcode bất kỳ link hay mã QR nào. Cho phép người dùng tự nhập: **Ngân hàng (chọn từ danh sách ngân hàng Việt Nam)**, **Số tài khoản (STK)**, **Tên chủ tài khoản**, **Nội dung chuyển khoản mặc định** hoặc **Link Donate cá nhân (MoMo, PayPal, Buy Me a Coffee)**.
  - Dữ liệu được lưu vĩnh viễn (`UserDefaults`). Hệ thống tự động tạo mã **VietQR thực tế** theo đúng STK + Ngân hàng vừa nhập và hiển thị nút sao chép STK nhanh.

### [12:05] feat: official Release v1.0.0, redesign Sidebar Power box, remove AppleSMC/Sleep Aid jargon, add Check Update / Auto-Update & Donate modal
- **Phát hành phiên bản chính thức `v1.0.0` (`VERSION`, `scripts/bundle.sh`, `releases/latest.json`)**:
  - Thiết lập chuẩn `CFBundleShortVersionString = 1.0.0` (Build `100`), tự động đóng gói bản phát hành `releases/MacNAP-v1.0.0.zip` và manifest `releases/latest.json`.
- **Cơ chế Kiểm tra Cập nhật (`Check Update`) & Tự động Cập nhật (`Auto-Update`) (`AppUpdateAndDonateService.swift`, `AppState.swift`)**:
  - Thêm công tắc **Tự động kiểm tra & cập nhật** (`autoUpdateEnabled`) và nút **Kiểm tra Update / Cập nhật ngay** trên cả thanh Toolbar trên cùng, Sidebar và Menu Bar Popover.
  - Hỗ trợ tự động kiểm tra manifest phiên bản mới, giải nén/biên dịch bản cập nhật mới và tự khởi động lại (`relaunchApp`) liền mạch.
- **Cơ chế Ủng hộ tác giả (`DonateSheetView` trong `AppUpdateAndDonateService.swift`)**:
  - Bổ sung nút **❤️ Ủng hộ (Donate)** trên Toolbar, Sidebar và Menu Bar, mở cửa sổ Donate tích hợp mã QR tạo trực tiếp bằng `CoreImage` (`CIQRCodeGenerator`), chọn mức ủng hộ (`3$ ☕️`, `5$ 🍜`, `10$ 🚀`, `25$ 💎`) và 3 kênh ủng hộ nhanh (`Buy Me a Coffee`, `PayPal / Chuyển khoản`, `GitHub Sponsors & Star`).
- **Thiết kế lại cụm Nguồn ở Sidebar & Xoá bỏ toàn bộ từ khoá kỹ thuật thừa (`AppleSMC`, `PSTR`, `PDTR`, `Sleep Aid`) (`DashboardView.swift`, `MacNAPApp.swift`, `MenuBarPopoverView.swift`)**:
  - Đổi tiêu đề cửa sổ thành **`MacNAP — Quản lý Nguồn & Bảo vệ Pin`**; đổi toàn bộ tiêu đề thẻ KPI, biểu đồ và chú thích về đúng tên chức năng thực tế (`Tổng tiêu thụ`, `Thiết bị ngoại vi`, `Sạc vào (Max 140W)`, `Pin hiện tại`).
  - Đưa trạng thái nguồn (`Dùng nguồn trực tiếp (+0.47W Pin)` / `Đang sạc vào Pin` / `Đang dùng Pin`) lên thanh huy hiệu ngang 1 dòng ở đầu khung Sidebar, chấm dứt hoàn toàn lỗi rớt dòng 3 hàng.

### [11:55] feat: redesign Sleep Aid timeline card, comparison pills, bottom DarkWake tick strip & interactive event inspector
- **Thiết kế lại bố cục Header & Điều khiển của Biểu đồ Phiên Ngủ (`DashboardView.swift`)**:
  - **Hàng 1**: Tách riêng cụm Tiêu đề + Mô tả bên trái và bộ chuyển chế độ (`Theo lần Sleep / CloseLid` | `Theo Ngày (Từ 00:00)`) cố định kích thước + nút `Đọc lại log` bên phải, chấm dứt hoàn toàn lỗi đè chữ lên nhau.
  - **Hàng 2**: Đặt Menu chọn phiên ngủ (`Menu`) gọn đẹp bên trái và 3 huy hiệu so sánh trực quan (`Thực tế chưa bật App`, `Khi bật Auto-Unmount`, `Auto-Unmount + Chặn DarkWake`) bên phải, loại bỏ hoàn toàn lỗi hiển thị ký tự `**` Markdown thô.
- **Làm sạch Biểu đồ Đường & Vạch DarkWake (`DashboardView.swift`, `AppState.swift`)**:
  - Thay thế hơn 80 đường kẻ dọc màu cam kéo kín chiều cao biểu đồ (gây rối mắt như "song sắt") bằng **Dải Tick DarkWake 10% ở đáy biểu đồ** kết hợp duy nhất **1 đường gióng Crosshair dọc** tại điểm sự kiện đang chọn.
  - Mặc định chọn ngay **phiên ngủ gần nhất có hao pin** (`27/10 22:51 → 28/10 09:25 • -20%`) thay vì nhảy về phiên cũ nhất.
- **Thanh Chi tiết Sự kiện (Event Inspector) có nút điều hướng `◀` / `▶` (`DashboardView.swift`, `SleepMountGuardService.swift`)**:
  - Bổ sung bộ nút chuyển nhanh từng mốc sự kiện (`◀` / `▶` kèm bộ đếm `Sự kiện X/Y`), làm sạch chuỗi nguyên nhân đánh thức máy (`triggerReason`) không còn bị cắt cụt ở `Using BATT (Charge`, kèm giải thích tiếng Việt/Anh rõ ràng cho `ATC0.USBWakeup`, `SleepService`, `SMC.OutboxNotEmpty`.

### [11:44] feat: redesign Power & Assertions Log tab + add persistent Activity & Signal Crash Logger (`AppDiagnosticLogger`)
- **Hệ thống tự tạo File Log Hoạt động & Bẫy lỗi Văng App (`AppDiagnosticLogger.swift`)**:
  - Tự động ghi log đồng bộ (`synchronize`) xuống `/Users/lu/HUB/MacNAP/logs/macnap-activity.log` và `~/Library/Logs/MacNAP/macnap-activity.log` (hỗ trợ xoay vòng file log `rotate` khi vượt quá 2MB).
  - Cài đặt **Crash & Signal Guard** (`NSSetUncaughtExceptionHandler` + POSIX signal handlers cho `SIGABRT`, `SIGSEGV`, `SIGBUS`, `SIGILL`, `SIGTRAP`, `SIGFPE`) ghi trực tiếp stack trace (`backtrace_symbols_fd`) vào file log trước khi tiến trình thoát, kèm file `.macnap-running.lock` tự phát hiện nếu phiên chạy trước bị văng/force-kill.
- **Thiết kế lại toàn diện Tab 4 — `Nhật ký Nguồn & Chẩn đoán` (`DashboardView.swift`, `SleepMountGuardService.swift`)**:
  - Bổ sung 3 thẻ KPI Chẩn đoán ở đầu trang (`Tiến trình giữ máy thức`, `Bảo vệ Sleep/CloseLid & DarkWake`, `Nhật ký Hoạt động & Bẫy lỗi Crash`) và thanh công cụ mở nhanh file log trong Finder.
  - Chia 2 cột đối xứng chiều cao cố định (`465pt`) có `ScrollView` riêng biệt:
    - **Cột trái**: Làm sạch chuỗi XPC/UUID rối mắt của `runningboardd`/`Safari`/`coreaudiod` thành thẻ tiến trình gọn đẹp, dễ đọc, kèm lịch sử Auto-Unmount/Remount.
    - **Cột phải**: Bộ chuyển đổi kép giữa **🛠 Nhật ký App & Crash Guard** (hiển thị realtime mọi thao tác của app) và **⚡ Nhật ký Nguồn (`pmset`)** (chỉ lọc các dòng chuẩn có mốc ngày giờ đầu dòng, loại bỏ lỗi cắt chuỗi hex).

### [11:29] feat: auto-close Dashboard when inactive, zero-truncation responsive layout, 140W MacBook Pro hardware spec, realtime peripheral Watts & explicit Charging vs Direct Power status
- **Tự động đóng cửa sổ Dashboard khi mất active (`MacNAPApp.swift`)**:
  - Theo dõi `NSApplication.didResignActiveNotification` và `NSWindow.didResignKeyNotification` để tự động ẩn (`orderOut`) cửa sổ Dashboard ngay khi nhấn ra ngoài, đồng thời giữ cửa sổ không bị đóng nhầm khi đang mở menu chọn ngôn ngữ/phiên ngủ bên trong.
- **Hiển thị đầy đủ 100% nội dung trên thẻ KPI & Biểu đồ (`DashboardView.swift`)**:
  - Mở rộng kích thước mặc định của Dashboard (`1280x850`), áp dụng `.minimumScaleFactor` và `.fixedSize` cho toàn bộ 4 thẻ Bento KPI để không còn bất kỳ chữ hay huy hiệu nào bị cắt cụt (`...`), tiêu đề biểu đồ Sleep Aid nằm gọn trên 1 dòng.
- **Nhận diện chuẩn công suất sạc tối đa theo từng đời máy MacBook (`PowerTelemetryService.swift`)**:
  - Đọc `hw.model` & `machdep.cpu.brand_string` (`MacBookPro18,2` — `Apple M1 Max` 16-inch hỗ trợ sạc tối đa **`Max 140W`**), hiển thị song song công suất tối đa của máy (`140W`) và công suất củ sạc đang cắm (`100W`).
- **Hiển thị rõ công suất thiết bị ngoại vi dưới phần tiêu thụ & chế độ Sạc vào Pin vs Dùng nguồn trực tiếp (`AppState.swift`, `DashboardView.swift`, `MenuBarPopoverView.swift`)**:
  - Ngay dưới thẻ **Công suất tiêu thụ (`System Total`)** và Sidebar: Hiển thị rõ **`🔌 Thiết bị ngoại vi: X.XX W • Core: Y.YY W`** và công suất cổng USB-C Out (`PowerOutDetails`).
  - Ngay dưới thẻ **Nguồn sạc vào (`DC In`)**: Hiển thị tường minh đang **`⚡ Đang sạc vào Pin (+X.XX W) • Nuôi máy trực tiếp`**, hay **`🔌 Dùng nguồn trực tiếp (Sạc duy trì vào Pin: +0.47 W)`**, hay **`🔋 Đang dùng Pin (Xả từ Pin)`**.
- **Tab Thiết bị Ngoại vi & USB chạy công suất Realtime 1.0s (`PowerTelemetryService.swift`, `DashboardView.swift`)**:
  - Kết hợp thông số điện áp/dòng thực tế từ `AppleSmartBattery` (`PowerOutDetails`: `AdapterVoltage`, `Current`, `Watts`) với cảm biến `AppleSMC` mỗi 1.0 giây, bổ sung 3 thẻ KPI Ngoại vi Realtime và **Biểu đồ Đường Công suất Ngoại vi Realtime (1.0s)** ngay trong tab Thiết bị.

### [11:19] fix: remove top toolbar action buttons, use dropdown language menu & unify Sleep/CloseLid detection and log parsing
- **Dọn gọn thanh Toolbar trên Dashboard (`DashboardView.swift`)**:
  - Loại bỏ hoàn toàn 3 nút hành động thừa (`Unmount ổ ngoài`, `Mount lại ngay`, `Unmount & Ngủ ngay`) trên thanh tiêu đề trên cùng của Dashboard.
  - Đổi bộ chọn ngôn ngữ (`Tiếng Việt / English`) sang dạng **Menu xổ xuống (`Picker` với `.pickerStyle(.menu)`)** trên cả Dashboard và Menu Bar Popover.
- **Đồng bộ tuyệt đối `Sleep / CloseLid` và `Wake / OpenLid` (`PowerTelemetryService.swift`, `AppState.swift`, `SleepMountGuardService.swift`)**:
  - Đọc trực tiếp trạng thái gập nắp phần cứng `AppleClamshellState` từ `IOPMrootDomain` (IOKit) kết hợp với `NSWorkspace.willSleepNotification` / `didWakeNotification` để `Sleep` và `CloseLid` luôn đi cùng nhau làm một (và `Wake` / `OpenLid` đi cùng nhau).
  - Loại bỏ dòng rác `MaintenanceWake "com.apple.obc"` khỏi luồng trích xuất phiên ngủ `pmset -g log`, giúp giữ nguyên vẹn 100% phiên `Clamshell Sleep` (`CloseLid / Sleep`) từ lúc gập nắp (`27/10 22:51` • `100%`) đến lúc mở nắp (`28/10 09:25` • `80%`, mất `-20%`) thay vì bị cắt ngang.

### [11:11] feat: align all toggle switches right, group settings into clusters & add direct DarkWake blocker toggle
- **Căn thẳng hàng tuyệt đối toàn bộ công tắc (`Toggle`) & icon thông số ở Sidebar và Menu Bar Popover**:
  - Sửa lỗi `Toggle("Label")` mặc định của SwiftUI làm lệch vị trí nút gạt theo độ dài chữ: Tách thành `HStack { Text(title); Spacer(); Toggle("", isOn: ...).labelsHidden() }` để tất cả các công tắc thẳng tắp một cột bên phải, icon thông số cố định `frame(width: 16)`.
- **Chia rõ từng cụm tính năng (`Card Clusters`)**:
  1. **Cụm 1 (Live Telemetry)**: `System Total`, `DC In`, `Pin hiện tại`.
  2. **Cụm 2 (`BẢO VỆ NGỦ & Ổ NGOÀI` / `SLEEP & DRIVE GUARD`)**: `Tự Unmount khi gập nắp`, `Tự Mount khi mở nắp`, `Chặn DarkWake (Pin)`.
  3. **Cụm 3 (`HỆ THỐNG & GIAO DIỆN` / `SYSTEM & INTERFACE`)**: `Khởi động cùng macOS`, `Ẩn icon trên thanh Dock`.
- **Thêm nút bật/tắt trực tiếp `Chặn DarkWake (Pin)` (`SleepMountGuardService.swift`)**:
  - Đọc trạng thái thật từ `pmset -g custom` (`tcpkeepalive` & `powernap` ở mục `Battery Power`).
  - Khi gạt công tắc sẽ mở hộp thoại xác thực quyền Admin chuẩn của macOS để chạy `/usr/bin/pmset -b tcpkeepalive 0 powernap 0 womp 0 ttyskeepawake 0` (hoặc khôi phục về `1` khi tắt).

### [11:05] feat: add Sleep Analysis Mode switcher (By Sleep Session vs By Day from 00:00)
- **Thêm bộ chuyển đổi chế độ xem phiên ngủ (`SleepAnalysisMode`: Theo lần Sleep vs Theo Ngày từ `00:00`)**:
  - **Theo lần Sleep (`By Sleep Session`)**: Tính từ lúc gập nắp bắt đầu ngủ đến lúc mở máy (`FullWake`), gộp trọn vẹn cả đêm ngủ (`100% → 80%`, mất `-20%`).
  - **Theo Ngày (`By Day • Từ 00:00`)**: Tự động gom toàn bộ quá trình ngủ từ `00:00` đêm đến lúc mở máy trong ngày đó (ví dụ `Ngày 28/10 (00:00 / 00:50 → 09:25)`: `100% → 80%`, mất `-20%`), cho phép chọn xem lại từng ngày trước đó.
  - Có nút chuyển nhanh Segmented Picker ngay trên cả **Menu Bar Popover** và **Dashboard**.

### [11:01] feat: custom NSPopover Menu Bar UI, double-click Menu Bar to open Dashboard, VI/EN i18n & equal-height Bento KPI cards
- **Thay thế Menu chuẩn của macOS bằng `NSPopover` Custom View (`MenuBarPopoverView.swift` & `StatusBarController.swift`)**:
  - Loại bỏ hoàn toàn hiện tượng các dòng chữ bị xám mờ (`disabled`) của `NSMenu` mặc định.
  - Đưa nút **"Mở Dashboard Phân tích" (`Open Analytics Dashboard`)** lên ngay đầu tiên trong Menu Bar Popover.
  - Hỗ trợ **Double-click (nhấp đúp)** hoặc **Right-click** trực tiếp vào icon trên thanh Menu Bar để mở ngay cửa sổ Dashboard.
- **Hệ thống đa ngôn ngữ `Tiếng Việt / English` (`Localization.swift`)**:
  - Chuyển đổi tức thì `VI / EN` ngay trên Menu Bar Popover, Sidebar hoặc thanh công cụ của Dashboard (tự lưu vào `UserDefaults`).
- **Làm lại 4 thẻ KPI đồng nhất chiều cao (`132pt`) & dự đoán pin dễ hiểu (`DashboardView.swift`)**:
  - Cố định chiều cao 4 thẻ KPI bằng nhau tuyệt đối, có viền phát sáng nhẹ theo màu trạng thái và pill badge góc phải.
  - Hiển thị dự đoán trực quan dễ hiểu: *"Chỉ mất ~1% Pin (`90% → ~89%`) • Giữ lại +9% pin mỗi đêm"* thay vì dải số âm khó đọc.

### [10:50] feat: Launch at Login, Hide Dock Icon toggle, MenuBar-only startup & NavigationSplitView UI redesign
- **Khởi động cùng máy & Chạy ngầm chỉ hiện trên Menu Bar**:
  - Thêm nút **"Khởi động cùng máy tính (Login)"** (`SMAppService` + fallback `~/Library/LaunchAgents/com.lu.MacNAP.plist`).
  - Thêm nút **"Ẩn icon trên thanh Dock"** (`NSApplication.shared.setActivationPolicy(.accessory)` vs `.regular`).
  - Khi mới mở app, chỉ hiện thông tin realtime trên thanh Menu Bar (`defaultLaunchBehavior(.suppressed)` + `LSUIElement`). Khi người dùng bấm **"Mở bảng phân tích chuyên sâu (Dashboard)"** mới mở cửa sổ.
- **Thiết kế lại toàn bộ giao diện (`DashboardView.swift`)**:
  - Chuyển từ cuộn dọc dài sang kiến trúc **`NavigationSplitView` 2 cột chuẩn macOS** với Sidebar điều hướng 4 phân khu độc lập:
    1. **Tổng quan & Realtime**: KPI Cards + Biểu đồ AppleSMC 1.0s + Xem nhanh Sleep Aid.
    2. **Phân tích Phiên Ngủ (Sleep Aid)**: Biểu đồ tương tác theo ngày giờ thực tế từ `pmset log` + 2 đường dự đoán `%` pin tiết kiệm được.
    3. **Ngoại vi & Auto-Unmount**: Quản lý từng thiết bị + cổng Thunderbolt SMC Live + mở cửa sổ Chart & Log riêng.
    4. **Nhật ký Nguồn & Assertions**: Bảng lọc `pmset Power Log` & lịch sử đóng/mở nắp.

### [10:45] feat: direct AppleSMC 1s realtime reader (PSTR, PDTR, PTRL, PTRR), restore colorful App/Dashboard icons & enlarge Menu Bar font
- **Đọc trực tiếp phần cứng `AppleSMC` chuẩn 100% như app Stats (`SMCReader.swift`)**:
  - Đọc trực tiếp các key cảm biến SMC mỗi **1.0 giây** (realtime): `PSTR` (`System Total`), `PDTR` (`DC In`), `PTRL` (`Thunderbolt Left`), `PTRR` (`Thunderbolt Right`), `PPBR` (`Battery Power`). Không còn bị trễ 30–60 giây như `AppleSmartBattery`.
- **Trả lại màu sắc cho App Icon (Dock) và các icon trong Dashboard**:
  - Khôi phục bộ màu Indigo + Cyan + Yellow `Zzz` cho `AppIcon.icns`, Header và các thẻ KPI/danh sách thiết bị trong cửa sổ chính.
  - Chỉ giữ **Monochrome SF Symbols** cho 2 icon tia sét (`bolt.fill`) và phích cắm (`powerplug.fill`) trên thanh Menu Bar, đồng thời tăng cỡ chữ Menu Bar lên chuẩn macOS (`13.5pt semibold`, icon `14pt`).

### [10:40] fix: move all pmset & diskutil subprocesses off MainActor to eliminate UI freeze
- **Triệt tiêu hoàn toàn hiện tượng đơ/freeze app khi đọc `pmset` & `diskutil` (`AppState.swift` & `SleepMountGuardService.swift`)**:
  - Đưa toàn bộ lệnh `pmset -g log`, `pmset -g assertions`, `diskutil list -plist` và `diskutil mount/unmount` sang `Task.detached(priority: .utility)` chạy ngầm ngoài luồng giao diện (`@MainActor`).
  - Đổi thứ tự `readDataToEndOfFile()` trước `waitUntilExit()` để tránh kẹt pipe buffer (deadlock) khi output của `pmset` lớn.
  - Gộp 2 lần gọi `pmset -g log` thành 1 lần duy nhất (`loadAllPmsetLogData`) và thêm trạng thái `ProgressView` ("Đang đọc log...") trên nút bấm.

### [10:36] feat: use SystemTotal vs DCIn and switch to monochrome SF Symbols & Dock/Menu Bar icons
- Đổi sang chuẩn đo **System Total** (`SystemEnergyConsumed` ~ 6.8W) và **DC In** (`SystemVoltageIn * SystemCurrentIn` ~ 24.7W).
- Thay toàn bộ emoji màu (`⚡️`, `🔌`, `🖨️`, `🌙`) và icon màu loè loẹt bằng **SF Symbols đơn sắc (monochrome)** (`bolt.fill`, `powerplug.fill`).
- Vẽ trực tiếp `NSImage(isTemplate: true)` trên Menu Bar gồm SF Symbol tia sét + Watt tiêu thụ và SF Symbol phích cắm + Watt DC In.
- Thiết kế lại icon App/Dock/Header sang phong cách Dark/Silver monochrome tối giản hiện đại.

### [10:32] fix: accurate SystemEnergyConsumed & Battery Charging Watts + predicted % battery saved with MacNAP
- **Sửa công suất tiêu thụ thực & công suất đang sạc vào Pin (`PowerTelemetryService.swift`)**:
  - Đọc `SystemEnergyConsumed` (mW) làm công suất tiêu thụ thực của máy (`~6.5W - 9W`), tách biệt với `SystemPowerIn` (tổng nguồn củ sạc PD cấp) và `InstantAmperage * Voltage` (công suất thực nạp vào viên pin: `0.00 W (Giữ Pin)` khi macOS bật Bypass ở `90%` pin, hoặc `+W` khi đang sạc).
- **Hiển thị rõ dự đoán `%` pin khi dùng MacNAP (`AppState.swift` & `DashboardView.swift`)**:
  - Thêm thẻ KPI **"Dự đoán % Pin khi dùng MacNAP"** và vẽ trực tiếp 2 đường dự đoán trên biểu đồ phiên ngủ:
    1. **Bật Auto-Unmount ổ ngoài**: Giảm hao phí từ `-20%` xuống chỉ còn **`~ -7.9%`** (tiết kiệm `+12%` pin).
    2. **Bật Auto-Unmount + Tắt DarkWake**: Giảm xuống chỉ còn **`~ -3.1%`** (giữ lại `~97%` pin sau 10.6h ngủ).

### [10:27] fix: display single-text lightning & plug Watts in MenuBarExtra label
- Sửa lỗi `MenuBarExtra` trên macOS chỉ render phần tử `Text` đầu tiên khi dùng nhiều `Text` trong `HStack`: Gộp thành một `Text("⚡️%.1fW 🔌%.1fW")` duy nhất để hiển thị rõ biểu tượng tia sét (Watt tiêu thụ) và phích cắm sạc (Watt sạc vào) ngay trên thanh Menu Bar.

### [10:24] feat: Sleep Aid interactive timeline from real pmset log, Dock icon fix, Menu Bar In/Out Watts & per-device popup window
- **Phân tích chuẩn từ `pmset -g log` (Loại bỏ dự báo giả định)**:
  - Tự động trích xuất các phiên ngủ thật từ `pmset -g log` (như phiên đêm qua `00:50 → 09:25`: Pin từ `100%` xuống `80%`, mất đúng `-20%`, 29 lần `DarkWake` do `rtc/SleepService`, `wifibt SMC.OutboxNotEmpty` và `ATC0.USBWakeup`, công suất rò trung bình thực tế `2.23 W`).
  - Hiệu chỉnh lại công suất thực tế của từng thiết bị USB (thay vì lấy nguyên trần Max Allocation `896mA`/`496mA`).
- **Biểu đồ tương tác kiểu Sleep Aid theo ngày giờ (`DashboardView.swift`)**:
  - Vẽ đường cong `%` pin thực tế kết hợp các vạch `RuleMark` cam/đỏ tại đúng thời điểm máy bị `DarkWake` / `Wake` trong đêm.
  - Nhấn trực tiếp vào bất kỳ điểm/vạch giờ nào trên biểu đồ sẽ hiện chi tiết nguyên nhân thức (`triggerReason`), thời lượng thức (`secs`), `%` pin lúc đó và dòng `raw pmset log`.
- **Cửa sổ mới (Popup Window) riêng cho từng thiết bị (`DeviceDetailView.swift`)**:
  - Nhấn vào bất kỳ thiết bị nào trong danh sách hoặc từ Menu Bar sẽ mở cửa sổ riêng hiển thị biểu đồ Watts realtime + lịch sử Log của riêng thiết bị đó.
- **Menu Bar & Dock Icon**:
  - Menu Bar hiển thị đồng thời công suất đang tiêu thụ và công suất đang sạc vào (`↓15.4W ↑15.4W`).
  - Gán trực tiếp `NSApplication.shared.applicationIconImage` bằng `SleepingMacIconView.renderDockIcon()` kết hợp `lsregister -f MacNAP.app` để icon Mac ngủ `Zzz` hiện chuẩn trên thanh Dock.

### [10:13] feat: auto-unmount on sleep & instant remount on wake, remove third-party brand, add Sleeping Mac Zzz icon & deep charts/logs
- Thay toàn bộ cơ chế `diskutil eject` bằng `diskutil unmount <partition>` khi gập nắp và `diskutil mount <partition>` khi mở nắp.

### [10:06] feat: init MacNAP native SwiftUI deep Watt profiler
- Đọc trực tiếp `AppleSmartBattery` và `IOUSBHostDevice` qua `IOKit`.
