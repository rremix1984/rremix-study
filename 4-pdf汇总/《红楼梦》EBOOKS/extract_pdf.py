#!/usr/bin/env python3
"""
PDF文本提取工具
支持多种PDF库，自动选择最佳方案
"""

import sys
import os
from pathlib import Path

def extract_with_pypdf2(pdf_path):
    """使用PyPDF2提取文本"""
    try:
        import PyPDF2
        text = []
        with open(pdf_path, 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            total_pages = len(reader.pages)
            print(f"总页数: {total_pages}", file=sys.stderr)

            for page_num in range(total_pages):
                page = reader.pages[page_num]
                page_text = page.extract_text()
                text.append(f"--- 第{page_num + 1}页 ---\n")
                text.append(page_text)
                text.append("\n")

                # 显示进度
                if (page_num + 1) % 10 == 0:
                    print(f"已处理: {page_num + 1}/{total_pages}页", file=sys.stderr)

        return ''.join(text)
    except Exception as e:
        print(f"PyPDF2提取失败: {e}", file=sys.stderr)
        return None

def extract_with_pdfplumber(pdf_path):
    """使用pdfplumber提取文本"""
    try:
        import pdfplumber
        text = []

        with pdfplumber.open(pdf_path) as pdf:
            total_pages = len(pdf.pages)
            print(f"总页数: {total_pages}", file=sys.stderr)

            for page_num, page in enumerate(pdf.pages):
                page_text = page.extract_text()
                if page_text:
                    text.append(f"--- 第{page_num + 1}页 ---\n")
                    text.append(page_text)
                    text.append("\n")

                # 显示进度
                if (page_num + 1) % 10 == 0:
                    print(f"已处理: {page_num + 1}/{total_pages}页", file=sys.stderr)

        return ''.join(text)
    except Exception as e:
        print(f"pdfplumber提取失败: {e}", file=sys.stderr)
        return None

def extract_pdf_text(pdf_path, output_path=None, method='auto'):
    """
    提取PDF文本

    Args:
        pdf_path: PDF文件路径
        output_path: 输出文件路径（可选）
        method: 提取方法 ('auto', 'pypdf2', 'pdfplumber')

    Returns:
        提取的文本内容
    """
    if not os.path.exists(pdf_path):
        print(f"错误: 文件不存在 - {pdf_path}", file=sys.stderr)
        return None

    print(f"开始提取: {pdf_path}", file=sys.stderr)

    # 自动选择方法
    if method == 'auto':
        # 优先尝试pdfplumber，效果通常更好
        text = extract_with_pdfplumber(pdf_path)
        if not text:
            text = extract_with_pypdf2(pdf_path)
    elif method == 'pypdf2':
        text = extract_with_pypdf2(pdf_path)
    elif method == 'pdfplumber':
        text = extract_with_pdfplumber(pdf_path)
    else:
        print(f"未知的提取方法: {method}", file=sys.stderr)
        return None

    if not text:
        print("提取失败", file=sys.stderr)
        return None

    # 保存到文件
    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f"已保存到: {output_path}", file=sys.stderr)

    return text

def main():
    if len(sys.argv) < 2:
        print("用法: python extract_pdf.py <PDF文件> [输出文件] [方法]")
        print("方法: auto(默认) | pypdf2 | pdfplumber")
        sys.exit(1)

    pdf_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    method = sys.argv[3] if len(sys.argv) > 3 else 'auto'

    # 如果没有指定输出文件，自动生成
    if not output_path:
        pdf_name = Path(pdf_path).stem
        output_path = f"{pdf_name}_提取.txt"

    text = extract_pdf_text(pdf_path, output_path, method)

    if text:
        print(f"\n提取完成! 共{len(text)}个字符", file=sys.stderr)
        # 如果没有保存到文件，输出到stdout
        if len(sys.argv) < 3:
            print(text)
        return 0
    else:
        print("提取失败", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
