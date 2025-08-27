#!/bin/bash
set -e

echo "[1/4] 클러스터 정보 추출 중..."
export EKS_CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
export EKS_CLUSTER_CA=$(terraform output -raw cluster_ca)
export EKS_CLUSTER_NAME=$(terraform output -raw cluster_name)

if [[ -z "$EKS_CLUSTER_ENDPOINT" || -z "$EKS_CLUSTER_CA" || -z "$EKS_CLUSTER_NAME" ]]; then
  echo "❌ 클러스터 정보 추출 실패! (endpoint, ca, name 중 하나가 비었습니다)"
  exit 1
fi

echo "[INFO] ENDPOINT: $EKS_CLUSTER_ENDPOINT"
echo "[INFO] CA: $EKS_CLUSTER_CA"
echo "[INFO] NAME: $EKS_CLUSTER_NAME"

echo "[2/4] 클러스터 kubeconfig 연결 설정..."
aws eks update-kubeconfig --region ap-northeast-1 --name "$EKS_CLUSTER_NAME"

echo "[3/4] 모든 리소스 삭제 (terraform destroy)..."
terraform destroy \
  -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
  -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
  -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
  -auto-approve

echo "[4/4] ✅ 모든 리소스가 성공적으로 삭제되었습니다."
