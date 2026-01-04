# DevSecOps CI/CD với Spring Petclinic Microservices trên Jenkins để tự động  hóa SonarQube, Snyk, OWASP

## 1. Các bước đã thực hiện

### Prerequisite
- Đã cài docker desktop, mvn 
- Trong docker-compose.yml, thêm image của sonarqube, Jenkins, OWASP:
    ```sh
    sonarqube:
        image: sonarqube:lts
        container_name: sonarqube
        environment:
        - SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar
        - SONAR_JDBC_USERNAME=sonar
        - SONAR_JDBC_PASSWORD=sonar
        ports:
        - 9000:9000
        depends_on:
        - sonarqube-db

    sonarqube-db:
        image: postgres:15
        container_name: sonarqube-db
        environment:
        - POSTGRES_USER=sonar
        - POSTGRES_PASSWORD=sonar
        - POSTGRES_DB=sonar
        volumes:
        - sonarqube_db_data:/var/lib/postgresql/data

    jenkins:
        build:
        context: ./Jenkins
        container_name: jenkins
        ports:
        - 8085:8080
        - 50000:50000
        volumes:
        - jenkins_home:/var/jenkins_home
        - /var/run/docker.sock:/var/run/docker.sock

    owasp-zap:
        image: zaproxy/zap-stable
        container_name: owasp-zap
        entrypoint: ["tail", "-f", "/dev/null"]
        volumes:
        - ./zap-reports:/zap/wrk
        networks:
        - default

    volumes:
    sonarqube_db_data:
    jenkins_home:
   ```
- Tạo Jenkins folder:
    - Tạo Jenkinsfile, thêm stage cho checkout, build, SonarQube, Snyk, OWASP(chỉ scan spring-petclinic-api-gateway):
        ```sh
        pipeline {
            agent any
            environment {
                SONAR_PROJECT_KEY = 'spring-petclinic-microservices'
                SONAR_HOST_URL = 'http://sonarqube:9000'
                SONAR_TOKEN = credentials('SONAR_TOKEN_ID')
            }
            stages {
                stage('Checkout') {
                    steps {
                        checkout scm
                    }
                }
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
                        withCredentials([string(credentialsId: 'SNYK_TOKEN', variable: 'SNYK_TOKEN')]) {
                            sh 'snyk auth $SNYK_TOKEN'
                            sh 'snyk test --all-projects'
                        }
                    }
                }

                stage('OWASP ZAP Baseline Scan') {
            steps {
                sh '''
                    echo "=== Before scan ==="
                    ls -la
                    
                    docker run --rm --user 0 --network spring-petclinic-microservices_default \
                        -v $PWD:/zap/wrk:rw -t zaproxy/zap-stable zap-baseline.py \
                        -t http://api-gateway:8080 \
                        -r zap-report.html \
                        -I
                    
                    echo "=== After scan ==="
                    ls -la
                    
                    if [ -f zap-report.html ]; then
                        echo "Report found!"
                        cat zap-report.html | head -20
                    else
                        echo "Report NOT found!"
                    fi
                '''
                
                archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true
            }
        }
                // Thêm các stage khác nếu cần
            }
        }
        ```
    - Tạo Dockerfile:
        ```sh
        FROM jenkins/jenkins:lts
        USER root
        RUN apt-get update && \
            apt-get install -y npm docker.io git && \
            npm install -g snyk
        USER root
        ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
        ```
    


### 1.1. Triển khai Jenkins
- Chạy Jenkins bằng Docker Compose
- Truy cập Jenkins tại http://localhost:8085
- Tạo tài khoản Jenkins (admin/admin), tải các plugins khuyến khích, sẽ tải thêm các cần thiết ở khúc sau
### 1.2. Triển khai SonarQube 
- Chạy SonarQube-db, SonarQube bằng Docker Compose (cùng với các service khác).
- Truy cập SonarQube tại http://localhost:9000.
- Create new Project:
    - Chọn <>Manually
    - Nhập Project Display Name: spring-petclinic-microservices
    - Nhập Project Key: spring-petclinic-microservices
    - Nhập Main Branch Name: main hoặc branch tương ứng
    - Lưu 
    - How do you want to analyze your repository? Chọn Locally:
        - Step 1: Generate token with token  name. Ví dụ token: sqp_631e2bd6052e3d08843fe3ce1f2d276653516888
        - Step 2: Run analysis, chọn Maven (có thể bỏ qua vì có tự động trên Jenkins)


### 1.3. Tích hợp SonarScanner vào CI/CD trên giao diện Jenkins
- Install SonarQube Scanner:
    - Vào icon "Manage Jenkins"
    - Chọn Plugins
    - Chọn Available Plugins
    - Tìm kiếm SonarQube Scanner và install
