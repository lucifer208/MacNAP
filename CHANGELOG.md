# Changelog

## [1.0.1] - 2026-10-28

### [19:26] fix(ui): deduplicate version displays and redesign popover dropdown to eliminate text truncation
- **Gom gọn hiển thị Version (chỉ hiện duy nhất 1 lần) (`DashboardView.swift`, `MenuBarPopoverView.swift`)**:
  - Dashboard: Chỉ giữ phiên bản gọn gàng dưới tên MacNAP ở đầu Sidebar. Gỡ bỏ hoàn toàn huy hiệu `Release v...` ở tiêu đề trang, gỡ `v...` ở nhóm Hệ thống, đổi nút Cập nhật thành nhãn ngắn "Đã là bản mới nhất".
  - MenuBar Popover: Chỉ hiển thị phiên bản ở thanh Footer dưới cùng. Gỡ bỏ `v...` ở nhóm Hệ thống.
- **Thiết kế lại giao diện xổ xuống MenuBar không bị mất chữ (`MenuBarPopoverView.swift`, `StatusBarController.swift`)**:
  - Mở rộng chiều ngang Popover lên 370px.
  - Thay picker ngôn ngữ to cồng kềnh bằng nút chuyển đổi VI/EN nhỏ gọn, giữ nguyên toàn bộ chữ "MacNAP" và phụ đề không bị cắt ngắn `...`.
  - Thiết kế lại 2 thẻ đo công suất (`Tổng tiêu thụ`, `Nguồn sạc vào`) với nhãn ngắn gọn, súc tích.
  - Tách bố cục banner so sánh phiên ngủ thành 2 dòng (thời gian bên trái, mức tụt bên phải) tránh tràn dòng.

### [18:44] feat(sleep-aid): add sleep battery drain culprits breakdown cards & proportional bar
- **Bóc tách nguyên nhân đốt pin khi Sleep / CloseLid (`DashboardView.swift`, `Models.swift`)**:
  - Tự động phân loại 4 tác nhân chính:
    1. Cổng USB & Thiết bị Ngoại vi (Hub / SSD): Cấp nguồn 5V bus và ngắt phần cứng `ATC0.USBWakeup`.
    2. Sóng Wi-Fi & Gói mạng IP ngầm: Card Wi-Fi duy trì nhận gói IP khi chưa tắt `tcpkeepalive`.
    3. Tác vụ bảo trì ngầm macOS: Apple RTC timer chạy `SleepService` / `Maintenance Sleep` đồng bộ iCloud/Mail.
    4. Tiêu thụ phần cứng tự nhiên: Dòng điện tối thiểu duy trì RAM Self-Refresh & SMC chip Apple Silicon.
  - Hiển thị thanh tỷ lệ màu trực quan (Segmented Bar) kèm số % hao pin và % tỷ trọng cụ thể của từng tác nhân.
  - Tích hợp nút hành động nhanh "Chặn DarkWake ngay" khi phát hiện phiên ngủ bị thức dậy bởi mạng ngầm.

### [16:12] fix(settings): resolve settings window trigger and automate timestamped versioning
- **Sửa triệt để lỗi không mở được cửa sổ Cài đặt (`DashboardView.swift`, `AppState.swift`, `MacNAPApp.swift`, `MenuBarPopoverView.swift`)**:
  - Gỡ bỏ ép kiểu `(NSApp.delegate as? MacNAPAppDelegate)` (bị nil do SwiftUI AppDelegateAdaptor bao bọc).
  - Định tuyến mở cài đặt qua `state.openSettings()`, kết nối trực tiếp AppDelegate handler và `MacNAPAppDelegate.shared`.
  - Hỗ trợ phím tắt `⌘,` trên cả Dashboard và MenuBar Popover.
- **Tự động định dạng phiên bản `1.0.1.yymmddhhss` (`scripts/bundle.sh`, `VERSION`, `releases/latest.json`)**:
  - Tự động gắn timestamp `yymmddhhss` (Năm 2 số, Tháng, Ngày, Giờ, Giây) sau mỗi lần fix và build.

