#!/bin/bash

# ========= 色彩定义 =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WARNING='\033[1;33m'
SUCCESS='\033[1;32m'

# ========= 日志文件 =========
LOG_FILE="$(pwd)/nockchain_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ========= 项目路径 =========
NCK_DIR="$(pwd)/nockchain"

# ========= 作者信息 =========
function show_banner() {
  # 仅在交互式终端中清除屏幕
  [[ -t 0 ]] && clear

  # 定义脚本版本
  local SCRIPT_VERSION="1.0.0"
  local CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

  # 获取终端宽度，设置分隔线
  local TERM_WIDTH=$(tput cols 2>/dev/null || echo 50)
  local LINE=$(printf '%*s' "$((TERM_WIDTH/2))" | tr ' ' '=')
  local HALF_LINE=$(printf '%*s' "$((TERM_WIDTH/2))" | tr ' ' '-')

  # 居中标题
  local TITLE="Nockchain Setup Script"
  local TITLE_LEN=${#TITLE}
  local TITLE_PAD=$(( (TERM_WIDTH - TITLE_LEN) / 2 ))

  # 输出横幅
  echo -e "${BOLD}${BLUE}${LINE}${RESET}"
  echo -e "${BOLD}${BLUE}Nockchain一键安装脚本${RESET}"
  echo -e "${BOLD}${BLUE}${LINE}${RESET}"
  echo -e "${CYAN}版本: ${SCRIPT_VERSION}${RESET}"
  echo -e "${CYAN}日期: ${CURRENT_DATE}${RESET}"
  echo -e "${CYAN}${HALF_LINE}${RESET}"
  echo -e "${GREEN}作者: 闲菜${RESET}"
  echo -e "${GREEN}推特: https://x.com/xiancai4188391${RESET}"
  echo -e "${CYAN}${HALF_LINE}${RESET}"
  echo ""
}

# ========= 错误处理函数 =========
function handle_error() {
  echo -e "${RED}[-] 错误: $1${RESET}" | ts '[%Y-%m-%d %H:%M:%S]' 2>/dev/null || echo -e "${RED}[-] 错误: $1${RESET} [$CURRENT_DATE]"
  pause_and_return
  exit 1
}

# ========= 提示输入 CPU 核心数 =========
function prompt_core_count() {
  while true; do
    read -p "[?] 请输入用于编译的 CPU 核心数量 (1-$(nproc)) / Enter number of CPU cores for compilation (1-$(nproc)): " CORE_COUNT
    if [[ "$CORE_COUNT" =~ ^[0-9]+$ ]] && [[ "$CORE_COUNT" -ge 1 ]] && [[ "$CORE_COUNT" -le $(nproc) ]]; then
      break
    else
      echo -e "${RED}[-] 输入无效，请输入 1 到 $(nproc) 之间的数字。${RESET}"
    fi
  done
}

# ========= 检查命令是否存在 =========
function check_command() {
  if ! command -v "$1" &> /dev/null; then
    handle_error "$1 未安装，请先安装该工具。"
  fi
}

# ========= 安装系统依赖 =========
function install_dependencies() {
  echo -e "[*] 安装系统依赖 / Installing system dependencies..."
  check_command apt-get || handle_error "apt-get 未安装"
  
  if ! apt-get update; then
    handle_error "更新软件包列表失败！"
  fi
  
  sudo apt install -y screen curl git wget make gcc build-essential jq \
    pkg-config libssl-dev libleveldb-dev clang unzip nano autoconf \
    automake htop ncdu bsdmainutils tmux lz4 iptables nvme-cli libgbm1 || {
    handle_error "安装依赖失败！"
  }
}

# ========= 检查 Rust 版本 =========
function check_rust_version() {
  echo -e "[*] 检查 Rust 版本..."
  local min_version="1.70.0"
  if command -v rustc &> /dev/null; then
    local rust_version=$(rustc --version | awk '{print $2}')
    if [[ "$rust_version" < "$min_version" ]]; then
      echo -e "${YELLOW}[!] Rust 版本 $rust_version 过旧，正在更新...${RESET}"
      rustup update || handle_error "Rust 更新失败！"
    else
      echo -e "${GREEN}[+] Rust 版本 $rust_version 符合要求。${RESET}"
    fi
  fi
}

# ========= 安装 Rust =========
function install_rust() {
  echo -e "[*] 安装 Rust..."
  if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
      handle_error "Rust 安装失败！"
    }
    source "$HOME/.cargo/env" || handle_error "加载 Rust 环境失败！"
    rustup default stable || handle_error "设置 Rust 默认版本失败！"
  else
    echo -e "${YELLOW}[!] Rust 已安装，检查版本...${RESET}"
  fi
  check_rust_version
}

