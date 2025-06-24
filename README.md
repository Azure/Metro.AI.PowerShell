# Metro.AI PowerShell module

Metro.AI is a [PowerShell module](https://www.powershellgallery.com/packages/Metro.AI) that simplifies working with Azure AI Agent and Assistant APIs. It provides a unified, intuitive command set to manage AI resources, upload files, start and monitor threads, and integrate custom functions, all from your PowerShell console.

### Getting Started

Metro-AI is designed for simplicity and speed. To quickly set it up, install the module directly from the PowerShell Gallery using:

```powershell
Install-Module Metro.AI -Force
```

## Connecting to Azure

Before using Metro-AI, ensure you're connected to your Azure account:

```powershell
Connect-AzAccount
```

## Example Usage

### Setting Up MetroAI Context

Retrieve the connection string or project uri from your Azure AI Foundry project, then configure Metro-AI:

#### GA Version of Foundry
```powershell
# Example project URI (from GA version of foundry)
Set-MetroAIContext -Endpoint https://aiservicesw3ba.services.ai.azure.com/api/projects/projectw3ba -ApiType Agent
Get-MetroAIContext
```

#### Preview version of Foundry
```powershell
# Example project connection string (from preview version of foundry)
$connectionString = "swedencentral.api.azureml.ms;80ffa654-da7f-4c46-8d9a-9ed75956766e;ai-foundry-workflows;admin-7818"

Set-MetroAIContext -ConnectionString $connectionString -ApiType Agent
Get-MetroAIContext
```

### Creating a New Agent

Define your agent's instructions and create a new Metro-AI agent using GPT-4.1:

```powershell
$instructions = @"
You are a helpful assistant. Your task is to assist the user with their queries and provide relevant information.
You should always be polite and respectful. If you do not know the answer to a question, you should say so.
You should not provide personal opinions or make assumptions about the user.
Always ask clarifying questions if the user's request is unclear.
"@

New-MetroAIAgent -ResourceName "myAgent" -Model "gpt-4.1" -Instructions $instructions
```

### Working with Existing Agents

Metro.AI provides powerful pipeline support for managing existing agents, allowing you to easily copy, modify, and export agent configurations.

#### Copying an Existing Agent

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

#### Updating an Existing Agent

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

#### Exporting and Importing Agent Configurations

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

#### Advanced Agent Management Workflows

Combine these operations for sophisticated agent management across different projects and environments:

```powershell
# Scenario 1: Copy agent from production to development project
# First, connect to production environment
Set-MetroAIContext -Endpoint "https://prod-ai.services.ai.azure.com/api/projects/prod-project" -ApiType Agent
$prodAgent = Get-MetroAIAgent -AssistantId "asst_production_123"

# Export production agent configuration
$prodAgent | ConvertTo-Json -Depth 10 | Out-File -FilePath "./prod-agent-backup.json" -Encoding UTF8

# Switch to development environment
Set-MetroAIContext -Endpoint "https://dev-ai.services.ai.azure.com/api/projects/dev-project" -ApiType Agent

# Create development version from production configuration
$devAgent = New-MetroAIAgent -InputFile "./prod-agent-backup.json" | Set-MetroAIAgent -Name "DevAgent" -Temperature 0.8

Write-Output "Created dev agent: $($devAgent.id) in development project"

# Scenario 2: Multi-environment deployment from version-controlled configuration
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
    Write-Output "Deploying to $($env.Key) environment..."

    # Set context for target environment
    Set-MetroAIContext -Endpoint $env.Value.Endpoint -ApiType Agent

    # Deploy agent with environment-specific settings
    $envAgent = New-MetroAIAgent -InputFile $agentConfig | Set-MetroAIAgent `
        -Name "CustomerSupportAgent$($env.Value.Suffix)" `
        -Temperature $env.Value.Temperature `
        -Description "Customer support agent deployed to $($env.Key) environment"

    $deployedAgents[$env.Key] = $envAgent
    Write-Output "Deployed agent $($envAgent.id) to $($env.Key)"
}

