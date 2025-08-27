# 파일 경로: modules/argocd/outputs.tf

# Argo CD 초기 관리자 비밀번호 시크릿을 읽어옵니다.
data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    # fullnameOverride 설정에 따라 생성될 시크릿 이름을 직접 지정합니다.
    # 'fanda-argocd-initial-admin-secret'
    name      = "argocd-initial-admin-secret"
    namespace = "fanda-cicd"
  }
  depends_on = [helm_release.fanda_argocd]
}

# Argo CD 서버의 LoadBalancer 서비스 정보를 읽어옵니다.
data "kubernetes_service" "argocd_server" {
  metadata {
    # fullnameOverride 설정에 따라 생성될 서비스 이름을 직접 지정합니다.
    # 'fanda-argocd-server'
    name      = "fanda-argocd-server"
    namespace = "fanda-cicd"
  }
  depends_on = [helm_release.fanda_argocd]
}


# 출력: 초기 비밀번호
# terraform output -raw argocd_initial_admin_password
output "argocd_initial_admin_password" {
  description = "Initial password for the Argo CD 'admin' user."
  # try()를 사용하여, 시크릿이 아직 생성되지 않은 plan 단계에서 오류가 발생하는 것을 방지합니다.
  value       = try(base64decode(data.kubernetes_secret.argocd_initial_admin_secret.data.password), "Secret not available yet")
  sensitive   = true
}

# 출력: 서버 접속 주소
output "argocd_server_hostname" {
  description = "Hostname of the Argo CD server Load Balancer."
  # try()를 사용하여, 로드밸런서가 아직 생성되지 않은 plan 단계에서 오류가 발생하는 것을 방지합니다.
  value       = try("http://${data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname}", "LoadBalancer not ready yet")
}


