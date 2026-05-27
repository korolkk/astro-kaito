---
title: '剑指 Offer 53 - I. 在排序数组中查找数字 I'
description: '剑指 Offer 53 - I. 在排序数组中查找数字 I'
pubDate: 'Jan 10 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['LeetCode', '算法']
---
## 题目

剑指 Offer 53 - I. 在排序数组中查找数字 I

统计一个数字在排序数组中出现的次数。

**示例 1:**

```
输入: nums = [5,7,7,8,8,10], target = 8
输出: 2
```

**示例 2:**

```
输入: nums = [5,7,7,8,8,10], target = 6
输出: 0
```

**提示：**

*   `0 <= nums.length <= 105`
*   `-109 <= nums[i] <= 109`
*   `nums` 是一个非递减数组
*   `-109 <= target <= 109`

## 代码

**Go：**

```go
func search(nums []int, target int) int {
    var i,j,mid,count int

    i=0;
    j=len(nums)-1
    count=0
    for i<=j{
        mid=(i+j)/2
        if target==nums[mid]{
            i=mid
            j=mid
            for ;i>=0&&nums[i]==target;i--{
                count++
            }
            for ;j<=len(nums)-1&&nums[j]==target;j++{
                count++
            }
            return count-1
        }else if target>nums[mid] {
            i=mid+1
        }else {
            j=mid-1
        }
    }
    return 0;
}
```
