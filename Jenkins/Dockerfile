FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y npm docker.io && \
    npm install -g snyk && \
    chmod 666 /var/run/docker.sock || true
    
# Copy custom entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER jenkins
ENTRYPOINT ["/entrypoint.sh"]