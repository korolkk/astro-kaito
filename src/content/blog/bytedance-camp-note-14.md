---
title: 'JWT认证 ｜ 字节跳动青训营笔记'
description: '参数'
pubDate: 'Feb 10 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
---
## 配置

参数

介绍

`Key`

用于设置签名密钥（**必要配置**）

`KeyFunc`

用于设置获取签名密钥的回调函数，设置后 token 解析时将从 `KeyFunc` 获取 `jwt` 签名密钥

`Timeout`

用于设置 token 过期时间，默认为一小时

`MaxRefresh`

用于设置最大 token 刷新时间，允许客户端在 `TokenTime` + `MaxRefresh` 内刷新 token 的有效时间，追加一个 `Timeout` 的时长

`Authenticator`

用于设置登录时认证用户信息的函数（**必要配置**）

`Authorizator`

用于设置授权已认证的用户路由访问权限的函数

`PayloadFunc`

用于设置登陆成功后为向 token 中添加自定义负载信息的函数

`Unauthorized`

用于设置 jwt 验证流程失败的响应函数

## 流程

### 用户登陆（认证）

注册完成后，服务器需要在用户第一次登陆的时候，验证用户账号和密码，并签发 jwt token。

```go
JwtMiddleware, err = jwt.New(&jwt.HertzJWTMiddleware{
    Key:           []byte("secret key"),
    Timeout:       time.Hour,
    MaxRefresh:    time.Hour,
    Authenticator: func(ctx context.Context, c *app.RequestContext) (interface{}, error) {
        var loginStruct struct {
            Account  string `form:"account" json:"account" query:"account" vd:"(len($) > 0 && len($) < 30); msg:'Illegal format'"`
            Password string `form:"password" json:"password" query:"password" vd:"(len($) > 0 && len($) < 30); msg:'Illegal format'"`
        }
        if err := c.BindAndValidate(&loginStruct); err != nil {
            return nil, err
        }
        users, err := mysql.CheckUser(loginStruct.Account, utils2.MD5(loginStruct.Password))
        if err != nil {
            return nil, err
        }
        if len(users) == 0 {
            return nil, errors.New("user already exists or wrong password")
        }

        return users[0], nil
    },
    PayloadFunc: func(data interface{}) jwt.MapClaims {
        if v, ok := data.(*model.User); ok {
            return jwt.MapClaims{
                jwt.IdentityKey: v,
            }
        }
        return jwt.MapClaims{}
    },
})
```

*   Authenticator：用于设置登录时认证用户信息的函数，demo 当中定义了一个 `loginStruct` 结构接收用户登陆信息，并进行认证有效性。这个函数的返回值 `users[0]` 将为后续生成 jwt token 提供 payload 数据源。
    
*   PayloadFunc：它的入参就是 `Authenticator` 的返回值，此时负责解析 `users[0]`，并将用户名注入 token 的 payload 部分。
    
*   Key：指定了用于加密 jwt token 的密钥为 `"secret key"`。
    
*   Timeout：指定了 token 有效期为一个小时。
    
*   MaxRefresh：用于设置最大 token 刷新时间，允许客户端在 `TokenTime` + `MaxRefresh` 内刷新 token 的有效时间，追加一个 `Timeout` 的时长。
    

### Token 的返回

```verilog
JwtMiddleware, err = jwt.New(&jwt.HertzJWTMiddleware{
    LoginResponse: func(ctx context.Context, c *app.RequestContext, code int, token string, expire time.Time) {
        c.JSON(http.StatusOK, utils.H{
            "code":    code,
            "token":   token,
            "expire":  expire.Format(time.RFC3339),
            "message": "success",
        })
    },
})
```

*   LoginResponse：在登陆成功之后，jwt token 信息会随响应返回，你可以自定义这部分的具体内容，但注意不要改动函数签名，因为它与 `LoginHandler` 是强绑定的。

### Token 的校验

访问配置了 jwt 中间件的路由时，会经过 jwt token 的校验流程。

```go
JwtMiddleware, err = jwt.New(&jwt.HertzJWTMiddleware{
    TokenLookup:   "header: Authorization, query: token, cookie: jwt",
    TokenHeadName: "Bearer",
    HTTPStatusMessageFunc: func(e error, ctx context.Context, c *app.RequestContext) string {
        hlog.CtxErrorf(ctx, "jwt biz err = %+v", e.Error())
        return e.Error()
    },
    Unauthorized: func(ctx context.Context, c *app.RequestContext, code int, message string) {
        c.JSON(http.StatusOK, utils.H{
            "code":    code,
            "message": message,
        })
    },
})
```

*   TokenLookup：用于设置 token 的获取源，可以选择 `header`、`query`、`cookie`、`param`，默认为 `header:Authorization`，同时存在是以左侧一个读取到的优先。当前 demo 将以 `header` 为数据源，因此在访问 `/ping` 接口时，需要你将 token 信息存放在 HTTP Header 当中。
    
*   TokenHeadName：用于设置从 header 中获取 token 时的前缀，默认为 `"Bearer"`。
    
*   HTTPStatusMessageFunc：用于设置 jwt 校验流程发生错误时响应所包含的错误信息，你可以自行包装这些内容。
    
*   Unauthorized：用于设置 jwt 验证流程失败的响应函数，当前 demo 返回了错误码和错误信息。
    

### 用户信息的提取

```go
JwtMiddleware, err = jwt.New(&jwt.HertzJWTMiddleware{
    IdentityKey: IdentityKey,
    IdentityHandler: func(ctx context.Context, c *app.RequestContext) interface{} {
        claims := jwt.ExtractClaims(ctx, c)
        return &model.User{
            UserName: claims[IdentityKey].(string),
        }
    },
})

// Ping .
func Ping(ctx context.Context, c *app.RequestContext) {
    user, _ := c.Get(mw.IdentityKey)
    c.JSON(200, utils.H{
        "message": fmt.Sprintf("username:%v", user.(*model.User).UserName),
    })
}
```

*   IdentityHandler：用于设置获取身份信息的函数，在 demo 中，此处提取 token 的负载，并配合 `IdentityKey` 将用户名存入上下文信息。
*   IdentityKey：用于设置检索身份的键，默认为 `"identity"`。
*   Ping：构造响应结果，从上下文信息中取出用户名信息并返回。

### 参数绑定

hertz 使用开源库 [go-tagexpr](https://github.com/bytedance/go-tagexpr) 进行参数的绑定及验证，demo 中也频繁使用了这个特性。

```csharp
var loginStruct struct {
    // 通过声明 tag 进行参数绑定和验证
    Account  string `form:"account" json:"account" query:"account" vd:"(len($) > 0 && len($) < 30); msg:'Illegal format'"`
    Password string `form:"password" json:"password" query:"password" vd:"(len($) > 0 && len($) < 30); msg:'Illegal format'"`
}
if err := c.BindAndValidate(&loginStruct); err != nil {
    return nil, err
}
```
