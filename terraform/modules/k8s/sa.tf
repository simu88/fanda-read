# variable "cluster_name" {}
# variable "oidc_provider_arn" {}
# variable "namespace" {
#   default = "default"
# }
# variable "web_service_account_name" {
#   default = "web-server-sa"
# }

# resource "aws_iam_role" "web_irsa_role" {
#   name = "web-server-irsa-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Federated = var.oidc_provider_arn
#         },
#         Action = "sts:AssumeRoleWithWebIdentity",
#         Condition = {
#           StringEquals = {
#             "${replace(var.oidc_provider_arn, "arn:aws:iam::", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.web_service_account_name}"
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "attach_web_policy" {
#   role       = aws_iam_role.web_irsa_role.name
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
# }

# resource "kubernetes_service_account" "web_sa" {
#   metadata {
#     name      = var.web_service_account_name
#     namespace = var.namespace
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.web_irsa_role.arn
#     }
#   }
# }
