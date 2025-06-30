# 🤖 Metro.AI PowerShell Module

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Metro.AI?label=PowerShell%20Gallery&logo=powershell)](https://www.powershellgallery.com/packages/Metro.AI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Azure AI](https://img.shields.io/badge/Azure-AI%20Foundry-blue?logo=microsoft-azure)](https://azure.microsoft.com/en-us/products/ai-services/)

Metro.AI is a powerful PowerShell module that simplifies working with **Azure AI Agent and Assistant APIs**. It provides a unified, intuitive command set to manage AI resources, upload files, start and monitor conversations, and integrate custom functions—all from your PowerShell console.

## 📋 Table of Contents

- [🚀 Quick Start](#-quick-start)
- [🔧 Setup & Configuration](#-setup--configuration)
- [📚 Core Features](#-core-features)
  - [Agent Management](#agent-management)
  - [Thread & Message Handling](#thread--message-handling)
  - [Advanced Agent Orchestration](#advanced-agent-orchestration)
  - [Bing Grounding Integration](#bing-grounding-integration)
  - [MCP Server Integration](#mcp-server-integration)
- [💡 Usage Examples](#-usage-examples)
- [🔄 Advanced Workflows](#-advanced-workflows)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

## 🚀 Quick Start

Install the module directly from the PowerShell Gallery:

```powershell
Install-Module Metro.AI -Force
```

## 🔧 Setup & Configuration

### Connecting to Azure

Before using Metro.AI, ensure you're connected to your Azure account:

```powershell
Connect-AzAccount
```

### Setting Up Metro.AI Context

Retrieve the connection string or project URI from your Azure AI Foundry project, then configure Metro.AI:

#### 🆕 GA Version of AI Foundry
```powershell
# Example project URI (from GA version of foundry)
Set-MetroAIContext -Endpoint https://aiservicesw3ba.services.ai.azure.com/api/projects/projectw3ba -ApiType Agent
Get-MetroAIContext
```

#### 🔍 Preview Version of AI Foundry
```powershell
# Example project connection string (from preview version of foundry)
$connectionString = "swedencentral.api.azureml.ms;80ffa654-da7f-4c46-8d9a-9ed75956766e;ai-foundry-workflows;admin-7818"

Set-MetroAIContext -ConnectionString $connectionString -ApiType Agent
Get-MetroAIContext
```

## 📚 Core Features

### Agent Management

#### 🆕 Creating a New Agent

Define your agent's instructions and create a new Metro.AI agent using GPT-4.1:

```powershell
$instructions = @"
You are a helpful assistant. Your task is to assist the user with their queries and provide relevant information.
You should always be polite and respectful. If you do not know the answer to a question, you should say so.
You should not provide personal opinions or make assumptions about the user.
Always ask clarifying questions if the user's request is unclear.
"@

New-MetroAIAgent -ResourceName "myAgent" -Model "gpt-4.1" -Instructions $instructions
```

#### 📋 Working with Existing Agents

Metro.AI provides powerful pipeline support for managing existing agents, allowing you to easily copy, modify, and export agent configurations.

##### 🔄 Copying an Existing Agent

You can create a new agent based on an existing one using PowerShell pipeline operations:

```powershell
# Get an existing agent and create a copy with a new name
$originalAgent = Get-MetroAIAgent -AssistantId "asst_abc123"
$copiedAgent = $originalAgent | New-MetroAIAgent -Name "CopiedAgent"

# Copy with modifications - override specific properties while copying
$enhancedAgent = $originalAgent | New-MetroAIAgent -Name "EnhancedAgent" `
    -Model "gpt-4.1" `
    -Description "Enhanced version of the original agent"

Write-Output "Created new agent: $($enhancedAgent.name) with ID: $($enhancedAgent.id)"
```

##### ✏️ Updating an Existing Agent

You can modify an agent object and update it seamlessly:

```powershell
# Get an agent, modify its properties, and update it
$agent = Get-MetroAIAgent -AssistantId "asst_abc123"
$agent.Description = "Updated description for better clarity"
$agent.Instructions = @"
You are an expert PowerShell assistant. Help users with PowerShell scripting,
automation, and Azure management tasks. Always provide working examples
and explain best practices.
"@

# Update the agent with the modified properties
$updatedAgent = $agent | Set-MetroAIAgent
Write-Output "Updated agent: $($updatedAgent.name)"

# You can also override specific properties during the update
Get-MetroAIAgent -AssistantId "asst_abc123" | Set-MetroAIAgent -Name "NewName" -Temperature 0.5
```

##### 📥📤 Exporting and Importing Agent Configurations

Export an agent configuration to JSON for backup, version control, or sharing:

```powershell
# Export an existing agent to JSON file
$agent = Get-MetroAIAgent -AssistantId "asst_abc123"
$agent | ConvertTo-Json -Depth 100 | Out-File -FilePath "./my-agent-backup.json" -Encoding UTF8

Write-Output "Agent configuration exported to my-agent-backup.json"

# Create a new agent from the exported JSON file
$newAgentFromFile = New-MetroAIAgent -InputFile "./my-agent-backup.json"
Write-Output "Created agent from file: $($newAgentFromFile.name) with ID: $($newAgentFromFile.id)"

# Update an existing agent from a JSON file
Set-MetroAIAgent -AssistantId "asst_xyz789" -InputFile "./my-agent-backup.json"
```

### Thread & Message Handling

#### 💬 Creating and Managing Threads

Start a new conversation thread:

```powershell
$thread = New-MetroAIThread
```

Add a message to the thread:

```powershell
$message = Invoke-MetroAIMessage -ThreadID $thread.id -Message "Hello, can you generate a PowerShell script that I can download as a file to connect to Azure?"
```

Execute the thread with your agent:

```powershell
$run = Start-MetroAIThreadRun -ThreadID $thread.id -AssistantId $yourAgent.id
```

#### 📁 Working with Generated Files

After execution, the agent can generate downloadable files:

```powershell
# List available output files
Get-MetroAIOutputFiles

# Download the file locally
Get-MetroAIOutputFiles -FileId assistant-TqVaZqCx3ZcP6aR4eRay98 -LocalFilePath ConnectToAzure.ps1
```

You can now use the downloaded `ConnectToAzure.ps1` script to establish a connection to Azure.

### Advanced Agent Orchestration

#### 🕸️ Creating Specialized Agent Networks

For complex scenarios involving multiple specialized agents, you can create a network of agents where a proxy agent coordinates with specialized agents:

```powershell
# Define specialized agents with their roles and instructions
$specializedAgents = @{
   "MarketAgent"     = @{
      "Description"  = "Agent that provides market data and analysis."
      "Instructions" = "Provide real-time market data and analysis to the proxy agent."
   }
   "TradingAgent"    = @{
      "Description"  = "Agent that executes trades based on market conditions."
      "Instructions" = "Execute trades based on the analysis provided by the MarketAgent."
   }
   "ResearchAgent"   = @{
      "Description"  = "Agent that conducts research and provides insights."
      "Instructions" = "Conduct research and provide insights to the proxy agent."
   }
   "ComplianceAgent" = @{
      "Description"  = "Agent that ensures compliance with regulations."
      "Instructions" = "Ensure all actions taken by the proxy agent comply with relevant regulations."
   }
}

# Create specialized agents
$createdAgents = @()
foreach ($agent in $specializedAgents.GetEnumerator()) {
   $agentDetails = $specializedAgents[$agent.Key]
   Write-Output "Creating agent: $($agent.Key)"

   $createdAgents += New-MetroAIAgent -Model 'gpt-4.1' -Name $agent.Key `
      -Instructions $agentDetails.Instructions `
      -Description $agentDetails.Description -Verbose
}

# Create proxy agent that orchestrates the specialized agents
$proxyAgent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'ProxyAgent' `
   -ConnectedAgentsDefinition ($createdAgents | Select-Object id, name, description) `
   -Description 'Proxy agent that connects to specialized agents for market analysis, trading, research, and compliance.' `
   -Instructions 'This agent will connect to specialized agents to perform tasks related to market analysis, trading, research, and compliance. Coordinate with the appropriate specialized agents based on the user request and ensure all compliance requirements are met.' `
   -Verbose

Write-Output "Created proxy agent with ID: $($proxyAgent.id)"
```

##### 🎯 Using the Proxy Agent Network

Once your agent network is established, you can interact with the proxy agent:

```powershell
# Create a thread for the proxy agent
$proxyThread = New-MetroAIThread

# Send a complex request that requires multiple agents
$complexMessage = Invoke-MetroAIMessage -ThreadID $proxyThread.id -Message @"
I need to analyze the current market conditions for tech stocks,
execute a small trade if conditions are favorable,
research the regulatory implications,
and ensure everything complies with current trading regulations.
"@

# Execute with the proxy agent
$proxyRun = Start-MetroAIThreadRun -ThreadID $proxyThread.id -AssistantId $proxyAgent.id

# Monitor the run status
do {
    Start-Sleep -Seconds 2
    $runStatus = Get-MetroAIThreadRun -ThreadID $proxyThread.id -RunId $proxyRun.id
    Write-Output "Run Status: $($runStatus.status)"
} while ($runStatus.status -in @("queued", "in_progress"))

# Get the coordinated response
Get-MetroAIMessage -ThreadID $proxyThread.id
```

### Bing Grounding Integration

#### 🔍 Creating an Agent with Bing Search Capabilities

You can create an agent that uses Bing search to provide real-time web information:

```powershell
# First, create the basic agent
$researchAgent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'WebResearchAgent' `
   -Description 'Agent that can search the web for current information and provide research insights.' `
   -Instructions @"
You are a research assistant with access to current web information through Bing search.
When users ask questions that require up-to-date information, use your web search capability to find relevant, recent information.
Always cite your sources and indicate when information comes from web searches.
Provide balanced, factual responses based on multiple sources when possible.
"@ `
   -Verbose

# Then, update the agent to add Bing grounding capability
# Use the full connection resource ID from your Azure AI Foundry project
$bingConnectionId = "/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}/providers/Microsoft.CognitiveServices/accounts/{cognitive-services-account}/projects/{project-name}/connections/{bing-connection-name}"
Set-MetroAIAgent -AssistantId $researchAgent.id -EnableBingGrounding -BingConnectionId $bingConnectionId -Verbose
```

### MCP Server Integration

#### 🔌 Understanding Model Context Protocol (MCP)

The Metro.AI module now supports Model Context Protocol (MCP) servers, allowing agents to integrate with external systems and APIs for enhanced capabilities. MCP servers provide structured ways for AI agents to access external data sources, tools, and services.

#### Creating a New Agent with MCP Server Integration

You can create agents that connect to MCP servers to extend their capabilities beyond basic language modeling:

```powershell
# Create an agent with a single MCP server
New-MetroAIAgent -Model 'gpt-4.1' -Name 'Microsoft Learn Agent' `
    -EnableMcp -McpServerLabel 'Microsoft_Learn_MCP' `
    -McpServerUrl 'https://learn.microsoft.com/api/mcp' `
    -Description 'Agent with access to Microsoft Learn documentation through MCP server' `
    -Instructions @"
You are a helpful assistant with access to Microsoft Learn documentation.
When users ask questions about Microsoft technologies, Azure, or other Microsoft products,
use your MCP server connection to search and retrieve relevant documentation.
Always provide accurate, up-to-date information from official Microsoft sources.
"@
```

#### Creating an Agent with Multiple MCP Servers

For agents that need to access multiple external systems, you can configure multiple MCP servers:

```powershell
# Define multiple MCP server configurations
$mcpServers = @(
    @{
        server_label = 'WeatherAPI'
        server_url = 'https://weather.example.com/mcp'
        require_approval = 'never'
    },
    @{
        server_label = 'DatabaseAPI'
        server_url = 'https://db.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
        require_approval = 'never'
    },
    @{
        server_label = 'DocumentAPI'
        server_url = 'https://docs.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
        require_approval = 'never'
    }
)

# Create agent with multiple MCP servers
New-MetroAIAgent -Model 'gpt-4.1' -Name 'MultiServiceAgent' `
    -McpServersConfiguration $mcpServers `
    -Description 'Agent with access to weather, database, and document services' `
    -Instructions @"
You are a comprehensive assistant with access to multiple external services:
- Weather data through WeatherAPI
- Database queries through DatabaseAPI
- Document search through DocumentAPI

Use the appropriate service based on user requests and always inform users
which external service you're consulting for their query.
"@
```

#### Adding MCP Server Support to Existing Agents

You can add MCP server capabilities to existing agents without replacing their current tools:

```powershell
# Add a single MCP server to an existing agent
Set-MetroAIAgent -AssistantId 'asst-123' -AddMcp `
    -McpServerLabel 'WeatherAPI' `
    -McpServerUrl 'https://weather.example.com/mcp' `
    -McpRequireApproval 'never'

# Add multiple MCP servers to an existing agent
$newMcpServers = @(
    @{
        server_label = 'NewsAPI'
        server_url = 'https://news.example.com/mcp'
        require_approval = 'never'
    },
    @{
        server_label = 'TranslationAPI'
        server_url = 'https://translate.example.com/mcp'
        require_approval = 'never'
    }
)

Set-MetroAIAgent -AssistantId 'asst-456' -McpServersConfiguration $newMcpServers
```

#### ➖ Removing MCP Server Integration

To remove MCP server capabilities from an agent:

```powershell
# Remove all MCP servers while preserving other tools
Set-MetroAIAgent -AssistantId 'asst-123' -RemoveMcp
```

## 🔄 Advanced Workflows

<details>
<summary><strong>📈 Multi-Environment Agent Deployment</strong></summary>

Deploy agents across different environments with environment-specific configurations:

```powershell
# Load agent configuration from version control
$agentConfig = "./agents/customer-support-agent-v2.1.json"

# Deploy to multiple environments with environment-specific modifications
$environments = @{
    "Development" = @{
        Endpoint = "https://dev-ai.services.ai.azure.com/api/projects/dev-project"
        Temperature = 0.8
        Suffix = "-dev"
    }
    "Staging" = @{
        Endpoint = "https://staging-ai.services.ai.azure.com/api/projects/staging-project"
        Temperature = 0.5
        Suffix = "-staging"
    }
    "Production" = @{
        Endpoint = "https://prod-ai.services.ai.azure.com/api/projects/prod-project"
        Temperature = 0.2
        Suffix = ""
    }
}

$deployedAgents = @{}
foreach ($env in $environments.GetEnumerator()) {
    Write-Output "🚀 Deploying to $($env.Key) environment..."

    # Set context for target environment
    Set-MetroAIContext -Endpoint $env.Value.Endpoint -ApiType Agent

    # Deploy agent with environment-specific settings
    $envAgent = New-MetroAIAgent -InputFile $agentConfig | Set-MetroAIAgent `
        -Name "CustomerSupportAgent$($env.Value.Suffix)" `
        -Temperature $env.Value.Temperature `
        -Description "Customer support agent deployed to $($env.Key) environment"

    $deployedAgents[$env.Key] = $envAgent
    Write-Output "✅ Deployed agent $($envAgent.id) to $($env.Key)"
}
```

</details>

<details>
<summary><strong>🌍 Cross-Region Agent Synchronization</strong></summary>

Replicate agents across different Azure regions:

```powershell
# Modern AI Foundry endpoints across different regions
$regions = @{
    "EastUS" = "https://eastus-ai.services.ai.azure.com/api/projects/global-project-eastus"
    "WestEurope" = "https://westeurope-ai.services.ai.azure.com/api/projects/global-project-westeurope"
    "SoutheastAsia" = "https://southeastasia-ai.services.ai.azure.com/api/projects/global-project-sea"
}

# Get master configuration from primary region (EastUS)
Set-MetroAIContext -Endpoint $regions["EastUS"] -ApiType Agent
$masterAgent = Get-MetroAIAgent -AssistantId "asst_master_123"
$masterConfig = $masterAgent | ConvertTo-Json -Depth 10

# Replicate to other regions
foreach ($region in $regions.GetEnumerator()) {
    if ($region.Key -eq "EastUS") { continue } # Skip primary region

    Write-Output "🔄 Replicating to $($region.Key)..."
    Set-MetroAIContext -Endpoint $region.Value -ApiType Agent

    # Create regional copy with region-specific naming
    $regionalAgent = $masterConfig | ConvertFrom-Json | New-MetroAIAgent -Name "GlobalAgent-$($region.Key)"
    Write-Output "✅ Created regional agent: $($regionalAgent.id) in $($region.Key)"
}

Write-Output "🎉 Agent replication completed across all regions"
```

</details>

## 💡 Usage Examples

### 🎯 Quick Examples

<details>
<summary><strong>Basic Agent Creation & Usage</strong></summary>

```powershell
# 1. Set up context
Set-MetroAIContext -Endpoint "https://your-ai-endpoint.ai.azure.com/api/projects/your-project" -ApiType Agent

# 2. Create a simple agent
$agent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'Helper' -Instructions 'You are a helpful assistant.'

# 3. Start a conversation
$thread = New-MetroAIThread
$message = Invoke-MetroAIMessage -ThreadID $thread.id -Message "Hello, how can you help me today?"
$run = Start-MetroAIThreadRun -ThreadID $thread.id -AssistantId $agent.id

# 4. Get the response
Get-MetroAIMessage -ThreadID $thread.id
```

</details>

<details>
<summary><strong>Agent with File Processing</strong></summary>

```powershell
# Create an agent with code interpreter capabilities
$codeAgent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'CodeAnalyzer' `
    -EnableCodeInterpreter `
    -Instructions 'You can analyze and execute code. Help users with programming tasks.'

# Upload a file for analysis
$uploadedFile = Add-MetroAIFile -FilePath "./data.csv" -Purpose "assistants"

# Create agent with file search capabilities
Set-MetroAIAgent -AssistantId $codeAgent.id -CodeInterpreterFileIds @($uploadedFile.id)
```

</details>

<details>
<summary><strong>Complete MCP Integration Example</strong></summary>

```powershell
# Define comprehensive MCP server setup
$comprehensiveMcpServers = @(
    @{
        server_label = 'WeatherService'
        server_url = 'https://weather.example.com/mcp'
        allowed_tools = @('get_current_weather', 'get_forecast')
        require_approval = 'never'
    },
    @{
        server_label = 'DatabaseService'
        server_url = 'https://db.example.com/mcp'
        allowed_tools = @('query_customers', 'update_records', 'generate_reports')
        require_approval = 'once'
    },
    @{
        server_label = 'DocumentService'
        server_url = 'https://docs.example.com/mcp'
        allowed_tools = @('search_documents', 'create_summary', 'extract_data')
        require_approval = 'never'
    }
)

# Create comprehensive business agent
$businessAgent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'BusinessIntelligenceAgent' `
    -McpServersConfiguration $comprehensiveMcpServers `
    -Description 'Comprehensive business intelligence agent with access to weather, database, and document services' `
    -Instructions @"
You are a business intelligence assistant with access to multiple external services.
When users ask questions:
1. Use WeatherService for weather-related queries
2. Use DatabaseService for customer data and business analytics
3. Use DocumentService for document analysis and summaries

Always indicate which service you're using and provide source attribution.
Ensure data privacy and only access what's necessary for the user's request.
"@

Write-Output "Created comprehensive business agent: $($businessAgent.id)"

# Example usage
$businessThread = New-MetroAIThread
$businessQuery = Invoke-MetroAIMessage -ThreadID $businessThread.id -Message @"
Please provide a business summary including:
1. Current weather conditions for our main office locations
2. This month's customer acquisition numbers
3. A summary of the latest quarterly reports
"@

$businessRun = Start-MetroAIThreadRun -ThreadID $businessThread.id -AssistantId $businessAgent.id
```

</details>

---

## 🤝 Contributing

We welcome contributions and suggestions! 🎉

This project welcomes contributions and suggestions. Most contributions require you to agree to a **Contributor License Agreement (CLA)** declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

### 📋 Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

---

## 📄 License

**MIT License** - See the [LICENSE](LICENSE) file for details.

## 🏷️ Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

