#!/usr/bin/env zsh
set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
info() {
    echo "${GREEN}[INFO]${NC} $1"
}

error() {
    echo "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

# 配置
REPO="zolagz/douyin-barrage-grab"
DIST_DIR="dist"

# 检查必要工具
check_requirements() {
    info "检查必要工具..."
    
    if ! command -v git &> /dev/null; then
        error "git 未安装，请先安装 git"
    fi
    
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) 未安装，请运行: brew install gh"
    fi
    
    # 检查 gh 是否已登录
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI 未登录，请运行: gh auth login"
    fi
    
    info "✓ 所有必要工具已就绪"
}

# 获取版本号
get_version() {
    if [ -n "${1:-}" ]; then
        VERSION="$1"
    else
        # 从 readme.md 中提取版本号
        if [ -f "$DIST_DIR/readme.md" ]; then
            VERSION=$(grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" "$DIST_DIR/readme.md" | head -1)
        fi
        
        if [ -z "$VERSION" ]; then
            read "VERSION?请输入版本号 (例如 v1.2.0): "
        fi
    fi
    
    # 验证版本号格式
    if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "版本号格式错误，应为 vX.Y.Z 格式，例如: v1.2.0"
    fi
    
    info "版本号: $VERSION"
}

# 检查 dist 目录和文件
check_dist() {
    info "检查构建产物..."
    
    if [ ! -d "$DIST_DIR" ]; then
        error "dist 目录不存在，请先构建项目"
    fi
    
    # 检查是否有发布文件
    local files_found=0
    local release_files=()
    
    if [ -f "$DIST_DIR/douyin-barrage-grab-macos.dmg" ]; then
        release_files+=("$DIST_DIR/douyin-barrage-grab-macos.dmg")
        ((files_found++))
    fi
    
    if [ -f "$DIST_DIR/douyin-barrage-grab-windows-x64.zip" ]; then
        release_files+=("$DIST_DIR/douyin-barrage-grab-windows-x64.zip")
        ((files_found++))
    fi
    
    if [ $files_found -eq 0 ]; then
        error "在 dist 目录中未找到发布文件"
    fi
    
    info "找到 $files_found 个发布文件"
    for file in "${release_files[@]}"; do
        local size=$(du -h "$file" | cut -f1)
        info "  - $(basename "$file") ($size)"
    done
    
    echo "${release_files[@]}"
}

# 生成校验和
generate_checksums() {
    info "生成校验和文件..."
    
    local checksum_file="$DIST_DIR/SHA256SUMS.txt"
    rm -f "$checksum_file"
    
    cd "$DIST_DIR"
    for file in *.dmg *.zip; do
        if [ -f "$file" ]; then
            shasum -a 256 "$file" >> SHA256SUMS.txt
        fi
    done
    cd ..
    
    if [ -f "$checksum_file" ]; then
        info "✓ 校验和文件已生成"
        cat "$checksum_file"
    else
        warn "校验和文件生成失败"
    fi
}

# 检查 tag 是否已存在
check_tag() {
    if git rev-parse "$VERSION" >/dev/null 2>&1; then
        warn "Tag $VERSION 已存在"
        read "response?是否要删除现有 tag 并重新创建? (y/N): "
        if [[ "$response" =~ ^[Yy]$ ]]; then
            info "删除本地 tag..."
            git tag -d "$VERSION"
            info "删除远程 tag..."
            git push origin ":refs/tags/$VERSION" 2>/dev/null || true
        else
            error "发布已取消"
        fi
    fi
}

# 创建和推送 tag
create_tag() {
    info "创建 git tag: $VERSION"
    
    # 确保工作区干净
    if ! git diff-index --quiet HEAD --; then
        warn "工作区有未提交的更改"
        read "response?是否继续? (y/N): "
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "发布已取消"
        fi
    fi
    
    git tag -a "$VERSION" -m "Release $VERSION"
    
    info "推送 tag 到远程仓库..."
    git push origin "$VERSION"
    
    info "✓ Tag 已创建并推送"
}

# 生成发布说明
generate_release_notes() {
    local notes_file="$DIST_DIR/RELEASE_NOTES.md"
    
    if [ -f "$DIST_DIR/readme.md" ]; then
        info "从 readme.md 生成发布说明..."
        cp "$DIST_DIR/readme.md" "$notes_file"
    else
        info "创建默认发布说明..."
        cat > "$notes_file" << EOF
## 抖音直播弹幕抓取工具 $VERSION

### 📥 下载

- **Windows 64位**: \`douyin-barrage-grab-windows-x64.zip\`
- **macOS**: \`douyin-barrage-grab-macos.dmg\`

### 📦 安装说明

#### Windows
1. 下载 \`douyin-barrage-grab-windows-x64.zip\`
2. 解压缩到任意目录
3. 运行 \`flutter_barrage_grab.exe\`

#### macOS
1. 下载 \`douyin-barrage-grab-macos.dmg\`
2. 双击打开 DMG 文件
3. 将应用拖拽到 Applications 文件夹
4. 首次打开可能需要在系统偏好设置中允许运行

### ✨ 主要功能

- 💬 实时弹幕抓取
- 🎁 礼物统计分析
- 👥 用户活跃度分析
- 📊 数据可视化
- 🔊 TTS 语音播报
- 🔍 消息过滤
- 💾 数据持久化

### 🐛 问题反馈

如遇到问题，请在 [Issues](https://github.com/$REPO/issues) 中反馈。

### ⚠️ 免责声明

本工具仅供学习交流使用，请勿用于商业用途。
EOF
    fi
    
    echo "$notes_file"
}

# 创建 GitHub Release
create_release() {
    info "创建 GitHub Release..."
    
    local notes_file=$(generate_release_notes)
    local release_files=($@)
    
    # 添加校验和文件
    if [ -f "$DIST_DIR/SHA256SUMS.txt" ]; then
        release_files+=("$DIST_DIR/SHA256SUMS.txt")
    fi
    
    # 创建 release
    if gh release create "$VERSION" \
        "${release_files[@]}" \
        --repo "$REPO" \
        --title "抖音直播弹幕抓取工具 $VERSION" \
        --notes-file "$notes_file"; then
        info "✓ Release 创建成功!"
        info "查看: https://github.com/$REPO/releases/tag/$VERSION"
    else
        error "Release 创建失败"
    fi
}

# 主函数
main() {
    info "开始发布流程..."
    echo ""
    
    # 1. 检查环境
    check_requirements
    echo ""
    
    # 2. 获取版本号
    get_version "${1:-}"
    echo ""
    
    # 3. 检查构建产物
    local release_files=($(check_dist))
    echo ""
    
    # 4. 生成校验和
    generate_checksums
    echo ""
    
    # 5. 确认发布
    echo "准备发布以下文件到 GitHub:"
    for file in "${release_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""
    read "response?确认发布 $VERSION 到 GitHub? (y/N): "
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        error "发布已取消"
    fi
    echo ""
    
    # 6. 检查并创建 tag
    check_tag
    create_tag
    echo ""
    
    # 7. 创建 Release
    create_release "${release_files[@]}"
    echo ""
    
    info "🎉 发布完成!"
}

# 执行主函数
main "$@"