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
  - [Conversation & Response Handling](#conversation--response-handling-foundry-agents-preview)
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

Define your agent's instructions and create a new Metro.AI agent using GPT-4o:

```powershell
$instructions = @"
You are a helpful assistant. Keep responses concise and cite sources when relevant.
"@

# Create a new agent with specific model and instructions
New-MetroAIAgent -Name "myAgent" -Model "gpt-4o" -Instructions $instructions
```

#### 📋 Working with Existing Agents

Metro.AI provides powerful pipeline support for managing existing agents, allowing you to easily copy, modify, and export agent configurations.

##### 🔄 Copying an Existing Agent

You can create a new agent based on an existing one using PowerShell pipeline operations:

```powershell
# Get an existing agent and create a copy with a new name
$originalAgent = Get-MetroAIAgent -AssistantId "agent_abc123"
$copiedAgent = $originalAgent | New-MetroAIAgent -Name "CopiedAgent"

# Copy with modifications - override specific properties while copying
# This creates a NEW agent based on the original, but with a different model and description
$enhancedAgent = $originalAgent | New-MetroAIAgent -Name "EnhancedAgent" `
    -Model "gpt-4o" `
    -Description "Enhanced version of the original agent"

Write-Output "Created new agent: $($enhancedAgent.name) with ID: $($enhancedAgent.id)"
```

##### ✏️ Updating an Existing Agent

You can modify an agent object and update it seamlessly:

```powershell
# Get an agent, modify its properties locally, and then push the update
$agent = Get-MetroAIAgent -AssistantId "agent_abc123"
$agent.Description = "Updated description for better clarity"
$agent.definition.instructions = @"
You are an expert PowerShell assistant. Help users with PowerShell scripting,
automation, and Azure management tasks. Always provide working examples
and explain best practices.
"@

# Update the agent with the modified properties
$updatedAgent = $agent | Set-MetroAIAgent
Write-Output "Updated agent: $($updatedAgent.name)"

# You can also override specific properties directly via parameters during the update
Get-MetroAIAgent -AssistantId "agent_abc123" | Set-MetroAIAgent -Name "NewName" -Temperature 0.5
```

##### 📥📤 Exporting and Importing Agent Configurations

Export an agent configuration to JSON for backup, version control, or sharing:

```powershell
# Export an existing agent to JSON file
$agent = Get-MetroAIAgent -AssistantId "agent_abc123"
$agent | ConvertTo-Json -Depth 100 | Out-File -FilePath "./my-agent-backup.json" -Encoding UTF8

Write-Output "Agent configuration exported to my-agent-backup.json"

# Create a new agent from the exported JSON file
$newAgentFromFile = New-MetroAIAgent -InputFile "./my-agent-backup.json"
Write-Output "Created agent from file: $($newAgentFromFile.name) with ID: $($newAgentFromFile.id)"

# Update an existing agent from a JSON file
Set-MetroAIAgent -AssistantId "agent_xyz789" -InputFile "./my-agent-backup.json"
```

### Conversation & Response Handling (Foundry Agents Preview)

Start a conversation and send a turn using the preview Responses API:

```powershell
# Create a simple helper agent
$agent = New-MetroAIAgent -Model 'gpt-4o' -Name 'Helper' -Instructions 'You are a helpful assistant.'

# Create a new conversation
$conv  = New-MetroAIConversation

# Send a message to the agent within the conversation
$turn  = Invoke-MetroAIConversation -AgentId $agent.id -ConversationId $conv.id -UserInput "Hello, how can you help me today?" -Verbose

# Display the agent's response
$turn.AssistantText
```

List, inspect, or delete conversations/responses:

```powershell
Get-MetroAIConversation
Get-MetroAIConversation -ConversationId $conv.id
Get-MetroAIResponse
Remove-MetroAIResponse -ResponseId $turn.ResponseId -Confirm:$false
Remove-MetroAIConversation -ConversationId $conv.id -Confirm:$false
```

#### 💬 Multi-Turn Conversation Example

Here is a complete example of a multi-turn conversation where the context is maintained across multiple messages:

```powershell
# 1. Setup: Create an AI Expert agent and a conversation
$agent = New-MetroAIAgent -Model 'gpt-4o' -Name 'AIExpert' -Instructions 'You are an expert in Artificial Intelligence concepts. Explain complex topics simply.'
$conversation = New-MetroAIConversation
Write-Host "Created conversation: $($conversation.id)"

# 2. First Turn: Ask about Model Knowledge vs RAG
$turn1 = Invoke-MetroAIConversation -AgentId $agent.id -ConversationId $conversation.id -UserInput "What is the difference between a model's internal knowledge and RAG?"
Write-Host "Agent: $($turn1.AssistantText)"
# Output: Agent: Internal knowledge is what the model learned during training (static). RAG (Retrieval-Augmented Generation) allows the model to access external, up-to-date data at runtime.

# 3. Second Turn: Follow up about Fine-tuning (context aware)
$turn2 = Invoke-MetroAIConversation -AgentId $agent.id -ConversationId $conversation.id -UserInput "How does fine-tuning fit into this picture?"
Write-Host "Agent: $($turn2.AssistantText)"
# Output: Agent: Fine-tuning updates the model's weights to learn a specific style or domain language, whereas RAG provides facts. Fine-tuning changes *how* it talks; RAG changes *what* it knows.

# 4. Third Turn: Ask about Prompt Engineering
$turn3 = Invoke-MetroAIConversation -AgentId $agent.id -ConversationId $conversation.id -UserInput "And where does prompt engineering come in?"
Write-Host "Agent: $($turn3.AssistantText)"
# Output: Agent: Prompt engineering is the art of crafting inputs to guide the model's behavior without changing its weights or external data. It's the most lightweight way to steer the model.

# 5. Cleanup
Remove-MetroAIConversation -ConversationId $conversation.id -Confirm:$false
```

### Advanced Agent Orchestration (Coming Soon)

#### 🕸️ Creating Specialized Agent Networks

> **Note:** Advanced agent orchestration features are currently in development and will be available in a future release.

For complex scenarios involving multiple specialized agents, you can create a network of agents where a proxy agent coordinates with specialized agents.

### Bing Grounding Integration

#### 🔍 Creating an Agent with Bing Search Capabilities

You can create an agent that uses Bing search to provide real-time web information. This is a two-step process: create the agent, then enable the Bing Grounding tool.

```powershell
# 1. Create the basic agent with appropriate instructions
$researchAgent = New-MetroAIAgent -Model 'gpt-4o' -Name 'WebResearchAgent' `
   -Description 'Agent that can search the web for current information and provide research insights.' `
   -Instructions @"
You are a research assistant with access to current web information through Bing search.
When users ask questions that require up-to-date information, use your web search capability to find relevant, recent information.
Always cite your sources and indicate when information comes from web searches.
Provide balanced, factual responses based on multiple sources when possible.
"@

# 2. Enable Bing grounding capability on the existing agent
# You need the full connection resource ID from your Azure AI Foundry project
$bingConnectionId = "/subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.CognitiveServices/accounts/{account}/projects/{project}/connections/{connection-name}"

Set-MetroAIAgent -AssistantId $researchAgent.id -EnableBingGrounding -BingConnectionId $bingConnectionId -Verbose
```

### MCP Server Integration

#### 🔌 Understanding Model Context Protocol (MCP)

The Metro.AI module now supports Model Context Protocol (MCP) servers, allowing agents to integrate with external systems and APIs for enhanced capabilities. MCP servers provide structured ways for AI agents to access external data sources, tools, and services.

#### Creating a New Agent with MCP Server Integration

You can create agents that connect to MCP servers to extend their capabilities beyond basic language modeling:

```powershell
# Create an agent with a single MCP server
New-MetroAIAgent -Model 'gpt-4o' -Name 'MicrosoftLearnAgent' `
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
    },
    @{
        server_label = 'DatabaseAPI'
        server_url = 'https://db.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
    },
    @{
        server_label = 'DocumentAPI'
        server_url = 'https://docs.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
    }
)