### [15:58] fix(audit): fix smc connection lifecycle, menu activation and update author links
- **Đóng kết nối AppleSMC an toàn (`SMCReader.swift`)**:
  - Bổ sung `deinit` giải phóng cổng `IOServiceClose(connection)` tránh rò rỉ mach port.
  - Tự động reset và tái tạo kết nối khi cổng SMC bị ngắt hoặc không phản hồi sau chu kỳ Sleep/Wake.
- **Kích hoạt Menu Bar hệ thống chuẩn xác (`MacNAPApp.swift`)**:
  - Chuyển `NSApp.activate` sang asynchronous main queue sau khi đổi `activationPolicy(.regular)` để menu bar của MacNAP luôn hiển thị chính xác thay vì bị đè bởi app khác.
- **Đồng bộ liên kết tác giả & thông tin dự án (`SettingsView.swift`)**:
  - Cập nhật đúng GitHub URL `@lucifer208/MacNAP` trong tab Giới thiệu.
- **Biên dịch & Bundle bản mới nhất**:
  - Loại bỏ hoàn toàn mục `Cài đặt` bị trùng lặp ở sidebar và làm mới tiến trình chạy thực tế.

### [14:57] docs: update README and README_EN with all 7 highlight features
- **Cập nhật đầy đủ 7 tính năng nổi bật (`README.md` & `README_EN.md`)**:
  1. Auto-Unmount ổ ngoài khi Sleep / Gập nắp.
  2. Auto-Remount 2 đợt khi Wake / Mở nắp.
  3. Chặn thức ngầm DarkWake khi dùng Pin.
  4. Auto Low Power Mode khi gập nắp trên Pin.
  5. Săn "Kẻ trộm giấc ngủ" (Sleep Insomnia Hunter).
  6. Báo động Tụt Pin Sáng Dậy (Morning Drain Alert).
  7. Biểu đồ Phân tích Pin & Đo công suất SMC 1.0s.

### [14:52] ci: add GitHub Actions automated release pipeline & create tag v1.0.1
- **Tự động hóa phát hành bản mới (`.github/workflows/release.yml`)**:
  - Tích hợp CI/CD tự động chạy trên macOS-14 (Apple Silicon).
  - Tự động đóng gói `.dmg`, `.zip` và publish lên mục GitHub Releases khi push tag `v*`.
- **Gắn nhãn phiên bản `v1.0.1`**:
  - Tạo Git Tag `v1.0.1` sẵn sàng cho việc phát hành tự động.

### [14:38] fix(ui): remove duplicate Settings item from sidebar navigation list
- **Loại bỏ mục trùng lặp `Cài đặt & Tùy chọn` trong Sidebar List (`AppState.swift`, `DashboardView.swift`, `Localization.swift`)**:
  - Gỡ `DashboardSection.settings` khỏi danh sách điều hướng bên trái để tránh dư thừa và làm chật sidebar.
  - Nút **`⚙️ Cài đặt (⌘,)`** trên thanh Toolbar trên cùng và phím tắt `⌘,` mở trực tiếp cửa sổ Cài đặt native của macOS.

### [14:29] feat(guard): implement Auto Low Power Mode, Sleep Insomnia Hunter & Morning Drain Alert
- **Tính năng 1: Tự động kích hoạt Low Power Mode khi gập nắp trên Pin (`AppState.swift` & `SleepMountGuardService.swift`)**:
  - Tự động hạ xung nhịp CPU/GPU qua `pmset -b powermode 1` khi gập nắp/sleep trên pin.
  - Tự động khôi phục xung nhịp bình thường (`powermode 0`) ngay khi mở nắp/wake.
- **Tính năng 2: Săn "Kẻ trộm giấc ngủ" (Sleep Insomnia Hunter & Alert)**:
  - Tự động phát hiện các tiến trình nền (Docker, Chrome, qBittorrent, Media...) giữ quyền ngăn Mac đi ngủ.
  - Tự động gửi macOS Local Notification cảnh báo khi người dùng gập nắp để tránh tình trạng máy chạy ngầm nóng ran trong balo.
