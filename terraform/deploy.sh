set -e

AWS_REGION="us-east-1"

# 1단계: VPC + EKS만 생성
echo "[1/7] VPC + EKS 클러스터 생성 중..."
terraform apply -target=module.vpc -auto-approve
terraform apply -target=module.db -auto-approve
terraform apply -target=module.msk -auto-approve
terraform apply -target=module.eks -auto-approve


# 2단계: 클러스터 정보 추출
echo "[2/7] EKS 클러스터 정보 추출 중..."
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

# 3단계: 클러스터 활성 대기 + kubeconfig 연결
echo "[3/7] 클러스터 활성화 대기 및 kubeconfig 설정 중..."
aws eks wait cluster-active --name "$EKS_CLUSTER_NAME" --region $AWS_REGION
aws eks update-kubeconfig --region $AWS_REGION --name "$EKS_CLUSTER_NAME"

# 인증 잘 되는지 체크
echo "[INFO] kubeconfig 인증 테스트"
kubectl get nodes || {
  echo "❌ kubectl 인증 실패! AWS 자격증명 프로필을 확인하세요."
  exit 2
}

# 4단계: Karpenter Helm Chart 및 CRD만 우선 설치
# echo "[4/7] Karpenter Helm Chart/CRD만 먼저 설치..."
# terraform apply -target=module.karpenter.helm_release.karpenter \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -auto-approve

terraform apply \
  -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
  -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
  -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
  -auto-approve

# 5단계: CRD 생성 완료까지 대기
echo "⏳ Karpenter CRD 등록 대기 중... (최대 30초 대기)"
sleep 30
kubectl get crd | grep karpenter

# ✅ 기존 Provisioner 삭제(충돌 방지)
echo "[INFO] 기존 Provisioner 리소스 삭제 중 (충돌 방지)"
kubectl delete provisioner default --ignore-not-found || true

# ✅ Instance Profile 이름 추출 및 YAML 변수치환 후 적용
echo "[INFO] Karpenter용 Instance Profile 이름 추출"
export INSTANCE_PROFILE=$(terraform output -raw karpenter_node_instance_profile)

echo "[INFO] Provisioner 리소스 YAML 변수 치환 후 수동 적용 중..."
envsubst < modules/karpenter/nodepool.yaml | kubectl apply -f -

# # 6단계 전 추가 (aws-auth까지 적용되었을 때)모니터링 적용
# echo "[5.5/7] Prometheus + Grafana 모니터링 모듈 적용..."
# terraform apply \
#   -target=module.monitoring \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -parallelism=1 \
#   -auto-approve

# # 6단계: 나머지 Karpenter 리소스 및 전체 리소스 적용
# echo "[6/7] 전체 리소스 최종 적용 (ALB, K8s 등)..."
# terraform apply \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -auto-approve

# echo "[7/7] ✅ 모든 리소스가 성공적으로 배포되었습니다."






# set -e

# AWS_REGION="ap-northeast-1"

# # 1단계: VPC + EKS만 생성
# echo "[1/7] VPC + EKS 클러스터 생성 중..."
# terraform apply -target=module.vpc -auto-approve
# # terraform apply -target=module.db -auto-approve
# # terraform apply -target=module.msk -auto-approve
# terraform apply -target=module.eks -auto-approve


# # 2단계: 클러스터 정보 추출
# echo "[2/7] EKS 클러스터 정보 추출 중..."
# export EKS_CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
# export EKS_CLUSTER_CA=$(terraform output -raw cluster_ca)
# export EKS_CLUSTER_NAME=$(terraform output -raw cluster_name)

# if [[ -z "$EKS_CLUSTER_ENDPOINT" || -z "$EKS_CLUSTER_CA" || -z "$EKS_CLUSTER_NAME" ]]; then
#   echo "❌ 클러스터 정보 추출 실패! (endpoint, ca, name 중 하나가 비었습니다)"
#   exit 1
# fi

# echo "[INFO] ENDPOINT: $EKS_CLUSTER_ENDPOINT"
# echo "[INFO] CA: $EKS_CLUSTER_CA"
# echo "[INFO] NAME: $EKS_CLUSTER_NAME"

# # 3단계: 클러스터 활성 대기 + kubeconfig 연결
# echo "[3/7] 클러스터 활성화 대기 및 kubeconfig 설정 중..."
# aws eks wait cluster-active --name "$EKS_CLUSTER_NAME" --region $AWS_REGION
# aws eks update-kubeconfig --region $AWS_REGION --name "$EKS_CLUSTER_NAME"

# # 인증 잘 되는지 체크
# echo "[INFO] kubeconfig 인증 테스트"
# kubectl get nodes || {
#   echo "❌ kubectl 인증 실패! AWS 자격증명 프로필을 확인하세요."
#   exit 2
# }

# # 4단계: Karpenter Helm Chart 및 CRD만 우선 설치
# echo "[4/7] Karpenter Helm Chart/CRD만 먼저 설치..."
# terraform apply -target=module.karpenter.helm_release.karpenter \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -auto-approve

# # 5단계: CRD 생성 완료까지 대기
# echo "⏳ Karpenter CRD 등록 대기 중... (최대 30초 대기)"
# sleep 30
# kubectl get crd | grep karpenter

# # ✅ 기존 Provisioner 삭제(충돌 방지)
# echo "[INFO] 기존 Provisioner 리소스 삭제 중 (충돌 방지)"
# kubectl delete provisioner default --ignore-not-found || true

# # ✅ Instance Profile 이름 추출 및 YAML 변수치환 후 적용
# echo "[INFO] Karpenter용 Instance Profile 이름 추출"
# export INSTANCE_PROFILE=$(terraform output -raw karpenter_node_instance_profile)

# echo "[INFO] Provisioner 리소스 YAML 변수 치환 후 수동 적용 중..."
# envsubst < modules/karpenter/nodepool.yaml | kubectl apply -f -

# # 6단계 전 추가 (aws-auth까지 적용되었을 때)모니터링 적용
# echo "[5.5/7] Prometheus + Grafana 모니터링 모듈 적용..."
# terraform apply \
#   -target=module.monitoring \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -parallelism=1 \
#   -auto-approve

# # 6단계: 나머지 Karpenter 리소스 및 전체 리소스 적용
# echo "[6/7] 전체 리소스 최종 적용 (ALB, K8s 등)..."
# terraform apply \
#   -var="eks_cluster_endpoint=$EKS_CLUSTER_ENDPOINT" \
#   -var="eks_cluster_ca=$EKS_CLUSTER_CA" \
#   -var="eks_cluster_name=$EKS_CLUSTER_NAME" \
#   -auto-approve

# echo "[7/7] ✅ 모든 리소스가 성공적으로 배포되었습니다."


