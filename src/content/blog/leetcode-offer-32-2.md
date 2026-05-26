---
title: '剑指 Offer 32 - II. 从上到下打印二叉树 II'
description: '剑指 Offer 32 - II. 从上到下打印二叉树 II'
pubDate: 'Jan 11 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
---
## 题目

剑指 Offer 32 - II. 从上到下打印二叉树 II

从上到下按层打印二叉树，同一层的节点按从左到右的顺序打印，每一层打印到一行。

例如: 给定二叉树: `[3,9,20,null,null,15,7]`,

```
    3
   / \
  9  20
    /  \
   15   7
```

返回其层次遍历结果：

```
[
  [3],
  [9,20],
  [15,7]
]
```

**提示：**

1.  `节点总数 <= 1000`

注意：本题与主站 102 题相同：[https://leetcode-cn.com/problems/binary-tree-level-order-traversal/](https://leetcode-cn.com/problems/binary-tree-level-order-traversal/)

## 代码

**Go：**层次遍历，每次的旧队列是一层，新队列是下一层

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func levelOrder(root *TreeNode) [][]int {
    res:=make([][]int,0)
    if root==nil {
        return nil
    }
    oldqueue:=make([]*TreeNode,0)
    oldqueue=append(oldqueue,root)
    for len(oldqueue)>0{
        newqueue:=make([]*TreeNode,0)
        tmp:=make([]int,0)
        for len(oldqueue)>0{
            tmp=append(tmp,oldqueue[0].Val)
            if oldqueue[0].Left!=nil{
                newqueue=append(newqueue,oldqueue[0].Left)
            }
            if oldqueue[0].Right!=nil{
                newqueue=append(newqueue,oldqueue[0].Right)
            }
            oldqueue=oldqueue[1:]
        }
        res=append(res,tmp)
        oldqueue=newqueue
    }
    return res
}
```
