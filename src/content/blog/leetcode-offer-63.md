---
title: '剑指 Offer 63. 股票的最大利润'
description: '剑指 Offer 63. 股票的最大利润'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 63. 股票的最大利润

假设把某股票的价格按照时间先后顺序存储在数组中，请问买卖该股票一次可能获得的最大利润是多少？

**示例 1:**

```
输入: [7,1,5,3,6,4]
输出: 5
解释: 在第 2 天（股票价格 = 1）的时候买入，在第 5 天（股票价格 = 6）的时候卖出，最大利润 = 6-1 = 5 。
     注意利润不能是 7-1 = 6, 因为卖出价格需要大于买入价格。
```

**示例 2:**

```
输入: [7,6,4,3,1]
输出: 0
解释: 在这种情况下, 没有交易完成, 所以最大利润为 0。
```

**限制：**

```
0 <= 数组长度 <= 10^5
```

**注意：**本题与主站 121 题相同：[https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock/](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock/)

## 代码

**Go：**暴力法

```go
func maxProfit(prices []int) int {
    dp:=make([]int,100001)
    n:=len(prices)
    dp[0]=0;
    for i:=1;i<n;i++{
        dp[i]=prices[i]-prices[i-1]
    }
    max:=0
    for i:=0;i<n;i++{
        tmp:=0
        for j:=i+1;j<n;j++{
            tmp+=dp[j]
            if tmp>max{
                max=tmp
            }
        }
    }
    return max
}
```

**如何进一步优化**

动态规划五部曲分析如下：

1.确定dp数组（dp table）以及下标的含义 dp\[i\]\[0\] 表示第i天持有股票所得最多现金

一开始现金是0，那么加入第i天买入股票现金就是 -prices\[i\]， 这是一个负数。

dp\[i\]\[1\] 表示第i天不持有股票所得最多现金

注意这里说的是“持有”，“持有”不代表就是当天“买入”！也有可能是昨天就买入了，今天保持持有的状态

2.确定递推公式 如果第i天持有股票即dp\[i\]\[0\]， 那么可以由两个状态推出来

· 第i-1天就持有股票，那么就保持现状，所得现金就是昨天持有股票的所得现金 即：dp\[i - 1\]\[0\] · 第i天买入股票，所得现金就是买入今天的股票后所得现金即：-prices\[i\] 那么dp\[i\]\[0\]应该选所得现金最大的，所以dp\[i\]\[0\] = max(dp\[i - 1\]\[0\], -prices\[i\]);

如果第i天不持有股票即dp\[i\]\[1\]， 也可以由两个状态推出来

· 第i-1天就不持有股票，那么就保持现状，所得现金就是昨天不持有股票的所得现金 即：dp\[i - 1\]\[1\] · 第i天卖出股票，所得现金就是按照今天股票佳价格卖出后所得现金即：prices\[i\] + dp\[i - 1\]\[0\] 同样dp\[i\]\[1\]取最大的，dp\[i\]\[1\] = max(dp\[i - 1\]\[1\], prices\[i\] + dp\[i - 1\]\[0\]);

3.dp数组如何初始化 由递推公式 dp\[i\]\[0\] = max(dp\[i - 1\]\[0\], -prices\[i\]); 和 dp\[i\]\[1\] = max(dp\[i - 1\]\[1\], prices\[i\] + dp\[i - 1\]\[0\]);可以看出

其基础都是要从dp\[0\]\[0\]和dp\[0\]\[1\]推导出来。

那么dp\[0\]\[0\]表示第0天持有股票，此时的持有股票就一定是买入股票了，因为不可能有前一天推出来，所以dp\[0\]\[0\] -= prices\[0\];

dp\[0\]\[1\]表示第0天不持有股票，不持有股票那么现金就是0，所以dp\[0\]\[1\] = 0;

4.确定遍历顺序 从递推公式可以看出dp\[i\]都是有dp\[i - 1\]推导出来的，那么一定是从前向后遍历。

5.举例推导dp数组

**代码如下**

```go
func maxProfit(prices []int) int {
    length:=len(prices)
    if length==0{return 0}
    dp:=make([][]int,length)
    for i:=0;i<length;i++{
        dp[i]=make([]int,2)
    }

    dp[0][0]=-prices[0]
    dp[0][1]=0
    for i:=1;i<length;i++{
        dp[i][0]=max(dp[i-1][0],-prices[i])
        dp[i][1]=max(dp[i-1][1],dp[i-1][0]+prices[i])
    }
    return dp[length-1][1]
}

func max(a,b int)int {
    if a>b{
        return a 
    }
    return b 
}
```
