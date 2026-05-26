---
title: '剑指 Offer 10- I. 斐波那契数列'
description: '剑指 Offer 10- I. 斐波那契数列'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
---
## 题目

剑指 Offer 10- I. 斐波那契数列

写一个函数，输入 `n` ，求斐波那契（Fibonacci）数列的第 `n` 项（即 `F(N)`）。斐波那契数列的定义如下：

```
F(0) = 0,   F(1) = 1
F(N) = F(N - 1) + F(N - 2), 其中 N > 1.
```

斐波那契数列由 0 和 1 开始，之后的斐波那契数就是由之前的两数相加而得出。

答案需要取模 1e9+7（1000000007），如计算初始结果为：1000000008，请返回 1。

**示例 1：**

```
输入：n = 2
输出：1
```

**示例 2：**

```
输入：n = 5
输出：5
```

**提示：**

*   `0 <= n <= 100`

## 代码

**Go：**递归超时，需要采用简单动态规划

```go
func fib(n int) int {
    if n==0{
        return 0
    }else if n==1{
        return 1
    }
    dp:=make([]int,101)
    dp[0]=0
    dp[1]=1
    for i:=2;i<=n;i++{
        dp[i]=(dp[i-1]+dp[i-2])%1000000007
    }
    return dp[n]
}
```
