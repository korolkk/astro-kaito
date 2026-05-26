---
title: '剑指 Offer 28. 对称的二叉树'
description: '剑指 Offer 28. 对称的二叉树'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
---
## 题目

剑指 Offer 28. 对称的二叉树

请实现一个函数，用来判断一棵二叉树是不是对称的。如果一棵二叉树和它的镜像一样，那么它是对称的。

例如，二叉树 \[1,2,2,3,4,4,3\] 是对称的。

```
     1
    / \
   2   2
  / \ / \
 3  4 4  3
```

但是下面这个 \[1,2,2,null,3,null,3\] 则不是镜像对称的:

```
    1
   / \
  2   2
   \   \
    3   3
```

**示例 1：**

```
输入：root = [1,2,2,3,4,4,3]
输出：true
```

**示例 2：**

```
输入：root = [1,2,2,null,3,null,3]
输出：false
```

**限制：**

```
0 <= 节点个数 <= 1000
```

注意：本题与主站 101 题相同：[https://leetcode-cn.com/problems/symmetric-tree/](https://leetcode-cn.com/problems/symmetric-tree/)

## 代码

**Go：**递归判断左右子树是否对称

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func compareNode(A *TreeNode,B *TreeNode) bool{
    if A==nil&&B==nil{
        return true
    }
    if A==nilB==nilA.Val!=B.Val{
        return false
    }
    return compareNode(A.Left,B.Right)&&compareNode(A.Right,B.Left)
}

func isSymmetric(root *TreeNode) bool {
    if root==nil{
        return true
    }else{
        return compareNode(root.Left,root.Right)
    }
}
```
