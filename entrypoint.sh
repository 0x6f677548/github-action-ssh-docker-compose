#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 $TAR_PACKAGE_OPERATION_MODIFIERS .

log "Launching ssh agent."
eval `ssh-agent -s`

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace $PROJECT_NAME...'; rm -rf \"\$HOME/workspaces/$PROJECT_NAME\" ; } ; log 'Creating workspace directory $PROJECT_NAME...' ; mkdir -p \"\$HOME/workspaces/$PROJECT_NAME\" ; trap cleanup EXIT ; log 'Unpacking workspace $PROJECT_NAME...' ; tar -C \"\$HOME/workspaces/$PROJECT_NAME\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/workspaces/$PROJECT_NAME\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$PROJECT_NAME\" up -d --remove-orphans --build"
if $USE_DOCKER_STACK ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace $PROJECT_NAME...'; rm -rf \"\$HOME/workspaces/$PROJECT_NAME\" ; } ; log 'Creating workspace directory $PROJECT_NAME...' ; mkdir -p \"\$HOME/workspaces/$PROJECT_NAME\" ; trap cleanup EXIT ; log 'Unpacking workspace $PROJECT_NAME...' ; tar -C \"\$HOME/workspaces/$PROJECT_NAME\" -xjv ; log 'Launching docker stack deploy...' ; cd \"\$HOME/workspaces/$PROJECT_NAME\" ; docker stack deploy -c \"$DOCKER_COMPOSE_FILENAME\" --prune \"$PROJECT_NAME\""
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
