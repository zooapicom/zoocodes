#!/bin/bash

# =============================================================================
# Zoo 一键部署脚本（客户使用）
# 用途：自动部署 Zoo 服务
# =============================================================================

set -e

# 若用 sh 运行（如 sh deploy.sh），会报 Bad substitution 且 Docker 检测异常，改用 bash 执行
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

# 脚本所在目录（分发包时为包根目录，源码时为 deploy/dist/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 项目根目录：分发包模式为包根（与 SCRIPT_DIR 相同），源码模式为项目根（SCRIPT_DIR 的上两级）
if [ -d "${SCRIPT_DIR}/../docker" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
else
    PROJECT_ROOT="${SCRIPT_DIR}"
fi

# Docker Compose 命令（兼容 V1 与 V2）
COMPOSE_CMD="docker compose"
if ! docker compose version > /dev/null 2>&1; then
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
        echo "   或从项目根目录运行: ./deploy/dist/deploy.sh"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} 部署环境检查通过"
    echo ""
}

# 检查 Docker（兼容 PATH 中无 docker 但已安装于 /usr/bin 等情况）
check_docker() {
    echo -e "${BLUE}检查 Docker...${NC}"
    
    DOCKER_BIN=""
    if command -v docker > /dev/null 2>&1; then
        DOCKER_BIN="docker"
    elif [ -x /usr/bin/docker ]; then
        DOCKER_BIN="/usr/bin/docker"
    elif [ -x /usr/local/bin/docker ]; then
        DOCKER_BIN="/usr/local/bin/docker"
    fi
    
    if [ -z "$DOCKER_BIN" ]; then
        echo -e "${RED}✗ Docker 未安装${NC}"
        echo ""
        echo "请先安装 Docker:"
        echo "  macOS:   https://docs.docker.com/desktop/install/mac-install/"
        echo "  Linux:   https://docs.docker.com/engine/install/"
        echo ""
        exit 1
    fi
    
    if [ "$DOCKER_BIN" != "docker" ]; then
        export PATH="$(dirname "$DOCKER_BIN"):$PATH"
    fi
    
    if ! "$DOCKER_BIN" ps > /dev/null 2>&1; then
        echo -e "${RED}✗ Docker 服务未运行${NC}"
        echo ""
        echo "请启动 Docker 服务后重试"
        echo ""
        exit 1
    fi
    
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose > /dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    fi
    
    echo -e "${GREEN}✓${NC} Docker 已安装并运行"
    echo ""
}

