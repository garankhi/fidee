# AGENTS.md — Hướng dẫn tối ưu UX cho AI agents

Tài liệu này ghi lại các quyết định kiến trúc quan trọng nhằm tránh các anti-pattern
gây trải nghiệm xấu (spinner trắng, màn hình trắng trống giữa các route).
Bất kỳ agent AI nào làm việc trên codebase này **phải đọc và tuân thủ** các nguyên tắc dưới đây.

---

## 0. Quy tắc làm việc bắt buộc cho AI agents

### Khi thông tin còn mơ hồ
- Luôn kiểm chứng những điểm mơ hồ bằng source code, config, tài liệu trong repo, hoặc tool phù hợp trước khi kết luận.
- Nếu không thể tự kiểm chứng an toàn, đặt câu hỏi ngắn gọn cho user trước khi implement.
- Khi có nhiều hướng giải quyết hợp lý, đưa ra best-practice recommendation trước, sau đó liệt kê các phương án thay thế với ưu và nhược điểm để user chọn đúng.

### Khi user yêu cầu lập plan
- Phải tạo một file `.md` trong `docs/superpowers/plans/` để user review, thay vì chỉ viết plan trong session chat.
- Sau khi tạo plan, phải tự kiểm tra lại plan có khớp yêu cầu không.
- Cuối file plan phải suggest nên tiến hành bằng in-session implementation hay subagent-driven implementation, kèm lý do ngắn gọn.
- Chỉ được implement plan sau khi user đồng ý rõ ràng.
- Sau khi implement xong, nên hỏi user có muốn xóa file plan để repo sạch hơn không.

### Code style
- Với Dart, JavaScript, TypeScript, TSX, và MJS: ưu tiên single quotes (`'...'`) thay vì double quotes (`"..."`).
- Không áp dụng rule này cho JSON, XML, plist, Android manifest, generated files, hoặc format bắt buộc dùng double quotes.
- Được dùng double quotes khi string chứa dấu `'` và double quotes giúp tránh escape rối.

---

## 1. Anti-pattern cần tránh: Spinner giữa SplashScreen và màn hình chính

### Vấn đề gốc
Trước khi refactor, luồng khởi động như sau:

```
SplashScreen (đỏ)
  → [auth resolve] → HomeScreen mount
                       → _isLoading = true (spinner trắng)
                       → _initLocation() chạy (GPS permission + getCurrentPosition ~10s)
                       → _isLoading = false
                       → Map hiển thị
```

Kết quả: user thấy **3 màn hình** thay vì 2.

### Giải pháp đã áp dụng (Phương án 1 + 3)

**Phương án 3 — Chạy song song:**
Khởi động tất cả async operations cần thiết cho màn hình đích **ngay từ lúc app start**,
song song với auth, không phải sau khi navigate.

**Phương án 1 — Giữ SplashScreen làm gate:**
SplashScreen không tắt cho đến khi **tất cả** providers cần thiết đã resolve.

```
SplashScreen (đỏ) — giữ cho đến khi auth + location đều done
  → HomeScreen mount với map sẵn sàng ngay lập tức
```

---

## 2. Pattern bắt buộc: Provider-gated Navigation

### Quy tắc
> Mọi async data mà màn hình đích cần **ngay từ frame đầu tiên** phải được
> khởi động dưới dạng Riverpod provider **keepAlive** và được watch ở `main.dart`.
> SplashScreen (hoặc màn hình gate tương đương) giữ nguyên cho đến khi provider resolve.

### Implementation hiện tại

**`auth_providers.dart`** — khai báo providers:
```dart
// Auth provider (đã có từ trước)
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AuthUiState> build() async {
    await service.initialize();   // Cognito token refresh
    return AuthUiState.fromService(service);
  }
}

// Location provider — chạy song song với auth
@Riverpod(keepAlive: true)
Future<LocationService> locationController(LocationControllerRef ref) async {
  final service = LocationService();
  await service.initialize();    // GPS permission + getCurrentPosition
  return service;
}
```

**`main.dart`** — watch cả hai, giữ SplashScreen:
```dart
Widget _buildHome(AsyncValue<AuthUiState> authState, AsyncValue<LocationService> locationState) {
  // Bất kỳ provider nào còn loading → giữ SplashScreen
  if (authState.isLoading || locationState.isLoading) {
    return const _SplashScreen();
  }
  // ... route theo authState.value
}
```

