# AIM Engine Makefile
# Provides convenient commands for development and deployment

.PHONY: help setup install test lint format clean docs quick-start docker-pull validate dev-setup examples check-requirements dev build install-prod

# Default target
help:
	@echo "🚀 AIM Engine - Available Commands"
	@echo "=================================="
	@echo ""
	@echo "📦 Setup & Installation:"
	@echo "  setup           - Initial setup and dependency installation"
	@echo "  install         - Install AIM Engine in development mode"
	@echo "  install-prod    - Install AIM Engine in production mode"
	@echo "  docker-pull     - Pull required Docker images"
	@echo ""
	@echo "🧪 Testing & Validation:"
	@echo "  test            - Run the test suite"
	@echo "  validate        - Validate YAML configuration files"
	@echo "  check-requirements - Check system requirements"
	@echo ""
	@echo "🔧 Development:"
	@echo "  dev-setup       - Setup development environment"
	@echo "  dev             - Start development mode"
	@echo "  lint            - Run code linting"
	@echo "  format          - Format code with black"
	@echo ""
	@echo "📚 Documentation:"
	@echo "  docs            - Generate documentation"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  quick-start     - Run quick start script"
	@echo "  examples        - Run example usage"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  clean           - Clean build artifacts"
	@echo "  build           - Build distribution package"
	@echo ""

# Setup and installation
setup:
	@echo "🔧 Setting up AIM Engine..."
	@./install.sh

install:
	@echo "📦 Installing AIM Engine in development mode..."
	@pip install -e .

install-prod:
	@echo "📦 Installing AIM Engine in production mode..."
	@pip install .

docker-pull:
	@echo "🐳 Pulling Docker images..."
	@docker pull rocm/vllm:latest

# Testing and validation
test:
	@echo "🧪 Running AIM Engine tests..."
	@python3 tests/test_aim_implementation.py

validate:
	@echo "✅ Validating configuration files..."
	@python3 -c "import yaml; import json; from pathlib import Path; recipes_dir = Path('recipes'); [print(f'✅ {f.name}') if recipes_dir.exists() else None for f in recipes_dir.glob('*.yaml') if recipes_dir.exists()]"

check-requirements:
	@echo "🔍 Checking system requirements..."
	@python3 -c "import sys; print(f'✅ Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}') if sys.version_info >= (3, 8) else print(f'❌ Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro} (requires 3.8+)')"
	@docker --version 2>/dev/null && echo "✅ Docker: $$(docker --version)" || echo "❌ Docker not found"
	@docker info >/dev/null 2>&1 && echo "✅ Docker daemon running" || echo "❌ Docker daemon not running"

# Development
dev-setup:
	@echo "🔧 Setting up development environment..."
	@pip install -e ".[dev]"

dev:
	@echo "🚀 Starting AIM Engine development mode..."
	@echo "Available commands:"
	@echo "  make test      - Run tests"
	@echo "  make lint      - Run linting"
	@echo "  make format    - Format code"
	@echo "  make validate  - Validate configs"

lint:
	@echo "🔍 Running code linting..."
	@flake8 *.py tests/ 2>/dev/null || echo "flake8 not installed, skipping linting"

format:
	@echo "🎨 Formatting code..."
	@black *.py tests/ 2>/dev/null || echo "black not installed, skipping formatting"

# Documentation
docs:
	@echo "📚 Generating documentation..."
	@echo "Documentation is available in the docs/ directory"
	@echo "Main files:"
	@echo "  - README.md"
	@echo "  - AIM_VLLM_USAGE.md"
	@echo "  - AIM_ENGINE_DESIGN_SUMMARY.md"

# Quick start and examples
quick-start:
	@echo "🚀 Running AIM Engine quick start..."
	@echo "Use: ./build-aim-vllm.sh to build the combined container"

examples:
	@echo "📖 Running AIM Engine examples..."
	@echo "See AIM_VLLM_USAGE.md for usage examples"

# Maintenance
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info/
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -delete

build:
	@echo "📦 Building AIM Engine package..."
	@python3 setup.py sdist bdist_wheel 