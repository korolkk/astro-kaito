---
title: '剑指 Offer 32 - I. 从上到下打印二叉树'
description: '剑指 Offer 32 - I. 从上到下打印二叉树'
pubDate: 'Jan 11 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 32 - I. 从上到下打印二叉树

从上到下打印出二叉树的每个节点，同一层的节点按照从左到右的顺序打印。

例如: 给定二叉树: `[3,9,20,null,null,15,7]`,

```
    3
   / \
  9  20
    /  \
   15   7
```

返回：

```
[3,9,20,15,7]
```

**提示：**

1.  `节点总数 <= 1000`

## 代码

**Go：**层序遍历，借助队列

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func levelOrder(root *TreeNode) []int {
    res:=make([]int,0)
    if root==nil {
        return nil
    }
    queue:=make([]*TreeNode,0)
    queue=append(queue,root)
    for len(queue)>0{
        node:=queue[0]
        res=append(res,node.Val)
        if node.Left!=nil{
            queue=append(queue,node.Left)
        }
        if node.Right!=nil{
            queue=append(queue,node.Right)
        }
        queue=queue[1:]
    }
    return res
}
```
