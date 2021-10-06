FROM ubuntu:20.04

RUN apt update
RUN apt-get install -y apt-transport-https ca-certificates curl openssh-client && \
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

COPY bin/gitops /usr/local/bin/gitops
RUN chmod 555 /usr/local/bin/gitops

RUN useradd -ms /bin/bash gitops_admin
USER gitops_admin
RUN mkdir ~/.ssh
RUN ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

ENTRYPOINT [ "gitops" ]
