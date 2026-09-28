# GOM — UI/UX Redesign Specification

**Sản phẩm:** Delivery Copy (PowerShell 5.1 + WPF)  
**Phạm vi:** Thiết kế lại giao diện và luồng tương tác. Giữ nguyên nghiệp vụ copy file, so sánh Git, kiểm tra hash, manifest và SQL*Plus hiện có.  
**Ngôn ngữ giao diện:** English ASCII only. Tài liệu spec dùng tiếng Việt.

### Quyết định encoding

App chạy bằng Windows PowerShell 5.1 và đọc XAML/script từ file. Không dùng tiếng Việt hoặc ký tự Unicode có dấu trong XAML, PowerShell string, tooltip, status, manifest text hay label hiển thị. Lý do: PowerShell 5.1 có thể đọc file UTF-8 không BOM theo ANSI code page, dẫn đến lỗi dấu tiếng Việt trên máy người dùng. Dùng English ASCII cho UI để giữ tính portable. Nếu sau này bắt buộc Việt hóa, phải làm một thay đổi kỹ thuật riêng: chuẩn hóa UTF-8 with BOM và chỉ định Encoding UTF8 tại mọi điểm đọc file.

---

## 1. Mục tiêu

Người dùng cần tạo một gói bàn giao phần mềm nhanh, biết rõ mình đang ở bước nào, đã chọn bao nhiêu file, sắp copy đi đâu và kết quả ra sao.

Giao diện phải ưu tiên bảng danh sách file. Không để phần cấu hình, mô tả hoặc thống kê lấn át khu vực người dùng dùng nhiều nhất.

### Nguyên tắc ưu tiên: mặc định tối giản

Thiết kế cho người dùng không cần hiểu Git, SHA-256, manifest hay SQL*Plus để giao file thông thường. Khi mở app lần đầu, chỉ hiển thị:

- Tên ứng dụng.
- Một câu hướng dẫn ngắn: Chọn file hoặc thư mục, sau đó kiểm tra trước khi bàn giao.
- Nút Chọn file.
- Nút Chọn thư mục.
- Link hoặc expander Tùy chọn nâng cao.

Git, nhập danh sách đường dẫn, exclude rule, SHA-256 và SQL*Plus nằm trong Tùy chọn nâng cao, đóng mặc định. Chỉ hiện SQL khi danh sách đang có file SQL. Không hiển thị input kỹ thuật trống, checkbox kỹ thuật hay thuật ngữ kỹ thuật ở trạng thái mở app lần đầu.

### Tiêu chí thành công

- Với luồng thường, người dùng có thể chọn file → rà soát → giao hàng mà không cần đọc một đoạn hướng dẫn dài.
- Ở màn **Rà soát**, bảng file chiếm ít nhất 60% chiều cao vùng nội dung khi cửa sổ 1180 × 780.
- Không hiển thị cấu hình Git hoặc SQL nếu người dùng không chọn dùng tính năng đó.
- Câu chữ ngắn, nêu rõ hành động và hệ quả: ví dụ `So sánh thay đổi`, `Thêm thư mục`, `Bỏ chọn`, `Bắt đầu bàn giao`.
- Font, độ tương phản, cỡ chữ và trạng thái disabled phải đọc rõ trên Windows 10/11, độ scale 100% và 125%.

---

## 2. Review bản hiện tại