- Configure credentials:
    - Vào icon "Manage Jenkins"
    - Chọn "Credentials"
    - Chọn "System" from Domain "global"
    - Chọn "Global credentials (unrestricted)"
    - Chọn "Add Credentials":
        - Kind: Secret text
        - Scope: Global(Jenkins, nodes, items, all child items, etc)
        - Secret: token from SonarQube đã tạo ở trên, ví dụ: sqp_631e2bd6052e3d08843fe3ce1f2d276653516888
        - ID: SONAR_TOKEN_ID
    - Chọn "Create"
- Tạo New Item:
    - Chọn "New Item" trên giao diện chính
    - Nhập "Item name", ví dụ: Devsecops
    - Select a item type: chọn Pipeline
    - Chọn "Save" để đến bước tiếp theo
    - Tại bước "General":
        - Triggers: Tick vào "GitHub hook trigger for GITScm polling"
        - Pileline:
            - Defination: Pipeline script from SCM
            - SCM: git
            - Repository URL: tên repo cần CI/CD
            - Credentials: add nếu cần (đối với repo yêu cầu quyền hoặc private)
            - Branch to build: branch tương ứng
            - Script Path :Jenkins/Jenkinsfile
            - Lưu ý: Không tick chọn Lightweight checkout
            - Chọn "Save"


### 1.4. Cài đặt và sử dụng Snyk CLI
- Cài Snyk CLI bằng npm: `npm install -g snyk`.
- Đăng nhập Snyk: `snyk auth`(dùng gmail hoặc github).
- Trên giao diện Snyk:
    - Chọn Account Settings
    - Xem Auth Token, ví dụ "0ee1cb71-7e16-4b94-835b-6392b035bb99"

### 1.5. Cấp Credentials cho SNYK
- Configure credentials:
    - Vào icon "Manage Jenkins"
    - Chọn "Credentials"
    - Chọn "System" from Domain "global"
    - Chọn "Global credentials (unrestricted)"
    - Chọn "Add Credentials":
        - Kind: Secret text
        - Scope: Global(Jenkins, nodes, items, all child items, etc)
        - Secret: Auth token from SNYK đã tạo ở trên, ví dụ: "0ee1cb71-7e16-4b94-835b-6392b035bb99"
        - ID: SNYK_TOKEN
    - Chọn "Create"

### 1.6. Cài đặt OWASP trên Jenkins
- Install ScannerHTML để xuất report:
    - Vào icon "Manage Jenkins"
    - Chọn Plugins
    - Chọn Available Plugins
    - Tìm kiếm HTML Publisher và install

## 2. Hướng dẫn public Jenkins docker để add vào webhooks trên repository
- Install ngrok: https://ngrok.com/download/windows và giải nén
- Đăng nhập vào ngrok và xác thực bằng Google Authentication
- Xem AuthToken tại: https://dashboard.ngrok.com/get-started/your-authtoken
- Mở terminal ở đường dẫn chứa ngrok.exe và double click để vào CMD
- Chạy xác thực
    ```sh
    ngrok config add-authtoken <authtoken>
    ```
- Sau khi xác thực thành công, public Jenkins docker ở port 8085:
    ```sh
    ngrok http 8085
    ```
- Xem phần forwarding có chứa public domain, ví dụ: "https://phantasmagoric-nonerodent-jamika.ngrok-free.dev"
- Khi đó URL của Webhook là: "https://phantasmagoric-nonerodent-jamika.ngrok-free.dev/github-webhook/"
## 3. Thêm webhook vào Github
- Vào repository Github
- Chọn Settings
- Chọn Webhooks
- Chọn Add webhook
- Ở mục Payload URL, dán:
    ```sh
    https://phantasmagoric-nonerodent-jamika.ngrok-free.dev/github-webhook/
    ```
- Content type: Chọn application/json
- Which events would you like to trigger this webhook? Chọn "Just the push event"
- Nhấn Add webhook
## 4. Thực hiện quy trình CI/CD trên Jenkins
- Chỉ cần commit mới là oke
- Đối với Snyk scan dependency có lỗ hổng, hãy thử thêm dependency có lỗ hổng vào file Pom trong spring-petclinic bất kì

## 5. Ouput
- Đối với SonarQube, truy cập: http://sonarqube:9000 để xem status và các thông báo
- Đối với SNYK, xem trên Console output của Jenkins
- Đối với OWASP report, xem trên Status của Jenkins, file name: zap-report.html
---
Tài liệu này giúp bạn hiểu toàn bộ quy trình DevSecOps đã thực hiện và cách vận hành lại từ đầu, cả tự động (Jenkins) lẫn thủ công (terminal).