# ========= 获取最新仓库 =========
function clone_or_update_repo() {
  echo -e "[*] 获取最新仓库..."
  local retries=3
  local count=0

  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" || handle_error "进入仓库目录失败！"
    while [ $count -lt $retries ]; do
      if git pull; then
        echo -e "${GREEN}[+] 仓库更新成功！${RESET}"
        return
      fi
      count=$((count + 1))
      echo -e "${YELLOW}[!] 拉取失败，重试 $count/$retries...${RESET}"
      sleep 2
    done
    handle_error "拉取仓库更新失败！"
  else
    while [ $count -lt $retries ]; do
      if git clone --depth=1 https://github.com/zorp-corp/nockchain "$NCK_DIR"; then
        cd "$NCK_DIR" || handle_error "进入仓库目录失败！"
        echo -e "${GREEN}[+] 仓库克隆成功！${RESET}"
        return
      fi
      count=$((count + 1))
      echo -e "${YELLOW}[!] 克隆失败，重试 $count/$retries...${RESET}"
      sleep 2
    done
    handle_error "克隆仓库失败！"
  fi
}

# ========= 编译源码 =========
function build_source() {
  echo -e "[*] 编译源码 / Building source with ${CORE_COUNT} 核心..."
  
  # 定义编译命令数组
  declare -a build_commands=(
    "make install-hoonc"
    "make -j$CORE_COUNT build"
    "make -j$CORE_COUNT install-nockchain-wallet"
    "make -j$CORE_COUNT install-nockchain"
  )
  
  # 执行编译命令并检查错误
  for cmd in "${build_commands[@]}"; do
    echo -e "${CYAN}[+] 执行命令: $cmd${RESET}"
    eval "$cmd" || handle_error "命令执行失败: $cmd"
  done
}

# ========= 配置环境变量 =========
function configure_environment() {
  echo -e "[*] 配置环境变量..."
  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"

  for var in "export PATH=\"$(pwd)/nockchain/target/release:\$PATH\"" "export RUST_LOG=info" "export MINIMAL_LOG_FORMAT=true"; do
    if ! grep -Fx "$var" "$RC_FILE" > /dev/null; then
      echo "$var" >> "$RC_FILE"
      echo -e "${GREEN}[+] 添加环境变量: $var${RESET}"
    else
      echo -e "${YELLOW}[!] 环境变量已存在，跳过: $var${RESET}"
    fi
  done

  source "$RC_FILE" || handle_error "加载环境变量失败！"
}

# ========= 生成钱包 =========
function generate_wallet() {
  echo -e "[*] 生成钱包..."
  if [ ! -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
    handle_error "找不到 wallet 可执行文件，请确保编译成功。"
  fi

  tmpfile=$(mktemp)
  "$NCK_DIR/target/release/nockchain-wallet" keygen 2>&1 | tr -d '\0' | tee "$tmpfile"

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}[+] 钱包生成成功！${RESET}"
    mnemonic=$(grep "wallet: memo:" "$tmpfile" | head -1 | sed -E 's/^.*wallet: memo: (.*)$/\1/')
    private_key=$(grep 'private key: base58' "$tmpfile" | head -1 | sed -E 's/^.*private key: base58 "(.*)".*$/\1/')
    public_key=$(grep 'public key: base58' "$tmpfile" | head -1 | sed -E 's/^.*public key: base58 "(.*)".*$/\1/')

    if [[ -z "$mnemonic" || -z "$private_key" || -z "$public_key" ]]; then
      handle_error "提取钱包信息失败！"
    fi

    echo -e "\n${YELLOW}=== 请务必保存以下信息！ ===${RESET}"
    echo -e "${BOLD}助记词:${RESET}\n$mnemonic\n"
    echo -e "${BOLD}私钥:${RESET}\n$private_key\n"
    echo -e "${BOLD}公钥:${RESET}\n$public_key\n"
    echo -e "${YELLOW}=================================${RESET}\n"

    read -p "[?] 是否将助记词和私钥保存到文件？(y/N) " save_choice
    if [[ "$save_choice" =~ ^[Yy]$ ]]; then
      read -p "[?] 输入保存路径 (默认: $(pwd)/nockchain_wallet.txt): " save_path
      save_path=${save_path:-"$(pwd)/nockchain_wallet.txt"}
      echo -e "助记词: $mnemonic\n私钥: $private_key" > "$save_path"
      chmod 600 "$save_path"
      echo -e "${YELLOW}[!] 已保存到 $save_path，请确保文件安全！${RESET}"
    fi
  else
    handle_error "钱包生成失败！"
  fi

  rm -f "$tmpfile"
  pause_and_return
}

