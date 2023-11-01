#!/bin/bash

##################################################### CMI Cloud Azure Grafana Agent Entry Point #####################################################
# Das folgende Script dient als container entry point und kümmert sich um die einrichtung des Grafana Agent anhand der übergebenen Env Variablen

grafanaAgentConfigPath="/etc/agent/config.river"

function handle_env_variable() {
    env_variable_name=$1
    default_value=$2
    env_variable_value=${!env_variable_name}
    if [ -z "$env_variable_value" ]; then
        if [ -z "$default_value" ]; then
            echo "Environment variable $env_variable_name is required but not set. Please specify a value. Exiting..."
            exit 1
        else
            echo "Environment variable $env_variable_name is not set. Using default value '$default_value'"
            export "$env_variable_name"="$default_value"
        fi
    fi
}

# Check required environment variables and set default values if not set
handle_env_variable "GRAFANA_TOKEN"
handle_env_variable "SITE_NAME"
handle_env_variable "AGENT_NAME"
handle_env_variable "STACK_NAME" "cminformatik"
handle_env_variable "BRANCH_NAME" "master"
handle_env_variable "LOG_LEVEL" "info"
handle_env_variable "ENABLE_OPENTELEMETRY_RECEIVER" true
handle_env_variable "ENABLE_AZURE_AUTODISCOVERY" true
handle_env_variable "ENABLE_PUSH_GATEWAY" false
handle_env_variable "ENABLE_FORWARDERS" false
handle_env_variable "ENABLE_POSTGRES_MONITORING" false

if [ -f "$grafanaAgentConfigPath" ]; then
    # Remove default config file if it exists inside the container
    rm $grafanaAgentConfigPath
fi
touch $grafanaAgentConfigPath

echo "Setting Grafana Agent base configuration with the following values:"
echo "GRAFANA_TOKEN: ${GRAFANA_TOKEN:0:4}..."
echo "SITE_NAME: $SITE_NAME"
echo "AGENT_NAME: $AGENT_NAME"
echo "STACK_NAME: $STACK_NAME"
echo "BRANCH_NAME: $BRANCH_NAME"
cat << EOF >> $grafanaAgentConfigPath
logging {
	level = "$LOG_LEVEL"
}

module.git "base_module" {
	repository = "https://github.com/CMInformatik/cmi-grafana-monitoring.git"
	path       = "modules/grafana_agent_uplink/module.river"
	revision   = "$BRANCH_NAME"

	arguments {
		token            = "$GRAFANA_TOKEN"
		site             = "$SITE_NAME"
		stack_name       = "$STACK_NAME"
		submodule_branch = "$BRANCH_NAME"
	}
}

prometheus.scrape "grafana_agent" {
	targets    = [{"__address__" = "localhost:12345", "job" = "integrations/agent", "instance" = "$AGENT_NAME"}]
	forward_to = [
		module.git.base_module.exports.metrics_receiver,
	]
}
EOF

echo "Grafana Agent base configuration set."


# check and setup azure auto discovery for vms
if  [  "$ENABLE_AZURE_AUTODISCOVERY" == true ]; then
    echo "Azure auto-discovery enabled, checking requirements..."
    
    handle_env_variable "AZURE_CLIENT_ID"
    handle_env_variable "AZURE_SUBSCRIPTION_ID"
    handle_env_variable "AZURE_ENV_NAME"
    
    echo "Saving Azure Auto Discovery configuration with the following values:"
    echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID"
    echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"
    echo "AZURE_ENV_NAME: $AZURE_ENV_NAME"
cat << EOF >> $grafanaAgentConfigPath
module.file "azure_auto_discovery" {
	filename  = "/etc/agent/submodules/azure_discovery.river"
	arguments {
		azure_subscription_id = "$AZURE_CLIENT_ID"
		azure_client_id = "$AZURE_SUBSCRIPTION_ID"
        azure_env_name = "$AZURE_ENV_NAME"
		metrics_receiver = module.git.base_module.exports.metrics_receiver
	}
}
EOF
    echo "Azure Auto Discovery configuration set."
else
    echo "Azure Auto discovery configuration not set, skipping..."
fi


# add open telemetry receiver if not disabled
if [  "$ENABLE_OPENTELEMETRY_RECEIVER" == true ]; then
    echo "Configuring Open Telemetry Receiver..."
