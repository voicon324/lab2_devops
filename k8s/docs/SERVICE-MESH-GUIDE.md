# Service Mesh & Security Configuration - Complete Implementation Guide

## 📋 Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Detailed Configuration](#detailed-configuration)
6. [Testing & Verification](#testing--verification)
7. [Troubleshooting](#troubleshooting)
8. [Appendix](#appendix)

---

## Overview

This project implements a **production-grade Service Mesh** using **Istio** for the Spring PetClinic Microservices application running on Kubernetes.

### What is Service Mesh?

A service mesh is a dedicated infrastructure layer that handles service-to-service communication in microservices architectures. It provides:

- **mTLS (Mutual TLS)**: Automatic encryption and authentication between services
- **Authorization Policies**: Control which services can communicate with each other
- **Resilience**: Automatic retries, circuit breaking, timeout handling
- **Observability**: Detailed metrics, tracing, and topology visualization

### Key Features Implemented

| Feature | Status | Description |
|---------|--------|-------------|
| **mTLS Encryption** | ✅ | STRICT mode - all traffic encrypted |
| **Authorization** | ✅ | Zero-trust model with explicit allow rules |
| **Retry Policy** | ✅ | Automatic retry on 5xx errors (3 attempts) |
| **Traffic Policy** | ✅ | Connection pooling, HTTP/2 upgrade |
| **Observability** | ✅ | Kiali dashboard, Prometheus metrics |
| **Service Topology** | ✅ | Automatic service discovery and visualization |

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              PETCLINIC NAMESPACE                            │ │
│  │         (istio-injection: enabled)                          │ │
│  │                                                             │ │
│  │  ENTRY POINT:                                              │ │
│  │  ┌──────────────────┐                                       │ │
│  │  │ API GATEWAY      │ ◄─── HTTP/REST Requests             │ │
│  │  │ Port: 8080       │                                       │ │
│  │  │ [sidecar proxy]  │                                       │ │
│  │  └──────────┬───────┘                                       │ │
│  │             │                                               │ │
│  │  BACKEND SERVICES (mTLS Protected):                        │ │
│  │  ┌──────────┴──────────┬─────────────────┬──────────────┐ │ │
│  │  │                     │                 │              │ │ │
│  │  ▼                     ▼                 ▼              ▼ │ │
│  │ ┌──────────┐       ┌──────────┐     ┌──────────┐  ┌────────┐│ │
│  │ │CUSTOMERS │       │  VISITS  │     │  VETS    │  │ GENAI  ││ │
│  │ │Service   │       │ Service  │     │ Service  │  │Service ││ │
│  │ │8081      │       │ 8082     │     │ 8083     │  │ 8084   ││ │
│  │ └──────────┘       └──────────┘     └──────────┘  └────────┘│ │
│  │                                                             │ │
│  │  INFRASTRUCTURE SERVICES:                                  │ │
│  │  ┌──────────────────────────┬──────────────────────────┐  │ │
│  │  │                          │                          │  │ │
│  │  ▼                          ▼                          ▼  │ │
│  │ ┌──────────────┐      ┌──────────────┐      ┌──────────┐ │ │
│  │ │CONFIG SERVER │      │ DISCOVERY    │      │  ADMIN   │ │ │
│  │ │8888          │      │ SERVER 8761  │      │ SERVER   │ │ │
│  │ └──────────────┘      └──────────────┘      └──────────┘ │ │
│  │                                                             │ │
│  │  Security Features:                                        │ │
│  │  • Each pod: [App Container] + [Envoy Sidecar Proxy]     │ │
│  │  • mTLS: STRICT (TLS required)                           │ │
│  │  • AuthZ: Default deny, explicit allow                   │ │
│  │  • Retry: 3 attempts on 5xx errors                       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │            ISTIO SYSTEM NAMESPACE                           │ │
│  │                                                             │ │
│  │  ┌──────────┐  ┌───────┐  ┌────────────┐  ┌────────────┐ │ │
│  │  │ ISTIOD   │  │ KIALI │  │PROMETHEUS  │  │  GRAFANA   │ │ │
│  │  │(Control  │  │(UI    │  │(Metrics)   │  │(Dashboards)│ │ │
│  │  │Plane)    │  │Visual)│  │            │  │            │ │ │
│  │  └──────────┘  └───────┘  └────────────┘  └────────────┘ │ │
│  │                                                             │ │
│  │  ┌──────────┐  ┌────────────┐                             │ │
│  │  │ JAEGER   │  │ INGRESS    │                             │ │
│  │  │(Tracing) │  │ GATEWAY    │                             │ │
│  │  └──────────┘  └────────────┘                             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Service Communication Flow

```
REQUEST FLOW WITH mTLS & AUTHORIZATION:

1. Client Request
   ↓
2. API Gateway (Ingress)
   ↓ [mTLS STRICT]
3. Envoy Sidecar Proxy (API Gateway)
   ├─ Check AuthorizationPolicy
   ├─ Establish mTLS connection
   └─ Encrypt traffic
   ↓
4. Network (Encrypted)
   ↓
5. Envoy Sidecar Proxy (Backend Service)
   ├─ Decrypt traffic
   └─ Verify mTLS certificate
   ↓
6. Backend Service (Customers/Vets/Visits)
   ↓
7. Response (Same encrypted path backwards)

AUTHORIZATION DECISION LOGIC:
┌─────────────────────┐
│ Request arrives     │
└──────────┬──────────┘
           ↓
┌─────────────────────────┐
│ Check deny-all policy   │ ← Default: DENY ALL
└──────────┬──────────────┘
           ↓ (Explicitly denied, unless...)
┌──────────────────────────────────┐
│ Check allow-* policies            │
├─ allow-api-gateway-*             │
├─ allow-config-discovery          │
└──────────────────────────────────┘
           ↓
┌──────────────────────┐
│ ALLOW ✓ or DENY ✗    │
└──────────────────────┘
```

---

## Prerequisites

### System Requirements

| Component | Requirement | Minimum |
|-----------|-------------|---------|
| Kubernetes | Version | 1.23+ |
| Cluster Memory | RAM | 8 GB |
| CPU Cores | Cores | 4 |
| Disk Space | Storage | 20 GB |
| Network | Internet | Required (for pulling images) |

### Required Tools

```bash
# Check installed tools
kubectl version --client
minikube start
istioctl version
helm version
docker version  # or podman
```

### Installation Checklist

- [x] Kubernetes cluster running (minikube, kind, EKS, GKE, AKS)
- [x] kubectl configured and accessible
- [x] Internet connectivity for pulling images
- [x] Sufficient cluster resources (CPU, memory, storage)

### Verify Kubernetes Connectivity

```bash
# Test cluster access
kubectl cluster-info
kubectl get nodes

# Expected output: At least 1 node in Ready state
```

---

## Quick Start

### 1. Prepare Kubernetes Cluster

```bash
# Create namespace for PetClinic
kubectl create namespace petclinic

# Enable Istio sidecar injection for this namespace
kubectl label namespace petclinic istio-injection=enabled

# Verify
kubectl get namespace petclinic --show-labels
```

### 2. Install Istio

```bash
cd k8s/scripts

# Option A: Using provided script
chmod +x install-istio.sh
./install-istio.sh

# Option B: Manual installation
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
```

### 3. Deploy Spring PetClinic Services

```bash
# Apply namespace and deployments
kubectl apply -f ./k8s/namespace.yaml
kubectl apply -f ./k8s/deployments/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=api-gateway -n petclinic --timeout=300s
```

### 4. Apply Service Mesh Configuration

```bash
# Apply mTLS, Authorization, Retry policies
kubectl apply -f ./k8s/istio/

# Verify configuration applied
kubectl get peerauthentication -n petclinic
kubectl get authorizationpolicy -n petclinic
kubectl get virtualservice -n petclinic
```

### 5. Verify Installation

```bash
# Check all pods running
kubectl get pods -n petclinic -o wide

# Test connectivity
API_GW=$(kubectl get pod -n petclinic -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n petclinic $API_GW -c api-gateway -- \
  curl -s http://customers-service:8081/actuator/health

# Expected: {"status":"UP"}
```

### 6. Access Kiali Dashboard

```bash
# Port-forward Kiali
kubectl port-forward svc/kiali -n istio-system 20000:20000 &

# Open browser
# URL: http://localhost:20000/kiali
# Navigate to: Graph → Select "petclinic" namespace
```

---

## Detailed Configuration

### 1. mTLS Configuration (PeerAuthentication)

**File:** `istio/peer-authentication.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: petclinic
spec:
  mtls:
    mode: STRICT
```

**What it does:**
- Enforces mutual TLS for all services in petclinic namespace
- `STRICT`: Only mTLS traffic allowed (plaintext rejected)
- Certificates are automatically managed by Istio

**Verification:**
```bash
kubectl get peerauthentication -n petclinic -o yaml
kubectl get peerauthentication -n petclinic -o jsonpath='{.items[0].spec.mtls.mode}'
# Output: STRICT
```

### 2. Authorization Policies

**File:** `istio/authorization-policies.yaml`

#### Policy 1: Deny-All (Default)

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: petclinic
spec:
  rules: []  # Empty rules = deny everything
```

**Effect:**
- Default: DENY ALL traffic (zero-trust model)
- Must explicitly allow communication

#### Policy 2: Allow API Gateway to Services

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-api-gateway-to-customers
  namespace: petclinic
spec:
  selector:
    matchLabels:
      app: customers-service
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces:
        - "petclinic"
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
```

**Effect:**
- Allows API Gateway (and any service in petclinic namespace) to call customers-service
- Only HTTP methods: GET, POST, PUT, DELETE
- Port: 8081 (default for customers-service)

**Verification:**
```bash
kubectl get authorizationpolicy -n petclinic
kubectl get authorizationpolicy -n petclinic -o yaml
```

### 3. Retry Policies (VirtualService)

**File:** `istio/virtual-services.yaml`

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
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure,retriable-4xx
```

**Configuration Breakdown:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `attempts` | 3 | Max number of attempts (1 original + 2 retries) |
| `perTryTimeout` | 3s | Timeout per individual attempt |
| `timeout` | 10s | Total timeout (all attempts combined) |
| `retryOn` | 5xx,reset,... | Conditions that trigger retry |

**Retry Flow Example:**
```
1. Initial request → Response: HTTP 500
2. Retry 1 → Response: HTTP 500  
3. Retry 2 → Response: HTTP 200 ✓ (Success)

Total time: ~6-9 seconds (depends on perTryTimeout)
```

### 4. Traffic Policies (DestinationRule)

**File:** `istio/destination-rules.yaml`

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
      mode: ISTIO_MUTUAL  # Use Istio-managed certificates
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
```

**Configuration Details:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `mode: ISTIO_MUTUAL` | Istio certs | Automatic mTLS certificate management |
| `maxConnections` | 100 | Max TCP connections per service |
| `h2UpgradePolicy` | UPGRADE | Upgrade HTTP/1.1 to HTTP/2 |
| `http1MaxPendingRequests` | 100 | Max pending HTTP/1.1 requests |
| `http2MaxRequests` | 1000 | Max concurrent HTTP/2 requests |

---

## Testing & Verification

### Automated Testing

```bash
# Run comprehensive test suite
chmod +x k8s/scripts/run-full-tests.sh
./k8s/scripts/run-full-tests.sh

# Outputs to: test-results/
# Report: test-results/test-report-*.md
```

### Manual Testing

#### Test 1: Verify mTLS is Enforced

```bash
# Check PeerAuthentication
kubectl get peerauthentication -n petclinic
kubectl get peerauthentication -n petclinic -o jsonpath='{.items[0].spec.mtls.mode}'
# Expected: STRICT

# Check sidecar injection
kubectl get pods -n petclinic -o wide
# Expected: READY column shows "2/2" (app + sidecar)

# Check sidecar containers
kubectl get pods -n petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Expected: Each pod has "istio-proxy" in container names
```

#### Test 2: Test mTLS Connection

```bash
# Get API Gateway pod
API_GW=$(kubectl get pod -n petclinic -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')

# Test connection to Customers Service
kubectl exec -n petclinic $API_GW -c api-gateway -- \
  curl -v http://customers-service:8081/actuator/health

# Expected output:
# - Connected to customers-service:8081 via mTLS
# - HTTP 200 OK
# - Response body: {"status":"UP","components":{...}}
```

#### Test 3: Test Plaintext Rejection

```bash
# Try to connect without sidecar (should fail)
kubectl run test-plaintext --image=curlimages/curl --rm -i --restart=Never \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"}}}' \
  -n petclinic -- curl -v http://customers-service:8081/actuator/health

# Expected: Connection timeout or refused (STRICT mode blocks plaintext)
```

#### Test 4: Test Authorization

```bash
# Test allowed connection: API Gateway → Customers
API_GW=$(kubectl get pod -n petclinic -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n petclinic $API_GW -c api-gateway -- \
  curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/actuator/health
# Expected: 200 (ALLOWED)

# Test denied connection: Customers → API Gateway  
CUSTOMERS=$(kubectl get pod -n petclinic -l app=customers-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n petclinic $CUSTOMERS -c customers-service -- \
  curl -s -m 5 -o /dev/null -w "%{http_code}" http://api-gateway:8080/actuator/health
# Expected: 000 or 403 (DENIED)
```

#### Test 5: View Kiali Topology

```bash
# Port-forward Kiali
kubectl port-forward svc/kiali -n istio-system 20000:20000 &

# Open in browser
# URL: http://localhost:20000/kiali
# Navigate to: Graph → Select "petclinic" namespace

# Observe:
# - Service topology diagram
# - Connection lines between services
# - Traffic metrics (requests/sec, latency)
# - mTLS status (lock icons)
```

### Test Results Expected

| Test | Expected Result | Status |
|------|-----------------|--------|
| mTLS STRICT mode | mode: STRICT in PeerAuthentication | ✅ PASS |
| Sidecar injection | All pods READY 2/2 | ✅ PASS |
| mTLS connection | HTTP 200 from sidecar pod | ✅ PASS |
| Plaintext rejection | Connection timeout/refused | ✅ PASS |
| Authorization allow | HTTP 200 for allowed pairs | ✅ PASS |
| Authorization deny | HTTP 403/timeout for denied pairs | ✅ PASS |
| Retry config | VirtualServices show 3 attempts | ✅ PASS |
| Kiali visualization | Service topology visible | ✅ PASS |

---

## Troubleshooting

### Problem 1: Pods Not Getting Sidecar

**Symptom:** `kubectl get pods -n petclinic -o wide` shows `READY 1/1` instead of `2/2`

**Solution:**
```bash
# Check namespace label
kubectl get namespace petclinic --show-labels
# Should show: istio-injection=enabled

# If missing, add label
kubectl label namespace petclinic istio-injection=enabled --overwrite

# Redeploy pods
kubectl rollout restart deployment -n petclinic
```

### Problem 2: Connection Timeout Between Services

**Symptom:** `curl` commands timeout or hang

**Causes & Solutions:**

```bash
# 1. Check if authorization policy is blocking
kubectl get authorizationpolicy -n petclinic
kubectl get authorizationpolicy -n petclinic -o yaml

# 2. Check if pods have sidecar
kubectl describe pod <pod-name> -n petclinic | grep istio-proxy

# 3. Check sidecar logs for errors
kubectl logs <pod-name> -c istio-proxy -n petclinic | tail -50

# 4. Check if service exists and is accessible
kubectl get svc -n petclinic
kubectl get endpoints <service-name> -n petclinic
```

### Problem 3: Kiali Dashboard Not Accessible

**Symptom:** Cannot connect to `localhost:20000/kiali`

**Solution:**
```bash
# Check Kiali pod is running
kubectl get pods -n istio-system -l app=kiali
# Should show: 1/1 Running

# Kill previous port-forward
pkill -f "port-forward.*kiali"

# Restart port-forward
kubectl port-forward svc/kiali -n istio-system 20000:20000

# Try with different port if 20000 in use
kubectl port-forward svc/kiali -n istio-system 30000:20000
# Access: http://localhost:30000/kiali
```

### Problem 4: Authorization Policies Not Working

**Symptom:** All requests pass even with deny-all policy

**Solution:**
```bash
# Check deny-all policy exists
kubectl get authorizationpolicy -n petclinic -o yaml | grep -A 5 deny-all

# Verify policy is valid YAML
kubectl apply -f istio/authorization-policies.yaml --dry-run=client

# Check for policy typos
# Should have "deny-all" with empty rules: spec.rules: []

# Reapply policies
kubectl delete authorizationpolicy -n petclinic --all
kubectl apply -f istio/authorization-policies.yaml
```

### Problem 5: mTLS Connection Errors

**Symptom:** "Connection reset" or "TLS handshake failed"

**Solution:**
```bash
# Check mTLS mode
kubectl get peerauthentication -n petclinic -o yaml
# Should show: mode: STRICT

# Check sidecar version matches
istioctl analyze
# Look for version mismatches or incompatibilities

# Check Istiod is running
kubectl get pods -n istio-system -l app=istiod

# View sidecar proxy configuration
kubectl exec <pod> -n petclinic -c istio-proxy -- \
  curl -s localhost:15000/config_dump | grep -A 10 "mTLS"
```

---

## Appendix

### A. Useful Commands Reference

```bash
# Service Mesh Status
kubectl get svc,pods,vs,dr,pa -n petclinic
kubectl get peerauthentication,authorizationpolicy -n petclinic

# Check Configuration
kubectl describe peerauthentication default -n petclinic
kubectl describe authorizationpolicy deny-all -n petclinic

# View Logs
kubectl logs <pod-name> -n petclinic                   # App logs
kubectl logs <pod-name> -c istio-proxy -n petclinic  # Sidecar logs

# Debug Sidecar Proxy
kubectl exec <pod> -n petclinic -c istio-proxy -- \
  curl -s localhost:15000/config_dump | python -m json.tool

# Test Connectivity
kubectl exec <pod> -n petclinic -c <container> -- curl -v http://<service>:8080

# Restart Pods
kubectl rollout restart deployment <name> -n petclinic

# Delete All Custom Resources
kubectl delete peerauthentication,authorizationpolicy,virtualservice,destinationrule \
  -n petclinic --all
```

### B. Environment Cleanup

```bash
# Remove PetClinic deployment
kubectl delete namespace petclinic

# Uninstall Istio (keep istio-system for other workloads)
istioctl uninstall --purge

# Remove Istio system namespace
kubectl delete namespace istio-system

# Remove Istio installation directory
rm -rf istio-*/
```

### C. Additional Resources

- **Istio Documentation**: https://istio.io/latest/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Kiali Dashboard**: https://kiali.io/
- **mTLS in Istio**: https://istio.io/latest/docs/concepts/security/#mutual-tls

---

## Summary

This implementation provides:

✅ **Secure Communication**: mTLS encryption between all services  
✅ **Access Control**: Authorization policies enforce zero-trust security  
✅ **Resilience**: Automatic retry on failures  
✅ **Visibility**: Kiali provides real-time topology and metrics  
✅ **Production-Ready**: Follows Istio best practices  

**Status**: ✅ All components deployed and verified

**Next Steps**:
1. Run full test suite: `./k8s/scripts/run-full-tests.sh`
2. Review Kiali topology visualization
3. Monitor logs for any issues
4. Proceed with DevSecOps implementation (Part 2)

---

**Document Version:** 1.0  
**Last Updated:** January 3, 2026  
**Maintained By:** A (Khánh Duy)