- **Tính năng 5: Báo động Tụt Pin Sáng Dậy (Morning Drain Alert & Budget)**:
  - Tự động kiểm tra mức hao pin của phiên ngủ vừa kết thúc.
  - Nếu pin tụt vượt quá hạn mức an toàn (mặc định: ≥ 3%), MacNAP bắn ngay thông báo hệ thống kèm số liệu chi tiết. Nhấp vào thông báo sẽ mở Dashboard phân tích tức thì.
- **Tích hợp giao diện quản lý**:
  - Bổ sung toggle bật/tắt và picker chọn ngưỡng cảnh báo linh hoạt trong cả Sidebar Dashboard và cửa sổ Cài đặt (`SettingsView.swift`).

### [14:12] fix(remount): direct hardware lid detection, 2-stage wake remount & rewrite concise README
- **Sửa triệt để lỗi không tự động wake/remount ổ đĩa ngoại vi (`AppState.swift` & `SleepMountGuardService.swift`)**:
  - Chuyển sang đọc trực tiếp phần cứng `AppleClamshellState` (`isClamshellClosed()`), khắc phục lỗi máy cắm sạc bị gán `AppleClamshellCausesSleep = No` khiến app bỏ qua sự kiện gập/mở nắp.
  - Bổ sung `mountWholeDisk` (`diskutil mountDisk`) đánh thức controller trước khi mount từng phân vùng.
  - Tích hợp cơ chế remount 2 đợt (tức thì + đệm 1.5s) đảm bảo USB Hub và ổ SSD ngoại vi luôn được kết nối lại 100%.
- **Chặn đứng việc cửa sổ Cài đặt tự động nhảy ra khi mở app (`MacNAPApp.swift`)**:
  - Vô hiệu hóa `NSQuitAlwaysKeepsWindows`, chuyển sang quản lý cửa sổ Settings độc lập qua AppKit, app khởi động hoàn toàn im lặng trên Menu Bar.
- **Tối ưu hóa tiêu điểm Menu Bar đỉnh màn hình**:
  - `activateAppWithRegularPolicy()` kích hoạt `makeMain()` và `setActivationPolicy(.regular)` giúp Menu Bar chuyển ngay về `MacNAP` khi mở Dashboard.
- **Viết lại `README.md` & `README_EN.md`**:
  - Giản lược toàn bộ văn phong quảng cáo, tập trung đúng câu chuyện và 3 tính năng cốt lõi: Auto-Unmount khi sleep, Auto-Remount khi wake, và Chặn DarkWake.

### [14:02] feat(app-menu): native macOS application menu bar & in-dashboard Settings button
- **Hiển thị Menu Bar hệ thống trên đỉnh macOS (`setupAppMainMenu` trong `MacNAPApp.swift`)**:
  - Tích hợp `NSMenu` chuẩn macOS khi ứng dụng active: `MacNAP`, `Cửa sổ (Window)`, `Trợ giúp (Help)`.
  - Hỗ trợ đầy đủ phím tắt macOS: `⌘,` (Cài đặt), `⌘D` (Dashboard), `⌘W` (Đóng cửa sổ), `⌘M` (Thu nhỏ), `⌘H` (Ẩn app), `⌘Q` (Thoát app).
- **Thêm lối vào Cài đặt trực tiếp trên Dashboard (`DashboardView.swift` & `AppState.swift`)**:
  - Bổ sung nút **`Cài đặt (⌘,)`** với icon bánh răng nổi bật ngay tại thanh Toolbar trên cùng của Dashboard.
  - Thêm mục **`Cài đặt & Tùy chọn`** vào danh sách Sidebar Navigation, cho phép xem và điều chỉnh thiết lập ngay trong Dashboard.

