FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y npm docker.io git && \
    npm install -g snyk
USER root
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]