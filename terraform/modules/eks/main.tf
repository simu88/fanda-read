# eks 클러스터 설정
resource "aws_eks_cluster" "fanda_eks" {
  name     = var.cluster_name
  version  = var.cluster_version

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.fanda_eks_role.arn

  vpc_config {
    subnet_ids = [var.private_subnet_ids[0], var.private_subnet_ids[1]]
  }

  depends_on = [
    aws_iam_role_policy_attachment.fanda_eks_role_attachment
  ]
}

resource "aws_iam_role" "fanda_eks_role" {
  name = "fanda-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fanda_eks_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.fanda_eks_role.name
}


# eks node group 설정
resource "aws_eks_node_group" "fanda_node_group" {
  cluster_name    = aws_eks_cluster.fanda_eks.name
  node_group_name = "fanda-node-group"
  node_role_arn   = aws_iam_role.fanda_node_group_role.arn
  subnet_ids      = [var.private_subnet_ids[0], var.private_subnet_ids[1]]
  # instance_types = ["m7g.xlarge"]
  # ami_type       = "AL2_ARM_64"
  
  instance_types = ["t3.large"]
  ami_type       = "AL2_x86_64"

  scaling_config {
    desired_size = 3
    max_size     = 4
    min_size     = 3
  }

  update_config {
    max_unavailable = 3
  }

  #  # =================== [추가] ===================
  # # 1. 이 노드 그룹을 식별하기 위한 레이블을 추가합니다.
  # # Karpenter 컨트롤러가 이 레이블을 보고 찾아올 것입니다.
  # labels = {
  #   "fanda-node-group-type" = "core-management"
  # }

  # # 2. 이 노드 그룹에 Taint를 설정하여 일반 파드가 스케줄링되는 것을 막습니다.
  # # "NoSchedule"은 새로운 파드의 스케줄링만 막고, 이미 실행 중인 파드는 유지합니다.
  # taint {
  #   key    = "fanda-node-group-type"
  #   value  = "core-management"
  #   effect = "NO_SCHEDULE"
  # }


  depends_on = [
    aws_iam_role_policy_attachment.fanda-ng-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.fanda-ng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.fanda-ng-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.fanda-ng-ssm-policy 
  ]
}

resource "aws_iam_role" "fanda_node_group_role" {
  name = "fanda-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fanda-ng-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.fanda_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "fanda-ng-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.fanda_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "fanda-ng-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.fanda_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "fanda-ng-ssm-policy" {
  role       = aws_iam_role.fanda_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}



resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "fanda-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attach" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.fanda_eks.name
  addon_name               = "aws-ebs-csi-driver"
  //addon_version            = "v1.17.0-eksbuild.1"  # 최신 버전 확인 후 수정 가능
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
  //resolve_conflicts        = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}



# 현재 AWS 계정 ID를 가져오기 위한 데이터 소스
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "sso_admin" {
  cluster_name  = aws_eks_cluster.fanda_eks.name
  principal_arn = "arn:aws:iam::746491138596:role/aws-reserved/sso.amazonaws.com/ap-northeast-2/AWSReservedSSO_AdministratorAccess_4b936ab6103e5edf"
}

resource "aws_eks_access_policy_association" "sso_admin_policy" {
  cluster_name  = aws_eks_cluster.fanda_eks.name
  principal_arn = aws_eks_access_entry.sso_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

