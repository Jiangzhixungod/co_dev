"""从标准输入读取整数，并将排序结果写入标准输出。"""

import argparse
import sys
from typing import List

from . import merge_sort


def main() -> int:
    """运行整数排序命令行；非法整数返回退出码 2。"""
    parser = argparse.ArgumentParser(description="对标准输入中的整数进行稳定排序。")
    parser.add_argument("-r", "--reverse", action="store_true", help="按降序排列")
    args = parser.parse_args()

    numbers: List[int] = []
    # 固定输入编码；非法字节以转义文本保留，进入整数解析的错误路径。
    input_text = sys.stdin.buffer.read().decode(
        "utf-8", errors="backslashreplace"
    )
    for token in input_text.split():
        try:
            numbers.append(int(token))
        except ValueError:
            print("error: invalid integer: {}".format(token), file=sys.stderr)
            return 2

    result = merge_sort(numbers, reverse=args.reverse)
    print(" ".join(str(number) for number in result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
