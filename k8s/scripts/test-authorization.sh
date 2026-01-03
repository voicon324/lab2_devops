#!/bin/bash
# test-authorization.sh - Script để kiểm tra Authorization Policies
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  AUTHORIZATION POLICY TESTING SCRIPT"
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

# Test 1: Verify Authorization Policies are applied
test_policies_exist() {
    echo -e "${YELLOW}[Test 1] Verifying Authorization Policies exist...${NC}"
    
    POLICIES=$(kubectl get authorizationpolicy -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    echo "Found policies: $POLICIES"
    
    EXPECTED_POLICIES=("deny-all" "allow-api-gateway-to-services" "allow-config-server-access" "allow-discovery-server-access")
    
    for policy in "${EXPECTED_POLICIES[@]}"; do
        if echo "$POLICIES" | grep -q "$policy"; then
            echo -e "${GREEN}✓ Policy '$policy' exists${NC}"
            echo "Policy $policy: EXISTS" >> "$LOG_DIR/authorization-test.log"
        else
            echo -e "${RED}✗ Policy '$policy' not found${NC}"
            echo "Policy $policy: MISSING" >> "$LOG_DIR/authorization-test.log"
        fi
    done
}

# Test 2: Test allowed connection (API Gateway -> Customers Service)
test_allowed_connection() {
    echo ""
    echo -e "${YELLOW}[Test 2] Testing ALLOWED connection (API Gateway -> Customers Service)...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No api-gateway pod found${NC}"
        return 1
    fi
    
    echo "Testing from $SOURCE_POD..."
    
    RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c api-gateway -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://customers-service:8081/actuator/health 2>/dev/null || echo "FAILED")
    
    if [ "$RESULT" == "200" ]; then
        echo -e "${GREEN}✓ PASS: API Gateway can access Customers Service (HTTP $RESULT)${NC}"
        echo "API Gateway -> Customers Service: ALLOWED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    else
        echo -e "${RED}✗ FAIL: Expected HTTP 200, got $RESULT${NC}"
        echo "API Gateway -> Customers Service: FAILED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    fi
}

# Test 3: Test allowed connection (API Gateway -> Vets Service)
test_allowed_vets_connection() {
    echo ""
    echo -e "${YELLOW}[Test 3] Testing ALLOWED connection (API Gateway -> Vets Service)...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c api-gateway -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://vets-service:8083/actuator/health 2>/dev/null || echo "FAILED")
    
    if [ "$RESULT" == "200" ]; then
        echo -e "${GREEN}✓ PASS: API Gateway can access Vets Service (HTTP $RESULT)${NC}"
        echo "API Gateway -> Vets Service: ALLOWED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    else
        echo -e "${RED}✗ FAIL: Expected HTTP 200, got $RESULT${NC}"
        echo "API Gateway -> Vets Service: FAILED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    fi
}

# Test 4: Test denied connection (create unauthorized pod)
test_denied_connection() {
    echo ""
    echo -e "${YELLOW}[Test 4] Testing DENIED connection (unauthorized pod -> service)...${NC}"
    
    # Create a test pod that should be denied
    echo "Creating unauthorized test pod..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-unauthorized
  namespace: $NAMESPACE
  labels:
    app: unauthorized-app
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
EOF

    # Wait for pod to be ready
    echo "Waiting for test pod..."
    kubectl wait --for=condition=ready pod/test-unauthorized -n $NAMESPACE --timeout=120s 2>/dev/null || true
    sleep 10
    
    echo "Testing unauthorized access to customers-service..."
    RESULT=$(kubectl exec test-unauthorized -n $NAMESPACE -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://customers-service:8081/actuator/health 2>/dev/null || echo "CONNECTION_REFUSED")
    
    if [ "$RESULT" == "403" ] || [ "$RESULT" == "CONNECTION_REFUSED" ] || [ "$RESULT" == "000" ]; then
        echo -e "${GREEN}✓ PASS: Unauthorized access was denied (HTTP $RESULT)${NC}"
        echo "Unauthorized -> Customers Service: DENIED ($RESULT)" >> "$LOG_DIR/authorization-test.log"
    elif [ "$RESULT" == "503" ]; then
        echo -e "${GREEN}✓ PASS: Unauthorized access returned 503 (Service Unavailable due to policy)${NC}"
        echo "Unauthorized -> Customers Service: DENIED (503)" >> "$LOG_DIR/authorization-test.log"
    else
        echo -e "${RED}✗ FAIL: Expected 403 or connection refused, got $RESULT${NC}"
        echo "Unauthorized -> Customers Service: FAILED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    fi
    
    # Cleanup
    echo "Cleaning up test pod..."
    kubectl delete pod test-unauthorized -n $NAMESPACE --ignore-not-found=true
}

# Test 5: Test Config Server access (should be allowed for all services)
test_config_access() {
    echo ""
    echo -e "${YELLOW}[Test 5] Testing Config Server access (allowed for all)...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=customers-service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No customers-service pod found${NC}"
        return 1
    fi
    
    RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c customers-service -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://config-server:8888/actuator/health 2>/dev/null || echo "FAILED")
    
    if [ "$RESULT" == "200" ]; then
        echo -e "${GREEN}✓ PASS: service can access Config Server (HTTP $RESULT)${NC}"
        echo "Customers -> Config Server: ALLOWED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    else
        echo -e "${YELLOW}! Connection returned HTTP $RESULT${NC}"
        echo "Customers -> Config Server: HTTP $RESULT" >> "$LOG_DIR/authorization-test.log"
    fi
}

# Test 6: Test Discovery Server access
test_discovery_access() {
    echo ""
    echo -e "${YELLOW}[Test 6] Testing Discovery Server access (allowed for all)...${NC}"
    
    SOURCE_POD=$(kubectl get pods -n $NAMESPACE -l app=vets-service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$SOURCE_POD" ]; then
        echo -e "${RED}No vets-service pod found${NC}"
        return 1
    fi
    
    RESULT=$(kubectl exec $SOURCE_POD -n $NAMESPACE -c vets-service -- \
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 http://discovery-server:8761/actuator/health 2>/dev/null || echo "FAILED")
    
    if [ "$RESULT" == "200" ]; then
        echo -e "${GREEN}✓ PASS: Service can access Discovery Server (HTTP $RESULT)${NC}"
        echo "Vets -> Discovery Server: ALLOWED (HTTP $RESULT)" >> "$LOG_DIR/authorization-test.log"
    else
        echo -e "${YELLOW}! Connection returned HTTP $RESULT${NC}"
        echo "Vets -> Discovery Server: HTTP $RESULT" >> "$LOG_DIR/authorization-test.log"
    fi
}

# Generate summary
generate_summary() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo "=========================================="
    
    echo ""
    echo "Test logs saved to: $LOG_DIR/authorization-test.log"
    echo ""
    cat "$LOG_DIR/authorization-test.log"
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}  AUTHORIZATION TESTING COMPLETED!${NC}"
    echo "=========================================="
}

# Main
main() {
    echo "Test started at: $(date)" > "$LOG_DIR/authorization-test.log"
    echo "" >> "$LOG_DIR/authorization-test.log"
    
    test_policies_exist
    test_allowed_connection
    test_allowed_vets_connection
    test_denied_connection
    test_config_access
    test_discovery_access
    generate_summary
}

main "$@"
