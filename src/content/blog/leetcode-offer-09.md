---
title: '剑指 Offer 09. 用两个栈实现队列'
description: '剑指 Offer 09. 用两个栈实现队列'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 09. 用两个栈实现队列

用两个栈实现一个队列。队列的声明如下，请实现它的两个函数 `appendTail` 和 `deleteHead` ，分别完成在队列尾部插入整数和在队列头部删除整数的功能。(若队列中没有元素，`deleteHead` 操作返回 -1 )

**示例 1：**

```
输入：
["CQueue","appendTail","deleteHead","deleteHead","deleteHead"]
[[],[3],[],[],[]]
输出：[null,null,3,-1,-1]
```

**示例 2：**

```
输入：
["CQueue","deleteHead","appendTail","appendTail","deleteHead","deleteHead"]
[[],[],[5],[2],[],[]]
输出：[null,-1,null,null,5,2]
```

**提示：**

*   `1 <= values <= 10000`
*   最多会对 `appendTail、deleteHead` 进行 `10000` 次调用

## 代码

**C++：**

```cpp
class CQueue {
private:
    stack<int> inStack, outStack;

public:
    CQueue() {

    }

    void appendTail(int value) {
        inStack.push(value);
    }

    int deleteHead() {
        int a;
        if(outStack.empty())
        {
            while(!inStack.empty())
            {
                outStack.push(inStack.top());
                inStack.pop();
            }
        }
        if(outStack.empty())
            return -1;
        else
        {
            a=outStack.top();
            outStack.pop();
            return a;
        }

    }
};

/**
 * Your CQueue object will be instantiated and called as such:
 * CQueue* obj = new CQueue();
 * obj->appendTail(value);
 * int param_2 = obj->deleteHead();
 */
```

**Go：**

```go
type CQueue struct {
    inStack, outStack []int
}

//initial
func Constructor() CQueue {
    return CQueue{}
}

func (this *CQueue) AppendTail(value int)  {
    this.inStack=append(this.inStack,value)
}

func (this *CQueue) DeleteHead() int {
    if len(this.outStack)==0{
        for len(this.inStack)!=0 {
            v := this.inStack[len(this.inStack)-1]
            this.inStack = this.inStack[:len(this.inStack)-1]
            this.outStack=append(this.outStack,v)
        }
    }
    if len(this.outStack)==0{
        return -1
    }else {
        w := this.outStack[len(this.outStack)-1]
        this.outStack = this.outStack[:len(this.outStack)-1]
        return w
    }

}

/**
 * Your CQueue object will be instantiated and called as such:
 * obj := Constructor();
 * obj.AppendTail(value);
 * param_2 := obj.DeleteHead();
 */
```
