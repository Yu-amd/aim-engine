#!/usr/bin/env python3
"""
Example usage of AIM Engine

This script demonstrates various use cases of the AIM Engine for AI model deployment.
"""

import json
from pathlib import Path
from aim_launcher import AIMEngine


def main():
    """Demonstrate AIM Engine usage"""
    
    # Initialize AIM Engine
    launcher = AIMEngine()
    
    print("🚀 AIM Engine - AI Model Deployment Examples")
    print("=" * 50)
    
    # Example 1: Auto-detection (no parameters specified)
    print("\n📋 Example 1: Auto-detection")
    print("-" * 30)
    print("Launching Qwen/Qwen3-32B with auto-detected GPUs and optimal precision...")
    
    result = launcher.launch_model("Qwen/Qwen3-32B")
    
    if result["success"]:
        print("✅ Model launched successfully!")
        print(f"   Model: {result['model_id']}")
        print(f"   Recipe: {result['recipe_id']}")
        print(f"   GPUs: {result['gpu_count']} (available: {result['available_gpus']})")
        print(f"   Precision: {result['precision']}")
        print(f"   Backend: {result['backend']}")
        print(f"   Endpoint: {result['endpoint_url']}")
        print(f"   Auto-selected GPU count: {result['auto_selected']['gpu_count']}")
        print(f"   Auto-selected precision: {result['auto_selected']['precision']}")
    else:
        print(f"❌ Failed to launch model: {result['error']}")
    
    # Example 2: Customer specified GPU count
    print("\n📋 Example 2: Customer specified GPU count")
    print("-" * 30)
    print("Launching Qwen/Qwen3-32B with 4 GPUs (auto-selected precision)...")
    
    result = launcher.launch_model("Qwen/Qwen3-32B", gpu_count=4)
    
    if result["success"]:
        print("✅ Model launched successfully!")
        print(f"   Model: {result['model_id']}")
        print(f"   GPUs: {result['gpu_count']} (requested: 4)")
        print(f"   Precision: {result['precision']} (auto-selected)")
        print(f"   Endpoint: {result['endpoint_url']}")
    else:
        print(f"❌ Failed to launch model: {result['error']}")
    
    # Example 3: Customer specified precision
    print("\n📋 Example 3: Customer specified precision")
    print("-" * 30)
    print("Launching Qwen/Qwen3-32B with bf16 precision (auto-detected GPUs)...")
    
    result = launcher.launch_model("Qwen/Qwen3-32B", precision="bf16")
    
    if result["success"]:
        print("✅ Model launched successfully!")
        print(f"   Model: {result['model_id']}")
        print(f"   GPUs: {result['gpu_count']} (auto-detected)")
        print(f"   Precision: {result['precision']} (requested: bf16)")
        print(f"   Endpoint: {result['endpoint_url']}")
    else:
        print(f"❌ Failed to launch model: {result['error']}")
    
    # Example 4: Get optimal configuration without deploying
    print("\n📋 Example 4: Get optimal configuration")
    print("-" * 30)
    print("Getting optimal configuration for Qwen/Qwen3-32B...")
    
    result = launcher.get_optimal_configuration("Qwen/Qwen3-32B")
    
    if result["success"]:
        config = result["configuration"]
        print("✅ Optimal configuration found!")
        print(f"   Recipe: {config['recipe_id']}")
        print(f"   GPUs: {config['gpu_count']} (available: {config['available_gpus']})")
        print(f"   Precision: {config['precision']}")
        print(f"   Backend: {config['backend']}")
        print(f"   Configuration: {json.dumps(config['config'], indent=2)}")
    else:
        print(f"❌ Failed to get configuration: {result['error']}")
    
    # Example 5: Show all available configurations
    print("\n📋 Example 5: Show available configurations")
    print("-" * 30)
    print("Showing all available configurations for Qwen/Qwen3-32B...")
    
    result = launcher.show_model_configurations("Qwen/Qwen3-32B")
    
    if result["success"]:
        print("✅ Available configurations:")
        for config_key, config_info in result["configurations"].items():
            print(f"   {config_key}:")
            print(f"     Recipe: {config_info['recipe_id']}")
            print(f"     GPUs: {config_info['gpu_count']}")
            print(f"     Precision: {config_info['precision']}")
            print(f"     Backend: {config_info['backend']}")
            print(f"     Enabled: {config_info['enabled']}")
    else:
        print(f"❌ Failed to get configurations: {result['error']}")
    
    # Example 6: List running models
    print("\n📋 Example 6: List running models")
    print("-" * 30)
    
    result = launcher.list_models()
    
    if result["success"]:
        if result["containers"]:
            print("✅ Running models:")
            for container in result["containers"]:
                print(f"   {container['name']}: {container['status']}")
        else:
            print("ℹ️  No models currently running")
    else:
        print(f"❌ Failed to list models: {result['error']}")
    
    # Example 7: Advanced usage with specific requirements
    print("\n📋 Example 7: Advanced usage")
    print("-" * 30)
    print("Launching with specific GPU count, precision, and backend...")
    
    result = launcher.launch_model(
        model_id="Qwen/Qwen3-32B",
        gpu_count=2,
        precision="bf16",
        backend="vllm",
        port=8001,
        container_name="my-custom-qwen-model"
    )
    
    if result["success"]:
        print("✅ Advanced model launch successful!")
        print(f"   Container: {result['container_name']}")
        print(f"   Endpoint: {result['endpoint_url']}")
        print(f"   Configuration: {json.dumps(result['config'], indent=2)}")
    else:
        print(f"❌ Failed to launch model: {result['error']}")
    
    print("\n🎉 AIM Engine examples completed!")
    print("\n💡 Key Features Demonstrated:")
    print("   • Auto-GPU detection")
    print("   • Optimal precision selection")
    print("   • Recipe-based configuration")
    print("   • Flexible parameter specification")
    print("   • Configuration preview without deployment")
    print("   • Model lifecycle management")


if __name__ == "__main__":
    main() 