# AIM Model Context Protocol (MCP) Integration Strategy

## Overview

This document outlines the strategic approach to expand AIM (AI Model Inference) capabilities to support Model Context Protocol (MCP) out of the box, providing seamless integration with modern AI development workflows and enhanced DevOps experience.

## Current AIM Architecture

### **AIM Container Structure**
```
AIM Container
├── vLLM/SGLang Server (Inference Engine)
├── Recipe Selection Engine
├── Cache Management System
├── Configuration Generator
└── OpenAI-Compatible API
```

### **Current Capabilities**
- **Recipe-Based Optimization**: Automatic configuration selection based on model and hardware
- **Multi-Backend Support**: vLLM, SGLang serving backends
- **Hardware Detection**: AMD GPU optimization with ROCm
- **Caching System**: Model file caching and management
- **OpenAI Compatibility**: Standard chat completions API

## MCP Integration Strategy

### **What is Model Context Protocol (MCP)?**

MCP is a protocol that enables AI models to access external data sources, tools, and context in real-time during inference. It provides:
- **Dynamic Context Retrieval**: Access to databases, APIs, documents
- **Tool Integration**: Function calling and external tool execution
- **Real-time Data Access**: Live data integration during inference
- **Contextual Awareness**: Enhanced responses with current information

### **AIM + MCP Architecture Vision**

```
Enhanced AIM Container
├── vLLM/SGLang Server (Inference Engine)
├── Recipe Selection Engine
├── Cache Management System
├── Configuration Generator
├── OpenAI-Compatible API
├── MCP Server (NEW)
│   ├── Context Providers
│   ├── Tool Registry
│   ├── Data Connectors
│   └── MCP Protocol Handler
└── Unified API Gateway
    ├── OpenAI Endpoints
    ├── MCP Endpoints
    └── Health & Metrics
```

## Implementation Strategy

### **Phase 1: MCP Server Integration**

#### **1.1 MCP Server Component**
```python
# src/aim_engine/mcp_server.py
class AIMMCPServer:
    """MCP Server integrated with AIM Engine"""
    
    def __init__(self, config: MCPConfig):
        self.config = config
        self.context_providers = {}
        self.tool_registry = {}
        self.data_connectors = {}
        
    def register_context_provider(self, provider: ContextProvider):
        """Register a context provider (database, API, etc.)"""
        
    def register_tool(self, tool: MCPTool):
        """Register an MCP tool for function calling"""
        
    def handle_mcp_request(self, request: MCPRequest) -> MCPResponse:
        """Handle MCP protocol requests"""
        
    def get_context(self, query: str) -> List[ContextItem]:
        """Retrieve relevant context for a query"""
```

#### **1.2 MCP Configuration Schema**
```yaml
# config/mcp_config.yaml
mcp:
  enabled: true
  port: 8001
  providers:
    - name: "database"
      type: "postgresql"
      config:
        host: "localhost"
        port: 5432
        database: "ai_context"
        credentials:
          secret_name: "db-credentials"
    
    - name: "api"
      type: "rest"
      config:
        base_url: "https://api.example.com"
        auth:
          type: "bearer"
          secret_name: "api-token"
    
    - name: "vector_store"
      type: "chroma"
      config:
        host: "localhost"
        port: 8000
        collection: "documents"
  
  tools:
    - name: "web_search"
      description: "Search the web for current information"
      parameters:
        query:
          type: "string"
          description: "Search query"
    
    - name: "file_reader"
      description: "Read files from the filesystem"
      parameters:
        path:
          type: "string"
          description: "File path to read"
```

### **Phase 2: Enhanced Recipe System**

