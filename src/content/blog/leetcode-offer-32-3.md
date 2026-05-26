---
title: '剑指 Offer 32 - III. 从上到下打印二叉树 III'
description: '剑指 Offer 32 - III. 从上到下打印二叉树 III'
pubDate: 'Jan 11 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
---
## 题目

剑指 Offer 32 - III. 从上到下打印二叉树 III

请实现一个函数按照之字形顺序打印二叉树，即第一行按照从左到右的顺序打印，第二层按照从右到左的顺序打印，第三行再按照从左到右的顺序打印，其他行以此类推。

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
  [20,9],
  [15,7]
]
```

**提示：**

1.  `节点总数 <= 1000`

## 代码

**Go：**层次遍历，之字形说明栈和队列交错输出

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
    flag:=1
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
        if flag==1{
            res=append(res,tmp)
        }else{
            v:=make([]int,0)
            for len(tmp)>0{
                v=append(v,tmp[len(tmp)-1])
                tmp=tmp[:len(tmp)-1]
            }
            res=append(res,v)
        }
        flag=-flag
        oldqueue=newqueue
    }
    return res
}
```