| Khu vực | Quan sát từ bản hiện tại | Ảnh hưởng | Yêu cầu sửa |
|---|---|---|---|
| Thanh bước | Tab `1. Collect / 2. Review / 3. Deliver` trông giống tab nội dung, không cho biết bước nào đủ điều kiện đi tiếp. | Người dùng không biết cần làm gì để mở bước 3. | Dùng thanh bước ngang, có trạng thái `Đang làm`, `Hoàn thành`, `Chưa sẵn sàng`. |
| Màn Thu thập | Ba thẻ lớn: nguồn, Git, thêm tay. Git chiếm ngang hàng với thao tác thường dù không phải ai cũng dùng. | Màn đầu dài, phải cuộn và khó biết bắt đầu ở đâu. | Một thao tác chính `Chọn file/thư mục`; Git là vùng mở rộng gập lại. |
| Nhãn input | `Source and filters` và ô exclude không có nhãn rõ ràng; ý nghĩa phải đọc ToolTip. | ToolTip không thể là nguồn giải thích chính. | Có label trên từng trường và dòng mô tả ngắn dưới các trường khó. |
| Màn Rà soát | Bốn ô thống kê lớn và thẻ dán danh sách chiếm nhiều chiều cao; bảng file còn ít chỗ. | Danh sách file là đối tượng chính nhưng bị thu nhỏ. | Gom thống kê thành một dòng nhỏ; đưa dán danh sách vào nút mở panel hoặc expander. |
| Bảng file | Cột đường dẫn nguồn quá dài, trạng thái bằng badge màu nhỏ, không có tìm kiếm/lọc. | Khó tìm file, khó quét lỗi, chữ và màu làm mỏi mắt. | Có tìm kiếm, lọc, cột tên file rõ; màu trạng thái kèm chữ; giới hạn cột theo mục đích. |
| Chọn/bỏ file | `Select all`, `Clear selection`, `Remove selected` dùng từ dễ lẫn: selected có thể là hàng đang focus hoặc checkbox. | Có nguy cơ xoá sai file. | Dùng duy nhất khái niệm `Đã chọn để bàn giao`: `Chọn tất cả`, `Bỏ chọn tất cả`, `Xóa file đã chọn`. Xác nhận trước khi xóa. |
| Ô dán file | Tự import sau 450 ms khi người dùng gõ/dán. | Dễ thêm nhầm khi dán dữ liệu nhiều cột hoặc đang sửa nội dung. | Chỉ xử lý sau nút `Thêm đường dẫn`; báo rõ số thêm được và đường dẫn không hợp lệ. |
| Màn Bàn giao | Destination, option copy, SQL*Plus và tiến trình xuất hiện đồng thời. | Phần phụ che phần quyết định chính: nơi nhận và nút bắt đầu. | Gộp nơi nhận và tóm tắt ở trên; `Tùy chọn nâng cao` gập lại; SQL chỉ hiện khi có file `.sql` được chọn. |
| Copy chữ | Nhiều câu mô tả tiếng Anh dài; nút có ký tự `▣`, `↻`, `⇄`, `▶`, `↗` lẫn lộn. | Khó quét và icon ký tự hiển thị không ổn định theo font Windows. | Toàn bộ câu chữ tiếng Việt; icon dùng Segoe Fluent Icons hoặc bỏ icon nếu không có bộ icon thống nhất. |
| Typography | Tiêu đề thẻ 20 px xuất hiện dày, data grid 33 px/hàng, màu xám phụ #4B5563 và #9CA3AF dùng lẫn lộn. | Mật độ thấp, danh sách chữ cảm giác to nhưng lại thiếu độ rõ. | Dùng thang chữ và token màu thống nhất ở mục 6. |

### Nhận định cần giữ

Bản hiện tại đã có luồng nghiệp vụ ba bước hợp lý và các chức năng quan trọng: Git compare, thêm folder/file, dán path, hash, manifest, cancel. Spec này không yêu cầu thêm màn hình hay biến nó thành dashboard.

---

## 3. Kiến trúc thông tin và luồng chính

### 3.1 Thanh bước cố định

Đặt dưới header, cao 44 px, luôn hiển thị.

| Bước | Tên hiển thị | Điều kiện |
|---|---|---|
| 1 | `Chọn file` | Luôn truy cập được |
| 2 | `Rà soát (n)` | Có ít nhất một file trong danh sách; `n` là số file được chọn để bàn giao |
| 3 | `Bàn giao` | Có ít nhất một file được chọn |

- Bước hiện tại: nền xanh nhạt, số bước xanh đậm.
- Bước hoàn thành: dấu tick nhỏ, vẫn bấm quay lại được.
- Bước chưa sẵn sàng: màu trung tính, tooltip giải thích điều kiện.
- Không dùng TabControl theo kiểu tab tài liệu; dùng control điều hướng stepper, nhưng vẫn cho phép click bước hợp lệ.

### 3.2 Luồng mặc định: chọn tay

1. Người dùng bấm `Chọn file` hoặc `Chọn thư mục`.
2. File được thêm và tự chuyển tới **Rà soát**.
3. Người dùng tìm/lọc, tick hoặc bỏ tick file.
4. Bấm `Tiếp tục`.
5. Chọn thư mục nhận, kiểm tra tóm tắt, bấm `Bắt đầu bàn giao`.
6. Xem kết quả, mở thư mục nhận hoặc manifest.

### 3.3 Luồng tùy chọn: Git

