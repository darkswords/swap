#!/bin/bash
set -e

# ==========================
# Docker 管理脚本
# 支持 install | update | uninstall
# 默认安装/更新到最新版本，也可指定版本号
# ==========================

# 获取 Docker 最新版本号
get_latest_version() {
  curl -fsSL https://download.docker.com/linux/static/stable/x86_64/ \
  | grep -oP 'docker-\K[0-9]+\.[0-9]+\.[0-9]+' \
  | sort -V | tail -1
}

get_current_version() {
  if command -v docker &> /dev/null; then
    docker --version | grep -oP '\d+\.\d+\.\d+'
  else
    echo "未安装"
  fi
}

install_docker() {
  local version=$1
  if [ -z "$version" ]; then
    echo "[*] 正在获取 Docker 最新版本号..."
    version=$(get_latest_version)
  fi

  local url="https://download.docker.com/linux/static/stable/x86_64/docker-${version}.tgz"
  echo "[1/6] 下载 Docker ${version} 二进制包..."
  curl -fsSL $url -o /tmp/docker.tgz

  echo "[2/6] 解压并安装到 /usr/bin ..."
  tar xzvf /tmp/docker.tgz -C /tmp
  sudo cp /tmp/docker/* /usr/bin/
  rm -rf /tmp/docker /tmp/docker.tgz

  echo "[3/6] 创建 systemd 服务文件..."
  sudo tee /etc/systemd/system/docker.service > /dev/null <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service containerd.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  echo "[4/6] 重新加载 systemd 并启动 Docker..."
  sudo systemctl daemon-reexec
  sudo systemctl enable --now docker

  echo "[5/6] 检查 Docker 版本..."
  docker --version

  echo "[6/6] (可选) 安装 docker-compose v1.29.2"
  read -p "是否安装 docker-compose (y/n)? " yn
  if [[ "$yn" == "y" ]]; then
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version
  fi

  echo "✅ Docker ${version} 安装完成！"
}

update_docker() {
  local version=$1
  if [ -z "$version" ]; then
    echo "[*] 正在获取 Docker 最新版本号..."
    version=$(get_latest_version)
  fi

  local current_version=$(get_current_version)

  echo "[*] 当前版本: $current_version"
  echo "[*] 目标版本: $version"

  if [ "$current_version" = "$version" ]; then
    echo "✅ 已是最新版本，无需更新。"
    return
  fi

  local url="https://download.docker.com/linux/static/stable/x86_64/docker-${version}.tgz"
  echo "[1/4] 下载 Docker ${version} 二进制包..."
  curl -fsSL $url -o /tmp/docker.tgz

  echo "[2/4] 解压并覆盖安装到 /usr/bin ..."
  tar xzvf /tmp/docker.tgz -C /tmp
  sudo cp /tmp/docker/* /usr/bin/
  rm -rf /tmp/docker /tmp/docker.tgz

  echo "[3/4] 重启 Docker 服务..."
  sudo systemctl daemon-reexec
  sudo systemctl restart docker

  echo "[4/4] 检查 Docker 版本..."
  docker --version

  echo "✅ Docker 已更新至 ${version}"
}

uninstall_docker() {
  echo "[1/4] 停止 Docker 服务..."
  sudo systemctl stop docker || true
  sudo systemctl disable docker || true

  echo "[2/4] 删除 systemd 服务文件..."
  sudo rm -f /etc/systemd/system/docker.service
  sudo systemctl daemon-reload

  echo "[3/4] 删除二进制文件..."
  sudo rm -f /usr/bin/docker*
  sudo rm -f /usr/bin/containerd*
  sudo rm -f /usr/bin/runc

  echo "[4/4] 删除 docker-compose (如果有安装)..."
  sudo rm -f /usr/local/bin/docker-compose

  echo "✅ Docker 已彻底卸载完成。"
}

# ==========================
# 主逻辑
# ==========================
action=$1
version=$2

case "$action" in
  install)
    install_docker $version
    ;;
  update)
    update_docker $version
    ;;
  uninstall)
    uninstall_docker
    ;;
  *)
    echo "用法: $0 {install|update|uninstall} [版本号]"
    echo "示例:"
    echo "  $0 install        # 安装最新版本"
    echo "  $0 install 26.1.4 # 安装指定版本"
    echo "  $0 update         # 更新到最新版本（若不同才更新）"
    echo "  $0 update 27.0.3  # 更新到指定版本"
    echo "  $0 uninstall      # 卸载 Docker"
    exit 1
    ;;
esac
