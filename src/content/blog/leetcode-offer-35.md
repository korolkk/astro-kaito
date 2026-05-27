---
title: '剑指 Offer 35. 复杂链表的复制'
description: '剑指 Offer 35. 复杂链表的复制'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 35. 复杂链表的复制

定义一个函数，输入一个链表的头节点，反转该链表并输出反转后链表的头节点。

**示例:**

```
输入: 1->2->3->4->5->NULL
输出: 5->4->3->2->1->NULL
```

**限制：**

```
0 <= 节点个数 <= 5000
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
func reverseList(head *ListNode) *ListNode {
    var p,q *ListNode
    p=head
    if head==nil{
        return nil
    }
    for p.Next!=nil{
        q=head
        head=p.Next
        p.Next=head.Next
        head.Next=q
    }
    return head
}
```