1. Người dùng mở `Lấy file từ so sánh Git`.
2. Chọn repository → bấm `Tải nhánh` → chọn nhánh gốc và nhánh so sánh.
3. Bấm `Thêm thay đổi vào danh sách`.
4. Chuyển tới **Rà soát**.

Không bắt người dùng hiểu `fetch --all --prune` để làm tác vụ này. Dòng phụ: `Cập nhật danh sách nhánh từ remote trước khi so sánh. Không đổi nhánh hiện tại.`

---

## 4. Đặc tả từng màn

## 4.1 Header chung

**Mục đích:** nhận diện công cụ và báo trạng thái ngắn.

- Bên trái: `Delivery Copy`, phụ đề `Tạo gói bàn giao từ file hoặc thay đổi Git`.
- Bên phải: một chip trạng thái rộng tối đa 240 px.
  - `Sẵn sàng`
  - `Đang quét file…`
  - `Đã thêm 18 file`
  - `Đang bàn giao 7/18 file`
  - `Hoàn tất · 16 copied · 2 skipped`
- Trạng thái lỗi phải có màu đỏ và câu hành động: `Không tìm thấy thư mục nguồn. Chọn lại thư mục.`
- Không hiển thị footer mô tả kỹ thuật thường trực. Chuyển thông tin `PowerShell 5.1`/`Git` vào About hoặc tooltip của biểu tượng trợ giúp.

## 4.2 Bước 1 — Chọn file

### Bố cục

Một cột chính, rộng tối đa 880 px; không chia thẻ lớn khi chưa cần.

1. Tiêu đề: `Chọn file để bàn giao`
2. Dòng phụ: `Chọn file hoặc thư mục, sau đó kiểm tra trước khi bàn giao.`
3. Hai nút hành động chính cùng hàng:
   - `Chọn file` — mở OpenFileDialog nhiều file.
   - `Chọn thư mục` — quét đệ quy theo rule loại trừ.
4. Link button: `Tùy chọn nâng cao` — đóng mặc định.
5. Trong vùng nâng cao: `Dán danh sách đường dẫn`, `Lấy file từ so sánh Git`, `Tùy chỉnh file loại trừ`.

Không hiển thị input trống, checkbox kỹ thuật, Git hoặc rule exclude trước khi người dùng mở vùng này.

### Hành vi

- Khi chọn thư mục: hiển thị progress bar mảnh ngay dưới `Chọn thư mục`, dòng `Đang quét…`, disable nút quét lặp.
- Khi hoàn tất: trạng thái `Đã thêm X file` và tự chuyển bước 2.
- Nếu file trùng: không thêm lại; báo `Bỏ qua 3 file đã có trong danh sách`.
- Dán path phải có textarea cao 96 px và nút `Thêm đường dẫn`; không tự chạy theo TextChanged.
- Sau nhập, hiển thị kết quả rõ: `Đã thêm 12 file · 2 đường dẫn không hợp lệ`. Có link `Xem lỗi` để mở danh sách lỗi.

### Vùng Git mở rộng

- Nhãn trường: `Thư mục repository`, `Nhánh gốc`, `Nhánh so sánh`.
- Nút phụ: `Tải nhánh`; nút chính: `Thêm thay đổi vào danh sách`.
- Checkbox: `Bao gồm thay đổi chưa commit`.
- Khi chưa chọn repository, hai combobox nhánh và nút thêm thay đổi disabled; dòng giải thích hiển thị ngay bên dưới.

## 4.3 Bước 2 — Rà soát

### Bố cục

Đây là màn ưu tiên danh sách, không dùng nhiều card.

**Toolbar trên cùng, một hàng:**

- Trái: `Rà soát file` và text phụ `Chỉ file đã tick mới được bàn giao.`
- Kế bên: `18 file · 14 đã chọn · 6.4 MB · 3 SQL` bằng text nhỏ 13 px, không dùng bốn số lớn.
- Phải: ô tìm kiếm `Tìm theo tên hoặc đường dẫn`; dropdown `Tất cả / Đã chọn / Chưa chọn / SQL / Có lỗi`.

**Bảng file:** chiếm phần còn lại.

