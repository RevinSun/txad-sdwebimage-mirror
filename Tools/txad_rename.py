#!/usr/bin/env python3
# Tools/txad_rename.py
# 把 SDWebImage 源码命名空间化到 TXAd 前缀（v5 适配，无 FLAnimatedImage）
import os, re, shutil, sys

src_root = sys.argv[1]
dst_root = sys.argv[2]

TEXT_SUFFIX = (".h",".m",".mm",".c",".cpp",".plist",".pch",".modulemap")

def should_skip_dir(path):
    parts = path.split(os.sep)
    skip = {"Examples","Docs",".git",".github",".swiftpm","Configs","Certificate"}
    return any(p in skip for p in parts)

def map_rel_path(rel):
    return rel.replace("include/SDWebImage", "include/TXAdWebImage")

def map_filename(name):
    # 分类文件名
    name = name.replace("+WebCacheOperation", "+TXAdWebCacheOperation")
    name = name.replace("+WebCache", "+TXAdWebCache")
    # 以 SD 开头的文件名（类/头）
    name = re.sub(r"^SD(?=[A-Z])", "TXAd", name)
    return name

REPLACEMENTS = [
    # 目录与 umbrella
    (r"include/SDWebImage", "include/TXAdWebImage"),
    (r'"SDWebImage.h"', '"TXAdWebImage.h"'),
    # 分类名
    (r"\+WebCacheOperation", "+TXAdWebCacheOperation"),
    (r"\+WebCache", "+TXAdWebCache"),
    # 分类方法选择器：sd_ -> txad_
    (r"\bsd_([A-Za-z0-9_]+)", r"txad_\1"),
    # 文本中的 SDWebImage（通知/键/路径/queue label）
    (r"\bSDWebImage", "TXAdWebImage"),
    (r"com\.hackemist\.SDWebImage", "com.txad.TXAdWebImage"),
    # 常量/宏前缀
    (r"\bSDWEBIMAGE_", "TXADWEBIMAGE_"),
    (r"\bkSD(?=[A-Z])", "kTXAd"),
    # 核心标识符：SD -> TXAd（词边界，避免误伤）
    (r"(?<![A-Za-z0-9_])SD(?=[A-Z_])", "TXAd"),
]

def process_text_file(src, dst):
    with open(src, "rb") as f:
        raw = f.read()
    try:
        text = raw.decode("utf-8")
    except:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        return
    for pat, rep in REPLACEMENTS:
        text = re.sub(pat, rep, text)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)

def copy_tree(src, dst):
    for root, dirs, files in os.walk(src):
        if should_skip_dir(root): 
            continue
        rel = os.path.relpath(root, src)
        rel = map_rel_path(rel)
        for name in files:
            src_file = os.path.join(root, name)
            if should_skip_dir(src_file): 
                continue
            new_name = map_filename(name)
            dst_file = os.path.join(dst, rel, new_name)
            if new_name.endswith(TEXT_SUFFIX):
                process_text_file(src_file, dst_file)
            else:
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                shutil.copy2(src_file, dst_file)

copy_tree(src_root, dst_root)
