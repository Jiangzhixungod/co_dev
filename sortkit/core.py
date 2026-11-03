"""使用稳定归并算法排序可迭代对象。"""

from typing import Any, Callable, Iterable, List, Optional, TypeVar


T = TypeVar("T")


def merge_sort(
    items: Iterable[T],
    *,
    key: Optional[Callable[[T], Any]] = None,
    reverse: bool = False,
) -> List[T]:
    """返回排序后的新列表，不修改输入，且升序与降序均保持稳定。

    每个元素的 key 只计算一次，比较只使用小于运算。自底向上的
    归并不使用递归，时间复杂度为 O(n log n)，额外空间为 O(n)。
    不可比较的元素会自然抛出 TypeError。
    """
    values = list(items)
    keys: List[Any] = (
        values.copy() if key is None else [key(x) for x in values]
    )
    size = len(values)
    if size < 2:
        return values

    next_values = values.copy()
    next_keys = keys.copy()
    width = 1
    while width < size:
        for start in range(0, size, 2 * width):
            middle = min(start + width, size)
            end = min(start + 2 * width, size)
            left, right, target = start, middle, start

            while left < middle and right < end:
                # 仅在右侧严格优先时取右侧，相等时始终先取左侧。
                take_right = (
                    keys[left] < keys[right]
                    if reverse
                    else keys[right] < keys[left]
                )
                if take_right:
                    source = right
                    right += 1
                else:
                    source = left
                    left += 1
                next_values[target] = values[source]
                next_keys[target] = keys[source]
                target += 1

            while left < middle:
                next_values[target] = values[left]
                next_keys[target] = keys[left]
                left += 1
                target += 1
            while right < end:
                next_values[target] = values[right]
                next_keys[target] = keys[right]
                right += 1
                target += 1

        values, next_values = next_values, values
        keys, next_keys = next_keys, keys
        width *= 2

    return values