| Cột | Rộng | Nội dung | Quy tắc |
|---|---:|---|---|
| Checkbox | 42 px | Chọn để bàn giao | Header checkbox chọn/bỏ tất cả file đang lọc; hiện confirm khi thao tác ảnh hưởng >100 file. |
| Tên file | 28% | Tên + dòng phụ thư mục nguồn rút gọn | Tên 13 px SemiBold, đường dẫn 11 px muted. |
| Đường dẫn trong gói | 38% | Relative path | Tooltip đầy đủ khi bị cắt. |
| Loại | 76 px | `SQL`, `DLL`, `Config`… | Có thể suy từ extension, ẩn nếu chưa cần. |
| Dung lượng | 90 px | 1.2 MB | Căn phải. |
| Trạng thái | 120 px | `Sẵn sàng`, `Đã copy`, `Bỏ qua`, `Lỗi` | Không chỉ biểu thị bằng màu. |

- Chiều cao hàng: 42 px; header: 34 px.
- Không dùng badge bo tròn đậm trong từng hàng khi trạng thái `Sẵn sàng`; chỉ dùng text xám. Badge nhẹ chỉ cho `Lỗi`, `Đã copy`, `Bỏ qua`.
- Đường dẫn nguồn đầy đủ có tooltip hoặc panel chi tiết bên phải khi chọn một hàng; không dành một cột lớn cho absolute path.

**Thanh hành động dưới bảng:**

- Trái: `Chọn tất cả`, `Bỏ chọn tất cả`, `Xóa file đã chọn`.
- Phải: `Tiếp tục (14 file)`.
- `Xóa file đã chọn` là destructive secondary, cần confirm `Xóa 14 file khỏi danh sách? File gốc không bị xóa.`
- Panel `Dán danh sách đường dẫn` chỉ mở khi bấm `Thêm đường dẫn`, không chiếm không gian thường trực.

## 4.4 Bước 3 — Bàn giao

### Bố cục

Hai vùng, cùng trên một màn, tối đa hai thẻ.

**A. Tóm tắt và điểm đến**

- Tiêu đề: `Bàn giao 14 file · 6.4 MB`.
- Input `Thư mục nhận` + nút `Chọn thư mục`.
- Khi hợp lệ, hiển thị đường dẫn theo style read-only rõ ràng.
- Link `Quay lại rà soát`.

**B. Tùy chọn và hành động**

- Mặc định chỉ có:
  - `Nếu trùng tên file`: combobox `Bỏ qua / Ghi đè / Tự đổi tên`.
  - checkbox `Kiểm tra SHA-256 sau khi copy` (mặc định bật).
- Expander `Tùy chọn SQL` chỉ hiện khi có SQL file được chọn.
  - Checkbox `Tạo runscript.sql` (mặc định tắt).
  - Khi bật mới hiện `Thiết lập SQL*Plus`.
  - Dòng mô tả: `Script không lưu mật khẩu. SQL*Plus sẽ hỏi khi chạy.`
- Khu vực cuối: Progress bar, trạng thái hiện tại, nút chính `Bắt đầu bàn giao`, nút `Hủy` khi đang chạy.

### Sau khi hoàn tất

Hiển thị result panel thay cho form hành động:

- Icon trạng thái: xanh/vàng/đỏ.
- Tiêu đề: `Đã bàn giao` hoặc `Bàn giao hoàn tất có lỗi`.
- Số liệu: `14 copied · 2 skipped · 1 failed`.
- Các nút: `Mở thư mục nhận`, `Mở manifest`, `Quay lại rà soát`.
- Nếu lỗi: nút `Xem file lỗi` lọc bảng Review theo lỗi.

---

## 5. Hành vi và trạng thái bắt buộc

| Tình huống | Yêu cầu UI |
|---|---|
| Chưa có file | Bước Rà soát và Bàn giao disabled, tooltip giải thích. |
| Có file nhưng chưa tick | Bước Bàn giao disabled; nút `Tiếp tục` disabled. |
| Đang quét/copy | Khoá các hành động thay đổi danh sách hoặc điểm đến; hiển thị thao tác đang chạy và nút Hủy nếu backend hỗ trợ. |
| Không có file SQL | Ẩn hoàn toàn phần SQL; không hiển thị `Configure SQL*Plus`. |
| Đích trùng/không hợp lệ | Nêu lỗi cạnh trường destination, không chỉ MessageBox. |
| Chọn Ghi đè | Trước khi chạy, dialog xác nhận nêu số file đích đang tồn tại nếu biết được. |
| Giao xong | Bảng Review cập nhật trạng thái, manifest có thể mở được trực tiếp. |
| Lọc bảng | Tóm tắt `đã chọn` luôn tính toàn bộ danh sách, không chỉ những hàng đang lọc. |

