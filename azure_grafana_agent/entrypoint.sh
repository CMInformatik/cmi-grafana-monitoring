#!/bin/bash

############################# CMI Cloud Azure Grafana Agent Entry Point #####################################
# Das folgende Script dient als container entry point und kümmert sich um die einrichtung des Grafana Agent anhand der übergebenen Env Variablen

grafanaAgentConfigPath="/etc/agent/config.river"

function replaceGrafanaAgentConfigValue() {
    local envVarName=$1
    local configKey=$2
    local requred=$3
    local sensitive=$4
    local defaultValue=$5
    local envVarValue=${!envVarName}
    
    if [ -z "$envVarValue" ]; then
        if [ "$requred" = 1 ]; then
            echo "Environment variable $envVarName is required, please specify a value. Exiting..."
            exit 1
        fi
        if [ -z "$defaultValue" ]; then
            echo "Environment variable $envVarName is not set. Removing config key $configKey from grafana config file..."
            sed -i "/${configKey}/d" $grafanaAgentConfigPath
            return
        fi
        echo "Environment variable $envVarName is not set. Using default value $defaultValue"
        sed -i "s/${configKey}/${defaultValue}/g" $grafanaAgentConfigPath
        return
    fi
    envVarValueLogValue=$envVarValue
    if [ "$sensitive" = 1 ]; then
        envVarValueLogValue="${envVarValue:0:4}..."
    fi
    configValue=${!envVarName}
    echo "Replacing config value for $configKey with $envVarValueLogValue"
    sed -i "s/${configKey}/${configValue}/g" $grafanaAgentConfigPath
}

# Entry Point
echo "Reading environment variables and setting Grafana Agent configuration..."

# Get all required environment variables and set the values in the grafana agent config
replaceGrafanaAgentConfigValue "GRAFANA_TOKEN" "<replace_grafana_token>" 1 1
replaceGrafanaAgentConfigValue "SITE_NAME" "<replace_site_name>" 1 0
replaceGrafanaAgentConfigValue "AGENT_NAME" "<replace_agent_name>" 1 0
replaceGrafanaAgentConfigValue "AZURE_CLIENT_ID" "<replace_azure_client_id>" 1 0
replaceGrafanaAgentConfigValue "AZURE_SUBSCRIPTION_ID" "<replace_azure_subscription_id>" 1 0



# Get all optional environment variables and set the values in the grafana agent config. If the value is not set, the config line will be removed
replaceGrafanaAgentConfigValue "STACK_NAME" "<replace_stack_name>" 0 0
replaceGrafanaAgentConfigValue "BRANCH_NAME" "<replace_branch_name>" 0 0 "master"
replaceGrafanaAgentConfigValue "LOG_LEVEL" "<replace_log_level>" 0 0 "info"


# Set Environment Variable AGENT_MODE to flow since we want to Run the Agent in Flow Mode
export AGENT_MODE="flow"

echo "Grafana Agent configuration set. Running Grafana Agent..."
/bin/grafana-agent run "--server.http.listen-addr=0.0.0.0:12345" "$grafanaAgentConfigPath"
