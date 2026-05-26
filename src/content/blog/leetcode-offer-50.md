---
title: '剑指 Offer 50. 第一个只出现一次的字符'
description: '剑指 Offer 50. 第一个只出现一次的字符'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
---
## 题目

剑指 Offer 50. 第一个只出现一次的字符

在字符串 s 中找出第一个只出现一次的字符。如果没有，返回一个单空格。 s 只包含小写字母。

**示例 1:**

```
输入：s = "abaccdeff"
输出：'b'
```

**示例 2:**

```
输入：s = "" 
输出：' '
```

**限制：**

```
0 <= s 的长度 <= 50000
```

## 代码

**Go：**哈希表映射，map没有顺序

```go
func firstUniqChar(s string) byte {
    chars := make(map[byte]int)

    for i:=0;i<len(s);i++{
        chars[s[i]]++
    }
    for i:=0;i<len(s);i++{
        if chars[s[i]]==1{
            return s[i]
        }
    }
    return ' '
}
```
