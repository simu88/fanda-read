# 1-1. AssumeRole Policy (OIDC/ServiceAccount 연결)
data "aws_iam_policy_document" "karpenter_assume_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      # [수정] data 소스 대신 명시적인 변수를 사용합니다.
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:fanda-karpenter:karpenter"]
    }
  }
}

# 1-2. 위 정책을 기반으로 실제 AWS에 Role생성
resource "aws_iam_role" "fanda_karpenter_controller" {
  name = "fanda-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume_policy.json
}


# 2-1. Karpenter Controller Policy (공식 권장 최소 권한)
data "aws_iam_policy_document" "karpenter_controller_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:TerminateInstances",
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeSecurityGroups",
      //"iam:PassRole",
      "ssm:GetParameter",
      "eks:DescribeCluster",
      "pricing:GetProducts",
      "ec2:DescribeSpotPriceHistory",  
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSubnets",
      "ec2:DescribePlacementGroups",
      "ec2:GetLaunchTemplateData",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeVolumes",
      "ec2:AttachVolume",
      "elasticloadbalancing:*",
        # 추가 IAM 권한 (Instance Profile 등 생성/삭제)
       # 추가 IAM 권한 (Instance Profile 등 생성/삭제)
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:GetInstanceProfile"
    ]
    resources = ["*"]
  }

  # 문(Statement) 2: iam:PassRole 권한만 별도로 분리 (Resource를 특정 역할로 제한)
  statement {
    sid    = "KarpenterPassRolePolicy"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    # 중요! 실제로 노드에 부여될 역할(Role)의 ARN을 정확히 지정합니다.
    # fanda-karpenter-node-role의 ARN을 참조하도록 수정해야 합니다.
    resources = [
      aws_iam_role.fanda_karpenter_node_role.arn # <--- 이 부분이 핵심!
      
    ]
  }

}

# 2-2. 위 Policy 기반으로 실제 AWS에 생성
resource "aws_iam_policy" "fanda_karpenter_controller_policy" {
  name   = "fanda-karpenter-controller-policy"
  policy = data.aws_iam_policy_document.karpenter_controller_policy.json
  
  lifecycle {
    create_before_destroy = true
  }
}

# 3. AWS에 각각 생성한 Policy를 Role에 Attach
resource "aws_iam_role_policy_attachment" "fanda_karpenter_policy_attachment" {
  role       = aws_iam_role.fanda_karpenter_controller.name
  policy_arn = aws_iam_policy.fanda_karpenter_controller_policy.arn
}
