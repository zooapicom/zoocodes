#!/bin/bash

# =============================================================================
# Zoo 一键部署脚本（客户使用）
# 用途：自动部署 Zoo 服务
# 参考：https://github.com/xyhelper/chatgpt-mirror-server-deploy
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本所在目录（源码时为 deploy/，分发包时为包根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录：源码模式为项目根，分发包模式为包根（与 SCRIPT_DIR 相同）
if [ -f "${SCRIPT_DIR}/Dockerfile" ] || [ -d "${SCRIPT_DIR}/../web" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
    PROJECT_ROOT="${SCRIPT_DIR}"
fi

# Docker Compose 命令（兼容 V1 与 V2）
COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
fi

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}           Zoo 一键部署${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# 检查是否在正确的目录
check_directory() {
    echo -e "${BLUE}检查部署环境...${NC}"
    
    if [ ! -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
        echo -e "${RED}✗ 错误: 缺少 docker-compose.yml${NC}"
        echo "   预期位置: ${SCRIPT_DIR}/docker-compose.yml"
        echo ""
        echo -e "${YELLOW}提示:${NC} 请先解压分发包: tar -xzf zoo-deploy-*.tar.gz && cd zoo-deploy-*"
        echo "   或从项目根目录运行: ./deploy/deploy.sh"
        echo ""
        exit 1
    fi
    
    # 分发包模式（无 Dockerfile、无 web/）仅需 docker-compose.yml
    if [ -f "${SCRIPT_DIR}/Dockerfile" ] || [ -d "${SCRIPT_DIR}/../web" ]; then
        if [ ! -f "${SCRIPT_DIR}/Dockerfile" ]; then
            echo -e "${RED}✗ 错误: 缺少 Dockerfile（源码模式）${NC}"
            echo "   预期位置: ${SCRIPT_DIR}/Dockerfile"
            exit 1
        fi
        if [ ! -d "${PROJECT_ROOT}/web" ]; then
            echo -e "${RED}✗ 错误: 缺少 web/ 目录（源码模式）${NC}"
            echo "   预期位置: ${PROJECT_ROOT}/web"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓${NC} 部署环境检查通过"
    echo ""
}

# 检查 Docker
check_docker() {
    echo -e "${BLUE}检查 Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker 未安装${NC}"
        echo ""
        echo "请先安装 Docker:"
        echo "  macOS:   https://docs.docker.com/desktop/install/mac-install/"
        echo "  Linux:   https://docs.docker.com/engine/install/"
        echo ""
        exit 1
    fi
    
    if ! docker ps &> /dev/null 2>&1; then
        echo -e "${RED}✗ Docker 服务未运行${NC}"
        echo ""
        echo "请启动 Docker 服务后重试"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Docker 已安装并运行"
    echo ""
}

# 检查 Docker Compose
check_docker_compose() {
    echo -e "${BLUE}检查 Docker Compose...${NC}"
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        echo -e "${RED}✗ Docker Compose 未安装${NC}"
        echo ""
        echo "Docker Desktop 通常已包含 Docker Compose"
        echo "或使用: pip install docker-compose"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Docker Compose 已安装"
    echo ""
}

# 检查并创建配置文件
check_config() {
    echo -e "${BLUE}检查配置文件...${NC}"
    
    # 确保 configs 目录存在
    mkdir -p "${PROJECT_ROOT}/configs"
    
    # 检查并创建 .env 文件（分发包根目录为 .env.example）
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            echo -e "${YELLOW}⚠${NC} .env 文件不存在，从示例文件自动创建..."
            cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
            echo -e "${GREEN}✓${NC} .env 文件已创建"
            echo ""
            echo -e "${YELLOW}⚠ 提示:${NC} 如需修改 MySQL、Redis 等配置，请编辑 .env 文件"
            echo ""
        elif [ -f "${SCRIPT_DIR}/env.example" ]; then
            echo -e "${YELLOW}⚠${NC} .env 文件不存在，从示例文件自动创建..."
            cp "${SCRIPT_DIR}/env.example" "${PROJECT_ROOT}/.env"
            echo -e "${GREEN}✓${NC} .env 文件已创建"
            echo ""
            echo -e "${YELLOW}⚠ 提示:${NC} 如需修改 MySQL、Redis 等配置，请编辑 .env 文件"
            echo ""
        else
            echo -e "${YELLOW}⚠${NC} .env.example / env.example 不存在，跳过 .env 创建"
        fi
    else
        echo -e "${GREEN}✓${NC} .env 文件存在"
    fi
    
    if [ ! -f "${PROJECT_ROOT}/configs/zoo.yaml" ]; then
        if [ -f "${PROJECT_ROOT}/configs/zoo.yaml.example" ]; then
            echo -e "${YELLOW}⚠${NC} 配置文件不存在，从示例文件自动创建..."
            cp "${PROJECT_ROOT}/configs/zoo.yaml.example" "${PROJECT_ROOT}/configs/zoo.yaml"
            echo -e "${GREEN}✓${NC} 配置文件已创建: configs/zoo.yaml"
            echo ""
            echo -e "${YELLOW}⚠ 重要:${NC} 请编辑 configs/zoo.yaml 配置以下信息:"
            echo "  - MySQL 数据库连接信息"
            echo "  - Redis 连接信息"
            echo "  - JWT 密钥"
            echo "  - 其他必要配置"
            echo ""
            read -p "是否现在编辑配置文件? (Y/n): " edit_config
            if [[ ! "$edit_config" =~ ^[Nn]$ ]]; then
                # 尝试使用默认编辑器
                if command -v nano &> /dev/null; then
                    nano "${PROJECT_ROOT}/configs/zoo.yaml"
                elif command -v vim &> /dev/null; then
                    vim "${PROJECT_ROOT}/configs/zoo.yaml"
                elif command -v vi &> /dev/null; then
                    vi "${PROJECT_ROOT}/configs/zoo.yaml"
                else
                    echo -e "${YELLOW}未找到编辑器，请手动编辑: ${PROJECT_ROOT}/configs/zoo.yaml${NC}"
                    read -p "按 Enter 继续..."
                fi
            fi
        else
            echo -e "${RED}✗ 配置文件示例不存在${NC}"
            echo "   预期位置: ${PROJECT_ROOT}/configs/zoo.yaml.example"
            exit 1
        fi
    else
        echo -e "${GREEN}✓${NC} 配置文件存在"
    fi
    
    echo ""
}

# 创建必要的目录
create_directories() {
    echo -e "${BLUE}创建必要目录...${NC}"
    
    mkdir -p "${PROJECT_ROOT}/logs"
    mkdir -p "${PROJECT_ROOT}/configs"
    
    echo -e "${GREEN}✓${NC} 目录创建完成"
    echo ""
}

# 部署服务
deploy_service() {
    echo -e "${BLUE}部署服务...${NC}"
    echo ""
    
    cd "${SCRIPT_DIR}"
    
    # 检查 docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}✗ docker-compose.yml 不存在${NC}"
        exit 1
    fi
    
    # 拉取/构建镜像并启动
    echo "启动服务（这可能需要几分钟）..."
    echo ""
    
    ${COMPOSE_CMD} -f docker-compose.yml up -d --build
    
    echo ""
    echo -e "${GREEN}✓${NC} 服务启动完成"
    echo ""
}

# 等待服务就绪
wait_for_service() {
    echo -e "${BLUE}等待服务就绪...${NC}"
    echo ""
    
    MAX_WAIT=30
    for i in $(seq 1 $MAX_WAIT); do
        if curl -f -s http://localhost:8599/healthz > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} 服务已就绪"
            echo ""
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    echo ""
    echo -e "${YELLOW}⚠${NC} 服务启动超时，但可能仍在启动中"
    echo ""
}

# 显示服务信息
show_service_info() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}             部署完成！${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "${GREEN}服务状态:${NC}"
    
    cd "${SCRIPT_DIR}"
    ${COMPOSE_CMD} -f docker-compose.yml ps
    
    echo ""
    echo -e "${GREEN}访问地址:${NC}"
    echo -e "  ${BLUE}用户端${NC}       → http://localhost:8599/"
    echo -e "  ${BLUE}管理后台${NC}     → http://localhost:8599/web/admin/"
    echo -e "  ${BLUE}健康检查${NC}     → http://localhost:8599/healthz"
    echo ""
    echo -e "${YELLOW}常用命令:${NC} (在当前目录下执行)"
    echo "  查看日志:   ${COMPOSE_CMD} -f docker-compose.yml logs -f"
    echo "  停止服务:   ${COMPOSE_CMD} -f docker-compose.yml down"
    echo "  重启服务:   ${COMPOSE_CMD} -f docker-compose.yml restart"
    echo "  查看状态:   ${COMPOSE_CMD} -f docker-compose.yml ps"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# 主函数
main() {
    check_directory
    check_docker
    check_docker_compose
    check_config
    create_directories
    deploy_service
    wait_for_service
    show_service_info
}

# 运行主函数
main "$@"