### [13:56] feat(settings): replace blank Settings window with native tabbed MacNAPSettingsView & guarantee crash-proof chart domain
- **Khắc phục cửa sổ trống `MacNAP Settings` (`SettingsView.swift` & `MacNAPApp.swift`)**:
  - Thay thế `EmptyView()` bên trong SwiftUI `Settings` scene bằng giao diện Cài đặt native macOS chuyên nghiệp (`SettingsView`) với 4 tabs:
    1. **Chung (General)**: Khởi động cùng macOS (`LaunchAtLogin`), Ẩn icon trên Dock khi đóng Dashboard, Ngôn ngữ giao diện (Tiếng Việt / English).
    2. **Sleep & Ổ đĩa**: Tự động Unmount khi Sleep/Gập nắp, Tự động Remount khi mở máy, Chặn DarkWake hao pin qua đêm trên Pin.
    3. **Cập nhật (Updates)**: Tự động kiểm tra bản mới từ GitHub Releases, Tự động cài đặt bản cập nhật, Nút kiểm tra cập nhật thủ công.
    4. **Giới thiệu & Tác giả (About)**: Thông tin phiên bản, bản quyền Tác giả Huỳnh Tuấn Huy (@tuanhuydev), nút Báo lỗi GitHub và nút Ủng hộ Tác giả (VietQR).
  - Tích hợp nút mở Cài đặt (`Cài đặt (⌘,)`) trực tiếp ở góc chân `MenuBarPopoverView`.
  - Cập nhật chính sách Dock: Nhận diện khi cửa sổ Settings đang mở để hiển thị icon và tự động thu hồi biến mất ngay khi đóng cửa sổ Settings.
- **Bảo vệ biểu đồ toán học tuyệt đối (`DashboardView.swift`)**:
  - Ép `safeMinBat = min(calcMin, max(0, calcMax - 1))` và `safeMaxBat = max(calcMax, safeMinBat + 1)` đảm bảo 100% không bao giờ gặp lỗi `Range requires lowerBound <= upperBound`.

### [13:47] fix(ui): synchronize actual drain pill and dropdown labels strictly with By Session and By Day modes
- **Đồng bộ hóa nhãn và số liệu thẻ "Thực tế" theo đúng ngữ cảnh lựa chọn (`DashboardView.swift`)**:
  - Khi xem **`Theo lần Sleep / CloseLid`**:
    - Nhãn chọn: `Phiên ngủ:`
    - Thẻ thực tế: **`Thực tế lần ngủ này`** (hiển thị đúng số pin đầu - cuối của phiên ngủ đó, ví dụ `100% → 80% (-20%)`).
    - Các thẻ kịch bản: `Bật Auto-Unmount (Lần này)` và `Toàn diện (Lần này)`.
  - Khi xem **`Theo Ngày (Từ 00:00)`**:
    - Nhãn chọn: `Ngày phân tích:`
    - Thẻ thực tế: **`Thực tế trong ngày (từ 00:00)`** (hiển thị mức tụt tính riêng từ `00:00:00` sáng của ngày đó đến lúc thức giấc).
    - Các thẻ kịch bản: `Bật Auto-Unmount (Trong ngày)` và `Toàn diện (Trong ngày)`.
  - Phản ánh trung thực nếu phiên không tụt pin hoặc cắm sạc (ví dụ: `90% (0%)` hoặc `+10%`).

### [13:43] feat: Release v1.0.1 with crash auto-relaunch watchdog & instant Dock icon cleanup on window close
- **Cơ chế Tự động Hồi sinh sau Crash (`Crash Auto-Relaunch Watchdog` trong `AppDiagnosticLogger.swift`)**:
  - Tích hợp 2 lớp cứu hộ chống crash:
    1. **Signal & Exception Handler trực tiếp**: Bẫy toàn bộ fatal signal (`SIGSEGV`, `SIGBUS`, `SIGABRT`, `SIGILL`, `SIGTRAP`) và ngoại lệ unhandled NSException, ghi log đầy đủ stacktrace và ngay lập tức gọi tiến trình cứu hộ độc lập khởi động lại MacNAP.
    2. **Watchdog Daemon nền độc lập (`spawnCrashWatchdogDaemon`)**: Giám sát PID tiến trình MacNAP. Nếu PID biến mất trong khi file khóa `.macnap-running.lock` vẫn còn (chứng minh bị crash hoặc kill đột ngột, không phải người dùng bấm Thoát), daemon sẽ tự động mở lại app sau 0.8s.
    3. **Chống lặp vô tận (Anti-Crash Loop)**: Tự động đếm số lần crash trong 25 giây. Nếu app crash liên tiếp > 3 lần, daemon tự ngắt để bảo vệ CPU và pin MacBook.
