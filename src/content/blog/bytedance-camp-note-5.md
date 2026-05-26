---
title: 'Go 框架三件套详解(Web/RPC/ORM) ｜ 字节跳动青训营笔记'
description: '暂无简介'
pubDate: 'Feb 01 2023'
heroImage: '../../assets/blog-placeholder-5.jpg'
---
## 一、Gorm：

### Gorm的约定

*   使用名为ID的字段作为主键
*   默认结构体的蛇形复数作为表名，字段名的蛇形作为列名
*   使用CreatedAt、UpdateAt字段作为创建、更新时间

### Gorm支持的数据库

*   MySQL、SQLServer、PostgreSQL、SQLite，通过驱动连接
    
    ```go
    import (
    "gorm.io/driver/mysql"
    "gorm.io/gorm"
    )
    
    db, err := gorm.Open(
        mysql.Open("root:123456@tcp(127.0.0.1:3306)/test?charset=utf8mb4&parseTime=True&loc=Local"),
        &gorm.Config{})
    ```
    

### 创建数据

*   使用default标签为字段定义默认值
*   使用clause.OnConflict处理数据冲突

```go
p:=&Product{Code:"D42",ID:1}
//不处理冲突
db.Create(p)
//处理冲突
db.clauses(clause.OnConflict{DoNothing:true}).Create(&p)
```

### 查询数据

*   First查询单条数据失败返回ErrRecordNotFound，查询多条数据，查询不到不会返回错误
*   使用结构体作为查询条件，如果字段值为0、''、false或其他零值，不会用于构建查询条件。需要使用Map来构建

```go
// SELECT * FROM users ORDER BY id LIMIT 1;
db.First(&user)
// SELECT * FROM users WHERE name IN ('jinzhu','jinzhu2');
db.Where("name IN ?",[]string{"jinzhu","jinzhu2"}).Find(&users)
// SELECT * FROM users WHERE name LIKE '%jin%';
db.Where("name LIKE ?","%jin%").Find(&users)

// SELECT * FROM users WHERE name='jinzhu';
db.Where(&User{name:"jinzhu",Age:0}).Find(&users)
// SELECT * FROM users WHERE name='jinzhu'AND age=0;
db.Where(map[string]interface{}{"name":"jinzhu","Age":0}).Find(&users)
```

### 更新数据

*   使用结构体作为更新零值同样需要使用Map来构建
*   SQL表达式更新
*   调用model！！不是db！！

```go
// UPDATE "products" SET "price"=price*2+100,"updated_at"='2013-11-17-21:34:10' WHERE 'id'=111;
db.model(&User{ID:111}).Update("age",gorm.Expr("age*?+?",2,100))
```

### 删除数据

*   通过gorm.DeletedAt用于实现软删除，记录不会从数据库中真正删除，但会将DeletedAt置为当前时间，并且不能再通过正常的查询方法找到该记录
*   使用Unscoped可以查询软删除的数据

### 事务

*   通过Tansaction方法用于自动提交事务，避免用户漏写Commit、Rollback

```go
if err=db.Transaction(fun(tx *gorm.DB){
    if err=tx.create(&User{Name:"name"}).Error;err!=nil{
        return err
    }
});err !=nil{
    return
}
```

### Hook

*   Hook 是在创建、查询、更新、删除等操作之前、之后调用的函数。
*   如果您已经为模型定义了指定的方法，它会在创建、更新、查询、删除时自动被调用。如果任何回调返回错误，GORM 将停止后续的操作并回滚事务。
*   钩子方法的函数签名应该是 `func(*gorm.DB) error`

```go
func (u *User) BeforeCreate(tx *gorm.DB) (err error) {
  u.UUID = uuid.New()

  if !u.IsValid() {
    err = errors.New("can't save invalid data")
  }
  return
}

func (u *User) AfterCreate(tx *gorm.DB) (err error) {
  if u.ID == 1 {
    tx.Model(u).Update("role", "admin")
  }
  return
}
```

### 性能提高

