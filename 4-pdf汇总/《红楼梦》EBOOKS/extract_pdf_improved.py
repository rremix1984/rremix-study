#!/usr/bin/env python3
"""
改进的PDF文本提取工具
专门处理中文PDF的编码问题
"""

import sys
import os
import re
from pathlib import Path

def extract_with_pdfplumber(pdf_path, output_path):
    """使用pdfplumber提取文本，更好地处理中文"""
    try:
        import pdfplumber

        with open(output_path, 'w', encoding='utf-8') as out_file:
            with pdfplumber.open(pdf_path) as pdf:
                total_pages = len(pdf.pages)
                print(f"总页数: {total_pages}", file=sys.stderr)

                for page_num, page in enumerate(pdf.pages):
                    # 尝试多种提取方法
                    page_text = page.extract_text()

                    if page_text:
                        # 清理文本
                        page_text = clean_text(page_text)
                        out_file.write(f"\n--- 第{page_num + 1}页 ---\n")
                        out_file.write(page_text)
                        out_file.write("\n")

                    # 显示进度
                    if (page_num + 1) % 50 == 0:
                        print(f"已处理: {page_num + 1}/{total_pages}页", file=sys.stderr)

        return True
    except Exception as e:
        print(f"pdfplumber提取失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

def clean_text(text):
    """清理提取的文本"""
    # 移除多余的空白
    text = re.sub(r'\s+', ' ', text)
    # 移除(cid:xxxx)这种编码标记
    text = re.sub(r'\(cid:\d+\)', '', text)
    return text.strip()

def extract_sample_pages(pdf_path, output_path, max_pages=10):
    """提取前几页作为样本"""
    try:
        import pdfplumber

        with open(output_path, 'w', encoding='utf-8') as out_file:
            with pdfplumber.open(pdf_path) as pdf:
                total_pages = len(pdf.pages)
                pages_to_extract = min(max_pages, total_pages)
                print(f"提取前{pages_to_extract}页（共{total_pages}页）", file=sys.stderr)

                for page_num in range(pages_to_extract):
                    page = pdf.pages[page_num]

                    # 尝试提取文本
                    page_text = page.extract_text()

                    if page_text:
                        out_file.write(f"\n{'='*60}\n")
                        out_file.write(f"第{page_num + 1}页\n")
                        out_file.write(f"{'='*60}\n\n")
                        out_file.write(page_text)
                        out_file.write("\n")

                print(f"已保存到: {output_path}", file=sys.stderr)

        return True
    except Exception as e:
        print(f"提取失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  python extract_pdf_improved.py <PDF文件> [输出文件] [--all|--sample=N]")
        print("\n选项:")
        print("  --all       提取全部页面（默认）")
        print("  --sample=N  提取前N页作为样本（默认10页）")
        print("\n示例:")
        print("  python extract_pdf_improved.py book.pdf output.txt --all")
        print("  python extract_pdf_improved.py book.pdf sample.txt --sample=5")
        sys.exit(1)

    pdf_path = sys.argv[1]

    # 解析参数
    max_pages = None
    sample_mode = False

    for arg in sys.argv[2:]:
        if arg.startswith('--sample='):
            max_pages = int(arg.split('=')[1])
            sample_mode = True
        elif arg == '--all':
            max_pages = None
            sample_mode = False

    # 确定输出文件
    if len(sys.argv) > 2 and not sys.argv[2].startswith('--'):
        output_path = sys.argv[2]
    else:
        pdf_name = Path(pdf_path).stem
        if sample_mode:
            output_path = f"{pdf_name}_样本{max_pages}页.txt"
        else:
            output_path = f"{pdf_name}_完整提取.txt"

    if not os.path.exists(pdf_path):
        print(f"错误: 文件不存在 - {pdf_path}", file=sys.stderr)
        sys.exit(1)

    print(f"开始提取: {pdf_path}", file=sys.stderr)

    if sample_mode:
        success = extract_sample_pages(pdf_path, output_path, max_pages)
    else:
        success = extract_with_pdfplumber(pdf_path, output_path)

    if success:
        print("✓ 提取完成!", file=sys.stderr)
        sys.exit(0)
    else:
        print("✗ 提取失败", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
