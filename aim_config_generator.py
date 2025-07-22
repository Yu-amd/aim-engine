#!/usr/bin/env python3
"""
AIM Configuration Generator

This module generates deployment configurations from AIM recipes for Docker containers.
"""

import logging
from typing import Dict, List, Optional


class AIMConfigGenerator:
    """Generates deployment configurations from AIM recipes"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def generate_config(self, recipe: Dict, gpu_count: int, precision: str, 
                       backend: str, port: int = 8000) -> Dict:
        """
        Generate deployment configuration from AIM recipe
        
        Args:
            recipe: AIM recipe dictionary
            gpu_count: Number of GPUs
            precision: Precision format
            backend: Serving backend
            port: Port for the endpoint
            
        Returns:
            Deployment configuration dictionary
        """
        try:
            # Get the specific configuration for this GPU count and backend
            backend_key = f"{backend}_serve"
            gpu_key = f"{gpu_count}_gpu"
            
            if backend_key not in recipe:
                raise ValueError(f"Backend {backend} not supported in recipe {recipe['recipe_id']}")
            
            if gpu_key not in recipe[backend_key]:
                raise ValueError(f"GPU count {gpu_count} not supported in recipe {recipe['recipe_id']}")
            
            recipe_config = recipe[backend_key][gpu_key]
            if not recipe_config.get('enabled', False):
                raise ValueError(f"Configuration for {gpu_count} GPUs is disabled in recipe {recipe['recipe_id']}")
            
            # Build the command
            command = self._build_command(recipe_config, backend, port)
            
            # Build environment variables
            environment = self._build_environment(recipe, precision, backend)
            
            # Build volume mounts
            volumes = self._build_volumes(recipe)
            
            # Create deployment configuration
            config = {
                "recipe_id": recipe["recipe_id"],
                "model_id": recipe["huggingface_id"],
                "gpu_count": gpu_count,
                "precision": precision,
                "backend": backend,
                "port": port,
                "command": command,
                "environment": environment,
                "volumes": volumes,
                "args": recipe_config.get("args", {})
            }
            
            self.logger.info(f"Generated configuration for {recipe['recipe_id']}")
            self.logger.debug(f"Configuration: {config}")
            
            return config
            
        except Exception as e:
            self.logger.error(f"Failed to generate configuration: {str(e)}")
            raise
    
    def _build_command(self, recipe_config: Dict, backend: str, port: int) -> str:
        """
        Build the command string for the container
        
        Args:
            recipe_config: Recipe configuration for specific GPU count
            backend: Serving backend
            port: Port for the endpoint
            
        Returns:
            Command string
        """
        args = recipe_config.get("args", {})
        
        # Start with the backend command
        if backend == "vllm":
            command = "python -m vllm.entrypoints.openai.api_server"
        elif backend == "sglang":
            command = "python -m sglang.launch_server"
        else:
            raise ValueError(f"Unsupported backend: {backend}")
        
        # Add arguments
        for key, value in args.items():
            # Remove leading dashes if present
            if key.startswith("--"):
                key = key[2:]
            elif key.startswith("-"):
                key = key[1:]
            
            # Handle special cases
            if key == "port":
                command += f" --{key} {port}"
            else:
                command += f" --{key} {value}"
        
        return command
    
    def _build_environment(self, recipe: Dict, precision: str, backend: str) -> Dict:
        """
        Build environment variables for the container
        
        Args:
            recipe: AIM recipe
            precision: Precision format
            backend: Serving backend
            
        Returns:
            Dictionary of environment variables
        """
        environment = {
            "PYTHONUNBUFFERED": "1",
            "CUDA_VISIBLE_DEVICES": "0,1,2,3,4,5,6,7",  # Will be overridden by GPU allocation
        }
        
        # Add precision-specific environment variables
        if precision == "bf16":
            environment["VLLM_USE_BF16"] = "1"
        elif precision == "fp16":
            environment["VLLM_USE_FP16"] = "1"
        elif precision == "fp8":
            environment["VLLM_USE_FP8"] = "1"
        
        # Add backend-specific environment variables
        if backend == "vllm":
            environment["VLLM_DISABLE_CUSTOM_ALLREDUCE"] = "1"
        elif backend == "sglang":
            environment["SGLANG_DISABLE_CUSTOM_ALLREDUCE"] = "1"
        
        # Add model-specific environment variables
        model_id = recipe.get("huggingface_id", "")
        if "trust-remote-code" in str(recipe).lower():
            environment["HF_HUB_TRUST_REMOTE_CODE"] = "1"
        
        return environment
    
    def _build_volumes(self, recipe: Dict) -> List[str]:
        """
        Build volume mounts for the container
        
        Args:
            recipe: AIM recipe
            
        Returns:
            List of volume mount strings
        """
        volumes = []
        
        # Add cache directory for model downloads
        volumes.append("/tmp/.cache:/tmp/.cache")
        
        # Add model cache directory
        volumes.append("~/.cache/huggingface:/root/.cache/huggingface")
        
        # Add any additional volumes from recipe (if specified)
        # This could be extended to support custom volume mounts in recipes
        
        return volumes
    
    def generate_dockerfile(self, recipe: Dict, gpu_count: int, precision: str, 
                           backend: str) -> str:
        """
        Generate a Dockerfile for the deployment
        
        Args:
            recipe: AIM recipe
            gpu_count: Number of GPUs
            precision: Precision format
            backend: Serving backend
            
        Returns:
            Dockerfile content as string
        """
        dockerfile = f"""# AIM Dockerfile for {recipe['recipe_id']}
