---
title: '剑指 Offer 05. 替换空格'
description: '剑指 Offer 05. 替换空格'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
---
## 题目

剑指 Offer 05. 替换空格

请实现一个函数，把字符串 `s` 中的每个空格替换成"%20"。

**示例 1：**

```
输入：s = "We are happy."
输出："We%20are%20happy."
```

**限制：**

```
0 <= s 的长度 <= 10000
```

## 代码

**Go：**

```go
func replaceSpace(s string) string {
    var news string
    for i:=0;i!=len(s);i++{
        if s[i]!=' '{
            news+=string(s[i])
        }else{
            news+="%20"
        }
    }
    return news
}
```
