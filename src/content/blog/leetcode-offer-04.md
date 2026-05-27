---
title: '剑指 Offer 04. 二维数组中的查找'
description: '剑指 Offer 04. 二维数组中的查找'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 04. 二维数组中的查找

在一个 n \* m 的二维数组中，每一行都按照从左到右 **非递减** 的顺序排序，每一列都按照从上到下 **非递减** 的顺序排序。请完成一个高效的函数，输入这样的一个二维数组和一个整数，判断数组中是否含有该整数。

**示例:**

现有矩阵 matrix 如下：

```
[
  [1,   4,  7, 11, 15],
  [2,   5,  8, 12, 19],
  [3,   6,  9, 16, 22],
  [10, 13, 14, 17, 24],
  [18, 21, 23, 26, 30]
]
```

给定 target = `5`，返回 `true`。

给定 target = `20`，返回 `false`。

**限制：**

```
0 <= n <= 1000
0 <= m <= 1000
```

## 代码

**Go：**

```go
func findNumberIn2DArray(matrix [][]int, target int) bool {
    var flagx,flagy int
    if len(matrix)==0len(matrix[0])==0{
        return false
    }

    flagx=len(matrix)-1
    flagy=0
    for matrix[flagx][flagy]!=target{
        if matrix[flagx][flagy]>target && flagx>0{
            flagx--
        }else if matrix[flagx][flagy]<target && flagy<len(matrix[flagx])-1{
            flagy++
        }else{
            return false
        }
    }
    return true

}
```
