#!/bin/bash
# deploy-app.sh - Script để deploy Spring PetClinic microservices
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  PETCLINIC APPLICATION DEPLOYMENT"
echo "=========================================="

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

# Kiểm tra namespace
check_namespace() {
    echo -e "${YELLOW}[1/6] Checking namespace...${NC}"
    
    if ! kubectl get namespace petclinic &> /dev/null; then
        echo "Creating petclinic namespace..."
        kubectl apply -f "$K8S_DIR/namespace.yaml"
    fi
    
    # Verify istio-injection label
    INJECTION=$(kubectl get namespace petclinic -o jsonpath='{.metadata.labels.istio-injection}')
    if [ "$INJECTION" != "enabled" ]; then
        echo -e "${RED}Istio injection is not enabled for petclinic namespace.${NC}"
        echo "Enabling istio-injection..."
        kubectl label namespace petclinic istio-injection=enabled --overwrite
    fi
    
    echo -e "${GREEN}Namespace petclinic is ready with istio-injection enabled.${NC}"
}

# Deploy infrastructure services
deploy_infrastructure() {
    echo -e "${YELLOW}[2/6] Deploying infrastructure services...${NC}"
    
    echo "Deploying Config Server..."
    kubectl apply -f "$K8S_DIR/deployments/config-server.yaml"
    
    echo "Waiting for Config Server to be ready..."
    kubectl wait --for=condition=ready pod -l app=config-server -n petclinic --timeout=300s
    
    echo "Deploying Discovery Server..."
    kubectl apply -f "$K8S_DIR/deployments/discovery-server.yaml"
    
    echo "Waiting for Discovery Server to be ready..."
    kubectl wait --for=condition=ready pod -l app=discovery-server -n petclinic --timeout=300s
    
    echo -e "${GREEN}Infrastructure services deployed successfully.${NC}"
}

# Deploy business services
deploy_services() {
    echo -e "${YELLOW}[3/6] Deploying business services...${NC}"
    
    echo "Deploying Customers Service..."
    kubectl apply -f "$K8S_DIR/deployments/customers-service.yaml"
    
    echo "Deploying Visits Service..."
    kubectl apply -f "$K8S_DIR/deployments/visits-service.yaml"
    
    echo "Deploying Vets Service..."
    kubectl apply -f "$K8S_DIR/deployments/vets-service.yaml"
    
    echo "Deploying GenAI Service..."
    kubectl apply -f "$K8S_DIR/deployments/genai-service.yaml"
    
    echo "Waiting for services to be ready..."
    kubectl wait --for=condition=ready pod -l app=customers-service -n petclinic --timeout=300s
    kubectl wait --for=condition=ready pod -l app=visits-service -n petclinic --timeout=300s
    kubectl wait --for=condition=ready pod -l app=vets-service -n petclinic --timeout=300s
    kubectl wait --for=condition=ready pod -l app=genai-service -n petclinic --timeout=300s
    
    echo -e "${GREEN}Business services deployed successfully.${NC}"
}

# Deploy API Gateway
deploy_gateway() {
    echo -e "${YELLOW}[4/6] Deploying API Gateway...${NC}"
    
    kubectl apply -f "$K8S_DIR/deployments/api-gateway.yaml"
    
    echo "Waiting for API Gateway to be ready..."
    kubectl wait --for=condition=ready pod -l app=api-gateway -n petclinic --timeout=300s
    
    echo -e "${GREEN}API Gateway deployed successfully.${NC}"
}

# Apply Istio configurations
apply_istio_config() {
    echo -e "${YELLOW}[5/6] Applying Istio configurations...${NC}"
    
    echo "Applying Destination Rules..."
    kubectl apply -f "$K8S_DIR/istio/destination-rules.yaml"
    
    echo "Applying Virtual Services (Retry policies)..."
    kubectl apply -f "$K8S_DIR/istio/virtual-services.yaml"
    
    echo "Applying Peer Authentication (mTLS)..."
    kubectl apply -f "$K8S_DIR/istio/peer-authentication.yaml"
    
    echo "Applying Authorization Policies..."
    kubectl apply -f "$K8S_DIR/istio/authorization-policies.yaml"
    
    echo -e "${GREEN}Istio configurations applied successfully.${NC}"
}

# Verify deployment
verify_deployment() {
    echo -e "${YELLOW}[6/6] Verifying deployment...${NC}"
    
    echo ""
    echo -e "${BLUE}===== PODS STATUS =====${NC}"
    kubectl get pods -n petclinic -o wide
    
    echo ""
    echo -e "${BLUE}===== SERVICES STATUS =====${NC}"
    kubectl get svc -n petclinic
    
    echo ""
    echo -e "${BLUE}===== ISTIO PROXY STATUS =====${NC}"
    kubectl get pods -n petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
    
    echo ""
    echo -e "${BLUE}===== VIRTUAL SERVICES =====${NC}"
    kubectl get virtualservices -n petclinic
    
    echo ""
    echo -e "${BLUE}===== DESTINATION RULES =====${NC}"
    kubectl get destinationrules -n petclinic
    
    echo ""
    echo -e "${BLUE}===== AUTHORIZATION POLICIES =====${NC}"
    kubectl get authorizationpolicies -n petclinic
    
    echo ""
    echo -e "${BLUE}===== PEER AUTHENTICATION =====${NC}"
    kubectl get peerauthentication -n petclinic
}

# Show access information
show_access_info() {
    echo ""
    echo "=========================================="
    echo "  ACCESS INFORMATION"
    echo "=========================================="
    echo ""
    
    # Get API Gateway service info
    GATEWAY_IP=$(kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    GATEWAY_PORT=$(kubectl get svc api-gateway -n petclinic -o jsonpath='{.spec.ports[0].port}')
    
    if [ "$GATEWAY_IP" == "pending" ] || [ -z "$GATEWAY_IP" ]; then
        echo "API Gateway LoadBalancer IP is pending..."
        echo ""
        echo "To access the application, use port-forward:"
        echo "  kubectl port-forward svc/api-gateway -n petclinic 8080:8080"
        echo "  Then open: http://localhost:8080"
    else
        echo "API Gateway is accessible at:"
        echo "  http://$GATEWAY_IP:$GATEWAY_PORT"
    fi
    
    echo ""
    echo "To view the service mesh topology:"
    echo "  istioctl dashboard kiali"
    echo ""
}

# Main
main() {
    echo ""
    check_namespace
    echo ""
    deploy_infrastructure
    echo ""
    deploy_services
    echo ""
    deploy_gateway
    echo ""
    apply_istio_config
    echo ""
    verify_deployment
    show_access_info
    
    echo "=========================================="
    echo -e "${GREEN}  DEPLOYMENT COMPLETED!${NC}"
    echo "=========================================="
    echo ""
}

main "$@"