#### **2.1 MCP-Enabled Recipe Schema**
```json
{
  "recipe_id": "qwen3-32b-mi300x-bf16-mcp",
  "model_id": "Qwen/Qwen3-32B",
  "huggingface_id": "Qwen/Qwen3-32B",
  "hardware": "MI300X",
  "precision": "bf16",
  "mcp_enabled": true,
  "mcp_config": {
    "context_providers": ["database", "api", "vector_store"],
    "tools": ["web_search", "file_reader", "calculator"],
    "max_context_length": 8192,
    "context_retrieval_strategy": "semantic_search"
  },
  "vllm_serve": {
    "1_gpu": {
      "enabled": true,
      "args": {
        "--model": "Qwen/Qwen3-32B",
        "--dtype": "bfloat16",
        "--max-num-batched-tokens": "8192",
        "--max-model-len": "32768",
        "--gpu-memory-utilization": "0.9",
        "--trust-remote-code": "true",
        "--port": "8000",
        "--mcp-port": "8001",
        "--enable-mcp": "true"
      }
    }
  }
}
```

#### **2.2 MCP Recipe Selector**
```python
# src/aim_engine/aim_mcp_recipe_selector.py
class AMMCPRecipeSelector(AIMRecipeSelector):
    """Enhanced recipe selector with MCP capabilities"""
    
    def select_mcp_recipe(self, model_id: str, mcp_requirements: MCPRequirements) -> Optional[Dict]:
        """Select optimal recipe with MCP support"""
        
    def validate_mcp_config(self, recipe: Dict, mcp_config: Dict) -> bool:
        """Validate MCP configuration against recipe capabilities"""
        
    def get_mcp_providers(self, recipe_id: str) -> List[str]:
        """Get available MCP providers for a recipe"""
```

### **Phase 3: Unified API Gateway**

#### **3.1 Enhanced API Endpoints**
```python
# src/aim_engine/api_gateway.py
class AIMAPIGateway:
    """Unified API gateway for OpenAI and MCP endpoints"""
    
    def __init__(self):
        self.openai_server = None
        self.mcp_server = None
        
    async def handle_chat_completion(self, request: ChatCompletionRequest) -> ChatCompletionResponse:
        """Handle OpenAI-compatible chat completions with MCP context"""
        
    async def handle_mcp_request(self, request: MCPRequest) -> MCPResponse:
        """Handle MCP protocol requests"""
        
    async def get_health(self) -> HealthResponse:
        """Health check for both OpenAI and MCP services"""
```

#### **3.2 MCP-Enhanced Chat Completions**
```python
# Enhanced chat completion with MCP context
async def chat_completion_with_mcp(
    messages: List[Message],
    mcp_context: Optional[MCPContext] = None,
    tools: Optional[List[Tool]] = None
) -> ChatCompletionResponse:
    """
    Enhanced chat completion that integrates MCP context and tools
    """
    # 1. Retrieve relevant context using MCP
    if mcp_context:
        context_items = await mcp_server.get_context(messages[-1].content)
        enhanced_messages = inject_context(messages, context_items)
    else:
        enhanced_messages = messages
    
    # 2. Handle tool calls if requested
    if tools:
        tool_results = await execute_tools(tools, mcp_server)
        enhanced_messages = inject_tool_results(enhanced_messages, tool_results)
    
    # 3. Generate response with enhanced context
    return await vllm_server.generate(enhanced_messages)
```

## Kubernetes Operator Integration

### **Enhanced AIMEndpoint CRD**

#### **MCP-Enabled AIMEndpoint**
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: AIMEndpoint
metadata:
  name: qwen-mcp-endpoint
  namespace: aim-engine
spec:
  model:
    id: "Qwen/Qwen3-32B"
    version: "latest"
  
  recipe:
    autoSelect: true
    mcpEnabled: true
  
  mcp:
    enabled: true
    port: 8001
    providers:
      - name: "postgres-db"
        type: "postgresql"
        config:
          host: "postgres-service"
          port: 5432
          database: "ai_context"
          credentials:
            secretName: "postgres-credentials"
      
      - name: "vector-store"
        type: "chroma"
        config:
          host: "chroma-service"
          port: 8000
          collection: "documents"
    
    tools:
      - name: "web_search"
        description: "Search the web for current information"
        enabled: true
      
      - name: "file_reader"
        description: "Read files from the filesystem"
        enabled: true
        config:
          allowedPaths: ["/workspace/data"]
    
    context:
      maxLength: 8192
      retrievalStrategy: "semantic_search"
      cacheEnabled: true
      cacheTTL: "1h"
  
  resources:
    gpuCount: 1
    memory: "32Gi"
    cpu: "8"
  
  service:
    type: LoadBalancer
    ports:
      - name: "openai"
        port: 8000
        targetPort: 8000
      - name: "mcp"
        port: 8001
        targetPort: 8001
  
  monitoring:
    enabled: true
    mcpMetrics:
      enabled: true
      contextRetrievalLatency: true
      toolExecutionLatency: true
      contextHitRate: true
