#!/bin/bash
# install-kiali.sh - Script để cài đặt Kiali Dashboard
# Author: A (Khánh Duy)
# Date: 01/01/2026

set -e

echo "=========================================="
echo "  KIALI INSTALLATION SCRIPT"
echo "=========================================="

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Kiểm tra Istio đã được cài đặt
check_istio() {
    echo -e "${YELLOW}[1/4] Checking Istio installation...${NC}"
    
    if ! kubectl get namespace istio-system &> /dev/null; then
        echo -e "${RED}Istio is not installed. Please run install-istio.sh first.${NC}"
        exit 1
    fi
    
    if ! kubectl get pods -n istio-system -l app=istiod --no-headers | grep -q Running; then
        echo -e "${RED}Istiod is not running. Please check Istio installation.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Istio is installed and running.${NC}"
}

# Cài đặt Kiali
install_kiali() {
    echo -e "${YELLOW}[2/4] Installing Kiali...${NC}"
    
    # Kiali đã được bao gồm trong Istio demo profile
    # Chỉ cần apply thêm addons nếu chưa có
    
    # Check if Kiali is already installed
    if kubectl get deployment kiali -n istio-system &> /dev/null; then
        echo "Kiali is already installed."
    else
        echo "Installing Kiali from Istio addons..."
        
        # Download and apply Kiali addon
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
    fi
    
    echo -e "${GREEN}Kiali installation completed.${NC}"
}

# Cài đặt Prometheus và Grafana (dependencies cho Kiali)
install_dependencies() {
    echo -e "${YELLOW}[3/4] Installing Prometheus and Grafana...${NC}"
    
    # Prometheus
    if kubectl get deployment prometheus -n istio-system &> /dev/null; then
        echo "Prometheus is already installed."
    else
        echo "Installing Prometheus..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
    fi
    
    # Grafana
    if kubectl get deployment grafana -n istio-system &> /dev/null; then
        echo "Grafana is already installed."
    else
        echo "Installing Grafana..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
    fi
    
    # Jaeger (tracing)
    if kubectl get deployment jaeger -n istio-system &> /dev/null; then
        echo "Jaeger is already installed."
    else
        echo "Installing Jaeger..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
    fi
    
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
}

# Verify và hiển thị thông tin truy cập
verify_and_show_access() {
    echo -e "${YELLOW}[4/4] Verifying installation and showing access info...${NC}"
    
    # Wait for Kiali to be ready
    echo "Waiting for Kiali to be ready..."
    kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=300s
    
    echo -e "${GREEN}All observability tools are ready:${NC}"
    kubectl get pods -n istio-system -l 'app in (kiali,prometheus,grafana,jaeger)'
    
    echo ""
    echo "=========================================="
    echo "  ACCESS INFORMATION"
    echo "=========================================="
    echo ""
    echo "To access Kiali Dashboard:"
    echo "  istioctl dashboard kiali"
    echo ""
    echo "Or port-forward manually:"
    echo "  kubectl port-forward svc/kiali -n istio-system 20001:20001"
    echo "  Then open: http://localhost:20001"
    echo ""
    echo "To access Grafana:"
    echo "  kubectl port-forward svc/grafana -n istio-system 3000:3000"
    echo "  Then open: http://localhost:3000"
    echo ""
    echo "To access Jaeger (Tracing):"
    echo "  kubectl port-forward svc/tracing -n istio-system 16686:80"
    echo "  Then open: http://localhost:16686"
    echo ""
}

# Main
main() {
    echo ""
    check_istio
    echo ""
    install_dependencies
    echo ""
    install_kiali
    echo ""
    verify_and_show_access
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}  KIALI INSTALLATION COMPLETED!${NC}"
    echo "=========================================="
    echo ""
}

main "$@"
