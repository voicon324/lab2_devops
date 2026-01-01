# Test Plan - Service Mesh

## Thông Tin Chung

| Mục | Giá trị |
|-----|---------|
| Project | Spring PetClinic with Istio Service Mesh |
| Author | A (Khánh Duy) |
| Version | 1.0 |
| Date | 01/01/2026 |

---

## 1. Phạm Vi Testing

### 1.1 In Scope
- mTLS encryption giữa các services
- Authorization Policies (service-to-service access control)
- Retry Policies (automatic retry on 5xx errors)
- Kiali visualization

### 1.2 Out of Scope
- Performance testing
- Load testing
- Penetration testing

---

## 2. Test Cases

### 2.1 mTLS Testing

#### TC-MTLS-001: Verify mTLS Mode STRICT
| Attribute | Value |
|-----------|-------|
| **Objective** | Xác nhận PeerAuthentication được cấu hình STRICT |
| **Prerequisites** | Istio và PetClinic đã được deploy |
| **Steps** | 1. Chạy lệnh: `kubectl get peerauthentication default -n petclinic -o yaml` |
| **Expected Result** | `spec.mtls.mode: STRICT` |
| **Priority** | High |

#### TC-MTLS-002: Verify Sidecar Injection
| Attribute | Value |
|-----------|-------|
| **Objective** | Xác nhận tất cả pods có istio-proxy sidecar |
| **Prerequisites** | PetClinic đã được deploy |
| **Steps** | 1. Chạy: `kubectl get pods -n petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'` |
| **Expected Result** | Mỗi pod hiển thị 2 containers: `<app-name> istio-proxy` |
| **Priority** | High |

#### TC-MTLS-003: Test mTLS Connection
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify connection với mTLS thành công |
| **Prerequisites** | - PeerAuthentication STRICT đã apply<br>- Tất cả pods có sidecar |
| **Steps** | 1. Exec vào api-gateway pod<br>2. Curl tới customers-service |
| **Test Command** | `kubectl exec <api-gateway-pod> -n petclinic -c api-gateway -- curl -s http://customers-service:8081/actuator/health` |
| **Expected Result** | HTTP 200 OK |
| **Priority** | High |

#### TC-MTLS-004: Test Plaintext Rejection
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify plaintext traffic bị từ chối khi mTLS STRICT |
| **Prerequisites** | PeerAuthentication STRICT đã apply |
| **Steps** | 1. Tạo pod KHÔNG có sidecar<br>2. Curl tới customers-service |
| **Test Command** | `kubectl run test-no-sidecar --image=curlimages/curl --rm -it --restart=Never --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"}}}' -n petclinic -- curl -v http://customers-service:8081/actuator/health` |
| **Expected Result** | Connection refused hoặc HTTP 503 |
| **Priority** | High |

---

### 2.2 Authorization Testing

#### TC-AUTH-001: Verify Authorization Policies Exist
| Attribute | Value |
|-----------|-------|
| **Objective** | Xác nhận tất cả Authorization Policies đã được apply |
| **Prerequisites** | Istio và authorization-policies.yaml đã apply |
| **Steps** | 1. Chạy: `kubectl get authorizationpolicy -n petclinic` |
| **Expected Result** | Hiển thị các policies: deny-all, allow-api-gateway-to-services, allow-config-server-access, allow-discovery-server-access |
| **Priority** | High |

#### TC-AUTH-002: Test Allowed Connection (API Gateway → Customers)
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify API Gateway có thể gọi Customers Service |
| **Prerequisites** | Authorization policies đã apply |
| **Steps** | 1. Exec vào api-gateway pod<br>2. Curl tới customers-service |
| **Test Command** | `kubectl exec <api-gateway-pod> -n petclinic -c api-gateway -- curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/actuator/health` |
| **Expected Result** | HTTP 200 |
| **Priority** | High |

#### TC-AUTH-003: Test Allowed Connection (API Gateway → Vets)
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify API Gateway có thể gọi Vets Service |
| **Prerequisites** | Authorization policies đã apply |
| **Test Command** | `kubectl exec <api-gateway-pod> -n petclinic -c api-gateway -- curl -s -o /dev/null -w "%{http_code}" http://vets-service:8083/actuator/health` |
| **Expected Result** | HTTP 200 |
| **Priority** | High |

#### TC-AUTH-004: Test Denied Connection (Unauthorized Pod)
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify unauthorized pod bị từ chối truy cập |
| **Prerequisites** | deny-all policy đã apply |
| **Steps** | 1. Tạo pod với label khác<br>2. Curl tới customers-service |
| **Test Command** | `kubectl run unauthorized --image=curlimages/curl --rm -it --restart=Never -n petclinic -- curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/actuator/health` |
| **Expected Result** | HTTP 403 hoặc Connection refused |
| **Priority** | High |

#### TC-AUTH-005: Test Config Server Access
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify tất cả services có thể truy cập Config Server |
| **Prerequisites** | allow-config-server-access policy đã apply |
| **Test Command** | `kubectl exec <customers-service-pod> -n petclinic -c customers-service -- curl -s -o /dev/null -w "%{http_code}" http://config-server:8888/actuator/health` |
| **Expected Result** | HTTP 200 |
| **Priority** | Medium |