cat << EOF >> $grafanaAgentConfigPath
module.file "otelcol" {
	filename  = "/etc/agent/submodules/otelcol.river"
	arguments {
		base_module_exports = module.git.base_module.exports
		branch = "$BRANCH_NAME"
	}
}
EOF
    echo "Open Telemetry Receiver configured."
else
    echo "Open Telemetry Receiver configuration disabled."
fi

# ToDo: Implement authentication for push gateway
# add configuration for the push gateway and run the push gateway binary in the background if enabled
if [ "$ENABLE_PUSH_GATEWAY" == true ]; then
    echo "Configuring Push Gateway..."
cat << EOF >> $grafanaAgentConfigPath
prometheus.scrape "push_gateway" {
	targets    = [{"__address__" = "localhost:9091", "__metrics_path__" = "/metrics", "job" = "integrations/generic-push", "instance" = "$AGENT_NAME"}]
    honor_labels = true
	forward_to = [
		module.git.base_module.exports.metrics_receiver,
	]
}
EOF
    echo "Push Gateway configuration set, starting Push Gateway..."
    /bin/pushgateway&
else
    echo "Push Gateway configuration disabled."
fi

if [ "$ENABLE_FORWARDERS" == true ]; then
    echo "Configuring Loki and Prometheus Forwarder..."
cat << EOF >> $grafanaAgentConfigPath
loki.source.api "main" {
    http {
        listen_address = "0.0.0.0"
        listen_port = 9999
    }
    forward_to = [
        module.git.base_module.exports.logs_receiver,
    ]
}

prometheus.receive_http "main" {
  http {
    listen_address = "0.0.0.0"
    listen_port = 9998
  }
  forward_to = [
	module.git.base_module.exports.metrics_receiver,
  ]
}
EOF
    echo "Loki and Prometheus Forwarder configuration set."
else
    echo "Loki and Prometheus Forwarder disabled."
fi

# Check if the environment variable exists and is not empty
if [ -n "$ENABLE_POSTGRES_MONITORING" ]; then
echo "Postgres Monitoring enabled, checking requirements..."
handle_env_variable "POSTGRES_DATA_SOURCES"

  # Split the POSTGRES_DATA_SOURCES by newline and format it as an array
  IFS=',' read -ra DATA_SOURCE_NAMES_ARRAY <<< "$POSTGRES_DATA_SOURCES"
 
  # Create a string with the format [value1, value2, ...]
  for value in "${DATA_SOURCE_NAMES_ARRAY[@]}"; do
    # parser the following string postgresql://username:password@localhost:5432/database_name to get the server name
    # and the database name
    # remove the postgresql:// from the string
    value_without_postgres=${value#"postgresql://"}
    # split the string by @ to get the server name and the database name
    IFS='@' read -ra intitial_split_array <<< "$value_without_postgres"
    IFS=':' read -ra username_and_password_array <<< "${intitial_split_array[0]}"
    username=${username_and_password_array[0]}
    password=${username_and_password_array[1]}
    IFS='/' read -ra server_port_and_database_array <<< "${intitial_split_array[1]}"
    database_name=${server_port_and_database_array[1]}
    server_and_port=${server_port_and_database_array[0]}
    IFS=':' read -ra server_and_port_array <<< "$server_and_port"
    server_name=${server_and_port_array[0]}
    server_port=${server_and_port_array[1]}
    
    echo "Creating Postgres Scrape Configuration for $server_name with Username $username on Port $server_port and Database $database_name"
    DATA_SOURCE_NAME="[\"$value\"]"
      cat << EOF >> $grafanaAgentConfigPath
prometheus.exporter.postgres "postgres_$server_name" {
  data_source_names = $DATA_SOURCE_NAME
  autodiscovery {
    enabled            = true
    database_allowlist = ["frontend_app", "backend_app"]
  }
}

prometheus.scrape "prometheus_scraper_postgres_$server_name" {
  targets    = prometheus.exporter.postgres.postgres_$server_name.targets
  forward_to = [
    module.git.base_module.exports.metrics_receiver,
    ]
}
EOF
  done

 
  echo "Postgres Configuration added to $grafanaAgentConfigPath"
else
  echo "Environment variable POSTGRES_DATA_SOURCES is not set or empty."
fi



# Set Environment Variable AGENT_MODE to flow since we want to Run the Agent in Flow Mode
export AGENT_MODE="flow"

echo "Grafana Agent configuration set. Running Grafana Agent..."
/bin/grafana-agent run "--server.http.listen-addr=0.0.0.0:12345" "$grafanaAgentConfigPath"