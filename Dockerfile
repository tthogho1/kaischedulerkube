# Build/run environment for scripts/*.sh: terraform + ansible + aws cli + jq + ssh.
FROM ubuntu:22.04

ARG TERRAFORM_VERSION=1.9.8
ARG DEBIAN_FRONTEND=noninteractive

# Some networks block plain HTTP (port 80) egress. Ubuntu's default sources.list
# uses http://, and a bare image has no CA store yet to validate https:// either
# (chicken-and-egg). Bootstrap ca-certificates over https with TLS peer
# verification off just for that one package - apt's GPG signature check still
# guarantees its authenticity - then do a normal, fully-verified update/install
# for everything else.
RUN sed -i \
      -e 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g' \
      -e 's|http://security.ubuntu.com|https://security.ubuntu.com|g' \
      /etc/apt/sources.list \
    && apt-get update -o Acquire::https::Verify-Peer=false \
    && apt-get install -y --no-install-recommends -o Acquire::https::Verify-Peer=false ca-certificates \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      curl \
      unzip \
      git \
      jq \
      openssh-client \
      python3 \
      python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Ansible
RUN pip3 install --no-cache-dir ansible

# Terraform
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && terraform version

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws \
    && aws --version

WORKDIR /workspace

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bash"]
