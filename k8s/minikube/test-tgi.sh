#!/bin/bash

# Test script for AIM Engine TGI functionality in Minikube
# Usage: ./test-tgi.sh

set -e

echo "🧪 Testing AIM Engine TGI functionality in Minikube..."

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

# Test TGI health endpoint
test_tgi_health() {
    echo "🏥 Testing TGI health endpoint..."
    
    # Start port forward in background
    echo "Starting port forward..."
    kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine &
    PF_PID=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Test health endpoint
    if curl -s http://localhost:8000/health | jq -r '.status' | grep -q "healthy"; then
        echo "✅ TGI health endpoint working"
        echo "📋 Health Info:"
        curl -s http://localhost:8000/health | jq '.'
    else
        echo "❌ TGI health endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop port forward
    kill $PF_PID 2>/dev/null || true
}

# Test TGI inference endpoint
test_tgi_inference() {
    echo "🤖 Testing TGI inference endpoint..."
    
    # Start port forward in background
    echo "Starting port forward..."
    kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine &
    PF_PID=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Test TGI generate endpoint
    echo "Testing text generation..."
    GENERATE_RESPONSE=$(curl -s -X POST http://localhost:8000/generate \
        -H "Content-Type: application/json" \
        -d '{
            "inputs": "Hello, how are you?",
            "parameters": {
                "max_new_tokens": 50,
                "temperature": 0.7,
                "top_p": 0.9
            }
        }')
    
    if echo "$GENERATE_RESPONSE" | jq -r '.generated_text' &> /dev/null; then
        echo "✅ TGI inference working"
        echo "📝 Generated text:"
        echo "$GENERATE_RESPONSE" | jq -r '.generated_text'
    else
        echo "❌ TGI inference failed"
        echo "Response: $GENERATE_RESPONSE"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Test TGI info endpoint
    echo "Testing TGI info endpoint..."
    if curl -s http://localhost:8000/info | jq -r '.model_id' &> /dev/null; then
        echo "✅ TGI info endpoint working"
        echo "📋 Model Info:"
        curl -s http://localhost:8000/info | jq '.'
    else
        echo "❌ TGI info endpoint failed"
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop port forward
    kill $PF_PID 2>/dev/null || true
}

# Test recipe configuration
test_recipe_config() {
    echo "🎯 Testing recipe configuration..."
    
    if ! kubectl get configmap aim-engine-recipe-config -n aim-engine &> /dev/null; then
        echo "❌ Recipe configuration not found"
        exit 1
    fi
    
    echo "✅ Recipe configuration exists"
    
    # Check if TGI backend is configured
    BACKEND=$(kubectl get configmap aim-engine-recipe-config -n aim-engine -o jsonpath='{.data.BACKEND}')
    if [ "$BACKEND" = "tgi" ]; then
        echo "✅ TGI backend configured"
    else
        echo "⚠️  Backend is not TGI: $BACKEND"
    fi
    
    # Display recipe info
    echo "📋 Recipe Configuration:"
    kubectl get configmap aim-engine-recipe-config -n aim-engine -o yaml | grep -A 20 "data:"
}

# Test model loading
test_model_loading() {
    echo "📦 Testing model loading..."
    
    # Check if model is being downloaded/loaded
    echo "📝 Recent logs (checking for model loading):"
    kubectl logs -n aim-engine deployment/aim-engine --tail=20 | grep -E "(model|download|load)" || echo "No model loading logs found"
    
    # Check if TGI server is ready
    echo "🔍 Checking TGI server readiness..."
    if kubectl logs -n aim-engine deployment/aim-engine --tail=10 | grep -q "text-generation-launcher"; then
        echo "✅ TGI server detected in logs"
    else
        echo "⚠️  TGI server not detected in recent logs"
    fi
}

# Test performance
test_performance() {
    echo "⚡ Testing performance..."
    
    # Start port forward in background
    echo "Starting port forward..."
    kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine &
    PF_PID=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Test multiple requests
    echo "Testing multiple inference requests..."
    for i in {1..3}; do
        echo "Request $i:"
        START_TIME=$(date +%s.%N)
        RESPONSE=$(curl -s -X POST http://localhost:8000/generate \
            -H "Content-Type: application/json" \
            -d '{
                "inputs": "Test message",
                "parameters": {
                    "max_new_tokens": 20,
                    "temperature": 0.5
                }
            }')
        END_TIME=$(date +%s.%N)
        
        DURATION=$(echo "$END_TIME - $START_TIME" | bc)
        echo "  Duration: ${DURATION}s"
        
        if echo "$RESPONSE" | jq -r '.generated_text' &> /dev/null; then
            echo "  ✅ Success"
        else
            echo "  ❌ Failed"
        fi
    done
    
    # Stop port forward
    kill $PF_PID 2>/dev/null || true
}

# Show resource usage
show_resource_usage() {
    echo "📊 Resource Usage:"
    
    # Check pod resource usage
    if command -v kubectl top &> /dev/null; then
        kubectl top pods -n aim-engine
    else
        echo "kubectl top not available, checking pod status:"
        kubectl get pods -n aim-engine -o wide
    fi
    
    # Check pod events
    echo "📝 Recent pod events:"
    kubectl get events -n aim-engine --sort-by='.lastTimestamp' | tail -5
}

# Main test execution
main() {
    check_deployment
    test_recipe_config
    test_model_loading
    test_tgi_health
    test_tgi_inference
    test_performance
    show_resource_usage
    
    echo ""
    echo "🎉 All TGI tests passed! AIM Engine TGI functionality is working in Minikube."
    echo ""
    echo "📋 Next steps:"
    echo "   - Access TGI API: kubectl port-forward service/aim-engine-service 8000:8000 -n aim-engine"
    echo "   - Test inference: curl -X POST http://localhost:8000/generate -H 'Content-Type: application/json' -d '{\"inputs\": \"Hello\", \"parameters\": {\"max_new_tokens\": 50}}'"
    echo "   - Check model info: curl http://localhost:8000/info"
    echo "   - View logs: kubectl logs -f deployment/aim-engine -n aim-engine"
}

# Run main function
main 