---

## 6. Design system WPF

### 6.1 Kích thước và typography

Dùng `Segoe UI` hoặc `Segoe UI Variable` với fallback `Segoe UI`.

| Thành phần | Cỡ | Weight | Màu |
|---|---:|---|---|
| Tên ứng dụng | 22 px | SemiBold | #17263C |
| Tiêu đề màn | 18 px | SemiBold | #17263C |
| Tiêu đề section | 15–16 px | SemiBold | #17263C |
| Body / label / button | 13 px | Regular / SemiBold cho label | #28384D |
| Đường dẫn phụ / hint | 11–12 px | Regular | #5D6B7E |
| Header bảng | 11 px | SemiBold | #5D6B7E |
| Số liệu tóm tắt | 13 px | SemiBold | #28384D |

Không dùng title 20 px cho mọi card. Không dùng body dưới 11 px. Không dùng icon ký tự trang trí lẫn trong nhãn nút.

### 6.2 Màu và tương phản

| Token | Giá trị | Dùng cho |
|---|---|---|
| `Surface` | #FFFFFF | Nền thẻ/bảng |
| `Canvas` | #F5F7FA | Nền cửa sổ |
| `TextPrimary` | #17263C | Text chính |
| `TextSecondary` | #5D6B7E | Hint/đường dẫn phụ |
| `Border` | #D7DFE9 | Viền, separator |
| `Primary` | #1463D6 | CTA/focus |
| `Success` | #16794A | Thành công |
| `Warning` | #A96500 | Bỏ qua/cảnh báo |
| `Danger` | #B42318 | Lỗi/thao tác xóa |

- Không dùng màu như tín hiệu duy nhất. Luôn kèm text/icon có nghĩa.
- Hover, focus và disabled có trạng thái riêng; disabled phải đọc được, không chỉ giảm opacity đến mức mờ.

### 6.3 Spacing và khung

- Grid hệ 8 px: 8 / 12 / 16 / 24 / 32.
- Padding thẻ: 16–20 px; khoảng giữa section: 16 px.
- Border radius: 8 px cho input/button, 10–12 px cho thẻ.
- Shadow rất nhẹ hoặc không dùng; đường viền đủ để phân tách. Không kết hợp border đậm và shadow rõ trên mọi thẻ.
- Cửa sổ mặc định 1180 × 780; nội dung không yêu cầu cuộn dọc ở màn Rà soát khi danh sách có ít file.

---

## 7. Những chức năng UI cần bổ sung

Đây là yêu cầu UX. Không đổi cách Core thực hiện nghiệp vụ nếu không cần thiết.

1. Search và filter danh sách file.
2. Panel nhập đường dẫn có nút xử lý rõ ràng; trả về số hợp lệ/lỗi.
3. Header checkbox chọn/bỏ chọn theo filter và hành động clear/xóa có xác nhận.
4. Hiển thị empty state và filtered-empty state khác nhau.
5. Kết quả bàn giao có số copied/skipped/failed, nút mở manifest.
6. Trạng thái disabled có lời giải thích gần control.
7. Hiện/ẩn phần Git, exclude rule và SQL theo ngữ cảnh.
8. Bản tiếng Việt hoàn chỉnh, không trộn lẫn các nhãn tiếng Anh trong UI.

---

## 8. Acceptance criteria cho Codex

Codex chỉ hoàn thành khi tất cả điều kiện dưới đây đạt được.

- [ ] Không sửa `Core.FileOps.ps1`, `Core.Git.ps1`, `Core.SqlPlus.ps1` trừ khi UI mới thực sự cần một tham số/hàm hiển thị mà chưa có.
- [ ] Giữ nguyên các khả năng: thêm file, quét folder, Git compare, đường dẫn paste, exclude, duplicate mode, hash, SQL runscript, cancel, CSV manifest.
- [ ] Bước 1 hiển thị chọn file/thư mục là hành động chính; Git và exclude thu gọn mặc định.
- [ ] Bước 2 có search, filter, bảng file chiếm phần lớn chiều cao, text và cột như mục 4.3.
- [ ] Không còn tự import khi người dùng nhập/paste nội dung.
- [ ] Bước 3 chỉ hiển thị SQL option khi có `.sql` đang chọn; `runscript.sql` mặc định tắt.
- [ ] Sau copy có nút `Mở manifest` và kết quả copied/skipped/failed.
- [ ] Tất cả text UI bằng tiếng Việt; dùng nhất quán thuật ngữ `file đã chọn để bàn giao`.
- [ ] Kiểm tra trên Windows PowerShell 5.1/WPF: mở app, chọn file, bỏ chọn/chọn lại, filter, giao một file vào thư mục tạm, tạo manifest, cancel.
- [ ] Kiểm tra UI ở 100% và 125% scaling: không cắt nút, không tràn label, bảng vẫn có ít nhất 5 hàng nhìn thấy.

