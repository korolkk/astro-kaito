---
title: '剑指 Offer 06. 从尾到头打印链表'
description: '剑指 Offer 06. 从尾到头打印链表'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 06. 从尾到头打印链表

输入一个链表的头节点，从尾到头反过来返回每个节点的值（用数组返回）。

**示例 1：**

```
输入：head = [1,3,2]
输出：[2,3,1]
```

**限制：**

```
0 <= 链表长度 <= 10000
```

## 代码

**Go：**

```go
/**
 * Definition for singly-linked list.
 * type ListNode struct {
 *     Val int
 *     Next *ListNode
 * }
 */

func reversePrint(head *ListNode) []int {
    if head==nil{
        res:=make([]int,0) 
        return res
    }

    return append(reversePrint(head.Next),head.Val)
}
```
