module "airflow" {
  source = "github.com/astrafy/terraform-astrafy-gcp-airflow-module//?ref=v0.0.1"

  project_id = var.project_id
  region     = "europe-west1"

  sql_private_network   = module.network.network_id
  dags_repository       = "test-airflow-dags"
  k8s_airflow_namespace = "airflow"

  deploy_airflow = true

  airflow_values_filepath = "${path.module}/values.yaml"

  depends_on = [google_service_networking_connection.vpc_connection, kubernetes_namespace.namespaces]
}