```

### **MCP-Specific CRDs**

#### **MCPProvider CRD**
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: MCPProvider
metadata:
  name: postgres-provider
  namespace: aim-engine
spec:
  type: "postgresql"
  config:
    host: "postgres-service"
    port: 5432
    database: "ai_context"
    credentials:
      secretName: "postgres-credentials"
  security:
    networkPolicy:
      enabled: true
      allowedNamespaces: ["aim-engine"]
  monitoring:
    enabled: true
    metrics:
      - connectionPool
      - queryLatency
      - errorRate
```

#### **MCPTool CRD**
```yaml
apiVersion: aim.engine.amd.com/v1alpha1
kind: MCPTool
metadata:
  name: web-search-tool
  namespace: aim-engine
spec:
  name: "web_search"
  description: "Search the web for current information"
  version: "v1"
  parameters:
    query:
      type: "string"
      description: "Search query"
      required: true
  security:
    allowedDomains: ["*.google.com", "*.bing.com"]
    rateLimit:
      requests: 100
      window: "1m"
  monitoring:
    enabled: true
    metrics:
      - executionLatency
      - successRate
      - rateLimitHits
```

## Developer Experience Enhancements

### **1. MCP Development Tools**

#### **MCP CLI Tool**
```bash
# Install MCP development tools
pip install aim-mcp-cli

# Create MCP provider
aim-mcp create-provider postgres \
  --type postgresql \
  --host localhost \
  --port 5432 \
  --database ai_context

# Create MCP tool
aim-mcp create-tool web-search \
  --description "Search the web for current information" \
  --parameters query:string

# Test MCP integration
aim-mcp test-endpoint qwen-mcp-endpoint \
  --query "What's the latest news about AI?" \
  --context-providers postgres,vector-store \
  --tools web-search
```

#### **MCP Development Environment**
```yaml
# docker-compose.mcp.yml
version: '3.8'
services:
  aim-mcp-dev:
    build: .
    ports:
      - "8000:8000"  # OpenAI API
      - "8001:8001"  # MCP API
    environment:
      - MCP_ENABLED=true
      - MCP_DEBUG=true
    volumes:
      - ./mcp-config:/workspace/mcp-config
      - ./data:/workspace/data
    depends_on:
      - postgres
      - chroma
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ai_context
      POSTGRES_USER: aim
      POSTGRES_PASSWORD: aim123
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  chroma:
    image: chromadb/chroma:latest
    ports:
      - "8000:8000"
    volumes:
      - chroma_data:/chroma/chroma
```

### **2. MCP Testing Framework**

#### **MCP Test Suite**
```python
# tests/test_mcp_integration.py
import pytest
from aim_engine.mcp_testing import MCPTestSuite

class TestMCPIntegration(MCPTestSuite):
    
    def test_context_retrieval(self):
        """Test MCP context retrieval"""
        response = self.client.chat.completions.create(
            model="qwen-mcp",
            messages=[{"role": "user", "content": "What's in the database?"}],
            mcp_context={
                "providers": ["postgres-db"],
                "query": "database content"
            }
        )
        assert response.choices[0].message.content is not None
    
    def test_tool_execution(self):
        """Test MCP tool execution"""
        response = self.client.chat.completions.create(
            model="qwen-mcp",
            messages=[{"role": "user", "content": "Search for AI news"}],
            tools=[{"type": "function", "function": {"name": "web_search"}}]
        )
        assert "tool_calls" in response.choices[0].message
    
    def test_mcp_health_check(self):
        """Test MCP health endpoint"""
        health = self.client.get("/mcp/health")
        assert health.status_code == 200
        assert health.json()["mcp"]["status"] == "healthy"
```

### **3. MCP Monitoring and Observability**