# 检查 Docker Compose
check_docker_compose() {
    echo -e "${BLUE}检查 Docker Compose...${NC}"
    
    if ! command -v docker-compose > /dev/null 2>&1 && ! docker compose version > /dev/null 2>&1; then
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

# 检查并创建配置文件（compose 在 SCRIPT_DIR 运行，故 .env 与 configs 放在 SCRIPT_DIR）
check_config() {
    echo -e "${BLUE}检查配置文件...${NC}"
    
    mkdir -p "${SCRIPT_DIR}/configs"
    
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            echo -e "${YELLOW}⚠${NC} .env 文件不存在，从示例文件自动创建..."
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            echo -e "${GREEN}✓${NC} .env 文件已创建"
            echo ""
            echo -e "${YELLOW}⚠ 提示:${NC} 如需修改 MySQL、Redis 等配置，请编辑 .env 文件"
            echo ""
        elif [ -f "${SCRIPT_DIR}/env.example" ]; then
            echo -e "${YELLOW}⚠${NC} .env 文件不存在，从示例文件自动创建..."
            cp "${SCRIPT_DIR}/env.example" "${SCRIPT_DIR}/.env"
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
    
    if [ ! -f "${SCRIPT_DIR}/configs/zoo.yaml" ]; then
        if [ -f "${SCRIPT_DIR}/configs/zoo.yaml.example" ]; then
            echo -e "${YELLOW}⚠${NC} 配置文件不存在，从示例文件自动创建..."
            cp "${SCRIPT_DIR}/configs/zoo.yaml.example" "${SCRIPT_DIR}/configs/zoo.yaml"
            echo -e "${GREEN}✓${NC} 配置文件已创建: configs/zoo.yaml"
            echo ""
            echo -e "${YELLOW}⚠ 重要:${NC} 请编辑 configs/zoo.yaml 配置以下信息:"
            echo "  - MySQL 数据库连接信息"
            echo "  - Redis 连接信息"
            echo "  - JWT 密钥"
            echo "  - 其他必要配置"
            echo ""
            edit_config="n"
            if [ -t 0 ]; then
                read -p "是否现在编辑配置文件? (Y/n): " edit_config || true
                edit_config="${edit_config:-y}"
            fi
            if [[ ! "$edit_config" =~ ^[Nn]$ ]]; then
                if command -v nano > /dev/null 2>&1; then
                    nano "${SCRIPT_DIR}/configs/zoo.yaml"
                elif command -v vim > /dev/null 2>&1; then
                    vim "${SCRIPT_DIR}/configs/zoo.yaml"
                elif command -v vi > /dev/null 2>&1; then
                    vi "${SCRIPT_DIR}/configs/zoo.yaml"
                else
                    echo -e "${YELLOW}未找到编辑器，请手动编辑: ${SCRIPT_DIR}/configs/zoo.yaml${NC}"
                    [ -t 0 ] && { read -p "按 Enter 继续..." _ || true; }
                fi
            fi
        elif [ -f "${PROJECT_ROOT}/configs/zoo.yaml.example" ]; then
            echo -e "${YELLOW}⚠${NC} 配置文件不存在，从项目示例自动创建..."
            cp "${PROJECT_ROOT}/configs/zoo.yaml.example" "${SCRIPT_DIR}/configs/zoo.yaml"
            echo -e "${GREEN}✓${NC} 配置文件已创建: configs/zoo.yaml"
            echo ""
            echo -e "${YELLOW}⚠ 重要:${NC} 请编辑 configs/zoo.yaml 配置必要信息"
            echo ""
        else
            echo -e "${RED}✗ 配置文件示例不存在${NC}"
            echo "   预期: ${SCRIPT_DIR}/configs/zoo.yaml.example 或 ${PROJECT_ROOT}/configs/zoo.yaml.example"
            exit 1
        fi
    else
        echo -e "${GREEN}✓${NC} 配置文件存在，保留现有配置（不覆盖）"
    fi
    
    echo ""
}

# 创建必要的目录
create_directories() {
    echo -e "${BLUE}创建必要目录...${NC}"
    
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${SCRIPT_DIR}/configs"
    
    echo -e "${GREEN}✓${NC} 目录创建完成"
    echo ""
}

# 部署服务
deploy_service() {
    echo -e "${BLUE}部署服务...${NC}"
    echo ""
    
    cd "${SCRIPT_DIR}"
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}✗ docker-compose.yml 不存在${NC}"
        exit 1
    fi
    
    # 无 TTY 时（如 curl | bash）不提示，直接用默认；有 TTY 时提示。read 加 || true 避免 set -e 在 EOF 时退出
    pull_choice="1"
    if [ -t 0 ]; then
        echo "请选择："
        echo "  1) 拉取最新镜像（从 Docker Hub 获取最新版本后启动）"
        echo "  2) 保持当前版本（使用本地已有镜像启动）"
        echo ""
        read -p "请选择 [1/2] (默认: 1): " pull_choice || true
        pull_choice="${pull_choice:-1}"
    else
        echo "非交互模式，使用默认：拉取最新镜像"
        echo ""
    fi
    if [ "$pull_choice" = "1" ]; then
        echo ""
        echo "拉取最新镜像..."
        ${COMPOSE_CMD} -f docker-compose.yml pull
        echo ""
    else
        echo ""
        echo "使用本地已有镜像，跳过拉取"
        echo ""
    fi
    
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
