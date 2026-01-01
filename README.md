# Lab 2: Service Mesh & DevSecOps

## Thông tin nhóm
- **Deadline:** Chủ Nhật, 4/1/2026, 11:30 PM

## Phân công
| Thành viên | Vai trò | Trạng thái |
|------------|---------|------------|
| A (Khánh Duy) | Service Mesh (Istio, Kiali, mTLS, Authorization, Retry) | ✅ Hoàn thành |
| B (Giáp) | DevSecOps (SonarQube, Snyk, ZAP, GitLeaks) | 🔄 Đang thực hiện |
| C (Bá Duy) | Tài liệu, Test Plan, README, kiểm thử | 🔄 Đang thực hiện |

---

## Cấu trúc Project

```
lab2_devops/
├── k8s/                          # Kubernetes manifests (A - Service Mesh)
│   ├── namespace.yaml
│   ├── deployments/              # 7 microservices
│   ├── istio/                    # Istio configs (mTLS, AuthZ, Retry)
│   ├── scripts/                  # Install & test scripts
│   └── docs/                     # README & Test Plan
├── spring-petclinic-microservices/  # Source code
├── yeucau.txt                    # Yêu cầu bài lab
└── phancong.txt                  # Phân công công việc
```

---

## Phần 1: Service Mesh (A - Khánh Duy) ✅

### Đã hoàn thành
- [x] Cài đặt Istio v1.24.2 trên K8S
- [x] Cài đặt Kiali, Prometheus, Grafana, Jaeger
- [x] Deploy 7 PetClinic microservices
- [x] Cấu hình mTLS (PeerAuthentication STRICT)
- [x] Cấu hình AuthorizationPolicy (8 policies)
- [x] Cấu hình VirtualService với Retry (3-5 attempts)
- [x] Scripts cài đặt và test
- [x] Documentation (README + Test Plan)

### Hướng dẫn sử dụng

```bash
# 1. Khởi động minikube (nếu chưa có)
minikube start --driver=docker --cpus=4 --memory=8192

# 2. Cài Istio
cd k8s/scripts
./install-istio.sh

# 3. Cài Kiali
./install-kiali.sh

# 4. Deploy app
./deploy-app.sh

# 5. Chạy tests
./test-mtls.sh
./test-authorization.sh
./test-retry.sh

# 6. Mở Kiali
istioctl dashboard kiali
```

### Test Results
| Test | Status |
|------|--------|
| mTLS STRICT | ✅ PASS |
| Sidecar Injection | ✅ 7/7 pods |
| Authorization Policies | ✅ 8 policies |
| Retry VirtualServices | ✅ 7 services |

---

## Phần 2: DevSecOps (B - Giáp) 🔄

### Cần thực hiện
- [ ] Setup SonarQube
- [ ] Thêm SonarScanner vào Jenkins
- [ ] Cài Snyk CLI và integration
- [ ] OWASP ZAP baseline scan
- [ ] Git hooks với GitLeaks
- [ ] Thu thập reports (Sonar, Snyk, ZAP)

### Thư mục đề xuất
```
devops/
├── jenkins/
│   └── Jenkinsfile
├── sonarqube/
│   └── sonar-project.properties
├── snyk/
│   └── snyk-report.json
├── zap/
│   └── zap-report.html
└── hooks/
    └── pre-commit (gitleaks)
```

---

## Phần 3: Tài liệu (C - Bá Duy) 🔄

### Cần thực hiện
- [ ] Merge tài liệu A + B
- [ ] Viết Test Plan hoàn chỉnh
- [ ] Viết README hướng dẫn
- [ ] Tạo slide demo
- [ ] Chuẩn bị script demo (10-15 phút)

---

## Links
- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kiali Documentation](https://kiali.io/docs/)

---

## Notes cho team

> **A đã hoàn thành phần Service Mesh.** Các files trong `k8s/` đã sẵn sàng sử dụng.
> 
> B và C có thể clone repo này và tiếp tục phần DevSecOps và Tài liệu.