**`home_screen.dart`** — nhận service đã sẵn sàng, không tự init:
```dart
class HomeScreen extends ConsumerStatefulWidget {
  final LocationService locationService;  // truyền từ main.dart
  const HomeScreen({super.key, required this.locationService});
}

// initState: KHÔNG gọi _initLocation() hay bất kỳ async nào blocking render
@override
void initState() {
  super.initState();
  _locationService = widget.locationService;  // dùng thẳng
  _showLocationBanner = _locationService.status != LocationStatus.granted;
}
```

---

## 3. Pattern cho màn hình mới

Khi thêm một màn hình mới cần data async ngay từ frame đầu tiên:

### Checklist
- [ ] Tạo `@Riverpod(keepAlive: true)` provider cho async operation đó
- [ ] Watch provider trong `main.dart` (hoặc màn hình gate tương đương)
- [ ] Thêm `|| newProvider.isLoading` vào điều kiện giữ SplashScreen
- [ ] Truyền data/service đã resolve vào màn hình qua constructor parameter
- [ ] **Không** dùng `bool _isLoading = true` + spinner trong `build()` của màn hình đích
- [ ] **Không** gọi async operations trong `initState` nếu kết quả đó cần cho frame đầu tiên

### Template provider
```dart
// Trong auth_providers.dart hoặc file providers riêng
@Riverpod(keepAlive: true)
Future<MyService> myController(MyControllerRef ref) async {
  final service = MyService();
  await service.initialize();
  return service;
}
```

### Template main.dart
```dart
final myState = ref.watch(myControllerProvider);

Widget _buildHome(..., AsyncValue<MyService> myState) {
  if (authState.isLoading || locationState.isLoading || myState.isLoading) {
    return const _SplashScreen();
  }
  // ...
}
```

---

## 4. Skeleton thay cho Spinner toàn màn hình

Khi **không thể** pre-load trước SplashScreen (ví dụ: màn hình được navigate đến
sau user action, không phải từ cold start), thay thế `CircularProgressIndicator`
toàn màn hình bằng **skeleton** giữ nguyên layout.

### Tại sao
- Spinner trắng/đen toàn màn hình gây visual jump khi content load xong
- Skeleton giữ nguyên spatial memory → transition tự nhiên hơn

### Ví dụ: CameraScreen
```dart
// Thay vì:
if (!_controller!.value.isInitialized) {
  return Scaffold(body: Center(child: CircularProgressIndicator()));
}

// Dùng:
if (!_controller!.value.isInitialized) {
  return const Scaffold(
    backgroundColor: Colors.black,
    body: _CameraSkeleton(),   // skeleton giữ layout camera
  );
}
```

`_CameraSkeleton` render các placeholder có cùng kích thước và vị trí
với các phần tử thật (top bar, viewfinder square, bottom controls).

---

## 5. Các màn hình hiện tại và trạng thái

| Màn hình | Pattern | Ghi chú |
|---|---|---|
| `HomeScreen` | Provider-gated (pattern 2) | `locationService` truyền từ `main.dart` |
| `CameraScreen` | Skeleton (pattern 4) | Camera init không thể pre-load |
| `SendImageScreen` | Inline loading OK | `_locationString = 'Đang tải...'` là inline, không block render |
| `NearbyPlacesSheet` | Inline loading OK | Bottom sheet, spinner trong nội dung sheet là acceptable |
| Auth screens (Step3-5) | Không cần | Không có async blocking render |

---

## 6. Nguyên tắc chung

1. **SplashScreen là single loading gate** — tất cả async critical-path chạy ở đây,
   không phân tán vào từng màn hình.

2. **keepAlive = true** cho providers liên quan đến startup — tránh re-initialize
   khi user navigate back/forward.

3. **Constructor injection** — màn hình nhận data qua constructor, không tự fetch.
   Dễ test, dễ trace, không có race condition.

4. **Fallback graceful** — nếu provider lỗi (GPS denied, network timeout),
   dùng giá trị mặc định (`LocationService.defaultLocation = HCM City`) thay vì block.
   ```dart
   final locationService = locationState.valueOrNull ?? LocationService();
   ```

5. **Inline loading là OK** cho data không critical tại frame đầu tiên —
   ví dụ: weather, reverse geocoding trong `SendImageScreen` hiển thị
   `'Đang tải...'` inline mà không block render toàn màn hình.
