# nockchain 脚本
## 一、Ubuntu 安装运行脚本
```
wget -O nockchain_setup.sh https://raw.githubusercontent.com/xk320/nockchain/main/nockchain_setup.sh && sed -i 's/\r$//' nockchain_setup.sh && chmod +x nockchain_setup.sh && ./nockchain_setup.sh
```
## 二、docker方式运行

### 1、安装docker

### 2、克隆仓库

### 3、编译镜像
编译过程时间比较长
```
docker compose build
```
### 4、配置助记词（镜像运行时自动导入）
```
#创建修改env文件，填入助记词
vim .env
```
### 5、运行
```
docker compose up -d
```
