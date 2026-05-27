---
title: '剑指 Offer 27. 二叉树的镜像'
description: '剑指 Offer 27. 二叉树的镜像'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 27. 二叉树的镜像

请完成一个函数，输入一个二叉树，该函数输出它的镜像。

例如输入：

```
    4
   / \
  2   7
 / \  / \
1  3 6   9
```

镜像输出：

```
    4
   /  \
  7   2
 / \  / \
 9  6 3  1
```

**示例 1：**

```
输入：root = [4,2,7,1,3,6,9]
输出：[4,7,2,9,6,3,1]
```

**限制：**

```
0 <= 节点个数 <= 1000
```

注意：本题与主站 226 题相同：[https://leetcode-cn.com/problems/invert-binary-tree/](https://leetcode-cn.com/problems/invert-binary-tree/)

## 代码

**Go：**

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func exchangeNode(root *TreeNode){
    if root!=nil{
        root.Left,root.Right=root.Right,root.Left
        exchangeNode(root.Left)
        exchangeNode(root.Right)
    }
}

func mirrorTree(root *TreeNode) *TreeNode {
    exchangeNode(root)
    return root
}
```
