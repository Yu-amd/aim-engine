#!/usr/bin/env python3
"""
AIM Endpoint Manager

This module manages the lifecycle of AIM inference endpoints including health monitoring,
status checking, and endpoint management.
"""

import json
import logging
import requests
import time
from typing import Dict, List, Optional


class AIMEndpointManager:
    """Manages AIM inference endpoints"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.endpoints = {}  # Track managed endpoints
    
    def start_endpoint(self, container_id: str, config: Dict, port: int) -> Dict:
        """
        Start an inference endpoint
        
        Args:
            container_id: Docker container ID
            config: Endpoint configuration
            port: Port for the endpoint
            
        Returns:
            Dictionary with endpoint information
        """
        try:
            endpoint_url = f"http://localhost:{port}"
            
            # Wait for endpoint to be ready
            if self._wait_for_endpoint_ready(endpoint_url):
                endpoint_info = {
                    "container_id": container_id,
                    "endpoint_url": endpoint_url,
                    "port": port,
                    "config": config,
                    "status": "running",
                    "start_time": time.time()
                }
                
                # Register endpoint
                self.endpoints[container_id] = endpoint_info
                
                self.logger.info(f"Endpoint started successfully: {endpoint_url}")
                return {"success": True, "endpoint": endpoint_info}
            else:
                return {
                    "success": False,
                    "error": f"Endpoint failed to become ready at {endpoint_url}"
                }
                
        except Exception as e:
            self.logger.error(f"Failed to start endpoint: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def _wait_for_endpoint_ready(self, endpoint_url: str, timeout: int = 600) -> bool:
        """
        Wait for endpoint to be ready by checking health endpoint
        
        Args:
            endpoint_url: URL of the endpoint
            timeout: Timeout in seconds
            
        Returns:
            True if endpoint is ready, False otherwise
        """
        self.logger.info(f"Waiting for endpoint to be ready: {endpoint_url}")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                # Try to connect to the endpoint
                response = requests.get(f"{endpoint_url}/health", timeout=5)
                if response.status_code == 200:
                    self.logger.info(f"Endpoint is ready: {endpoint_url}")
                    return True
            except requests.exceptions.RequestException:
                # Endpoint not ready yet, continue waiting
                pass
            
            time.sleep(5)
        
        self.logger.error(f"Endpoint failed to become ready within {timeout} seconds")
        return False
    
    def stop_endpoint(self, container_id: str) -> Dict:
        """
        Stop an inference endpoint
        
        Args:
            container_id: Docker container ID
            
        Returns:
            Dictionary with operation result
        """
        try:
            if container_id in self.endpoints:
                endpoint_info = self.endpoints[container_id]
                endpoint_info["status"] = "stopped"
                endpoint_info["stop_time"] = time.time()
                
                self.logger.info(f"Endpoint stopped: {endpoint_info['endpoint_url']}")
                return {"success": True, "endpoint": endpoint_info}
            else:
                return {
                    "success": False,
                    "error": f"Endpoint not found for container: {container_id}"
                }
                
        except Exception as e:
            self.logger.error(f"Failed to stop endpoint: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def check_endpoint_health(self, endpoint_url: str) -> Dict:
        """
        Check the health of an inference endpoint
        
        Args:
            endpoint_url: URL of the endpoint
            
        Returns:
            Dictionary with health information
        """
        try:
            response = requests.get(f"{endpoint_url}/health", timeout=10)
            
            if response.status_code == 200:
                health_data = response.json()
                return {
                    "success": True,
                    "status": "healthy",
                    "response_time": response.elapsed.total_seconds(),
                    "data": health_data
                }
            else:
                return {
                    "success": False,
                    "status": "unhealthy",
                    "status_code": response.status_code,
                    "error": f"Health check failed with status {response.status_code}"
                }
                
        except requests.exceptions.Timeout:
            return {
                "success": False,
                "status": "timeout",
                "error": "Health check timed out"
            }
        except requests.exceptions.ConnectionError:
            return {
                "success": False,
                "status": "connection_error",
                "error": "Could not connect to endpoint"
            }
        except Exception as e:
            return {
                "success": False,
                "status": "error",
                "error": str(e)
            }
    
    def test_inference(self, endpoint_url: str, model_id: str, 
                      prompt: str = "Hello, how are you?") -> Dict:
        """
        Test inference on the endpoint
        
        Args:
            endpoint_url: URL of the endpoint
            model_id: Model ID to test
            prompt: Test prompt
            
        Returns:
            Dictionary with test results
        """
        try:
            payload = {
                "model": model_id,
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "max_tokens": 100,
                "temperature": 0.7
            }
            
            response = requests.post(
                f"{endpoint_url}/v1/chat/completions",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                return {
                    "success": True,
                    "response_time": response.elapsed.total_seconds(),
                    "result": result,
                    "tokens_generated": len(result.get("choices", [{}])[0].get("message", {}).get("content", "").split())
                }
            else:
                return {
                    "success": False,
                    "status_code": response.status_code,
                    "error": f"Inference test failed with status {response.status_code}",
                    "response": response.text
                }
                
        except requests.exceptions.Timeout:
            return {
                "success": False,
                "error": "Inference test timed out"
            }
        except requests.exceptions.ConnectionError:
            return {
                "success": False,
                "error": "Could not connect to endpoint for inference test"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_endpoint_metrics(self, endpoint_url: str) -> Dict:
        """
        Get metrics from the endpoint
        
        Args:
            endpoint_url: URL of the endpoint
            
        Returns:
            Dictionary with metrics
        """
        try:
            # Try to get metrics from various endpoints
            metrics = {}
            
            # Health endpoint
            health_response = requests.get(f"{endpoint_url}/health", timeout=5)
            if health_response.status_code == 200:
                metrics["health"] = health_response.json()
            
            # Metrics endpoint (if available)
            try:
                metrics_response = requests.get(f"{endpoint_url}/metrics", timeout=5)
                if metrics_response.status_code == 200:
                    metrics["system_metrics"] = metrics_response.text
            except:
                pass
            
            # Model info endpoint
            try:
                models_response = requests.get(f"{endpoint_url}/v1/models", timeout=5)
                if models_response.status_code == 200:
                    metrics["models"] = models_response.json()
            except:
                pass
            
            return {
                "success": True,
                "metrics": metrics
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def list_endpoints(self) -> Dict:
        """
        List all managed endpoints
        
        Returns:
            Dictionary with endpoint information
        """
        return {
            "success": True,
            "endpoints": list(self.endpoints.values()),
            "count": len(self.endpoints)
        }
    
    def get_endpoint_info(self, container_id: str) -> Dict:
        """
        Get information about a specific endpoint
        
        Args:
            container_id: Docker container ID
            
        Returns:
            Dictionary with endpoint information
        """
        if container_id in self.endpoints:
            endpoint_info = self.endpoints[container_id].copy()
            
            # Add current health status
            health = self.check_endpoint_health(endpoint_info["endpoint_url"])
            endpoint_info["health"] = health
            
            return {
                "success": True,
                "endpoint": endpoint_info
            }
        else:
            return {
                "success": False,
                "error": f"Endpoint not found for container: {container_id}"
            }
    
    def cleanup_endpoints(self) -> Dict:
        """
        Clean up all managed endpoints
        
        Returns:
            Dictionary with cleanup results
        """
        cleaned = []
        failed = []
        
        for container_id, endpoint_info in self.endpoints.items():
            try:
                endpoint_info["status"] = "cleaned"
                endpoint_info["cleanup_time"] = time.time()
                cleaned.append(container_id)
            except Exception as e:
                failed.append(f"{container_id}: {str(e)}")
        
        self.endpoints.clear()
        
        return {
            "success": True,
            "cleaned": cleaned,
            "failed": failed,
            "total": len(cleaned) + len(failed)
        }
    
    def monitor_endpoint(self, endpoint_url: str, duration: int = 60, 
                        interval: int = 5) -> Dict:
        """
        Monitor an endpoint for a specified duration
        
        Args:
            endpoint_url: URL of the endpoint
            duration: Monitoring duration in seconds
            interval: Check interval in seconds
            
        Returns:
            Dictionary with monitoring results
        """
        self.logger.info(f"Starting endpoint monitoring for {duration} seconds")
        
        checks = []
        start_time = time.time()
        
        while time.time() - start_time < duration:
            check_time = time.time()
            health = self.check_endpoint_health(endpoint_url)
            
            checks.append({
                "timestamp": check_time,
                "health": health
            })
            
            time.sleep(interval)
        
        # Calculate statistics
        successful_checks = [c for c in checks if c["health"]["success"]]
        failed_checks = [c for c in checks if not c["health"]["success"]]
        
        if successful_checks:
            avg_response_time = sum(c["health"].get("response_time", 0) for c in successful_checks) / len(successful_checks)
        else:
            avg_response_time = 0
        
        return {
            "success": True,
            "duration": duration,
            "total_checks": len(checks),
            "successful_checks": len(successful_checks),
            "failed_checks": len(failed_checks),
            "availability": len(successful_checks) / len(checks) if checks else 0,
            "avg_response_time": avg_response_time,
            "checks": checks
        } 