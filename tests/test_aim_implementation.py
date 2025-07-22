#!/usr/bin/env python3
"""
Test AIM Implementation

This script tests the AIM implementation components to ensure they work correctly.
"""

import json
import logging
import sys
from pathlib import Path

# Add the parent directory to Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from aim_recipe_selector import AIMRecipeSelector
from aim_config_generator import AIMConfigGenerator
from aim_docker_manager import AIMDockerManager
from aim_endpoint_manager import AIMEndpointManager


def setup_logging():
    """Setup logging for tests"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def test_recipe_selector():
    """Test the recipe selector component"""
    print("\n" + "="*50)
    print("TESTING: Recipe Selector")
    print("="*50)
    
    try:
        # Use the project root directory (parent of tests/)
        project_root = Path(__file__).parent.parent
        selector = AIMRecipeSelector(project_root)
        
        # Test loading recipes
        recipes = selector.list_available_recipes()
        print(f"✅ Loaded {len(recipes)} recipes")
        
        # Test loading models
        models = selector.list_available_models()
        print(f"✅ Loaded {len(models)} models")
        
        # Test recipe selection
        recipe = selector.select_recipe("Qwen/Qwen3-32B", 2, "bf16", "vllm")
        if recipe:
            print(f"✅ Recipe selection successful: {recipe['recipe_id']}")
        else:
            print("❌ Recipe selection failed")
            return False
        
        # Test supported configurations
        configs = selector.get_supported_configurations("Qwen/Qwen3-32B")
        print(f"✅ Got supported configurations: {len(configs['recipes'])} recipes")
        
        return True
        
    except Exception as e:
        print(f"❌ Recipe selector test failed: {str(e)}")
        return False


def test_config_generator():
    """Test the configuration generator component"""
    print("\n" + "="*50)
    print("TESTING: Configuration Generator")
    print("="*50)
    
    try:
        generator = AIMConfigGenerator()
        # Use the project root directory (parent of tests/)
        project_root = Path(__file__).parent.parent
        selector = AIMRecipeSelector(project_root)
        
        # Get a recipe to test with
        recipe = selector.select_recipe("Qwen/Qwen3-32B", 2, "bf16", "vllm")
        if not recipe:
            print("❌ No recipe available for testing")
            return False
        
        # Test configuration generation
        config = generator.generate_config(recipe, 2, "bf16", "vllm", 8000)
        print(f"✅ Configuration generation successful")
        print(f"   Recipe ID: {config['recipe_id']}")
        print(f"   Model ID: {config['model_id']}")
        print(f"   Command: {config['command'][:100]}...")
        
        # Test Docker Compose generation
        compose_content = generator.generate_compose_file(recipe, 2, "bf16", "vllm", 8000)
        print(f"✅ Docker Compose generation successful ({len(compose_content)} characters)")
        
        # Test Kubernetes YAML generation
        k8s_content = generator.generate_kubernetes_yaml(recipe, 2, "bf16", "vllm", 8000)
        print(f"✅ Kubernetes YAML generation successful ({len(k8s_content)} characters)")
        
        return True
        
    except Exception as e:
        print(f"❌ Configuration generator test failed: {str(e)}")
        return False


def test_docker_manager():
    """Test the Docker manager component"""
    print("\n" + "="*50)
    print("TESTING: Docker Manager")
    print("="*50)
    
    try:
        manager = AIMDockerManager()
        
        # Test Docker availability
        print("✅ Docker manager initialized successfully")
        
        # Test listing containers
        containers = manager.list_containers()
        print(f"✅ Container listing successful: {len(containers)} containers found")
        
        # Test container status (should work even if container doesn't exist)
        status = manager.get_container_status("test-container")
        if not status["success"]:
            print("✅ Container status check working (expected failure for non-existent container)")
        
        return True
        
    except Exception as e:
        print(f"❌ Docker manager test failed: {str(e)}")
        return False


def test_endpoint_manager():
    """Test the endpoint manager component"""
    print("\n" + "="*50)
    print("TESTING: Endpoint Manager")
    print("="*50)
    
    try:
        manager = AIMEndpointManager()
        
        # Test endpoint listing
        endpoints = manager.list_endpoints()
        print(f"✅ Endpoint listing successful: {endpoints['count']} endpoints")
        
        # Test health check (should fail for non-existent endpoint)
        health = manager.check_endpoint_health("http://localhost:9999")
        if not health["success"]:
            print("✅ Health check working (expected failure for non-existent endpoint)")
        
        # Test metrics (should fail for non-existent endpoint)
        metrics = manager.get_endpoint_metrics("http://localhost:9999")
        if not metrics["success"]:
            print("✅ Metrics check working (expected failure for non-existent endpoint)")
        
        return True
        
    except Exception as e:
        print(f"❌ Endpoint manager test failed: {str(e)}")
        return False


def test_integration():
    """Test integration between components"""
    print("\n" + "="*50)
    print("TESTING: Component Integration")
    print("="*50)
    
    try:
        # Test full workflow without actually launching containers
        # Use the project root directory (parent of tests/)
        project_root = Path(__file__).parent.parent
        selector = AIMRecipeSelector(project_root)
        generator = AIMConfigGenerator()
        
        # Select recipe
        recipe = selector.select_recipe("Qwen/Qwen3-32B", 2, "bf16", "vllm")
        if not recipe:
            print("❌ Recipe selection failed in integration test")
            return False
        
        # Generate configuration
        config = generator.generate_config(recipe, 2, "bf16", "vllm", 8000)
        if not config:
            print("❌ Configuration generation failed in integration test")
            return False
        
        # Validate configuration
        required_fields = ["recipe_id", "model_id", "command", "environment"]
        for field in required_fields:
            if field not in config:
                print(f"❌ Missing required field in config: {field}")
                return False
        
        print("✅ Integration test successful")
        print(f"   Recipe: {config['recipe_id']}")
        print(f"   Model: {config['model_id']}")
        print(f"   Backend: {config['backend']}")
        print(f"   Precision: {config['precision']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Integration test failed: {str(e)}")
        return False


def test_validation():
    """Test input validation"""
    print("\n" + "="*50)
    print("TESTING: Input Validation")
    print("="*50)
    
    try:
        # Use the project root directory (parent of tests/)
        project_root = Path(__file__).parent.parent
        selector = AIMRecipeSelector(project_root)
        
        # Test valid inputs
        valid_recipe = selector.select_recipe("Qwen/Qwen3-32B", 2, "bf16", "vllm")
        if valid_recipe:
            print("✅ Valid input validation successful")
        else:
            print("❌ Valid input validation failed")
            return False
        
        # Test invalid model
        invalid_model = selector.select_recipe("invalid/model", 2, "bf16", "vllm")
        if not invalid_model:
            print("✅ Invalid model validation successful")
        else:
            print("❌ Invalid model validation failed")
            return False
        
        # Test invalid GPU count
        invalid_gpu = selector.select_recipe("Qwen/Qwen3-32B", 10, "bf16", "vllm")
        if not invalid_gpu:
            print("✅ Invalid GPU count validation successful")
        else:
            print("❌ Invalid GPU count validation failed")
            return False
        
        # Test invalid precision
        invalid_precision = selector.select_recipe("Qwen/Qwen3-32B", 2, "invalid", "vllm")
        if not invalid_precision:
            print("✅ Invalid precision validation successful")
        else:
            print("❌ Invalid precision validation failed")
            return False
        
        return True
        
    except Exception as e:
        print(f"❌ Validation test failed: {str(e)}")
        return False


def main():
    """Run all tests"""
    setup_logging()
    
    print("🧪 AIM Implementation Test Suite")
    print("Testing all components of the AIM system...")
    
    tests = [
        ("Recipe Selector", test_recipe_selector),
        ("Configuration Generator", test_config_generator),
        ("Docker Manager", test_docker_manager),
        ("Endpoint Manager", test_endpoint_manager),
        ("Integration", test_integration),
        ("Validation", test_validation)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} test PASSED")
            else:
                print(f"❌ {test_name} test FAILED")
        except Exception as e:
            print(f"❌ {test_name} test ERROR: {str(e)}")
    
    print("\n" + "="*50)
    print("TEST RESULTS")
    print("="*50)
    print(f"Passed: {passed}/{total}")
    print(f"Failed: {total - passed}/{total}")
    
    if passed == total:
        print("🎉 All tests passed! AIM implementation is ready.")
        return 0
    else:
        print("⚠️  Some tests failed. Please check the implementation.")
        return 1


if __name__ == "__main__":
    sys.exit(main()) 