#!/bin/bash
set -e

# ==========================
# Docker 离线管理脚本
# 支持 offline 安装/升级 | uninstall 卸载
# ==========================

get_current_version() {
  if command -v docker &> /dev/null; then
    docker --version | grep -oP '\d+\.\d+\.\d+'
  else
    echo "未安装"
  fi
}

install_offline() {
  local tgz_file=$1

  # 自动检测目录下最新 docker-*.tgz
  if [ -z "$tgz_file" ]; then
    tgz_file=$(ls docker-*.tgz 2>/dev/null | sort -V | tail -1)
    if [ -z "$tgz_file" ]; then
      echo "❌ 当前目录未找到 docker-*.tgz 包，请放置离线包再执行。"
      exit 1
    fi
  fi

  if [ ! -f "$tgz_file" ]; then
    echo "❌ 指定文件 $tgz_file 不存在！"
    exit 1
  fi

  # 从文件名提取版本号
  local version=$(echo "$tgz_file" | grep -oP '\d+\.\d+\.\d+')

  local current_version=$(get_current_version)
  echo "[*] 当前版本: $current_version"
  echo "[*] 目标版本: $version"

  if [ "$current_version" = "$version" ]; then
    echo "✅ 已是相同版本，无需安装。"
    return
  fi

  echo "[1/4] 解压 $tgz_file 并安装到 /usr/bin ..."
  tar xzvf "$tgz_file" -C /tmp
  sudo cp /tmp/docker/* /usr/bin/
  rm -rf /tmp/docker

  echo "[2/4] 创建 systemd 服务文件..."
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

  echo "[3/4] 重载 systemd 并启动 Docker..."
  sudo systemctl daemon-reexec
  sudo systemctl enable --now docker

  echo "[4/4] 检查 Docker 版本..."
  docker --version

  echo "✅ Docker ${version} 安装/升级完成！"
}

uninstall_offline() {
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
file=$2

case "$action" in
  offline)
    install_offline "$file"
    ;;
  upgrade)
    install_offline "$file"
    ;;
  uninstall)
    uninstall_offline
    ;;
  *)
    echo "用法: $0 {offline|upgrade|uninstall} [docker-<版本>.tgz]"
    echo "示例:"
    echo "  $0 offline                 # 自动检测当前目录最新 docker-*.tgz 安装"
    echo "  $0 offline docker-28.3.2.tgz # 指定离线包安装"
    echo "  $0 upgrade docker-28.3.2.tgz # 使用离线包升级"
    echo "  $0 uninstall               # 卸载 Docker"
    exit 1
    ;;
esac
