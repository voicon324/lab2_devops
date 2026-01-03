#!/bin/bash
# install-istio.sh - Script để cài đặt Istio trên K8S cluster
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  ISTIO INSTALLATION SCRIPT"
echo "=========================================="

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Kiểm tra kubectl
check_kubectl() {
    echo -e "${YELLOW}[1/6] Checking kubectl...${NC}"
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)${NC}"
}

# Kiểm tra cluster connection
check_cluster() {
    echo -e "${YELLOW}[2/6] Checking K8S cluster connection...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Cannot connect to K8S cluster. Please check your kubeconfig.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Connected to cluster successfully.${NC}"
    kubectl cluster-info
}

# Download istioctl nếu chưa có
download_istioctl() {
    echo -e "${YELLOW}[3/6] Checking istioctl...${NC}"
    
    if command -v istioctl &> /dev/null; then
        echo -e "${GREEN}istioctl already installed: $(istioctl version --remote=false 2>/dev/null)${NC}"
        return 0
    fi
    
    echo "Downloading Istio..."
    ISTIO_VERSION="1.20.2"  # Latest stable version
    
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    
    # Add to PATH
    export PATH="$PWD/istio-$ISTIO_VERSION/bin:$PATH"
    
    echo -e "${GREEN}istioctl downloaded successfully.${NC}"
}

# Cài đặt Istio với demo profile
install_istio() {
    echo -e "${YELLOW}[4/6] Installing Istio with demo profile...${NC}"
    
    # Install với demo profile (bao gồm nhiều features để test)
    istioctl install --set profile=demo -y
    
    echo -e "${GREEN}Istio installed successfully.${NC}"
}

# Verify installation
verify_installation() {
    echo -e "${YELLOW}[5/6] Verifying Istio installation...${NC}"
    
    # Kiểm tra Istio pods
    echo "Waiting for Istio pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
    kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n istio-system --timeout=300s
    
    echo -e "${GREEN}Istio pods are ready:${NC}"
    kubectl get pods -n istio-system
}

# Enable sidecar injection cho namespace
setup_namespace() {
    echo -e "${YELLOW}[6/6] Setting up petclinic namespace...${NC}"
    
    # Tạo namespace với label istio-injection
    kubectl apply -f ../namespace.yaml
    
    echo -e "${GREEN}Namespace petclinic created with Istio injection enabled.${NC}"
    kubectl get namespace petclinic --show-labels
}

# Main
main() {
    echo ""
    check_kubectl
    echo ""
    check_cluster
    echo ""
    download_istioctl
    echo ""
    install_istio
    echo ""
    verify_installation
    echo ""
    setup_namespace
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}  ISTIO INSTALLATION COMPLETED!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run install-kiali.sh to install Kiali dashboard"
    echo "  2. Run deploy-app.sh to deploy PetClinic application"
    echo ""
}

main "$@"
