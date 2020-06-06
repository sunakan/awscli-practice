ARG DOCKER_AWSCLI_TAG
FROM amazon/aws-cli:${DOCKER_AWSCLI_TAG}

RUN yum update \
  && yum install --assumeyes \
    make \
    jq
