#!/bin/bash
#
# 用法：
#   ./rename_with_size.sh [选项] /path/to/your/folder
#
# 选项：
#   -r          递归处理所有子目录
#   -d <层数>   指定递归层数（默认0不递归）
#
# 示例：
#   ./rename_with_size.sh /path           # 只处理一级子文件夹
#   ./rename_with_size.sh -r /path        # 递归处理所有层级
#   ./rename_with_size.sh -d 3 /path      # 递归处理3层
#

# ============================================
# 系统健康度检查函数
# ============================================

# 检查系统健康度（CPU、内存、I/O、硬盘）
check_system_health() {
  local cpu_threshold=80      # CPU使用率阈值（%）
  local mem_threshold=85      # 内存使用率阈值（%）
  local disk_threshold=90     # 硬盘使用率阈值（%）
  local load_threshold=8      # 系统负载阈值（基于CPU核心数）
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🏥 系统健康度检查"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  local health_issues=0
  local warning_messages=()
  
  # 1. CPU 使用率检查
  echo "🔍 检查 CPU 使用率..."
  local cpu_idle=$(top -l 2 -n 0 | grep "CPU usage" | tail -1 | awk '{print $7}' | sed 's/%//')
  if [ -n "$cpu_idle" ]; then
    local cpu_usage=$(echo "100 - $cpu_idle" | bc)
    local cpu_int=$(echo "$cpu_usage / 1" | bc)
    
    if [ "$(echo "$cpu_usage > $cpu_threshold" | bc)" -eq 1 ]; then
      echo "  ⚠️  CPU 使用率: ${cpu_int}% (超过阈值 ${cpu_threshold}%)"
      warning_messages+=("CPU 使用率过高")
      ((health_issues++))
    else
      echo "  ✅ CPU 使用率: ${cpu_int}% (正常)"
    fi
  else
    echo "  ⚠️  无法获取 CPU 使用率"
  fi
  echo
  
  # 2. 内存使用率检查
  echo "🔍 检查内存使用率..."
  # 使用 vm_stat 获取内存信息（macOS）
  local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
  local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
  local pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
  local pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
  local pages_wired=$(vm_stat | grep "Pages wired" | awk '{print $4}' | sed 's/\.//')
  
  if [ -n "$page_size" ] && [ -n "$pages_free" ]; then
    local mem_total_bytes=$(sysctl -n hw.memsize)
    local mem_used_bytes=$(echo "($pages_active + $pages_inactive + $pages_wired) * $page_size" | bc)
    local mem_usage=$(echo "scale=1; $mem_used_bytes * 100 / $mem_total_bytes" | bc)
    local mem_int=$(echo "$mem_usage / 1" | bc)
    
    if [ "$(echo "$mem_usage > $mem_threshold" | bc)" -eq 1 ]; then
      echo "  ⚠️  内存使用率: ${mem_int}% (超过阈值 ${mem_threshold}%)"
      warning_messages+=("内存使用率过高")
      ((health_issues++))
    else
      echo "  ✅ 内存使用率: ${mem_int}% (正常)"
    fi
  else
    echo "  ⚠️  无法获取内存使用率"
  fi
  echo
  
  # 3. 系统负载检查
  echo "🔍 检查系统负载..."
  local cpu_cores=$(sysctl -n hw.ncpu)
  local load_avg=$(uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1}' | sed 's/,//')
  
  if [ -n "$load_avg" ] && [ -n "$cpu_cores" ]; then
    local load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc)
    
    if [ "$(echo "$load_avg > $load_threshold" | bc)" -eq 1 ]; then
      echo "  ⚠️  系统负载: ${load_avg} (${cpu_cores}核心，平均${load_per_core}/核心)"
      echo "     负载过高，可能影响视频处理性能"
      warning_messages+=("系统负载过高")
      ((health_issues++))
    else
      echo "  ✅ 系统负载: ${load_avg} (${cpu_cores}核心，平均${load_per_core}/核心，正常)"
    fi
  else
    echo "  ⚠️  无法获取系统负载"
  fi
  echo
  
  # 4. 硬盘使用率检查（当前目录所在磁盘）
  echo "🔍 检查硬盘使用率..."
  local disk_usage=$(df -h "$TARGET_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
  local disk_avail=$(df -h "$TARGET_DIR" | tail -1 | awk '{print $4}')
  
  if [ -n "$disk_usage" ]; then
    if [ "$disk_usage" -gt "$disk_threshold" ]; then
      echo "  ⚠️  硬盘使用率: ${disk_usage}% (超过阈值 ${disk_threshold}%)"
      echo "     可用空间: ${disk_avail}"
      warning_messages+=("硬盘空间不足")
      ((health_issues++))
    else
      echo "  ✅ 硬盘使用率: ${disk_usage}% (可用: ${disk_avail}，正常)"
    fi
  else
    echo "  ⚠️  无法获取硬盘使用率"
  fi
  echo
  
  # 5. I/O 压力检查（通过磁盘活动进程数）
  echo "🔍 检查 I/O 压力..."
  local io_processes=$(ps aux | awk '$8 ~ /D/ {count++} END {print count+0}')
  
  if [ "$io_processes" -gt 5 ]; then
    echo "  ⚠️  I/O 等待进程数: ${io_processes} (可能存在 I/O 瓶颈)"
    warning_messages+=("I/O 压力较大")
    ((health_issues++))
  else
    echo "  ✅ I/O 等待进程数: ${io_processes} (正常)"
  fi
  echo
  
  # 汇总健康度检查结果
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ $health_issues -eq 0 ]; then
    echo "✅ 系统健康度良好，可以继续处理视频任务"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    return 0
  else
    echo "⚠️  检测到 ${health_issues} 个系统健康问题:"
    for msg in "${warning_messages[@]}"; do
      echo "   • $msg"
    done
    echo
    echo "🚨 建议：机器可能无法高效处理更多视频加工任务"
    echo "   您可以："
    echo "   1. 等待当前任务完成后再运行"
    echo "   2. 减少并行任务数（-j 参数）"
    echo "   3. 关闭其他占用资源的应用程序"
    echo "   4. 清理磁盘空间（如果磁盘空间不足）"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # 询问用户是否继续
    read -p "⚠️  是否仍要继续处理？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "✅ 用户选择继续处理"
      echo
      return 0
    else
      echo "🛑 用户选择停止，退出脚本"
      echo
      exit 0
    fi
  fi
}

# set -e  # 注释掉以防止脚本因单个命令失败而退出

# 默认参数
RECURSIVE=false
MAX_DEPTH=0
FILE_DEPTH=1  # 文件扫描深度，默认1（仅当前目录）
TARGET_DIR="."
SHOW_HIDDEN=false
HIDE_EMPTY=false  # 是否隐藏空目录（默认显示所有目录）
SOURCE_DIR=""
SET_ICON_MODE=false
REMOVE_ICON_MODE=false
FORCE_REFRESH_ICON=false
OCR_RENAME_MODE=false
OCR_TARGET=""
OCR_ROOT_DIR=""  # OCR模式下的根目录，用于创建“未成功分类”目录
CHECK_VIDEO_MODE=false  # 视频完整性检测模式
CHECK_VIDEO_TARGET=""
CHECK_VIDEO_ROOT_DIR=""  # 视频检测模式下的根目录
CHECK_SINGLE_FILE=""  # 单个文件检测模式（并行用）
PARALLEL_MODE=false  # 并行处理模式
PARALLEL_JOBS=4  # 并行任务数，默认4个
CLEAN_MODE=false  # 清空文件模式
CLEAN_TARGET=""
FORCE_AUTO_SELECT=false  # OCR模式下自动选择第一个结果，不进行交互
FORCE_RENAME=false  # OCR模式下强制重新识别已有名字的文件
TAG_CLASSIFY_MODE=false  # 基于标签的智能分类模式
CREATE_SYMLINK_VIEW=false  # 是否创建 DY-分类浏览 符号链接视图
COMPRESS_MODE=false  # 视频压缩模式
COMPRESS_TYPE=""  # 压缩类型：quality/4k/1080p/720p/cut
COMPRESS_START=""  # 截取开始时间
COMPRESS_END=""  # 截取结束时间
COMPRESS_DURATION=""  # 截取持续时长
COMPRESS_OUTPUT=""  # 输出文件路径
COMPRESS_TARGET_DIR=""  # 压缩后移动到的目标目录
COMPRESS_TARGET_FORMAT=""  # 目标格式（如mp4/mov/mkv等）
COMPRESS_SEARCH_DIR=""  # 递归模式下的搜索起始目录（默认当前目录）
CROP_MODE=false  # 视频裁剪模式
CROP_INPUT=""  # 输入文件
CROP_WIDTH=""  # 裁剪宽度
CROP_HEIGHT=""  # 裁剪高度
CROP_X="0"  # X坐标
CROP_Y="0"  # Y坐标
CROP_OUTPUT=""  # 输出文件
CROP_PRESET=""  # 快捷预设
TRIM_MODE=false  # 视频有效部分截取模式
TRIM_INPUT=""  # 输入文件（可以是单个文件或目录）
TRIM_OUTPUT=""  # 输出文件（可选）
TRIM_REENCODE=false  # 是否重新编码（解决时间戳问题）
TRIM_DURATION_MODE=false  # 简化的时长截取模式
TRIM_DURATION=""  # 要截取的时长
TRIM_DURATION_INPUT=""  # 输入文件
TRIM_DURATION_OUTPUT=""  # 输出文件
SPLIT_MODE=false  # 按1小时切分模式
SPLIT_INPUTS=()   # 输入文件列表
SPLIT_DIR=""      # 扫描目录
FIX_TIMESTAMP_MODE=false  # 修复视频时间戳模式
FIX_TIMESTAMP_INPUT=""    # 输入文件或目录
FORCE_OVERWRITE=false  # 是否强制覆盖已存在的文件

# 显示 compress 模式的详细帮助
show_compress_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎬 视频压缩/转码/截取 (-compress) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 [-r|-d <层数>] -compress <pattern> <type> [options]
  $0 -compress <input1> [input2 ...] <type> [options]

参数说明:
  输入文件: 
    • 非递归模式: 支持1-10个视频文件，支持通配符
      - 具体文件名: video1.mp4 video2.mov
      - 通配符匹配: *.MP4 (当前目录)
    • 递归模式 (-r 或 -d): 支持通配符模式，递归查找所有匹配文件
      - 使用 -r 递归所有层级
      - 使用 -d <数字> 指定递归层数
      - 可在通配符后指定搜索目录（默认当前目录）

  压缩类型:
    quality     保清晰压体积 (使用HEVC/H.265编码，CRF=28)
    4k          缩放到4K分辨率 (3840x2160)
    2k/1440p    缩放到2K分辨率 (2560x1440)
    1080p       缩放到1080p (1920x1080)
    720p        缩放到720p (1280x720)
    cut         截取视频片段 (需配合 -ss/-to/-t)

  通用选项:
    -r           递归处理所有层级
    -d <层数>   指定递归层数
    -o <output>  指定输出文件 (仅单文件时有效)
    <format>     目标格式 (如mp4/mov/mkv等，可选)
    <target_dir> 压缩后移动到的目标目录 (可选，放在最后)

  cut 模式专用选项:
    -ss <时间>   起始时间 (格式: 00:01:23 或 83)
    -to <时间>   结束时间
    -t  <时长>   持续时长

示例:
  # 单文件压缩
  $0 -compress input.mp4 quality
  $0 -compress input.mp4 quality -o output.mp4
  $0 -compress input.mp4 1080p

  # 批量压缩（当前目录）
  $0 -compress video1.mp4 video2.mp4 video3.mp4 quality
  $0 -compress *.mp4 1080p
  $0 -compress *.MP4 4k

  # 递归压缩（所有层级）
  $0 -r -compress '*.MP4' 4k
  $0 -r -compress '*.mp4' quality

  # 递归压缩（指定层数）
  $0 -d 2 -compress '*.MP4' 4k
  $0 -d 3 -compress '*.mp4' 1080p

  # 递归压缩（指定搜索目录）
  $0 -r -compress '*.MP4' /path/to/search 4k
  $0 -d 2 -compress '*.mp4' /path/to/search quality

  # 压缩后移动到指定目录
  $0 -r -compress '*.MP4' 4k /path/to/target
  $0 -d 2 -compress '*.mp4' quality ~/Videos/compressed

  # 视频截取
  $0 -compress input.mp4 cut -ss 00:01:30 -t 00:05:00
  $0 -compress input.mp4 cut -ss 90 -to 390

  # 转换格式
  $0 -compress input.mov 4k mp4
  $0 -compress input.mp4 quality mov
  $0 -r -compress '*.mov' 1080p mp4

注意事项:
  • 需要安装 ffmpeg: brew install ffmpeg
  • 非递归模式最多支持10个文件
  • 递归模式会处理所有匹配的文件（无数量限制）
  • 批量处理时自动命名，不支持 -o 参数
  • 缩放保持宽高比，不会变形
  • 自动检测并移除视频末尾的"直播已结束"画面
EOF
  exit 0
}

# 显示 trim 模式的详细帮助
show_trim_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━
✂️  视频有效部分截取 (-trim) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 -trim <input> [-o <output>] [--reencode]
  $0 [-r] -trim <directory> [--reencode]

参数说明:
  <input>       输入视频文件或目录
  -o <output>   指定输出文件（可选，默认自动命名）
  -r            递归处理目录中的所有视频
  --reencode    重新编码视频（慢但精确，解决时间戳问题）

功能说明:
  • 自动检测视频末尾的"直播已结束"画面
  • 使用优化的二分搜索算法，快速定位分界点
  • 自动截取有效内容，去除结束画面
  
  两种处理模式:
  1. 快速模式（默认）:
     - 无损复制，不重新编码，速度极快（几秒钟）
     - 适用于大多数视频
     - 可能因视频时间戳损坏导致截取不准确
  
  2. 重编码模式（--reencode）:
     - 重新编码视频，修复时间戳问题，确保精确截取
     - 使用H.265编码，高质量（CRF=23），大幅压缩文件
     - 处理较慢（173分钟视频约需1-2小时）
     - 适用于直播录屏等时间戳可能损坏的视频

示例:
  # 处理单个视频（快速模式）
  $0 -trim video.MP4
  $0 -trim video.MP4 -o video_clean.MP4

  # 处理单个视频（重编码模式）
  $0 -trim video.MP4 --reencode
  $0 -trim video.MP4 -o video_clean.MP4 --reencode

  # 处理目录中的所有视频
  $0 -trim /path/to/videos
  $0 -trim /path/to/videos --reencode
  
  # 递归处理
  $0 -r -trim /path/to/videos
  $0 -r -trim /path/to/videos --reencode

注意事项:
  • 需要安装 ffmpeg: brew install ffmpeg
  • 需要安装 tesseract: brew install tesseract tesseract-lang
  • 如果未检测到"直播已结束"画面，将保留原视频
  • 快速模式输出文件默认命名为: 原文件名_trimmed.格式
  • 重编码模式输出文件默认命名为: 原文件名_trimmed_reenc.mp4
  • 重编码模式会大幅减小文件体积（通常减少60-80%）
EOF
  exit 0
}

# 显示 crop 模式的详细帮助
show_crop_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━
✂️  视频画面裁剪 (-crop) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 -crop <input> [options]

参数说明:
  <input>      输入视频文件

  手动指定裁剪区域:
    -w <宽度>    裁剪区域的宽度 (像素)
    -h <高度>    裁剪区域的高度 (像素)
    -x <X坐标>   裁剪起始X坐标 (默认0，左上角)
    -y <Y坐标>   裁剪起始Y坐标 (默认0，左上角)
    -o <output>  指定输出文件

  快捷预设 (--preset):
    bottom-square   下半部分正方形
    top-square      上半部分正方形
    center-square   居中正方形
    left-half       左半部分
    right-half      右半部分

示例:
  # 使用预设
  $0 -crop input.mp4 --preset bottom-square
  $0 -crop input.mp4 --preset center-square

  # 手动指定裁剪区域
  $0 -crop input.mp4 -w 1080 -h 1080 -x 100 -y 200
  $0 -crop input.mp4 -w 1920 -h 1080 -x 0 -y 0 -o output.mp4

  # 裁剪左半部分
  $0 -crop input.mp4 --preset left-half -o left.mp4

注意事项:
  • 需要安装 ffmpeg: brew install ffmpeg
  • 裁剪区域不能超出视频范围
  • 使用高质量参数 (CRF=18) 保持清晰度
EOF
  exit 0
}

# 显示 ocr 模式的详细帮助
show_ocr_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 视频OCR识别重命名 (-ocr) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 [-r] -ocr [path] [options]

参数说明:
  [path]       可选，指定目录或单个文件
               • 不指定则处理当前目录
               • 可指定目录: /path/to/dir
               • 可指定文件: /path/to/video.mp4

  选项:
    -r           递归处理所有子目录
    --force      自动选择第一个识别结果，跳过交互
    --force-rename  强制重新识别已有名字的文件

功能说明:
  • 自动识别视频中的用户名文字
  • 从视频前1秒提取多帧进行OCR识别
  • 支持交互式选择识别结果
  • 未识别成功的文件移至"未成功分类"目录
  • 自动识别分片视频（_part_00/_part_01等），仅OCR首个分片，自动重命名所有分片

示例:
  # 处理当前目录
  $0 -ocr

  # 递归处理所有子目录
  $0 -r -ocr /path

  # 只处理指定文件
  $0 -ocr /path/video.mp4

  # 自动模式（不需要交互选择）
  $0 -ocr --force /path

  # 强制重新识别已有名字的文件
  $0 -ocr --force-rename /path

  # 递归处理特定DY-目录
  $0 -ocr /path/DY-user /bigpath

注意事项:
  • 需要安装: ffmpeg, python3, easyocr
  • OCR 逻辑已嵌入脚本中（不再依赖外部脚本）
  • 识别用户名通常在视频前1秒显示
  • 可使用方向键选择识别结果
EOF
  exit 0
}

# 显示 check 模式的详细帮助
show_check_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 视频完整性检测 (-check) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 [-r] -check [path] [-j <数量>]

参数说明:
  [path]       可选，指定目录
               不指定则处理当前目录

  选项:
    -r           递归处理所有子目录
    -j <数量>    并行处理，指定线程数 (默认4)

功能说明:
  • 检测视频是否提前结束
  • 检测"直播已结束"画面 (动态加速采样)
  • 检测画面静止或黑屏
  • 问题视频自动标记或移至"待优化视频"目录

检测机制:
  1. "直播已结束"检测:
     - 从末尾向前动态采样
     - 支持OCR文字识别或亮度检测
     - 占比超过20%时标记文件

  2. 画面静止检测:
     - 每10分钟采样一次
     - 比较帧之间的差异
     - 检测到静止后移至待优化目录

示例:
  # 检测当前目录
  $0 -check

  # 递归检测所有子目录
  $0 -r -check /path

  # 并行检测 (8线程)
  $0 -r -check -j 8 /path

注意事项:
  • 需要安装 ffmpeg
  • 建议安装 tesseract (OCR识别)
  • 建议安装 imagemagick (图像对比)
  • 并行处理可提升速度但占用更多资源
EOF
  exit 0
}

# 显示 tag 模式的详细帮助
show_tag_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏷️  基于标签的智能分类 (-tag) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 -tag [source_dir] [target_dir] [-link]

参数说明:
  [source_dir]  源目录 (包含待分类视频)
  [target_dir]  目标目录 (包含【】分类文件夹)
                不指定则默认使用当前目录

  选项:
    -link        创建"DY-分类浏览"符号链接视图
                 (不指定则跳过，节省时间)

功能说明:
  • 根据视频的Finder标签自动分类
  • 匹配目标目录中的【】文件夹
  • 自动创建或使用DY-子目录
  • 可选创建符号链接视图方便浏览

工作流程:
  1. 读取源视频的Finder标签
  2. 在目标目录查找匹配标签的【】文件夹
  3. 提取视频文件名中的关键词
  4. 移动到对应的 DY-关键词 子目录
  5. (可选) 创建按标签分类的符号链接视图

示例:
  # 基本分类
  $0 -tag /source /target

  # 使用当前目录
  $0 -tag

  # 分类并创建符号链接视图
  $0 -tag /source /target -link

  # 分类后更新目录大小
  $0 -tag /source /target
  $0 -r /target

注意事项:
  • 需要在macOS系统上运行 (使用mdls命令)
  • 视频需要有Finder标签
  • 目标目录需要有【】格式的文件夹
  • 文件名格式: 关键词-文件名.mp4
  • 创建符号链接视图会占用一些时间
EOF
  exit 0
}

# 显示 icon 模式的详细帮助
show_icon_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🖼️  文件夹图标设置 (-icon/-rmicon) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 [-r] -icon [path] [-force]
  $0 [-r] -rmicon [path]

参数说明:
  [path]       目标目录路径

  -icon 选项:
    -r           递归处理所有子目录
    -force       强制刷新已有图标

  -rmicon 选项:
    -r           递归移除所有子目录的图标

功能说明:
  -icon:  为DY-开头的文件夹设置视频截图作为图标
  -rmicon: 移除文件夹的自定义图标

示例:
  # 为指定路径的DY-文件夹设置图标
  $0 -icon /path

  # 递归为所有DY-文件夹设置图标
  $0 -r -icon /path

  # 强制刷新已有图标
  $0 -icon -force /path

  # 移除指定路径的文件夹图标
  $0 -rmicon /path

  # 递归移除所有文件夹图标
  $0 -r -rmicon /path

注意事项:
  • 需要安装: ffmpeg, fileicon
  • 安装命令: brew install ffmpeg fileicon
  • 提取视频第1秒帧作为图标
  • 生成512x512的图标文件
  • 默认跳过已有图标的文件夹
EOF
  exit 0
}

# 显示 clean 模式的详细帮助
show_clean_help() {
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  清空目录文件 (-clean) 详细帮助
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

用法:
  $0 [-r] -clean [path]

参数说明:
  [path]       可选，指定要清空的目录
               不指定则处理整个目标目录

  选项:
    -r           递归清空所有子目录

功能说明:
  • 删除指定目录下的所有文件
  • 保留目录结构不变
  • 自动重新计算并更新目录大小标签
  • 显示删除的文件数量和释放的空间

示例:
  # 清空指定目录
  $0 -clean /path/to/dir

  # 递归清空所有子目录
  $0 -r -clean /path

  # 清空整个目标目录
  $0 -clean

警告:
  ⚠️  此操作会永久删除文件，无法恢复！
  ⚠️  请确认目录路径正确后再执行
  ⚠️  建议先备份重要文件
EOF
  exit 0
}

