resource "aws_iam_policy" "cloudwatch_exporter_policy" {
  name = "CloudWatchExporterPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "ec2:DescribeTags",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricStatistics"

        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cloudwatch_exporter_role" {
  name = "cloudwatch-exporter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:fanda-monitoring:cloudwatch-exporter"
        }
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "cloudwatch_exporter_attach" {
  role       = aws_iam_role.cloudwatch_exporter_role.name
  policy_arn = aws_iam_policy.cloudwatch_exporter_policy.arn
}


resource "kubernetes_service_account" "cloudwatch_exporter_sa" {

  metadata {
    name      = "cloudwatch-exporter"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cloudwatch_exporter_role.arn
    }
  }
}