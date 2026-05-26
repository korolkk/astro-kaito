---
title: '剑指 Offer 30. 包含min函数的栈'
description: '剑指 Offer 30. 包含min函数的栈'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
---
## 题目

剑指 Offer 30. 包含min函数的栈

定义栈的数据结构，请在该类型中实现一个能够得到栈的最小元素的 min 函数在该栈中，调用 min、push 及 pop 的时间复杂度都是 O(1)。

**示例:**

```
MinStack minStack = new MinStack();
minStack.push(-2);
minStack.push(0);
minStack.push(-3);
minStack.min();   --> 返回 -3.
minStack.pop();
minStack.top();      --> 返回 0.
minStack.min();   --> 返回 -2.
```

**提示：**

1.  各函数的调用总次数不超过 20000 次

## 代码

**C++：**

```cpp
class MinStack {
private:
    stack<int> mstack;
    int minnum[20000];
    int length;
public:
    /** initialize your data structure here. */
    MinStack() {
        minnum[0]=0;
        length=0;
    }

    void push(int x) {
        if(length==0)
        {
            minnum[length+1]=x;
        }
        else
        {
            if(minnum[length]<x)
                minnum[length+1]=minnum[length];
            else
                minnum[length+1]=x;
        }
        length++;
        mstack.push(x);
    }

    void pop() {
        mstack.pop();
        length--;
    }

    int top() {
        return mstack.top();
    }

    int min() {
        return minnum[length];
    }
};

/**
 * Your MinStack object will be instantiated and called as such:
 * MinStack* obj = new MinStack();
 * obj->push(x);
 * obj->pop();
 * int param_3 = obj->top();
 * int param_4 = obj->min();
 */
```

**Go：**

```go
type MinStack struct {
    min,data []int
}

/** initialize your data structure here. */
func Constructor() MinStack {
    return MinStack{}
}

func (this *MinStack) Push(x int)  {
    if len(this.data)==0  x<this.min[len(this.min)-1]{
        this.min=append(this.min,x)
    }else{
        this.min=append(this.min,this.min[len(this.min)-1])
    }
    this.data=append(this.data,x)
}

func (this *MinStack) Pop()  {
    if len(this.data)!=0{
        this.data=this.data[:len(this.data)-1]
        this.min=this.min[:len(this.min)-1]
    }
}

func (this *MinStack) Top() int {
    return this.data[len(this.data)-1]
}

func (this *MinStack) Min() int {
    return this.min[len(this.min)-1]
}

/**
 * Your MinStack object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Push(x);
 * obj.Pop();
 * param_3 := obj.Top();
 * param_4 := obj.Min();
 */
```