FROM rocm/vllm:latest

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

# Set precision-specific environment variables
"""
        
        if precision == "bf16":
            dockerfile += "ENV VLLM_USE_BF16=1\n"
        elif precision == "fp16":
            dockerfile += "ENV VLLM_USE_FP16=1\n"
        elif precision == "fp8":
            dockerfile += "ENV VLLM_USE_FP8=1\n"
        
        if backend == "vllm":
            dockerfile += "ENV VLLM_DISABLE_CUSTOM_ALLREDUCE=1\n"
        elif backend == "sglang":
            dockerfile += "ENV SGLANG_DISABLE_CUSTOM_ALLREDUCE=1\n"
        
        # Add trust remote code if needed
        if "trust-remote-code" in str(recipe).lower():
            dockerfile += "ENV HF_HUB_TRUST_REMOTE_CODE=1\n"
        
        dockerfile += """
# Create cache directories
RUN mkdir -p /tmp/.cache /root/.cache/huggingface

# Expose port
EXPOSE 8000

# Default command (will be overridden by docker run)
CMD ["python", "-m", "vllm.entrypoints.openai.api_server"]
"""
        
        return dockerfile
    
    def generate_compose_file(self, recipe: Dict, gpu_count: int, precision: str, 
                             backend: str, port: int = 8000, 
                             container_name: Optional[str] = None) -> str:
        """
        Generate a Docker Compose file for the deployment
        
        Args:
            recipe: AIM recipe
            gpu_count: Number of GPUs
            precision: Precision format
            backend: Serving backend
            port: Port for the endpoint
            container_name: Optional container name
            
        Returns:
            Docker Compose file content as string
        """
        if not container_name:
            model_name = recipe["huggingface_id"].replace("/", "-").lower()
            container_name = f"aim-{model_name}-{gpu_count}gpu-{precision}-{backend}"
        
        config = self.generate_config(recipe, gpu_count, precision, backend, port)
        
        compose_file = f"""# AIM Docker Compose for {recipe['recipe_id']}
version: '3.8'

services:
  {container_name}:
    image: rocm/vllm:latest
    container_name: {container_name}
    ports:
      - "{port}:{port}"
    environment:
"""
        
        for key, value in config["environment"].items():
            compose_file += f"      - {key}={value}\n"
        
        compose_file += "    volumes:\n"
        for volume in config["volumes"]:
            compose_file += f"      - {volume}\n"
        
        compose_file += f"""    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: {gpu_count}
              capabilities: [gpu]
    command: {config['command']}
    restart: unless-stopped
"""
        
        return compose_file
    
    def generate_kubernetes_yaml(self, recipe: Dict, gpu_count: int, precision: str, 
                                backend: str, port: int = 8000, 
                                namespace: str = "default") -> str:
        """
        Generate Kubernetes YAML for the deployment
        
        Args:
            recipe: AIM recipe
            gpu_count: Number of GPUs
            precision: Precision format
            backend: Serving backend
            port: Port for the endpoint
            namespace: Kubernetes namespace
            
        Returns:
            Kubernetes YAML content as string
        """
        model_name = recipe["huggingface_id"].replace("/", "-").lower()
        deployment_name = f"aim-{model_name}-{gpu_count}gpu-{precision}-{backend}"
        
        config = self.generate_config(recipe, gpu_count, precision, backend, port)
        
        # Build environment variables for Kubernetes
        env_vars = []
        for key, value in config["environment"].items():
            env_vars.append(f"        - name: {key}\n          value: \"{value}\"")
        
        k8s_yaml = f"""# AIM Kubernetes Deployment for {recipe['recipe_id']}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {deployment_name}
  namespace: {namespace}
  labels:
    app: {deployment_name}
    aim: "true"
    model: "{recipe['huggingface_id']}"
    precision: {precision}
    backend: {backend}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {deployment_name}
  template:
    metadata:
      labels:
        app: {deployment_name}
    spec:
      containers:
      - name: {deployment_name}
        image: rocm/vllm:latest
        ports:
        - containerPort: {port}
        env:
{chr(10).join(env_vars)}
        command: {config['command'].split()}
        resources:
          limits:
            nvidia.com/gpu: {gpu_count}
          requests:
            nvidia.com/gpu: {gpu_count}
        volumeMounts:
        - name: cache-volume
          mountPath: /tmp/.cache
        - name: hf-cache-volume
          mountPath: /root/.cache/huggingface
      volumes:
      - name: cache-volume
        emptyDir: {{}}
      - name: hf-cache-volume
        emptyDir: {{}}
---
apiVersion: v1
kind: Service
metadata:
  name: {deployment_name}-service
  namespace: {namespace}
  labels:
    app: {deployment_name}
spec:
  selector:
    app: {deployment_name}
  ports:
  - port: {port}
    targetPort: {port}
    protocol: TCP
  type: ClusterIP
"""
        
        return k8s_yaml 