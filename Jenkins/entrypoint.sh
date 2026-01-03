#!/bin/bash
# Entrypoint script for Jenkins container to ensure docker.sock permissions and start Jenkins
chmod 666 /var/run/docker.sock || true
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
