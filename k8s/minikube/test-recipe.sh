#!/bin/bash

# Test script for AIM Engine recipe functionality in Minikube
# Usage: ./test-recipe.sh

set -e

echo "🧪 Testing AIM Engine recipe functionality in Minikube..."

# Check if deployment is running
check_deployment() {
    echo "🔍 Checking deployment status..."
    
    if ! kubectl get deployment aim-engine -n aim-engine &> /dev/null; then
        echo "❌ AIM Engine deployment not found"
        exit 1
    fi
    
    if ! kubectl get pods -n aim-engine -l app=aim-engine | grep -q Running; then
        echo "❌ AIM Engine pods not running"
        exit 1
    fi
    
    echo "✅ Deployment is running"
}

# Test recipe configuration
test_recipe_config() {
    echo "🎯 Testing recipe configuration..."
    
    if ! kubectl get configmap aim-engine-recipe-config -n aim-engine &> /dev/null; then
        echo "❌ Recipe configuration not found"
        exit 1
    fi
    
    echo "✅ Recipe configuration exists"
    
    # Display recipe info
    echo "📋 Recipe Configuration:"
    kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml | grep -A 20 "data:"
}

# Test service endpoints
test_endpoints() {
    echo "🌐 Testing service endpoints..."
    
    # Start port forward in background
    echo "Starting port forward..."
    kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine &
    PF_PID=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Test main endpoint
    echo "Testing main endpoint..."
    if curl -s http://localhost:8000/ | grep -q "AIM Engine Running"; then
        echo "✅ Main endpoint working"
    else
        echo "❌ Main endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Test recipe endpoint
    echo "Testing recipe endpoint..."
    if curl -s http://localhost:8000/recipe | jq -r '.recipe_id' &> /dev/null; then
        echo "✅ Recipe endpoint working"
        echo "📋 Recipe Info:"
        curl -s http://localhost:8000/recipe | jq '.'
    else
        echo "❌ Recipe endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Test metrics endpoint
    echo "Testing metrics endpoint..."
    if curl -s http://localhost:8000/metrics | grep -q "aim_recipe_selection_total"; then
        echo "✅ Metrics endpoint working"
        echo "📊 Sample Metrics:"
        curl -s http://localhost:8000/metrics | grep "aim_" | head -5
    else
        echo "❌ Metrics endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if curl -s http://localhost:8000/health | jq -r '.status' | grep -q "healthy"; then
        echo "✅ Health endpoint working"
    else
        echo "❌ Health endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop port forward
    kill $PF_PID 2>/dev/null || true
    echo "✅ All endpoints working correctly"
}

# Test monitoring (if available)
test_monitoring() {
    echo "📊 Testing monitoring setup..."
    
    if kubectl get namespace aim-engine-monitoring &> /dev/null; then
        echo "✅ Monitoring namespace exists"
        
        if kubectl get servicemonitor aim-engine-recipe-monitor -n aim-engine-monitoring &> /dev/null; then
            echo "✅ ServiceMonitor configured"
        else
            echo "⚠️  ServiceMonitor not found (Prometheus Operator may not be installed)"
        fi
        
        if kubectl get prometheusrule aim-engine-recipe-alerts -n aim-engine-monitoring &> /dev/null; then
            echo "✅ PrometheusRule configured"
        else
            echo "⚠️  PrometheusRule not found"
        fi
    else
        echo "⚠️  Monitoring not enabled"
    fi
}

# Show logs
show_logs() {
    echo "📝 Recent logs:"
    kubectl logs -n aim-engine deployment/aim-engine --tail=20
}

# Main test execution
main() {
    check_deployment
    test_recipe_config
    test_endpoints
    test_monitoring
    show_logs
    
    echo ""
    echo "🎉 All tests passed! AIM Engine recipe functionality is working in Minikube."
    echo ""
    echo "📋 Next steps:"
    echo "   - Access the web interface: minikube service aim-engine-service -n aim-engine"
    echo "   - View metrics: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine && curl http://localhost:8000/metrics"
    echo "   - Check recipe info: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine && curl http://localhost:8000/recipe"
}

# Run main function
main 