#### TC-AUTH-006: Test Discovery Server Access
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify tất cả services có thể truy cập Discovery Server |
| **Prerequisites** | allow-discovery-server-access policy đã apply |
| **Test Command** | `kubectl exec <vets-service-pod> -n petclinic -c vets-service -- curl -s -o /dev/null -w "%{http_code}" http://discovery-server:8761/actuator/health` |
| **Expected Result** | HTTP 200 |
| **Priority** | Medium |

---

### 2.3 Retry Policy Testing

#### TC-RETRY-001: Verify VirtualService Retry Config
| Attribute | Value |
|-----------|-------|
| **Objective** | Xác nhận VirtualServices có cấu hình retry |
| **Prerequisites** | virtual-services.yaml đã apply |
| **Steps** | 1. Chạy: `kubectl get virtualservice customers-service -n petclinic -o yaml` |
| **Expected Result** | `retries.attempts: 3`<br>`retries.retryOn: 5xx,reset,connect-failure` |
| **Priority** | High |

#### TC-RETRY-002: Test Retry with Fault Injection
| Attribute | Value |
|-----------|-------|
| **Objective** | Verify retry hoạt động khi inject fault 500 |
| **Prerequisites** | VirtualServices đã apply |
| **Steps** | 1. Apply fault injection (50% HTTP 500)<br>2. Gửi 10 requests<br>3. Đếm số success |
| **Expected Result** | Số success > 50% (do retry) |
| **Priority** | High |

#### TC-RETRY-003: Verify Retry in Envoy Logs
| Attribute | Value |
|-----------|-------|
| **Objective** | Xác nhận có evidence của retry trong proxy logs |
| **Prerequisites** | Đã chạy TC-RETRY-002 |
| **Steps** | 1. Xem logs của istio-proxy |
| **Test Command** | `kubectl logs <pod> -n petclinic -c istio-proxy --tail=100 \| grep -i retry` |
| **Expected Result** | Có log entries liên quan đến retry |
| **Priority** | Medium |

---

## 3. Test Environment

### 3.1 Environment Details
| Component | Version |
|-----------|---------|
| Kubernetes | v1.28+ |
| Istio | v1.20.x |
| Kiali | v1.78+ |
| kubectl | v1.28+ |

### 3.2 Namespace
- `petclinic`: Application namespace với istio-injection enabled
- `istio-system`: Istio control plane

---

## 4. Test Execution

### 4.1 Automated Test Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| test-mtls.sh | Test mTLS functionality | k8s/scripts/test-mtls.sh |
| test-authorization.sh | Test Authorization Policies | k8s/scripts/test-authorization.sh |
| test-retry.sh | Test Retry Policies | k8s/scripts/test-retry.sh |

### 4.2 Running Tests

```bash
# Run all tests
cd k8s/scripts
./test-mtls.sh
./test-authorization.sh
./test-retry.sh
```

### 4.3 Test Logs
All test logs will be saved to: `k8s/scripts/test-logs/`

---

## 5. Acceptance Criteria

### 5.1 mTLS
- [ ] PeerAuthentication mode là STRICT
- [ ] Tất cả pods trong petclinic namespace có istio-proxy sidecar
- [ ] Connection giữa services với sidecar thành công
- [ ] Plaintext connection bị từ chối

### 5.2 Authorization
- [ ] Tất cả Authorization Policies được apply thành công
- [ ] API Gateway có thể gọi tất cả backend services
- [ ] Unauthorized pods bị từ chối (HTTP 403)
- [ ] Tất cả services có thể truy cập Config Server và Discovery Server

### 5.3 Retry
- [ ] VirtualServices có cấu hình retry (attempts=3, retryOn=5xx)
- [ ] Retry hoạt động đúng khi có fault injection
- [ ] Evidence của retry có trong Envoy logs hoặc Kiali

---

## 6. Test Report Template

### Test Execution Summary

| Date | Tester | Environment |
|------|--------|-------------|
| DD/MM/YYYY | Name | Environment Name |

### Test Results

| Test Case ID | Description | Status | Notes |
|--------------|-------------|--------|-------|
| TC-MTLS-001 | Verify mTLS Mode STRICT | PASS/FAIL | |
| TC-MTLS-002 | Verify Sidecar Injection | PASS/FAIL | |
| TC-MTLS-003 | Test mTLS Connection | PASS/FAIL | |
| TC-MTLS-004 | Test Plaintext Rejection | PASS/FAIL | |
| TC-AUTH-001 | Verify Auth Policies Exist | PASS/FAIL | |
| TC-AUTH-002 | Test Allowed Connection | PASS/FAIL | |
| TC-AUTH-003 | Test Allowed Vets | PASS/FAIL | |
| TC-AUTH-004 | Test Denied Connection | PASS/FAIL | |
| TC-AUTH-005 | Test Config Server Access | PASS/FAIL | |
| TC-AUTH-006 | Test Discovery Server Access | PASS/FAIL | |
| TC-RETRY-001 | Verify Retry Config | PASS/FAIL | |
| TC-RETRY-002 | Test Retry with Fault | PASS/FAIL | |
| TC-RETRY-003 | Verify Retry Logs | PASS/FAIL | |

### Issues Found
| Issue ID | Description | Severity | Status |
|----------|-------------|----------|--------|
| | | | |

---

**Author:** A (Khánh Duy)  
**Date:** 01/01/2026