# ========= 设置挖矿公钥 =========
function configure_mining_key() {
  if [ ! -f "$NCK_DIR/Makefile" ]; then
    handle_error "找不到 Makefile，无法设置公钥！"
  fi

  read -p "[?] 输入你的挖矿公钥 : " key

  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $key|" "$NCK_DIR/Makefile"
  echo -e "${GREEN}[+] 挖矿公钥已设置！${RESET}"
  pause_and_return
}

# ========= 启动 Leader 节点 =========
function start_leader_node() {
  echo -e "[*] 启动 Leader 节点..."
  
  if screen -list | grep -q "leader"; then
    echo -e "${YELLOW}[-] Leader 节点已在运行！${RESET}"
    screen -r leader
    return
  fi

  screen -S leader -dm bash -c "cd \"$NCK_DIR\" && make run-nockchain-leader" || handle_error "启动 Leader 节点失败！"
  
  echo -e "${GREEN}[+] Leader 节点运行中！${RESET}"
  echo -e "${YELLOW}[!] 正在进入日志界面，按 Ctrl+A+D 可退出返回主菜单！${RESET}"
  sleep 2
  screen -r leader
  pause_and_return
}

# ========= 启动 Follower 节点 =========
function start_follower_node() {
  echo -e "[*] 启动 Follower 节点..."
  
  if screen -list | grep -q "follower"; then
    echo -e "${YELLOW}[-] Follower 节点已在运行！${RESET}"
    screen -r follower
    return
  fi

  screen -S follower -dm bash -c "cd \"$NCK_DIR\" && make run-nockchain-follower" || handle_error "启动 Follower 节点失败！"
  
  echo -e "${GREEN}[+] Follower 节点运行中！${RESET}"
  echo -e "${YELLOW}[!] 正在进入日志界面，按 Ctrl+A+D 可退出返回主菜单！${RESET}"
  sleep 2
  screen -r follower
  pause_and_return
}

# ========= 查看节点日志 =========
function view_logs() {
  echo ""
  echo "查看节点日志:"
  echo "  1) Leader 节点"
  echo "  2) Follower 节点"
  echo "  0) 返回主菜单"
  echo ""
  read -p "选择查看哪个节点日志: " log_choice
  case "$log_choice" in
    1)
      if screen -list | grep -q "leader"; then
        screen -r leader
      else
        echo -e "${RED}[-] Leader 节点未运行！${RESET}"
      fi
      ;;
    2)
      if screen -list | grep -q "follower"; then
        screen -r follower
      else
        echo -e "${RED}[-] Follower 节点未运行！${RESET}"
      fi
      ;;
    0) return ;;
    *) echo -e "${RED}[-] 无效选项！${RESET}" ;;
  esac
  pause_and_return
}

# ========= 停止节点 =========
function stop_nodes() {
  echo -e "[*] 停止节点..."
  for node in "leader" "follower"; do
    if screen -list | grep -q "$node"; then
      screen -S "$node" -X quit
      echo -e "${GREEN}[+] $node 节点已停止！${RESET}"
    else
      echo -e "${YELLOW}[!] $node 节点未运行！${RESET}"
    fi
  done
  pause_and_return
}

# ========= 清理项目 =========
function cleanup_project() {
  echo -e "[*] 清理项目..."
  read -p "[?] 是否删除 $NCK_DIR 目录和日志文件 $LOG_FILE？(y/N) " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$NCK_DIR" "$LOG_FILE"
    echo -e "${GREEN}[+] 项目已清理！${RESET}"
  else
    echo -e "${YELLOW}[!] 清理已取消！${RESET}"
  fi
  pause_and_return
}

# ========= 等待任意键继续 =========
function pause_and_return() {
  echo ""
  read -n1 -r -p "按任意键返回主菜单..." key
  main_menu
}

# ========= 主菜单 =========
function main_menu() {
  show_banner
  echo "请选择操作:"
  echo "  1) 一键安装并构建"
  echo "  2) 生成钱包"
  echo "  3) 设置挖矿公钥"
  echo "  4) 启动 Leader 节点 (实时日志)"
  echo "  5) 启动 Follower 节点 (实时日志)"
  echo "  6) 查看节点日志"
  echo "  7) 停止节点"
  echo "  8) 清理项目"
  echo "  0) 退出"
  echo ""
  read -p "请输入编号: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) configure_mining_key ;;
    4) start_leader_node ;;
    5) start_follower_node ;;
    6) view_logs ;;
    7) stop_nodes ;;
    8) cleanup_project ;;
    0) echo -e "${GREEN}[+] 已退出！${RESET}"; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项！${RESET}"; pause_and_return ;;
  esac
}

# ========= 一键安装并构建 =========
function setup_all() {
  install_dependencies
  install_rust
  clone_or_update_repo
  prompt_core_count
  build_source
  configure_environment
  echo -e "${GREEN}[+] 安装完成！${RESET}"
  pause_and_return
}

# ========= 启动主程序 =========
main_menu
