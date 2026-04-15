#!/usr/bin/env python3
"""
PDF OCR文本提取工具
使用Tesseract OCR从扫描版PDF中提取中文文本
"""

import sys
import os
import subprocess
import tempfile
from pathlib import Path

def extract_with_ocr(pdf_path, output_path, lang='chi_sim', max_pages=None):
    """
    使用OCR从扫描版PDF提取文本

    Args:
        pdf_path: PDF文件路径
        output_path: 输出文本文件路径
        lang: OCR语言 (chi_sim=简体中文, chi_tra=繁体中文)
        max_pages: 最大处理页数（None=全部）
    """
    try:
        import pdfplumber

        with open(output_path, 'w', encoding='utf-8') as out_file:
            with pdfplumber.open(pdf_path) as pdf:
                total_pages = len(pdf.pages)
                pages_to_process = min(max_pages, total_pages) if max_pages else total_pages

                print(f"开始OCR提取:", file=sys.stderr)
                print(f"  总页数: {total_pages}", file=sys.stderr)
                print(f"  处理页数: {pages_to_process}", file=sys.stderr)
                print(f"  OCR语言: {lang}", file=sys.stderr)

                for page_num in range(pages_to_process):
                    page = pdf.pages[page_num]

                    # 将页面转换为图片
                    img = page.to_image()

                    # 保存为临时PNG文件
                    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_img:
                        img.save(tmp_img.name)
                        tmp_img_path = tmp_img.name

                    try:
                        # 使用tesseract进行OCR
                        result = subprocess.run(
                            ['tesseract', tmp_img_path, 'stdout', '-l', lang],
                            capture_output=True,
                            text=True,
                            timeout=30
                        )

                        ocr_text = result.stdout

                        if ocr_text and len(ocr_text.strip()) > 0:
                            out_file.write(f"\n{'='*60}\n")
                            out_file.write(f"第{page_num + 1}页\n")
                            out_file.write(f"{'='*60}\n\n")
                            out_file.write(ocr_text)
                            out_file.write("\n")

                    except subprocess.TimeoutExpired:
                        print(f"  第{page_num+1}页: OCR超时", file=sys.stderr)
                    except Exception as e:
                        print(f"  第{page_num+1}页: OCR失败 - {e}", file=sys.stderr)
                    finally:
                        # 删除临时图片
                        try:
                            os.unlink(tmp_img_path)
                        except:
                            pass

                    # 显示进度
                    if (page_num + 1) % 10 == 0:
                        print(f"  已处理: {page_num + 1}/{pages_to_process}页", file=sys.stderr)

        print(f"\n✓ OCR提取完成!", file=sys.stderr)
        print(f"  输出文件: {output_path}", file=sys.stderr)
        return True

    except Exception as e:
        print(f"OCR提取失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

def extract_sample_ocr(pdf_path, output_path, sample_pages=5, lang='chi_sim'):
    """提取前几页作为OCR样本测试"""
    return extract_with_ocr(pdf_path, output_path, lang=lang, max_pages=sample_pages)

def main():
    if len(sys.argv) < 2:
        print("PDF OCR文本提取工具")
        print("\n用法:")
        print("  python extract_pdf_ocr.py <PDF文件> [输出文件] [选项]")
        print("\n选项:")
        print("  --sample=N     提取前N页作为样本（默认5页）")
        print("  --all          提取全部页面")
        print("  --lang=LANG    OCR语言（chi_sim=简体, chi_tra=繁体，默认chi_sim）")
        print("\n示例:")
        print("  # 测试前5页")
        print("  python extract_pdf_ocr.py book.pdf sample.txt --sample=5")
        print("  # 提取全部")
        print("  python extract_pdf_ocr.py book.pdf full.txt --all")
        sys.exit(1)

    pdf_path = sys.argv[1]

    # 解析参数
    sample_pages = 5
    max_pages = None
    lang = 'chi_sim'

    for arg in sys.argv[2:]:
        if arg.startswith('--sample='):
            sample_pages = int(arg.split('=')[1])
            max_pages = sample_pages
        elif arg == '--all':
            max_pages = None
        elif arg.startswith('--lang='):
            lang = arg.split('=')[1]

    # 确定输出文件
    if len(sys.argv) > 2 and not sys.argv[2].startswith('--'):
        output_path = sys.argv[2]
    else:
        pdf_name = Path(pdf_path).stem
        if max_pages:
            output_path = f"{pdf_name}_OCR样本{max_pages}页.txt"
        else:
            output_path = f"{pdf_name}_OCR完整.txt"

    if not os.path.exists(pdf_path):
        print(f"错误: 文件不存在 - {pdf_path}", file=sys.stderr)
        sys.exit(1)

    # 执行OCR提取
    success = extract_with_ocr(pdf_path, output_path, lang=lang, max_pages=max_pages)

    if success:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
