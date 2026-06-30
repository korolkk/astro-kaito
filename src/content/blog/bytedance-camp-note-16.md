---
title: '大项目Redis的原理及应用 ｜ 字节跳动青训营笔记'
description: 'Redis核心原理与实战应用，深入理解数据结构、持久化机制与缓存策略'
pubDate: 'Feb 22 2023'
heroImage: '../../assets/blog-placeholder-2.jpg'
tags: ['字节青训营', '后端']
---
## Redis介绍

### 简单概念

*   redis作为NoSql的一种，拥有NoSQL相关特点
    
*   redis支持数据的持久化，将内存中的数据保存到磁盘中，重启的时候可以再次加载进行使用
    
*   redis不仅仅支持key-value数据，还支持：string,list,set,hash等
    
*   redis支持数据备份，即master-slaver模式的数据备份
    

### 常见命令

通用指令是部分数据类型的，都可以使用的指令，常见的有:

*   `KEYS`:查看符合模板的所有key，不建议在生产环境设备上使用
*   `DEL`:删除一个指定的key
*   `EXISTS`:判断key是否存在
*   `EXPIRE`:给一个key设置有效期，有效期到期时该key会被自动删除
*   `TTL`:查看一个KEY的剩余有效期 (-1：代表永久有效)

还有其他几种数据结构操作命令参考[Redis](https://link.juejin.cn?target=https%3A%2F%2Fredis.io%2F)官网

## go操作Redis

### 获取Redis连接

```go
func GetRedisConnection() redis.Conn {
    c, err := redis.Dial("tcp", "localhost:6379")
    if err != nil {
        fmt.Println("conn redis failed,", err)
        return nil
    }
    fmt.Println("redis conn success")

    return c
}
```

`Dial`获取Redis连接：本地Redis使用6379端口

### 操作基础命令

*   Set命令

```go
//获取redis连接
    conn := utils.GetRedisConnection()
    if conn == nil {
        fmt.Println("获取redis连接失败")
    }

    //将token存入用户信息存入redis中
    token := utils.RandString(32)
    userJson, err := json.Marshal(user)
    if err != nil {
        fmt.Println(err)
    }
//使用set命令
    conn.Do("set", constant.USER_FLAG+token, userJson)
```

*   Get命令

```go
conn := utils.GetRedisConnection()
    userjson, err := redis.String(conn.Do("get", constant.USER_FLAG+token))
    if err != nil {
        fmt.Println(err)
    }

    var user common.User
    json.Unmarshal([]byte(userjson), &user)
    //redis中不存在用户信息，从数据库中查找
    if user.Username == "" {
        user = dao.GetInfos(userId)
    }
```

注：`redis.string()方法`将`get`命令返回的数据转成字符串，还有类似的`redis.int()方法`

### 基本思路

每个用户有都有一个关注 set 和粉丝 set，set 的存储的是用户的唯一 ID。

每当用户关注某人时，就会被写入到关注 set 中，同时对方的粉丝 set 也会记录当前用户

当需要判断两人是否进行互相关注时，可以直接使用 redis 中的 集合操作，找出对方关注 set 的交集。

原本我们使用 SQL 来实现这个功能的，性能上并不是很高效。

这样就可以免去使用 MySQL 查询实现了，更高效地提高性能。

### 操作Set相关命令

在上述操作Redis基础命令上，我们进阶一下使用最常用的set数据结构命令

*   判断用户是否是成员

```go
//省略Redis连接
//redis中set判断是否存在
        result, err := redis.Int(conn.Do("SISMEMBER", constant.VIDEO_FLAG+string(videoId), user.UserId))
        //不存在，点赞操作
        if err != nil {
            fmt.Println(err)
        }
复制代码
```

当`result==1`时:表示是存在该成员变量

当`result==0`时:表示是不存在该成员变量

*   获取所有成员

```go
conn.Do("SMEMBERS", constant.VIDEO_FLAG+string(videoId))
```

返回SET集合该key的所有成员

### 注意点

使用 redis 作为缓存需要额外注意“缓存失效”的情况。当 redis 查不到数据时，需要转而查询 MySQL 后端数据库，并且查到数据后，一定要将其更新到 redis 服务器中！

这里有一个提升效率的小细节：在往 redis 服务器更新数据的时候，可以作异步处理，另开一个协程进行更新。

这样当从 MySQL 查询出数据后，不必等待 redis 服务器的更新就可以及时将数据响应了！