#### **MCP Metrics Dashboard**
```yaml
# monitoring/mcp-grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mcp-grafana-dashboard
data:
  mcp-dashboard.json: |
    {
      "dashboard": {
        "title": "AIM MCP Metrics",
        "panels": [
          {
            "title": "Context Retrieval Latency",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(mcp_context_retrieval_duration_seconds[5m])",
                "legendFormat": "{{provider}}"
              }
            ]
          },
          {
            "title": "Tool Execution Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(mcp_tool_execution_total{status=\"success\"}[5m]) / rate(mcp_tool_execution_total[5m])",
                "legendFormat": "Success Rate"
              }
            ]
          },
          {
            "title": "Context Hit Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(mcp_context_cache_hits_total[5m]) / rate(mcp_context_requests_total[5m])",
                "legendFormat": "Cache Hit Rate"
              }
            ]
          }
        ]
      }
    }
```

## DevOps Experience Enhancements

### **1. MCP Infrastructure as Code**

#### **Terraform MCP Module**
```hcl
# terraform/modules/aim-mcp/main.tf
module "aim_mcp_endpoint" {
  source = "./modules/aim-endpoint"
  
  name = var.endpoint_name
  model_id = var.model_id
  
  mcp_enabled = true
  mcp_config = {
    providers = var.mcp_providers
    tools = var.mcp_tools
    context = var.mcp_context_config
  }
  
  resources = var.resources
  scaling = var.scaling
  monitoring = var.monitoring
}

module "mcp_providers" {
  source = "./modules/mcp-providers"
  
  for_each = var.mcp_providers
  
  name = each.key
  type = each.value.type
  config = each.value.config
  security = each.value.security
}
```

#### **Helm Chart MCP Values**
```yaml
# k8s/helm/values-mcp.yaml
aim_engine:
  mcp:
    enabled: true
    port: 8001
    
    providers:
      postgres:
        type: postgresql
        config:
          host: "{{ .Values.postgres.host }}"
          port: 5432
          database: "{{ .Values.postgres.database }}"
          credentials:
            secretName: "{{ .Values.postgres.secretName }}"
      
      vector_store:
        type: chroma
        config:
          host: "{{ .Values.chroma.host }}"
          port: 8000
          collection: "{{ .Values.chroma.collection }}"
    
    tools:
      web_search:
        enabled: true
        config:
          allowedDomains: ["*.google.com", "*.bing.com"]
          rateLimit:
            requests: 100
            window: "1m"
      
      file_reader:
        enabled: true
        config:
          allowedPaths: ["/workspace/data"]
    
    context:
      maxLength: 8192
      retrievalStrategy: semantic_search
      cacheEnabled: true
      cacheTTL: "1h"
  
  service:
    ports:
      - name: openai
        port: 8000
        targetPort: 8000
      - name: mcp
        port: 8001
        targetPort: 8001
  
  monitoring:
    mcpMetrics:
      enabled: true
      contextRetrievalLatency: true
      toolExecutionLatency: true
      contextHitRate: true
```

### **2. MCP CI/CD Pipeline**

#### **GitHub Actions MCP Workflow**
```yaml
# .github/workflows/mcp-deploy.yml
name: Deploy AIM MCP Endpoint

on:
  push:
    branches: [main]
    paths: ['mcp/**', 'src/aim_engine/mcp/**']

jobs:
  test-mcp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-mcp.txt
      
      - name: Run MCP tests
        run: |
          pytest tests/test_mcp_integration.py -v
          pytest tests/test_mcp_providers.py -v
      
      - name: Test MCP configuration
        run: |
          python -m aim_engine.mcp.validate_config mcp-config.yaml
  
  deploy-mcp:
    needs: test-mcp
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/operator/config/crd/bases/
          kubectl apply -f k8s/operator/examples/aimendpoint-mcp.yaml
      
      - name: Wait for deployment
        run: |
          kubectl wait --for=condition=ready pod -l app=aim-mcp-endpoint --timeout=300s
      
      - name: Run MCP health check
        run: |
          curl -f http://aim-mcp-endpoint:8001/mcp/health
```

### **3. MCP Security and Compliance**

