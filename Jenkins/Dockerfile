FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y npm && npm install -g snyk
USER jenkins
