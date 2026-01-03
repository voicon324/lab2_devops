#!/bin/bash
# test-mtls.sh - Script để kiểm tra mTLS hoạt động đúng
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  mTLS TESTING SCRIPT"
echo "=========================================="

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="petclinic"
LOG_DIR="./test-logs"
mkdir -p "$LOG_DIR"

# Test 1: Verify mTLS is enabled
test_mtls_enabled() {
    echo -e "${YELLOW}[Test 1] Verifying mTLS is enabled...${NC}"
    
    echo "Checking PeerAuthentication policy..."
    PA_MODE=$(kubectl get peerauthentication default -n $NAMESPACE -o jsonpath='{.spec.mtls.mode}' 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$PA_MODE" == "STRICT" ]; then
        echo -e "${GREEN}✓ PASS: mTLS mode is STRICT${NC}"
        echo "PeerAuthentication mode: STRICT" >> "$LOG_DIR/mtls-test.log"
    else
        echo -e "${RED}✗ FAIL: mTLS mode is $PA_MODE (expected STRICT)${NC}"
        echo "PeerAuthentication mode: $PA_MODE (FAIL)" >> "$LOG_DIR/mtls-test.log"
    fi
}

# Test 2: Verify sidecar is injected
test_sidecar_injection() {
    echo ""
    echo -e "${YELLOW}[Test 2] Verifying sidecar injection...${NC}"
    
    PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
        CONTAINERS=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}')
        
        if echo "$CONTAINERS" | grep -q "istio-proxy"; then
            echo -e "${GREEN}✓ Pod $POD has istio-proxy sidecar${NC}"
            echo "Pod $POD: istio-proxy PRESENT" >> "$LOG_DIR/mtls-test.log"
        else
            echo -e "${RED}✗ Pod $POD is missing istio-proxy sidecar${NC}"
            echo "Pod $POD: istio-proxy MISSING" >> "$LOG_DIR/mtls-test.log"
        fi
    done
}

# Test 3: Test connection with mTLS
test_mtls_connection() {
    echo ""
    echo -e "${YELLOW}[Test 3] Testing mTLS connection between services...${NC}"
    
    # Get a pod with sidecar
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No api-gateway pod found${NC}"
        return 1
    fi
    
    echo "Testing from $SOURCE_POD to customers-service..."
    
    # This should succeed because both pods have sidecars and mTLS is enabled
    RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c api-gateway -- \
        curl -s -o /dev/null -w "%{http_code}" http://customers-service:8081/actuator/health 2>/dev/null || echo "FAILED")
    
    if [ "$RESULT" == "200" ]; then
        echo -e "${GREEN}✓ PASS: Connection to customers-service successful (HTTP $RESULT)${NC}"
        echo "mTLS connection test: PASS (HTTP $RESULT)" >> "$LOG_DIR/mtls-test.log"
    else
        echo -e "${YELLOW}! Connection returned HTTP $RESULT${NC}"
        echo "mTLS connection test: HTTP $RESULT" >> "$LOG_DIR/mtls-test.log"
    fi
}

# Test 4: Verify TLS certificate info
test_tls_certificate() {
    echo ""
    echo -e "${YELLOW}[Test 4] Checking TLS certificate information...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    echo "Checking proxy configuration..."
    istioctl proxy-config secret $SOURCE_POD -n $NAMESPACE 2>/dev/null | head -20
    
    echo ""
    echo "Verifying TLS connections..."
    istioctl proxy-config clusters $SOURCE_POD -n $NAMESPACE 2>/dev/null | grep -E "customers|visits|vets" | head -10
}

# Test 5: Test plaintext rejection (should fail when mTLS is STRICT)
test_plaintext_rejection() {
    echo ""
    echo -e "${YELLOW}[Test 5] Testing plaintext rejection...${NC}"
    
    # Create a test pod without sidecar
    echo "Creating test pod without Istio sidecar..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-no-sidecar
  namespace: $NAMESPACE
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
EOF

    # Wait for pod to be ready
    echo "Waiting for test pod..."
    kubectl wait --for=condition=ready pod/test-no-sidecar -n $NAMESPACE --timeout=60s 2>/dev/null || true
    sleep 5
    
    echo "Testing plaintext connection from pod WITHOUT sidecar..."
    RESULT=$(kubectl exec test-no-sidecar -n $NAMESPACE -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://customers-service:8081/actuator/health 2>/dev/null || echo "CONNECTION_REFUSED")
    
    if [[ "$RESULT" == *"CONNECTION_REFUSED"* ]] || [[ "$RESULT" == *"000"* ]] || [ "$RESULT" == "56" ]; then
        echo -e "${GREEN}✓ PASS: Plaintext connection was rejected (mTLS enforced)${NC}"
        echo "Plaintext rejection test: PASS" >> "$LOG_DIR/mtls-test.log"
    elif [ "$RESULT" == "503" ]; then
        echo -e "${GREEN}✓ PASS: Connection returned 503 (mTLS required)${NC}"
        echo "Plaintext rejection test: PASS (503)" >> "$LOG_DIR/mtls-test.log"
    else
        echo -e "${RED}✗ FAIL: Plaintext connection succeeded with HTTP $RESULT${NC}"
        echo "Plaintext rejection test: FAIL (HTTP $RESULT)" >> "$LOG_DIR/mtls-test.log"
    fi
    
    # Cleanup
    echo "Cleaning up test pod..."
    kubectl delete pod test-no-sidecar -n $NAMESPACE --ignore-not-found=true
}

# Generate summary
generate_summary() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo "=========================================="
    
    echo ""
    echo "Test logs saved to: $LOG_DIR/mtls-test.log"
    echo ""
    cat "$LOG_DIR/mtls-test.log"
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}  mTLS TESTING COMPLETED!${NC}"
    echo "=========================================="
}

# Main
main() {
    echo "Test started at: $(date)" > "$LOG_DIR/mtls-test.log"
    echo "" >> "$LOG_DIR/mtls-test.log"
    
    test_mtls_enabled
    test_sidecar_injection
    test_mtls_connection
    test_tls_certificate
    test_plaintext_rejection
    generate_summary
}

main "$@"
