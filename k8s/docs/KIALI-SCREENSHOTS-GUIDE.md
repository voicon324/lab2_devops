# 📸 HƯỚNG DẪN CAPTURE KIALI SCREENSHOTS & GIẢI THÍCH FLOW

## 🎯 MỤC TIÊU
Capture screenshots từ Kiali để chứng minh Service Mesh hoạt động với:
- mTLS encryption
- Service topology
- Traffic flow
- Authorization policies

---

## 📋 CHUẨN BỊ

### Bước 1: Generate Traffic
```bash
# Chạy script để tạo traffic
cd /home/duy/DevOps/DevSecOps/Project/lab2_devops/k8s/scripts
chmod +x generate-traffic.sh
./generate-traffic.sh
```

### Bước 2: Mở Kiali Dashboard
```bash
# Terminal 1: Port-forward Kiali
kubectl port-forward svc/kiali -n istio-system 20000:20000

# Mở trình duyệt:
# URL: http://localhost:20000/kiali
```

---

## 📸 SCREENSHOTS CẦN CAPTURE

### Screenshot 1: **Service Topology (Full View)**

**Đường dẫn trong Kiali:**
1. Click menu **"Graph"** (bên trái)
2. Chọn Namespace: **"petclinic"**
3. Display settings:
   - ☑ Traffic Animation
   - ☑ Service Nodes
   - ☑ Security (để thấy mTLS lock icons)
   - Time Range: Last 1 minute

**Nội dung cần thấy:**
```
📸 topology-full.png
├─ API Gateway (entry point)
├─ Customers Service
├─ Vets Service
├─ Visits Service
├─ GenAI Service
├─ Config Server
├─ Discovery Server
└─ Connection arrows with:
   ├─ Lock icons (🔒) = mTLS enabled
   ├─ Traffic metrics (req/s)
   └─ Green = healthy connections
```

**Cách chụp:**
- Zoom để hiện toàn bộ topology
- Đảm bảo nhìn thấy tất cả services và connections
- Screenshot tool: PrtScn hoặc Shift+PrtScn (Linux)
- Lưu: `k8s/docs/kiali-screenshots/topology-full.png`

---

### Screenshot 2: **API Gateway Detail**

**Đường dẫn:**
1. Trong Graph view
2. Click vào **API Gateway** node
3. Panel bên phải sẽ hiện thông tin chi tiết

**Nội dung cần thấy:**
```
📸 api-gateway-detail.png
├─ Service: api-gateway
├─ Outbound Traffic to:
│  ├─ customers-service (HTTP 200, requests/sec)
│  ├─ vets-service (HTTP 200, requests/sec)
│  ├─ visits-service (HTTP 200, requests/sec)
│  └─ genai-service (optional)
├─ Traffic Metrics:
│  ├─ Request rate (req/s)
│  ├─ Success rate (%)
│  ├─ Error rate (%)
│  └─ Duration (latency)
└─ Security:
   └─ mTLS: Enabled ✓
```

**Cách chụp:**
- Click API Gateway node
- Wait for panel to load
- Screenshot cả graph và detail panel
- Lưu: `k8s/docs/kiali-screenshots/api-gateway-detail.png`

---

### Screenshot 3: **Traffic Metrics**

**Đường dẫn:**
1. Graph view
2. Click vào một connection line (arrow) giữa services
3. Hoặc chuyển sang **"Traffic"** tab ở panel bên phải

**Nội dung cần thấy:**
```
📸 traffic-metrics.png
├─ Request volume (req/s)
├─ Response time (ms)
├─ HTTP status codes distribution
│  ├─ 200: xx requests
│  ├─ 403: xx requests (từ authorization deny)
│  └─ 500: xx requests (nếu có)
└─ Protocol: HTTP/2 (with mTLS)
```

**Cách chụp:**
- Click vào connection arrow
- View traffic details
- Screenshot traffic panel
- Lưu: `k8s/docs/kiali-screenshots/traffic-metrics.png`

---

### Screenshot 4: **mTLS Verification**

**Đường dẫn:**
1. Graph view
2. Display settings → Enable **"Security"** badge
3. Hoặc click service → Tab **"Security"**

**Nội dung cần thấy:**
```
📸 mtls-verification.png
├─ mTLS indicators:
│  └─ Lock icons (🔒) on all connections
├─ Security status panel showing:
│  ├─ mTLS Mode: STRICT
│  ├─ Protocol: istio (mutual TLS)
│  └─ Certificate: valid
└─ All connections encrypted
```

**Cách chụp:**
- Enable Security badges in Display settings
- Screenshot showing lock icons
- Lưu: `k8s/docs/kiali-screenshots/mtls-verification.png`

---

## 📝 GIẢI THÍCH FLOW (Viết trong báo cáo)

### Flow 1: Request với mTLS

```
CLIENT REQUEST FLOW:

1. External Request (HTTP)
   ↓
2. API Gateway Service (Port 8080)
   ├─ Istio Sidecar (Envoy Proxy)
   │  ├─ Check AuthorizationPolicy
   │  ├─ Establish mTLS connection
   │  └─ Encrypt request with TLS certificate
   ↓
3. Network Layer (Encrypted Traffic)
   ↓
4. Backend Service Sidecar (Envoy Proxy)
   ├─ Decrypt traffic
   ├─ Verify mTLS certificate
   └─ Check Authorization Policy
   ↓
5. Backend Service (Customers/Vets/Visits)
   ├─ Process request
   └─ Return response
   ↓
6. Response Path (Same encrypted channel)
   ↓
7. Client receives response

Tất cả bước 3-6 được mã hóa với mTLS STRICT mode.
```

