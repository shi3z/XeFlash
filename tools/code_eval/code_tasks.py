"""Code-generation tasks used for the speculative-decoding study: prompt text and hidden tests.

Every task names the function it wants, so the same hidden test can grade the answer regardless of the prompt's context length.
Tests are run by code_eval.py inside a bubblewrap sandbox (no network, read-only system, scratch tmpfs, time and memory limits).
"""

TASKS = {
    "py_merge": dict(lang="python", name="merge_intervals", prompt=(
        "Write a Python function `merge_intervals(intervals)` that takes a list of [start, end] lists and returns the merged "
        "intervals sorted by start. Intervals that touch (for example [1, 3] and [3, 5]) must be merged. Put the complete code in one "
        "code block and add a few tests."), test='''
import gen
f = gen.merge_intervals
assert f([[1,3],[2,6],[8,10],[15,18]]) == [[1,6],[8,10],[15,18]]
assert f([[1,4],[4,5]]) == [[1,5]]
assert f([]) == []
assert f([[5,7],[1,2],[2,4]]) == [[1,4],[5,7]]
assert f([[1,10],[2,3],[4,5]]) == [[1,10]]
assert f([[3,3]]) == [[3,3]]
print("OK")
'''),
    "py_csv": dict(lang="python", name="parse_csv_line", prompt=(
        "Write a Python function `parse_csv_line(line)` that splits one CSV line into a list of strings. Fields may be wrapped in double "
        "quotes, quoted fields may contain commas, and a doubled quote inside a quoted field stands for one quote character. "
        "Put the complete code in one code block and add a few tests."), test='''
import gen
f = gen.parse_csv_line
assert f("a,b,c") == ["a","b","c"]
assert f('"a,b",c') == ["a,b","c"]
assert f('"he said ""hi""",x') == ['he said "hi"',"x"]
assert f("") == [""]
assert f("a,,c") == ["a","","c"]
assert f('"",x') == ["","x"]
print("OK")
'''),
    "py_lru": dict(lang="python", name="LRUCache", prompt=(
        "Write a Python class `LRUCache` with `__init__(self, capacity)`, `get(self, key)` (returns -1 when the key is missing) and "
        "`put(self, key, value)`. Both operations must run in O(1) and the least recently used entry is evicted when the capacity is "
        "exceeded. Put the complete code in one code block and add a few tests."), test='''
import gen
c = gen.LRUCache(2)
c.put(1, 1); c.put(2, 2)
assert c.get(1) == 1
c.put(3, 3)
assert c.get(2) == -1
c.put(4, 4)
assert c.get(1) == -1 and c.get(3) == 3 and c.get(4) == 4
c.put(3, 30)
assert c.get(3) == 30
d = gen.LRUCache(1); d.put(5, 6); d.put(7, 8)
assert d.get(5) == -1 and d.get(7) == 8
print("OK")
'''),
    "rs_balanced": dict(lang="rust", name="is_balanced", prompt=(
        "Write a Rust function `pub fn is_balanced(s: &str) -> bool` that returns true when the round, square and curly brackets in the "
        "string are correctly nested and closed; other characters are ignored. Put the complete code in one code block and add a few "
        "unit tests."), test='''
#[cfg(test)]
mod hidden_tests {
    use super::*;
    #[test]
    fn t() {
        assert!(is_balanced(""));
        assert!(is_balanced("()[]{}"));
        assert!(is_balanced("{[()]}"));
        assert!(is_balanced("a(b[c]{d}e)f"));
        assert!(!is_balanced("(]"));
        assert!(!is_balanced("(("));
        assert!(!is_balanced("())"));
        assert!(!is_balanced("{[}]"));
    }
}
'''),
    "rs_merge": dict(lang="rust", name="merge_intervals", prompt=(
        "Write a Rust function `pub fn merge_intervals(v: Vec<(i32, i32)>) -> Vec<(i32, i32)>` that merges overlapping or touching "
        "intervals and returns them sorted by start. Put the complete code in one code block and add a few unit tests."), test='''
#[cfg(test)]
mod hidden_tests {
    use super::*;
    #[test]
    fn t() {
        assert_eq!(merge_intervals(vec![(1,3),(2,6),(8,10),(15,18)]), vec![(1,6),(8,10),(15,18)]);
        assert_eq!(merge_intervals(vec![(1,4),(4,5)]), vec![(1,5)]);
        assert_eq!(merge_intervals(vec![]), vec![]);
        assert_eq!(merge_intervals(vec![(5,7),(1,2),(2,4)]), vec![(1,4),(5,7)]);
        assert_eq!(merge_intervals(vec![(1,10),(2,3),(4,5)]), vec![(1,10)]);
    }
}
'''),
    "cpp_fib": dict(lang="cpp", name="fib_mod", prompt=(
        "Write a C++17 function `long long fib_mod(long long n, long long m)` that returns the n-th Fibonacci number modulo m "
        "(F(0)=0, F(1)=1) using fast doubling, for n up to 10^18 and m up to 10^9+7. Put the complete code in one code block and add a "
        "small main that tests it."), test='''
#undef main
#include <cstdio>
int main() {
    int bad = 0;
    bad += fib_mod(0, 7) != 0;
    bad += fib_mod(1, 7) != 1;
    bad += fib_mod(10, 1000) != 55;
    bad += fib_mod(90, 1000000007LL) != @F90@;
    bad += fib_mod(1000000000000000000LL, 1000000007LL) != @FBIG@;
    bad += fib_mod(50, 1) != 0;
    std::puts(bad ? "FAIL" : "OK");
    return bad;
}
'''),
    "cpp_merge": dict(lang="cpp", name="merge_intervals", prompt=(
        "Write a C++17 function `std::vector<std::pair<int,int>> merge_intervals(std::vector<std::pair<int,int>> v)` that merges "
        "overlapping or touching intervals and returns them sorted by start. Put the complete code in one code block and add a small "
        "main that tests it."), test='''
#undef main
#include <cstdio>
int main() {
    using V = std::vector<std::pair<int,int>>;
    int bad = 0;
    bad += merge_intervals(V{{1,3},{2,6},{8,10},{15,18}}) != V{{1,6},{8,10},{15,18}};
    bad += merge_intervals(V{{1,4},{4,5}}) != V{{1,5}};
    bad += merge_intervals(V{}) != V{};
    bad += merge_intervals(V{{5,7},{1,2},{2,4}}) != V{{1,4},{5,7}};
    bad += merge_intervals(V{{1,10},{2,3},{4,5}}) != V{{1,10}};
    std::puts(bad ? "FAIL" : "OK");
    return bad;
}
'''),
}

# The pre-existing benchmark prompt (free-form, no hidden test): "code" = merges overlapping intervals in Python and adds tests.
def fib_mod_ref(n, m):
    def fd(n):
        if n == 0:
            return (0, 1)
        a, b = fd(n >> 1)
        c = a * ((2 * b - a) % m) % m
        d = (a * a + b * b) % m
        return (d, (c + d) % m) if n & 1 else (c, d)
    return fd(n)[0] % m
