#!/bin/bash
set -e

#cd /nockchain

echo "🔍 验证助记词..."
if [ -n "$SEED_PHRASE" ]; then
	WORD_COUNT=$(echo "$SEED_PHRASE" | wc -w)
	if [[ $WORD_COUNT -ne 12 && $WORD_COUNT -ne 24 ]]; then
		echo "❌ 助记词应为12或24个单词，当前为 $WORD_COUNT 个"
		exit 1
	fi

  # 初始化钱包（如果尚未初始化）
  echo "🔐 初始化钱包..."
  nockchain-wallet gen-master-privkey --seedphrase "$SEED_PHRASE"
fi

# 获取主私钥（适配实际输出格式）
echo "🔑 获取主私钥..."
PRIV_OUTPUT=$(nockchain-wallet show-master-privkey 2>&1 | tr -d '\0')
MASTER_PRIVKEY=$(echo "$PRIV_OUTPUT" | awk '/master private key/{getline; getline; print}' | tr -d '[:space:]')

if [[ -z "$MASTER_PRIVKEY" ]]; then
  echo "❌ 无法提取主私钥，完整输出:"
  echo "$PRIV_OUTPUT"
  exit 1
fi
echo "✅ 主私钥: ${MASTER_PRIVKEY:0:8}..." # 只显示前8位确保安全

# 获取主公钥
echo "🔑 获取主公钥..."
PUB_OUTPUT=$(nockchain-wallet show-master-pubkey 2>&1 | tr -d '\0')
MASTER_PUBKEY=$(echo "$PUB_OUTPUT" | awk '/master public key/{getline; getline; print}' | tr -d '[:space:]')

if [[ -z "$MASTER_PUBKEY" ]]; then
  echo "❌ 无法提取主公钥，完整输出:"
  echo "$PUB_OUTPUT"
  exit 1
fi
echo "✅ 主公钥: $MASTER_PUBKEY"

# 更新Makefile
if [ -f "Makefile" ]; then
  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $MASTER_PUBKEY|" Makefile
  echo "✅ 已更新Makefile中的挖矿公钥"
fi

# 根据角色启动
case "$ROLE" in
	leader)
		echo "🚀 启动leader节点..."
		#exec make run-nockchain-leader
		mkdir -p test-leader && cd test-leader && rm -f nockchain.sock && RUST_BACKTRACE=1 nockchain --fakenet --genesis-leader --npc-socket nockchain.sock --mining-pubkey $MASTER_PUBKEY --bind /ip4/0.0.0.0/udp/3005/quic-v1 --peer /ip4/127.0.0.1/udp/3006/quic-v1 --new-peer-id --no-default-peers
		;;
	follower)
		echo "🚀 启动follower节点..."
		#exec make run-nockchain-follower
		mkdir -p test-follower && cd test-follower && rm -f nockchain.sock && RUST_BACKTRACE=1  nockchain --fakenet --genesis-watcher --npc-socket nockchain.sock --mining-pubkey $MASTER_PUBKEY --bind /ip4/0.0.0.0/udp/3006/quic-v1 --peer /ip4/127.0.0.1/udp/3005/quic-v1 --new-peer-id --no-default-peers
		;;
	*)
		echo "ℹ️ 进入交互式shell"
		exec /bin/bash
		;;
esac