- **Khắc phục triệt để lỗi "App close nhưng icon vẫn còn ở Dock" (`MacNAPApp.swift`)**:
  - Khi người dùng đóng cửa sổ Dashboard (bấm nút đỏ, nhấn `Cmd+W`, hoặc bấm ra ngoài), ứng dụng tự động kiểm tra và chuyển ngay `activationPolicy` về `.accessory`.
  - macOS lập tức thu hồi và xóa icon MacNAP khỏi thanh Dock ngay trong tích tắc, giữ cho Dock luôn gọn gàng đúng chuẩn Menu Bar Utility.
- **Nâng cấp phiên bản chính thức `v1.0.1` (Build 101)**:
  - Cập nhật `VERSION`, `scripts/bundle.sh`, `releases/latest.json`, `README.md`, `README_EN.md`.
  - Đóng gói đầy đủ `releases/MacNAP-v1.0.1.dmg` và `releases/MacNAP-v1.0.1.zip`.

### [13:36] fix(chart): resolve Range crash lowerBound <= upperBound, isolate clean sleep sessions & fix By Day / By Session filter
- **Khắc phục triệt để lỗi Crash SIGTRAP / Range crash (`Range requires lowerBound <= upperBound`)**:
  - Tính toán `safeMin` và `safeMax` dựa trên toàn bộ các mốc pin thực tế `session.events.map(\.batteryPercent)` kết hợp với `startBattery` và `endBattery`.
  - Luôn đảm bảo `minBat < maxBat` trong `.chartYScale(domain: minBat...maxBat)` ngay cả khi máy cắm sạc hoặc pin tăng/bằng nhau, chấm dứt hoàn toàn hiện tượng văng app khi chuyển phiên ngủ.
- **Sửa thuật toán gom phiên ngủ, chấm dứt nối dữ liệu ảo khi cắm sạc trưa hôm sau (`SleepMountGuardService.swift`)**:
  - Một phiên ngủ **kết thúc dứt điểm ngay khi xuất hiện sự kiện `FullWake`** (mở máy thức giấc buổi sáng).
  - Tách rời hoàn toàn giấc ngủ qua đêm (`27/10 22:51 → 28/10 09:25`, tụt thật từ 100% xuống 80% `-20%`) khỏi các sự kiện cắm sạc buổi trưa (`12:11 → 12:21`, 90%). Không còn đường kẻ chéo ảo vọt từ 80% lên 90%.
  - Chỉ vẽ các đường nét đứt dự đoán mô phỏng khi phiên thực sự có sụt pin (`dropPercent >= 2`).
- **Sửa bộ chuyển đổi `Theo lần Sleep` vs `Theo Ngày (Từ 00:00)` (`AppState.swift`)**:
  - Khi người dùng bấm chuyển chế độ, tự động chọn ngay phiên đầu tiên của danh sách mới (`forceFirst: true`) và cập nhật biểu đồ tức thì.
  - Chế độ `Theo Ngày` lọc chính xác các sự kiện bắt đầu từ `00:00` sáng cho đến lúc mở máy thức dậy của ngày đó.

### [13:24] fix: robust in-app updater with remote GitHub download, bulletproof VietQR EMVCo generator & high-contrast donate UI
- **Khắc phục và hoàn thiện bộ Updater tự động tải từ GitHub (`AppUpdaterService`)**:
  - Hỗ trợ tải trực tiếp tệp `.zip` bản mới từ GitHub Releases qua `URLSession.shared.download(from:)`, tự động giải nén và thay thế `MacNAP.app` ở bất kỳ thư mục nào (`/Applications` hoặc workspace), sau đó khởi động lại app mượt mà.
  - Kiểm tra song song GitHub Releases API (`api.github.com/repos/lucifer208/MacNAP/releases/latest`) và Raw Manifest.
