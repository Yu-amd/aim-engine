#!/usr/bin/env python3
"""
AIM Docker Manager

This module handles Docker container operations for AIM deployment using the ROCm vLLM container.
"""

import json
import logging
import subprocess
import time
from typing import Dict, List, Optional


class AIMDockerManager:
    """Manages Docker containers for AIM deployment"""
    
    def __init__(self):
        self.base_image = "rocm/vllm:latest"
        self.logger = logging.getLogger(__name__)
        
        # Verify Docker is available
        self._verify_docker()
    
    def _verify_docker(self):
        """Verify that Docker is available and running"""
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                text=True,
                check=True
            )
            self.logger.info(f"Docker version: {result.stdout.strip()}")
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Docker is not available: {e}")
        except FileNotFoundError:
            raise RuntimeError("Docker is not installed or not in PATH")
    
    def _run_docker_command(self, command: List[str], capture_output: bool = True) -> Dict:
        """
        Run a Docker command and return the result
        
        Args:
            command: Docker command as list of arguments
            capture_output: Whether to capture output
            
        Returns:
            Dictionary with success status and output/error
        """
        try:
            if capture_output:
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    check=True
                )
                return {
                    "success": True,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "returncode": result.returncode
                }
            else:
                subprocess.run(command, check=True)
                return {"success": True}
        except subprocess.CalledProcessError as e:
            return {
                "success": False,
                "error": e.stderr,
                "returncode": e.returncode
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def pull_base_image(self) -> Dict:
        """Pull the base ROCm vLLM image"""
        self.logger.info(f"Pulling base image: {self.base_image}")
        
        result = self._run_docker_command(["docker", "pull", self.base_image])
        
        if result["success"]:
            self.logger.info("Base image pulled successfully")
        else:
            self.logger.error(f"Failed to pull base image: {result.get('error', 'Unknown error')}")
        
        return result
    
    def launch_container(self, config: Dict, container_name: str, gpu_count: int) -> Dict:
        """
        Launch a Docker container with the specified configuration
        
        Args:
            config: Container configuration
            container_name: Name for the container
            gpu_count: Number of GPUs to allocate
            
        Returns:
            Dictionary with container information
        """
        try:
            # Build Docker run command
            cmd = ["docker", "run"]
            
            # Container name
            cmd.extend(["--name", container_name])
            
            # Detached mode
            cmd.append("-d")
            
            # GPU allocation
            if gpu_count > 0:
                cmd.extend(["--gpus", f"all"])
            
            # Port mapping
            port = config.get("port", 8000)
            cmd.extend(["-p", f"{port}:{port}"])
            
            # Environment variables
            for key, value in config.get("environment", {}).items():
                cmd.extend(["-e", f"{key}={value}"])
            
            # Volume mounts (if any)
            for volume in config.get("volumes", []):
                cmd.extend(["-v", volume])
            
            # Base image
            cmd.append(self.base_image)
            
            # Command and arguments
            command = config.get("command", "")
            if command:
                cmd.extend(command.split())
            
            self.logger.info(f"Launching container: {' '.join(cmd)}")
            
            # Run the command
            result = self._run_docker_command(cmd)
            
            if result["success"]:
                container_id = result["stdout"].strip()
                self.logger.info(f"Container launched successfully: {container_id}")
                
                # Wait for container to be ready
                if self._wait_for_container_ready(container_name):
                    return {
                        "success": True,
                        "container_id": container_id,
                        "container_name": container_name,
                        "port": port
                    }
                else:
                    # Container failed to start properly
                    self.stop_container(container_name)
                    return {
                        "success": False,
                        "error": "Container failed to start properly"
                    }
            else:
                self.logger.error(f"Failed to launch container: {result.get('error', 'Unknown error')}")
                return result
                
        except Exception as e:
            self.logger.error(f"Exception while launching container: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def _wait_for_container_ready(self, container_name: str, timeout: int = 300) -> bool:
        """
        Wait for container to be ready (health check)
        
        Args:
            container_name: Name of the container
            timeout: Timeout in seconds
            
        Returns:
            True if container is ready, False otherwise
        """
        self.logger.info(f"Waiting for container {container_name} to be ready...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            # Check if container is running
            result = self._run_docker_command([
                "docker", "ps", "--filter", f"name={container_name}", "--format", "{{.Status}}"
            ])
            
            if result["success"] and result["stdout"].strip():
                # Container is running, check if it's healthy
                if "Up" in result["stdout"]:
                    self.logger.info(f"Container {container_name} is ready")
                    return True
            
            time.sleep(5)
        
        self.logger.error(f"Container {container_name} failed to become ready within {timeout} seconds")
        return False
    
    def stop_container(self, container_name: str) -> Dict:
        """
        Stop a running container
        
        Args:
            container_name: Name of the container to stop
            
        Returns:
            Dictionary with operation result
        """
        self.logger.info(f"Stopping container: {container_name}")
        
        # Stop the container
        result = self._run_docker_command(["docker", "stop", container_name])
        
        if result["success"]:
            self.logger.info(f"Container {container_name} stopped successfully")
        else:
            self.logger.error(f"Failed to stop container {container_name}: {result.get('error', 'Unknown error')}")
        
        return result
    
    def remove_container(self, container_name: str) -> Dict:
        """
        Remove a container
        
        Args:
            container_name: Name of the container to remove
            
        Returns:
            Dictionary with operation result
        """
        self.logger.info(f"Removing container: {container_name}")
        
        # Remove the container
        result = self._run_docker_command(["docker", "rm", container_name])
        
        if result["success"]:
            self.logger.info(f"Container {container_name} removed successfully")
        else:
            self.logger.error(f"Failed to remove container {container_name}: {result.get('error', 'Unknown error')}")
        
        return result
    
    def list_containers(self) -> List[Dict]:
        """
        List all AIM containers
        
        Returns:
            List of container information dictionaries
        """
        result = self._run_docker_command([
            "docker", "ps", "-a", "--filter", "name=aim-", 
            "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        ])
        
        containers = []
        if result["success"]:
            for line in result["stdout"].strip().split('\n'):
                if line.strip():
                    parts = line.split('\t')
                    if len(parts) >= 4:
                        containers.append({
                            "name": parts[0],
                            "image": parts[1],
                            "status": parts[2],
                            "ports": parts[3]
                        })
        
        return containers
    
    def get_container_status(self, container_name: str) -> Dict:
        """
        Get status of a specific container
        
        Args:
            container_name: Name of the container
            
        Returns:
            Dictionary with container status
        """
        result = self._run_docker_command([
            "docker", "inspect", container_name, "--format", 
            "{{.State.Status}}\t{{.State.Health.Status}}\t{{.Config.Image}}"
        ])
        
        if result["success"] and result["stdout"].strip():
            parts = result["stdout"].strip().split('\t')
            if len(parts) >= 3:
                return {
                    "success": True,
                    "status": parts[0],
                    "health": parts[1],
                    "image": parts[2]
                }
        
        return {
            "success": False,
            "error": "Container not found or inspect failed"
        }
    
    def get_container_logs(self, container_name: str, tail: int = 100) -> Dict:
        """
        Get logs from a container
        
        Args:
            container_name: Name of the container
            tail: Number of lines to return
            
        Returns:
            Dictionary with container logs
        """
        result = self._run_docker_command([
            "docker", "logs", "--tail", str(tail), container_name
        ])
        
        if result["success"]:
            return {
                "success": True,
                "logs": result["stdout"]
            }
        else:
            return {
                "success": False,
                "error": result.get("error", "Failed to get logs")
            }
    
    def execute_command(self, container_name: str, command: str) -> Dict:
        """
        Execute a command inside a running container
        
        Args:
            container_name: Name of the container
            command: Command to execute
            
        Returns:
            Dictionary with command output
        """
        result = self._run_docker_command([
            "docker", "exec", container_name, "sh", "-c", command
        ])
        
        if result["success"]:
            return {
                "success": True,
                "stdout": result["stdout"],
                "stderr": result["stderr"]
            }
        else:
            return {
                "success": False,
                "error": result.get("error", "Failed to execute command")
            }
    
    def cleanup_containers(self, pattern: str = "aim-") -> Dict:
        """
        Clean up containers matching a pattern
        
        Args:
            pattern: Pattern to match container names
            
        Returns:
            Dictionary with cleanup results
        """
        self.logger.info(f"Cleaning up containers matching pattern: {pattern}")
        
        # Get containers matching pattern
        result = self._run_docker_command([
            "docker", "ps", "-a", "--filter", f"name={pattern}", 
            "--format", "{{.Names}}"
        ])
        
        if not result["success"]:
            return result
        
        containers = [name.strip() for name in result["stdout"].split('\n') if name.strip()]
        
        cleaned = []
        failed = []
        
        for container in containers:
            # Stop container
            stop_result = self.stop_container(container)
            if stop_result["success"]:
                # Remove container
                remove_result = self.remove_container(container)
                if remove_result["success"]:
                    cleaned.append(container)
                else:
                    failed.append(f"{container} (remove failed)")
            else:
                failed.append(f"{container} (stop failed)")
        
        return {
            "success": True,
            "cleaned": cleaned,
            "failed": failed,
            "total": len(containers)
        } 

    def run_command_directly(self, config: Dict, container_name: str, gpu_count: int) -> Dict:
        """
        Run the command in a Docker container with proper port mapping
        
        Args:
            config: Container configuration
            container_name: Name for the container (used for logging)
            gpu_count: Number of GPUs to allocate
            
        Returns:
            Dictionary with container information
        """
        try:
            import subprocess
            import os
            
            # Get the command to run
            command = config.get("command", "")
            if not command:
                return {"success": False, "error": "No command specified in config"}
            
            # Get port from config
            port = config.get("port", 8000)
            
            # Build Docker run command with proper port mapping
            docker_cmd = [
                "docker", "run",
                "--rm",  # Remove container when it stops
                "--name", container_name,
                "-p", f"{port}:{port}",  # Port mapping
                "--device=/dev/kfd",
                "--device=/dev/dri", 
                "--group-add=video",
                "--cap-add=SYS_RAWIO"
            ]
            
            # Add environment variables
            for key, value in config.get("environment", {}).items():
                docker_cmd.extend(["-e", f"{key}={value}"])
            
            # Add volume mounts
            for volume in config.get("volumes", []):
                docker_cmd.extend(["-v", volume])
            
            # Add the base image
            docker_cmd.append(self.base_image)
            
            # Add the command
            docker_cmd.extend(command.split())
            
            self.logger.info(f"Running Docker command: {' '.join(docker_cmd)}")
            
            # Run the Docker command in the background
            process = subprocess.Popen(
                docker_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid  # Create new process group
            )
            
            # Wait a moment for container to start
            import time
            time.sleep(2)
            
            # Get container ID
            result = self._run_docker_command([
                "docker", "ps", "--filter", f"name={container_name}", 
                "--format", "{{.ID}}"
            ])
            
            container_id = result.get("stdout", "").strip()
            if not container_id:
                # Try to get container ID from process
                container_id = str(process.pid)
            
            return {
                "success": True,
                "container_id": container_id,
                "container_name": container_name,
                "process": process,
                "command": command,
                "port": port
            }
            
        except Exception as e:
            self.logger.error(f"Failed to run command in Docker container: {str(e)}")
            return {"success": False, "error": str(e)} 