# nockchain 脚本
## 一、脚本方式运行，Ubuntu为例
```
wget -O nockchain_setup.sh https://raw.githubusercontent.com/xk320/nockchain/main/nockchain_setup.sh && sed -i 's/\r$//' nockchain_setup.sh && chmod +x nockchain_setup.sh && ./nockchain_setup.sh
```
## 二、docker方式运行

### 1、安装docker
```
#安装依赖
apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common
# 配置官方仓库
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# 安装
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
### 2、克隆仓库
```
git clone https://github.com/xk320/nockchain.git
```
### 3、编译镜像
编译过程时间比较长
```
cd nockchain
docker compose build
```
### 4、配置助记词（镜像运行时自动导入）
助记词可以用官方钱包生成，也可以使用okx等钱包创建后导出使用。
```
#创建修改env文件，填入助记词
vim .env
```
### 5、运行
```
docker compose up -d
```
### 6、停止
```
docker compose down -v
```