- **Tạo bộ mã hóa VietQR EMVCo chuẩn NAPAS247 (`VietQRHelper` trong `AppUpdateAndDonateService.swift`)**:
  - Tích hợp hàm sinh chuỗi EMVCo NAPAS247 chính thống (BIN 970432 VPBank, STK 8888071992, CRC-16/CCITT-FALSE), hiển thị ngay lập tức không độ trễ, đảm bảo 100% app ngân hàng quét được ngay cả khi ngoại tuyến (offline).
  - Tải bất đồng bộ ảnh VietQR chính thức từ `img.vietqr.io` qua `NSImage(data:)` giải mã chuẩn SVG/PNG sắc nét trên macOS Sonoma/Sequoia.
  - Tăng độ tương phản cực đại cho STK `8888071992`, hỗ trợ sao chép 1 chạm và chọn bôi đen text.
- **Tối ưu báo cáo lỗi GitHub Issues (`ReportIssueSheetView`)**:
  - Tự động copy toàn bộ log chẩn đoán vào bộ nhớ tạm trước khi mở trang tạo Issue trên GitHub với query rút gọn an toàn chống tràn URL.

### [13:16] docs: add English documentation README_EN.md with bilingual switcher
- **Bổ sung tài liệu tiếng Anh hoàn chỉnh `README_EN.md`**:
  - Hỗ trợ nút chuyển đổi nhanh đa ngôn ngữ `[🇻🇳 Tiếng Việt](README.md) • [🇬🇧 English](README_EN.md)` ở đầu cả 2 tệp.
  - Diễn giải chi tiết bằng tiếng Anh chuẩn quốc tế về cơ chế tiết kiệm pin, 1.0s power telemetry, 140W fast charge profiling, sleep assertions, hướng dẫn cài đặt file DMG và đóng gói SPM.

### [13:13] feat(release): add comprehensive README.md, package source zip & release via DMG
- **Khởi tạo tài liệu dự án `README.md` chuyên nghiệp**:
  - Giới thiệu chi tiết giải pháp trị dứt điểm chứng tụt pin qua đêm cho MacBook khi dùng ổ cứng ngoài, hub và dock Thunderbolt.
  - Bảng tổng hợp tính năng (Auto-Unmount/Remount, Telemetry 1.0s, Apple SMC, Hardware Profiling 140W, Wake Blocker Detection, GitHub Updater & Issues, VietQR VPBank).
  - Hướng dẫn cài đặt chi tiết qua file `.dmg` (kéo thả `/Applications`) và `.zip`.
  - Hướng dẫn build từ mã nguồn với Swift Package Manager.
  - Sơ đồ cấu trúc cây thư mục mã nguồn và thông tin tác giả Huỳnh Tuấn Huy (`@lucifer208`).
- **Tạo giấy phép mã nguồn `LICENSE` (MIT License)**.
- **Nâng cấp kịch bản đóng gói `scripts/bundle.sh`**:
  - Tạo bộ cài đặt đĩa ảnh macOS DMG: `releases/MacNAP-v1.0.0.dmg` (kèm symlink kéo thả tiện lợi vào `/Applications`) và `releases/MacNAP.dmg`.
  - Đóng gói toàn bộ mã nguồn sạch: `releases/MacNAP-v1.0.0-source.zip` và `releases/MacNAP-source.zip`.
  - Cập nhật thông tin tải tệp trong `releases/latest.json`.