#### **MCP Security Policies**
```yaml
# k8s/security/mcp-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mcp-network-policy
  namespace: aim-engine
spec:
  podSelector:
    matchLabels:
      app: aim-mcp-endpoint
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: aim-engine
      ports:
        - protocol: TCP
          port: 8000  # OpenAI API
        - protocol: TCP
          port: 8001  # MCP API
  
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: mcp-providers
      ports:
        - protocol: TCP
          port: 5432  # PostgreSQL
        - protocol: TCP
          port: 8000  # Chroma
    - to: []
      ports:
        - protocol: TCP
          port: 443   # HTTPS for web search
```

## Benefits of MCP Integration

### **1. Enhanced AI Capabilities**
- **Real-time Context**: Access to live data during inference
- **Tool Integration**: Function calling and external tool execution
- **Dynamic Responses**: Up-to-date information in AI responses
- **Contextual Awareness**: Better understanding of current state

### **2. Developer Experience**
- **Unified API**: Single endpoint for OpenAI and MCP capabilities
- **Easy Configuration**: Declarative MCP configuration
- **Testing Framework**: Comprehensive MCP testing tools
- **Development Environment**: Local MCP development setup

### **3. DevOps Experience**
- **Infrastructure as Code**: Terraform and Helm integration
- **CI/CD Pipeline**: Automated MCP testing and deployment
- **Monitoring**: Comprehensive MCP metrics and dashboards
- **Security**: Built-in security policies and compliance

### **4. Production Readiness**
- **Scalability**: Horizontal scaling with MCP capabilities
- **Reliability**: Health checks and fault tolerance
- **Observability**: Detailed metrics and logging
- **Security**: Network policies and access controls

## Migration Path

### **From Current AIM to MCP-Enabled AIM**

#### **Step 1: Enable MCP in Existing Deployment**
```bash
# Update existing Helm deployment
helm upgrade aim-engine ./helm \
  --set mcp.enabled=true \
  --set mcp.port=8001 \
  --set service.ports[1].name=mcp \
  --set service.ports[1].port=8001 \
  --set service.ports[1].targetPort=8001
```

#### **Step 2: Add MCP Providers**
```bash
# Create MCP provider resources
kubectl apply -f k8s/operator/examples/mcp-provider-postgres.yaml
kubectl apply -f k8s/operator/examples/mcp-provider-chroma.yaml
```

#### **Step 3: Configure MCP Tools**
```bash
# Create MCP tool resources
kubectl apply -f k8s/operator/examples/mcp-tool-web-search.yaml
kubectl apply -f k8s/operator/examples/mcp-tool-file-reader.yaml
```

#### **Step 4: Update Applications**
```python
# Update client code to use MCP capabilities
import openai

client = openai.OpenAI(base_url="http://aim-mcp-endpoint:8000")

# Use MCP context
response = client.chat.completions.create(
    model="qwen-mcp",
    messages=[{"role": "user", "content": "What's the latest data?"}],
    mcp_context={
        "providers": ["postgres-db"],
        "query": "latest data"
    }
)

# Use MCP tools
response = client.chat.completions.create(
    model="qwen-mcp",
    messages=[{"role": "user", "content": "Search for current news"}],
    tools=[{"type": "function", "function": {"name": "web_search"}}]
)
```

## Conclusion

Integrating MCP into AIM provides a powerful foundation for building context-aware AI applications with excellent developer and DevOps experience. The integration leverages AIM's existing recipe system and Kubernetes operator capabilities while adding:

- **Seamless MCP Integration**: Native MCP server within AIM containers
- **Enhanced Recipe System**: MCP-enabled recipes with context and tool configurations
- **Unified API Gateway**: Single endpoint for OpenAI and MCP capabilities
- **Kubernetes Native**: Full operator support for MCP resources
- **Developer Tools**: CLI, testing framework, and development environment
- **DevOps Automation**: Infrastructure as code, CI/CD, and monitoring

This approach transforms AIM from a simple inference endpoint into a comprehensive AI platform that can access external data, execute tools, and provide contextually aware responses while maintaining the simplicity and reliability of the original AIM architecture. 