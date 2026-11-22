# syntax=docker/dockerfile:1
###############################################################################
# Jenkins controller cho Lab 02 – Câu 3, cài sẵn công cụ cho pipeline:
#   docker CLI + buildx (build image qua Docker socket của máy host)
#   kubectl            (deploy lên Kubernetes – cụm kind)
#   trivy              (quét lỗ hổng image / mã nguồn)
#   sonar-scanner CLI  (gửi kết quả phân tích lên SonarQube)
#   python3 + nodejs   (chạy unit test của 2 microservice)
# Plugin + cấu hình Jenkins nạp tự động bằng Configuration as Code (JCasC).
###############################################################################
FROM jenkins/jenkins:lts-jdk21

ARG SONAR_SCANNER_VERSION=6.2.1.4610
ARG NODE_MAJOR=22

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Gói hệ thống + Python
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg unzip jq git rsync \
      python3 python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Docker CLI + buildx (từ repo chính thức của Docker)
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

# Node.js
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# kubectl (bản stable mới nhất)
RUN ARCH="$(dpkg --print-architecture)" \
 && KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl" \
 && chmod +x /usr/local/bin/kubectl

# Trivy + template báo cáo HTML
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin \
 && mkdir -p /opt/trivy/contrib \
 && curl -fsSLo /opt/trivy/contrib/html.tpl https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl

# SonarScanner CLI (kèm JRE)
RUN curl -fsSLo /tmp/sonar.zip \
      "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" \
 && unzip -q /tmp/sonar.zip -d /opt \
 && ln -s "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64/bin/sonar-scanner" /usr/local/bin/sonar-scanner \
 && rm /tmp/sonar.zip

USER jenkins

# Plugin Jenkins
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Bỏ Setup Wizard, nạp cấu hình JCasC
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/usr/share/jenkins/casc_configs \
    TRIVY_CACHE_DIR=/var/jenkins_home/.cache/trivy
# Đặt ngoài JENKINS_HOME (là volume) để build lại image là cấu hình mới có hiệu lực
COPY --chown=jenkins:jenkins casc/ /usr/share/jenkins/casc_configs/
