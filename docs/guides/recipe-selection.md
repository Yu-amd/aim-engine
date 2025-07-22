# AIM Engine - Recipe Selection Guide

## 🎯 **When and How AIM Recipes Are Selected**

AIM recipes are selected **automatically** during the model deployment process based on user inputs and system requirements. Here's exactly when and how this happens:

## 🔄 **Recipe Selection Timeline**

### **Phase 1: User Request**
```bash
# User requests model deployment
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --backend vllm
```

### **Phase 2: Recipe Selection (Automatic)**
The recipe selection happens **immediately** after input validation and **before** container creation.

### **Phase 3: Configuration Generation**
Selected recipe is used to generate deployment configuration.

### **Phase 4: Container Launch**
Configuration is used to launch the vLLM container.

## 🔍 **Recipe Selection Process**

### **Step 1: Load All Recipes**
```python
# AIMRecipeSelector loads all recipes at startup
def _load_recipes(self):
    """Load all AIM recipes from the recipes directory"""
    self.recipes = {}
    
    for recipe_file in self.recipes_dir.glob("*.yaml"):
        with open(recipe_file, 'r') as f:
            recipe = yaml.safe_load(f)
            self.recipes[recipe['recipe_id']] = recipe
```

### **Step 2: Find Matching Recipes**
```python
def find_matching_recipes(self, model_id: str, gpu_count: int, 
                         precision: str, backend: str) -> List[Dict]:
    """Find all recipes that match the given criteria"""
    matching_recipes = []
    
    for recipe_id, recipe in self.recipes.items():
        # Check if recipe matches the model
        if recipe.get('huggingface_id') != model_id:
            continue
        
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
```

### **Step 3: Select Best Recipe**
```python
def select_best_recipe(self, model_id: str, gpu_count: int, 
                      precision: str, backend: str) -> Optional[Dict]:
    """Select the best performing recipe based on performance metrics"""
    matching_recipes = self.find_matching_recipes(model_id, gpu_count, precision, backend)
    
    if not matching_recipes:
        self.logger.warning(f"No matching recipes found for {model_id}")
        return None
    
    # For now, select the first matching recipe
    # Future: Compare performance metrics, hardware optimizations, etc.
    selected_recipe = matching_recipes[0]
    self.logger.info(f"Selected recipe: {selected_recipe['recipe_id']}")
    
    return selected_recipe
```

## 📋 **Recipe Selection Criteria**

### **Required Matches**
1. **Model ID**: `huggingface_id` must match exactly
2. **Precision**: `precision` field must match (bf16, fp16, etc.)
3. **Backend Support**: Recipe must have `{backend}_serve` section
4. **GPU Count**: Recipe must have `{gpu_count}_gpu` configuration
5. **Enabled Status**: Configuration must be `enabled: true`

### **Example: Recipe Selection for Qwen/Qwen3-32B**

**User Request:**
```bash
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --backend vllm
```

**Recipe Selection Process:**
```python
# 1. Find recipes matching Qwen/Qwen3-32B
model_id = "Qwen/Qwen3-32B"
gpu_count = 4
precision = "bf16"
backend = "vllm"

# 2. Check recipe: qwen3-32b-mi300x-bf16.yaml
recipe = {
    "recipe_id": "qwen3-32b-mi300x-bf16",
    "huggingface_id": "Qwen/Qwen3-32B",  # ✅ Matches
    "precision": "bf16",                  # ✅ Matches
    "vllm_serve": {                       # ✅ Backend exists
        "4_gpu": {                        # ✅ GPU count exists
            "enabled": true,              # ✅ Enabled
            "args": { ... }
        }
    }
}

# 3. Recipe selected!
selected_recipe = recipe
```

## 🏗️ **Recipe Structure and Matching**

### **Recipe File Structure**
```yaml
recipe_id: qwen3-32b-mi300x-bf16
model_id: Qwen/Qwen3-32B
huggingface_id: Qwen/Qwen3-32B  # ← Must match user input
hardware: MI300X
precision: bf16                  # ← Must match user input

vllm_serve:                      # ← Must exist for vLLM backend
  "1_gpu":                       # ← Must exist for GPU count
    enabled: true                # ← Must be true
    args:
      --model: Qwen/Qwen3-32B
      --dtype: bfloat16
      --tensor-parallel-size: "1"
      # ... more args
```

### **Matching Logic**
```python
# Pseudo-code for recipe matching
def matches_recipe(user_input, recipe):
    return (
        recipe['huggingface_id'] == user_input.model_id and
        recipe['precision'] == user_input.precision and
        f"{user_input.backend}_serve" in recipe and
        f"{user_input.gpu_count}_gpu" in recipe[f"{user_input.backend}_serve"] and
        recipe[f"{user_input.backend}_serve"][f"{user_input.gpu_count}_gpu"]["enabled"]
    )
```

## 🚀 **Recipe Selection in Action**

### **Example 1: Successful Selection**
```bash
# User command
aim-engine launch Qwen/Qwen3-32B 4 --precision bf16 --backend vllm

# Recipe selection process
1. Load all recipes from /recipes/
2. Find recipes matching:
   - model_id: "Qwen/Qwen3-32B"
   - precision: "bf16"
   - backend: "vllm"
   - gpu_count: 4
3. Found: qwen3-32b-mi300x-bf16.yaml
4. Check: vllm_serve.4_gpu.enabled = true
5. Selected: qwen3-32b-mi300x-bf16
6. Generated config from recipe args
7. Launched container with config
```