### [13:10] fix(ui): redesign MenuBar popover footer with equal-width action buttons and dedicated quit bar
- **Thiết kế lại toàn bộ cụm 4 nút chân trang MenuBar (`MenuBarPopoverView.swift`)**:
  - Khắc phục triệt để hiện tượng chữ bị ép xuống 2 dòng (`Cập \n nhật`) do thiếu không gian ngang:
    - **Hàng 1**: Chia đều thành 3 nút bấm chức năng chuẩn kích thước cân xứng (`[🔄 Cập nhật]`, `[❤️ Ủng hộ]`, `[🐞 Báo lỗi]`) sử dụng `maxWidth: .infinity`, bo góc mềm mại kèm viền nhẹ màu chủ đề, khoá `.fixedSize()` và `.lineLimit(1)` chống vỡ giao diện.
    - **Hàng 2**: Thanh trạng thái đáy tách biệt với số hiệu phiên bản `MacNAP v1.0.0` dạng monospaced tinh tế bên trái và nút `⏻ Thoát MacNAP` bên phải với màu đỏ dịu mắt.
  - Tăng độ rộng popover lên `355pt` cho không gian thoáng, bố cục chuẩn macOS native.

### [13:04] feat: pre-fill GitHub Issues report with markdown diagnostics & trigger live GitHub update check in Report modal
- **Tự động mở và điền sẵn nội dung lên GitHub Issues (`ReportIssueSheetView` trong `AppUpdateAndDonateService.swift`)**:
  - Nhấn nút **"Mở GitHub Issues & Tự điền sẵn log"** sẽ mã hoá toàn bộ tiêu đề và nội dung markdown chẩn đoán (phiên bản, đời máy MacBook, macOS, công suất, ngoại vi, tiến trình chặn sleep, trích xuất log) trực tiếp vào query URL GitHub `https://github.com/lucifer208/MacNAP/issues/new?title=...&body=...`, trình duyệt mở lên là nội dung đã nằm sẵn trong khung tạo Issue.
- **Đồng thời kích hoạt kiểm tra cập nhật trên GitHub (`AppUpdaterService`)**:
  - Ngay khi mở cửa sổ Báo cáo lỗi, app tự động gửi truy vấn kiểm tra phiên bản mới nhất từ GitHub Releases API (`api.github.com/repos/lucifer208/MacNAP/releases/latest`).
  - Hiển thị ngay banner trạng thái cập nhật trên đầu cửa sổ: Thông báo nếu đã có bản cập nhật mới kèm nút "Cập nhật ngay", giúp người dùng thử bản vá mới nhất trước khi gửi báo cáo.

### [12:57] fix: clean Donate modal UI & pills layout, format VND currency, load real VietQR image from VietQR server & configure GitHub URL
- **Sửa triệt để giao diện Modal Donate & Nút mức tiền (`DonateSheetView` trong `AppUpdateAndDonateService.swift`)**:
  - Tách chữ và emoji (`30.000đ ☕️`, `50.000đ 🍜`, `100.000đ 🚀`, `200.000đ 💎`, `Tuỳ tâm ❤️`) thành `HStack` cố định `.fixedSize()` và `.lineLimit(1)`, chấm dứt hoàn toàn hiện tượng icon nhảy xuống dòng 2 làm xấu nút.
  - Định dạng số tiền chuẩn tiếng Việt (`formatVND`): `30.000 đ`, `50.000 đ`, `100.000 đ`, `200.000 đ` (không còn dấu phẩy kiểu Mỹ `50,000đ`).
  - Mở rộng chiều rộng cửa sổ lên `630pt` giúp các ô thông tin tài khoản to rõ, thoáng đãng.
- **Tải ảnh mã VietQR thực tế chuẩn EMVCo từ máy chủ VietQR (`AsyncImage`)**:
  - Sử dụng `AsyncImage` nạp trực tiếp mã QR chính thức từ hệ thống VietQR (`img.vietqr.io`), đảm bảo mọi ứng dụng ngân hàng (VPBank, Vietcombank, Techcombank, MB, MoMo...) quét là nhận diện ngay STK `8888071992`, tên `HUỲNH TUẤN HUY` và số tiền chính xác 100%.
- **Cập nhật đường dẫn GitHub chính thức của dự án**:
  - Gán chuẩn `https://github.com/lucifer208/MacNAP` (Releases, Issues, Raw manifest).

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