# 显示帮助信息
show_help() {
  cat << EOF
用法: $0 [选项] [目录路径]

选项：
  -r          递归处理所有子目录，包括：
               • 自动移动视频文件到对应的 DY- 目录
               • 合并同名文件夹（忽略大小标签）
               • 更新所有层级的文件夹大小标签
               • 处理空目录的显示/隐藏
               注：一级目录只处理【】包围的目录
  -d <层数>   指定递归层数（默认0不递归）
  --file-depth <层数>  指定文件扫描深度（默认1，仅当前目录）
                        例如：2表示扫描当前目录+子目录，3表示扫描到孙目录
  -s          显示所有隐藏的目录（取消隐藏）
  -S          显示所有目录（包括空目录，默认行为）
  -H          隐藏空目录
  -path <源目录>  指定源目录，从中提取视频文件并匹配到目标目录的【】文件夹
  -tag        基于标签的智能分类：根据源视频的Finder标签自动移动到目标目录
               需要安装tag工具：brew install tag
  -link       创建"DY-分类浏览"符号链接视图（与-tag一起使用）
               如果不指定此参数，将跳过创建符号链接视图以节省时间
  -icon       为DY-开头的文件夹设置视频截图作为图标（需要ffmpeg）
  -force      强制刷新已有的图标（与-icon一起使用）
  -rmicon     移除文件夹的自定义图标
  -clean      递归清空指定目录下的所有文件（保留目录结构），并重新计算目录大小
               可选指定单个目录路径，不指定则处理整个目标目录
  -j <数量>   并行处理模式，指定并行任务数（默认4个）
               例如：-j 8 表示同时8个视频并行检测
  --force     OCR模式下自动选择第一个结果，跳过交互式选择
  --force-rename  OCR模式下强制重新识别已有名字的文件
  -compress <input1> [input2 ...] <type> [options] [format] [target_dir]  视频压缩/转码/截取
               支持批量处理视频文件，支持通配符匹配和递归查找
               输入格式：
                 • 非递归模式: 具体文件名或通配符 (最多10个)
                 • 递归模式 (-r/-d): 通配符模式，递归查找所有匹配文件
               type 可选：
                 quality     保清晰压体积（HEVC/H.265）
                 4k | 2k | 1080p | 720p  指定分辨率缩放
                 cut         截取片段（支持 -ss/-to/-t）
               通用选项：
                 -r          递归处理所有层级
                 -d <层数>  指定递归层数
                 -o <output> 指定输出文件（仅单文件时有效）
                 <format>    目标格式（如mp4/mov/mkv等，可选）
                 <target_dir> 压缩后移动到的目标目录（可选，放在最后）
               cut 选项：
                 -ss <起始>  例如 00:01:23 或 83
                 -to <结束>  结束时间
                 -t  <时长>  持续时长
  -crop <input> [options]  视频画面截取（裁剪特定区域）
               选项：
                 -w <宽度>   截取区域宽度（像素）
                 -h <高度>   截取区域高度（像素）
                 -x <X坐标>  截取起始X坐标（默认0，左上角）
                 -y <Y坐标>  截取起始Y坐标（默认0，左上角）
                 -o <output> 指定输出文件
                 --preset <name>  快捷预设：
                   bottom-square  下半部分正方形
                   top-square     上半部分正方形
                   center-square  居中正方形
                   left-half      左半部分
                   right-half     右半部分
  -split1h <pattern> [dir]  按1小时切分视频
               说明：
                 自动扫描并分割超过1.5小时的视频
                 快速无损拆分，每小时一个文件
                 输出格式：原文件名_part_00.扩展名
               参数：
                 <pattern>  文件匹配模式（支持通配符，如 IMG_*.MP4）
                 [dir]      可选，扫描目录（默认当前目录）
               示例：
                 $0 -split1h IMG_*.MP4 .        # 扫描当前目录
                 $0 -split1h '*.MP4' /path      # 扫描指定目录
                 $0 -split1h video.mp4          # 处理单个文件
  -fix-timestamp <input>  修复视频时间戳
               说明：
                 重置视频的start_time为0
                 支持单个文件或整个目录（配合-r递归）
                 自动跳过已修复的文件
                 输出格式：原文件名_fixed.扩展名
  -cut <input> <duration> [output]  截取指定时长的视频（从开头）
               参数：
                 <input>     输入视频文件
                 <duration>  时长（秒或格式：1m30s、90s、01:30）
                 [output]    可选输出文件名
               示例：
                 $0 -cut video.mp4 30       # 截取前30秒
                 $0 -cut video.mp4 1m30s    # 截取前1分30秒
                 $0 -cut video.mp4 90 out.mp4  # 截取前90秒，输出为out.mp4
  -h, --help  显示此帮助信息

示例：
  $0 /path                  # 只处理一级子文件夹，扫描当前目录文件
  $0 -r /path               # 递归处理所有层级，扫描当前目录文件
  $0 -d 3 /path             # 递归处理３层
  $0 --file-depth 2 /path   # 扫描当前目录+子目录的文件
  $0 --file-depth 3 /path   # 扫描到孙目录的文件
  $0 -r --file-depth 2 /path  # 递归处理目录，每个目录扫描2层文件
  $0 -s /path               # 显示所有隐藏的目录
  $0 -H /path               # 隐藏空目录（默认显示所有）
  $0 -S /path               # 显示所有目录（包括空目录，默认行为）
  $0 -r -s /path            # 递归处理并显示所有隐藏目录
  $0 -path /source /target  # 从源目录提取视频文件并放到目标目录的【】文件夹中
  $0 -tag /source /target   # 根据源视频的标签自动分类到目标目录
  $0 -tag -link /source /target  # 分类并创建DY-分类浏览符号链接视图
  $0 -icon /path            # 为指定路径下的DY-文件夹设置视频截图图标
  $0 -r -icon /path         # 递归为所有DY-文件夹设置视频截图图标
  $0 -icon -force /path     # 强制刷新已有图标的DY-文件夹
  $0 -rmicon /path          # 移除指定路径下文件夹的自定义图标
  $0 -r -rmicon /path       # 递归移除所有文件夹的自定义图标
  $0 -ocr /path                    # 识别目录中所有视频的文字并重命名
  $0 -r -ocr /path                 # 递归识别并重命名所有视频文件
  $0 -ocr /path/video.mp4          # 只识别指定的单个视频文件
  $0 -ocr /path/DY-user /bigpath   # 只识别/bigpath下的/path/DY-user目录
  $0 -clean /path                  # 清空指定目录下的所有文件，保留目录结构并更新大小
  $0 -r -clean /path               # 递归清空所有子目录的文件
  $0 -ocr --force /path            # OCR识别并自动选择第一个结果，不进行交互
  $0 -ocr --force-rename /path     # 强制重新识别已有名字的文件
  $0 -r -check -j 8 /path          # 并行检测视频（8个线程）
  $0 -compress input.mp4 quality -o output.mp4
  $0 -compress input.mp4 2k
  $0 -compress input.mp4 1080p
  $0 -compress input.mp4 cut -ss 00:01:30 -t 00:05:00
  $0 -compress video1.mp4 video2.mp4 video3.mp4 quality
  $0 -compress '*.mp4' 1080p                    # 匹配当前目录.mp4文件
  $0 -compress '*.MP4' 4k                       # 匹配当前目录.MP4文件
  $0 -r -compress '*.MP4' 4k                    # 递归处理所有层级的.MP4文件
  $0 -d 2 -compress '*.MP4' 4k                  # 递归处理2层的.MP4文件
  $0 -compress 1.mov 4k mp4                     # 将mov转换为4k的mp4
  $0 -r -compress '*.mov' 1080p mp4             # 递归将mov转为1080p mp4
  $0 -r -compress '*.MP4' 4k mp4 /path/to/target    # 递归压缩并移动到指定目录
  $0 -crop input.mp4 --preset bottom-square
  $0 -crop input.mp4 -w 1080 -h 1080 -x 100 -y 200 -o output.mp4
  $0 -split1h IMG_*.MP4 .                  # 扫描当前目录中超过1.5h的视频
  $0 -split1h '*.MP4' /path                # 扫描指定目录
  $0 -split1h video.mp4                    # 处理单个文件
  $0 -fix-timestamp video.mp4              # 修复单个视频时间戳
  $0 -r -fix-timestamp /path               # 递归修复目录中所有视频的时间戳

功能说明：
  1. 自动移动视频文件到对应的 DY- 目录
  2. 合并同名文件夹（忽略大小标签）
  3. 更新文件夹大小标签
  4. 隐藏空目录 / 显示非空目录（使用-s取消所有隐藏）

注意：
  - 对于一级目录，只处理【】包围的目录
  - 其他名称的一级目录将被跳过
  - 子目录（第2层及以下）不受此限制
  - 默认显示所有目录，使用-H参数可以隐藏空目录
  - 使用-s参数可以显示所有被隐藏的目录
EOF
  exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-single)
      # 内部参数：用于并行处理单个文件
      CHECK_VIDEO_MODE=true
      CHECK_SINGLE_FILE="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    -r)
      RECURSIVE=true
      MAX_DEPTH=999  # 表示无限递归
      shift
      ;;
    -s)
      SHOW_HIDDEN=true
      shift
      ;;
    -S)
      HIDE_EMPTY=false  # 显式设置为显示所有目录（默认行为）
      shift
      ;;
    -H)
      HIDE_EMPTY=true  # 隐藏空目录
      shift
      ;;
    -icon)
      SET_ICON_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_icon_help
      fi
      shift
      ;;
    -force)
      FORCE_REFRESH_ICON=true
      shift
      ;;
    -rmicon)
      REMOVE_ICON_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_icon_help
      fi
      shift
      ;;
    -ocr)
      OCR_RENAME_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_ocr_help
      fi
      # 检查下一个参数是否是路径（不是以-开头）
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        OCR_TARGET="$2"
        shift 2
      else
        shift
      fi
      ;;
    -check)
      CHECK_VIDEO_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_check_help
      fi
      # 检查下一个参数是否是路径（不是以-开头）
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        CHECK_VIDEO_TARGET="$2"
        shift 2
      else
        shift
      fi
      ;;
    -clean)
      CLEAN_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_clean_help
      fi
      # 检查下一个参数是否是路径（不是以-开头）
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        CLEAN_TARGET="$2"
        shift 2
      else
        shift
      fi
      ;;
    --force)
      FORCE_AUTO_SELECT=true
      shift
      ;;
    --force-rename)
      FORCE_RENAME=true
      shift
      ;;
    -j)
      PARALLEL_MODE=true
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        PARALLEL_JOBS="$2"
        shift 2
      else
        # 默认4个并行任务
        shift
      fi
      ;;
    -link)
      CREATE_SYMLINK_VIEW=true
      shift
      ;;
    -tag)
      TAG_CLASSIFY_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_tag_help
      fi
      # 检查是否提供了两个路径参数
      if [[ -n "$2" && ! "$2" =~ ^- ]] && [[ -n "$3" && ! "$3" =~ ^- ]]; then
        # 提供了两个参数：源目录和目标目录
        if [ -d "$2" ] && [ -d "$3" ]; then
          SOURCE_DIR="$2"
          TARGET_DIR="$3"
          shift 3
        else
          echo "错误: -tag 参数需要两个有效的目录路径"
          echo "使用 '$0 --help' 查看帮助信息"
          exit 1
        fi
      else
        # 没有提供参数或参数不足，默认源和目标都是当前目录
        SOURCE_DIR="."
        TARGET_DIR="."
        shift
      fi
      ;;
    -path)
      if [[ -n "$2" && -d "$2" ]]; then
        SOURCE_DIR="$2"
        shift 2
      else
        echo "错误: -path 参数需要一个有效的目录路径"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      ;;
    -d)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        MAX_DEPTH="$2"
        if [ "$MAX_DEPTH" -gt 0 ]; then
          RECURSIVE=true
        fi
        shift 2
      else
        echo "错误: -d 参数需要一个数字"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      ;;
    --file-depth)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        FILE_DEPTH="$2"
        shift 2
      else
        echo "错误: --file-depth 参数需要一个数字"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      ;;
    -compress)
      COMPRESS_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_compress_help
      fi
      # 收集输入文件（最多10个），支持通配符模糊匹配
      COMPRESS_INPUTS=()
      COMPRESS_PATTERN=""  # 用于存储通配符模式（递归模式）
      shift
      
      # 收集所有输入参数（通配符和文件名）
      reached_limit=false
      while [[ $# -gt 0 ]]; do
        param="$1"
        
        # 检查是否为压缩类型参数
        if [[ "$param" =~ ^(quality|4k|2k|1440p|1080p|720p|cut)$ ]]; then
          # 这是压缩类型，停止收集文件
          break
        fi
        
        # 检查是否为选项参数
        if [[ "$param" =~ ^- ]]; then
          # 这是选项参数，停止收集文件
          break
        fi
        
        # 如果是递归模式，保存通配符模式供后续使用
        if [ "$RECURSIVE" = true ]; then
          COMPRESS_PATTERN="$param"
          shift
          # 检查下一个参数是否是搜索目录（不是压缩类型和选项参数）
          if [[ -n "$1" && ! "$1" =~ ^(quality|4k|2k|1440p|1080p|720p|cut)$ && ! "$1" =~ ^- && -d "$1" ]]; then
            COMPRESS_SEARCH_DIR="$1"
            shift
          fi
          break
        fi
        
        # 非递归模式：尝试匹配文件（支持通配符）
        matched_files=()
        if [[ "$param" == *"*"* ]] || [[ "$param" == *"?"* ]]; then
          # 包含通配符，使用shell glob匹配
          shopt -s nullglob
          # 使用while循环遍历匹配的文件，正确处理空格
          while IFS= read -r -d '' file; do
            matched_files+=("$file")
          done < <(compgen -G "$param" | tr '\n' '\0')
          shopt -u nullglob
          
          if [ ${#matched_files[@]} -eq 0 ]; then
            echo "⚠️  警告: 通配符 '$param' 未匹配到任何文件，跳过"
            shift
            continue
          fi
        elif [ -f "$param" ]; then
          # 直接指定的文件
          matched_files=("$param")
        else
          # 文件不存在，给出错误提示
          echo "❌ 错误: 文件不存在: $param"
          exit 1
        fi
        
        # 添加匹配到的文件
        for file in "${matched_files[@]}"; do
          # 检查是否已达到10个文件的限制
          if [ ${#COMPRESS_INPUTS[@]} -ge 10 ]; then
            echo "⚠️  警告: 已达到10个文件上限（${#COMPRESS_INPUTS[@]}/10），忽略其余文件"
            reached_limit=true
            break
          fi
          COMPRESS_INPUTS+=("$file")
        done
        
        # 如果达到上限，需要继续消耗剩余的文件参数，直到遇到类型参数
        if [ "$reached_limit" = true ]; then
          shift
          # 跳过剩余的文件参数，直到找到类型参数或选项
          while [[ $# -gt 0 ]]; do
            if [[ "$1" =~ ^(quality|4k|2k|1440p|1080p|720p|cut)$ ]] || [[ "$1" =~ ^- ]]; then
              # 找到类型参数或选项，停止跳过
              break
            fi
            shift
          done
          break
        fi
        
        shift
      done
      
      # 递归模式：使用find命令查找文件
      if [ "$RECURSIVE" = true ] && [ -n "$COMPRESS_PATTERN" ]; then
        # 确定查找深度
        find_depth_opts=()
        if [ "$MAX_DEPTH" -ne 999 ]; then
          find_depth_opts=(-maxdepth "$MAX_DEPTH")
        fi
        
        # 确定搜索起始目录（默认当前目录）
        compress_search_root="${COMPRESS_SEARCH_DIR:-.}"
        
        echo "🔍 递归查找匹配 '$COMPRESS_PATTERN' 的视频文件（目录: $compress_search_root）..."
        
        # 使用find查找匹配的文件
        while IFS= read -r -d $'\0' file; do
          COMPRESS_INPUTS+=("$file")
        done < <(find "$compress_search_root" "${find_depth_opts[@]}" -type f -name "$COMPRESS_PATTERN" -print0 2>/dev/null)
        
        if [ ${#COMPRESS_INPUTS[@]} -eq 0 ]; then
          echo "❌ 错误: 未找到匹配 '$COMPRESS_PATTERN' 的文件"
          exit 1
        fi
        
        echo "✅ 找到 ${#COMPRESS_INPUTS[@]} 个文件"
      fi
      
      # 检查是否至少有一个输入文件
      if [ ${#COMPRESS_INPUTS[@]} -eq 0 ]; then
        echo "错误: -compress 需要指定至少一个输入文件"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      
      # 保持输入文件数组，不转换为字符串
      
      # 第二个参数：压缩类型
      if [[ -z "$1" || "$1" =~ ^- && "$1" != "-o" && "$1" != "-ss" && "$1" != "-to" && "$1" != "-t" ]]; then
        echo "错误: -compress 需要指定压缩类型（quality/4k/2k/1080p/720p/cut）"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      COMPRESS_TYPE="$1"
      shift
      # 解析附加参数
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -o)
            COMPRESS_OUTPUT="$2"; shift 2 ;;
          -ss)
            COMPRESS_START="$2"; shift 2 ;;
          -to)
            COMPRESS_END="$2"; shift 2 ;;
          -t)
            COMPRESS_DURATION="$2"; shift 2 ;;
          *)
            # 检查剩余参数：可能是目标格式或目标目录
            if [[ -n "$1" && ! "$1" =~ ^- ]]; then
              # 如果是目录，作为目标目录
              if [ -d "$1" ]; then
                COMPRESS_TARGET_DIR="$1"
                shift
              # 如果是常见视频格式（3-4个字母），作为目标格式
              elif [[ "$1" =~ ^[a-zA-Z0-9]{2,4}$ ]]; then
                COMPRESS_TARGET_FORMAT="$1"
                shift
                # 检查下一个参数是否为目录
                if [[ -n "$1" && ! "$1" =~ ^- && -d "$1" ]]; then
                  COMPRESS_TARGET_DIR="$1"
                  shift
                fi
              else
                shift
              fi
            fi
            break ;;
        esac
      done
      # 压缩模式直接结束参数解析
      break
      ;;
    -trim)
      TRIM_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_trim_help
      fi
      # 第一个参数：输入文件或目录
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        TRIM_INPUT="$2"
        shift 2
      else
        # 如果没有指定输入，默认为当前目录
        TRIM_INPUT="."
        shift
      fi
      
      # 解析trim选项
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -o)
            TRIM_OUTPUT="$2"; shift 2 ;;
          --reencode)
            TRIM_REENCODE=true; shift ;;
          *)
            break ;;
        esac
      done
      # trim模式直接结束参数解析
      break
      ;;
    -crop)
      CROP_MODE=true
      # 检查下一个参数是否为 -h
      if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        show_crop_help
      fi
      # 第一个参数：输入文件
      if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo "错误: -crop 需要指定输入文件"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
      fi
      CROP_INPUT="$2"
      shift 2
      
      # 解析crop选项
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -w)
            CROP_WIDTH="$2"; shift 2 ;;
          -h)
            CROP_HEIGHT="$2"; shift 2 ;;
          -x)
            CROP_X="$2"; shift 2 ;;
          -y)
            CROP_Y="$2"; shift 2 ;;
          -o)
            CROP_OUTPUT="$2"; shift 2 ;;
          --preset)
            CROP_PRESET="$2"; shift 2 ;;
          *)
            break ;;
        esac
      done
      # 裁剪模式直接结束参数解析
      break
      ;;
    -cut)
      TRIM_DURATION_MODE=true
      # 第一个参数：输入文件
      if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo "错误: -cut 需要指定输入文件"
        echo "使用方法: $0 -cut <视频文件> <时长> [输出文件]"
        echo "示例: $0 -cut video.mp4 30"
        exit 1
      fi
      TRIM_DURATION_INPUT="$2"
      
      # 第二个参数：时长
      if [[ -z "$3" || "$3" =~ ^- ]]; then
        echo "错误: -cut 需要指定时长"
        echo "使用方法: $0 -cut <视频文件> <时长> [输出文件]"
        echo "示例: $0 -cut video.mp4 30"
        exit 1
      fi
      TRIM_DURATION="$3"
      shift 3
      
      # 第三个参数（可选）：输出文件
      if [[ -n "$1" && ! "$1" =~ ^- ]]; then
        TRIM_DURATION_OUTPUT="$1"
        shift
      fi
      
      # 结束参数解析
      break
      ;;
    -split1h)
      SPLIT_MODE=true
      # 支持通配符或目录扫描
      shift
      SPLIT_INPUTS=()
      
      # 收集输入参数（通配符或具体文件）
      while [[ $# -gt 0 ]]; do
        param="$1"
        
        # 如果是选项参数，停止收集
        if [[ "$param" =~ ^- ]]; then
          break
        fi
        
        # 如果是目录，标记为扫描目录
        if [ -d "$param" ]; then
          SPLIT_DIR="$param"
          shift
          break
        fi
        
        # 尝试匹配文件（支持通配符）
        if [[ "$param" == *"*"* ]] || [[ "$param" == *"?"* ]]; then
          # 包含通配符，使用shell glob匹配
          shopt -s nullglob
          while IFS= read -r -d '' file; do
            SPLIT_INPUTS+=("$file")
          done < <(compgen -G "$param" | tr '\n' '\0')
          shopt -u nullglob
        elif [ -f "$param" ]; then
          # 直接指定的文件
          SPLIT_INPUTS+=("$param")
        fi
        
        shift
      done
      
      # 如果既没有文件也没有目录，使用当前目录
      if [ ${#SPLIT_INPUTS[@]} -eq 0 ] && [ -z "$SPLIT_DIR" ]; then
        SPLIT_DIR="."
      fi
      
      # 结束参数解析
      break
      ;;
    -fix-timestamp)
      FIX_TIMESTAMP_MODE=true
      # 第一个参数：输入文件或目录
      if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo "错误: -fix-timestamp 需要指定输入文件或目录"
        echo "使用方法: $0 -fix-timestamp <视频文件或目录> [-f|--force]"
        echo "示例: $0 -fix-timestamp video.mp4"
        echo "示例: $0 -fix-timestamp video.mp4 --force"
        echo "示例: $0 -r -fix-timestamp /path/to/videos"
        exit 1
      fi
      FIX_TIMESTAMP_INPUT="$2"
      shift 2
      
      # 解析可选参数
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -f|--force)
            FORCE_OVERWRITE=true
            shift
            ;;
          *)
            break
            ;;
        esac
      done
      # 结束参数解析
      break
      ;;
    -*)
      echo "未知选项: $1"
      echo "使用 '$0 --help' 查看帮助信息"
      exit 1
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# Trim模式：截取视频有效部分（自动检测并移除"直播已结束"画面）
if [ "$TRIM_MODE" = true ]; then
  # 检查依赖
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"
    exit 1
  fi
  
  if ! command -v tesseract >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 tesseract（brew install tesseract tesseract-lang）"
    exit 1
  fi
  
  # 定义处理单个视频的函数
  trim_single_video() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ]; then
      echo "❌ 文件不存在: $input_file"
      return 1
    fi
    
    local filename="$(basename "$input_file")"
    local dirname="$(dirname "$input_file")"
    local basename_no_ext="${filename%.*}"
    local extension="${filename##*.}"
    
    # 如果没有指定输出文件，自动命名
    if [ -z "$output_file" ]; then
      if [ "$TRIM_REENCODE" = true ]; then
        output_file="${dirname}/${basename_no_ext}_trimmed_reenc.mp4"
      else
        output_file="${dirname}/${basename_no_ext}_trimmed.${extension}"
      fi
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✂️  截取视频有效部分"
    echo "输入: $filename"
    if [ "$TRIM_REENCODE" = true ]; then
      echo "模式: 🔄 重编码模式（慢但精确）"
    else
      echo "模式: ⚡ 快速模式（无损复制）"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 获取视频时长
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    local duration_int=$(echo "$duration / 1" | bc 2>/dev/null)
    
    if [ -z "$duration_int" ] || [ "$duration_int" -lt 600 ]; then
      echo "⚠️  视频时长少于10分钟，跳过检测"
      return 0
    fi
    
    echo "  时长: $((duration_int/60)) 分钟"
    echo "  🔍 检测'直播已结束'画面..."
    
    # 使用二分查找算法精确定位分界点
    local temp_check_dir="$(mktemp -d)"
    local valid_end_time=""
    
    echo "    🔍 使用二分查找算法定位分界点..."
    
    # 定义检测函数：返回0表示"直播已结束"，返回1表示正常内容
    check_position() {
      local pos=$1
      local check_frame="$temp_check_dir/check_${pos}.jpg"
      
      if ffmpeg -ss "$pos" -i "$input_file" -vframes 1 -q:v 2 "$check_frame" -y &>/dev/null 2>&1; then
        local result=$(tesseract "$check_frame" - -l chi_sim 2>/dev/null | grep -o "直播已结束")
        rm -f "$check_frame"
        
        if [ -n "$result" ]; then
          return 0  # 直播已结束
        else
          return 1  # 正常内容
        fi
      fi
      return 1  # 默认返回正常内容
    }
    
    # 二分查找：在整个视频时长内查找分界点
    local left=0
    local right=$duration_int
    local iteration=0
    
    # 首先检查视频后段是否有"直播已结束"（从80%位置开始检查）
    local has_ended=false
    local check_start=$((duration_int * 4 / 5))  # 80%位置
    
    echo "    验证视频后段 ($((check_start/60))分后) 是否有'直播已结束'..."
    
    # 检查几个点：90%, 85%, 80%
    for ratio in 90 85 80; do
      local pos=$((duration_int * ratio / 100))
      if check_position $pos; then
        echo "      ✓ $ratio%位置 ($((pos/60))分) 有'直播已结束'"
        has_ended=true
        # 调整搜索区间：从视频前半到这个位置
        right=$pos
        break
      fi
    done
    
    if [ "$has_ended" = false ]; then
      echo "    ✓ 视频后段无'直播已结束'画面，无需处理"
      rm -rf "$temp_check_dir"
      return 0
    fi
    
    # 二分查找分界点
    while [ $((right - left)) -gt 5 ]; do
      ((iteration++))
      local mid=$(( (left + right) / 2 ))
      
      echo "    第${iteration}轮: 检测 $((mid/60))分$((mid%60))秒 (区间: $((left/60))分-$((right/60))分)..."
      
      if check_position $mid; then
        # 中点是"直播已结束"，说明分界点在左半部分
        echo "      → 直播已结束，分界点在左侧"
        right=$mid
      else
        # 中点是正常内容，说明分界点在右半部分
        echo "      → 正常内容，分界点在右侧"
        left=$mid
      fi
    done
    
    # 在最后的小区间内精确查找（每秒检查）
    echo "    🎯 最终精确定位 ($((left/60))分-$((right/60))分)..."
    for t in $(seq $right -1 $left); do
      if ! check_position $t; then
        valid_end_time=$t
        echo "      ✓ 找到精确分界点: $((t/60))分$((t%60))秒"
        break
      fi
    done
    
    # 如果没找到，使用left作为分界点
    if [ -z "$valid_end_time" ]; then
      valid_end_time=$left
    fi
    
    rm -rf "$temp_check_dir"
    
    # 在分界点前查找最近的关键帧位置，避免浪费
    echo "    🔑 查找分界点前的最近关键帧..."
    local keyframe_pos=$(ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,flags -of csv=p=0 "$input_file" 2>/dev/null | \
      awk -F',' -v target=$valid_end_time '$2 ~ /K/ && $1 <= target {last=$1} END {print int(last)}')
    
    if [ -n "$keyframe_pos" ] && [ $keyframe_pos -gt 0 ]; then
      local saved_time=$((valid_end_time - keyframe_pos))
      echo "      ✓ 找到关键帧位置: $((keyframe_pos/60))分$((keyframe_pos%60))秒"
      echo "      → 相比原分界点提前了 $((saved_time/60))分$((saved_time%60))秒"
      valid_end_time=$keyframe_pos
    else
      echo "      ⚠️  未找到关键帧信息，使用原分界点"
    fi
    
    # 执行截取
    if [ -n "$valid_end_time" ]; then
      local ended_duration=$((duration_int - valid_end_time))
      local ended_ratio=$(echo "scale=1; $ended_duration * 100 / $duration_int" | bc)
      
      echo "  ✅ 找到分界点: $((valid_end_time/3600))h$((valid_end_time%3600/60))m"
      echo "  🔢 精确值: ${valid_end_time} 秒"
      echo "  ⚠️  '直播已结束'占比: ${ended_ratio}%"
      echo "  ✂️  截取有效部分..."
      
      if [ "$TRIM_REENCODE" = true ]; then
        # 重编码模式：修复时间戳问题，精确截取
        echo "  ↪ 使用重编码模式 (libx265, CRF=23)..."
        echo "  ⏱️  预计处理时间: $((valid_end_time/60))分钟 → 约$((valid_end_time/60/2))-$((valid_end_time/60))分钟"
        echo ""
        
        # 使用进度条显示
        if ffmpeg -i "$input_file" -t $valid_end_time \
          -c:v libx265 -crf 23 -preset medium \
          -c:a copy \
          -movflags +faststart \
          "$output_file" -y 2>&1 | while IFS= read -r line; do
            # 提取时间信息 (macOS 兼容)
            if [[ "$line" =~ time=([0-9:.]+) ]]; then
              time="${BASH_REMATCH[1]}"
              # 将时间转换为秒
              IFS=: read h m s <<< "$time"
              current_sec=$(echo "$h * 3600 + $m * 60 + $s" | bc 2>/dev/null || echo "0")
              if [ -n "$current_sec" ] && [ "$(echo "$current_sec > 0" | bc 2>/dev/null)" = "1" ]; then
                progress=$(echo "scale=1; $current_sec * 100 / $valid_end_time" | bc 2>/dev/null || echo "0")
                printf "\r  进度: %.1f%% (%s / %02d:%02d:%02d)" "$progress" "$time" $((valid_end_time/3600)) $((valid_end_time%3600/60)) $((valid_end_time%60))
              fi
            fi
          done; then
          echo ""
          echo "  ✅ 完成！"
        else
          echo ""
          echo "  ❌ 重编码失败"
          return 1
        fi
      else
        # 快速模式：无损复制
        echo "  ↪ ffmpeg 命令: -ss 0 -t ${valid_end_time} -i ... -c copy ..."
        
        # 使用-ss 0 -t方式进行精确截取，-ss放在-i前面可以快速定位
        # -t也放在-i前面可以更精确地控制输出时长
        if ffmpeg -ss 0 -t $valid_end_time -i "$input_file" -c copy -avoid_negative_ts make_zero -movflags +faststart "$output_file" -y 2>&1 | grep -q "muxing overhead"; then
          echo "  ✅ 完成！"
          
          # 验证输出时长是否正确（快速模式可能有时间戳问题）
          local output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_file" 2>/dev/null)
          local output_duration_int=$(echo "$output_duration / 1" | bc 2>/dev/null)
          local time_diff=$((output_duration_int - valid_end_time))
          
          if [ -n "$output_duration_int" ] && [ $time_diff -gt 60 ]; then
            echo "  ⚠️  警告: 输出时长($((output_duration_int/60))分) 与预期($((valid_end_time/60))分) 相差 $((time_diff/60))分"
            echo "  💡 建议: 视频可能有时间戳问题，建议使用 --reencode 重新处理"
          fi
        else
          echo "  ❌ 截取失败"
          return 1
        fi
      fi
      
      local original_size=$(du -h "$input_file" | awk '{print $1}')
      local output_size=$(du -h "$output_file" | awk '{print $1}')
      echo "  原始: $original_size → 输出: $output_size"
      echo "  输出: $output_file"
      return 0
    else
      echo "  ✅ 未检测到'直播已结束'画面，无需处理"
      return 0
    fi
  }
  
  # 处理输入
  if [ -f "$TRIM_INPUT" ]; then
    # 单个文件
    trim_single_video "$TRIM_INPUT" "$TRIM_OUTPUT"
  elif [ -d "$TRIM_INPUT" ]; then
    # 目录
    echo "📁 处理目录: $TRIM_INPUT"
    echo ""
    
    # 查找视频文件
    local video_files=()
    if [ "$RECURSIVE" = true ]; then
      while IFS= read -r -d '' file; do
        video_files+=("$file")
      done < <(find "$TRIM_INPUT" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) -print0 2>/dev/null)
    else
      while IFS= read -r -d '' file; do
        video_files+=("$file")
      done < <(find "$TRIM_INPUT" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) -print0 2>/dev/null)
    fi
    
    if [ ${#video_files[@]} -eq 0 ]; then
      echo "⚠️  未找到视频文件"
      exit 0
    fi
    
    echo "找到 ${#video_files[@]} 个视频文件"
    echo ""
    
    local success=0
    local skipped=0
    local failed=0
    
    for video_file in "${video_files[@]}"; do
      if trim_single_video "$video_file" ""; then
        ((success++))
      else
        if [ $? -eq 0 ]; then
          ((skipped++))
        else
          ((failed++))
        fi
      fi
      echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 处理完成"
    echo "  成功: $success 个"
    echo "  跳过: $skipped 个"
    echo "  失败: $failed 个"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "❌ 错误: 输入路径不存在: $TRIM_INPUT"
    exit 1
  fi
  
  exit 0
fi

# 裁剪模式：处理视频裁剪
if [ "$CROP_MODE" = true ]; then
  if [ ! -f "$CROP_INPUT" ]; then
    echo "❌ 错误: 输入文件不存在: $CROP_INPUT"
    exit 1
  fi
  
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"
    exit 1
  fi
  
  filename="$(basename "$CROP_INPUT")"
  dirname="$(dirname "$CROP_INPUT")"
  basename_no_ext="${filename%.*}"
  extension="${filename##*.}"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✂️  视频画面裁剪"
  echo "输入: $filename"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # 获取视频分辨率
  video_info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$CROP_INPUT" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ 错误: 无法获取视频信息"
    exit 1
  fi
  
  video_width=$(echo $video_info | cut -d'x' -f1)
  video_height=$(echo $video_info | cut -d'x' -f2)
  
  echo "原始分辨率: ${video_width}x${video_height}"
  echo ""
  
  # 如果使用预设
  if [ -n "$CROP_PRESET" ]; then
    case "$CROP_PRESET" in
      bottom-square)
        CROP_WIDTH=$video_width
        CROP_HEIGHT=$video_width
        CROP_X=0
        CROP_Y=$((video_height - video_width))
        echo "使用预设: 下半部分正方形"
        ;;
      top-square)
        CROP_WIDTH=$video_width
        CROP_HEIGHT=$video_width
        CROP_X=0
        CROP_Y=0
        echo "使用预设: 上半部分正方形"
        ;;
      center-square)
        if [ $video_width -lt $video_height ]; then
          CROP_WIDTH=$video_width
          CROP_HEIGHT=$video_width
        else
          CROP_WIDTH=$video_height
          CROP_HEIGHT=$video_height
        fi
        CROP_X=$(( (video_width - CROP_WIDTH) / 2 ))
        CROP_Y=$(( (video_height - CROP_HEIGHT) / 2 ))
        echo "使用预设: 居中正方形"
        ;;
      left-half)
        CROP_WIDTH=$((video_width / 2))
        CROP_HEIGHT=$video_height
        CROP_X=0
        CROP_Y=0
        echo "使用预设: 左半部分"
        ;;
      right-half)
        CROP_WIDTH=$((video_width / 2))
        CROP_HEIGHT=$video_height
        CROP_X=$((video_width / 2))
        CROP_Y=0
        echo "使用预设: 右半部分"
        ;;
      *)
        echo "❌ 错误: 未知预设 $CROP_PRESET"
        exit 1
        ;;
    esac
  fi
  
  # 验证裁剪参数
  if [ -z "$CROP_WIDTH" ] || [ -z "$CROP_HEIGHT" ]; then
    echo "❌ 错误: 必须指定裁剪宽度和高度（-w 和 -h），或使用 --preset"
    exit 1
  fi
  
  # 验证参数是否为数字
  if ! [[ "$CROP_WIDTH" =~ ^[0-9]+$ ]] || ! [[ "$CROP_HEIGHT" =~ ^[0-9]+$ ]] || \
     ! [[ "$CROP_X" =~ ^[0-9]+$ ]] || ! [[ "$CROP_Y" =~ ^[0-9]+$ ]]; then
    echo "❌ 错误: 裁剪参数必须是数字"
    exit 1
  fi
  
  # 验证裁剪区域是否超出视频范围
  if [ $((CROP_X + CROP_WIDTH)) -gt $video_width ] || [ $((CROP_Y + CROP_HEIGHT)) -gt $video_height ]; then
    echo "❌ 错误: 裁剪区域超出视频范围"
    echo "  视频大小: ${video_width}x${video_height}"
    echo "  裁剪区域: ${CROP_WIDTH}x${CROP_HEIGHT} 从 (${CROP_X}, ${CROP_Y})"
    echo "  结束坐标: ($((CROP_X + CROP_WIDTH)), $((CROP_Y + CROP_HEIGHT)))"
    exit 1
  fi
  
  # 默认输出文件名
  if [ -z "$CROP_OUTPUT" ]; then
    CROP_OUTPUT="${dirname}/${basename_no_ext}_cropped.${extension}"
  fi
  
  echo "裁剪参数:"
  echo "  宽度: $CROP_WIDTH"
  echo "  高度: $CROP_HEIGHT"
  echo "  X坐标: $CROP_X"
  echo "  Y坐标: $CROP_Y"
  echo "  输出: $(basename "$CROP_OUTPUT")"
  echo ""
  echo "🚀 开始处理..."
  
  # 执行裁剪（使用高质量参数保持清晰度）
  if ffmpeg -i "$CROP_INPUT" -vf "crop=${CROP_WIDTH}:${CROP_HEIGHT}:${CROP_X}:${CROP_Y}" \
     -c:v libx264 -crf 18 -preset slow -c:a copy -movflags +faststart "$CROP_OUTPUT" -y; then
    echo ""
    echo "✅ 完成"
    
    if [ -f "$CROP_OUTPUT" ]; then
      original_size=$(du -h "$CROP_INPUT" | awk '{print $1}')
      output_size=$(du -h "$CROP_OUTPUT" | awk '{print $1}')
      echo "原始文件: $original_size"
      echo "输出文件: $output_size"
      echo "输出路径: $CROP_OUTPUT"
    fi
    exit 0
  else
    echo ""
    echo "❌ 处理失败"
    exit 1
  fi