### Flow 2: Authorization Decision

```
AUTHORIZATION FLOW:

Request arrives at Service
   ↓
┌──────────────────────────┐
│ Check deny-all policy    │ ← Default: DENY ALL
└──────────┬───────────────┘
           ↓
           ❌ DENIED (unless...)
           ↓
┌──────────────────────────────────┐
│ Check allow-* policies           │
├─ allow-api-gateway-to-customers │
├─ allow-api-gateway-to-vets      │
├─ allow-api-gateway-to-visits    │
└──────────────────────────────────┘
           ↓
┌──────────────────────┐
│ Match found?         │
├─ YES → ✅ ALLOW     │
└─ NO  → ❌ DENY      │
```

**Ví dụ:**
- ✅ API Gateway → Customers Service: **ALLOWED** (có policy)
- ❌ Customers → API Gateway: **DENIED** (không có policy)
- ✅ All Services → Config Server: **ALLOWED** (có policy)

### Flow 3: Retry Mechanism

```
RETRY FLOW (when 5xx error occurs):

Initial Request
   ↓
Backend returns 500 (Internal Error)
   ↓
┌──────────────────────────┐
│ VirtualService detects   │
│ retryOn: 5xx condition   │
└──────────┬───────────────┘
           ↓
   Retry Attempt 1 (after ~perTryTimeout)
   ├─ Still 500? → Retry Attempt 2
   ├─ Still 500? → Retry Attempt 3
   └─ Success 200? → Return to client
           ↓
   After 3 attempts:
   ├─ Success → Return 200 ✓
   └─ Still fail → Return last error ✗
```

**Cấu hình:**
- Attempts: 3
- Per-try timeout: 3s
- Total timeout: 10s
- Retry on: 5xx, reset, connect-failure

---

## 📊 TOPOLOGY EXPLANATION

### Service Communication Matrix

| From Service | To Service | Status | mTLS | Authorization |
|--------------|-----------|--------|------|---------------|
| API Gateway | Customers | ✅ | 🔒 | ALLOW |
| API Gateway | Vets | ✅ | 🔒 | ALLOW |
| API Gateway | Visits | ✅ | 🔒 | ALLOW |
| Customers | API Gateway | ❌ | 🔒 | DENY |
| Vets | Customers | ❌ | 🔒 | DENY |
| All Services | Config Server | ✅ | 🔒 | ALLOW |
| All Services | Discovery Server | ✅ | 🔒 | ALLOW |

**Legend:**
- ✅ = Connection allowed
- ❌ = Connection denied (by AuthorizationPolicy)
- 🔒 = mTLS encrypted

---

## 🎓 KEY OBSERVATIONS FOR REPORT

### 1. mTLS Security
```
Quan sát từ Kiali:
- Tất cả connections có lock icon (🔒)
- Protocol: istio (mutual TLS)
- Mode: STRICT (không cho phép plaintext)
- Certificates: tự động managed bởi Istio
```

### 2. Authorization Enforcement
```
Quan sát từ traffic:
- API Gateway → Services: HTTP 200 (allowed)
- Services → API Gateway: HTTP 403 hoặc timeout (denied)
- Zero-trust model: default deny, explicit allow
```

### 3. Service Dependencies
```
Từ topology, nhận thấy:
┌──────────────┐
│ API Gateway  │ ← Entry point
└──────┬───────┘
       ├─► Customers Service
       ├─► Vets Service
       ├─► Visits Service
       └─► GenAI Service (optional)

Backend Services
├─► Config Server (infrastructure)
└─► Discovery Server (service registry)
```

### 4. Traffic Metrics
```
Từ Kiali metrics:
- Request rate: X req/s
- Success rate: 95-100%
- Latency: avg 50-200ms
- Error rate: <5% (chủ yếu từ authorization denials)
```

---

## ✅ CHECKLIST HOÀN THÀNH

- [ ] Screenshot 1: topology-full.png (full service mesh)
- [ ] Screenshot 2: api-gateway-detail.png (connections detail)
- [ ] Screenshot 3: traffic-metrics.png (request rates, latency)
- [ ] Screenshot 4: mtls-verification.png (lock icons visible)
- [ ] Giải thích flow trong báo cáo (3 flows trên)
- [ ] Topology explanation viết rõ
- [ ] Key observations documented

---

## 💡 TIPS

1. **Generate đủ traffic** trước khi chụp (chạy generate-traffic.sh)
2. **Chọn time range phù hợp** (Last 1 minute hoặc Last 5 minutes)
3. **Zoom để thấy rõ** các node và connections
4. **Enable Security badge** để thấy lock icons
5. **Capture cả graph và detail panel** cho screenshot 2
6. **Chụp khi có traffic** (animation đang chạy)

---

## 📁 LƯU SCREENSHOTS

```bash
# Tạo thư mục
mkdir -p /home/duy/DevOps/DevSecOps/Project/lab2_devops/k8s/docs/kiali-screenshots

# Lưu 4 files:
k8s/docs/kiali-screenshots/
├── topology-full.png
├── api-gateway-detail.png
├── traffic-metrics.png
└── mtls-verification.png
```

---

## 🎯 KẾT QUẢ MONG ĐỢI

Sau khi hoàn thành, bạn sẽ có:
- ✅ 4 screenshots chất lượng cao
- ✅ Flow diagrams giải thích rõ ràng
- ✅ Topology explanation chi tiết
- ✅ Evidence về mTLS, Authorization, Retry
- ✅ Đủ để nộp deliverable "Screenshot Kiali topology và giải thích flow"

---

**Hoàn thành guide này = 100% deliverable 2! 🎉**
