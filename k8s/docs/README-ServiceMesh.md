# Service Mesh với Istio cho Spring PetClinic Microservices

## Mục Lục
- [Tổng Quan](#tổng-quan)
- [Kiến Trúc](#kiến-trúc)
- [Prerequisites](#prerequisites)
- [Cài Đặt Istio](#cài-đặt-istio)
- [Cài Đặt Kiali](#cài-đặt-kiali)
- [Deploy Ứng Dụng](#deploy-ứng-dụng)
- [Cấu Hình Service Mesh](#cấu-hình-service-mesh)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Tổng Quan

Hướng dẫn này mô tả cách triển khai Service Mesh với Istio cho ứng dụng Spring PetClinic Microservices trên Kubernetes, bao gồm:

- **mTLS (Mutual TLS)**: Mã hóa traffic giữa các services
- **Authorization Policies**: Kiểm soát quyền truy cập service-to-service
- **Retry Policies**: Tự động retry khi có lỗi 5xx
- **Observability**: Visualize topology với Kiali

### Các Services trong PetClinic

| Service | Port | Mô tả |
|---------|------|-------|
| config-server | 8888 | Spring Cloud Config Server |
| discovery-server | 8761 | Eureka Service Discovery |
| api-gateway | 8080 | API Gateway (entry point) |
| customers-service | 8081 | Quản lý khách hàng và pets |
| visits-service | 8082 | Quản lý lịch hẹn |
| vets-service | 8083 | Quản lý bác sĩ thú y |
| genai-service | 8084 | AI Service |

---

## Kiến Trúc

```
┌──────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     NAMESPACE: petclinic                      │ │
│  │                  (istio-injection: enabled)                   │ │
│  │                                                               │ │
│  │  ┌─────────────┐                                             │ │
│  │  │ API Gateway │ ◄─────── Ingress Traffic                    │ │
│  │  │   :8080     │                                             │ │
│  │  └──────┬──────┘                                             │ │
│  │         │ mTLS                                               │ │
│  │         ▼                                                    │ │
│  │  ┌──────────────┬──────────────┬──────────────┐             │ │
│  │  │  Customers   │    Visits    │     Vets     │             │ │
│  │  │   Service    │   Service    │   Service    │             │ │
│  │  │    :8081     │    :8082     │    :8083     │             │ │
│  │  └──────┬───────┴──────┬───────┴──────┬───────┘             │ │
│  │         │              │              │                      │ │
│  │         └──────────────┼──────────────┘                      │ │
│  │                        │ mTLS                                │ │
│  │                        ▼                                     │ │
│  │  ┌──────────────┬──────────────┐                            │ │
│  │  │   Config     │  Discovery   │                            │ │
│  │  │   Server     │   Server     │                            │ │
│  │  │    :8888     │    :8761     │                            │ │
│  │  └──────────────┴──────────────┘                            │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   NAMESPACE: istio-system                     │ │
│  │  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐        │ │
│  │  │ Istiod  │  │  Kiali  │  │Prometheus│  │ Grafana │        │ │
│  │  └─────────┘  └─────────┘  └──────────┘  └─────────┘        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Yêu cầu hệ thống
- Kubernetes cluster (minikube, kind, hoặc cloud provider)
- kubectl v1.25+
- Tối thiểu 8GB RAM cho cluster
- Internet access để pull images

### Kiểm tra môi trường

```bash
# Kiểm tra minikube (nếu dùng minikube)
minikube status 
# Kiểm tra kubectl
kubectl version --client

# Kiểm tra kết nối cluster
kubectl cluster-info

# Kiểm tra nodes
kubectl get nodes
```

---

## Cài Đặt Istio

### Bước 1: Chạy script cài đặt

```bash
cd k8s/scripts
./install-istio.sh
```

Script sẽ thực hiện:
1. Download istioctl (nếu chưa có)
2. Cài đặt Istio với demo profile
3. Verify installation
4. Tạo namespace petclinic với istio-injection enabled

### Bước 2: Verify Istio

```bash
# Kiểm tra pods trong istio-system
kubectl get pods -n istio-system

# Kiểm tra services
kubectl get svc -n istio-system

# Kiểm tra Istio version
istioctl version
```

**Expected output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-xxx                1/1     Running   0          2m
istiod-xxx                              1/1     Running   0          2m
```

---

## Cài Đặt Kiali

### Bước 1: Chạy script cài đặt

```bash
cd k8s/scripts
./install-kiali.sh
```

Script sẽ cài đặt:
- Kiali Dashboard
- Prometheus (metrics)
- Grafana (dashboards)
- Jaeger (distributed tracing)

### Bước 2: Truy cập Kiali

```bash
# Sử dụng istioctl
istioctl dashboard kiali

# Hoặc port-forward thủ công
kubectl port-forward svc/kiali -n istio-system 20001:20001
```

Mở browser: http://localhost:20001

---

## Deploy Ứng Dụng

### Bước 1: Deploy PetClinic

```bash
cd k8s/scripts
./deploy-app.sh
```

Script sẽ:
1. Tạo namespace (nếu chưa có)
2. Deploy infrastructure services (config-server, discovery-server)
3. Deploy business services (customers, visits, vets, genai)
4. Deploy API Gateway
5. Apply tất cả Istio configurations

### Bước 2: Verify deployment

```bash
# Kiểm tra pods
kubectl get pods -n petclinic

# Kiểm tra mỗi pod có 2 containers (app + istio-proxy)
kubectl get pods -n petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Kiểm tra services
kubectl get svc -n petclinic
```

**Expected output:**
```
NAME                 READY   STATUS    RESTARTS   AGE
api-gateway-xxx      2/2     Running   0          5m
config-server-xxx    2/2     Running   0          7m
customers-service    2/2     Running   0          6m
discovery-server-xxx 2/2     Running   0          7m
vets-service-xxx     2/2     Running   0          6m
visits-service-xxx   2/2     Running   0          6m
```

### Bước 3: Truy cập ứng dụng

```bash
# Port-forward API Gateway
kubectl port-forward svc/api-gateway -n petclinic 8080:8080

# Mở browser
open http://localhost:8080
```

---

## Cấu Hình Service Mesh

### 1. mTLS (Mutual TLS)

**File:** `k8s/istio/peer-authentication.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: petclinic
spec:
  mtls:
    mode: STRICT  # Chỉ chấp nhận mTLS traffic
```

**Giải thích:**
- `STRICT`: Bắt buộc mTLS, từ chối plaintext
- `PERMISSIVE`: Chấp nhận cả mTLS và plaintext (migration mode)
- `DISABLE`: Tắt mTLS

**Apply:**
```bash
kubectl apply -f k8s/istio/peer-authentication.yaml
```

### 2. Destination Rules

**File:** `k8s/istio/destination-rules.yaml`

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: customers-service
  namespace: petclinic
spec:
  host: customers-service.petclinic.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

**Apply:**
```bash
kubectl apply -f k8s/istio/destination-rules.yaml
```

### 3. Authorization Policies

**File:** `k8s/istio/authorization-policies.yaml`

Các policies được định nghĩa:
- `deny-all`: Default deny tất cả traffic
- `allow-api-gateway-to-services`: Cho phép API Gateway gọi backend
- `allow-config-server-access`: Cho phép tất cả services truy cập Config Server
- `allow-discovery-server-access`: Cho phép tất cả services truy cập Discovery Server

**Apply:**
```bash
kubectl apply -f k8s/istio/authorization-policies.yaml
```

### 4. Virtual Services (Retry Policy)

**File:** `k8s/istio/virtual-services.yaml`

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: customers-service
  namespace: petclinic
spec:
  hosts:
  - customers-service
  http:
  - route:
    - destination:
        host: customers-service
        port:
          number: 8081
    timeout: 10s
    retries:
      attempts: 3           # Retry 3 lần
      perTryTimeout: 3s     # Timeout mỗi lần retry
      retryOn: 5xx,reset,connect-failure
```

**Apply:**
```bash
kubectl apply -f k8s/istio/virtual-services.yaml
```

---

## Testing

### Test mTLS

```bash
cd k8s/scripts
./test-mtls.sh
```

**Các test cases:**
1. Verify PeerAuthentication mode là STRICT
2. Verify tất cả pods có istio-proxy sidecar
3. Test connection giữa services (với mTLS)
4. Test plaintext rejection (pod không có sidecar bị từ chối)

### Test Authorization

```bash
cd k8s/scripts
./test-authorization.sh
```

**Các test cases:**
1. Verify Authorization Policies tồn tại
2. Test allowed connection (API Gateway → services)
3. Test denied connection (unauthorized pod → services)

### Test Retry

```bash
cd k8s/scripts
./test-retry.sh
```

**Các test cases:**
1. Verify VirtualServices có retry config
2. Inject fault (500 errors) và quan sát retry behavior
3. Check Envoy proxy logs

---

## Troubleshooting

### 1. Pods không có sidecar

```bash
# Kiểm tra namespace label
kubectl get ns petclinic --show-labels

# Nếu thiếu istio-injection label
kubectl label namespace petclinic istio-injection=enabled --overwrite

# Restart pods để inject sidecar
kubectl rollout restart deployment -n petclinic
```

### 2. Connection bị từ chối

```bash
# Kiểm tra mTLS status
istioctl authn tls-check <pod-name> -n petclinic

# Kiểm tra proxy config
istioctl proxy-config listeners <pod-name> -n petclinic
```

### 3. Authorization bị block

```bash
# Xem proxy logs
kubectl logs <pod-name> -n petclinic -c istio-proxy

# Tạm thời disable authorization
kubectl delete authorizationpolicy deny-all -n petclinic
```

### 4. Kiali không hiển thị traffic

```bash
# Generate traffic
for i in {1..100}; do
  curl -s http://localhost:8080/api/customer/owners > /dev/null
  sleep 0.5
done

# Kiểm tra Prometheus có metrics
kubectl port-forward svc/prometheus -n istio-system 9090:9090
# Mở http://localhost:9090 và query: istio_requests_total
```

---

## Tài Liệu Tham Khảo

- [Istio Documentation](https://istio.io/latest/docs/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)

---

**Author:** A (Khánh Duy)  
**Date:** 01/01/2026  
**Version:** 1.0
