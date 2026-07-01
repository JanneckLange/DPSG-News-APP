#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

DEPLOY_USER="deploy"
DEPLOY_HOME="/home/${DEPLOY_USER}"
APP_DIR="/opt/dpsg-news"
SSH_PORT="22"
KEY_SOURCE=""

if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${DEPLOY_USER}"
fi

mkdir -p "${DEPLOY_HOME}/.ssh"
chmod 700 "${DEPLOY_HOME}/.ssh"

if [ -f "${APP_DIR}/pubkey" ]; then
  KEY_SOURCE="${APP_DIR}/pubkey"
elif [ -f "./pubkey" ]; then
  KEY_SOURCE="./pubkey"
elif [ -f "./server/pubkey" ]; then
  KEY_SOURCE="./server/pubkey"
fi

if [ -n "${KEY_SOURCE}" ]; then
  install -m 600 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${KEY_SOURCE}" "${DEPLOY_HOME}/.ssh/authorized_keys"
  chmod 600 "${DEPLOY_HOME}/.ssh/authorized_keys"
else
  echo "Missing public key file. Expected one of: ${APP_DIR}/pubkey, ./pubkey, ./server/pubkey"
  exit 1
fi

mkdir -p "${APP_DIR}" "${APP_DIR}/secrets"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}"
chmod 700 "${APP_DIR}/secrets"

if ! command -v docker >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release ufw fail2ban
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

usermod -aG docker "${DEPLOY_USER}"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

if ! grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config; then
  echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
fi

sshd -t
systemctl restart ssh || systemctl restart sshd

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

systemctl enable --now fail2ban

echo "Bootstrap done. Next steps:"
echo "1) Copy docker-compose.server.yml and Caddyfile to ${APP_DIR}"
echo "2) Create ${APP_DIR}/.env from server.env.example with strong passwords"
echo "3) Put firebase service account JSON at ${APP_DIR}/secrets/firebase-service-account.json"
echo "4) docker compose --env-file ${APP_DIR}/.env -f ${APP_DIR}/docker-compose.server.yml up -d"