---

## 9. Prompt triển khai cho Codex

> Hãy thiết kế lại UI/UX của ứng dụng WPF PowerShell Delivery Copy theo toàn bộ file spec này. Đây là một refactor giao diện và interaction flow, không phải viết lại nghiệp vụ. Giữ API và khả năng của các core module hiện có. Ưu tiên màn Rà soát file: bảng file phải chiếm đa số vùng hiển thị, có search/filter, hành động chọn/bỏ chọn rõ và không dùng trạng thái màu đơn lẻ. Dùng tiếng Việt cho toàn bộ giao diện. Chỉ thay đổi Core khi UI không thể thực hiện yêu cầu bằng layer App/XAML. Chạy smoke test trên Windows PowerShell 5.1/WPF sau khi làm xong.

## 10. Quyết định cuối cùng để giữ app gọn

Các điều kiện ở mục này có độ ưu tiên cao hơn khi Codex phải lựa chọn giữa nhiều phương án thiết kế.

- Luồng mặc định chỉ có: Chọn file hoặc thư mục → Rà soát → Bàn giao.
- Trạng thái mở app lần đầu không hiển thị Git, dán path, exclude, hash, SQL, manifest, dashboard, KPI card hoặc input cấu hình.
- Git, dán path và exclude nằm trong một Tùy chọn nâng cao ở bước Chọn file.
- Hash và SQL nằm trong Tùy chọn nâng cao ở bước Bàn giao. SQL chỉ hiện khi có SQL file.
- Không có card thống kê lớn. Chỉ dùng một dòng tóm tắt nhỏ cạnh tiêu đề bảng.
- Không có mô tả dài dưới từng nhóm. Mỗi khu vực chỉ có một câu hướng dẫn khi câu đó giúp người dùng quyết định hành động.
- Không dùng icon ký tự Unicode như mũi tên, refresh, play hoặc folder trong nhãn nút. Nếu chưa có bộ icon WPF nhất quán, dùng text thuần.
- Không thêm chức năng mới ngoài search/filter bảng, phản hồi rõ khi nhập path, confirmation cho xóa/ghi đè, và mở manifest sau khi giao.

### Acceptance criteria bổ sung

- [ ] Ở lần mở đầu, người dùng nhìn thấy tối đa: tên app, một câu hướng dẫn, hai nút chọn file/thư mục và Tùy chọn nâng cao.
- [ ] Một người dùng không biết Git vẫn có thể hoàn tất bàn giao file thường mà không bắt gặp thuật ngữ Git, SHA-256 hoặc SQL*Plus.
- [ ] Màn Rà soát không cần cuộn dọc để thấy tiêu đề, toolbar, tối thiểu năm dòng file và nút Tiếp tục ở kích thước 1180 × 780.
- [ ] Mọi action có rủi ro chỉ có một tên rõ nghĩa: Xóa file đã chọn và Ghi đè file có xác nhận trước khi chạy.

### Quy tắc text UI có độ ưu tiên cao hơn

Mọi nhãn, button, tooltip, status, dialog và thông báo thực thi trong app dùng English ASCII only. Các ví dụ tiếng Việt ở phần mô tả luồng chỉ giải thích ý nghĩa cho người đọc spec; Codex phải chuyển chúng thành English ASCII ngắn gọn khi code.

Bảng mapping bắt buộc:


| Ý nghĩa | Text UI |
|---|---|
| Chọn file | Select files |
| Chọn thư mục | Select folder |
| Tùy chọn nâng cao | Advanced options |
| Rà soát file | Review files |
| Bàn giao | Deliver |
| Thêm thay đổi Git | Add Git changes |
| Bắt đầu bàn giao | Start delivery |
| Bỏ chọn tất cả | Clear selection |
| Xóa file đã chọn | Remove selected files |
| Mở manifest | Open manifest |
| Thư mục nhận | Destination folder |
| Đang quét file | Scanning files... |
| Đang bàn giao | Delivering... |
