#!/usr/bin/env python3
"""
检查PDF类型和可提取性
"""

import sys
import os

def check_pdf_type(pdf_path):
    """检查PDF是否包含文本还是纯图片"""
    try:
        import pdfplumber

        with pdfplumber.open(pdf_path) as pdf:
            print(f"PDF信息:")
            print(f"  总页数: {len(pdf.pages)}")
            print(f"  元数据: {pdf.metadata}")

            # 检查前几页
            for i in range(min(5, len(pdf.pages))):
                page = pdf.pages[i]
                text = page.extract_text()

                print(f"\n第{i+1}页:")
                print(f"  页面尺寸: {page.width} x {page.height}")
                print(f"  提取文本长度: {len(text) if text else 0}")

                if text and len(text.strip()) > 50:
                    print(f"  文本预览: {text[:100]}")
                else:
                    print("  ⚠️  此页几乎没有可提取的文本（可能是图片）")

                # 检查是否有图片
                if page.images:
                    print(f"  包含图片: {len(page.images)}个")

    except Exception as e:
        print(f"检查失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python check_pdf.py <PDF文件>")
        sys.exit(1)

    check_pdf_type(sys.argv[1])
