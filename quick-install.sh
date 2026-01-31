#!/bin/bash

# =============================================================================
# Zoo 一键部署脚本（自动下载最新部署文件）
# 用途：从指定地址下载 docker-compose.yml、.env.example、deploy.sh 并执行部署
# 使用：curl -sSL <url>/quick-install.sh | bash
# =============================================================================

set -e

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}           Zoo 一键部署${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# =============================================================================
# 配置区域：部署文件下载地址
# =============================================================================
# 默认从 GitHub 仓库下载（请根据实际情况修改）
# 示例：
#   GitHub: https://raw.githubusercontent.com/zooapicom/zoocodes/main/quick-install.sh
#   自建服务器: https://your-domain.com/deploy
DEPLOY_BASE_URL="${DEPLOY_BASE_URL:-https://raw.githubusercontent.com/zooapicom/zoocodes/main/deploy/dist/}"

# 如果需要临时指定其他地址，可以通过环境变量：
#   DEPLOY_BASE_URL=https://your-server.com/deploy bash quick-install.sh
# =============================================================================

# 安装目录（默认当前目录，可通过环境变量 ZOO_INSTALL_DIR 指定）
INSTALL_DIR="${ZOO_INSTALL_DIR:-$(pwd)}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

echo -e "${BLUE}安装目录:${NC} ${INSTALL_DIR}"
echo -e "${BLUE}下载地址:${NC} ${DEPLOY_BASE_URL}"
echo ""

# 检查必要工具
check_tools() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}✗ curl 未安装${NC}"
        echo "请先安装 curl:"
        echo "  macOS:   brew install curl"
        echo "  Ubuntu:  sudo apt-get install curl"
        echo "  CentOS:  sudo yum install curl"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} curl 已安装"
}

# 下载部署文件
download_files() {
    echo ""
    echo -e "${BLUE}正在下载部署文件...${NC}"
    echo ""
    
    # 需要下载的文件列表（使用 env.example 而非 .env.example，避免 GitHub raw 对点文件 404）
    local files=("docker-compose.yml" "env.example" "deploy.sh" "configs/zoo.yaml.example")
    
    # 确保 configs 目录存在
    mkdir -p configs
    
    # 去掉下载地址末尾的斜杠，避免 URL 中出现双斜杠
    local base_url="${DEPLOY_BASE_URL%/}"
    
    for file in "${files[@]}"; do
        # docker-compose.yml 已存在则不覆盖
        if [ "$file" = "docker-compose.yml" ] && [ -f "docker-compose.yml" ]; then
            echo -e "  ${YELLOW}⚠${NC} docker-compose.yml 已存在，保留现有配置（不覆盖）"
            echo -e "  ${GREEN}✓${NC} ${file}"
            continue
        fi
        
        echo -e "  ${CYAN}→${NC} 下载: ${file}"
        
        local url="${base_url}/${file}"
        
        # 下载文件，-f 参数确保404时报错，-S 显示错误
        if ! curl -sSL -f "${url}" -o "${file}"; then
            echo ""
            echo -e "${RED}✗ 下载失败: ${file}${NC}"
            echo -e "${RED}  URL: ${url}${NC}"
            echo ""
            echo -e "${YELLOW}可能的原因：${NC}"
            echo "  1. 网络连接问题"
            echo "  2. 文件不存在或地址配置错误"
            echo "  3. GitHub 访问受限（如在国内）"
            echo ""
            echo -e "${YELLOW}解决方案：${NC}"
            echo "  1. 检查网络连接"
            echo "  2. 确认 DEPLOY_BASE_URL 配置正确"
            echo "  3. 或手动下载部署文件后执行 ./deploy.sh"
            exit 1
        fi
        
        echo -e "  ${GREEN}✓${NC} ${file}"
    done
    
    # 自动将 env.example 复制为 .env（如果 .env 不存在）
    if [ -f "env.example" ]; then
        if [ ! -f ".env" ]; then
            echo ""
            echo -e "  ${CYAN}→${NC} 生成 .env 配置文件（从 env.example）"
            cp env.example .env
            echo -e "  ${GREEN}✓${NC} .env"
        else
            echo ""
            echo -e "  ${YELLOW}⚠${NC} .env 已存在，保留现有配置（不覆盖）"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC} 所有部署文件下载完成"
    echo ""
}

# 检查下载的文件
check_files() {
    echo -e "${BLUE}检查下载的文件...${NC}"
    
    local required_files=("docker-compose.yml" ".env" "deploy.sh" "configs/zoo.yaml.example")
    local missing=0
    
    for file in "${required_files[@]}"; do
        if [ ! -f "${file}" ]; then
            echo -e "${RED}✗ 文件不存在: ${file}${NC}"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}部署文件不完整，请检查下载地址${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} 文件完整性检查通过"
    echo ""
}

# 赋予 deploy.sh 执行权限并执行
run_deploy() {
    echo -e "${BLUE}准备执行部署脚本...${NC}"
    echo ""
    
    # 赋予执行权限
    chmod +x deploy.sh
    
    # 执行 deploy.sh（使用 exec 替换当前进程，保持交互性）
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}           开始执行 deploy.sh${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    
    exec ./deploy.sh
}

# 主流程
main() {
    check_tools
    download_files
    check_files
    run_deploy
}

# 运行主流程
main "$@"
