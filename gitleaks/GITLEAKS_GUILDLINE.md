# Hướng dẫn tạo pre-commit hook kiểm tra secret với Gitleaks (Docker)

## Mục đích
Tự động kiểm tra và chặn commit chứa secret (API key, password, token, ...) bằng Gitleaks trước khi code được đẩy lên Git.

## Bước 1: Tạo file pre-commit


### Đối với Linux/macOS:
Chạy lệnh sau trong thư mục gốc repo (nơi có thư mục `.git`):
```sh
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/sh
# .git/hooks/pre-commit

export MSYS_NO_PATHCONV=1

docker run --rm -v "$(pwd):/code" \
  ghcr.io/gitleaks/gitleaks:latest \
  detect --source="/code" --no-git --redact

if [ $? -eq 1 ]; then
  echo ""
  echo "Commit blocked - Secrets detected!"
  echo ""
  exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

### Đối với Windows:
#### Tạo file pre-commit bằng lệnh trong cmd

Nếu bạn đã cd vào đúng ổ đĩa chứa repo (ví dụ C: hoặc D:), có thể tạo file pre-commit bằng lệnh:

```cmd
echo #!/bin/sh > .git\hooks\pre-commit
```

Lưu ý: Lệnh echo chỉ ghi được một dòng. Nếu muốn thêm nhiều dòng, bạn có thể lặp lại với >> hoặc dùng Notepad như hướng dẫn phía trên để thuận tiện hơn.

Ví dụ thêm nhiều dòng:
```cmd
echo #!/bin/sh > .git\hooks\pre-commit
echo export MSYS_NO_PATHCONV=1 >> .git\hooks\pre-commit
echo docker run --rm -v "$(pwd):/code" ^>^> .git\hooks\pre-commit
```
Hoặc dùng Notepad để dán toàn bộ nội dung.
1. Để mở hoặc tạo file pre-commit, hãy làm như sau:
   - Mở Notepad, chọn File → Open, chuyển sang “All Files (*.*)” rồi chọn file `.git/hooks/pre-commit` (vì file này không có đuôi mở rộng nên mặc định sẽ không hiện ra nếu để kiểu *.txt).
   - Hoặc, mở nhanh bằng lệnh trong terminal:
     ```cmd
     notepad .git\hooks\pre-commit
     ```
2. Dán nội dung sau vào file (nếu tạo mới):
   ```sh
   #!/bin/sh
   # .git/hooks/pre-commit

   export MSYS_NO_PATHCONV=1

   docker run --rm -v "$(pwd):/code" \
     ghcr.io/gitleaks/gitleaks:latest \
     detect --source="/code" --no-git --redact

   if [ $? -eq 1 ]; then
     echo ""
     echo "Commit blocked - Secrets detected!"
     echo ""
     exit 1
   fi
   ```
3. Lưu file với tên `pre-commit` vào thư mục `.git/hooks/` trong repo của bạn (chọn All Files khi lưu để không bị thêm đuôi .txt).
4. Mở Git Bash hoặc WSL, chạy lệnh sau để cấp quyền thực thi:
   ```sh
   chmod +x .git/hooks/pre-commit
   ```

### Xem lại nội dung file pre-commit vừa tạo

Tùy hệ điều hành, sử dụng lệnh phù hợp để xem nội dung file:

- **Linux/macOS:**
  ```sh
  cat .git/hooks/pre-commit
  ```
- **Windows:**
  ```cmd
  type .git\hooks\pre-commit
  ```

## Bước 2: Đảm bảo Docker đã cài trên máy
- Nếu chưa có, tải tại: https://www.docker.com/products/docker-desktop

## Bước 3: Thử commit file chứa secret để kiểm tra

### Tạo file test chứa secret để kiểm tra hook

1. Tạo một file test, ví dụ test_secret.txt, với nội dung giả lập secret:
  ```
  password=123456
  api_key=abcdefg
  ```
2. Thêm file này vào git:
  ```sh
  git add test_secret.txt
  ```
3. Thử commit:
  ```sh
  git commit -m "test gitleaks hook"
  ```
4. Nếu pre-commit hook hoạt động, commit sẽ bị chặn và hiện thông báo:
   
  `Commit blocked - Secrets detected!`

## Lưu ý
- File pre-commit này chỉ chạy trên máy local, không chạy trên GitHub hoặc CI/CD.
- Có thể copy file này cho mọi repo Git để bảo vệ secret khi commit.
