ARG FROM_TAG=3107.v665000b_51092-2

FROM jenkins/inbound-agent:${FROM_TAG}

ARG GOSU_VERSION=1.11
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.10
ARG TINY_VERSION=0.18.0

USER root

RUN \
    set -ex; \
    # alpine only glibc
    if [ -f /etc/alpine-release ] ; then \
        echo "Alpine" ; \
    elif [ -f /etc/debian_version ] ; then \
        echo "Debian, setting locales" \
        && apt-get update --allow-releaseinfo-change \
        && apt-get install -y --no-install-recommends locales \
        && localedef  -i en_US -f UTF-8 en_US.UTF-8 \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi

ENV LANG=en_US.UTF-8

RUN \
    echo "Installing required packages" \
    ; \
    set -ex; \
    if [ -f /etc/alpine-release ] ; then \
        apk add --no-cache curl shadow iptables \
        ; \
    elif [ -f /etc/debian_version ] ; then \
        apt-get update \
        && apt-get install -y --no-install-recommends curl iptables \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi


RUN \
    set -ex; \
    echo "Installing tiny and gosu" \
    ; \
    curl -SsLo /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 \
    && chmod +x /usr/bin/gosu \
    && curl -SsLo /usr/bin/tiny https://github.com/krallin/tini/releases/download/v${TINY_VERSION}/tini-static-amd64 \
    && chmod +x /usr/bin/tiny


RUN \
    set -ex; \
    echo "Installing docker" \
    ; \
    curl -Ssl "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" | \
    tar -xz  --strip-components 1 --directory /usr/bin/

RUN \
    set -ex; \
    echo "Installing docker-compose" \
    ; \
    export CRYPTOGRAPHY_DONT_BUILD_RUST=1; \
    if [ -f /etc/alpine-release ] ; then \
        apk add --no-cache python3 py3-pip \
        \
        && apk add --no-cache --virtual .build-deps \
            python3-dev libffi-dev openssl-dev gcc libc-dev make \
        && pip3 install --upgrade --no-cache-dir pip wheel \
        && pip3 install --upgrade --no-cache-dir docker-compose \
        && apk del .build-deps \
        ; \
    elif [ -f /etc/debian_version ] ; then \
        buildDeps="python3-dev libffi-dev gcc make" \
        && apt-get update \
        && apt-get install -y --no-install-recommends python3 python3-pip python3-setuptools \
        \
        && apt-get install -y --no-install-recommends $buildDeps \
        && pip3 install --upgrade --no-cache-dir pip wheel \
        && pip3 install --upgrade --no-cache-dir docker-compose \
        && apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
        && rm -rf /var/lib/apt/lists/* \
        ; \
    fi

RUN \
   apt-get update; \
   apt-get install zip unzip;

# Install sops
RUN \
   curl -SsLo /usr/bin/sops https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux \
   && chmod +x /usr/bin/sops

# Install terraform
RUN \
    curl https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_386.zip --output terraform.zip \
    && unzip terraform.zip && rm terraform.zip \
    && mv terraform /usr/bin/terraform \
    && chmod +x /usr/bin/terraform

# Sonarqube
RUN \
    curl https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.7.0.2747-linux.zip --output sonarqube.zip \
    && unzip sonarqube.zip && rm sonarqube.zip \
    && mv sonar-scanner-4.7.0.2747-linux/ /usr/bin/sonarqube \
    && ln -s /usr/bin/sonarqube/bin/sonar-scanner /usr/bin/sonar-scanner

# jq
RUN \
    curl -LO https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && mv jq-linux64 /usr/bin/jq-linux64 \
    && chmod +x /usr/bin/jq-linux64 \
    && ln -s /usr/bin/jq-linux64 /usr/bin/jq

RUN pip3 --no-cache-dir install --upgrade awscli
RUN apt-get install make g++ -y

RUN curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl \
    && curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
    && chmod +x get_helm.sh && ./get_helm.sh

RUN apt-get install npm -y # latest version
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
SHELL ["/bin/bash", "-c", "source ~/.profile"]
RUN nvm install v16.18.1
RUN nvm use v16.18.1
RUN npm install npm@8.19.2 -g
RUN apt-get install gnupg -y
RUN gpg --version
RUN node --version
RUN npm --version
RUN helm version
RUN sops --version
RUN terraform --version
RUN sonar-scanner -v
RUN jq --version
COPY entrypoint.sh /entrypoint.sh

## https://github.com/docker-library/docker/blob/fe2ca76a21fdc02cbb4974246696ee1b4a7839dd/18.06/modprobe.sh
COPY modprobe.sh /usr/local/bin/modprobe
## https://github.com/jpetazzo/dind/blob/72af271b1af90f6e2a4c299baa53057f76df2fe0/wrapdocker
COPY wrapdocker.sh /usr/local/bin/wrapdocker

VOLUME /var/lib/docker

ENTRYPOINT [ "tiny", "--", "/entrypoint.sh" ]
