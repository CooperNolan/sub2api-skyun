#!/usr/bin/env bash
# =============================================================================
# Sub2API 一键打包脚本
# 流程与官方 CI (release.yml) / Dockerfile 保持一致:
#   1. 前端: pnpm install + pnpm run build
#      (vite 会把产物直接输出到 backend/internal/web/dist/)
#   2. 后端: go build -tags embed 把前端嵌入二进制, 注入版本信息
#   3. 产物: dist/sub2api + dist/resources/
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${ROOT_DIR}/frontend"
BACKEND_DIR="${ROOT_DIR}/backend"
DIST_DIR="${ROOT_DIR}/dist"

log() { echo -e "\033[1;32m[build]\033[0m $*"; }
err() { echo -e "\033[1;31m[build]\033[0m $*" >&2; }

# 可选参数: 手动指定版本号 (默认读取 backend/cmd/server/VERSION)
VERSION="${1:-}"
if [ -z "${VERSION}" ]; then
    VERSION="$(tr -d ' \r\n' < "${BACKEND_DIR}/cmd/server/VERSION")"
fi

# -----------------------------------------------------------------------------
# 前置检查
# -----------------------------------------------------------------------------
command -v pnpm >/dev/null 2>&1 || { err "未找到 pnpm, 请先安装 (官方使用 pnpm 9)"; exit 1; }
command -v go   >/dev/null 2>&1 || { err "未找到 go, 请先安装 (官方使用 go 1.27)"; exit 1; }

GO_VERSION_NEED="$(grep '^go ' "${BACKEND_DIR}/go.mod" | awk '{print $2}')"
log "工具链: pnpm $(pnpm --version), go $(go version | awk '{print $3}') (go.mod 要求 ${GO_VERSION_NEED})"
log "版本号: ${VERSION}"

# -----------------------------------------------------------------------------
# Stage 1: 构建前端 -> backend/internal/web/dist/
# -----------------------------------------------------------------------------
log "==> [1/3] 构建前端..."
cd "${FRONTEND_DIR}"
pnpm install --frozen-lockfile
pnpm run build

if [ ! -f "${BACKEND_DIR}/internal/web/dist/index.html" ]; then
    err "前端产物缺失 (backend/internal/web/dist/index.html 不存在)"
    exit 1
fi

# -----------------------------------------------------------------------------
# Stage 2: 构建后端 (嵌入前端)
# -----------------------------------------------------------------------------
log "==> [2/3] 构建后端..."
cd "${BACKEND_DIR}"
COMMIT="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
DATE_VALUE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

CGO_ENABLED=0 GOOS=linux GOARCH="$(go env GOARCH)" go build \
    -tags embed \
    -ldflags="-s -w -X main.Version=${VERSION} -X main.Commit=${COMMIT} -X main.Date=${DATE_VALUE} -X main.BuildType=release" \
    -trimpath \
    -o "${DIST_DIR}/sub2api" \
    ./cmd/server

# -----------------------------------------------------------------------------
# Stage 3: 整理产物 (布局与官方 Docker 镜像的 /app 一致)
# -----------------------------------------------------------------------------
log "==> [3/3] 整理产物..."
rm -rf "${DIST_DIR}/resources"
cp -r "${BACKEND_DIR}/resources" "${DIST_DIR}/resources"

log "打包完成:"
ls -lh "${DIST_DIR}/sub2api"
log "产物目录: ${DIST_DIR} (sub2api 与 resources/ 保持同级)"
