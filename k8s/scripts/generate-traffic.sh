#!/bin/bash

# Script to generate traffic for Kiali visualization
# This helps populate the service mesh topology with traffic data

NAMESPACE="petclinic"
REQUESTS=20

echo "=========================================="
echo "  GENERATING TRAFFIC FOR SERVICE MESH"
echo "=========================================="
echo ""

# Get API Gateway pod
API_GW=$(kubectl get pod -n $NAMESPACE -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')

if [ -z "$API_GW" ]; then
    echo "❌ API Gateway pod not found!"
    exit 1
fi

echo "✓ Found API Gateway pod: $API_GW"
echo ""
echo "Sending $REQUESTS requests to each service..."
echo ""

for i in $(seq 1 $REQUESTS); do
    echo -n "Request $i/$REQUESTS: "
    
    # Call Customers Service
    kubectl exec -n $NAMESPACE $API_GW -c api-gateway -- \
        curl -s -o /dev/null -w "Customers(%{http_code}) " \
        http://customers-service:8081/actuator/health 2>/dev/null
    
    # Call Vets Service
    kubectl exec -n $NAMESPACE $API_GW -c api-gateway -- \
        curl -s -o /dev/null -w "Vets(%{http_code}) " \
        http://vets-service:8083/actuator/health 2>/dev/null
    
    # Call Visits Service
    kubectl exec -n $NAMESPACE $API_GW -c api-gateway -- \
        curl -s -o /dev/null -w "Visits(%{http_code})" \
        http://visits-service:8082/actuator/health 2>/dev/null
    
    echo ""
    sleep 0.5
done

echo ""
echo "=========================================="
echo "✅ Traffic generation completed!"
echo "=========================================="
echo ""
echo "Now open Kiali dashboard:"
echo "  1. kubectl port-forward svc/kiali -n istio-system 20000:20000"
echo "  2. Open: http://localhost:20000/kiali"
echo "  3. Navigate to: Graph → Select 'petclinic' namespace"
echo ""
