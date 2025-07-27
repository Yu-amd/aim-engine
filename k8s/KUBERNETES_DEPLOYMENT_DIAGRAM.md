# AIM Engine Kubernetes Deployment Architecture

## **System Architecture Overview**

```mermaid
graph TB
    %% User/Admin
    User[👤 User/Admin]
    
    %% External Systems
    Internet[🌐 Internet]
    ModelRegistry[HuggingFace Model Registry]
    
    %% Local Infrastructure
    subgraph "Local Node"
        subgraph "Docker Layer"
            LocalRegistry[📦 Local Registry<br/>localhost:5000]
            AIMImage[🐳 AIM Engine Image<br/>aim-vllm:latest]
        end
        
        subgraph "Kubernetes Cluster"
            subgraph "System Components"
                KubeAPI[🔌 Kubernetes API Server]
                KubeScheduler[📅 Scheduler]
                KubeController[🎛️ Controller Manager]
                Etcd[💾 etcd]
            end
            
            subgraph "Network Layer"
                Calico[🌐 Calico CNI]
                CoreDNS[🔍 CoreDNS]
            end
            
            subgraph "Storage Layer"
                LocalStorage[💿 Local Path Provisioner]
                ModelCache[📁 Model Cache PVC]
            end
            
            subgraph "GPU Layer"
                AMDGPUPlugin[🎮 AMD GPU Device Plugin]
                ROCm[⚡ ROCm Runtime]
            end
            
            subgraph "Monitoring Layer"
                MetricsServer[📊 Metrics Server]
                Prometheus[📈 Prometheus]
                Grafana[📊 Grafana]
            end
            
            subgraph "AIM Engine Namespace"
                subgraph "Recipe System"
                    RecipeSelector[🎯 Recipe Selector Job]
                    RecipeValidator[✅ Admission Controller]
                    RecipeConfig[⚙️ Recipe ConfigMap]
                end
                
                subgraph "Core Application"
                    AIMDeployment[🚀 AIM Engine Deployment]
                    AIMService[🔗 NodePort Service]
                    AIMPod[📦 AIM Engine Pod]
                end
                
                subgraph "Application Components"
                    vLLM[vLLM Server]
                    RecipeEngine[Recipe Engine]
                    Monitoring[Custom Metrics]
                end
            end
        end
    end
    
    %% External Access
    ExternalClient[💻 External Client]
    
    %% Connections - Setup Flow
    User -->|1. Setup Script| LocalRegistry
    User -->|2. Build Image| AIMImage
    User -->|3. Deploy| KubeAPI
    
    %% Connections - Image Flow
    AIMImage -->|Push| LocalRegistry
    LocalRegistry -->|Pull| AIMPod
    
    %% Connections - Model Flow
    Internet -->|Download Models| ModelRegistry
    ModelRegistry -->|Cache| ModelCache
    ModelCache -->|Mount| AIMPod
    
    %% Connections - Kubernetes Flow
    KubeAPI --> KubeScheduler
    KubeScheduler --> AIMDeployment
    AIMDeployment --> AIMPod
    KubeAPI --> Etcd
    
    %% Connections - Network Flow
    Calico --> AIMPod
    CoreDNS --> AIMPod
    AIMService --> AIMPod
    
    %% Connections - Storage Flow
    LocalStorage --> ModelCache
    ModelCache --> AIMPod
    
    %% Connections - GPU Flow
    AMDGPUPlugin --> AIMPod
    ROCm --> AIMPod
    
    %% Connections - Monitoring Flow
    MetricsServer --> AIMPod
    Prometheus --> Monitoring
    Grafana --> Prometheus
    
    %% Connections - Recipe Flow
    RecipeSelector --> RecipeConfig
    RecipeValidator --> AIMDeployment
    RecipeConfig --> AIMPod
    
    %% Connections - Application Flow
    AIMPod --> vLLM
    AIMPod --> RecipeEngine
    AIMPod --> Monitoring
    
    %% External Access Flow
    ExternalClient -->|HTTP Request| AIMService
    AIMService -->|Port Forward| AIMPod
    
    %% Styling
    classDef userClass fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef systemClass fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef appClass fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef infraClass fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef monitoringClass fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class User,ExternalClient userClass
    class KubeAPI,KubeScheduler,KubeController,Etcd,Calico,CoreDNS,LocalStorage,AMDGPUPlugin,ROCm systemClass
    class AIMDeployment,AIMService,AIMPod,vLLM,RecipeEngine,RecipeSelector,RecipeValidator,RecipeConfig appClass
    class LocalRegistry,AIMImage,ModelCache,ModelRegistry,Internet infraClass
    class MetricsServer,Prometheus,Grafana,Monitoring monitoringClass
```

## **Deployment Flow**

