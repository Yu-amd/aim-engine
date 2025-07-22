#!/usr/bin/env python3
"""
AIM Recipe Selector

This module handles the selection of the best performing AIM recipe based on
customer specifications including model, GPU count, precision, and backend.
Now optimized to only load recipes for the specific model.
"""

import logging
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class AIMRecipeSelector:
    """Selects the best performing AIM recipe based on customer inputs"""
    
    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
        self.recipes_dir = config_dir / "recipes"
        self.models_dir = config_dir / "models"
        self.logger = logging.getLogger(__name__)
        
        # Don't load all recipes at startup - load on demand
        self.recipes = {}  # Will be populated per model
        self.models = {}
        
        # Load model definitions
        self._load_models()
    
    def _load_models(self):
        """Load all model definitions from the models directory"""
        self.models = {}
        
        if not self.models_dir.exists():
            self.logger.warning(f"Models directory not found: {self.models_dir}")
            return
        
        for model_file in self.models_dir.glob("*.yaml"):
            try:
                with open(model_file, 'r') as f:
                    model = yaml.safe_load(f)
                    self.models[model['huggingface_id']] = model
                    self.logger.debug(f"Loaded model: {model['huggingface_id']}")
            except Exception as e:
                self.logger.error(f"Failed to load model {model_file}: {e}")
    
    def _load_model_recipes(self, model_id: str) -> Dict[str, Dict]:
        """
        Load recipes only for the specific model
        
        Args:
            model_id: Hugging Face model ID
            
        Returns:
            Dictionary of recipes for the model
        """
        model_recipes = {}
        
        if not self.recipes_dir.exists():
            self.logger.warning(f"Recipes directory not found: {self.recipes_dir}")
            return model_recipes
        
        # Load recipes that match the model_id
        for recipe_file in self.recipes_dir.glob("*.yaml"):
            try:
                with open(recipe_file, 'r') as f:
                    recipe = yaml.safe_load(f)
                    
                    # Only load recipes for this specific model
                    if recipe.get('huggingface_id') == model_id:
                        model_recipes[recipe['recipe_id']] = recipe
                        self.logger.debug(f"Loaded recipe for {model_id}: {recipe['recipe_id']}")
                        
            except Exception as e:
                self.logger.error(f"Failed to load recipe {recipe_file}: {e}")
        
        return model_recipes
    
    def _detect_available_gpus(self) -> int:
        """
        Detect the number of available GPUs
        
        Returns:
            Number of available GPUs
        """
        try:
            import subprocess
            # Try AMD ROCm first
            result = subprocess.run(['rocm-smi', '--showproductname'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                # Count GPU entries (lines starting with "GPU[")
                gpu_lines = [line for line in result.stdout.strip().split('\n') 
                           if line.strip().startswith('GPU[')]
                gpu_count = len(gpu_lines)
                self.logger.info(f"Detected {gpu_count} AMD GPUs using rocm-smi")
                return gpu_count
            
            # Try NVIDIA if AMD not available
            result = subprocess.run(['nvidia-smi', '--list-gpus'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                gpu_lines = [line for line in result.stdout.strip().split('\n') 
                           if line.strip()]
                gpu_count = len(gpu_lines)
                self.logger.info(f"Detected {gpu_count} NVIDIA GPUs using nvidia-smi")
                return gpu_count
                
        except Exception as e:
            self.logger.warning(f"Failed to detect GPUs: {e}")
        
        # Fallback to environment variable or default
        import os
        gpu_count = int(os.environ.get('CUDA_VISIBLE_DEVICES', '0').count(',') + 1)
        self.logger.info(f"Using fallback GPU count: {gpu_count}")
        return gpu_count
    
    def _detect_container_gpus(self) -> int:
        """
        Detect the number of GPUs available inside the container
        This is different from host GPUs due to Docker GPU access limitations
        
        Returns:
            Number of GPUs available inside the container
        """
        try:
            import subprocess
            import torch
            
            # Try PyTorch first (most reliable inside containers)
            if torch.cuda.is_available():
                gpu_count = torch.cuda.device_count()
                self.logger.info(f"Detected {gpu_count} GPUs using PyTorch")
                return gpu_count
            
            # Try AMD ROCm
            result = subprocess.run(['rocm-smi', '--showproductname'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                gpu_lines = [line for line in result.stdout.strip().split('\n') 
                           if line.strip().startswith('GPU[')]
                gpu_count = len(gpu_lines)
                self.logger.info(f"Detected {gpu_count} AMD GPUs in container using rocm-smi")
                return gpu_count
            
            # Try NVIDIA
            result = subprocess.run(['nvidia-smi', '--list-gpus'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                gpu_lines = [line for line in result.stdout.strip().split('\n') 
                           if line.strip()]
                gpu_count = len(gpu_lines)
                self.logger.info(f"Detected {gpu_count} NVIDIA GPUs in container using nvidia-smi")
                return gpu_count
                
        except Exception as e:
            self.logger.warning(f"Failed to detect container GPUs: {e}")
        
        # Fallback to environment variable or default to 1
        import os
        gpu_count = int(os.environ.get('CUDA_VISIBLE_DEVICES', '0').count(',') + 1)
        self.logger.info(f"Using fallback container GPU count: {gpu_count}")
        return gpu_count
    
    def _detect_vllm_gpus(self) -> int:
        """
        Detect the number of GPUs that vLLM can actually use
        This is the most important detection for tensor parallelism
        
        Returns:
            Number of GPUs available for vLLM
        """
        try:
            import subprocess
            
            # Try to run a simple PyTorch command to see how many GPUs it detects
            test_cmd = [
                "python", "-c", 
                "import torch; print(torch.cuda.device_count() if torch.cuda.is_available() else 0)"
            ]
            
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                gpu_count = int(result.stdout.strip())
                if gpu_count > 0:
                    self.logger.info(f"vLLM-compatible GPU count: {gpu_count}")
                    return gpu_count
                else:
                    self.logger.warning("PyTorch detected 0 GPUs, trying fallback detection")
                
        except Exception as e:
            self.logger.warning(f"Failed to detect vLLM GPUs with PyTorch: {e}")
        
        # Fallback: Try container GPU detection
        container_gpus = self._detect_container_gpus()
        if container_gpus > 0:
            self.logger.info(f"Using container GPU count as fallback: {container_gpus}")
            return container_gpus
        
        # Final fallback: Assume 1 GPU if all else fails
        self.logger.warning("All GPU detection methods failed, assuming 1 GPU")
        return 1
    
    def _get_optimal_gpu_count(self, model_id: str, available_gpus: int, 
                              customer_gpu_count: Optional[int] = None) -> int:
        """
        Get the optimal GPU count for a model based on available resources
        
        Args:
            model_id: Hugging Face model ID
            available_gpus: Number of available GPUs
            customer_gpu_count: Customer specified GPU count (optional)
            
        Returns:
            Optimal GPU count to use
        """
        # If customer specified a GPU count, use it (but validate)
        if customer_gpu_count is not None:
            self.logger.info(f"Using customer specified GPU count: {customer_gpu_count}")
            # Ensure customer GPU count doesn't exceed available GPUs
            if customer_gpu_count > available_gpus:
                self.logger.warning(f"Customer requested {customer_gpu_count} GPUs but only {available_gpus} available")
                return available_gpus
            return customer_gpu_count
        
        # Ensure we have at least 1 GPU
        if available_gpus < 1:
            self.logger.warning("No GPUs detected, assuming 1 GPU")
            available_gpus = 1
        
        # Auto-select optimal GPU count based on model size and available GPUs
        model_info = self.models.get(model_id, {})
        model_size = model_info.get('size', 'unknown')
        
        # Simple heuristic for optimal GPU count
        if model_size in ['7B', '8B'] and available_gpus >= 1:
            optimal_gpus = 1
        elif model_size in ['13B', '14B'] and available_gpus >= 2:
            optimal_gpus = 2
        elif model_size in ['32B', '34B'] and available_gpus >= 4:
            optimal_gpus = 4
        elif model_size in ['70B', '72B'] and available_gpus >= 8:
            optimal_gpus = 8
        else:
            # Use maximum available GPUs
            optimal_gpus = available_gpus
        
        self.logger.info(f"Auto-selected optimal GPU count: {optimal_gpus} for {model_size} model")
        return optimal_gpus
    
    def _select_best_precision(self, model_id: str, customer_precision: Optional[str] = None) -> str:
        """
        Select the best precision based on model and customer preference
        
        Args:
            model_id: Model ID
            customer_precision: Customer specified precision (optional)
            
        Returns:
            Best precision to use
        """
        if customer_precision:
            self.logger.info(f"Using customer specified precision: {customer_precision}")
            return customer_precision
        
        # Auto-select precision based on model characteristics
        model_info = self.models.get(model_id, {})
        model_size = model_info.get('size', 'unknown')
        
        # Simple heuristic for precision selection
        if model_size in ['7B', '8B']:
            precision = 'fp16'  # Smaller models can use fp16
        elif model_size in ['13B', '14B']:
            precision = 'bf16'  # Medium models benefit from bf16
        else:
            precision = 'bf16'  # Larger models use bf16 for stability
        
        self.logger.info(f"Auto-selected precision: {precision} for {model_size} model")
        return precision
    
    def find_matching_recipes(self, model_id: str, gpu_count: int, 
                            precision: str, backend: str) -> List[Dict]:
        """
        Find all recipes that match the given criteria
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs
            precision: Precision format
            backend: Serving backend
            
        Returns:
            List of matching recipes
        """
        # Load recipes only for this model
        model_recipes = self._load_model_recipes(model_id)
        
        if not model_recipes:
            self.logger.warning(f"No recipes found for model: {model_id}")
            return []
        
        matching_recipes = []
        
        for recipe_id, recipe in model_recipes.items():
            # Check if recipe matches the precision
            if recipe.get('precision') != precision:
                continue
            
            # Check if the backend is supported and enabled for the GPU count
            backend_key = f"{backend}_serve"
            if backend_key not in recipe:
                continue
            
            gpu_key = f"{gpu_count}_gpu"
            if gpu_key not in recipe[backend_key]:
                continue
            
            if not recipe[backend_key][gpu_key].get('enabled', False):
                continue
            
            # Recipe matches all criteria
            matching_recipes.append(recipe)
        
        return matching_recipes
    
    def select_best_recipe(self, model_id: str, gpu_count: Optional[int] = None, 
                          precision: Optional[str] = None, backend: str = 'vllm') -> Optional[Dict]:
        """
        Select the best performing recipe based on available resources and preferences
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs (optional - will auto-detect if not provided)
            precision: Precision format (optional - will auto-select if not provided)
            backend: Serving backend
            
        Returns:
            Best matching recipe or None if no match found
        """
        # Step 1: Use provided GPU count or detect available GPUs
        if gpu_count is not None:
            available_gpus = gpu_count
            optimal_gpu_count = gpu_count
        else:
            available_gpus = self._detect_available_gpus()
            optimal_gpu_count = self._get_optimal_gpu_count(model_id, available_gpus, gpu_count)
        
        # Step 2: Select optimal precision
        optimal_precision = self._select_best_precision(model_id, precision)
        
        self.logger.info(f"Model: {model_id}")
        self.logger.info(f"Available GPUs: {available_gpus}")
        self.logger.info(f"Selected GPU count: {optimal_gpu_count}")
        self.logger.info(f"Selected precision: {optimal_precision}")
        self.logger.info(f"Selected backend: {backend}")
        
        # Step 3: Find matching recipes
        matching_recipes = self.find_matching_recipes(
            model_id, optimal_gpu_count, optimal_precision, backend
        )
        
        if not matching_recipes:
            self.logger.warning(f"No matching recipes found for {model_id} with {optimal_gpu_count} GPUs, {optimal_precision} precision, {backend} backend")
            
            # Try to find alternative configurations
            self.logger.info("Trying alternative configurations...")
            
            # Try different precisions
            for alt_precision in ['bf16', 'fp16', 'fp8']:
                if alt_precision != optimal_precision:
                    alt_recipes = self.find_matching_recipes(model_id, optimal_gpu_count, alt_precision, backend)
                    if alt_recipes:
                        self.logger.info(f"Found alternative with {alt_precision} precision")
                        return alt_recipes[0]
            
            # Try different GPU counts
            for alt_gpu_count in [1, 2, 4, 8]:
                if alt_gpu_count != optimal_gpu_count and alt_gpu_count <= available_gpus:
                    alt_recipes = self.find_matching_recipes(model_id, alt_gpu_count, optimal_precision, backend)
                    if alt_recipes:
                        self.logger.info(f"Found alternative with {alt_gpu_count} GPUs")
                        return alt_recipes[0]
            
            return None
        
        # Step 4: Select the best recipe (currently first match, future: performance-based)
        selected_recipe = matching_recipes[0]
        self.logger.info(f"Selected recipe: {selected_recipe['recipe_id']}")
        
        return selected_recipe
    
    def select_recipe(self, model_id: str, gpu_count: Optional[int] = None, 
                     precision: Optional[str] = None, backend: str = 'vllm') -> Optional[Dict]:
        """
        Main method to select a recipe (alias for select_best_recipe)
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs (optional)
            precision: Precision format (optional)
            backend: Serving backend
            
        Returns:
            Best matching recipe or None if no match found
        """
        return self.select_best_recipe(model_id, gpu_count, precision, backend)
    
    def get_recipe_config(self, recipe: Dict, gpu_count: int, 
                         backend: str) -> Optional[Dict]:
        """
        Get the specific configuration for a recipe with given GPU count and backend
        
        Args:
            recipe: Recipe dictionary
            gpu_count: Number of GPUs
            backend: Serving backend
            
        Returns:
            Configuration dictionary or None if not found
        """
        backend_key = f"{backend}_serve"
        gpu_key = f"{gpu_count}_gpu"
        
        if backend_key not in recipe:
            self.logger.error(f"Backend {backend} not supported in recipe {recipe['recipe_id']}")
            return None
        
        if gpu_key not in recipe[backend_key]:
            self.logger.error(f"GPU count {gpu_count} not supported in recipe {recipe['recipe_id']}")
            return None
        
        config = recipe[backend_key][gpu_key]
        if not config.get('enabled', False):
            self.logger.error(f"Configuration for {gpu_count} GPUs is disabled in recipe {recipe['recipe_id']}")
            return None
        
        return config
    
    def list_available_models(self) -> List[str]:
        """List all available models"""
        return list(self.models.keys())
    
    def list_available_recipes(self) -> List[str]:
        """List all available recipes (deprecated - use get_model_recipes instead)"""
        self.logger.warning("list_available_recipes is deprecated. Use get_model_recipes instead.")
        return []
    
    def get_model_recipes(self, model_id: str) -> List[str]:
        """List all available recipes for a specific model"""
        model_recipes = self._load_model_recipes(model_id)
        return list(model_recipes.keys())
    
    def get_model_info(self, model_id: str) -> Optional[Dict]:
        """Get information about a specific model"""
        return self.models.get(model_id)
    
    def get_recipe_info(self, recipe_id: str) -> Optional[Dict]:
        """Get information about a specific recipe"""
        # Search through all recipe files for this specific recipe
        if not self.recipes_dir.exists():
            return None
        
        for recipe_file in self.recipes_dir.glob("*.yaml"):
            try:
                with open(recipe_file, 'r') as f:
                    recipe = yaml.safe_load(f)
                    if recipe.get('recipe_id') == recipe_id:
                        return recipe
            except Exception as e:
                self.logger.error(f"Failed to load recipe {recipe_file}: {e}")
        
        return None
    
    def validate_recipe_exists(self, model_id: str, gpu_count: Optional[int] = None, 
                             precision: Optional[str] = None, backend: str = 'vllm') -> bool:
        """
        Validate that a recipe exists for the given parameters
        
        Args:
            model_id: Hugging Face model ID
            gpu_count: Number of GPUs (optional)
            precision: Precision format (optional)
            backend: Serving backend
            
        Returns:
            True if recipe exists, False otherwise
        """
        recipe = self.select_best_recipe(model_id, gpu_count, precision, backend)
        return recipe is not None
    
    def get_supported_configurations(self, model_id: str) -> Dict:
        """
        Get all supported configurations for a model
        
        Args:
            model_id: Hugging Face model ID
            
        Returns:
            Dictionary of supported configurations
        """
        model_recipes = self._load_model_recipes(model_id)
        configurations = {}
        
        for recipe_id, recipe in model_recipes.items():
            precision = recipe.get('precision', 'unknown')
            
            for backend in ['vllm', 'sglang']:
                backend_key = f"{backend}_serve"
                if backend_key in recipe:
                    for gpu_key, config in recipe[backend_key].items():
                        if config.get('enabled', False):
                            gpu_count = gpu_key.replace('_gpu', '')
                            config_key = f"{gpu_count}gpu_{precision}_{backend}"
                            configurations[config_key] = {
                                'recipe_id': recipe_id,
                                'gpu_count': int(gpu_count),
                                'precision': precision,
                                'backend': backend,
                                'enabled': True
                            }
        
        return configurations
    
    def get_optimal_configuration(self, model_id: str, 
                                customer_gpu_count: Optional[int] = None,
                                customer_precision: Optional[str] = None,
                                backend: str = 'vllm') -> Optional[Dict]:
        """
        Get the optimal configuration for a model based on available resources
        
        Args:
            model_id: Hugging Face model ID
            customer_gpu_count: Customer specified GPU count (optional)
            customer_precision: Customer specified precision (optional)
            backend: Serving backend
            
        Returns:
            Optimal configuration or None if not found
        """
        # Detect GPUs that vLLM can actually use (most important for tensor parallelism)
        vllm_gpus = self._detect_vllm_gpus()
        container_gpus = self._detect_container_gpus()
        host_gpus = self._detect_available_gpus()
        
        self.logger.info(f"vLLM GPUs: {vllm_gpus}, Container GPUs: {container_gpus}, Host GPUs: {host_gpus}")
        
        # Use vLLM GPU count for actual configuration (this is what vLLM will see)
        actual_gpu_count = self._get_optimal_gpu_count(model_id, vllm_gpus, customer_gpu_count)
        actual_precision = self._select_best_precision(model_id, customer_precision)
        
        # Try to find a recipe with the optimal configuration
        recipe = None
        
        # First try with the optimal GPU count (but limited by vLLM GPUs)
        recipe = self.select_best_recipe(model_id, actual_gpu_count, actual_precision, backend)
        
        # If no recipe found, try with supported GPU counts in order of preference
        if not recipe:
            supported_gpu_counts = [8, 4, 2, 1]  # Prefer higher GPU counts first
            for gpu_count in supported_gpu_counts:
                if gpu_count <= vllm_gpus:  # Only use what vLLM can actually see
                    self.logger.info(f"Trying with {gpu_count} GPUs...")
                    recipe = self.select_best_recipe(model_id, gpu_count, actual_precision, backend)
                    if recipe:
                        actual_gpu_count = gpu_count
                        self.logger.info(f"Found recipe with {gpu_count} GPUs")
                        break
        
        # If still no recipe, try with different precisions
        if not recipe:
            for precision in ['bf16', 'fp16', 'fp8']:
                if precision != actual_precision:
                    for gpu_count in [8, 4, 2, 1]:
                        if gpu_count <= vllm_gpus:  # Only use what vLLM can actually see
                            self.logger.info(f"Trying with {gpu_count} GPUs and {precision} precision...")
                            recipe = self.select_best_recipe(model_id, gpu_count, precision, backend)
                            if recipe:
                                actual_gpu_count = gpu_count
                                actual_precision = precision
                                self.logger.info(f"Found recipe with {gpu_count} GPUs and {precision} precision")
                                break
                    if recipe:
                        break
        
        if not recipe:
            self.logger.error(f"No suitable recipe found for {model_id} with any supported configuration")
            return None
        
        config = self.get_recipe_config(recipe, actual_gpu_count, backend)
        
        if not config:
            return None
        
        return {
            'recipe_id': recipe['recipe_id'],
            'model_id': model_id,
            'gpu_count': actual_gpu_count,
            'precision': actual_precision,
            'backend': backend,
            'config': config,
            'available_gpus': vllm_gpus,
            'container_gpus': container_gpus,
            'host_gpus': host_gpus
        } 