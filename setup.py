#!/usr/bin/env python3
"""
Setup script for AIM Engine
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read the README file
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text()

setup(
    name="aim-engine",
    version="1.0.0",
    description="AIM Engine - AI Model Deployment Engine for Single Node Deployment",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="AIM Engine Team",
    author_email="team@aim-engine.com",
    url="https://github.com/your-org/aim-engine",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "requests>=2.31.0",
        "PyYAML>=6.0",
        "jsonschema>=4.17.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "black>=22.0.0",
            "flake8>=4.0.0",
        ],
        "docker": [
            "docker>=6.0.0",
        ],
        "kubernetes": [
            "kubernetes>=26.0.0",
        ],
        "monitoring": [
            "prometheus-client>=0.16.0",
            "psutil>=5.9.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "aim-engine=aim_launcher:main",
        ],
    },
    python_requires=">=3.8",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Distributed Computing",
    ],
    keywords="ai machine-learning model-serving inference vllm rocm docker",
    project_urls={
        "Bug Reports": "https://github.com/your-org/aim-engine/issues",
        "Source": "https://github.com/your-org/aim-engine",
        "Documentation": "https://github.com/your-org/aim-engine/docs",
    },
) 