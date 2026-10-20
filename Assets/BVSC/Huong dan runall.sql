-------------------B1: Yêu cầu môi trường trước khi thực hiện chạy script ------------------
yêu cầu:
- Tắt job xử lý lệnh
- Máy đã cài oracle client
- Máy đã cài NLS_LANG: UTF8

-------------------B2: Hướng dẫn đổi user DB-------------
- Trong file /cmd/setVariable.bat
- Sửa tên user/pass connect tới DB HOST
set HOST_USER=[USERNAME DB HOST]
set HOST_PASSW_USER=[PASSWORD]
set FLEX_TNSNAMES=[TNSNAMES]
- Lưu lại file setVariable.bat

-------------------B3: Click chạy file run_changeScript.bat(nếu có)-------------
Chạy ChangeScript (1 lần): /cmd/run_changeScript.bat

-------------------B4: Click chạy file runUpdate.bat-------------
Chạy file nâng cấp DB: /cmd/runUpdate.bat

-------------------B5: Kiểm tra log chạy script-------------
- Vào thư lục /log kiểm tra file log output