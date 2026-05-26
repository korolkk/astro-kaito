---
title: '剑指 Offer 26. 树的子结构'
description: '剑指 Offer 26. 树的子结构'
pubDate: 'Jan 14 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
---
## 题目

剑指 Offer 26. 树的子结构

输入两棵二叉树A和B，判断B是不是A的子结构。(约定空树不是任意一个树的子结构)

B是A的子结构， 即 A中有出现和B相同的结构和节点值。

例如:给定的树 A:

```
    3
   / \
   4  5
  / \
 1  2
```

给定的树 B：

```
   4 
  /
 1
```

返回 true，因为 B 与 A 的一个子树拥有相同的结构和节点值。

**示例 1：**

```
输入：A = [1,2,3], B = [3,1]
输出：false
```

**示例 2：**

```
输入：A = [3,4,5,1,2], B = [4,1]
输出：true
```

**限制：**

```
0 <= 节点个数 <= 10000
```

## 代码

**Go：** DFS深度优先搜索

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func isSameTree(A *TreeNode, B *TreeNode) bool {
    if A==nil&&B!=nilA==nil&&B!=nil{
        return false
    }else if A!=nil&&B!=nil{
        if A.Val!=B.Val{
            return false
        }else if isSameTree(A.Left,B.Left)==falseisSameTree(A.Right,B.Right)==false{
            return false
        }
    }
    return true
}

func DFS(root *TreeNode,B *TreeNode) bool{
    if root==nil{
        return false
    }
    if isSameTree(root,B){
        return true
    }else if root.Left!=nil&&DFS(root.Left,B){
        return true
    }else if root.Right!=nil&&DFS(root.Right,B){
        return true
    }
    return false
}

func isSubStructure(A *TreeNode, B *TreeNode) bool {
    if B==nil{
        return false
    }
    return DFS(A,B)
}
```

**优化后的代码：**时间不变，内存占用减少

```go
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */

func compare(A *TreeNode, B *TreeNode) bool{
    if B == nil{
        return true
    }
    if A == nil{
        return false
    }
    return A.Val == B.Val && compare(A.Left, B.Left) && compare(A.Right, B.Right)
}

func isSubStructure(A *TreeNode, B *TreeNode) bool {
    if(A == nil  B == nil) {
        return false
    }
    return compare(A, B)  isSubStructure(A.Left, B)  isSubStructure(A.Right, B)
}
```
