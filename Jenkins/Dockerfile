FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y npm docker.io && \
    npm install -g snyk
USER jenkins