```mermaid
sequenceDiagram
    participant U as User
    participant S as Setup Script
    participant D as Docker
    participant R as Local Registry
    participant K as Kubernetes
    participant G as GPU Plugin
    participant A as AIM Engine
    
    Note over U,A: Complete Setup Flow
    
    U->>S: Run setup-complete-kubernetes.sh
    S->>S: System preparation
    S->>D: Install containerd
    S->>R: Start local registry
    S->>D: Build AIM Engine image
    S->>R: Push image to registry
    S->>K: Install Kubernetes components
    S->>K: Initialize cluster
    S->>K: Install Calico CNI
    S->>K: Install metrics server
    S->>K: Install storage provisioner
    S->>G: Setup AMD GPU support
    S->>K: Create namespace
    S->>K: Deploy AIM Engine
    S->>A: Wait for deployment ready
    
    Note over U,A: Deployment Flow
    
    U->>K: Run deploy-aim-engine.sh
    K->>K: Check cluster health
    K->>G: Verify GPU availability
    K->>R: Ensure registry running
    K->>D: Build/push image if needed
    K->>K: Deploy with Helm
    K->>A: Create AIM Engine pod
    A->>A: Load model and start vLLM
    K->>U: Return service endpoint
```

## **Recipe Selection Flow**

```mermaid
flowchart TD
    Start([Deploy AIM Engine]) --> CheckAuto{Auto Select?}
    
    CheckAuto -->|Yes| DetectGPU[Detect Available GPUs]
    CheckAuto -->|No| ManualConfig[Use Manual Configuration]
    
    DetectGPU --> AnalyzeModel[Analyze Model Requirements]
    AnalyzeModel --> FilterRecipes[Filter Compatible Recipes]
    FilterRecipes --> RankRecipes[Rank by Performance]
    RankRecipes --> ValidateResources[Validate Resource Requirements]
    
    ValidateResources --> ResourcesOK{Resources Available?}
    ResourcesOK -->|Yes| SelectRecipe[Select Best Recipe]
    ResourcesOK -->|No| FallbackRecipe[Select Fallback Recipe]
    
    SelectRecipe --> ApplyConfig[Apply Recipe Configuration]
    FallbackRecipe --> ApplyConfig
    ManualConfig --> ApplyConfig
    
    ApplyConfig --> ValidateConfig[Validate Configuration]
    ValidateConfig --> ConfigOK{Configuration Valid?}
    ConfigOK -->|Yes| Deploy[Deploy AIM Engine]
    ConfigOK -->|No| Error[Configuration Error]
    
    Deploy --> Monitor[Monitor Deployment]
    Monitor --> Success[Deployment Successful]
    
    Error --> LogError[Log Error Details]
    LogError --> End([End])
    Success --> End
```

## **Resource Allocation**

```mermaid
graph LR
    subgraph "Hardware Resources"
        GPU[🎮 AMD GPUs<br/>MI300X/MI325X]
        CPU[🖥️ CPU Cores<br/>4-32 cores]
        Memory[💾 RAM<br/>16-512GB]
        Storage[💿 Storage<br/>50GB-1TB]
    end
    
    subgraph "Kubernetes Resources"
        GPUResource[amd.com/gpu<br/>1-8 GPUs]
        CPUResource[cpu<br/>4-32 cores]
        MemoryResource[memory<br/>16-512Gi]
        StorageResource[storage<br/>50Gi-1Ti]
    end
    
    subgraph "AIM Engine Pod"
        GPULimit[GPU Limit<br/>Based on Recipe]
        CPURequest[CPU Request<br/>Based on Model]
        MemoryLimit[Memory Limit<br/>Based on Model Size]
        ModelCache[Model Cache<br/>Persistent Storage]
    end
    
    GPU --> GPUResource
    CPU --> CPUResource
    Memory --> MemoryResource
    Storage --> StorageResource
    
    GPUResource --> GPULimit
    CPUResource --> CPURequest
    MemoryResource --> MemoryLimit
    StorageResource --> ModelCache
```

## **Monitoring Architecture**

```mermaid
graph TB
    subgraph "AIM Engine Pod"
        AIMApp[AIM Engine Application]
        CustomMetrics[Custom Metrics Endpoint]
    end
    
    subgraph "Monitoring Stack"
        ServiceMonitor[ServiceMonitor]
        Prometheus[Prometheus Server]
        Grafana[Grafana Dashboard]
        AlertManager[Alert Manager]
    end
    
    subgraph "Recipe Metrics"
        RecipeSelection[Recipe Selection Metrics]
        PerformanceMetrics[Performance Metrics]
        ResourceMetrics[Resource Utilization]
    end
    
    subgraph "Kubernetes Metrics"
        KubeMetrics[Kubernetes Metrics Server]
        NodeMetrics[Node Metrics]
        PodMetrics[Pod Metrics]
    end
    
    AIMApp --> CustomMetrics
    CustomMetrics --> ServiceMonitor
    ServiceMonitor --> Prometheus
    
    RecipeSelection --> Prometheus
    PerformanceMetrics --> Prometheus
    ResourceMetrics --> Prometheus
    
    KubeMetrics --> Prometheus
    NodeMetrics --> Prometheus
    PodMetrics --> Prometheus
    
    Prometheus --> Grafana
    Prometheus --> AlertManager
    
    Grafana --> Dashboard[Recipe Performance Dashboard]
    AlertManager --> Alerts[Performance Alerts]
```

