## A: 5 repeats (one process each, warm-up prompt discarded; measured = last 3 rows)
ctx|config|tok/s mean (min-max)|main ms|draft ms|tok/pass|accept1|same tok/state
8k|bd2:fixed8|67.9 (67.0-68.2)|43.85|6.32|3.53|0.770|True n=5
8k|bd2:fixed16|61.3 (61.0-61.4)|49.95|7.42|3.62|0.764|True n=5
8k|bd2:adapt-cost|65.8 (65.7-65.9)|45.42|6.44|3.53|0.757|True n=5
30k|bd2:fixed8|56.0 (55.6-56.1)|51.05|6.27|3.31|0.821|True n=5
30k|bd2:fixed16|51.2 (51.1-51.3)|60.19|7.41|3.55|0.851|True n=5
30k|bd2:adapt-cost|55.8 (55.7-55.8)|51.39|6.19|3.31|0.821|True n=5
60k|bd2:fixed8|44.9 (44.5-45.0)|60.71|6.28|3.08|0.765|True n=5
60k|bd2:fixed16|36.4 (36.3-36.4)|73.99|7.40|3.02|0.747|True n=5
60k|bd2:adapt-cost|45.0 (45.0-45.0)|60.70|6.14|3.08|0.765|True n=5
## B_sustained_8k
long8000 bd2:fixed8 76.4 main 44.1 draft 6.5 tpp 4.01 acc 0.791 2048 True True
long8000 bd2:fixed16 74.0 main 50.2 draft 7.4 tpp 4.39 acc 0.767 2048 True True
long8000 bd2:adapt-cost 79.4 main 45.1 draft 6.3 tpp 4.22 acc 0.778 2048 True True
## C_code
py_merge bd2:fixed8 91.5 main 41.7 draft 6.0 tpp 4.54 acc 0.796 2048 True True
py_merge bd2:fixed16 92.5 main 46.7 draft 7.0 tpp 5.15 acc 0.741 2048 True True
py_merge bd2:adapt-cost 96.8 main 44.7 draft 6.5 tpp 5.15 acc 0.764 2048 True True
py_csv bd2:fixed8 119.1 main 41.7 draft 6.0 tpp 5.92 acc 0.916 2048 True True
py_csv bd2:fixed16 140.9 main 46.6 draft 6.9 tpp 7.85 acc 0.897 2048 True True
py_csv bd2:adapt-cost 140.1 main 46.2 draft 6.8 tpp 7.73 acc 0.902 2048 True True
py_lru bd2:fixed8 60.5 main 41.8 draft 6.0 tpp 2.99 acc 0.633 2048 True True
py_lru bd2:fixed16 58.1 main 46.8 draft 7.1 tpp 3.23 acc 0.602 2048 True True
py_lru bd2:adapt-cost 63.4 main 43.0 draft 6.2 tpp 3.23 acc 0.603 2048 True True
rs_balanced bd2:fixed8 53.1 main 41.7 draft 6.0 tpp 2.62 acc 0.752 2048 True True
rs_balanced bd2:fixed16 54.4 main 46.7 draft 6.9 tpp 3.01 acc 0.839 2048 True True
rs_balanced bd2:adapt-cost 53.5 main 42.3 draft 6.0 tpp 2.67 acc 0.746 2048 True True
rs_merge bd2:fixed8 42.3 main 41.8 draft 6.0 tpp 2.08 acc 0.547 2048 True True
rs_merge bd2:fixed16 38.9 main 46.7 draft 7.0 tpp 2.15 acc 0.538 2048 True True
rs_merge bd2:adapt-cost 42.9 main 42.2 draft 6.1 tpp 2.14 acc 0.534 2048 True True
cpp_fib bd2:fixed8 117.0 main 41.7 draft 6.0 tpp 5.82 acc 0.909 2048 True True
cpp_fib bd2:fixed16 142.0 main 46.6 draft 6.9 tpp 7.92 acc 0.888 2048 True True
cpp_fib bd2:adapt-cost 141.6 main 46.4 draft 6.9 tpp 7.86 acc 0.885 2048 True True
cpp_merge bd2:fixed8 53.8 main 41.8 draft 6.0 tpp 2.66 acc 0.672 2048 True True
cpp_merge bd2:fixed16 61.7 main 46.7 draft 7.0 tpp 3.42 acc 0.796 2048 True True
cpp_merge bd2:adapt-cost 55.8 main 42.5 draft 6.1 tpp 2.81 acc 0.656 2048 True True
