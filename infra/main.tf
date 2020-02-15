variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_kubernetes_cluster" "demo" {
  name    = "demo"
  region  = "nyc1"
  version = "1.16.6-do.0"
  tags    = ["demo"]

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 2
  }
}

output "config" {
    value = digitalocean_kubernetes_cluster.demo.kube_config.0.raw_config
}