## **Network Architecture**

```mermaid
graph TB
    subgraph "External Access"
        Client[External Client]
        LoadBalancer[Load Balancer]
    end
    
    subgraph "Kubernetes Cluster"
        subgraph "Node"
            NodePort[NodePort Service<br/>30000-32767]
            AIMPod[AIM Engine Pod<br/>Port 8000]
        end
        
        subgraph "Internal Services"
            ClusterIP[ClusterIP Service]
            Ingress[Ingress Controller]
        end
    end
    
    subgraph "Network Policies"
        NetworkPolicy[Network Policy]
        RBAC[RBAC Rules]
    end
    
    Client --> LoadBalancer
    LoadBalancer --> NodePort
    NodePort --> AIMPod
    
    ClusterIP --> AIMPod
    Ingress --> ClusterIP
    
    NetworkPolicy --> AIMPod
    RBAC --> AIMPod
```

## **Deployment States**

```mermaid
stateDiagram-v2
    [*] --> Setup: Run setup script
    Setup --> RegistryRunning: Start local registry
    RegistryRunning --> ImageBuilt: Build AIM image
    ImageBuilt --> ImagePushed: Push to registry
    ImagePushed --> ClusterReady: Initialize cluster
    ClusterReady --> GPUReady: Setup GPU support
    GPUReady --> NamespaceCreated: Create namespace
    NamespaceCreated --> Deploying: Deploy AIM Engine
    Deploying --> PodCreating: Create pod
    PodCreating --> ImagePulling: Pull image
    ImagePulling --> ContainerStarting: Start container
    ContainerStarting --> ModelLoading: Load model
    ModelLoading --> vLLMStarting: Start vLLM server
    vLLMStarting --> Ready: Service ready
    Ready --> [*]
    
    Setup --> SetupFailed: Setup error
    SetupFailed --> [*]
    
    ImagePulling --> PullFailed: Pull error
    PullFailed --> [*]
    
    ModelLoading --> LoadFailed: Load error
    LoadFailed --> [*]
    
    vLLMStarting --> StartFailed: Start error
    StartFailed --> [*]
```

## **Cleanup Flow**

```mermaid
flowchart TD
    Start([Start Cleanup]) --> CheckType{Cleanup Type?}
    
    CheckType -->|Basic| RemoveK8s[Remove Kubernetes Resources]
    CheckType -->|Images| RemoveImages[Remove Docker Images]
    CheckType -->|Registry| RemoveRegistry[Remove Local Registry]
    CheckType -->|All| RemoveAll[Remove Everything]
    
    RemoveK8s --> UninstallHelm[Uninstall Helm Release]
    UninstallHelm --> DeleteNamespace[Delete Namespace]
    DeleteNamespace --> StopRegistry[Stop Registry Container]
    
    RemoveImages --> RemoveAIMImage[Remove AIM Engine Images]
    RemoveImages --> CleanupDangling[Cleanup Dangling Images]
    
    RemoveRegistry --> StopRegistry
    RemoveRegistry --> RemoveRegistryImage[Remove Registry Image]
    
    RemoveAll --> RemoveK8s
    RemoveAll --> RemoveImages
    RemoveAll --> RemoveRegistry
    RemoveAll --> ResetCluster[Reset Kubernetes Cluster]
    
    StopRegistry --> End([Cleanup Complete])
    RemoveAIMImage --> End
    RemoveRegistryImage --> End
    ResetCluster --> End
    CleanupDangling --> End
```

## **Usage Examples**

```mermaid
graph LR
    subgraph "Deployment Commands"
        C1[Complete Setup<br/>setup-complete-kubernetes.sh]
        C2[Deploy to Existing<br/>deploy-aim-engine.sh]
        C3[Custom Model<br/>--model Qwen/Qwen3-32B]
        C4[Multiple GPUs<br/>--gpu-count 2]
    end
    
    subgraph "Verification Commands"
        V1[Check Pods<br/>kubectl get pods]
        V2[Check Logs<br/>kubectl logs]
        V3[Test Health<br/>curl /health]
        V4[Test Inference<br/>curl /v1/chat/completions]
    end
    
    subgraph "Monitoring Commands"
        M1[Check Metrics<br/>kubectl top pods]
        M2[Port Forward<br/>kubectl port-forward]
        M3[Check GPU<br/>rocm-smi]
        M4[Recipe Status<br/>kubectl logs recipe-selector]
    end
    
    C1 --> V1
    C2 --> V1
    C3 --> V2
    C4 --> M3
    
    V1 --> V2
    V2 --> V3
    V3 --> V4
    
    V4 --> M1
    M1 --> M2
    M2 --> M3
    M3 --> M4
```

These diagrams provide a comprehensive view of the AIM Engine Kubernetes deployment architecture, from initial setup through monitoring and cleanup. 