data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../aws-eks-cluster-base/terraform.tfstate"
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_namespace" "kub-ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "camunda-dep" {
  metadata {
    name = "camunda-dep"
    namespace = kubernetes_namespace.kub-ns.metadata.0.name
    labels = {
      app = "camunda"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "camunda"
      }
    }
    template {
      metadata {
        labels = {
          app = "camunda"
        }
      }
      spec {
        container {
          image = "camunda/camunda-bpm-platform@sha256:9ca5363c41a0a4f3730b62c4e5bdf347fe6d52af70f2c6253aeb75efc6279266"
          name = "camunda"

          port {
            container_port = 8080
          }

          env {
            name = "DB_DRIVER"
            value = "org.postgresql.Driver"
          }

          env {
            name = "DB_USERNAME"
            value = "<<username for database created in data layer>>"
          }

          env {
            name = "DB_PASSWORD"
            value = "<<password for database created in data layer>>"
          }

          env {
            name = "DB_URL"
            value = "jdbc:postgresql://<<db to go here>>.ap-southeast-2.rds.amazonaws.com:5432/process_engine"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "camunda-svc" {
  metadata {
    name = "camunda-svc"
    namespace = kubernetes_namespace.kub-ns.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.camunda-dep.spec.0.template.0.metadata.0.labels.app
    }

    type = "NodePort"
    port {
      port = 8088
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress" "camunda" {
  metadata {
    name = "camunda-ingress"
    namespace = "healthlab"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      #"alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/scheme" = "internal"
      "alb.ingress.kubernetes.io/tags" = "Environment=dev"
      "alb.ingress.kubernetes.io/target-type" = "instance"
    }
  }

  spec {
    backend {
      service_name = "camunda-svc"
      service_port = 8088
    }

    rule {
      http {
        path {
          backend {
            service_name = "camunda-svc"
            service_port = 8088
          }

          path = "/"
        }
      }
    }
  }
}

# output "lb_ip" {
#   # value = kubernetes_service.fhir-svc.status.0.load_balancer.0.ingress.0.hostname
#   value = kubernetes_service.camunda-svc.status.0.load_balancer.0.ingress.0.hostname
# }