### **Example 2: No Matching Recipe**
```bash
# User command
aim-engine launch Qwen/Qwen3-32B 16 --precision fp8 --backend vllm

# Recipe selection process
1. Load all recipes from /recipes/
2. Find recipes matching:
   - model_id: "Qwen/Qwen3-32B" ✅
   - precision: "fp8" ❌ (only bf16 available)
   - backend: "vllm" ✅
   - gpu_count: 16 ❌ (only 1,2,4,8 available)
3. No matching recipes found
4. Error: "No suitable recipe found for Qwen/Qwen3-32B"
```

## 🔧 **Recipe Selection in the Launcher**

### **Integration in AIMEngine.launch_model()**
```python
def launch_model(self, model_id: str, gpu_count: int, precision: str = 'bf16',
                backend: str = 'vllm', port: int = 8000,
                container_name: Optional[str] = None) -> Dict:
    try:
        # Step 1: Validate inputs
        if not self.validate_inputs(model_id, gpu_count, precision, backend):
            return {"success": False, "error": "Invalid inputs"}
        
        # Step 2: Select the best recipe ← RECIPE SELECTION HAPPENS HERE
        recipe = self.recipe_selector.select_recipe(model_id, gpu_count, precision, backend)
        if not recipe:
            return {"success": False, "error": f"No suitable recipe found for {model_id}"}
        
        self.logger.info(f"Selected recipe: {recipe['recipe_id']}")
        
        # Step 3: Generate deployment configuration
        config = self.config_generator.generate_config(
            recipe, gpu_count, precision, backend, port
        )
        
        # Step 4: Launch Docker container
        container_info = self.docker_manager.launch_container(
            config, container_name, gpu_count
        )
        
        # ... rest of deployment process
```

## 📊 **Recipe Selection Examples**

### **Available Recipes**
```bash
# List all available recipes
aim-engine list-recipes

# Example output:
# - qwen3-32b-mi300x-bf16
# - llama-3-8b-mi300x-fp16
# - mistral-7b-mi300x-bf16
```

### **Supported Configurations**
```bash
# Check what configurations are supported for a model
aim-engine show-configurations Qwen/Qwen3-32B

# Example output:
# Qwen/Qwen3-32B supported configurations:
# - 1 GPU, bf16, vLLM: ✅ Enabled
# - 2 GPU, bf16, vLLM: ✅ Enabled
# - 4 GPU, bf16, vLLM: ✅ Enabled
# - 8 GPU, bf16, vLLM: ✅ Enabled
# - 1 GPU, bf16, sglang: ✅ Enabled
# - 2 GPU, bf16, sglang: ✅ Enabled
# - 4 GPU, bf16, sglang: ✅ Enabled
# - 8 GPU, bf16, sglang: ✅ Enabled
```

## 🎯 **Recipe Selection Strategies**

### **Current Strategy: First Match**
- Selects the first recipe that matches all criteria
- Simple and fast
- Good for most use cases

### **Future Enhancement: Performance-Based Selection**
```python
def select_best_recipe_advanced(self, model_id: str, gpu_count: int, 
                               precision: str, backend: str) -> Optional[Dict]:
    """Advanced recipe selection with performance metrics"""
    matching_recipes = self.find_matching_recipes(model_id, gpu_count, precision, backend)
    
    if not matching_recipes:
        return None
    
    # Score recipes based on performance metrics
    scored_recipes = []
    for recipe in matching_recipes:
        score = self.calculate_performance_score(recipe, gpu_count, backend)
        scored_recipes.append((recipe, score))
    
    # Select recipe with highest score
    best_recipe = max(scored_recipes, key=lambda x: x[1])[0]
    return best_recipe

def calculate_performance_score(self, recipe: Dict, gpu_count: int, backend: str) -> float:
    """Calculate performance score for a recipe"""
    config = self.get_recipe_config(recipe, gpu_count, backend)
    
    # Consider factors like:
    # - Throughput (requests/second)
    # - Latency (response time)
    # - Memory efficiency
    # - Cost per request
    # - Hardware optimization level
    
    score = 0.0
    # ... scoring logic
    return score
```

## 🔍 **Debugging Recipe Selection**

### **Enable Debug Logging**
```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Recipe selection will show detailed logs:
# DEBUG: Loaded recipe: qwen3-32b-mi300x-bf16
# DEBUG: Checking recipe qwen3-32b-mi300x-bf16
# DEBUG: Model match: True
# DEBUG: Precision match: True
# DEBUG: Backend match: True
# DEBUG: GPU count match: True
# DEBUG: Enabled: True
# INFO: Selected recipe: qwen3-32b-mi300x-bf16
```

### **Recipe Validation**
```python
# Validate recipe exists before deployment
if not self.recipe_selector.validate_recipe_exists(model_id, gpu_count, precision, backend):
    print(f"No recipe found for {model_id} with {gpu_count} GPUs, {precision} precision, {backend} backend")
    print("Available configurations:")
    configs = self.recipe_selector.get_supported_configurations(model_id)
    for config in configs:
        print(f"  - {config}")
```

## 🎉 **Summary**

**When Recipe Selection Happens:**
- ✅ **During model deployment** (not at runtime)
- ✅ **After input validation** but before container creation
- ✅ **Automatically** based on user parameters
- ✅ **Once per deployment** (not per request)

**How Recipe Selection Works:**
1. **Load all recipes** from `/recipes/` directory
2. **Filter by criteria**: model_id, precision, backend, gpu_count
3. **Check enabled status** for the specific configuration
4. **Select best match** (currently first match, future: performance-based)
5. **Generate configuration** from selected recipe
6. **Launch container** with generated configuration

**Key Points:**
- Recipes are **pre-defined** YAML files with optimized configurations
- Selection is **automatic** and **transparent** to users
- **No manual intervention** required during deployment
- **Performance-optimized** configurations for each hardware/software combination

The recipe selection system ensures that users get the best possible performance for their specific model, hardware, and requirements without needing to understand the underlying optimization details! 