#!/usr/bin/env python3
"""
Setup script for AIM Engine
"""

from setuptools import setup, find_packages
import os

# Read the README file
def read_readme():
    with open("README.md", "r", encoding="utf-8") as fh:
        return fh.read()

# Read requirements
def read_requirements():
    with open("requirements.txt", "r", encoding="utf-8") as fh:
        return [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="aim-engine",
    version="0.1.0",
    author="AMD",
    author_email="your-email@amd.com",
    description="AMD Inference Microservice - AI Model Deployment Made Simple",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    url="https://github.com/Yu-amd/aim-engine",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=read_requirements(),
    entry_points={
        "console_scripts": [
            "aim-generate=aim_engine.aim_generate_command:main",
            "aim-recipe-selector=aim_engine.aim_recipe_selector:main",
            "aim-config-generator=aim_engine.aim_config_generator:main",
            "aim-cache-manager=aim_engine.aim_cache_manager:main",
        ],
    },
    include_package_data=True,
    package_data={
        "aim_engine": [
            "config/*.json",
            "config/models/*.yaml",
            "config/recipes/*.yaml",
            "config/templates/*.yaml",
        ],
    },
) 