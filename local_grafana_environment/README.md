# Local Dev Grafana Setup

This repo provides a docker-compose setup for collecting traces, metrics and logs with open telemetry.

> **Warning**
> This setup is only intended as a local test setup. It is not production ready.

To start the setup, just run:
```
docker-compose up
```

The setup runs the Grafana Agent which exposes the following endpoints for receiving data:
- `http://localhost:4317` (OTLP GRPC)
- `http://localhost:4318` (OTLP HTTP)
- `http://localhost:12345` (Status UI)


The Grafana UI is available at http://localhost:3000, the credentials for the initial admin user are `admin` / `admin`.

To stop all services in this setup, run:
```
docker-compose stop
```

To remove all services and volumes from this setup, run:
```
docker-compose down -v
```

The services can also be started with the vscode task `run local grafana test environment`.

## Services

A quick overview of the services run by this setup, and how they interact with each other.

### Grafana Agent (Collector)

The collector is configured to receive trace, metrics and log data in the `OTLP` format either through `GRPC` (port 4317) or `HTTP` (port 4318).

It then distributes that data to individual services that are then used by Grafana to query data from:
- Traces are sent to Grafana Tempo
- Metrics are exposed to be scraped by Prometheus
- Logs are sent to Grafana Loki

### Grafana Tempo

Receives traces from the OpenTelemetry Collector and stores them.

Exposes a query API that is used by Grafana to search for traces.

### Prometheus

Scrapes metrics from an endpoint provided by the OpenTelemetry Collector and stores them.

Exposes a query API that is used by Grafana to search for metric.

### Loki

Receives logs from the OpenTelemetry Collector and stores them.

Exposes a query API that is used by Grafana to search for logs.

### Grafana

Provides the UI to display the traces, metrics and logs. The Grafana setup automatically provisions data sources for collecting the respective data from Tempo, Prometheus and Loki. It also includes a basic dashboard for showing some metrics, traces and logs.
