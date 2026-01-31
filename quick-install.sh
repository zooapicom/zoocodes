#!/bin/bash

# =============================================================================
# Zoo 快速安装脚本
# 用途：从 Git 仓库一键克隆并部署（分发包仓库根目录即 deploy.sh）
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Git 仓库地址（与 build-deploy-package.sh 中 GIT_REPO 一致）
REPO_URL="${ZOO_REPO_URL:-git@github.com:zooapicom/zoocodes.git}"
REPO_DIR="zoocodes"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}           Zoo 快速安装${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# 检查 Git
check_git() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git 未安装${NC}"
        echo ""
        echo "请先安装 Git:"
        echo "  macOS:   brew install git"
        echo "  Linux:   sudo apt-get install git"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Git 已安装"
}

# 克隆仓库
clone_repo() {
    echo ""
    echo -e "${BLUE}克隆仓库...${NC}"
    echo ""
    
    if [ -d "${REPO_DIR}" ]; then
        echo -e "${YELLOW}⚠${NC} 目录 ${REPO_DIR} 已存在"
        read -p "是否删除并重新克隆? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "${REPO_DIR}"
        else
            echo "使用现有目录"
            return 0
        fi
    fi
    
    echo "正在克隆仓库: ${REPO_URL}"
    git clone "${REPO_URL}" "${REPO_DIR}" || {
        echo -e "${RED}✗ 克隆失败${NC}"
        echo ""
        echo "请检查:"
        echo "  1. Git 仓库地址是否正确"
        echo "  2. 是否有访问权限"
        echo "  3. SSH 密钥是否配置（或使用 HTTPS 地址）"
        echo ""
        exit 1
    }
    
    echo -e "${GREEN}✓${NC} 仓库克隆完成"
    echo ""
}

# 运行部署脚本（分发包仓库根目录即为 deploy.sh）
run_deploy() {
    echo ""
    echo -e "${BLUE}进入目录并运行部署脚本...${NC}"
    echo ""
    
    cd "${REPO_DIR}"
    
    if [ ! -f "deploy.sh" ]; then
        echo -e "${RED}✗ deploy.sh 不存在（预期在仓库根目录）${NC}"
        echo "   当前目录: $(pwd)"
        exit 1
    fi
    
    chmod +x deploy.sh
    ./deploy.sh
}

# 主函数
main() {
    check_git
    clone_repo
    run_deploy
}

# 运行主函数
main "$@"

