---
title: '剑指 Offer 24. 反转链表'
description: '剑指 Offer 24. 反转链表'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
---
## 题目

剑指 Offer 24. 反转链表

请实现 `copyRandomList` 函数，复制一个复杂链表。在复杂链表中，每个节点除了有一个 `next` 指针指向下一个节点，还有一个 `random` 指针指向链表中的任意节点或者 `null`。

**示例 1：**

![img](https://www.kkkode.top/wp-content/uploads/2023/01/post-368-63bcfdfda14f7.png)

```
输入：head = [[7,null],[13,0],[11,4],[10,2],[1,0]]
输出：[[7,null],[13,0],[11,4],[10,2],[1,0]]
```

**示例 2：**

![img](https://www.kkkode.top/wp-content/uploads/2023/01/post-368-63bcfdfdb28ed.png)

```
输入：head = [[1,1],[2,1]]
输出：[[1,1],[2,1]]
```

**示例 3：**

**![img](https://www.kkkode.top/wp-content/uploads/2023/01/post-368-63bcfdfdc920f.png)**

```
输入：head = [[3,null],[3,0],[3,null]]
输出：[[3,null],[3,0],[3,null]]
```

**示例 4：**

```
输入：head = []
输出：[]
解释：给定的链表为空（空指针），因此返回 null。
```

**提示：**

*   `-10000 <= Node.val <= 10000`
*   `Node.random` 为空（null）或指向链表中的节点。
*   节点数目不超过 1000 。

## 代码

**Go：**

```go
/**
 * Definition for a Node.
 * type Node struct {
 *     Val int
 *     Next *Node
 *     Random *Node
 * }
 */

func copyRandomList(head *Node) *Node {
    if head==nil{
        return nil
    }
    var p,q  *Node
    for p := head; p != nil; p = p.Next.Next {
        p.Next = &Node{Val: p.Val, Next: p.Next}
    }

    for p=head;p!=nil;p=p.Next.Next{
        if p.Random!=nil{
            p.Next.Random=p.Random.Next
        }        

    }
    newhead:=head.Next
    q=head

    for p=head.Next.Next;p!=nil;p=p.Next.Next{
        q.Next.Next=p.Next;
        q.Next=p
        q=p;
    } 
    q.Next=nil
    return newhead

}
```
