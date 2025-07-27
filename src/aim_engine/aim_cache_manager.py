#!/usr/bin/env python3
"""
AIM Engine - Cache Manager

This module provides model caching functionality to optimize deployments
by ensuring only model differences need to be downloaded.
"""

import os
import shutil
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import json
import hashlib
from datetime import datetime

logger = logging.getLogger(__name__)

class AIMCacheManager:
    """Manages model caching for AIM Engine deployments"""
    
    def __init__(self, cache_dir: str = "/workspace/model-cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.cache_index_file = self.cache_dir / "cache_index.json"
        self.cache_index = self._load_cache_index()
        
        # Set up logging
        logging.basicConfig(level=logging.INFO)
    
    def _load_cache_index(self) -> Dict:
        """Load cache index from file"""
        if self.cache_index_file.exists():
            try:
                with open(self.cache_index_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"Could not load cache index: {e}")
        return {}
    
    def _save_cache_index(self):
        """Save cache index to file"""
        try:
            with open(self.cache_index_file, 'w') as f:
                json.dump(self.cache_index, f, indent=2)
        except Exception as e:
            logger.error(f"Could not save cache index: {e}")
    
    def get_cache_info(self, model_id: str) -> Dict:
        """Get cache information for a model"""
        return self.cache_index.get(model_id, {})
    
    def is_model_cached(self, model_id: str) -> bool:
        """Check if a model is cached"""
        cache_info = self.get_cache_info(model_id)
        if not cache_info:
            return False
        
        # Check if model files exist
        model_path = self.cache_dir / "models" / model_id.replace("/", "--")
        return model_path.exists() and cache_info.get("cached", False)
    
    def get_model_cache_path(self, model_id: str) -> Path:
        """Get the cache path for a model"""
        return self.cache_dir / "models" / model_id.replace("/", "--")
    
    def add_model_to_cache(self, model_id: str, model_path: Path, commit_hash: str = None):
        """Add a model to the cache"""
        try:
            # Create cache directory for model
            cache_path = self.get_model_cache_path(model_id)
            cache_path.mkdir(parents=True, exist_ok=True)
            
            # Copy model files to cache
            if model_path.is_dir():
                shutil.copytree(model_path, cache_path, dirs_exist_ok=True)
            else:
                shutil.copy2(model_path, cache_path)
            
            # Update cache index
            self.cache_index[model_id] = {
                "cached": True,
                "cache_path": str(cache_path),
                "commit_hash": commit_hash,
                "cached_at": datetime.now().isoformat(),
                "size": self._get_directory_size(cache_path)
            }
            
            self._save_cache_index()
            logger.info(f"Added {model_id} to cache at {cache_path}")
            
        except Exception as e:
            logger.error(f"Failed to add {model_id} to cache: {e}")
    
    def _get_directory_size(self, path: Path) -> int:
        """Get directory size in bytes"""
        total_size = 0
        try:
            for dirpath, dirnames, filenames in os.walk(path):
                for filename in filenames:
                    filepath = os.path.join(dirpath, filename)
                    total_size += os.path.getsize(filepath)
        except Exception as e:
            logger.warning(f"Could not calculate size for {path}: {e}")
        return total_size
    
    def remove_model_from_cache(self, model_id: str):
        """Remove a model from the cache"""
        try:
            cache_path = self.get_model_cache_path(model_id)
            if cache_path.exists():
                shutil.rmtree(cache_path)
            
            if model_id in self.cache_index:
                del self.cache_index[model_id]
                self._save_cache_index()
            
            logger.info(f"Removed {model_id} from cache")
            
        except Exception as e:
            logger.error(f"Failed to remove {model_id} from cache: {e}")
    
    def list_cached_models(self) -> List[Dict]:
        """List all cached models"""
        cached_models = []
        for model_id, info in self.cache_index.items():
            if info.get("cached", False):
                cached_models.append({
                    "model_id": model_id,
                    "cache_path": info.get("cache_path"),
                    "cached_at": info.get("cached_at"),
                    "size": info.get("size", 0),
                    "commit_hash": info.get("commit_hash")
                })
        return cached_models
    
    def get_cache_stats(self) -> Dict:
        """Get cache statistics"""
        cached_models = self.list_cached_models()
        total_size = sum(model["size"] for model in cached_models)
        
        return {
            "total_models": len(cached_models),
            "total_size": total_size,
            "total_size_gb": total_size / (1024**3),
            "cache_dir": str(self.cache_dir),
            "models": cached_models
        }
    
    def cleanup_old_models(self, days_old: int = 30):
        """Clean up models older than specified days"""
        try:
            cutoff_date = datetime.now().timestamp() - (days_old * 24 * 60 * 60)
            models_to_remove = []
            
            for model_id, info in self.cache_index.items():
                if info.get("cached", False):
                    cached_at = datetime.fromisoformat(info["cached_at"]).timestamp()
                    if cached_at < cutoff_date:
                        models_to_remove.append(model_id)
            
            for model_id in models_to_remove:
                self.remove_model_from_cache(model_id)
            
            logger.info(f"Cleaned up {len(models_to_remove)} old models")
            
        except Exception as e:
            logger.error(f"Failed to cleanup old models: {e}")
    
    def generate_cache_environment(self, model_id: str) -> Dict[str, str]:
        """Generate environment variables for cached model"""
        env_vars = {
            "HF_HOME": str(self.cache_dir),
            "TRANSFORMERS_CACHE": str(self.cache_dir),
            "HF_DATASETS_CACHE": str(self.cache_dir),
            "VLLM_CACHE_DIR": str(self.cache_dir),
            "HF_HUB_DISABLE_TELEMETRY": "1",
            "PYTORCH_CUDA_ALLOC_CONF": "max_split_size_mb:512"
        }
        
        # If model is cached, add specific path
        if self.is_model_cached(model_id):
            cache_path = self.get_model_cache_path(model_id)
            env_vars["MODEL_CACHE_PATH"] = str(cache_path)
        
        return env_vars
    
    def generate_cache_volumes(self, model_id: str) -> List[str]:
        """Generate volume mounts for cached model"""
        volumes = [f"{self.cache_dir}:/workspace/model-cache:ro"]
        
        # If model is cached, add specific model volume
        if self.is_model_cached(model_id):
            cache_path = self.get_model_cache_path(model_id)
            volumes.append(f"{cache_path}:/workspace/models/{model_id.replace('/', '--')}:ro")
        
        return volumes

class AIMCacheCLI:
    """Command-line interface for cache management"""
    
    def __init__(self, cache_dir: str = "/workspace/model-cache"):
        self.cache_manager = AIMCacheManager(cache_dir)
    
    def list_models(self):
        """List all cached models"""
        cached_models = self.cache_manager.list_cached_models()
        
        if not cached_models:
            print("No models currently cached.")
            return
        
        print(f"\n📦 Cached Models ({len(cached_models)}):")
        print("=" * 80)
        
        for model in cached_models:
            size_gb = model["size"] / (1024**3)
            print(f"🔹 {model['model_id']}")
            print(f"   📁 Cache Path: {model['cache_path']}")
            print(f"   📅 Cached: {model['cached_at']}")
            print(f"   💾 Size: {size_gb:.2f} GB")
            if model.get("commit_hash"):
                print(f"   🔗 Commit: {model['commit_hash'][:8]}")
            print()
    
    def cache_stats(self):
        """Show cache statistics"""
        stats = self.cache_manager.get_cache_stats()
        
        print(f"\n📊 Cache Statistics:")
        print("=" * 40)
        print(f"📁 Cache Directory: {stats['cache_dir']}")
        print(f"🔢 Total Models: {stats['total_models']}")
        print(f"💾 Total Size: {stats['total_size_gb']:.2f} GB")
        print(f"📅 Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    def add_model(self, model_id: str, model_path: str):
        """Add a model to cache"""
        model_path = Path(model_path)
        
        if not model_path.exists():
            print(f"❌ Error: Model path {model_path} does not exist")
            return
        
        print(f"📥 Adding {model_id} to cache...")
        self.cache_manager.add_model_to_cache(model_id, model_path)
        print(f"✅ Successfully added {model_id} to cache")
    
    def remove_model(self, model_id: str):
        """Remove a model from cache"""
        if not self.cache_manager.is_model_cached(model_id):
            print(f"❌ Error: Model {model_id} is not cached")
            return
        
        print(f"🗑️  Removing {model_id} from cache...")
        self.cache_manager.remove_model_from_cache(model_id)
        print(f"✅ Successfully removed {model_id} from cache")
    
    def cleanup(self, days: int = 30):
        """Clean up old models"""
        print(f"🧹 Cleaning up models older than {days} days...")
        self.cache_manager.cleanup_old_models(days)
        print("✅ Cleanup completed")
    
    def setup_cache(self):
        """Set up cache directory and permissions"""
        cache_dir = self.cache_manager.cache_dir
        
        try:
            # Create cache directory
            cache_dir.mkdir(parents=True, exist_ok=True)
            
            # Set permissions
            os.chmod(cache_dir, 0o755)
            
            # Create subdirectories
            (cache_dir / "models").mkdir(exist_ok=True)
            (cache_dir / "tokenizers").mkdir(exist_ok=True)
            (cache_dir / "configs").mkdir(exist_ok=True)
            
            print(f"✅ Cache setup completed at {cache_dir}")
            print(f"📁 Created directories: models, tokenizers, configs")
            
        except Exception as e:
            print(f"❌ Error setting up cache: {e}")

def main():
    """Main CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="AIM Engine Cache Manager")
    parser.add_argument("--cache-dir", default="/workspace/model-cache", 
                       help="Cache directory path")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List command
    subparsers.add_parser("list", help="List cached models")
    
    # Stats command
    subparsers.add_parser("stats", help="Show cache statistics")
    
    # Add command
    add_parser = subparsers.add_parser("add", help="Add model to cache")
    add_parser.add_argument("model_id", help="Model ID (e.g., Qwen/Qwen3-32B)")
    add_parser.add_argument("model_path", help="Path to model files")
    
    # Remove command
    remove_parser = subparsers.add_parser("remove", help="Remove model from cache")
    remove_parser.add_argument("model_id", help="Model ID to remove")
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Clean up old models")
    cleanup_parser.add_argument("--days", type=int, default=30, 
                               help="Remove models older than N days")
    
    # Setup command
    subparsers.add_parser("setup", help="Set up cache directory")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    cli = AIMCacheCLI(args.cache_dir)
    
    if args.command == "list":
        cli.list_models()
    elif args.command == "stats":
        cli.cache_stats()
    elif args.command == "add":
        cli.add_model(args.model_id, args.model_path)
    elif args.command == "remove":
        cli.remove_model(args.model_id)
    elif args.command == "cleanup":
        cli.cleanup(args.days)
    elif args.command == "setup":
        cli.setup_cache()

if __name__ == "__main__":
    main() 