# Create agent with multiple MCP servers
New-MetroAIAgent -Model 'gpt-4o' -Name 'MultiServiceAgent' `
    -McpServersConfiguration $mcpServers `
    -Description 'Agent with access to weather, database, and document services' `
    -Instructions "You are a multi-service agent. Use the available tools to answer user queries."
```

#### Creating an Agent with Multiple MCP Servers

For agents that need to access multiple external systems, you can configure multiple MCP servers:

```powershell
# Define multiple MCP server configurations
$mcpServers = @(
    @{
        server_label = 'WeatherAPI'
        server_url = 'https://weather.example.com/mcp'
    },
    @{
        server_label = 'DatabaseAPI'
        server_url = 'https://db.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
    },
    @{
        server_label = 'DocumentAPI'
        server_url = 'https://docs.example.com/mcp'
        allowed_tools = @('tool1','tool2') # Limit tool usage
    }
)

# Create agent with multiple MCP servers
New-MetroAIAgent -Model 'gpt-4o' -Name 'MultiServiceAgent' `
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

#### 🔑 Using MCP Servers with Authentication Headers

Some MCP servers require authentication headers (like API keys) to access their resources. You can provide these headers securely when configuring the MCP server.

**Single MCP Server with Headers:**

```powershell
# Define headers (e.g., API Key)
$headers = @{
    "Authorization" = "Bearer your-api-key-here"
    "X-Custom-Header" = "custom-value"
}

# Create agent with MCP server and headers
New-MetroAIAgent -Model 'gpt-4o' -Name 'SecureAgent' `
    -EnableMcp -McpServerLabel 'SecureAPI' `
    -McpServerUrl 'https://api.example.com/mcp' `
    -McpServerHeaders $headers
