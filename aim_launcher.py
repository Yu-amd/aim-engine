#!/usr/bin/env python3
"""
AIM (AI Model) Launcher for Single Node Deployment

This module provides a command-line interface for launching AI model inference
endpoints using AIM recipes and Docker containers.
"""

import argparse
import json
import logging
import os
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from aim_recipe_selector import AIMRecipeSelector
from aim_docker_manager import AIMDockerManager
from aim_endpoint_manager import AIMEndpointManager
from aim_config_generator import AIMConfigGenerator


class AIMEngine:
    """AIM Engine for AI Model Deployment"""
    
    def __init__(self, config_dir: str = ".", cache_dir: str = "/workspace/model-cache"):
        self.config_dir = Path(config_dir)
        self.cache_dir = Path(cache_dir)
        self.recipe_selector = AIMRecipeSelector(self.config_dir)
        self.docker_manager = AIMDockerManager()
        self.endpoint_manager = AIMEndpointManager()
        self.config_generator = AIMConfigGenerator()
        
        # Initialize cache manager if available
        try:
            from aim_cache_manager import AIMCacheManager
            self.cache_manager = AIMCacheManager(str(self.cache_dir))
            self.cache_enabled = True
            self.logger.info(f"Cache enabled at: {self.cache_dir}")
        except ImportError:
            self.cache_manager = None
            self.cache_enabled = False
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        self.logger = logging.getLogger(__name__)
        
        if self.cache_manager:
            self.cache_enabled = True
            self.logger.info(f"Cache enabled at: {self.cache_dir}")
        else:
            self.logger.warning("Cache manager not available - caching disabled")
    
    def validate_inputs(self, model_id: str, gpu_count: Optional[int] = None, 
                       precision: Optional[str] = None, backend: str = 'vllm') -> bool:
        """
        Validate user inputs
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs (optional - will auto-detect)
            precision: Precision format (optional - will auto-select)
            backend: Serving backend
            
        Returns:
            True if inputs are valid, False otherwise
        """
        # Validate model_id
        if not model_id or '/' not in model_id:
            self.logger.error("Invalid model_id. Must be in format 'org/model'")
            return False
        
        # Validate gpu_count if provided
        if gpu_count is not None:
            if not isinstance(gpu_count, int) or gpu_count < 1 or gpu_count > 8:
                self.logger.error("GPU count must be between 1 and 8")
                return False
        
        # Validate precision if provided
        if precision is not None:
            valid_precisions = ['fp16', 'bf16', 'fp8', 'int8', 'int4']
            if precision not in valid_precisions:
                self.logger.error(f"Precision must be one of: {valid_precisions}")
                return False
        
        # Validate backend
        valid_backends = ['vllm', 'sglang']
        if backend not in valid_backends:
            self.logger.error(f"Backend must be one of: {valid_backends}")
            return False
        
        return True
    
    def launch_model(self, model_id: str, gpu_count: Optional[int] = None, 
                    precision: Optional[str] = None, backend: str = 'vllm', 
                    port: int = 8000, container_name: Optional[str] = None) -> Dict:
        """
        Launch an AI model endpoint
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs (optional - will auto-detect)
            precision: Precision format (optional - will auto-select)
            backend: Serving backend
            port: Port for the inference endpoint
            container_name: Optional custom container name
            
        Returns:
            Dict containing deployment information
        """
        try:
            # Validate inputs
            if not self.validate_inputs(model_id, gpu_count, precision, backend):
                return {"success": False, "error": "Invalid inputs"}
            
            self.logger.info(f"Launching AI model: {model_id}")
            if gpu_count:
                self.logger.info(f"Customer specified GPU count: {gpu_count}")
            if precision:
                self.logger.info(f"Customer specified precision: {precision}")
            self.logger.info(f"Backend: {backend}")
            
            # Step 1: Get optimal configuration (auto-detects GPUs and selects best options)
            optimal_config = self.recipe_selector.get_optimal_configuration(
                model_id, gpu_count, precision, backend
            )
            
            if not optimal_config:
                return {"success": False, "error": f"No suitable configuration found for {model_id}"}
            
            self.logger.info(f"Selected configuration:")
            self.logger.info(f"  Recipe: {optimal_config['recipe_id']}")
            self.logger.info(f"  GPU Count: {optimal_config['gpu_count']} (available: {optimal_config['available_gpus']})")
            self.logger.info(f"  Precision: {optimal_config['precision']}")
            self.logger.info(f"  Backend: {optimal_config['backend']}")
            
            # Step 2: Generate deployment configuration with cache support
            config = self.config_generator.generate_config(
                optimal_config['config'], 
                optimal_config['gpu_count'], 
                optimal_config['precision'], 
                optimal_config['backend'], 
                port
            )
            
            # Add cache support to configuration
            if self.cache_enabled:
                self.logger.info(f"Adding cache support from: {self.cache_dir}")
                
                # Add cache environment variables
                cache_env = self.cache_manager.generate_cache_environment(model_id)
                config["environment"].update(cache_env)
                
                # Add cache volume mounts
                cache_volumes = self.cache_manager.generate_cache_volumes(model_id)
                config["volumes"].extend(cache_volumes)
                
                # Check if model is already cached
                if self.cache_manager.is_model_cached(model_id):
                    self.logger.info(f"✅ Model {model_id} found in cache - will use cached version")
                else:
                    self.logger.info(f"📥 Model {model_id} not in cache - will download and cache")
            else:
                self.logger.info("⚠️  Cache not available - models will be downloaded each time")
            
            # Step 3: Generate container name if not provided
            if not container_name:
                container_name = f"aim-engine-{model_id.replace('/', '-').lower()}-{optimal_config['gpu_count']}gpu-{optimal_config['precision']}-{optimal_config['backend']}"
            
            # Step 4: Launch Docker container
            container_info = self.docker_manager.launch_container(
                config, container_name, optimal_config['gpu_count']
            )
            
            if not container_info["success"]:
                return container_info
            
            # Step 5: Start endpoint manager
            endpoint_info = self.endpoint_manager.start_endpoint(
                container_info["container_id"],
                config,
                port
            )
            
            # Step 6: Return deployment information
            deployment_info = {
                "success": True,
                "model_id": model_id,
                "recipe_id": optimal_config["recipe_id"],
                "container_id": container_info["container_id"],
                "container_name": container_name,
                "endpoint_url": f"http://localhost:{port}",
                "gpu_count": optimal_config["gpu_count"],
                "available_gpus": optimal_config["available_gpus"],
                "precision": optimal_config["precision"],
                "backend": optimal_config["backend"],
                "port": port,
                "status": "running",
                "config": config,
                "auto_selected": {
                    "gpu_count": gpu_count is None,
                    "precision": precision is None
                }
            }
            
            self.logger.info(f"AI model deployment successful!")
            self.logger.info(f"Endpoint URL: {deployment_info['endpoint_url']}")
            self.logger.info(f"Container ID: {deployment_info['container_id']}")
            
            if deployment_info["auto_selected"]["gpu_count"]:
                self.logger.info(f"Auto-selected {optimal_config['gpu_count']} GPUs from {optimal_config['available_gpus']} available")
            
            if deployment_info["auto_selected"]["precision"]:
                self.logger.info(f"Auto-selected {optimal_config['precision']} precision for optimal performance")
            
            return deployment_info
            
        except Exception as e:
            self.logger.error(f"Failed to launch AI model: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def stop_model(self, container_name: str) -> Dict:
        """Stop an AI model endpoint"""
        try:
            result = self.docker_manager.stop_container(container_name)
            if result["success"]:
                self.logger.info(f"Stopped AI model container: {container_name}")
            return result
        except Exception as e:
            self.logger.error(f"Failed to stop AI model: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def list_models(self) -> Dict:
        """List all running AI model endpoints"""
        try:
            containers = self.docker_manager.list_containers()
            return {"success": True, "containers": containers}
        except Exception as e:
            self.logger.error(f"Failed to list models: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def get_model_status(self, container_name: str) -> Dict:
        """Get status of a specific AI model endpoint"""
        try:
            status = self.docker_manager.get_container_status(container_name)
            return {"success": True, "status": status}
        except Exception as e:
            self.logger.error(f"Failed to get model status: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def show_model_configurations(self, model_id: str) -> Dict:
        """Show all available configurations for a model"""
        try:
            configurations = self.recipe_selector.get_supported_configurations(model_id)
            return {"success": True, "model_id": model_id, "configurations": configurations}
        except Exception as e:
            self.logger.error(f"Failed to get model configurations: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def get_optimal_configuration(self, model_id: str, gpu_count: Optional[int] = None,
                                precision: Optional[str] = None, backend: str = 'vllm') -> Dict:
        """Get the optimal configuration for a model without deploying"""
        try:
            if not self.validate_inputs(model_id, gpu_count, precision, backend):
                return {"success": False, "error": "Invalid inputs"}
            
            optimal_config = self.recipe_selector.get_optimal_configuration(
                model_id, gpu_count, precision, backend
            )
            
            if not optimal_config:
                return {"success": False, "error": f"No suitable configuration found for {model_id}"}
            
            return {"success": True, "configuration": optimal_config}
            
        except Exception as e:
            self.logger.error(f"Failed to get optimal configuration: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def get_cache_status(self) -> Dict:
        """Get cache status and statistics"""
        try:
            if not self.cache_enabled:
                return {"success": False, "error": "Cache not available"}
            
            stats = self.cache_manager.get_cache_stats()
            return {"success": True, "cache_stats": stats}
            
        except Exception as e:
            self.logger.error(f"Failed to get cache status: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def list_cached_models(self) -> Dict:
        """List all cached models"""
        try:
            if not self.cache_enabled:
                return {"success": False, "error": "Cache not available"}
            
            cached_models = self.cache_manager.list_cached_models()
            return {"success": True, "cached_models": cached_models}
            
        except Exception as e:
            self.logger.error(f"Failed to list cached models: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def add_model_to_cache(self, model_id: str, model_path: str) -> Dict:
        """Add a model to the cache"""
        try:
            if not self.cache_enabled:
                return {"success": False, "error": "Cache not available"}
            
            self.cache_manager.add_model_to_cache(model_id, Path(model_path))
            return {"success": True, "message": f"Added {model_id} to cache"}
            
        except Exception as e:
            self.logger.error(f"Failed to add model to cache: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def remove_model_from_cache(self, model_id: str) -> Dict:
        """Remove a model from the cache"""
        try:
            if not self.cache_enabled:
                return {"success": False, "error": "Cache not available"}
            
            self.cache_manager.remove_model_from_cache(model_id)
            return {"success": True, "message": f"Removed {model_id} from cache"}
            
        except Exception as e:
            self.logger.error(f"Failed to remove model from cache: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def cleanup_cache(self, days_old: int = 30) -> Dict:
        """Clean up old models from cache"""
        try:
            if not self.cache_enabled:
                return {"success": False, "error": "Cache not available"}
            
            self.cache_manager.cleanup_old_models(days_old)
            return {"success": True, "message": f"Cleaned up models older than {days_old} days"}
            
        except Exception as e:
            self.logger.error(f"Failed to cleanup cache: {str(e)}")
            return {"success": False, "error": str(e)}


def main():
    """Main entry point for the AIM Engine CLI"""
    parser = argparse.ArgumentParser(
        description="AIM Engine - AI Model Deployment Engine for Single Node Deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Launch model with auto-detection
  python aim_launcher.py --model Qwen/Qwen3-32B
  
  # Launch model with specific GPU count
  python aim_launcher.py --model Qwen/Qwen3-32B --gpus 4
  
  # Launch model with specific precision
  python aim_launcher.py --model Qwen/Qwen3-32B --precision bf16
  
  # Launch model with specific GPU count and precision
  python aim_launcher.py --model Qwen/Qwen3-32B --gpus 4 --precision bf16
  
  # List running models
  python aim_launcher.py --list
  
  # Stop a model
  python aim_launcher.py --stop --container aim-engine-qwen-qwen3-32b-4gpu-bf16-vllm
  
  # Show model configurations
  python aim_launcher.py --show-config Qwen/Qwen3-32B
  
  # Get optimal configuration without deploying
  python aim_launcher.py --get-config Qwen/Qwen3-32B --gpus 4
        """
    )
    
    # Create subparsers for different commands
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Launch command
    launch_parser = subparsers.add_parser('launch', help='Launch a model endpoint')
    launch_parser.add_argument('--model', required=True, help='Hugging Face model ID')
    launch_parser.add_argument('--gpus', type=int, help='Number of GPUs (auto-detected if not specified)')
    launch_parser.add_argument('--precision', choices=['fp16', 'bf16', 'fp8', 'int8', 'int4'], 
                              help='Precision format (auto-selected if not specified)')
    launch_parser.add_argument('--backend', choices=['vllm', 'sglang'], default='vllm', 
                              help='Serving backend')
    launch_parser.add_argument('--port', type=int, default=8000, help='Port for the endpoint')
    launch_parser.add_argument('--container', help='Custom container name')
    
    # List command
    list_parser = subparsers.add_parser('list', help='List running model endpoints')
    
    # Stop command
    stop_parser = subparsers.add_parser('stop', help='Stop a model endpoint')
    stop_parser.add_argument('--container', required=True, help='Container name to stop')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Get status of a model endpoint')
    status_parser.add_argument('--container', required=True, help='Container name to check')
    
    # Show configurations command
    config_parser = subparsers.add_parser('show-config', help='Show available configurations for a model')
    config_parser.add_argument('model_id', help='Hugging Face model ID')
    
    # Get optimal configuration command
    opt_config_parser = subparsers.add_parser('get-config', help='Get optimal configuration for a model')
    opt_config_parser.add_argument('model_id', help='Hugging Face model ID')
    opt_config_parser.add_argument('--gpus', type=int, help='Number of GPUs')
    opt_config_parser.add_argument('--precision', choices=['fp16', 'bf16', 'fp8', 'int8', 'int4'], 
                                  help='Precision format')
    opt_config_parser.add_argument('--backend', choices=['vllm', 'sglang'], default='vllm', 
                                  help='Serving backend')
    
    # Cache management commands
    cache_parser = subparsers.add_parser('cache', help='Cache management')
    cache_subparsers = cache_parser.add_subparsers(dest='cache_command', help='Cache commands')
    
    cache_stats_parser = cache_subparsers.add_parser('stats', help='Show cache statistics')
    cache_list_parser = cache_subparsers.add_parser('list', help='List cached models')
    cache_add_parser = cache_subparsers.add_parser('add', help='Add model to cache')
    cache_add_parser.add_argument('model_id', help='Model ID')
    cache_add_parser.add_argument('model_path', help='Path to model files')
    cache_remove_parser = cache_subparsers.add_parser('remove', help='Remove model from cache')
    cache_remove_parser.add_argument('model_id', help='Model ID')
    cache_cleanup_parser = cache_subparsers.add_parser('cleanup', help='Clean up old models')
    cache_cleanup_parser.add_argument('--days', type=int, default=30, help='Remove models older than N days')
    
    # Legacy arguments for backward compatibility
    parser.add_argument('--launch', action='store_true', help='Launch a model (legacy)')
    parser.add_argument('--list', action='store_true', help='List running models (legacy)')
    parser.add_argument('--stop', action='store_true', help='Stop a model (legacy)')
    parser.add_argument('--status', action='store_true', help='Get model status (legacy)')
    parser.add_argument('--show-config', help='Show model configurations (legacy)')
    parser.add_argument('--get-config', help='Get optimal configuration (legacy)')
    
    args = parser.parse_args()
    
    # Initialize AIM Engine
    launcher = AIMEngine()
    
    # Handle legacy arguments
    if args.launch or args.command == 'launch':
        if not hasattr(args, 'model') or not args.model:
            parser.error("--model is required for launch")
        
        result = launcher.launch_model(
            model_id=args.model,
            gpu_count=getattr(args, 'gpus', None),
            precision=getattr(args, 'precision', None),
            backend=getattr(args, 'backend', 'vllm'),
            port=getattr(args, 'port', 8000),
            container_name=getattr(args, 'container', None)
        )
        
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    elif args.list or args.command == 'list':
        result = launcher.list_models()
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    elif args.stop or args.command == 'stop':
        container_name = getattr(args, 'container', None)
        if not container_name:
            parser.error("--container is required for stop")
        
        result = launcher.stop_model(container_name)
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    elif args.status or args.command == 'status':
        container_name = getattr(args, 'container', None)
        if not container_name:
            parser.error("--container is required for status")
        
        result = launcher.get_model_status(container_name)
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    elif args.command == 'cache':
        if not args.cache_command:
            cache_parser.print_help()
            return
        
        if args.cache_command == 'stats':
            result = launcher.get_cache_status()
            if result["success"]:
                print(json.dumps(result, indent=2))
            else:
                print(f"Error: {result['error']}")
                sys.exit(1)
        
        elif args.cache_command == 'list':
            result = launcher.list_cached_models()
            if result["success"]:
                print(json.dumps(result, indent=2))
            else:
                print(f"Error: {result['error']}")
                sys.exit(1)
        
        elif args.cache_command == 'add':
            result = launcher.add_model_to_cache(args.model_id, args.model_path)
            if result["success"]:
                print(json.dumps(result, indent=2))
            else:
                print(f"Error: {result['error']}")
                sys.exit(1)
        
        elif args.cache_command == 'remove':
            result = launcher.remove_model_from_cache(args.model_id)
            if result["success"]:
                print(json.dumps(result, indent=2))
            else:
                print(f"Error: {result['error']}")
                sys.exit(1)
        
        elif args.cache_command == 'cleanup':
            result = launcher.cleanup_cache(args.days)
            if result["success"]:
                print(json.dumps(result, indent=2))
            else:
                print(f"Error: {result['error']}")
                sys.exit(1)
        
        else:
            cache_parser.print_help()
    
    elif args.show_config or args.command == 'show-config':
        model_id = getattr(args, 'model_id', args.show_config)
        if not model_id:
            parser.error("model_id is required for show-config")
        
        result = launcher.show_model_configurations(model_id)
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    elif args.get_config or args.command == 'get-config':
        model_id = getattr(args, 'model_id', args.get_config)
        if not model_id:
            parser.error("model_id is required for get-config")
        
        result = launcher.get_optimal_configuration(
            model_id=model_id,
            gpu_count=getattr(args, 'gpus', None),
            precision=getattr(args, 'precision', None),
            backend=getattr(args, 'backend', 'vllm')
        )
        if result["success"]:
            print(json.dumps(result, indent=2))
        else:
            print(f"Error: {result['error']}")
            sys.exit(1)
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main() 