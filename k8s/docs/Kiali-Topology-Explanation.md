# Giải Thích Kiali Topology - Spring PetClinic Service Mesh

## Mục Lục
- [Tổng Quan Topology](#tổng-quan-topology)
- [Các Microservices](#các-microservices)
- [Node Badges - Ý Nghĩa và Cấu Hình](#node-badges---ý-nghĩa-và-cấu-hình)
- [Ý Nghĩa Màu Sắc](#ý-nghĩa-màu-sắc)
- [Tổng Kết Badges Trong Dự Án](#tổng-kết-badges-trong-dự-án)
- [Lưu Ý Về Mũi Tên Đỏ](#lưu-ý-về-mũi-tên-đỏ-discovery-server)
- [Luồng Traffic](#luồng-traffic)

---

## Tổng Quan Topology

| Thông tin | Giá trị |
|-----------|---------|
| **Namespace** | `petclinic` |
| **Số lượng Apps** | 7 apps (7 versions) |
| **Số lượng Services** | 4 services |
| **Số lượng Edges** | 19 edges (kết nối) |

---

## Các Microservices

| Service | Port | Vai trò |
|---------|------|---------|
| **api-gateway** | 8080 | Entry point - Nhận requests từ bên ngoài, route đến backend |
| **customers-service** | 8081 | Quản lý khách hàng và thú cưng (pets) |
| **visits-service** | 8082 | Quản lý lịch hẹn khám |
| **vets-service** | 8083 | Quản lý bác sĩ thú y |
| **genai-service** | 8084 | AI Service |
| **config-server** | 8888 | Spring Cloud Config - cung cấp configuration tập trung |
| **discovery-server** | 8761 | Eureka Service Registry - đăng ký và khám phá services |

---

## Node Badges - Ý Nghĩa và Cấu Hình

### ⚡ Circuit Breaker (Ngắt mạch)

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | Bảo vệ service khỏi quá tải bằng cách **giới hạn số connections và requests**. Khi vượt ngưỡng, requests mới bị từ chối (503) thay vì làm sập service |
| **Mục đích** | Ngăn chặn hiệu ứng cascading failure - khi 1 service chậm, không kéo theo toàn bộ hệ thống sập |
| **File cấu hình** | `k8s/istio/destination-rules.yaml` |
| **Có trong dự án** | ✅ CÓ (6/7 services) |

**Cấu hình:**
```yaml
connectionPool:
  tcp:
    maxConnections: 100           # Tối đa 100 TCP connections
  http:
    http1MaxPendingRequests: 100  # Tối đa 100 requests trong queue
    http2MaxRequests: 1000        # Tối đa 1000 concurrent HTTP/2 requests
```

---

### 🚫 Fault Injection (Tiêm lỗi)

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Cố ý tạo lỗi** (delay hoặc abort) để test khả năng chịu lỗi của hệ thống |
| **Mục đích** | Chaos engineering - kiểm tra hệ thống có hoạt động đúng khi có lỗi xảy ra |
| **File cấu hình** | `k8s/istio/virtual-services.yaml` → `fault` |
| **Có trong dự án** | ❌ KHÔNG (chỉ dùng khi testing) |

**Ví dụ cấu hình (không áp dụng trong production):**
```yaml
spec:
  http:
  - fault:
      delay:
        percentage:
          value: 10              # 10% requests bị delay
        fixedDelay: 5s           # Delay 5 giây
      abort:
        percentage:
          value: 5               # 5% requests bị abort
        httpStatus: 503          # Trả về 503
```

---

### 🌐 Gateway

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Điểm vào/ra của mesh**, xử lý traffic từ bên ngoài Kubernetes cluster |
| **Mục đích** | Quản lý ingress/egress traffic, TLS termination, routing |
| **File cấu hình** | Istio Gateway resource |
| **Có trong dự án** | ⚠️ Sử dụng Spring Cloud Gateway (api-gateway), không phải Istio Gateway |

---

### 🔀 Mirroring (Traffic Mirroring/Shadowing)

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Sao chép traffic** đến một service khác để testing mà không ảnh hưởng production |
| **Mục đích** | Test version mới với real traffic mà không có risk |
| **File cấu hình** | `k8s/istio/virtual-services.yaml` → `mirror` |
| **Có trong dự án** | ❌ KHÔNG |

**Ví dụ cấu hình:**
```yaml
spec:
  http:
  - route:
    - destination:
        host: customers-service
        subset: v1
    mirror:
      host: customers-service
      subset: v2              # Mirror traffic đến v2
    mirrorPercentage:
      value: 100              # 100% traffic được mirror
```

---

### 📦❌ Missing Sidecar

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | Pod **không có Istio sidecar** (istio-proxy), không nằm trong service mesh |
| **Mục đích** | Cảnh báo pod không được Istio quản lý (không có mTLS, không có observability) |
| **Kiểm tra** | Pods phải có READY 2/2 (app + istio-proxy) |
| **Có trong dự án** | ❌ KHÔNG xuất hiện (tất cả pods có sidecar ✅) |

**Kiểm tra sidecar:**
```bash
# Pods có 2/2 containers = có sidecar
kubectl get pods -n petclinic
# NAME                 READY   STATUS
# api-gateway-xxx      2/2     Running  ← có sidecar ✅
```

---

### ⏱️ Request Timeout

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Giới hạn thời gian chờ** response từ service. Quá timeout → request fail |
| **Mục đích** | Tránh request treo vô hạn, giải phóng resources nhanh chóng |
| **File cấu hình** | `k8s/istio/virtual-services.yaml` |
| **Có trong dự án** | ✅ CÓ |

**Cấu hình:**
```yaml
timeout: 10s              # Timeout tổng: 10 giây
retries:
  attempts: 3             # Retry 3 lần
  perTryTimeout: 3s       # Timeout mỗi lần: 3 giây
  retryOn: 5xx,reset,connect-failure,retriable-4xx
```

**Chi tiết cấu hình từng service:**

| Service | Timeout | Retry | Per-Retry |
|---------|---------|-------|-----------|
| customers-service | 10s | 3x | 3s |
| visits-service | 10s | 3x | 3s |
| vets-service | 10s | 3x | 3s |
| genai-service | **30s** | 3x | **10s** |
| config-server | 10s | **5x** | 3s |
| discovery-server | 10s | **5x** | 3s |
| api-gateway | **30s** | 3x | **10s** |

---

### 📊 Traffic Shifting / TCP Traffic Shifting

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Chia traffic** giữa các versions khác nhau của service |
| **Mục đích** | Canary deployment, A/B testing, Blue-Green deployment |
| **File cấu hình** | `k8s/istio/virtual-services.yaml` → `route.weight` |
| **Có trong dự án** | ❌ KHÔNG (chỉ có 1 version - v1) |

**Ví dụ cấu hình Canary deployment:**
```yaml
spec:
  http:
  - route:
    - destination:
        host: customers-service
        subset: v1
      weight: 90              # 90% traffic đến v1
    - destination:
        host: customers-service
        subset: v2
      weight: 10              # 10% traffic đến v2 (canary)
```

---

### ➡️ Traffic Source

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | **Nguồn gốc traffic** - node này là điểm bắt đầu của traffic flow |
| **Mục đích** | Xác định entry point của hệ thống |
| **Có trong dự án** | ✅ CÓ - `api-gateway` là traffic source |

---

### 🔀 Virtual Service / Request Routing

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | Có **VirtualService** được áp dụng (routing rules, retry, timeout, fault injection) |
| **Mục đích** | Kiểm soát cách traffic được route đến service |
| **File cấu hình** | `k8s/istio/virtual-services.yaml` |
| **Có trong dự án** | ✅ CÓ (7/7 services) |

---

### 💻 Workload Entry

| Thuộc tính | Chi tiết |
|------------|----------|
| **Ý nghĩa** | Service chạy **bên ngoài Kubernetes** nhưng được thêm vào mesh |
| **Mục đích** | Tích hợp VMs, external databases, legacy systems vào service mesh |
| **Có trong dự án** | ❌ KHÔNG (tất cả chạy trong K8s) |

**Ví dụ cấu hình:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: external-db
spec:
  address: 192.168.1.100       # IP của external service
  ports:
    mysql: 3306
  labels:
    app: external-database
```

---

## Ý Nghĩa Màu Sắc

### Màu Node

| Màu | Ý nghĩa |
|-----|---------|
| 🟢 **Xanh lá** | Healthy - Service hoạt động bình thường |
| 🟡 **Vàng** | Warning - Có vấn đề nhẹ |
| 🔴 **Đỏ** | Error - Có lỗi xảy ra |

### Màu Edge (Mũi tên)

| Màu | Ý nghĩa |
|-----|---------|
| 🟢 **Xanh** | 100% success rate |
| 🔴 **Đỏ** | Có errors (4xx/5xx) |
| ⚫ **Xám** | Không có traffic |

### Labels trên Edge

| Label | Ý nghĩa |
|-------|---------|
| `0.03 rps` | Requests Per Second - số request mỗi giây |
| `0.00 err` | Error rate - tỷ lệ lỗi |
| `50.00 err` | 50% requests bị lỗi |

---

## Tổng Kết Badges Trong Dự Án

| Service | ⚡ Circuit Breaker | ⏱️ Timeout | 🔀 VirtualService | ➡️ Source |
|---------|-------------------|------------|-------------------|-----------|
| api-gateway | ✅ | ✅ 30s | ✅ | ✅ |
| customers-service | ✅ | ✅ 10s | ✅ | - |
| visits-service | ✅ | ✅ 10s | ✅ | - |
| vets-service | ✅ | ✅ 10s | ✅ | - |
| genai-service | ✅ | ✅ 30s | ✅ | - |
| config-server | ✅ | ✅ 10s | ✅ | - |
| discovery-server | ❌ | ✅ 10s | ✅ | - |

### Tổng hợp các badges:

| Badge | Icon | Có trong dự án? | File cấu hình |
|-------|------|-----------------|---------------|
| **Circuit Breaker** | ⚡ | ✅ CÓ (6/7 services) | `destination-rules.yaml` → `connectionPool` |
| Fault Injection | 🚫 | ❌ KHÔNG | - |
| Gateway | 🌐 | ⚠️ Spring Cloud Gateway | - |
| Mirroring | 🔀 | ❌ KHÔNG | - |
| Missing Sidecar | 📦❌ | ❌ KHÔNG (tất cả có sidecar) | - |
| **Request Timeout** | ⏱️ | ✅ CÓ | `virtual-services.yaml` → `timeout` |
| Traffic Shifting | 📊 | ❌ KHÔNG | - |
| **Traffic Source** | ➡️ | ✅ CÓ (api-gateway) | Auto-detected |
| **Virtual Service** | 🔀 | ✅ CÓ | `virtual-services.yaml` |
| Workload Entry | 💻 | ❌ KHÔNG | - |

---

## Lưu Ý Về Mũi Tên Đỏ (Discovery-Server)

| Vấn đề | Chi tiết |
|--------|----------|
| **Hiện tượng** | ~50% error rate đến discovery-server trong Kiali |
| **Nguyên nhân** | Apache HttpClient 5.x gửi header `Upgrade: h2c`, Istio từ chối → 403 upgrade_failed |
| **Ảnh hưởng thực tế** | ❌ Kiali hiển thị đỏ (cosmetic issue) |
| | ✅ mTLS vẫn hoạt động bình thường |
| | ✅ Authorization Policy vẫn hoạt động |
| | ✅ Service discovery vẫn hoạt động |
| **Giải pháp** | Known issue - chấp nhận và giải thích trong báo cáo |

---

## Luồng Traffic

Dựa trên cấu hình trong các file YAML (`k8s/deployments/*.yaml` và `k8s/istio/authorization-policies.yaml`):

### Sơ đồ luồng traffic chi tiết

```
                              External User
                                    │
                                    ▼
                           ┌────────────────┐
                           │  api-gateway   │ ← Entry Point (LoadBalancer)
                           │   (⚡⏱️🔀)     │
                           └───────┬────────┘
                                   │ mTLS 🔒
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│customers-service│    │  visits-service │    │   vets-service  │
│    (⚡⏱️🔀)     │    │    (⚡⏱️🔀)     │    │    (⚡⏱️🔀)     │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         │                      │                      │
         │                      │                      │     ┌─────────────────┐
         │                      │                      │     │  genai-service  │
         │                      │                      │     │    (⚡⏱️🔀)     │
         │                      │                      │     └────────┬────────┘
         │                      │                      │              │
         └──────────────────────┴──────────────────────┴──────────────┘
                                       │
                   ┌───────────────────┴───────────────────┐
                   │ mTLS 🔒  (Tất cả services đều gọi)    │
                   ▼                                       ▼
          ┌─────────────────┐                    ┌─────────────────┐
          │  config-server  │                    │ discovery-server│
          │    (⚡⏱️🔀)     │                    │     (⏱️🔀)      │
          │    :8888        │                    │     :8761       │
          └─────────────────┘                    └─────────────────┘
                  │                                       │
                  └───────────────┬───────────────────────┘
                                  │
                                  ▼
                          PassthroughCluster
                        (External traffic)
```

### Chi tiết các kết nối (dựa trên YAML)

| Từ Service | Đến Service | Mục đích | File cấu hình |
|------------|-------------|----------|---------------|
| **External** | api-gateway | Entry point | `api-gateway.yaml` (LoadBalancer) |
| api-gateway | customers-service | Route requests | `authorization-policies.yaml` |
| api-gateway | visits-service | Route requests | `authorization-policies.yaml` |
| api-gateway | vets-service | Route requests | `authorization-policies.yaml` |
| api-gateway | genai-service | Route requests | `authorization-policies.yaml` |
| **Tất cả services** | config-server | Lấy configuration | `SPRING_CLOUD_CONFIG_URI` trong mỗi deployment |
| **Tất cả services** | discovery-server | Đăng ký/Discovery | `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` trong mỗi deployment |

### Environment Variables trong Deployments

Mỗi service đều có 2 environment variables quan trọng:

```yaml
# Trong tất cả deployment YAML files
env:
- name: SPRING_CLOUD_CONFIG_URI
  value: "http://config-server:8888"          # ← Connect to Config Server
- name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
  value: "http://discovery-server:8761/eureka" # ← Connect to Discovery Server
```

### Authorization Policies (ai được phép gọi ai)

| Policy | Target Service | Cho phép từ | Methods |
|--------|----------------|-------------|---------|
| `deny-all` | Tất cả | ❌ Block all (default) | - |
| `allow-api-gateway-to-services` | customers-service | petclinic namespace | GET, POST, PUT, DELETE |
| `allow-api-gateway-to-visits` | visits-service | petclinic namespace | GET, POST, PUT, DELETE |
| `allow-api-gateway-to-vets` | vets-service | petclinic namespace | GET, POST, PUT, DELETE |
| `allow-api-gateway-to-genai` | genai-service | petclinic namespace | GET, POST, PUT, DELETE |
| `allow-config-server-access` | config-server | petclinic namespace | GET only |
| `allow-discovery-server-access` | discovery-server | petclinic namespace | GET, POST, PUT, DELETE |
| `allow-ingress-to-gateway` | api-gateway | istio-system, petclinic, external | GET, POST, PUT, DELETE |

**Chú thích icon:**
- ⚡ = Circuit Breaker (connectionPool trong DestinationRule)
- ⏱️ = Request Timeout (VirtualService)
- 🔀 = Virtual Service / Request Routing
- 🔒 = mTLS enabled (PeerAuthentication + DestinationRule)

---

**Author:** A (Khánh Duy)  
**Date:** 04/01/2026  
**Version:** 1.0