# Scenario 3: Cross-region agent synchronization
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

    Write-Output "Replicating to $($region.Key)..."
    Set-MetroAIContext -Endpoint $region.Value -ApiType Agent

    # Create regional copy with region-specific naming
    $regionalAgent = $masterConfig | ConvertFrom-Json | New-MetroAIAgent -Name "GlobalAgent-$($region.Key)"
    Write-Output "Created regional agent: $($regionalAgent.id) in $($region.Key)"
}

Write-Output "Agent replication completed across all regions"
```

### Creating and Managing Threads

Start a new conversation thread:

```powershell
$thread = New-MetroAIThread
```

Add a message to the thread:

```powershell
$message = Invoke-MetroAIMessage -ThreadID $thread.id -Message "Hello, can you generate a PowerShell script that I can download as a file to connect to Azure?"
```

Execute the thread with the previously created agent:

```powershell
$run = Start-MetroAIThreadRun -ThreadID $thread.id -AssistantId asst_y0NifdnDS0hrprT9azLw3VrK
```

After execution, the agent generates a downloadable script:

```powershell
# List available output files
Get-MetroAIOutputFiles

# Download the file locally
Get-MetroAIOutputFiles -FileId assistant-TqVaZqCx3ZcP6aR4eRay98 -LocalFilePath ConnectToAzure.ps1
```

You can now use the downloaded `ConnectToAzure.ps1` script to establish a connection to Azure.

### Creating Specialized Agents with Proxy Agent Orchestration

For complex scenarios involving multiple specialized agents, you can create a network of agents where a proxy agent coordinates with specialized agents:

```powershell
# Define specialized agents with their roles and instructions
$specializedAgents = @{
   # Market agent
   "MarketAgent"     = @{
      "Description"  = "Agent that provides market data and analysis."
      "Instructions" = "Provide real-time market data and analysis to the proxy agent."
   }
   # Trading agent
   "TradingAgent"    = @{
      "Description"  = "Agent that executes trades based on market conditions."
      "Instructions" = "Execute trades based on the analysis provided by the MarketAgent."
   }
   # Research agent
   "ResearchAgent"   = @{
      "Description"  = "Agent that conducts research and provides insights."
      "Instructions" = "Conduct research and provide insights to the proxy agent."
   }
   # Compliance agent
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
   Write-Output "Description: $($agentDetails.Description)"
   Write-Output "Instructions: $($agentDetails.Instructions)"

   $createdAgents += New-MetroAIAgent -Model 'gpt-4.1' -Name $agent.Key -Instructions $agentDetails.Instructions -Description $agentDetails.Description -Verbose
}

# Create proxy agent that orchestrates the specialized agents
$proxyAgent = New-MetroAIAgent -Model 'gpt-4.1' -Name 'ProxyAgent' `
   -ConnectedAgentsDefinition ($createdAgents | Select-Object id, name, description) `
   -Description 'Proxy agent that connects to specialized agents for market analysis, trading, research, and compliance.' `
   -Instructions 'This agent will connect to specialized agents to perform tasks related to market analysis, trading, research, and compliance. Coordinate with the appropriate specialized agents based on the user request and ensure all compliance requirements are met.' `
   -Verbose

Write-Output "Created proxy agent with ID: $($proxyAgent.id)"
```

#### Using the Proxy Agent Network

Once your agent network is established, you can interact with the proxy agent, which will coordinate with the specialized agents as needed:

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

This approach allows you to build sophisticated AI workflows where different agents handle their specialized domains while a central proxy agent orchestrates the overall process.

### Creating an Agent with Bing Grounding

You can create an agent that uses Bing search to provide real-time web information by first creating the agent and then updating it with Bing grounding capabilities:

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

Now you can use this agent to get current web information for research tasks.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