```

**Multiple MCP Servers with Headers:**

```powershell
$mcpServers = @(
    @{
        server_label = 'ServiceA'
        server_url = 'https://service-a.com/mcp'
        headers = @{ "Authorization" = "Bearer key-a" }
    },
    @{
        server_label = 'ServiceB'
        server_url = 'https://service-b.com/mcp'
        headers = @{ "X-API-Key" = "key-b" }
    }
)

New-MetroAIAgent -Model 'gpt-4o' -Name 'MultiSecureAgent' -McpServersConfiguration $mcpServers
```

> **Note:** Approval behavior for MCP servers is now managed by Azure AI Foundry. The previous `require_approval` setting is ignored by the service and does not need to be specified.

#### ➕ Adding MCP Servers to Existing Agents

You can add MCP capabilities to existing agents without recreating them:

```powershell
# Add a single MCP server to an existing agent
Set-MetroAIAgent -AssistantId 'asst-123' -AddMcp `
    -McpServerLabel 'WeatherAPI' `
    -McpServerUrl 'https://weather.example.com/mcp'

# Add multiple MCP servers to an existing agent
$newMcpServers = @(
    @{
        server_label = 'NewsAPI'
        server_url = 'https://news.example.com/mcp'
    },
    @{
        server_label = 'TranslationAPI'
        server_url = 'https://translate.example.com/mcp'
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
$masterAgent = Get-MetroAIAgent -AssistantId "agent_master_123"
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
$agent = New-MetroAIAgent -Model 'gpt-4o' -Name 'Helper' -Instructions 'You are a helpful assistant.'

# 3. Start a conversation (preview Responses API)
$conv = New-MetroAIConversation
$turn = Invoke-MetroAIConversation -AgentName $agent.name -ConversationId $conv.id -Input "Hello, how can you help me today?" -Verbose
$turn.AssistantText
```

</details>

<details>
<summary><strong>Agent with File Processing (Coming Soon)</strong></summary>

```powershell
# Upload a file (purpose value depends on service support; "assistants" is commonly accepted)
Invoke-MetroAIUploadFile -FilePath "./data.csv" -Purpose "assistants"
```

_Note: The Foundry Agents preview currently has limited support for file tooling. This feature will be fully enabled in future updates._

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
    },
    @{
        server_label = 'DatabaseService'
        server_url = 'https://db.example.com/mcp'
        allowed_tools = @('query_customers', 'update_records', 'generate_reports')
    },
    @{
        server_label = 'DocumentService'
        server_url = 'https://docs.example.com/mcp'
        allowed_tools = @('search_documents', 'create_summary', 'extract_data')
    }
)

# Create comprehensive business agent
$businessAgent = New-MetroAIAgent -Model 'gpt-4o' -Name 'BusinessIntelligenceAgent' `
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

# Example usage (conversation/response)
$conv = New-MetroAIConversation
$businessRequest = @"
Please provide a business summary including:
1. Current weather conditions for our main office locations
2. This month's customer acquisition numbers
3. A summary of the latest quarterly reports
"@
$businessTurn = Invoke-MetroAIConversation -AgentName $businessAgent.name -ConversationId $conv.id -Input $businessRequest
$businessTurn.AssistantText
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
