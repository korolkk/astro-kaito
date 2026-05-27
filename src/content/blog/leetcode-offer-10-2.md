---
title: '剑指 Offer 10- II. 青蛙跳台阶问题'
description: '剑指 Offer 10- II. 青蛙跳台阶问题'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 10- II. 青蛙跳台阶问题

一只青蛙一次可以跳上1级台阶，也可以跳上2级台阶。求该青蛙跳上一个 `n` 级的台阶总共有多少种跳法。

答案需要取模 1e9+7（1000000007），如计算初始结果为：1000000008，请返回 1。

**示例 1：**

```
输入：n = 2
输出：2
```

**示例 2：**

```
输入：n = 7
输出：21
```

**示例 3：**

```
输入：n = 0
输出：1
```

**提示：**

*   `0 <= n <= 100`

注意：本题与主站 70 题相同：[https://leetcode-cn.com/problems/climbing-stairs/](https://leetcode-cn.com/problems/climbing-stairs/)

## 代码

**Go：**简单动态规划 解法同斐波那契数列

```go
func numWays(n int) int {
    if n==0{
        return 1
    }else if n==1{
        return 1
    }
    dp:=make([]int,101)
    dp[0]=1
    dp[1]=1
    for i:=2;i<=n;i++{
        dp[i]=(dp[i-1]+dp[i-2])%1000000007
    }
    return dp[n]
}
```
