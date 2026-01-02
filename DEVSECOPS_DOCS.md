# DevSecOps CI/CD với Spring Petclinic Microservices

## 1. Các bước đã thực hiện

### 1.1. Triển khai SonarQube
- Chạy SonarQube bằng Docker Compose (cùng với các service khác).
- Truy cập SonarQube tại http://localhost:9000.
- Tạo project và lấy project key, tạo token để xác thực.

### 1.2. Tích hợp SonarScanner vào CI/CD
- Thêm bước SonarQube Analysis vào Jenkinsfile:
    - Sử dụng biến môi trường cho project key, host url và token.
    - Jenkins sẽ tự động scan code và gửi kết quả lên SonarQube mỗi lần build pipeline.

### 1.3. Cài đặt và sử dụng Snyk CLI
- Cài Snyk CLI bằng npm: `npm install -g snyk`.
- Đăng nhập Snyk: `snyk auth`.
- Chạy quét dependency: `snyk test`.
- Kết quả: Không phát hiện lỗ hổng bảo mật trong dependency.

## 2. Hướng dẫn chạy lại toàn bộ quy trình

### 2.1. Khởi động các service
```sh
docker compose up -d
```
- Đảm bảo SonarQube chạy tại http://localhost:9000
- Jenkins chạy tại http://localhost:8081

### 2.2. Tạo project và token trên SonarQube
- Vào SonarQube, tạo project mới (nếu chưa có).
- Lấy project key và tạo token.

### 2.3. Cấu hình Jenkinsfile
- Đảm bảo Jenkinsfile có đoạn:
```groovy
pipeline {
    agent any
    environment {
        SONAR_PROJECT_KEY = 'spring-petclinic-microservices'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN = credentials('SONAR_TOKEN_ID')
    }
    stages {
        stage('Build') {
            steps {
                sh './mvnw clean install -DskipTests'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "./mvnw sonar:sonar -Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN}"
                }
            }
        }
        stage('Snyk Scan') {
            steps {
                sh 'snyk test'
            }
        }
    }
}
```
- Thêm SONAR_TOKEN_ID vào Jenkins Credentials (dạng Secret Text).

### 2.4. Build pipeline Jenkins
- Truy cập Jenkins, tạo job pipeline trỏ đến repo chứa Jenkinsfile.
- Nhấn "Build Now" hoặc cấu hình webhook để tự động build khi có code mới.
- Theo dõi log, kiểm tra các stage SonarQube Analysis và Snyk Scan.

### 2.5. Kiểm tra kết quả
- Vào SonarQube để xem báo cáo phân tích code.
- Xem log Jenkins hoặc output Snyk để kiểm tra kết quả quét dependency.

## 3. Chạy thủ công toàn bộ quy trình bằng terminal (không cần Jenkins)

### 3.1. Build, SonarQube scan:
```sh
./mvnw clean verify sonar:sonar -Dsonar.projectKey=spring-petclinic-microservices -Dsonar.host.url=http://localhost:9000 -Dsonar.login=<token>
```

### 3.2. Snyk scan:
```sh
snyk test
```

> Ví dụ thực tế:
> ```sh
> ./mvnw clean verify sonar:sonar -Dsonar.projectKey=spring-petclinic-microservices -Dsonar.host.url=http://localhost:9000 -Dsonar.login=sqp_12bd6201489f0f28640b4dd868ec49e71b02bf3b
> snyk test
> ```

---
Tài liệu này giúp bạn hiểu toàn bộ quy trình DevSecOps đã thực hiện và cách vận hành lại từ đầu, cả tự động (Jenkins) lẫn thủ công (terminal).
