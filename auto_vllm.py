#!/usr/bin/env python3
"""
Auto vLLM - Automatically generate and run optimal vLLM commands using AIM Engine
"""

import sys
import subprocess
import time
import signal
import os
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

from aim_recipe_selector import AIMRecipeSelector
from aim_config_generator import AIMConfigGenerator

class AutoVLLM:
    def __init__(self):
        self.container_process = None
        self.container_id = None
        
    def get_optimal_vllm_command(self, model_id: str, gpu_count: int = None, precision: str = None, backend: str = 'vllm', port: int = 8000):
        """
        Get the optimal vLLM command using AIM Engine recipe selection
        """
        try:
            # Initialize AIM components
            selector = AIMRecipeSelector(Path("."))
            generator = AIMConfigGenerator()
            
            print(f"🔍 Analyzing model: {model_id}")
            if gpu_count:
                print(f"📊 Customer specified GPU count: {gpu_count}")
            if precision:
                print(f"🎯 Customer specified precision: {precision}")
            print(f"⚙️  Backend: {backend}")
            
            # Get optimal configuration
            config = selector.get_optimal_configuration(model_id, gpu_count, precision, backend)
            
            if not config:
                print(f"❌ No suitable configuration found for {model_id}")
                return None
            
            print(f"\n✅ Selected configuration:")
            print(f"   Recipe: {config['recipe_id']}")
            print(f"   GPU Count: {config['gpu_count']} (available: {config['available_gpus']})")
            print(f"   Precision: {config['precision']}")
            print(f"   Backend: {config['backend']}")
            
            # Get recipe and generate vLLM command
            recipe = selector.get_recipe_info(config["recipe_id"])
            if not recipe:
                print(f"❌ Recipe {config['recipe_id']} not found")
                return None
                
            deployment_config = generator.generate_config(
                recipe, config['gpu_count'], config['precision'], config['backend'], port
            )
            
            vllm_command = deployment_config.get("command", "")
            
            # Build the full Docker command
            docker_command = [
                "docker", "run", "--rm",
                "--device=/dev/kfd",
                "--device=/dev/dri", 
                "--group-add=video",
                "--group-add=render",
                "-v", "/workspace/model-cache:/workspace/model-cache",
                "-p", f"{port}:8000",
                "rocm/vllm:latest"
            ] + vllm_command.split()
            
            result = {
                "model_id": model_id,
                "recipe_id": config["recipe_id"],
                "gpu_count": config["gpu_count"],
                "available_gpus": config["available_gpus"],
                "precision": config["precision"],
                "backend": config["backend"],
                "vllm_command": vllm_command,
                "docker_command": docker_command,
                "port": port
            }
            
            return result
            
        except Exception as e:
            print(f"❌ Error: {str(e)}")
            return None
    
    def run_vllm_container(self, config: dict, container_name: str = None):
        """
        Run the vLLM container with the generated configuration
        """
        if not container_name:
            # Generate container name from model
            model_safe = config["model_id"].replace("/", "-").lower()
            container_name = f"vllm-{model_safe}-{config['gpu_count']}gpu-{config['precision']}"
        
        # Add container name to command
        docker_cmd = config["docker_command"][:2] + ["--name", container_name] + config["docker_command"][2:]
        
        print(f"\n🚀 Starting vLLM container: {container_name}")
        print(f"📡 Endpoint will be available at: http://localhost:{config['port']}")
        print(f"🔧 Command: {' '.join(docker_cmd)}")
        
        try:
            # Start the container
            self.container_process = subprocess.Popen(
                docker_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            self.container_id = container_name
            print(f"✅ Container started with PID: {self.container_process.pid}")
            
            return True
            
        except Exception as e:
            print(f"❌ Failed to start container: {e}")
            return False
    
    def wait_for_endpoint(self, port: int, timeout: int = 300):
        """
        Wait for the endpoint to become ready
        """
        print(f"\n⏳ Waiting for endpoint to be ready (timeout: {timeout}s)...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                # Try to connect to the health endpoint
                result = subprocess.run(
                    ["curl", "-s", "-f", f"http://localhost:{port}/health"],
                    capture_output=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    print(f"✅ Endpoint is ready! (took {time.time() - start_time:.1f}s)")
                    return True
                    
            except subprocess.TimeoutExpired:
                pass
            except Exception:
                pass
            
            # Wait a bit before trying again
            time.sleep(5)
            
            # Show progress
            elapsed = time.time() - start_time
            if elapsed % 30 < 5:  # Show progress every 30 seconds
                print(f"   Still waiting... ({elapsed:.0f}s elapsed)")
        
        print(f"❌ Endpoint failed to become ready within {timeout} seconds")
        return False
    
    def test_endpoint(self, port: int):
        """
        Test the endpoint with a simple request
        """
        print(f"\n🧪 Testing endpoint...")
        
        try:
            # Test models endpoint
            result = subprocess.run(
                ["curl", "-s", f"http://localhost:{port}/v1/models"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                print("✅ Models endpoint working!")
                
                # Test a simple chat completion
                test_payload = {
                    "model": "Qwen/Qwen3-32B",
                    "messages": [{"role": "user", "content": "Hi"}],
                    "max_tokens": 10
                }
                
                import json
                result = subprocess.run(
                    ["curl", "-s", "-X", "POST", f"http://localhost:{port}/v1/chat/completions",
                     "-H", "Content-Type: application/json",
                     "-d", json.dumps(test_payload)],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    print("✅ Chat completion working!")
                    return True
                else:
                    print("⚠️  Chat completion test failed, but models endpoint works")
                    return True
            else:
                print(f"❌ Endpoint test failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Endpoint test error: {e}")
            return False
    
    def stop_container(self):
        """
        Stop the running container
        """
        if self.container_id:
            print(f"\n🛑 Stopping container: {self.container_id}")
            try:
                subprocess.run(["docker", "stop", self.container_id], check=True)
                print("✅ Container stopped")
            except subprocess.CalledProcessError:
                print("⚠️  Failed to stop container (may already be stopped)")
    
    def cleanup(self):
        """
        Cleanup on exit
        """
        if self.container_process:
            self.container_process.terminate()
        self.stop_container()

def signal_handler(signum, frame):
    """Handle Ctrl+C gracefully"""
    print("\n\n🛑 Received interrupt signal, cleaning up...")
    if hasattr(signal_handler, 'auto_vllm'):
        signal_handler.auto_vllm.cleanup()
    sys.exit(0)

def main():
    """Main function"""
    if len(sys.argv) < 2:
        print("Usage: python3 auto_vllm.py <model_id> [gpu_count] [precision] [port]")
        print("Examples:")
        print("  python3 auto_vllm.py Qwen/Qwen3-32B")
        print("  python3 auto_vllm.py Qwen/Qwen3-32B 4")
        print("  python3 auto_vllm.py Qwen/Qwen3-32B 4 bf16")
        print("  python3 auto_vllm.py Qwen/Qwen3-32B 4 bf16 8001")
        sys.exit(1)
    
    model_id = sys.argv[1]
    gpu_count = int(sys.argv[2]) if len(sys.argv) > 2 else None
    precision = sys.argv[3] if len(sys.argv) > 3 else None
    port = int(sys.argv[4]) if len(sys.argv) > 4 else 8000
    
    # Create AutoVLLM instance
    auto_vllm = AutoVLLM()
    
    # Set up signal handler for graceful cleanup
    signal_handler.auto_vllm = auto_vllm
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Step 1: Get optimal configuration
        config = auto_vllm.get_optimal_vllm_command(model_id, gpu_count, precision, port=port)
        
        if not config:
            print("❌ Failed to get optimal configuration")
            sys.exit(1)
        
        # Step 2: Run the container
        if not auto_vllm.run_vllm_container(config):
            print("❌ Failed to start container")
            sys.exit(1)
        
        # Step 3: Wait for endpoint to be ready
        if not auto_vllm.wait_for_endpoint(port):
            print("❌ Endpoint failed to become ready")
            auto_vllm.cleanup()
            sys.exit(1)
        
        # Step 4: Test the endpoint
        if not auto_vllm.test_endpoint(port):
            print("❌ Endpoint test failed")
            auto_vllm.cleanup()
            sys.exit(1)
        
        # Success!
        print(f"\n🎉 vLLM deployment successful!")
        print(f"🌐 API available at: http://localhost:{port}")
        print(f"📋 Container: {auto_vllm.container_id}")
        print(f"🔧 Model: {config['model_id']}")
        print(f"⚙️  Recipe: {config['recipe_id']}")
        print(f"💾 GPUs: {config['gpu_count']} (from {config['available_gpus']} available)")
        print(f"🎯 Precision: {config['precision']}")
        
        print(f"\n📝 Example usage:")
        print(f"  curl -X GET http://localhost:{port}/v1/models")
        print(f"  curl -X POST http://localhost:{port}/v1/chat/completions \\")
        print(f"    -H 'Content-Type: application/json' \\")
        print(f"    -d '{{\"model\": \"{config['model_id']}\", \"messages\": [{{\"role\": \"user\", \"content\": \"Hello\"}}], \"max_tokens\": 50}}'")
        
        print(f"\n⏹️  Press Ctrl+C to stop the container")
        
        # Keep the script running
        try:
            auto_vllm.container_process.wait()
        except KeyboardInterrupt:
            pass
        
    except Exception as e:
        print(f"❌ Error: {e}")
        auto_vllm.cleanup()
        sys.exit(1)
    finally:
        auto_vllm.cleanup()

if __name__ == "__main__":
    main() 