#!/bin/bash
# test-retry.sh - Script để kiểm tra Retry Policy hoạt động
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  RETRY POLICY TESTING SCRIPT"
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

# Test 1: Verify VirtualServices with retry config exist
test_virtualservices_exist() {
    echo -e "${YELLOW}[Test 1] Verifying VirtualServices with retry configuration...${NC}"
    
    echo "Listing VirtualServices in $NAMESPACE..."
    kubectl get virtualservices -n $NAMESPACE
    
    VS_LIST=$(kubectl get virtualservices -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    for vs in $VS_LIST; do
        RETRIES=$(kubectl get virtualservice $vs -n $NAMESPACE -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null || echo "0")
        RETRY_ON=$(kubectl get virtualservice $vs -n $NAMESPACE -o jsonpath='{.spec.http[0].retries.retryOn}' 2>/dev/null || echo "N/A")
        
        if [ "$RETRIES" != "0" ] && [ -n "$RETRIES" ]; then
            echo -e "${GREEN}✓ VirtualService '$vs' has retry config: attempts=$RETRIES, retryOn=$RETRY_ON${NC}"
            echo "VirtualService $vs: retry=$RETRIES, retryOn=$RETRY_ON" >> "$LOG_DIR/retry-test.log"
        else
            echo -e "${YELLOW}! VirtualService '$vs' has no retry configuration${NC}"
            echo "VirtualService $vs: NO RETRY CONFIG" >> "$LOG_DIR/retry-test.log"
        fi
    done
}

# Test 2: Check retry configuration details
test_retry_configuration() {
    echo ""
    echo -e "${YELLOW}[Test 2] Checking retry configuration details...${NC}"
    
    for service in customers-service visits-service vets-service; do
        echo ""
        echo -e "${BLUE}=== $service ===${NC}"
        
        VS_CONFIG=$(kubectl get virtualservice $service -n $NAMESPACE -o jsonpath='
Attempts: {.spec.http[0].retries.attempts}
PerTryTimeout: {.spec.http[0].retries.perTryTimeout}
RetryOn: {.spec.http[0].retries.retryOn}
Timeout: {.spec.http[0].timeout}
' 2>/dev/null || echo "VirtualService not found")
        
        echo "$VS_CONFIG"
        echo "$service: $VS_CONFIG" >> "$LOG_DIR/retry-test.log"
    done
}

# Test 3: Create a fault injection to simulate 500 errors
test_with_fault_injection() {
    echo ""
    echo -e "${YELLOW}[Test 3] Testing retry with fault injection (simulating 500 errors)...${NC}"
    
    # Apply fault injection VirtualService
    echo "Applying fault injection to vets-service (50% HTTP 500)..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: vets-service-fault
  namespace: $NAMESPACE
spec:
  hosts:
  - vets-service
  http:
  - fault:
      abort:
        httpStatus: 500
        percentage:
          value: 50
    route:
    - destination:
        host: vets-service
        port:
          number: 8083
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure
EOF

    sleep 5
    
    # Test multiple requests
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No api-gateway pod found${NC}"
        return 1
    fi
    
    echo "Making 10 requests to test retry behavior..."
    SUCCESS=0
    FAILURE=0
    
    for i in $(seq 1 10); do
        RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c api-gateway -- \
            curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://vets-service:8083/actuator/health 2>/dev/null || echo "FAILED")
        
        if [ "$RESULT" == "200" ]; then
            echo "Request $i: HTTP $RESULT (success after retry)"
            ((SUCCESS++))
        else
            echo "Request $i: HTTP $RESULT (failed)"
            ((FAILURE++))
        fi
    done
    
    echo ""
    echo "Results: $SUCCESS successes, $FAILURE failures out of 10 requests"
    echo "Fault Injection Test: $SUCCESS/10 success" >> "$LOG_DIR/retry-test.log"
    
    # Due to retries, we should see more successes than the 50% fault rate would suggest
    if [ $SUCCESS -ge 6 ]; then
        echo -e "${GREEN}✓ PASS: Retry is helping recover from faults${NC}"
    else
        echo -e "${YELLOW}! Retry might not be working as expected${NC}"
    fi
    
    # Cleanup fault injection
    echo ""
    echo "Removing fault injection..."
    kubectl delete virtualservice vets-service-fault -n $NAMESPACE --ignore-not-found=true
    
    # Re-apply original VirtualService
    echo "Restoring original VirtualService..."
    kubectl apply -f ../istio/virtual-services.yaml
}

# Test 4: Check Envoy proxy logs for retry evidence
test_envoy_logs() {
    echo ""
    echo -e "${YELLOW}[Test 4] Checking Envoy proxy logs for retry evidence...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No api-gateway pod found${NC}"
        return 1
    fi
    
    echo "Checking last 50 lines of istio-proxy logs..."
    LOGS=$(kubectl logs $SOURCE_POD -n $NAMESPACE -c istio-proxy --tail=50 2>/dev/null || echo "No logs available")
    
    if echo "$LOGS" | grep -q "retry"; then
        echo -e "${GREEN}✓ Found retry-related entries in proxy logs${NC}"
        echo "$LOGS" | grep "retry" | head -10
    else
        echo -e "${YELLOW}No explicit retry entries found in recent logs${NC}"
        echo "(This is normal if no failures occurred recently)"
    fi
    
    echo ""
    echo "Full logs saved to: $LOG_DIR/envoy-proxy.log"
    kubectl logs $SOURCE_POD -n $NAMESPACE -c istio-proxy --tail=100 > "$LOG_DIR/envoy-proxy.log" 2>/dev/null || true
}

# Test 5: Check proxy configuration for retry settings
test_proxy_config() {
    echo ""
    echo -e "${YELLOW}[Test 5] Checking proxy configuration for retry settings...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    echo "Dumping cluster configuration..."
    istioctl proxy-config routes $SOURCE_POD -n $NAMESPACE 2>/dev/null | head -30
    
    echo ""
    echo "Checking route configuration for customers-service..."
    istioctl proxy-config routes $SOURCE_POD -n $NAMESPACE --name "8081" -o json 2>/dev/null | head -50 || echo "Route info not available"
}

# Generate summary
generate_summary() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo "=========================================="
    
    echo ""
    echo "Test logs saved to: $LOG_DIR/retry-test.log"
    echo ""
    cat "$LOG_DIR/retry-test.log"
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}  RETRY TESTING COMPLETED!${NC}"
    echo "=========================================="
    echo ""
    echo "To observe retries in real-time, use Kiali:"
    echo "  istioctl dashboard kiali"
    echo ""
    echo "Or check Envoy access logs:"
    echo "  kubectl logs <pod> -n $NAMESPACE -c istio-proxy -f"
    echo ""
}

# Main
main() {
    echo "Test started at: $(date)" > "$LOG_DIR/retry-test.log"
    echo "" >> "$LOG_DIR/retry-test.log"
    
    test_virtualservices_exist
    test_retry_configuration
    test_with_fault_injection
    test_envoy_logs
    test_proxy_config
    generate_summary
}

main "$@"
