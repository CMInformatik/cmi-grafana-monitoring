#!/bin/bash

##################################################### CMI Cloud Azure Grafana Agent Entry Point #####################################################
# Das folgende Script dient als container entrypoint und kümmert sich um die Einrichtung des Grafana Agent anhand der übergebenen Env Variablen

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
handle_env_variable "ADDITIONAL_LABELS_TO_DROP" "[]"
handle_env_variable "ENABLE_OPENTELEMETRY_RECEIVER" false
handle_env_variable "ENABLE_AZURE_AUTODISCOVERY" false
handle_env_variable "ENABLE_PUSH_GATEWAY" false
handle_env_variable "ENABLE_FORWARDERS" false
handle_env_variable "ENABLE_POSTGRES_MONITORING" false
# Optional variable: RESOURCE_ATTRIBUTE_ENVIRONMENT

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
echo "LOG_LEVEL: $LOG_LEVEL"
echo "RESOURCE_ATTRIBUTE_ENVIRONMENT: $RESOURCE_ATTRIBUTE_ENVIRONMENT"

additional_lables_to_drop_string="[]"
if [ "$ADDITIONAL_LABELS_TO_DROP" != "[]" ]; then
    echo "The following metrics labels will be dropped: $ADDITIONAL_LABELS_TO_DROP"
    # Split the ADDITIONAL_LABELS_TO_DROP by comma and format it as an array
    IFS=',' read -ra ADDITIONAL_LABELS_TO_DROP_ARRAY <<< "$ADDITIONAL_LABELS_TO_DROP"
    additional_lables_to_drop_string="["
    for value in "${ADDITIONAL_LABELS_TO_DROP_ARRAY[@]}"; do
        additional_lables_to_drop_string+="\"$value\","
    done
    additional_lables_to_drop_string=${additional_lables_to_drop_string::-1}
    additional_lables_to_drop_string+="]"
fi


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
        additinal_lables_to_drop = $additional_lables_to_drop_string
	}
}

// Adds a new lable to all metrics scraped from the collector agent to be able to separate them from normal agents
prometheus.relabel "add_collector_lable" {
  forward_to = [module.git.base_module.exports.metrics_receiver]
  rule {
    target_label  = "collector_agent"
    replacement   = "true"
  }
}

prometheus.scrape "grafana_agent" {
	targets    = [{"__address__" = "localhost:12345", "job" = "integrations/agent", "instance" = "$AGENT_NAME"}]
	forward_to = [prometheus.relabel.add_collector_lable.receiver]
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
		azure_subscription_id = "$AZURE_SUBSCRIPTION_ID"
		azure_client_id = "$AZURE_CLIENT_ID"
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
		base_module_exports           = module.git.base_module.exports
		branch                        = "$BRANCH_NAME"
		otelcol_attribute_environment = "$RESOURCE_ATTRIBUTE_ENVIRONMENT"
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
if [ "$ENABLE_POSTGRES_MONITORING" == true ]; then
echo "Postgres Monitoring enabled, checking requirements..."
handle_env_variable "POSTGRES_DATA_SOURCES"

  # Split the POSTGRES_DATA_SOURCES by newline and format it as an array
  IFS=',' read -ra DATA_SOURCE_NAMES_ARRAY <<< "$POSTGRES_DATA_SOURCES"
 
  for value in "${DATA_SOURCE_NAMES_ARRAY[@]}"; do
    # Split the value by = to get the instance name (left) and the connection string (right)
    IFS='=' read -ra instance_connection_string_array <<< "$value"
    instance_name=${instance_connection_string_array[0]}
    connection_string=${instance_connection_string_array[1]}

    # Remove the postgres:// from the connection string and split the string by @ to get the username and password (left) and the server, port and database (right)
    value_without_postgres=${connection_string#"postgresql://"}
    IFS='@' read -ra login_server_string_array <<< "$value_without_postgres"

    # Split the login string by : to get the username (left) and the password (right)
    IFS=':' read -ra username_and_password_array <<< "${login_server_string_array[0]}"
    username=${username_and_password_array[0]}
    password=${username_and_password_array[1]}

    # Split the server string by / to get the server and port (left) and the database (right)
    IFS='/' read -ra server_port_and_database_array <<< "${login_server_string_array[1]}"
    database_name=${server_port_and_database_array[1]}
    server_and_port=${server_port_and_database_array[0]}

    # Split the server and port string by : to get the server (left) and the port (right)
    IFS=':' read -ra server_and_port_array <<< "$server_and_port"
    server_name=${server_and_port_array[0]}
    server_port=${server_and_port_array[1]}
    
    echo "Creating Postgres Scrape Configuration for Instance $instance_name with Username $username on Server $server_name on Port $server_port and Database $database_name"

    DATA_SOURCE_NAME="[\"$connection_string\"]"
      cat << EOF >> $grafanaAgentConfigPath
prometheus.exporter.postgres "postgres_$instance_name" {
  data_source_names = $DATA_SOURCE_NAME
  autodiscovery {
    enabled            = true
    database_allowlist = ["frontend_app", "backend_app"]
  }
}

prometheus.scrape "prometheus_scraper_postgres_$instance_name" {
  targets    = prometheus.exporter.postgres.postgres_$instance_name.targets
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