fi

# 简化的时长截取模式
if [ "$TRIM_DURATION_MODE" = true ]; then
  if [ ! -f "$TRIM_DURATION_INPUT" ]; then
    echo "❌ 错误: 输入文件不存在: $TRIM_DURATION_INPUT"
    exit 1
  fi
  
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"
    exit 1
  fi
  
  # 解析时长参数，支持多种格式
  parse_duration() {
    local input="$1"
    local seconds=0
    
    # 如果是纯数字，直接当作秒数
    if [[ "$input" =~ ^[0-9]+$ ]]; then
      seconds=$input
    # 如果是 HH:MM:SS 或 MM:SS 格式
    elif [[ "$input" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
      local h=${BASH_REMATCH[1]}
      local m=${BASH_REMATCH[2]}
      local s=${BASH_REMATCH[3]}
      seconds=$((h * 3600 + m * 60 + s))
    elif [[ "$input" =~ ^([0-9]+):([0-9]+)$ ]]; then
      local m=${BASH_REMATCH[1]}
      local s=${BASH_REMATCH[2]}
      seconds=$((m * 60 + s))
    # 如果是 1m30s 或 90s 格式
    elif [[ "$input" =~ ^([0-9]+)m([0-9]+)s$ ]]; then
      local m=${BASH_REMATCH[1]}
      local s=${BASH_REMATCH[2]}
      seconds=$((m * 60 + s))
    elif [[ "$input" =~ ^([0-9]+)m$ ]]; then
      local m=${BASH_REMATCH[1]}
      seconds=$((m * 60))
    elif [[ "$input" =~ ^([0-9]+)s$ ]]; then
      local s=${BASH_REMATCH[1]}
      seconds=$s
    else
      echo "0"
      return 1
    fi
    
    echo "$seconds"
    return 0
  }
  
  # 解析时长
  duration_seconds=$(parse_duration "$TRIM_DURATION")
  
  if [ "$duration_seconds" -le 0 ]; then
    echo "❌ 错误: 无效的时长格式: $TRIM_DURATION"
    echo "支持的格式:"
    echo "  - 秒数: 30, 90"
    echo "  - 分秒: 1m30s, 2m, 90s"
    echo "  - 时分秒: 01:30, 01:30:00"
    exit 1
  fi
  
  filename="$(basename "$TRIM_DURATION_INPUT")"
  dirname="$(dirname "$TRIM_DURATION_INPUT")"
  basename_no_ext="${filename%.*}"
  extension="${filename##*.}"
  
  # 默认输出文件名
  if [ -z "$TRIM_DURATION_OUTPUT" ]; then
    TRIM_DURATION_OUTPUT="${dirname}/${basename_no_ext}_${duration_seconds}s.${extension}"
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✂️  截取视频指定时长"
  echo "输入: $filename"
  echo "时长: ${duration_seconds}秒 ($((duration_seconds / 60))分$((duration_seconds % 60))秒)"
  echo "输出: $(basename "$TRIM_DURATION_OUTPUT")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # 获取原视频时长
  video_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TRIM_DURATION_INPUT" 2>/dev/null)
  video_duration_int=$(echo "$video_duration / 1" | bc 2>/dev/null)
  
  if [ -n "$video_duration_int" ] && [ "$video_duration_int" -gt 0 ]; then
    echo "原视频时长: $((video_duration_int / 60))分$((video_duration_int % 60))秒"
    
    if [ "$duration_seconds" -gt "$video_duration_int" ]; then
      echo "⚠️  警告: 请求的时长超过视频总时长，将截取整个视频"
    fi
  fi
  
  echo ""
  echo "🚀 开始处理..."
  
  # 使用 ffmpeg 快速截取（无损复制，不重新编码）
  if ffmpeg -i "$TRIM_DURATION_INPUT" -t "$duration_seconds" -c copy -avoid_negative_ts make_zero "$TRIM_DURATION_OUTPUT" -y 2>&1 | grep -q "muxing overhead\|video:"; then
    echo ""
    echo "✅ 完成"
    
    if [ -f "$TRIM_DURATION_OUTPUT" ]; then
      original_size=$(du -h "$TRIM_DURATION_INPUT" | awk '{print $1}')
      output_size=$(du -h "$TRIM_DURATION_OUTPUT" | awk '{print $1}')
      
      # 获取输出视频的实际时长
      output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TRIM_DURATION_OUTPUT" 2>/dev/null)
      output_duration_int=$(echo "$output_duration / 1" | bc 2>/dev/null)
      
      echo "原始文件: $original_size"
      echo "输出文件: $output_size"
      if [ -n "$output_duration_int" ]; then
        echo "输出时长: $((output_duration_int / 60))分$((output_duration_int % 60))秒"
      fi
      echo "输出路径: $TRIM_DURATION_OUTPUT"
    fi
    exit 0
  else
    echo ""
    echo "❌ 处理失败"
    exit 1
  fi
fi

# 按1小时切分模式
if [ "$SPLIT_MODE" = true ]; then
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"
    exit 1
  fi
  
  # 定义分割单个视频的函数
  split_single_video() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
      echo "❌ 文件不存在: $input_file"
      return 1
    fi
    
    local filename="$(basename "$input_file")"
    local dirname="$(dirname "$input_file")"
    local basename_no_ext="${filename%.*}"
    local extension="${filename##*.}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📹 检查视频: $filename"
    
    # 获取视频时长
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    
    if [ -z "$duration" ]; then
      echo "  ❌ 无法获取视频时长，跳过"
      return 1
    fi
    
    local duration_int=$(echo "$duration / 1" | bc 2>/dev/null)
    local hours=$(echo "$duration / 3600" | bc)
    local minutes=$(echo "($duration % 3600) / 60" | bc)
    
    echo "  时长: ${hours}小时${minutes}分钟 (${duration_int}秒)"
    
    # 检查是否超过1.5小时（5400秒）
    if [ "$duration_int" -le 5400 ]; then
      echo "  ⏭️  跳过: 时长不超过1.5小时"
      return 0
    fi
    
    echo "  ✅ 符合条件，开始分割..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 使用 ffmpeg 拆分视频（每小时一个文件）
    if ffmpeg -i "$input_file" -c copy -map 0 -segment_time 3600 -f segment -reset_timestamps 1 "${dirname}/${basename_no_ext}_part_%02d.${extension}" -y 2>&1 | grep -q "muxing overhead\|video:"; then
      echo ""
      echo "  ✅ 分割完成！生成的文件："
      ls -lh "${dirname}/${basename_no_ext}_part_"*."${extension}" 2>/dev/null | awk '{print "     "$9" ("$5")"}'
      return 0
    else
      echo ""
      echo "  ❌ 分割失败"
      return 1
    fi
  }
  
  # 收集要处理的视频文件
  video_files=()
  
  # 如果指定了目录，扫描该目录
  if [ -n "$SPLIT_DIR" ]; then
    echo "📁 扫描目录: $SPLIT_DIR"
    echo ""
    
    # 查找所有视频文件（不递归）
    while IFS= read -r -d '' file; do
      video_files+=("$file")
    done < <(find "$SPLIT_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.MP4" -o -iname "*.mov" -o -iname "*.MOV" -o -iname "*.avi" -o -iname "*.mkv" \) -print0 2>/dev/null)
  else
    # 使用通配符匹配的文件
    video_files=("${SPLIT_INPUTS[@]}")
  fi
  
  # 检查是否找到文件
  if [ ${#video_files[@]} -eq 0 ]; then
    echo "⚠️  未找到符合条件的视频文件"
    exit 0
  fi
  
  echo "找到 ${#video_files[@]} 个视频文件"
  echo ""
  
  # 统计
  total=${#video_files[@]}
  processed=0
  skipped=0
  failed=0
  
  # 处理每个视频
  for video_file in "${video_files[@]}"; do
    if split_single_video "$video_file"; then
      # 检查是否实际分割了文件（生成了_part_文件）
      filename="$(basename "$video_file")"
      dirname="$(dirname "$video_file")"
      basename_no_ext="${filename%.*}"
      extension="${filename##*.}"
      
      if ls "${dirname}/${basename_no_ext}_part_"*."${extension}" >/dev/null 2>&1; then
        ((processed++))
      else
        ((skipped++))
      fi
    else
      ((failed++))
    fi
    echo ""
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 处理完成"
  echo "  总数: $total 个视频"
  echo "  已分割: $processed 个"
  echo "  跳过: $skipped 个（时长≤1.5小时）"
  if [ $failed -gt 0 ]; then
    echo "  失败: $failed 个"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  exit 0
fi

# 修复视频时间戳模式
if [ "$FIX_TIMESTAMP_MODE" = true ]; then
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"
    exit 1
  fi
  
  if ! command -v ffprobe >/dev/null 2>&1; then
    echo "❌ 错误: 未安装 ffprobe（brew install ffmpeg）"
    exit 1
  fi
  
  # 修复单个视频的时间戳
  fix_video_timestamp() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
      echo "❌ 文件不存在: $input_file"
      return 1
    fi
    
    local filename="$(basename "$input_file")"
    local dirname="$(dirname "$input_file")"
    local basename_no_ext="${filename%.*}"
    local extension="${filename##*.}"
    
    # 跳过已经修复过的文件（文件名包含_fixed）
    if [[ "$basename_no_ext" =~ _fixed$ ]]; then
      echo "⏭️  跳过: $filename (已修复)"
      return 0
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 检查并修复视频时间戳"
    echo "输入: $filename"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 1. 获取 format 级别的 start_time 和 duration
    local format_info=$(ffprobe -v error -show_entries format=start_time,duration -of csv=p=0 "$input_file" 2>/dev/null)
    local start_time=$(echo "$format_info" | cut -d',' -f1)
    local duration=$(echo "$format_info" | cut -d',' -f2)
    
    if [ -z "$start_time" ] || [ -z "$duration" ]; then
      echo "  ⚠️  无法获取视频信息，跳过"
      return 1
    fi
    
    local start_time_int=$(echo "$start_time / 1" | bc 2>/dev/null || echo "0")
    local duration_int=$(echo "$duration / 1" | bc 2>/dev/null || echo "0")
    
    echo "  format start_time: ${start_time}秒"
    echo "  format duration:   ${duration}秒 ($((duration_int/60))分$((duration_int%60))秒)"
    
    # 2. 检查第一个关键帧的 PTS 时间（更精确的判断依据）
    echo "  🔍 检查首个关键帧 PTS..."
    local first_keyframe_pts=$(ffprobe -v error -select_streams v:0 \
      -show_entries packet=pts_time,flags -of csv=p=0 \
      -read_intervals "%+300" "$input_file" 2>/dev/null \
      | grep "K__" | head -1 | cut -d',' -f1)
    
    if [ -z "$first_keyframe_pts" ]; then
      echo "  ⚠️  无法获取关键帧信息，跳过"
      return 1
    fi
    
    local first_kf_int=$(echo "$first_keyframe_pts / 1" | bc 2>/dev/null || echo "0")
    echo "  首个关键帧 PTS: ${first_keyframe_pts}秒"
    
    # 3. 判断是否需要修复
    # 条件：start_time >= 1秒 或 首个关键帧 PTS >= 1秒
    if [ "$start_time_int" -lt 1 ] && [ "$first_kf_int" -lt 1 ]; then
      echo "  ✅ 时间戳正常（start_time 和首个关键帧 PTS 均接近0），无需修复"
      return 0
    fi
    
    # 确定修复用的偏移量（取首个关键帧PTS，因为更精确）
    local seek_offset="$first_keyframe_pts"
    if [ "$first_kf_int" -lt 1 ] && [ "$start_time_int" -ge 1 ]; then
      # 关键帧PTS正常但start_time异常，使用start_time
      seek_offset="$start_time"
    fi
    
    echo "  ⚠️  检测到时间戳偏移: ${seek_offset}秒"
    
    # 输出文件名
    local output_file="${dirname}/${basename_no_ext}_fixed.${extension}"
    
    # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
      if [ "$FORCE_OVERWRITE" = true ]; then
        echo "  🔄 强制覆盖已存在的文件: $(basename "$output_file")"
      else
        echo "  ⚠️  输出文件已存在: $(basename "$output_file")"
        echo "  💡 提示: 使用 -f 或 --force 参数可以强制覆盖"
        return 0
      fi
    fi
    
    echo "  🚀 开始修复时间戳..."
    echo "  ↪ ffmpeg -ss ${seek_offset} -i ... -c copy -avoid_negative_ts make_zero ..."
    echo "  输出: $(basename "$output_file")"
    
    # 使用 -ss 跳到首个关键帧位置，配合 -avoid_negative_ts make_zero 重置时间戳
    # 这比 -fflags +genpts -start_at_zero -copyts 更可靠
    if ffmpeg -ss "$seek_offset" -i "$input_file" -c copy -avoid_negative_ts make_zero "$output_file" -y 2>&1 | grep -q "muxing overhead\|video:"; then
      echo ""
      echo "  ✅ 修复完成"
      
      # 4. 验证修复结果
      echo "  🔍 验证修复结果..."
      
      # 验证 format 级别 start_time 和 duration
      local new_format_info=$(ffprobe -v error -show_entries format=start_time,duration -of csv=p=0 "$output_file" 2>/dev/null)
      local new_start_time=$(echo "$new_format_info" | cut -d',' -f1)
      local new_duration=$(echo "$new_format_info" | cut -d',' -f2)
      local new_duration_int=$(echo "$new_duration / 1" | bc 2>/dev/null || echo "0")
      
      echo "  修复后 start_time: ${new_start_time}秒"
      echo "  修复后 duration:   ${new_duration}秒 ($((new_duration_int/60))分$((new_duration_int%60))秒)"
      
      # 验证首个关键帧 PTS
      local new_first_kf_pts=$(ffprobe -v error -select_streams v:0 \
        -show_entries packet=pts_time,flags -of csv=p=0 \
        "$output_file" 2>/dev/null \
        | grep "K__" | head -1 | cut -d',' -f1)
      
      if [ -n "$new_first_kf_pts" ]; then
        local new_first_kf_int=$(echo "$new_first_kf_pts / 1" | bc 2>/dev/null || echo "0")
        echo "  修复后首个关键帧 PTS: ${new_first_kf_pts}秒"
        
        if [ "$new_first_kf_int" -ge 1 ]; then
          echo "  ⚠️  警告: 修复后首个关键帧 PTS 仍 >= 1秒，可能需要重新编码"
          echo "  💡 建议: 尝试 -compress quality 重新编码视频"
        fi
      fi
      
      # 对比文件大小
      local original_size=$(du -h "$input_file" | awk '{print $1}')
      local output_size=$(du -h "$output_file" | awk '{print $1}')
      echo "  原始文件: $original_size"
      echo "  输出文件: $output_size"
      echo "  输出路径: $output_file"
      
      return 0
    else
      echo ""
      echo "  ❌ 修复失败"
      # 删除失败的输出文件
      [ -f "$output_file" ] && rm -f "$output_file"
      return 1
    fi
  }
  
  # 处理输入
  if [ -f "$FIX_TIMESTAMP_INPUT" ]; then
    # 单个文件
    fix_video_timestamp "$FIX_TIMESTAMP_INPUT"
  elif [ -d "$FIX_TIMESTAMP_INPUT" ]; then
    # 目录
    echo "📁 处理目录: $FIX_TIMESTAMP_INPUT"
    echo ""
    
    # 查找视频文件
    local video_files=()
    if [ "$RECURSIVE" = true ]; then
      while IFS= read -r -d '' file; do
        video_files+=("$file")
      done < <(find "$FIX_TIMESTAMP_INPUT" -type f \( -iname "*.mp4" -o -iname "*.MP4" -o -iname "*.mov" -o -iname "*.MOV" -o -iname "*.avi" -o -iname "*.mkv" \) -print0 2>/dev/null)
    else
      while IFS= read -r -d '' file; do
        video_files+=("$file")
      done < <(find "$FIX_TIMESTAMP_INPUT" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.MP4" -o -iname "*.mov" -o -iname "*.MOV" -o -iname "*.avi" -o -iname "*.mkv" \) -print0 2>/dev/null)
    fi
    
    if [ ${#video_files[@]} -eq 0 ]; then
      echo "⚠️  未找到视频文件"
      exit 0
    fi
    
    echo "找到 ${#video_files[@]} 个视频文件"
    echo ""
    
    local success=0
    local skipped=0
    local failed=0
    
    for video_file in "${video_files[@]}"; do
      if fix_video_timestamp "$video_file"; then
        # 检查返回值：0表示成功或跳过
        if [[ "$(basename "$video_file")" =~ _fixed ]]; then
          ((skipped++))
        else
          # 检查是否生成了输出文件
          local output_check="${video_file%.*}_fixed.${video_file##*.}"
          if [ -f "$output_check" ]; then
            ((success++))
          else
            ((skipped++))
          fi
        fi
      else
        ((failed++))
      fi
      echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 处理完成"
    echo "  成功: $success 个"
    echo "  跳过: $skipped 个"
    echo "  失败: $failed 个"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "❌ 错误: 输入路径不存在: $FIX_TIMESTAMP_INPUT"
    exit 1
  fi
  
  exit 0
fi

# 压缩模式：批量处理并提前返回
if [ "$COMPRESS_MODE" = true ]; then
  compress_video() {
    local input_file="$1"
    local compress_type="$2"
    local output_file="$3"
    local target_dir="$4"
    local target_format="$5"

    if [ ! -f "$input_file" ]; then
      echo "❌ 错误: 输入文件不存在: $input_file"; return 1; fi
    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "❌ 错误: 未安装 ffmpeg（brew install ffmpeg）"; return 1; fi

    local filename="$(basename "$input_file")"
    local dirname="$(dirname "$input_file")"
    local basename_no_ext="${filename%.*}"
    local extension="${filename##*.}"
    
    # 如果指定了目标格式，使用目标格式，否则保持原格式
    if [ -n "$target_format" ]; then
      extension="$target_format"
    fi

    # 默认输出名
    if [ -z "$output_file" ]; then
      case "$compress_type" in
        quality) output_file="${dirname}/${basename_no_ext}_compressed.${extension}" ;;
        4k|2k|1080p|720p) output_file="${dirname}/${basename_no_ext}_${compress_type}.${extension}" ;;
        cut) output_file="${dirname}/${basename_no_ext}_cut.${extension}" ;;
      esac
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎬 视频压缩处理"
    echo "输入: $filename"
    echo "输出: $(basename "$output_file")"
    echo "类型: $compress_type"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local original_size=$(du -h "$input_file" | awk '{print $1}')
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    local resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input_file" 2>/dev/null)
    echo "  原始大小: $original_size"
    [ -n "$duration" ] && echo "  时长: $(echo "$duration/60" | bc) 分钟"
    [ -n "$resolution" ] && echo "  分辨率: $resolution"
    
    # === 检测视频有效部分（优化的二分搜索算法） ===
    local valid_end_time=""  # 视频有效结束时间
    local duration_int=$(echo "$duration / 1" | bc)
    
    if [ -n "$duration" ] && [ "$duration_int" -gt 600 ]; then
      echo "  🔍 检测视频有效部分..."
      
      # 使用高效的二分搜索从后往前找"直播已结束"画面
      local temp_check_dir="$(mktemp -d)"
      
      # 检查是否有tesseract
      if ! command -v tesseract &> /dev/null; then
        echo "  ⚠️  未安装tesseract，跳过检测（可选安装: brew install tesseract tesseract-lang）"
        rm -rf "$temp_check_dir"
      else
        # 第一阶段：大步长搜索（每5分钟=300秒）
        local found_end=0
        local found_start=$duration_int
        local search_start=$((duration_int - 300))  # 从倒数5分钟开始
        
        echo "  📍 阶段1: 粗略定位（每5分钟采样）..."
        for t in $(seq $search_start -300 600); do
          local check_frame="$temp_check_dir/phase1_${t}.jpg"
          if ffmpeg -ss "$t" -i "$input_file" -vframes 1 -q:v 2 "$check_frame" -y &>/dev/null 2>&1; then
            local result=$(tesseract "$check_frame" - -l chi_sim 2>/dev/null | grep -o "直播已结束")
            if [ -n "$result" ]; then
              found_end=$t
              echo "    $((t/60))分钟: 发现'直播已结束'"
            else
              found_start=$t
              echo "    $((t/60))分钟: 正常内容 ← 锁定区间"
              break
            fi
            rm -f "$check_frame"
          fi
        done
        
        # 第二阶段：在锁定区间内精确搜索（每30秒）
        if [ "$found_end" -gt 0 ] && [ "$found_start" -lt "$found_end" ]; then
          echo "  📍 阶段2: 精确定位 ($((found_start/60))-$((found_end/60))分钟，每30秒采样)..."
          local precise_cut=""
          
          for t in $(seq $((found_end - 30)) -30 $found_start); do
            local check_frame="$temp_check_dir/phase2_${t}.jpg"
            if ffmpeg -ss "$t" -i "$input_file" -vframes 1 -q:v 2 "$check_frame" -y &>/dev/null 2>&1; then
              local result=$(tesseract "$check_frame" - -l chi_sim 2>/dev/null | grep -o "直播已结束")
              if [ -z "$result" ]; then
                # 找到最后一个正常内容帧
                precise_cut=$t
                echo "    $((t/60))分$((t%60))秒: 正常内容 ← 分界点"
                break
              fi
              rm -f "$check_frame"
            fi
          done
          
          if [ -n "$precise_cut" ]; then
            valid_end_time=$precise_cut
            local ended_duration=$((duration_int - precise_cut))
            local ended_ratio=$(echo "scale=1; $ended_duration * 100 / $duration_int" | bc)
            
            echo "  ⚠️  检测到'直播已结束'画面占比 ${ended_ratio}%"
            echo "  ✂️  将截取有效部分: 0 - ${valid_end_time}秒 ($((valid_end_time/3600))h$((valid_end_time%3600/60))m)"
          fi
        else
          echo "  ✅ 未检测到'直播已结束'画面"
        fi
      fi
      
      rm -rf "$temp_check_dir"
    fi

    local cmd
    # 如果检测到有效结束时间，添加-to参数
    local time_limit_opts=()
    if [ -n "$valid_end_time" ]; then
      time_limit_opts=(-to "$valid_end_time")
    fi
    
    case "$compress_type" in
      quality)
        # H.265 更高压缩比；可根据需要调高/调低 crf（22高质->30更小）
        cmd=(ffmpeg "${time_limit_opts[@]}" -i "$input_file" -c:v libx265 -crf 28 -preset medium -c:a aac -b:a 128k -movflags +faststart "$output_file" -y)
        ;;
      4k)
        # 保持宽高比并确保尺寸为偶数（H.264要求）
        cmd=(ffmpeg "${time_limit_opts[@]}" -i "$input_file" -vf "scale='min(3840,iw)':'min(2160,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$output_file" -y)
        ;;
      2k|1440p)
        # 2K/1440p: 2560x1440 （4K与1080p的中间值，适合高清屏幕）
        cmd=(ffmpeg "${time_limit_opts[@]}" -i "$input_file" -vf "scale='min(2560,iw)':'min(1440,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$output_file" -y)
        ;;
      1080p)
        cmd=(ffmpeg "${time_limit_opts[@]}" -i "$input_file" -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$output_file" -y)
        ;;
      720p)
        cmd=(ffmpeg "${time_limit_opts[@]}" -i "$input_file" -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset medium -crf 23 -c:a copy -movflags +faststart "$output_file" -y)
        ;;
      cut)
        # 组合时间选项
        time_opts=()
        [ -n "$COMPRESS_START" ] && time_opts+=(-ss "$COMPRESS_START")
        if [ -n "$COMPRESS_END" ]; then time_opts+=( -to "$COMPRESS_END" );
        elif [ -n "$COMPRESS_DURATION" ]; then time_opts+=( -t "$COMPRESS_DURATION" ); fi
        if [ ${#time_opts[@]} -eq 0 ]; then echo "❌ 错误: cut 需要 -ss/-to/-t"; return 1; fi
        # 无损快速截取
        cmd=(ffmpeg "${time_opts[@]}" -i "$input_file" -c copy -movflags +faststart "$output_file" -y)
        ;;
      *) echo "❌ 错误: 未知类型 $compress_type"; return 1 ;;
    esac

    echo "🚀 开始处理..."
    if "${cmd[@]}"; then
      echo "✅ 完成"
      if [ -f "$output_file" ]; then
        new_size=$(du -h "$output_file" | awk '{print $1}')
        ob=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
        nb=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        if [ -n "$ob" ] && [ -n "$nb" ] && [ "$ob" -gt 0 ]; then
          delta=$(echo "scale=1; ($ob-$nb)*100/$ob" | bc)
          echo "📊 大小: $original_size -> $new_size (减少 ${delta}%)"
        else
          echo "📊 新文件大小: $new_size"
        fi
        echo "输出: $output_file"
        
        # 如果指定了目标目录，移动文件
        if [ -n "$target_dir" ]; then
          if [ ! -d "$target_dir" ]; then
            echo "📁 创建目标目录: $target_dir"
            mkdir -p "$target_dir"
          fi
          local target_file="$target_dir/$(basename "$output_file")"
          if mv "$output_file" "$target_file"; then
            echo "📦 已移动到: $target_file"
          else
            echo "⚠️  移动失败，文件保留在: $output_file"
          fi
        fi
      fi
      return 0
    else
      echo "❌ ffmpeg 失败"; return 1
    fi
  }
  
  # 批量处理视频文件
  # 直接使用COMPRESS_INPUTS数组（已经包含正确处理的文件路径）
  input_files=("${COMPRESS_INPUTS[@]}")
  
  total=${#input_files[@]}
  success=0
  failed=0
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🎬 批量视频压缩处理"
  echo "总数: $total 个视频"
  echo "类型: $COMPRESS_TYPE"
  [ -n "$COMPRESS_TARGET_DIR" ] && echo "目标目录: $COMPRESS_TARGET_DIR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 处理每个视频文件
  index=1
  skipped=0
  for input_file in "${input_files[@]}"; do
    filename="$(basename "$input_file")"
    
    # 检查文件名是否包含 _4k (任意位置)
    if [[ "$filename" =~ _4k ]]; then
      echo "📹 [$index/$total] 跳过: $filename (已包含_4k标记)"
      echo
      ((skipped++))
      ((index++))
      continue
    fi
    
    echo "📹 [$index/$total] 处理: $filename"
    echo
    
    # 对于批量处理，不使用 -o 参数（每个文件自动命名）
    if compress_video "$input_file" "$COMPRESS_TYPE" "" "$COMPRESS_TARGET_DIR" "$COMPRESS_TARGET_FORMAT"; then
      ((success++))
    else
      ((failed++))
    fi
    
    echo
    ((index++))
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 批量处理完成"
  echo "成功: $success 个"
  if [ $skipped -gt 0 ]; then
    echo "跳过: $skipped 个 (已包含_4k标记)"
  fi
  echo "失败: $failed 个"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [ $failed -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
fi

# 确保目录存在
if [ ! -d "$TARGET_DIR" ]; then
  echo "目标目录不存在：$TARGET_DIR"
  exit 1
fi

echo "目标目录：$TARGET_DIR"
if [ -n "$SOURCE_DIR" ]; then
  echo "源目录：$SOURCE_DIR"
fi
if [ "$RECURSIVE" = true ]; then
  if [ "$MAX_DEPTH" -eq 999 ]; then
    echo "递归模式：处理所有层级"
  else
    echo "递归模式：处理 $MAX_DEPTH 层"
  fi
else
  echo "非递归模式：只处理一级子文件夹"
fi
if [ "$FILE_DEPTH" -eq 1 ]; then
  echo "文件扫描深度：1（仅当前目录）"
else
  echo "文件扫描深度：$FILE_DEPTH"
fi
echo

# ============================================
# 对于视频处理相关任务，执行系统健康度检查
# ============================================
if [ "$COMPRESS_MODE" = true ] || [ "$CHECK_VIDEO_MODE" = true ] || [ "$OCR_RENAME_MODE" = true ] || [ "$CROP_MODE" = true ]; then
  check_system_health
fi

# ============================================
# 定义处理函数
# ============================================

# 清空目录下的所有文件（保留目录结构）
clean_directory_files() {
  local target_path="$1"
  
  if [ ! -e "$target_path" ]; then
    echo "❌ 错误: 路径不存在: $target_path"
    return 1
  fi
  
  if [ ! -d "$target_path" ]; then
    echo "❌ 错误: 不是目录: $target_path"
    return 1
  fi
  
  echo "🗑️  清空目录: $(basename "$target_path")"
  
  local deleted_files=0
  local deleted_size=0
  
  # 递归查找所有文件（不包括目录）
  while IFS= read -r -d '' file; do
    # 获取文件大小
    local file_size=0
    if [[ "$OSTYPE" == "darwin"* ]]; then
      file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
      file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    
    deleted_size=$((deleted_size + file_size))
    
    # 删除文件
    if rm -f "$file" 2>/dev/null; then
      ((deleted_files++))
    else
      echo "  ⚠️  无法删除: $file"
    fi
  done < <(find "$target_path" -type f -print0 2>/dev/null)
  
  # 转换大小为可读格式
  local size_readable=""
  if [ $deleted_size -ge 1073741824 ]; then
    size_readable="$(echo "scale=1; $deleted_size / 1073741824" | bc)G"
  elif [ $deleted_size -ge 1048576 ]; then
    size_readable="$(echo "scale=1; $deleted_size / 1048576" | bc)M"
  elif [ $deleted_size -ge 1024 ]; then
    size_readable="$(echo "scale=1; $deleted_size / 1024" | bc)K"
  else
    size_readable="${deleted_size}B"
  fi
  
  echo "  ✅ 已删除: ${deleted_files}个文件 (${size_readable})"
  
  return 0
}

# 递归更新目录大小标签
update_directory_sizes() {
  local target_path="$1"
  
  if [ ! -d "$target_path" ]; then
    return 0
  fi
  
  echo "📊 更新目录大小: $(basename "$target_path")"
  
  local updated_count=0
  
  # 从深度优先遍历（从子目录开始）
  while IFS= read -r dir; do
    local base="$(basename "$dir")"
    local parent="$(dirname "$dir")"
    
    # 去掉末尾的大小标签
    local clean_name="$(printf '%s' "$base" | sed 's/（[^（]*）$//')"
    
    # 计算实际大小
    local size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    
    if [ -z "$size" ]; then
      continue
    fi
    
    # 拼接新名称
    local new_name="${clean_name}（${size}）"
    
    # 如果名称没变化就跳过
    if [ "$base" = "$new_name" ]; then
      continue
    fi
    
    # 执行重命名
    local src="$parent/$base"
    local dst="$parent/$new_name"
    
    if [ -e "$dst" ] && [ "$dst" != "$src" ]; then
      echo "  ⚠️  目标已存在，跳过: $dst"
      continue
    fi
    
    echo "  ✅ 更新: $base → $new_name"
    if mv "$src" "$dst" 2>/dev/null; then
      ((updated_count++))
    else
      echo "    ❌ 失败"
    fi
  done < <(find "$target_path" -type d -depth 2>/dev/null)
  
  echo "  📊 共更新 ${updated_count} 个目录"
  
  return 0
}

# 递归处理空目录的显示/隐藏（用于-tag模式）
process_empty_directories() {
  local target_path="$1"
  
  if [ ! -d "$target_path" ]; then
    return 0
  fi
  
  # 从深度优先遍历（从最深的子目录开始）
  while IFS= read -r dir; do
    local base="$(basename "$dir")"
    
    # 只处理【】包围的目录或DY-开头的目录
    if [[ ! "$base" =~ ^【.*】 ]] && [[ ! "$base" =~ ^DY- ]]; then
      continue
    fi
    
    # 跳过特殊目录
    if [[ "$base" =~ ^DY-分类浏览 ]] || [[ "$base" =~ ^TODO ]]; then
      continue
    fi
    
    # 如果使用了 -s 参数，显示所有目录
    if [ "$SHOW_HIDDEN" = true ]; then
      if chflags nohidden "$dir" 2>/dev/null; then
        echo "✅ 显示: $base"
      fi
    else
      # 检查目录是否为空（忽略所有隐藏文件，包括.DS_Store）
      # 只统计非隐藏文件和非隐藏目录
      local visible_count=$(find "$dir" -mindepth 1 \( -type f -o -type d \) -not -name ".*" -not -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')
      
      if [ "$visible_count" -eq 0 ]; then
        # 目录为空（没有可见内容），设置为隐藏
        if ! [[ "$base" =~ ^\. ]]; then
          # 使用chflags设置隐藏属性（不打印日志）
          chflags hidden "$dir" 2>/dev/null
        fi
      fi
    fi
  done < <(find "$target_path" -type d -depth 2>/dev/null)
}

# 递归更新【】目录和DY-目录的大小标签（用于-tag模式）
update_all_directory_sizes() {
  local target_path="$1"
  
  if [ ! -d "$target_path" ]; then
    return 0
  fi
  
  # 只处理【】包围的目录和DY-开头的目录
  # 从深度优先遍历（从最深的子目录开始）更新
  while IFS= read -r dir; do
    local base="$(basename "$dir")"
    local parent="$(dirname "$dir")"
    
    # 只处理【】包围的目录或DY-开头的目录
    if [[ ! "$base" =~ ^【.*】 ]] && [[ ! "$base" =~ ^DY- ]]; then
      continue
    fi
    
    # 跳过特殊目录（不需要添加大小标签）
    if [[ "$base" =~ ^DY-分类浏览 ]] || [[ "$base" =~ ^TODO ]]; then
      continue
    fi
    
    # 去掉末尾的大小标签
    local clean_name="$(printf '%s' "$base" | sed 's/（[^（]*）$//')"
    
    # 计算实际大小
    local size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    
    if [ -z "$size" ]; then
      continue
    fi
    
    # 拼接新名称
    local new_name="${clean_name}（${size}）"
    
    # 检查目录是否非空，如果非空则移除hidden属性（无论是否需要重命名）
    local visible_count=$(find "$dir" -mindepth 1 \( -type f -o -type d \) -not -name ".*" -not -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$visible_count" -gt 0 ]; then
      # 目录非空，移除hidden属性
      chflags nohidden "$dir" 2>/dev/null
    fi
    
    # 如果名称没变化就跳过重命名
    if [ "$base" = "$new_name" ]; then
      continue
    fi
    
    # 执行重命名
    local src="$parent/$base"
    local dst="$parent/$new_name"
    
    if [ -e "$dst" ] && [ "$dst" != "$src" ]; then
      echo "⚠️  目标已存在，跳过: $dst"
      continue
    fi
    
    echo "✅ 更新: $base → $new_name"
    if ! mv "$src" "$dst" 2>/dev/null; then
      echo "  ❌ 失败"
    fi
  done < <(find "$target_path" -maxdepth 2 -type d -depth 2>/dev/null)
}

# 检测视频是否提前结束（画面静止或黑屏）或出现"直播已结束"
  check_video_integrity() {
  local video_file="$1"
  local filename="$(basename "$video_file")"
  local dirname="$(dirname "$video_file")"
  local basename_no_ext="${filename%.*}"
  local extension="${filename##*.}"
  
  # 检查 ffmpeg 是否可用
  if ! command -v ffmpeg &> /dev/null; then
    echo "❌ 错误: ffmpeg 未安装，无法处理视频"
    return 1
  fi
  
  echo "🔍 检测: $filename"
  
  # 获取视频时长（秒）
  local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
  if [ -z "$duration" ] || [ "$(echo "$duration < 1" | bc)" -eq 1 ]; then
    echo "  ⚠️  无法获取视频时长或视频过短"
    return 1
  fi
  
  # 转换为整数秒
  local duration_int=$(echo "$duration / 1" | bc)
  echo "  📺 视频时长: ${duration_int}秒 ($(echo "$duration_int / 60" | bc)分钟)"
  
  # === 新增：检测"直播已结束"画面（动态加速采样） ===
  local sample_interval=30  # 初始采样间隔：30秒
  local detected_live_ended=0
  local consecutive_live_ended=0  # 连续检测到的次数
  local total_samples=0
  local early_exit=false
  
  echo "  🔍 检测'直播已结束'画面（动态加速采样）..."
  
  # 创建临时目录
  local temp_ocr_dir="$(mktemp -d)"
  
  # 从视频末尾开始向前采样
  local t=$((duration_int - 5))  # 从结束前5秒开始
  local first_live_ended_position=$((duration_int - 5))  # 记录最早检测到"直播已结束"的位置
  
  while [ "$t" -gt 0 ]; do
    ((total_samples++))
    local frame_file="$temp_ocr_dir/frame_${t}.jpg"
    
    # 提取帧
    if ffmpeg -ss "$t" -i "$video_file" -vframes 1 -q:v 2 "$frame_file" -y &>/dev/null 2>&1; then
      local is_live_ended=false
      
      # 检查是否有 tesseract
      if command -v tesseract &> /dev/null; then
        # 使用OCR检测
        local ocr_text=$(tesseract "$frame_file" - -l chi_sim 2>/dev/null | tr -d '[:space:]\n')
        
        # 检查是否包含"直播已结束"相关文字
        if [[ "$ocr_text" =~ 直播.*结束 ]] || [[ "$ocr_text" =~ 直播已结束 ]] || [[ "$ocr_text" =~ 直播结束 ]]; then
          is_live_ended=true
        fi
      else
        # 如果没有tesseract，使用图像亮度检测（暗色画面可能是结束页）
        if command -v convert &> /dev/null; then
          local brightness=$(convert "$frame_file" -colorspace gray -format "%[fx:mean]" info: 2>/dev/null)
          
          # 如果亮度小于0.15（很暗），可能是结束画面
          if [ -n "$brightness" ] && [ "$(echo "$brightness < 0.15" | bc)" -eq 1 ]; then
            is_live_ended=true
          fi
        fi
      fi
      
      if [ "$is_live_ended" = true ]; then
        ((detected_live_ended++))
        ((consecutive_live_ended++))
        
        # 记录最早检测到"直播已结束"的位置（因为是反向采样，越早检测到的t越小）
        first_live_ended_position=$t
        
        # 动态调整采样间隔：检测到结束画面后，加快采样速度
        # 采样间隔：30秒 -> 15秒 -> 10秒 -> 5秒
        if [ "$consecutive_live_ended" -eq 1 ] && [ "$sample_interval" -eq 30 ]; then
          sample_interval=15
          echo "  ⚡ 检测到'直播已结束'，加快采样速度至 ${sample_interval}秒/次"
        elif [ "$consecutive_live_ended" -eq 2 ] && [ "$sample_interval" -eq 15 ]; then
          sample_interval=10
          echo "  ⚡⚡ 连续检测到，继续加快至 ${sample_interval}秒/次"
        elif [ "$consecutive_live_ended" -eq 3 ] && [ "$sample_interval" -eq 10 ]; then
          sample_interval=5
          echo "  ⚡⚡⚡ 继续加快至 ${sample_interval}秒/次"
        fi
        
        # 计算当前占比，如果已经超过20%就可以退出了
        local current_ended_duration=$((duration_int - first_live_ended_position))
        local current_ratio=$(echo "scale=1; $current_ended_duration * 100 / $duration_int" | bc)
        
        if [ "$(echo "$current_ratio >= 20" | bc)" -eq 1 ]; then
          echo "  ✅ '直播已结束'占比已达 ${current_ratio}% >= 20%，停止检测"
          early_exit=true
          rm -f "$frame_file"
          break
        fi
      else
        # 如果当前帧不是"直播已结束"
        if [ "$consecutive_live_ended" -gt 0 ]; then
          # 之前检测到连续结束画面，现在检测到正常画面
          # 说明已经越过分界点，可以退出了
          echo "  🎯 检测到正常画面，已找到'直播已结束'分界点"
          rm -f "$frame_file"
          early_exit=true
          break
        elif [ "$detected_live_ended" -eq 0 ] && [ "$total_samples" -ge 3 ]; then
          # 如果前3个采样点都没有检测到，可以提前退出
          echo "  ✅ 前${total_samples}个采样点未检测到'直播已结束'，视频正常"
          rm -f "$frame_file"
          early_exit=true
          break
        fi
      fi
      
      rm -f "$frame_file"
    fi
    
    # 向前移动采样点（使用当前的采样间隔）
    t=$((t - sample_interval))
  done
  
  # 清理临时目录
  rm -rf "$temp_ocr_dir"
  
  # 计算"直播已结束"画面占比（基于已采样的部分）
  local live_ended_ratio=0
  if [ "$total_samples" -gt 0 ]; then
    live_ended_ratio=$(echo "scale=2; $detected_live_ended / $total_samples" | bc)
  fi
  
  # 估算"直播已结束"画面的实际时长
  # 使用最早检测到的位置到视频末尾的时长
  local estimated_ended_duration=0
  local video_ratio=0
  
  if [ "$detected_live_ended" -gt 0 ]; then
    # 从最早检测到"直播已结束"的位置到视频结束（duration_int）
    estimated_ended_duration=$((duration_int - first_live_ended_position))
    
    # 计算占整个视频的比例
    video_ratio=$(echo "scale=1; $estimated_ended_duration * 100 / $duration_int" | bc)
  fi
  
  echo "  📊 '直播已结束'检测: ${detected_live_ended}/${total_samples} 个采样点"
  if [ "$detected_live_ended" -gt 0 ]; then
    local ended_minutes=$(echo "$estimated_ended_duration / 60" | bc)
    echo "  📏 '直播已结束'画面估算时长: ~${estimated_ended_duration}秒 (约${ended_minutes}分钟)"
    echo "  📊 '直播已结束'占比: ${video_ratio}% 的视频时长"
  fi
  
  # 如果"直播已结束"画面占比超过20%（视频总时长），标记文件
  if [ "$(echo "$video_ratio >= 20" | bc)" -eq 1 ]; then
    echo "  ⚠️  检测到大量'直播已结束'画面（超过20%阈值）"
    
    # 先移除旧的(todo)或占比标记（如果有）
    local clean_basename="$basename_no_ext"
    # 移除旧的 -(todo) 或 -(占比XX%) 标记
    clean_basename=$(echo "$clean_basename" | sed -E 's/-\(todo\)$//; s/-\(占比[0-9.]+%\)$//')
    
    # 添加占比标记
    local ratio_int=$(echo "$video_ratio / 1" | bc)  # 转为整数
    local new_filename="${clean_basename}-(占比${ratio_int}%).${extension}"
    local new_filepath="$dirname/$new_filename"
    
    # 检查新文件名是否已存在
    if [ -e "$new_filepath" ] && [ "$new_filepath" != "$video_file" ]; then
      echo "  ⚠️  目标文件已存在，跳过重命名"
    else
      # 重命名文件
      if mv "$video_file" "$new_filepath"; then
        echo "  ✅ 已标记: $filename -> $new_filename"
        return 2  # 返回2表示文件已被标记
      else
        echo "  ❌ 重命名失败"
        return 1
      fi
    fi
    
    return 0
  else
    # 占比不足，不标记
    if [ "$detected_live_ended" -gt 0 ]; then
      echo "  ✅ '直播已结束'占比 ${video_ratio}% < 20%，不需标记"
    else
      echo "  ✅ 未检测到'直播已结束'画面，视频正常"
    fi
  fi
  
  # === 继续原有的画面静止检测 ===
  # 如果视频小于10分钟，不需要检测画面静止
  if [ "$duration_int" -lt 600 ]; then
    echo "  ✅ 视频正常，无需优化"
    return 0
  fi
  
  # 创建临时目录
  local temp_dir="$(mktemp -d)"
  
  # 每10分钟采样一次，最后一帧在视频结束前5秒
  local sample_interval=600  # 10分钟 = 600秒
  local sample_times=()
  local t=0
  
  # 生成采样时间点
  while [ "$t" -lt "$duration_int" ]; do
    sample_times+=($t)
    t=$((t + sample_interval))
  done
  
  # 添加最后一帧（结束前5秒）
  local last_frame=$((duration_int - 5))
  local last_sample_time=${sample_times[${#sample_times[@]}-1]}
  if [ "$last_frame" -gt 0 ] && [ "$last_frame" -gt "$last_sample_time" ]; then
    sample_times+=($last_frame)
  fi
  
  echo "  📊 采样点: ${#sample_times[@]}个 ($(echo ${sample_times[@]} | sed 's/ /, /g')秒)"
  
  # 提取关键帧
  local frame_files=()
  local i=0
  for ts in "${sample_times[@]}"; do
    local frame_file="$temp_dir/frame_${i}.png"
    if ffmpeg -ss "$ts" -i "$video_file" -vframes 1 -q:v 2 "$frame_file" -y &>/dev/null 2>&1; then
      if [ -f "$frame_file" ]; then
        frame_files+=("$frame_file")
      fi
    fi
    i=$((i + 1))
  done
  
  if [ ${#frame_files[@]} -lt 2 ]; then
    echo "  ⚠️  提取帧失败"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # 比较相邻帧的相似度
  local is_frozen=false
  local frozen_at=""
  local prev_frame="${frame_files[0]}"
  
  for i in $(seq 1 $((${#frame_files[@]} - 1))); do
    local curr_frame="${frame_files[$i]}"
    local curr_time=${sample_times[$i]}
    
    # 使用ImageMagick比较两帧，计算差异度
    # 如果没有ImageMagick，使用文件大小作为简单判断
    if command -v compare &> /dev/null; then
      # 使用compare计算相似度
      local diff=$(compare -metric RMSE "$prev_frame" "$curr_frame" null: 2>&1 | awk '{print $1}' | sed 's/[^0-9.]//g')
      
      # 如果diff小于500，认为画面基本相同（静止）
      if [ -n "$diff" ] && [ "$(echo "$diff < 500" | bc)" -eq 1 ]; then
        is_frozen=true
        frozen_at=$((curr_time / 60))
        echo "  ⚠️  检测到画面静止: 第${frozen_at}分钟后画面不再变化 (diff=$diff)"
        break
      fi
    else
      # 简单判断：比较文件大小
      local prev_size=$(stat -f%z "$prev_frame" 2>/dev/null || stat -c%s "$prev_frame" 2>/dev/null)
      local curr_size=$(stat -f%z "$curr_frame" 2>/dev/null || stat -c%s "$curr_frame" 2>/dev/null)
      local size_diff=$((prev_size - curr_size))
      [ $size_diff -lt 0 ] && size_diff=$((-size_diff))
      
      # 如果文件大小差异小于5%，认为画面相似
      local threshold=$((prev_size / 20))  # 5%
      if [ "$size_diff" -lt "$threshold" ]; then
        is_frozen=true
        frozen_at=$((curr_time / 60))
        echo "  ⚠️  检测到画面静止: 第${frozen_at}分钟后画面不再变化 (文件大小相似)"
        break
      fi
    fi
    
    prev_frame="$curr_frame"
  done
  
  # 清理临时文件
  rm -rf "$temp_dir"
  
  # 如果检测到提前结束，移动到“待优化视频”目录
  if [ "$is_frozen" = true ]; then
    local optimize_dir="${CHECK_VIDEO_ROOT_DIR}/待优化视频"
    if [ ! -d "$optimize_dir" ]; then
      mkdir -p "$optimize_dir"
      echo "  📁 创建目录: 待优化视频/"
    fi
    
    local dest_file="$optimize_dir/$filename"
    if [ -e "$dest_file" ]; then
      echo "  ⚠️  目标文件已存在，不移动"
      return 1
    fi
    
    if mv "$video_file" "$dest_file"; then
      echo "  📦 移动到: 待优化视频/$filename"
      return 2  # 返回2表示移动到待优化目录
    else
      echo "  ❌ 移动失败"
      return 1
    fi
  else
    echo "  ✅ 视频完整，无需优化"
    return 0
  fi
}

# 使用 Python3 进行批量 OCR 识别（内嵌逻辑）
perform_easyocr_batch() {
  local -a img_paths=("$@")  # 获取所有图片路径
  
  # 检查 Python3 是否可用
  if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: python3 未安装，无法运行OCR" >&2
    return 1
  fi
  
  # 执行内嵌的 Python 脚本
  python3 << 'PYTHON_EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os
import re

def extract_chinese_from_images(image_paths):
    try:
        import easyocr
        import cv2
        
        reader = easyocr.Reader(["ch_sim", "en"], gpu=False, verbose=False)
        results = {}
        
        for image_path in image_paths:
            if not os.path.exists(image_path):
                results[image_path] = []
                continue
            
            result = reader.readtext(image_path, 
                                    paragraph=False,
                                    text_threshold=0.5,
                                    low_text=0.3,
                                    link_threshold=0.3,
                                    canvas_size=2560,
                                    mag_ratio=1.5)
            
            img = cv2.imread(image_path)
            if img is None:
                results[image_path] = []
                continue
            
            img_height = img.shape[0]
            max_y_threshold = img_height * 0.7
            
            texts = []
            
            for detection in result:
                bbox = detection[0]
                text = detection[1]
                confidence = detection[2]
                
                y_pos = min([point[1] for point in bbox])
                
                if y_pos > max_y_threshold:
                    continue
                
                if re.match(r"^\d{1,2}:\d{2}", text):
                    continue
                if re.match(r"^\d+$", text):
                    continue
                
                ui_blacklist = [
                    "本场点赞", "点赞", "关注", "分享", "评论", "收藏",
                    "直播中", "回放", "送礼物", "礼物",
                    "人气榜", "热门", "推荐", "同城",
                ]
                if any(keyword in text for keyword in ui_blacklist):
                    continue
                
                chinese_text = "".join(re.findall(r"[\u4e00-\u9fa5]", text))
                english_text = "".join(re.findall(r"[a-zA-Z0-9]", text))
                
                has_both = bool(chinese_text) and bool(english_text)
                min_confidence = 0.005 if has_both else 0.05
                
                if confidence < min_confidence:
                    continue
                
                if any(keyword in text for keyword in ui_blacklist):
                    continue
                
                if chinese_text:
                    if any(keyword in chinese_text for keyword in ui_blacklist):
                        continue
                    if len(chinese_text) >= 2 or (len(chinese_text) == 1 and confidence > 0.3):
                        texts.append((chinese_text, y_pos, confidence))
                elif english_text:
                    if any(keyword in english_text for keyword in ui_blacklist):
                        continue
                    if len(english_text) >= 2:
                        texts.append((english_text, y_pos, confidence))
            
            texts.sort(key=lambda x: x[1])
            results[image_path] = texts
        
        return results
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return {}

if __name__ == "__main__":
    image_paths = sys.argv[1:]
    results = extract_chinese_from_images(image_paths)
    
    for image_path in image_paths:
        texts = results.get(image_path, [])
        if texts:
            text_strings = [f"{text}:{y:.1f}:{conf:.3f}" for text, y, conf in texts]
            print(f"{image_path}|{"|".join(text_strings)}")
        else:
            print(f"{image_path}|")
PYTHON_EOF
}

# 智能识别视频中的文字并重命名文件
ocr_rename_video() {
  local video_file="$1"
  local filename="$(basename "$video_file")"
  local dirname="$(dirname "$video_file")"
  local extension="${filename##*.}"
  local basename_no_ext="${filename%.*}"
  
  # 检查文件是否仍然存在（可能已被其他分片的处理过程重命名）
  if [ ! -f "$video_file" ]; then
    return 0
  fi
  
  # 检测是否为分片视频（如 IMG_0080_part_00_4k）
  local is_part_file=false
  local part_base=""
  local part_num=""
  local part_suffix=""
  if [[ "$basename_no_ext" =~ ^(.+)_part_([0-9]+)(.*)$ ]]; then
    is_part_file=true
    part_base="${BASH_REMATCH[1]}"
    part_num="${BASH_REMATCH[2]}"
    part_suffix="${BASH_REMATCH[3]}"
  fi
  
  # 检查 ffmpeg 是否可用
  if ! command -v ffmpeg &> /dev/null; then
    echo "❌ 错误: ffmpeg 未安装，无法处理视频"
    echo "   请使用 'brew install ffmpeg' 安装"
    return 1
  fi
  
  # 检查 Python3 是否可用
  if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: python3 未安装，无法运行OCR"
    return 1
  fi
  
  echo "🔍 处理: $filename"
  
  # 检查文件名是否已经包含中文字符（表示已经处理过）
  # 检查是否有 "中文-" 的格式
  if [ "$FORCE_RENAME" = false ]; then
    if echo "$basename_no_ext" | perl -C -ne 'exit(0) if /[\x{4e00}-\x{9fa5}]+-/; exit(1)' 2>/dev/null; then
      echo "  ✅ 文件名已包含用户名，跳过"
      return 0
    fi
  else
    echo "  🔄 强制重新识别模式"
  fi
  
  # 如果是分片视频的非首个文件（part_01, part_02 等），智能处理
  if [ "$is_part_file" = true ] && [ "$part_num" != "00" ]; then
    # 先检查是否已有重命名过的 part_00 文件（文件名中包含用户名前缀）
    local renamed_first_part=""
    for f in "$dirname"/*-${part_base}_part_00${part_suffix}.${extension}; do
      if [ -f "$f" ]; then
        renamed_first_part="$f"
        break
      fi
    done
    
    if [ -n "$renamed_first_part" ]; then
      # 从已重命名的首个分片文件名派生当前分片的新文件名
      local renamed_first_filename="$(basename "$renamed_first_part")"
      local renamed_first_base="${renamed_first_filename%.*}"
      local renamed_first_ext="${renamed_first_filename##*.}"
      
      # 将 _part_00 替换为当前分片的编号
      local new_part_base="${renamed_first_base/_part_00/_part_${part_num}}"
      local new_part_filename="${new_part_base}.${renamed_first_ext}"
      local new_part_filepath="$dirname/$new_part_filename"
      
      if [ "$filename" = "$new_part_filename" ]; then
        echo "  ✅ 文件名已正确，跳过"
        return 0
      fi
      
      if [ ! -e "$new_part_filepath" ]; then
        if mv "$video_file" "$new_part_filepath"; then
          echo "  ✅ 基于首个分片重命名: $filename -> $new_part_filename"
        else
          echo "  ❌ 重命名失败: $filename"
        fi
      else
        echo "  ⚠️  目标文件已存在: $new_part_filename"
      fi
      return 0
    fi
    
    # 检查原始 part_00 是否存在（还未被处理）
    local original_first_part="$dirname/${part_base}_part_00${part_suffix}.${extension}"
    if [ -f "$original_first_part" ]; then
      echo "  ⏭️  分片视频 (part_${part_num})，等待首个分片 (part_00) 处理"
      return 0
    fi
    
    # 既没有重命名的也没有原始的 part_00，作为独立文件进行OCR
    echo "  ℹ️  未找到首个分片 (part_00)，独立进行OCR识别"
  fi
  
  # 创建临时目录
  local temp_dir="$(mktemp -d)"
  
  # 精简采样：只采样关键帧（用户名通常在前3秒显示）
  local best_text=""
  local max_chinese_count=0
  
  # 采样时间点：前1秒内密集采样（0.05s, 0.1s, 0.2s, 0.3s, 0.4s, 0.5s, 0.6s, 0.8s, 1.0s）
  # 增加采样密度以提高用户名识别准确率
  local sample_times=(0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.8 1.0)
  local frame_imgs=()
  local i=0
  
  # 第一步：提取所有帧并预处理
  for ts in "${sample_times[@]}"; do
    i=$((i + 1))
    local frame_img_raw="$temp_dir/frame_raw_${i}.png"
    local frame_img="$temp_dir/frame_${i}.png"
    
    # 裁剪用户名区域：左上角，宽度为视频的60%，从 Y=60开始，高度180像素
    # 这样可以捕捉头像+用户名区域，同时过滤掉下方的"本场点赞"
    if ffmpeg -ss "$ts" -i "$video_file" -vf "crop=in_w*0.6:180:0:60" -vframes 1 -q:v 2 "$frame_img_raw" -y &>/dev/null 2>&1; then
      # 使用 ImageMagick 对图片进行预处理：放大 + 增强清晰度 + 优化字体识别
      if command -v magick &> /dev/null; then
        # 优化处理流程：
        # 1. 放大600%（更大的图像提供更多细节）
        # 2. 增强对比度（normalize）
        # 3. 更强的锐化（提升字体边缘清晰度）
        # 4. 轻微的降噪（减少干扰）
        magick "$frame_img_raw" -resize 600% -normalize -unsharp 0x1.5 -despeckle "$frame_img" 2>/dev/null
      elif command -v convert &> /dev/null; then
        # 兼容旧版ImageMagick
        convert "$frame_img_raw" -resize 600% -normalize -unsharp 0x1.5 -despeckle "$frame_img" 2>/dev/null
      else
        # 如果没有ImageMagick，直接使用原图
        cp "$frame_img_raw" "$frame_img"
      fi
      
      if [ -f "$frame_img" ]; then
        frame_imgs+=("$frame_img")
      fi
      rm -f "$frame_img_raw"
    fi
  done
  
  # 第二步：批量OCR识别（只初始化一次EasyOCR模型）
  local best_confidence=0
  local -a candidates=()  # 候选项数组："text|confidence|timestamp"
  local -a candidate_display=()  # 用于显示的数组
  
  if [ ${#frame_imgs[@]} -gt 0 ]; then
    # 调用内嵌的 OCR 批量处理函数
    local batch_result=$(perform_easyocr_batch "${frame_imgs[@]}" 2>/dev/null)
    
    # 解析批量结果，收集所有候选项
    while IFS='|' read -r img_path text_info rest; do
      # 提取时间戳（从文件名中）
      local frame_num=$(basename "$img_path" .png | sed 's/frame_//' | grep -o '[0-9]\+')
      # 验证 frame_num 是否为有效数字
      if [ -z "$frame_num" ] || ! [[ "$frame_num" =~ ^[0-9]+$ ]]; then
        continue
      fi
      # 验证数组索引范围
      local array_index=$((frame_num - 1))
      if [ $array_index -lt 0 ] || [ $array_index -ge ${#sample_times[@]} ]; then
        continue
      fi
      local ts=${sample_times[$array_index]}
      
      if [ -n "$text_info" ]; then
        # 解析 text:y:conf 格式
        local text=$(echo "$text_info" | cut -d':' -f1)
        local y_pos=$(echo "$text_info" | cut -d':' -f2)
        local confidence=$(echo "$text_info" | cut -d':' -f3)
        
        echo "  📝 ${ts}s: $text (Y=${y_pos}, conf=${confidence})"
        
        # 过滤条件：
        # 1. 依赖Python黑名单过滤UI文本（如"本场点赞"），不再使用Y坐标过滤
        # 2. 长度合理：2-20个字符（过滤单个字符的噪声）
        # 3. 置信度 > 0.15
        local y_threshold=1000  # 不限制Y坐标
        local part_length=${#text}
        
        if [ "$(echo "$y_pos < $y_threshold" | bc)" -eq 1 ] && \
           [ $part_length -ge 2 ] && [ $part_length -le 20 ] && \
           [ "$(echo "$confidence > 0.15" | bc)" -eq 1 ]; then
          
          # 检查是否已经存在该候选项（去重）
          local already_exists=false
          for candidate in "${candidates[@]}"; do
            local existing_text=$(echo "$candidate" | cut -d'|' -f1)
            if [ "$existing_text" = "$text" ]; then
              already_exists=true
              break
            fi
          done
          
          if [ "$already_exists" = false ]; then
            # 存储时包含Y坐标，用于后续排序
            candidates+=("$text|$confidence|$ts|$y_pos")
            candidate_display+=("$text (时间:${ts}s, 置信度:${confidence}, Y:${y_pos})")
          fi
        else
          echo "    ⏭️  过滤：Y=${y_pos} (过低) 或 置信度过低"
        fi
      fi
    done <<< "$batch_result"
  fi
  
  # 处理候选项
  local best_text=""
  if [ ${#candidates[@]} -eq 0 ]; then
    # 没有候选项
    best_text=""
  elif [ ${#candidates[@]} -eq 1 ]; then
    # 只有一个候选项，直接使用
    best_text=$(echo "${candidates[0]}" | cut -d'|' -f1)
    echo "  ✅ 自动采用: '$best_text'"
  else
    # 有多个候选项 - 按Y坐标（上方优先）和置信度排序
    local -a sorted_candidates=()
    local -a sorted_display=()
    
    # 使用冒泡排序
    for i in "${!candidates[@]}"; do
      sorted_candidates+=( "${candidates[$i]}" )
      sorted_display+=( "${candidate_display[$i]}" )
    done
    
    for ((i = 0; i < ${#sorted_candidates[@]}; i++)); do
      for ((j = i + 1; j < ${#sorted_candidates[@]}; j++)); do
        local conf_i=$(echo "${sorted_candidates[$i]}" | cut -d'|' -f2)
        local conf_j=$(echo "${sorted_candidates[$j]}" | cut -d'|' -f2)
        local y_i=$(echo "${sorted_candidates[$i]}" | cut -d'|' -f4)
        local y_j=$(echo "${sorted_candidates[$j]}" | cut -d'|' -f4)
        
        # 排序逻辑：
        # 1. 如果置信度差异大于0.3，优先选置信度高的
        # 2. 否则优先选Y坐标小的（位置靠上）
        local conf_diff=$(echo "$conf_j - $conf_i" | bc -l)
        local should_swap=0
        
        if (( $(echo "$conf_diff > 0.3" | bc -l) )); then
          # 置信度差异大，优先选置信度高的
          should_swap=1
        elif (( $(echo "$conf_diff < -0.3" | bc -l) )); then
          # 置信度差异大，不交换
          should_swap=0
        else
          # 置信度相近，比较Y坐标（越小越靠上，越优先）
          if (( $(echo "$y_j < $y_i" | bc -l) )); then
            should_swap=1
          fi
        fi
        
        if [ $should_swap -eq 1 ]; then
          # 交换
          local temp="${sorted_candidates[$i]}"
          sorted_candidates[$i]="${sorted_candidates[$j]}"
          sorted_candidates[$j]="$temp"
          
          temp="${sorted_display[$i]}"
          sorted_display[$i]="${sorted_display[$j]}"
          sorted_display[$j]="$temp"
        fi
      done
    done
    
    # 更新原数组
    candidates=( "${sorted_candidates[@]}" )
    candidate_display=( "${sorted_display[@]}" )
    
    if [ "$FORCE_AUTO_SELECT" = true ]; then
      # 强制模式：自动选择置信度最高的（第一个）
      best_text=$(echo "${candidates[0]}" | cut -d'|' -f1)
      local conf=$(echo "${candidates[0]}" | cut -d'|' -f2)
      echo "  ✅ 自动采用最高置信度结果: '$best_text' (conf=$conf)"
    else
      # 交互模式：让用户选择
      echo
      echo "  🤔 检测到多个可能的用户名，请选择："
      echo
      
      # 添加"跳过"选项到候选列表
      local -a menu_items=()
      menu_items+=("${candidate_display[@]}")
      menu_items+=("跳过此文件")
      
      local selected=0
      local menu_size=${#menu_items[@]}
      
      # 显示菜单的函数
      show_menu() {
        local current=$1
        # 清屏并移动光标到菜单开始位置
        tput sc  # 保存光标位置
        
        for i in "${!menu_items[@]}"; do
          if [ $i -eq $current ]; then
            echo -e "    ➤ \033[1;32m${menu_items[$i]}\033[0m"  # 选中项（绿色加粗）
          else
            echo "      ${menu_items[$i]}"
          fi
        done
        
        echo
        echo "  ℹ️  使用 ↑/↓ 选择，Enter 确认，Esc 跳过"
      }
      
      # 清除菜单显示的函数
      clear_menu() {
        tput rc  # 恢复光标位置
        for i in "${!menu_items[@]}"; do
          tput el  # 清除当前行
          tput cud1  # 下移一行
        done
        tput el  # 清除提示行
        tput cud1
        tput el
        tput rc  # 回到开始位置
      }
      
      # 显示初始菜单
      show_menu $selected
      
      # 读取按键
      while true; do
        # 读取一个字符，不显示，不等待回车
        IFS= read -rsn1 key
        
        case "$key" in
          $'\x1b')  # ESC 序列开始
            read -rsn2 key 2>/dev/null  # 读取后续字符
            case "$key" in
              '[A')  # 上箭头
                ((selected--))
                if [ $selected -lt 0 ]; then
                  selected=$((menu_size - 1))
                fi
                clear_menu
                show_menu $selected
                ;;
              '[B')  # 下箭头
                ((selected++))
                if [ $selected -ge $menu_size ]; then
                  selected=0
                fi
                clear_menu
                show_menu $selected
                ;;
              '')  # 只有ESC，没有后续字符
                # ESC 键 - 跳过
                echo
                echo "  ⏭️  已跳过"
                best_text=""
                break
                ;;
            esac
            ;;
          '')  # Enter 键
            echo
            if [ $selected -eq $((menu_size - 1)) ]; then
              # 选择了"跳过"
              echo "  ⏭️  已跳过"
              best_text=""
            else
              # 选择了某个候选项
              best_text=$(echo "${candidates[$selected]}" | cut -d'|' -f1)
              echo "  ✅ 已选择: '$best_text'"
            fi
            break
            ;;
        esac
      done
      echo
    fi
  fi
  
  # 清理所有帧图片
  for frame_img in "${frame_imgs[@]}"; do
    rm -f "$frame_img"
  done
  
  # 清理临时文件
  rm -rf "$temp_dir"
  
  # 检查是否识别到文字
  if [ -z "$best_text" ]; then
    echo "  ⚠️  未识别到有效文字"
    
    # 创建“未成功分类”目录（始终在根目录下创建）
    local unclassified_dir="${OCR_ROOT_DIR}/未成功分类"
    if [ ! -d "$unclassified_dir" ]; then
      mkdir -p "$unclassified_dir"
      echo "  📁 创建目录: 未成功分类/"
    fi
    
    # 移动文件到未成功分类目录
    local dest_file="$unclassified_dir/$filename"
    if [ -e "$dest_file" ]; then
      echo "  ⚠️  目标文件已存在，不移动"
      return 1
    fi
    
    if mv "$video_file" "$dest_file"; then
      echo "  📦 移动到: 未成功分类/$filename"
      
      # 如果是分片视频，同时移动同组的其他分片到未成功分类
      if [ "$is_part_file" = true ]; then
        for sibling in "$dirname"/*${part_base}_part_*${part_suffix}.${extension}; do
          if [ -f "$sibling" ]; then
            local sib_filename="$(basename "$sibling")"
            local sib_basename_no_ext="${sib_filename%.*}"
            # 验证是否为同组的有效分片
            if [[ "$sib_basename_no_ext" =~ ${part_base}_part_[0-9]+${part_suffix}$ ]]; then
              local sib_dest="$unclassified_dir/$sib_filename"
              if [ ! -e "$sib_dest" ]; then
                if mv "$sibling" "$sib_dest"; then
                  echo "  📦 分片移动: $sib_filename -> 未成功分类/"
                fi
              fi
            fi
          fi
        done
      fi
      
      return 2  # 返回2表示移动到未分类目录
    else
      echo "  ❌ 移动失败"
      return 1
    fi
  fi
  
  # 检查识别结果长度（允许单字用户名）
  if [ ${#best_text} -lt 1 ]; then
    echo "  ⚠️  识别结果过短: '$best_text'"
    return 1
  fi
  
  echo "  📝 识别到: $best_text"
  
  # 生成新文件名
  # 如果是强制重命名模式，需要先移除旧的用户名前缀
  local clean_basename="$basename_no_ext"
  if [ "$FORCE_RENAME" = true ]; then
    # 移除旧的 "中文-" 或 "英文数字-" 前缀（匹配一个或多个字符）
    clean_basename=$(echo "$basename_no_ext" | perl -C -pe 's/^[\x{4e00}-\x{9fa5}a-zA-Z0-9]+-//')
  fi
  
  local new_filename="${best_text}-${clean_basename}.${extension}"
  local new_filepath="$dirname/$new_filename"
  
  # 检查是否需要重命名
  if [ "$filename" = "$new_filename" ]; then
    echo "  ✅ 文件名无需更改，跳过"
    return 0
  fi
  
  # 检查新文件名是否已存在
  if [ -e "$new_filepath" ]; then
    echo "  ⚠️  目标文件已存在: $new_filename"
    return 1
  fi
  
  # 重命名文件
  if mv "$video_file" "$new_filepath"; then
    echo "  ✅ 重命名: $filename -> $new_filename"
    
    # 如果是分片视频，自动重命名同组的其他分片
    if [ "$is_part_file" = true ]; then
      local sibling_count=0
      for sibling in "$dirname"/*${part_base}_part_*${part_suffix}.${extension}; do
        if [ -f "$sibling" ] && [ "$sibling" != "$new_filepath" ]; then
          local sib_filename="$(basename "$sibling")"
          local sib_basename_no_ext="${sib_filename%.*}"
          local sib_ext="${sib_filename##*.}"
          
          # 验证是否为同组的有效分片并提取分片编号
          if [[ "$sib_basename_no_ext" =~ ${part_base}_part_([0-9]+)${part_suffix}$ ]]; then
            local sib_part_num="${BASH_REMATCH[1]}"
            
            # 从当前文件的新名称派生分片的新名称（替换分片编号）
            local new_base="${new_filename%.*}"
            local sib_new_base="${new_base/_part_${part_num}/_part_${sib_part_num}}"
            local sib_new_filename="${sib_new_base}.${sib_ext}"
            local sib_new_filepath="$dirname/$sib_new_filename"
            
            if [ "$sib_filename" != "$sib_new_filename" ] && [ ! -e "$sib_new_filepath" ]; then
              if mv "$sibling" "$sib_new_filepath"; then
                echo "  ✅ 分片重命名: $sib_filename -> $sib_new_filename"
                ((sibling_count++))
              else
                echo "  ❌ 分片重命名失败: $sib_filename"
              fi
            fi
          fi
        fi
      done
      
      if [ $sibling_count -gt 0 ]; then
        echo "  🔗 共重命名 $sibling_count 个关联分片"
      fi
    fi
    
    return 0
  else
    echo "  ❌ 重命名失败"
    return 1
  fi
}

# 为目录设置视频截图作为图标
set_folder_icon_from_video() {
  local dir="$1"
  local force="${2:-false}"  # 第二个参数：是否强制设置（默认false）
  local dir_basename="$(basename "$dir")"
  
  # 检查目录是否还存在（可能已被重命名）
  if [ ! -d "$dir" ]; then
    return 0
  fi
  
  # 查找目录下的第一个视频文件
  local video_file=""
  local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
  
  for ext in "${VIDEO_EXTS[@]}"; do
    video_file=$(find "$dir" -maxdepth 1 -type f -name "*.$ext" 2>/dev/null | head -n 1)
    if [ -n "$video_file" ]; then
      break
    fi
  done
  
  if [ -z "$video_file" ]; then
    if [ "$force" = true ]; then
      echo "⚠️  跳过（无视频）: $dir_basename"
    fi
    return 0  # 没有视频文件，跳过
  fi
  
  # 检查是否已经有自定义图标
  if [ -f "$dir/Icon"$'\r' ]; then
    # 如果不是强制刷新模式，跳过
    if [ "$FORCE_REFRESH_ICON" = false ]; then
      if [ "$force" = true ]; then
        echo "⏭️  跳过（已有图标）: $dir_basename"
      fi
      return 0  # 已有图标，跳过
    else
      # 强制刷新模式：先删除旧图标
      if [ "$force" = true ]; then
        echo "🔄 刷新图标: $dir_basename"
      fi
      rm -f "$dir/Icon"$'\r' 2>/dev/null
    fi
  fi
  
  # 检查 ffmpeg 是否可用
  if ! command -v ffmpeg &> /dev/null; then
    if [ "$force" = true ]; then
      echo "❌ 错误: ffmpeg 未安装，无法设置图标"
      echo "   请使用 'brew install ffmpeg' 安装"
    fi
    return 1
  fi
  
  # 创建临时文件
  local temp_img="$(mktemp -u).png"
  
  # 使用 ffmpeg 提取视频第一帧（1秒处，避免黑屏）
  if ffmpeg -ss 00:00:01 -i "$video_file" -vframes 1 -q:v 2 "$temp_img" -y &>/dev/null; then
    # 生成 512x512 的图标
    local icon_img="$(mktemp -u).png"
    sips -z 512 512 "$temp_img" --out "$icon_img" &>/dev/null
    
    # 创建 iconset 目录
    local icon_dir="$(mktemp -d)"
    local iconset_dir="$icon_dir/icon.iconset"
    mkdir -p "$iconset_dir"
    
    # 生成不同尺寸的图标
    sips -z 16 16 "$icon_img" --out "$iconset_dir/icon_16x16.png" &>/dev/null
    sips -z 32 32 "$icon_img" --out "$iconset_dir/icon_16x16@2x.png" &>/dev/null
    sips -z 32 32 "$icon_img" --out "$iconset_dir/icon_32x32.png" &>/dev/null
    sips -z 64 64 "$icon_img" --out "$iconset_dir/icon_32x32@2x.png" &>/dev/null
    sips -z 128 128 "$icon_img" --out "$iconset_dir/icon_128x128.png" &>/dev/null
    sips -z 256 256 "$icon_img" --out "$iconset_dir/icon_128x128@2x.png" &>/dev/null
    sips -z 256 256 "$icon_img" --out "$iconset_dir/icon_256x256.png" &>/dev/null
    sips -z 512 512 "$icon_img" --out "$iconset_dir/icon_256x256@2x.png" &>/dev/null
    sips -z 512 512 "$icon_img" --out "$iconset_dir/icon_512x512.png" &>/dev/null
    cp "$icon_img" "$iconset_dir/icon_512x512@2x.png" &>/dev/null
    
    # 转换为 .icns
    local icns_file="$icon_dir/Icon.icns"
    iconutil -c icns "$iconset_dir" -o "$icns_file" &>/dev/null
    if [ -f "$icns_file" ]; then
      # 检查 fileicon 工具是否可用
      if ! command -v fileicon &> /dev/null; then
        if [ "$force" = true ]; then
          echo "❌ 错误: fileicon 工具未安装"
          echo "   请使用 'brew install fileicon' 安装"
        fi
        rm -rf "$icon_dir" "$temp_img" "$icon_img" 2>/dev/null
        return 1
      fi
      
      # 使用 fileicon 工具设置文件夹图标
      if fileicon set "$dir" "$icns_file" &>/dev/null; then
        echo "🖼️  设置图标: $dir_basename"
      else
        if [ "$force" = true ]; then
          echo "❌ 错误: 无法设置图标 - $dir_basename"
        fi
      fi
    else
      if [ "$force" = true ]; then
        echo "❌ 错误: 无法创建图标文件 - $dir_basename"
      fi
    fi
    # 清理临时文件
    rm -rf "$icon_dir" "$temp_img" "$icon_img" 2>/dev/null
  else
    if [ "$force" = true ]; then
      echo "❌ 错误: ffmpeg 处理失败 - $dir_basename"
    fi
    # 清理可能生成的临时文件
    rm -f "$temp_img" 2>/dev/null
  fi
}

# 读取 Finder 标签的辅助函数
get_finder_tags() {
  local file_path="$1"
  # 使用 mdls 读取 Finder 标签
  local tags_raw=$(mdls -name kMDItemUserTags -raw "$file_path" 2>/dev/null)
  if [ -z "$tags_raw" ] || [ "$tags_raw" = "(null)" ]; then
    echo ""
    return
  fi
  # 使用 perl 解码 Unicode 并格式化为逗号分隔
  echo "$tags_raw" | perl -pe 's/\\U([0-9a-fA-F]{4})/chr(hex($1))/ge' 2>/dev/null | sed 's/[(),"]//g' | tr -s ' \n' ',' | sed 's/^,\|,$//g'
}

# 基于标签的智能视频分类（优化版 - 添加缓存）
classify_videos_by_tags() {
  local source_dir="$1"
  local target_dir="$2"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🏷️  基于标签的智能视频分类"
  echo "源目录: $source_dir"
  echo "目标目录: $target_dir"
  echo
  
  # 检查 mdls 命令是否可用（macOS 系统命令）
  if ! command -v mdls &> /dev/null; then
    echo "❌ 错误: mdls 命令不可用，请确认运行在 macOS 系统上"
    return 1
  fi
  
  # 定义视频文件扩展名
  local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
  
  # 统计信息
  local moved=0
  local skipped=0
  local errors=0
  local no_tag=0
  local no_match=0
  
  # 🚀 优化1: 预先缓存所有【】目录及其标签
  echo "🔍 预扫描目标目录..."
  # 使用临时文件存储映射（兼容 bash 3.x）
  local bracket_cache=$(mktemp)
  local dy_cache=$(mktemp)
  
  local start_time=$(date +%s)
  while IFS= read -r bracket_dir; do
    local tags=$(get_finder_tags "$bracket_dir")
    # 存储格式: bracket_dir|tags
    echo "$bracket_dir|$tags" >> "$bracket_cache"
    echo "  📁 $(basename "$bracket_dir"): $tags"
  done < <(find "$target_dir" -maxdepth 1 -type d -name "【*】*" 2>/dev/null)
  
  local bracket_count=$(wc -l < "$bracket_cache" | tr -d ' ')
  local scan_time=$(($(date +%s) - start_time))
  echo "  ✅ 扫描完成，找到 ${bracket_count} 个目标目录 (耗时: ${scan_time}s)"
  echo
  
  # 🚀 优化2: 预先构建 DY- 目录映射
  echo "🔍 构建 DY- 目录映射..."
  
  start_time=$(date +%s)
  while IFS='|' read -r bracket_dir bracket_tags; do
    while IFS= read -r dy_dir; do
      local dy_basename=$(basename "$dy_dir")
      # 提取关键词（去掉 DY- 前缀和大小标签）
      if [[ "$dy_basename" =~ ^DY-(.+)$ ]]; then
        local full_keyword="${BASH_REMATCH[1]}"
        local keyword=$(echo "$full_keyword" | sed 's/（[^（]*）$//')
        # 存储格式: bracket_dir|keyword|dy_dir
        echo "$bracket_dir|$keyword|$dy_dir" >> "$dy_cache"
      fi
    done < <(find "$bracket_dir" -maxdepth 1 -type d -name "DY-*" 2>/dev/null)
  done < "$bracket_cache"
  
  local dy_count=$(wc -l < "$dy_cache" | tr -d ' ')
  scan_time=$(($(date +%s) - start_time))
  echo "  ✅ 映射完成，共 ${dy_count} 个 DY- 目录 (耗时: ${scan_time}s)"
  echo
  
  # 🚀 优化3: 将缓存文件加载到关联数组（使用awk预处理）
  echo "🔍 加载缓存到内存..."
  # 创建快速查找表：keyword|tag -> dy_dir
  local lookup_cache=$(mktemp)
  
  # 预处理：构建 keyword|tag -> target_path 的映射
  while IFS='|' read -r bracket_dir bracket_tags; do
    if [ -n "$bracket_tags" ]; then
      # 将标签拆分
      IFS=',' read -ra tags <<< "$bracket_tags"
      for tag in "${tags[@]}"; do
        tag=$(echo "$tag" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$tag" ]; then
          # 查找该bracket_dir下的所有DY-目录
          while IFS='|' read -r cached_bracket cached_keyword cached_dy_dir; do
            if [ "$cached_bracket" = "$bracket_dir" ]; then
              # 存储: keyword|tag -> dy_dir
              echo "$cached_keyword|$tag|$cached_dy_dir" >> "$lookup_cache"
            fi
          done < "$dy_cache"
          # 同时存储bracket_dir本身（用于fallback）
          echo "|$tag|$bracket_dir" >> "$lookup_cache"
        fi
      done
    fi
  done < "$bracket_cache"
  
  echo "  ✅ 缓存加载完成"
  echo
  
  # 扫描源目录中的视频文件（只扫描根层级，不递归）
  echo "=== 扫描源视频文件 ==="
  local processed=0
  start_time=$(date +%s)
  
  find "$source_dir" -maxdepth 1 -type f | while IFS= read -r video_file; do
    local filename="$(basename "$video_file")"
    local extension="${filename##*.}"
    
    # 检查是否为视频文件
    local is_video=false
    for ext in "${VIDEO_EXTS[@]}"; do
      if [ "$extension" = "$ext" ]; then
        is_video=true
        break
      fi
    done
    
    if [ "$is_video" = false ]; then
      continue
    fi
    
    ((processed++))
    
    # 每20个文件显示一次进度（减少日志输出）
    if [ $((processed % 20)) -eq 0 ]; then
      local elapsed=$(($(date +%s) - start_time))
      echo "⏱️  已处理 ${processed} 个视频 (${elapsed}s)"
    fi
    
    # 读取视频文件的 Finder 标签
    local tags=$(get_finder_tags "$video_file")
    
    if [ -z "$tags" ]; then
      ((no_tag++))
      continue
    fi
    
    # 将逗号分隔的标签拆分成数组，并过滤空字符串
    IFS=',' read -ra tag_array_raw <<< "$tags"
    local tag_array=()
    for t in "${tag_array_raw[@]}"; do
      # 去除首尾空格并跳过空标签（使用bash内置功能，避免调用sed）
      t="${t#"${t%%[![:space:]]*}"}"
      t="${t%"${t##*[![:space:]]}"}" 
      if [ -n "$t" ]; then
        tag_array+=("$t")
      fi
    done
    
    # 检查是否有有效标签
    if [ ${#tag_array[@]} -eq 0 ]; then
      ((no_tag++))
      continue
    fi
    
    # 提取文件名中的关键词（- 之前的部分）
    local keyword=""
    if [[ "$filename" =~ ^([^-]+)- ]]; then
      keyword="${BASH_REMATCH[1]}"
    else
      ((errors++))
      continue
    fi
    
    # 🚀 使用预处理的查找表快速匹配
    local target_path=""
    local found_tag=""
    
    # 优先查找：keyword + tag 匹配的 DY- 目录
    for tag in "${tag_array[@]}"; do
      local search_key="$keyword|$tag|"
      local match=$(grep -m 1 "^$search_key" "$lookup_cache" 2>/dev/null)
      if [ -n "$match" ]; then
        target_path=$(echo "$match" | cut -d'|' -f3)
        found_tag="$tag"
        # 验证目录是否为DY-目录且存在
        if [[ "$(basename "$target_path")" =~ ^DY- ]] && [ -d "$target_path" ]; then
          break
        fi
      fi
    done
    
    # 如果没找到DY-目录，查找bracket目录作为fallback并创建DY-目录
    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      local bracket_dir=""
      for tag in "${tag_array[@]}"; do
        local search_key="|$tag|"
        local match=$(grep -m 1 "^$search_key" "$lookup_cache" 2>/dev/null)
        if [ -n "$match" ]; then
          bracket_dir=$(echo "$match" | cut -d'|' -f3)
          found_tag="$tag"
          if [ -d "$bracket_dir" ]; then
            # 找到了bracket目录，在其下创建DY-keyword目录
            target_path="$bracket_dir/DY-$keyword"
            if [ ! -d "$target_path" ]; then
              mkdir -p "$target_path"
              echo "  📁 创建目录: $(basename "$bracket_dir")/DY-$keyword"
            fi
            break
          fi
        fi
      done
    fi
    
    # 如果还是没有找到，说明没有匹配的目标
    if [ -z "$target_path" ] || [ ! -d "$target_path" ]; then
      ((no_match++))
      continue
    fi
    
    # 移动文件（如果目标已存在则覆盖）
    local dest_file="$target_path/$filename"
    
    if mv -f "$video_file" "$dest_file" 2>/dev/null; then
      ((moved++))
    else
      ((errors++))
    fi
  done
  
  # 清理临时文件
  rm -f "$bracket_cache" "$dy_cache" "$lookup_cache" 2>/dev/null
  
  local total_time=$(($(date +%s) - start_time))
  echo
  echo "✅ 分类完成: 移动${moved}个 | 跳过${skipped}个 | 错误${errors}个 | 无标签${no_tag}个 | 未匹配${no_match}个"
  echo "⏱️  总耗时: ${total_time}秒"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
}

# 创建基于标签的符号链接视图
create_tag_based_symlink_view() {
  local source_dir="$1"
  local target_base="$source_dir/DY-分类浏览"
  
  # 检查 mdls 命令是否可用（macOS 系统命令）
  if ! command -v mdls &> /dev/null; then
    echo "⚠️  警告: mdls 命令不可用，跳过创建 DY-分类浏览"
    echo "请确认运行在 macOS 系统上"
    return 0
  fi
  
  # 清理旧的聚合目录（包括可能带大小标签的版本）
  find "$source_dir" -maxdepth 1 -type d -name "DY-分类浏览*" 2>/dev/null | while IFS= read -r old_dir; do
    rm -rf "$old_dir"
  done
  mkdir -p "$target_base"
  
  local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
  local linked_count=0
  
  echo "  🔍 扫描所有视频文件..."
  
  # 扫描并聚合视频文件（递归查找，包括【】目录下的DY-子目录）
  for ext in "${VIDEO_EXTS[@]}"; do
    find "$source_dir" -type f -iname "*.$ext" 2>/dev/null | while read -r file; do
      # 跳过 DY-分类浏览 目录内的文件
      if [[ "$file" =~ DY-分类浏览 ]]; then
        continue
      fi
      
      # 读取文件的 Finder 标签（使用 get_finder_tags 函数）
      local tags=$(get_finder_tags "$file")
      
      if [[ -n "$tags" ]]; then
        # 将逗号分隔的标签拆分成数组
        IFS=',' read -ra tag_array <<< "$tags"
        
        # 如果有标签，为每个标签创建链接
        for tagname in "${tag_array[@]}"; do
          # 去除首尾空格
          tagname=$(echo "$tagname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -n "$tagname" ]]; then
            # 创建标签对应的目录
            local tag_dir="$target_base/$tagname"
            mkdir -p "$tag_dir"
            
            # 转换为绝对路径并创建符号链接
            local abs_file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
            ln -sf "$abs_file" "$tag_dir/$(basename "$file")"
            ((linked_count++))
          fi
        done
      fi
    done
  done
  
  # 扫描并聚合带标签的文件夹（排除 DY-分类浏览 自身）
  find "$source_dir" -type d -name "DY-*" 2>/dev/null | while read -r folder; do
    # 跳过 DY-分类浏览 目录自身
    local folder_basename="$(basename "$folder")"
    if [[ "$folder_basename" =~ ^DY-分类浏览 ]]; then
      continue
    fi
    
    # 读取文件夹的 Finder 标签（使用 get_finder_tags 函数）
    local tags=$(get_finder_tags "$folder")
    
    if [[ -n "$tags" ]]; then
      # 将逗号分隔的标签拆分成数组
      IFS=',' read -ra tag_array <<< "$tags"
      
      # 为每个标签处理
      for tagname in "${tag_array[@]}"; do
        # 去除首尾空格
        tagname=$(echo "$tagname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$tagname" ]]; then
          local tag_dir="$target_base/$tagname"
          mkdir -p "$tag_dir"
          
          # 链接该文件夹内的所有视频
          for ext in "${VIDEO_EXTS[@]}"; do
            find "$folder" -type f -iname "*.$ext" 2>/dev/null | while read -r video; do
              # 转换为绝对路径并创建符号链接
              local abs_video="$(cd "$(dirname "$video")" && pwd)/$(basename "$video")"
              ln -sf "$abs_video" "$tag_dir/$(basename "$video")"
            done
          done
        fi
      done
    fi
  done
  
  # 统计报告
  if [[ -d "$target_base" ]]; then
    local tag_count=0
    local total_links=0
    for tag_dir in "$target_base"/*; do
      if [[ -d "$tag_dir" ]]; then
        ((tag_count++))
        local file_count=$(find "$tag_dir" -type l 2>/dev/null | wc -l | xargs)
        total_links=$((total_links + file_count))
      fi
    done
    echo "  ✅ 已创建 ${tag_count} 个标签分类，共 ${total_links} 个视频链接"
  fi
}

# 从源目录提取视频文件到目标目录的【】文件夹
extract_videos_from_source() {
  local source_dir="$1"
  local target_dir="$2"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "从源目录提取视频文件"
  echo "源目录: $source_dir"
  echo "目标目录: $target_dir"
  echo
  
  # 定义视频文件扩展名
  local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
  
  # 统计信息
  local moved=0
  local skipped=0
  local errors=0
  local no_match=0
  
  # 1. 处理源目录中的 DY- 目录
  echo "=== 处理 DY- 目录 ==="
  find "$source_dir" -type d -name "DY-*" | while IFS= read -r source_dy_dir; do
    local dy_basename="$(basename "$source_dy_dir")"
    
    # 提取 DY- 后面的关键词（去掉可能的大小标签）
    if [[ "$dy_basename" =~ ^DY-(.+)$ ]]; then
      local full_keyword="${BASH_REMATCH[1]}"
      # 去掉大小标签，得到纯关键词
      local keyword="$(echo "$full_keyword" | sed 's/（[^（]*）$//')"
      
      echo "处理源目录: $dy_basename"
      
      # 在目标目录的【】文件夹下查找匹配的 DY-关键词 目录
      local target_dy_dir=""
      local matched=false
      
      while IFS= read -r bracket_dir; do
        # 在【】目录下查找 DY-关键词 格式的目录
        while IFS= read -r dy_dir; do
          if [ -d "$dy_dir" ]; then
            target_dy_dir="$dy_dir"
            matched=true
            break 2
          fi
        done < <(find "$bracket_dir" -maxdepth 1 -type d -name "DY-${keyword}*")
      done < <(find "$target_dir" -maxdepth 1 -type d -name "【*】*")
      
      if [ "$matched" = false ]; then
        echo "  ⚠️  找不到目标目录: DY-${keyword}"
        ((no_match++))
        continue
      fi
      
      echo "  → 目标: $(basename "$(dirname "$target_dy_dir")") / $(basename "$target_dy_dir")/"
      
      # 遍历源DY-目录下的所有视频文件
      find "$source_dy_dir" -maxdepth 1 -type f | while IFS= read -r file; do
        local filename="$(basename "$file")"
        local extension="${filename##*.}"
        
        # 检查是否为视频文件
        local is_video=false
        for ext in "${VIDEO_EXTS[@]}"; do
          if [ "$extension" = "$ext" ]; then
            is_video=true
            break
          fi
        done
        
        if [ "$is_video" = false ]; then
          continue
        fi
        
        # 移动视频文件
        local dest_file="$target_dy_dir/$filename"
        
        if [ -e "$dest_file" ]; then
          echo "    ⚠️  跳过: $filename (目标已存在)"
          ((skipped++))
        else
          if mv "$file" "$dest_file"; then
            echo "    ✅ 移动: $filename"
            ((moved++))
          else
            echo "    ❌ 错误: 无法移动 $filename"
            ((errors++))
          fi
        fi
      done
      
      echo
    fi
  done
  
  # 2. 处理源目录中的散装视频文件（只查找直接包含的文件，不包括DY-子目录）
  echo "=== 处理散装视频文件 ==="
  find "$source_dir" -maxdepth 1 -type f | while IFS= read -r file; do
    local filename="$(basename "$file")"
    local extension="${filename##*.}"
    
    # 检查是否为视频文件
    local is_video=false
    for ext in "${VIDEO_EXTS[@]}"; do
      if [ "$extension" = "$ext" ]; then
        is_video=true
        break
      fi
    done
    
    if [ "$is_video" = false ]; then
      continue
    fi
    
    # 提取文件名中 - 之前的关键词
    # 例如：爆炸小脑袋-IMG_1263.MP4 -> 爆炸小脑袋
    if [[ ! "$filename" =~ ^([^-]+)- ]]; then
      continue  # 静默跳过不符合命名规范的文件
    fi
    
    local keyword="${BASH_REMATCH[1]}"
    
    echo "处理散装视频: $filename"
    
    # 在目标目录的【】文件夹下查找匹配的 DY-关键词 目录
    local target_dy_dir=""
    local matched=false
    
    while IFS= read -r bracket_dir; do
      while IFS= read -r dy_dir; do
        if [ -d "$dy_dir" ]; then
          target_dy_dir="$dy_dir"
          matched=true
          break 2
        fi
      done < <(find "$bracket_dir" -maxdepth 1 -type d -name "DY-${keyword}*")
    done < <(find "$target_dir" -maxdepth 1 -type d -name "【*】*")
    
    if [ "$matched" = false ]; then
      echo "  ⚠️  找不到目标目录: DY-${keyword}"
      ((no_match++))
      continue
    fi
    
    echo "  → 目标: $(basename "$(dirname "$target_dy_dir")") / $(basename "$target_dy_dir")/"
    
    # 移动视频文件
    local dest_file="$target_dy_dir/$filename"
    
    if [ -e "$dest_file" ]; then
      echo "  ⚠️  跳过: $filename (目标已存在)"
      ((skipped++))
    else
      if mv "$file" "$dest_file"; then
        echo "  ✅ 移动: $filename"
        ((moved++))
      else
        echo "  ❌ 错误: 无法移动 $filename"
        ((errors++))
      fi
    fi
    
    echo
  done
  
  echo "提取完成: 移动${moved}个 跳过${skipped}个 错误${errors}个 未匹配${no_match}个目录"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
}

process_directory() {
  local target_dir="$1"
  local current_depth="$2"
  local dir_basename="$(basename "$target_dir")"
  
  # 如果启用标签分类模式，不执行正常的视频移动逻辑
  if [ "$TAG_CLASSIFY_MODE" = true ]; then
    return 0
  fi
  
  echo "━━ $(basename "$target_dir")"
  
  # 如果启用OCR模式，对视频文件进行OCR识别并重命名
  if [ "$OCR_RENAME_MODE" = true ]; then
    # 如果指定了OCR目标，检查是否匹配当前目录
    if [ -n "$OCR_TARGET" ]; then
      # 将OCR_TARGET转为绝对路径（如果不是绝对路径）
      local ocr_target_abs="$OCR_TARGET"
      if [[ ! "$OCR_TARGET" =~ ^/ ]]; then
        ocr_target_abs="$TARGET_DIR/$OCR_TARGET"
      fi
      
      # 如果指定的是单个文件
      if [ -f "$ocr_target_abs" ]; then
        # 检查文件是否在当前目录中
        local file_dir="$(dirname "$ocr_target_abs")"
        if [ "$file_dir" != "$target_dir" ]; then
          # 不在当前目录，跳过
          return 0
        fi
        
        # 处理该文件
        echo "🎯 处理指定文件: $(basename "$ocr_target_abs")"
        ocr_rename_video "$ocr_target_abs"
        echo
        return 0
      # 如果指定的是目录
      elif [ -d "$ocr_target_abs" ]; then
        # 检查是否匹配当前目录
        if [ "$ocr_target_abs" != "$target_dir" ]; then
          # 不匹配，跳过
          return 0
        fi
        # 匹配，继续处理下面的逻辑
      else
        # 文件或目录不存在，跳过
        return 0
      fi
    fi
    
    # 处理当前目录中的所有视频文件
    local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
    local ocr_success=0
    local ocr_failed=0
    
    # 使用find扫描视频文件（支持FILE_DEPTH深度）
    for ext in "${VIDEO_EXTS[@]}"; do
      find "$target_dir" -maxdepth "$FILE_DEPTH" -type f -name "*.$ext" 2>/dev/null | while IFS= read -r file; do
        if ocr_rename_video "$file"; then
          ((ocr_success++))
        else
          ((ocr_failed++))
        fi
      done
    done
    
    if [ $ocr_success -gt 0 ] || [ $ocr_failed -gt 0 ]; then
      echo "📊 OCR结果: 成功${ocr_success} 失败${ocr_failed}"
      echo
    fi
    
    # OCR模式下不执行其他操作，直接返回
    return 0
  fi
  
  # 如果当前目录是DY-开头的，跳过步骤1（不再移动视频文件）
  if [[ "$dir_basename" =~ ^DY- ]]; then
    : # DY-目录，跳过视频移动
  else
    # 只有在非DY-目录内才执行步骤1
# ============================================
# 新增功能：自动移动视频文件到 DY- 开头的目录
# ============================================

# 定义视频文件扩展名（支持大小写）
VIDEO_EXTENSIONS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")

# 统计信息
moved_count=0
skipped_count=0
error_count=0


# 使用find扫描视频文件（支持FILE_DEPTH深度）
for ext in "${VIDEO_EXTENSIONS[@]}"; do
  find "$target_dir" -maxdepth "$FILE_DEPTH" -type f -name "*.$ext" 2>/dev/null | while IFS= read -r file; do
    filename="$(basename "$file")"
    extension="${filename##*.}"
    
    # 提取文件名中的用户名（-号之前的部分）
    if [[ "$filename" =~ ^([^-]+)- ]]; then
        username="${BASH_REMATCH[1]}"
        
        # 查找是否已存在 DY-${username} 开头的目录（可能有大小标签）
        existing_dir=""
        for dir in "$target_dir"/DY-"${username}"*; do
            if [ -d "$dir" ]; then
                existing_dir="$dir"
                break
            fi
        done
        
        # 如果找到已存在的目录，使用它；否则创建新目录
        if [ -n "$existing_dir" ]; then
            target_video_dir="$existing_dir"
        else
            target_video_dir="$target_dir/DY-${username}"
            if mkdir "$target_video_dir"; then
                echo "📁 创建目录: DY-${username}/"
            else
                echo "❌ 错误: 无法创建目录 DY-${username}"
                ((error_count++))
                continue
            fi
        fi
        
        # 检查目标位置是否已存在同名文件
        if [ -e "$target_video_dir/$filename" ]; then
            echo "⚠️  跳过: $filename (目标位置已存在同名文件)"
            ((skipped_count++))
        else
            # 移动文件
            if mv "$file" "$target_video_dir/"; then
                echo "✅ 移动: $filename -> DY-${username}/"
                ((moved_count++))
            else
                echo "❌ 错误: 无法移动 $filename"
                ((error_count++))
            fi
        fi
    fi
  done
done

if [ $moved_count -gt 0 ] || [ $error_count -gt 0 ]; then
  echo "视频文件: 移动$moved_count 跳过$skipped_count 错误$error_count"
fi
fi  # 结束 DY
# 生成目录列表，每行格式：清理后的名字|完整路径
temp_file=$(mktemp)
find "$target_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r dir; do
  base="$(basename "$dir")"
  
  # 🛡️ 保护 DY-分类浏览 目录，不要处理它（无论是否有大小标签）
  if [[ "$base" =~ ^DY-分类浏览 ]]; then
    continue
  fi
  
  # 如果当前处理的是根目录且子目录不是【】包围，则跳过
  if [ "$current_depth" -eq 0 ]; then
    local target_base
    if [ "$target_dir" = "." ]; then
      target_base="$(basename "$(pwd)")"
    else
      target_base="$(basename "$target_dir")"
    fi
    if [[ ! "$target_base" =~ ^【.*】 ]] && [[ ! "$base" =~ ^【.*】 ]]; then
      continue
    fi
  fi
  
  # 去掉末尾的大小标签
  clean_name="$(printf '%s' "$base" | sed 's/（[^（]*）$//')"
  echo "$clean_name|$dir"
done | sort > "$temp_file"

# 逐行读取，找出同名的并合并
prev_clean=""
prev_dirs=()

while IFS='|' read -r clean_name dir_path; do
  if [ "$clean_name" = "$prev_clean" ]; then
    # 同名，添加到列表
    prev_dirs+=("$dir_path")
  else
    # 不同名，处理之前的一组
    if [ ${#prev_dirs[@]} -gt 1 ]; then
      # 有多个同名目录，进行合并
      merge_target_dir="${prev_dirs[0]}"
      
      # 统计总文件数
      local total_files=0
      for ((i=1; i<${#prev_dirs[@]}; i++)); do
        if [ -d "${prev_dirs[$i]}" ]; then
          local count=$(find "${prev_dirs[$i]}" -mindepth 1 -maxdepth 1 -not -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
          total_files=$((total_files + count))
        fi
      done
      
      echo "合并: $prev_clean (${#prev_dirs[@]}个目录, ${total_files}个文件)"
      
      # 将其他目录的内容移动到目标目录
      for ((i=1; i<${#prev_dirs[@]}; i++)); do
        src_dir="${prev_dirs[$i]}"
        
        if [ -d "$src_dir" ]; then
          # 🚀 优化: 先批量收集需要移动的文件
          local items_to_move=()
          while IFS= read -r -d '' item; do
            local item_name="$(basename "$item")"
            # 跳过 .DS_Store
            if [ "$item_name" = ".DS_Store" ]; then
              rm -f "$item" 2>/dev/null
              continue
            fi
            # 如果目标不存在，添加到移动列表
            if [ ! -e "$merge_target_dir/$item_name" ]; then
              items_to_move+=("$item")
            fi
          done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
          
          # 🚀 批量移动文件（更快）
          if [ ${#items_to_move[@]} -gt 0 ]; then
            mv "${items_to_move[@]}" "$merge_target_dir/" 2>/dev/null
          fi
          
          # 删除源目录
          rmdir "$src_dir" 2>/dev/null
        fi
      done
    fi
    
    # 开始新的一组
    prev_clean="$clean_name"
    prev_dirs=("$dir_path")
  fi
done < "$temp_file"

# 处理最后一组
if [ ${#prev_dirs[@]} -gt 1 ]; then
  merge_target_dir="${prev_dirs[0]}"
  
  # 统计总文件数
  local total_files=0
  for ((i=1; i<${#prev_dirs[@]}; i++)); do
    if [ -d "${prev_dirs[$i]}" ]; then
      local count=$(find "${prev_dirs[$i]}" -mindepth 1 -maxdepth 1 -not -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
      total_files=$((total_files + count))
    fi
  done
  
  echo "合并: $prev_clean (${#prev_dirs[@]}个目录, ${total_files}个文件)"
  
  for ((i=1; i<${#prev_dirs[@]}; i++)); do
    src_dir="${prev_dirs[$i]}"
    
    if [ -d "$src_dir" ]; then
      # 🚀 优化: 先批量收集需要移动的文件
      local items_to_move=()
      while IFS= read -r -d '' item; do
        local item_name="$(basename "$item")"
        # 跳过 .DS_Store
        if [ "$item_name" = ".DS_Store" ]; then
          rm -f "$item" 2>/dev/null
          continue
        fi
        # 如果目标不存在，添加到移动列表
        if [ ! -e "$merge_target_dir/$item_name" ]; then
          items_to_move+=("$item")
        fi
      done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
      
      # 🚀 批量移动文件（更快）
      if [ ${#items_to_move[@]} -gt 0 ]; then
        mv "${items_to_move[@]}" "$merge_target_dir/" 2>/dev/null
      fi
      
      # 删除源目录
      rmdir "$src_dir" 2>/dev/null
    fi
  done
fi

# 清理临时文件
rm -f "$temp_file"

# 遵历一级子文件夹
find "$target_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r dir; do

  base="$(basename "$dir")"
  parent="$(dirname "$dir")"
  
  # 🛡️ 保护 DY-分类浏览 目录，不要处理它（无论是否有大小标签）
  if [[ "$base" =~ ^DY-分类浏览 ]]; then
    continue
  fi
  
  # 如果当前处理的是根目录（比如 /Volumes/4TB ssd/）且子目录不是【】包围，则跳过
  # 但是如果已经在【】目录内部，则处理所有子目录（包括DY-开头的）
  if [ "$current_depth" -eq 0 ]; then
    # 检查 target_dir 的 basename 是否是【】包围
    local target_base
    if [ "$target_dir" = "." ]; then
      target_base="$(basename "$(pwd)")"
    else
      target_base="$(basename "$target_dir")"
    fi
    # 如果 target_dir 不是【】包围，且子目录也不是【】包围，则跳过
    if [[ ! "$target_base" =~ ^【.*】 ]] && [[ ! "$base" =~ ^【.*】 ]]; then
      continue
    fi
  fi

  #
  # 1. 去掉末尾的（xxx）
  #
  clean_name="$(printf '%s' "$base" | sed 's/（[^（]*）$//')"

  #
  # 2. 计算实际大小（确保 awk 不出问题）
  #
  size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')

  # du 如果返回空，说明目录权限问题或路径异常
  if [ -z "$size" ]; then
    echo "❌ 无法获取大小：$dir"
    continue
  fi

  #
  # 3. 拼接新名称
  #
  new_name="${clean_name}（${size}）"

  # 如果无需变化就跳过
  if [ "$base" = "$new_name" ]; then
    continue
  fi

  #
  # 4. 执行重命名
  #
  src="$parent/$base"
  dst="$parent/$new_name"

  if [ -e "$dst" ] && [ "$dst" != "$src" ]; then
    echo "⚠️ 目标已存在，跳过：$dst"
    continue
  fi

  echo "重命名: $base → $new_name"
  mv "$src" "$dst" 2>/dev/null || echo "  ❌ 失败"

done


  # 遍历一级子文件夹（重新扫描，因为目录可能已被重命名）
find "$target_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r dir; do
  # 检查目录是否存在（防止在重命名过程中被删除或合并）
  if [ ! -d "$dir" ]; then
    continue
  fi
  
  base="$(basename "$dir")"
  
  # 🛡️ 保护 DY-分类浏览 目录，不要处理它（无论是否有大小标签）
  if [[ "$base" =~ ^DY-分类浏览 ]]; then
    continue
  fi
  
  # 如果当前处理的是根目录且子目录不是【】包围，则跳过
  if [ "$current_depth" -eq 0 ]; then
    local target_base
    if [ "$target_dir" = "." ]; then
      target_base="$(basename "$(pwd)")"
    else
      target_base="$(basename "$target_dir")"
    fi
    if [[ ! "$target_base" =~ ^【.*】 ]] && [[ ! "$base" =~ ^【.*】 ]]; then
      continue
    fi
  fi
  
  # 如果使用了 -s 参数，显示所有目录
  if [ "$SHOW_HIDDEN" = true ]; then
    if chflags nohidden "$dir" 2>/dev/null; then
      echo "显示: $base"
    fi
  elif [ "$HIDE_EMPTY" = true ]; then
    # 使用了 -H 参数，隐藏空目录
    # 检查目录是否为空（忽略所有隐藏文件，包括.DS_Store）
    # 只统计非隐藏文件和非隐藏目录
    visible_count=$(find "$dir" -mindepth 1 \( -type f -o -type d \) -not -name ".*" -not -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$visible_count" -eq 0 ]; then
      # 目录为空（没有可见内容），设置为隐藏
      if ! [[ "$base" =~ ^\. ]]; then
        # 使用chflags设置隐藏属性（不打印日志）
        chflags hidden "$dir" 2>/dev/null
      fi
    else
      # 目录非空，移除隐藏属性
      chflags nohidden "$dir" 2>/dev/null
    fi
  else
    # 默认行为：显示所有目录（包括空目录）
    chflags nohidden "$dir" 2>/dev/null
  fi
done

}  # 结束 process_directory 函数

# ============================================
# 主程序逻辑
# ============================================

# 递归处理函数
process_recursively() {
  local dir="$1"
  local depth="$2"
  
  # 处理当前目录
  process_directory "$dir" "$depth"
  
  # 如果需要递归且还没达到最大深度
  if [ "$RECURSIVE" = true ] && [ "$depth" -lt "$MAX_DEPTH" ]; then
    local next_depth=$((depth + 1))
    # 先收集所有子目录到数组中（避免在遍历过程中目录被重命名导致路径失效）
    local subdirs=()
    while IFS= read -r subdir; do
      subdirs+=("$subdir")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    
    # 递归处理每个子目录
    for subdir in "${subdirs[@]}"; do
      # 检查目录是否仍然存在（可能在处理过程中被重命名或合并）
      if [ ! -d "$subdir" ]; then
        continue
      fi
      
      # 如果是第0层（一级目录），只处理【】包围的目录
      if [ "$depth" -eq 0 ]; then
        local basename="$(basename "$subdir")"
        # 检查是否以【开头且包含】
        if [[ "$basename" =~ ^【.*】 ]]; then
          process_recursively "$subdir" "$next_depth"
        else
          # 静默跳过非【】目录
          : 
        fi
      else
        # 其他层级不做限制
        process_recursively "$subdir" "$next_depth"
      fi
    done
  fi
}

# 开始处理
# 如果启用了标签分类模式
if [ "$TAG_CLASSIFY_MODE" = true ]; then
  if [ -z "$SOURCE_DIR" ]; then
    echo "❌ 错误: 标签分类模式需要指定源目录"
    exit 1
  fi
  
  classify_videos_by_tags "$SOURCE_DIR" "$TARGET_DIR"
  
  # 移动完成后，更新目标目录的大小标签
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 更新目录大小标签"
  echo
  
  # 递归更新所有DY-目录和【】目录的大小
  update_all_directory_sizes "$TARGET_DIR"
  
  echo
  
  # 处理空目录的显示/隐藏
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$SHOW_HIDDEN" = true ]; then
    echo "📂 显示所有目录"
  else
    echo "🙈 隐藏空目录"
  fi
  echo
  
  # 递归处理目标目录下的所有【】和DY-目录
  process_empty_directories "$TARGET_DIR"
  
  echo
  echo "✅ 分类移动完成"
  
  # 如果指定了 -link 参数，创建 DY-分类浏览 符号链接视图
  if [ "$CREATE_SYMLINK_VIEW" = true ]; then
    echo ""
    echo "🔗 创建 DY-分类浏览..."
    create_tag_based_symlink_view "$TARGET_DIR"
  else
    echo ""
    echo "ℹ️  跳过创建符号链接视图（使用 -link 参数可启用）"
  fi
  
  echo
  echo "✅ 全部完成"
  exit 0
elif [ -n "$SOURCE_DIR" ]; then
  # 如果指定了源目录，执行视频提取（原有功能）
  extract_videos_from_source "$SOURCE_DIR" "$TARGET_DIR"
fi

# 如果OCR模式下指定了单个文件或目录
if [ "$OCR_RENAME_MODE" = true ] && [ -n "$OCR_TARGET" ]; then
  # 将OCR_TARGET转为绞对路径（如果不是绞对路径）
  ocr_target_abs="$OCR_TARGET"
  if [[ ! "$OCR_TARGET" =~ ^/ ]]; then
    ocr_target_abs="$TARGET_DIR/$OCR_TARGET"
  fi
  
  # 如果指定的是单个文件
  if [ -f "$ocr_target_abs" ]; then
    echo "🎯 处理指定文件: $ocr_target_abs"
    echo
    # 设置OCR根目录为文件所在目录的父目录
    OCR_ROOT_DIR="$(dirname "$ocr_target_abs")"
    ocr_rename_video "$ocr_target_abs"
    echo
    echo "✅ 完成"
    exit 0
  elif [ -d "$ocr_target_abs" ]; then
    # 如果是目录，更新TARGET_DIR为OCR_TARGET
    TARGET_DIR="$ocr_target_abs"
  elif [ ! -e "$ocr_target_abs" ]; then
    echo "❌ 错误: 路径不存在: $ocr_target_abs"
    exit 1
  fi
fi

# 如果视频检测模式下指定了单个文件或目录
if [ "$CHECK_VIDEO_MODE" = true ] && [ -n "$CHECK_VIDEO_TARGET" ]; then
  # 将CHECK_VIDEO_TARGET转为绞对路径（如果不是绞对路径）
  check_target_abs="$CHECK_VIDEO_TARGET"
  if [[ ! "$CHECK_VIDEO_TARGET" =~ ^/ ]]; then
    check_target_abs="$TARGET_DIR/$CHECK_VIDEO_TARGET"
  fi
  
  # 如果指定的是单个文件
  if [ -f "$check_target_abs" ]; then
    echo "🎯 检测指定文件: $check_target_abs"
    echo
    # 设置检测根目录为文件所在目录
    CHECK_VIDEO_ROOT_DIR="$(dirname "$check_target_abs")"
    check_video_integrity "$check_target_abs"
    echo
    echo "✅ 完成"
    exit 0
  elif [ -d "$check_target_abs" ]; then
    # 如果是目录，更新TARGET_DIR为CHECK_VIDEO_TARGET
    TARGET_DIR="$check_target_abs"
  elif [ ! -e "$check_target_abs" ]; then
    echo "❌ 错误: 路径不存在: $check_target_abs"
    exit 1
  fi
fi

# 如果是清空文件模式
if [ "$CLEAN_MODE" = true ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🗑️  清空文件模式"
  echo "目标目录: $TARGET_DIR"
  if [ -n "$CLEAN_TARGET" ]; then
    echo "指定路径: $CLEAN_TARGET"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 确定要清空的目录
  clean_path="$TARGET_DIR"
  if [ -n "$CLEAN_TARGET" ]; then
    # 将CLEAN_TARGET转为绝对路径（如果不是绝对路径）
    if [[ ! "$CLEAN_TARGET" =~ ^/ ]]; then
      clean_path="$TARGET_DIR/$CLEAN_TARGET"
    else
      clean_path="$CLEAN_TARGET"
    fi
  fi
  
  # 检查路径是否存在
  if [ ! -d "$clean_path" ]; then
    echo "❌ 错误: 目录不存在: $clean_path"
    exit 1
  fi
  
  # 确认操作
  echo "⚠️  将要清空以下目录中的所有文件（保留目录结构）:"
  echo "   $clean_path"
  echo
  read -p "是否继续? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
  fi
  echo
  
  # 执行清空操作
  clean_directory_files "$clean_path"
  echo
  
  # 重新计算并更新所有目录的大小标签
  update_directory_sizes "$clean_path"
  echo
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ 清空完成"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
elif [ "$REMOVE_ICON_MODE" = true ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "移除文件夹图标模式"
  echo "目标目录: $TARGET_DIR"
  if [ "$RECURSIVE" = true ]; then
    if [ "$MAX_DEPTH" -eq 999 ]; then
      echo "递归模式: 处理所有层级"
    else
      echo "递归模式: 处理 $MAX_DEPTH 层"
    fi
  else
    echo "非递归模式: 只处理一级子文件夹"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 递归移除图标函数
  remove_icons_recursively() {
    local dir="$1"
    local depth="$2"
    
    # 处理当前目录下的所有子目录
    find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r subdir; do
      # 检查目录是否还存在
      if [ ! -d "$subdir" ]; then
        continue
      fi
      
      local subdir_basename="$(basename "$subdir")"
      
      # 检查是否有自定义图标
      if [ -f "$subdir/Icon"$'\r' ]; then
        # 删除 Icon\r 文件
        rm -f "$subdir/Icon"$'\r' 2>/dev/null
        
        # 移除文件夹的自定义图标标志
        SetFile -a c "$subdir" 2>/dev/null
        
        echo "🗑️  移除图标: $subdir_basename"
      fi
      
      # 如果需要递归且还没达到最大深度
      if [ "$RECURSIVE" = true ] && [ "$depth" -lt "$MAX_DEPTH" ]; then
        local next_depth=$((depth + 1))
        remove_icons_recursively "$subdir" "$next_depth"
      fi
    done
  }
  
  # 开始移除图标
  remove_icons_recursively "$TARGET_DIR" 0
  
  echo
  echo "✅ 图标移除完成"
elif [ "$SET_ICON_MODE" = true ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "设置文件夹图标模式"
  echo "目标目录: $TARGET_DIR"
  if [ "$RECURSIVE" = true ]; then
    if [ "$MAX_DEPTH" -eq 999 ]; then
      echo "递归模式: 处理所有层级"
    else
      echo "递归模式: 处理 $MAX_DEPTH 层"
    fi
  else
    echo "非递归模式: 只处理一级子文件夹"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 检查 ffmpeg 是否可用
  if ! command -v ffmpeg &> /dev/null; then
    echo "❌ 错误: ffmpeg 未安装"
    echo "请使用以下命令安装: brew install ffmpeg"
    exit 1
  fi
  
  # 检查 fileicon 是否可用
  if ! command -v fileicon &> /dev/null; then
    echo "❌ 错误: fileicon 工具未安装"
    echo "请使用以下命令安装: brew install fileicon"
    exit 1
  fi
  
  # 递归设置图标函数
  set_icons_recursively() {
    local dir="$1"
    local depth="$2"
    
    # 处理当前目录下的所有子目录
    find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while IFS= read -r subdir; do
      local subdir_basename="$(basename "$subdir")"
      
      # 只处理 DY- 开头的文件夹
      if [[ "$subdir_basename" =~ ^DY- ]]; then
        # 为当前子目录设置图标（强制模式）
        set_folder_icon_from_video "$subdir" true
      fi
      
      # 如果需要递归且还没达到最大深度
      if [ "$RECURSIVE" = true ] && [ "$depth" -lt "$MAX_DEPTH" ]; then
        local next_depth=$((depth + 1))
        set_icons_recursively "$subdir" "$next_depth"
      fi
    done
  }
  
  # 开始设置图标
  set_icons_recursively "$TARGET_DIR" 0
  
  echo
  echo "✅ 图标设置完成"
elif [ "$OCR_RENAME_MODE" = true ]; then
  # OCR识别重命名模式
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "OCR识别重命名模式"
  echo "目标目录: $TARGET_DIR"
  if [ "$RECURSIVE" = true ]; then
    if [ "$MAX_DEPTH" -eq 999 ]; then
      echo "递归模式: 处理所有层级"
    else
      echo "递归模式: 处理 $MAX_DEPTH 层"
    fi
  else
    echo "非递归模式: 只处理一级子文件夹"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 设置OCR根目录（用于创建“未成功分类”目录）
  OCR_ROOT_DIR="$TARGET_DIR"
  
  # 递归OCR处理函数
  ocr_process_recursively() {
    local dir="$1"
    local depth="$2"
    
    # 处理当前目录下的所有视频文件（使用FILE_DEPTH深度）
    local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
    
    for ext in "${VIDEO_EXTS[@]}"; do
      find "$dir" -maxdepth "$FILE_DEPTH" -type f -name "*.$ext" 2>/dev/null | while IFS= read -r video_file; do
        echo "━━ $(basename "$(dirname "$video_file")")"
        echo
        ocr_rename_video "$video_file"
        echo
      done
    done
    
    # 如果需要递归且还没达到最大深度
    if [ "$RECURSIVE" = true ] && [ "$depth" -lt "$MAX_DEPTH" ]; then
      local next_depth=$((depth + 1))
      # 先收集所有子目录到数组中
      local subdirs=()
      while IFS= read -r subdir; do
        subdirs+=("$subdir")
      done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
      
      # 递归处理每个子目录
      for subdir in "${subdirs[@]}"; do
        if [ ! -d "$subdir" ]; then
          continue
        fi
        
        # 跳过“未成功分类”目录，避免递归处理
        local subdir_basename="$(basename "$subdir")"
        if [ "$subdir_basename" = "未成功分类" ]; then
          continue
        fi
        
        ocr_process_recursively "$subdir" "$next_depth"
      done
    fi
  }
  
  # 开始OCR处理
  ocr_process_recursively "$TARGET_DIR" 0
  
  echo
  echo "✅ OCR处理完成"
elif [ "$CHECK_VIDEO_MODE" = true ]; then
  # 检查是否是单文件检测模式（并行用）
  if [ -n "$CHECK_SINGLE_FILE" ]; then
    # 单文件检测模式
    if [ -f "$CHECK_SINGLE_FILE" ]; then
      CHECK_VIDEO_ROOT_DIR="$(dirname "$CHECK_SINGLE_FILE")"
      echo "━━ $(basename "$CHECK_SINGLE_FILE")"
      check_video_integrity "$CHECK_SINGLE_FILE"
      echo
      exit $?
    else
      echo "错误: 文件不存在: $CHECK_SINGLE_FILE"
      exit 1
    fi
  fi
  
  # 视频完整性检测模式
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 视频完整性检测模式"
  echo "目标目录: $TARGET_DIR"
  if [ "$RECURSIVE" = true ]; then
    if [ "$MAX_DEPTH" -eq 999 ]; then
      echo "递归模式: 处理所有层级"
    else
      echo "递归模式: 处理 $MAX_DEPTH 层"
    fi
  else
    echo "非递归模式: 只处理一级子文件夹"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  
  # 设置视频检测根目录（用于创建"待优化视频"目录）
  CHECK_VIDEO_ROOT_DIR="$TARGET_DIR"
  
  # 统计变量
  total_checked=0
  total_marked=0
  total_normal=0
  total_skipped=0
  
  # 递归视频检测处理函数
  check_video_recursively() {
    local dir="$1"
    local depth="$2"
    
    # 处理当前目录下的所有视频文件（使用FILE_DEPTH深度）
    local VIDEO_EXTS=("mp4" "MP4" "mov" "MOV" "avi" "AVI" "mkv" "MKV" "flv" "FLV" "wmv" "WMV" "m4v" "M4V")
    
    if [ "$PARALLEL_MODE" = true ]; then
      # 并行处理模式：使用-print0和-0处理包含空格的文件名
      for ext in "${VIDEO_EXTS[@]}"; do
        find "$dir" -maxdepth "$FILE_DEPTH" -type f -name "*.$ext" -print0 2>/dev/null
      done | xargs -0 -n 1 -P "$PARALLEL_JOBS" "$0" --check-single
    else
      # 串行处理模式
      for ext in "${VIDEO_EXTS[@]}"; do
        find "$dir" -maxdepth "$FILE_DEPTH" -type f -name "*.$ext" 2>/dev/null | while IFS= read -r video_file; do
          ((total_checked++))
          echo "━━ $(basename "$(dirname "$video_file")")"
          echo
          
          # 检测视频并获取返回值
          check_video_integrity "$video_file"
          local result=$?
          
          if [ $result -eq 2 ]; then
            # 返回2表示文件被标记
            ((total_marked++))
          elif [ $result -eq 0 ]; then
            # 返回0表示正常
            ((total_normal++))
          else
            # 其他情况（错误或跳过）
            ((total_skipped++))
          fi
          
          echo
        done
      done
    fi
    
    # 如果需要递归且还没达到最大深度
    if [ "$RECURSIVE" = true ] && [ "$depth" -lt "$MAX_DEPTH" ]; then
      local next_depth=$((depth + 1))
      # 先收集所有子目录到数组中
      local subdirs=()
      while IFS= read -r subdir; do
        subdirs+=("$subdir")
      done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
      
      # 递归处理每个子目录
      for subdir in "${subdirs[@]}"; do
        if [ ! -d "$subdir" ]; then
          continue
        fi
        
        # 跳过“待优化视频”目录，避免递归处理
        local subdir_basename="$(basename "$subdir")"
        if [ "$subdir_basename" = "待优化视频" ]; then
          continue
        fi
        
        check_video_recursively "$subdir" "$next_depth"
      done
    fi
  }
  
  # 开始视频检测处理
  check_video_recursively "$TARGET_DIR" 0
  
  echo
  
  if [ "$PARALLEL_MODE" = true ]; then
    # 并行模式下不显示统计（因为各进程独立，统计无法累加）
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 并行检测完成 (使用${PARALLEL_JOBS}个线程)"
    echo "ℹ️  并行模式下无法统计总数，请查看上方输出中的具体结果"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    # 串行模式显示详细统计
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 检测统计汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💼 总计检测: ${total_checked} 个视频"
    echo "⚠️  已标记: ${total_marked} 个 (占比 ≥ 20%)"
    echo "✅ 正常视频: ${total_normal} 个"
    if [ $total_skipped -gt 0 ]; then
      echo "⏭️  跳过/错误: ${total_skipped} 个"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 视频检测完成"
  fi
else
  # 正常处理模式
  process_recursively "$TARGET_DIR" 0
  
  echo ""
  echo "✅ 完成"
  
  # 如果指定了 -link 参数，创建 DY-分类浏览 符号链接
  if [ "$CREATE_SYMLINK_VIEW" = true ]; then
    echo ""
    echo "🔗 创建 DY-分类浏览..."
    create_tag_based_symlink_view "$TARGET_DIR"
  fi
fi