*   对于写操作（创建、更新、删除），为了确保数据的完整性，GORM 会将它们封装在事务内运行，但这会降低性能
*   执行任何 SQL 时都创建并缓存预编译语句，可以提高后续的调用速度

```go
db, err := gorm.Open(sqlite.Open("gorm.db"), &gorm.Config{
  SkipDefaultTransaction: true,
  PrepareStmt: true
})
```

## 二、Kitex

### 关于 Kitex

Kitex 是一个 RPC 框架，既然是 RPC，底层就需要两大功能：

1.  Serialization 序列化
2.  Transport 传输

Kitex 框架及命令行工具，默认支持 `thrift` 和 `proto3` 两种 IDL，对应的 Kitex 支持 `thrift` 和 `protobuf` 两种序列化协议。 传输上 Kitex 使用扩展的 `thrift` 作为底层的传输协议（注：thrift 既是 IDL 格式，同时也是序列化协议和传输协议）。IDL 全称是 Interface Definition Language，接口定义语言。

### 运行环境

VMware Centos7

具体安装和网络配置参照文章，可以实现手机连接同一wifi测试虚拟机内抖音项目demo

[Centos7.7安装及配置教程 - 掘金 (juejin.cn)](https://juejin.cn/post/6844904101583519752)

期间踩了无数坑，还碰巧给虚拟机配和手机相同ip，电脑测试正常，手机网络异常，大家千万要避坑！！

### thrift版本的问题

由于thrift最新版本与kitex不兼容，所以需要输入以下命令切换版本

```bash
go mod edit -replace github.com/apache/thrift=github.com/apache/thrift@v0.13.0
```

### DEMO运行

具体步骤参照[快速开始 CloudWeGo](https://www.cloudwego.io/zh/docs/kitex/getting-started/#基础教程)

## 三、Hertz

### 基本使用

```go
package main

import (
    "context"

    "github.com/cloudwego/hertz/pkg/app"
    "github.com/cloudwego/hertz/pkg/app/server"
    "github.com/cloudwego/hertz/pkg/common/utils"
    "github.com/cloudwego/hertz/pkg/protocol/consts"
)

func main() {
    h := server.Default()

    h.GET("/ping", func(c context.Context, ctx *app.RequestContext) {
            ctx.JSON(consts.StatusOK, utils.H{"message": "pong"})
    })

    h.Spin()
}
```

### 路由

*   Hertz提供了GET、POST、PUT、DELETE、ANY等方法用于注册路由。
*   Hertz提供了路由组(Group的能力，用于支持路由分组的功能
*   Hrtz提供了参数路由和通配路由，路由的优先级为：静态路由>命名路由>通配路由

### 参数绑定

Hertz提供了Bind、Validate、BindAndValidate函数用于进行参数绑定和校验

### 中间件

中间件会按定义的先后顺序依次执行，如果想快速终止中间件调用，可以使用以下方法，注意**当前中间件仍将执行**。

*   `Abort()`：终止后续调用
*   `AbortWithMsg(msg string, statusCode int)`：终止后续调用，并设置 response中body，和状态码
*   `AbortWithStatus(code int)`：终止后续调用，并设置状态码

```go
// 方式一
func MyMiddleware() app.HandlerFunc {
  return func(ctx context.Context, c *app.RequestContext) {
    // pre-handle
    // ...
    c.Next(ctx)
  }
}

// 方式二
func MyMiddleware() app.HandlerFunc {
  return func(ctx context.Context, c *app.RequestContext) {
    c.Next(ctx) // call the next middleware(handler)
    // post-handle
    // ...
  }
}
```

### 代码生成工具

Hertz提供了代码生成工具Hz,通过定义IDL文件即可生成对应的基础服务代码

## 四、笔记项目实战

阅读笔记项目的代码并可以在本地环境运行起来

## 五、课后个人总结：

课后要进一步熟悉Gorm/Kitex/Hertz的使用，尤其是关注官方文档

多多阅读笔记项目的代码，以便在后续大作业进行参考
