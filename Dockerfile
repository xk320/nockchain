# 阶段1：构建环境
FROM ubuntu:22.04 AS builder

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装构建依赖，包括 ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git make gcc clang pkg-config libssl-dev libleveldb-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# 克隆仓库
WORKDIR /root
RUN git clone https://github.com/zorp-corp/nockchain

# 构建项目
WORKDIR /root/nockchain
RUN make install-hoonc && \
    make build && \
    make install-nockchain-wallet && \
    make install-nockchain

# 阶段2：运行时环境
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libleveldb1d ca-certificates make \
    && rm -rf /var/lib/apt/lists/*

# 复制整个 nockchain 目录
#COPY --from=builder /root/nockchain /nockchain
COPY --from=builder /root/nockchain/target/release/nockchain /usr/local/bin/nockchain
COPY --from=builder /root/nockchain/target/release/nockchain-wallet /usr/local/bin/nockchain-wallet

# 设置环境变量
#ENV PATH="/usr/local/bin:/nockchain/target/release:${PATH}"
ENV PATH="/usr/local/bin:${PATH}"
ENV RUST_LOG=info
ENV MINIMAL_LOG_FORMAT=true

# 复制启动脚本
COPY entrypoint.sh /nockchain/entrypoint.sh
RUN chmod +x /nockchain/entrypoint.sh

# 设置工作目录
WORKDIR /nockchain

ENTRYPOINT ["./entrypoint.sh"]
