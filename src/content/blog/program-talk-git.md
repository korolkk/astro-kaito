---
title: '基于GitHub代码托管的团队合作开发常用git操作'
description: '暂无简介'
pubDate: 'Feb 09 2023'
heroImage: '../../assets/blog-placeholder-3.jpg'
---
## 基本git命令

### 查看仓库名

git remote

### 查看推送至仓库的用户名和邮箱

git config user.name git config user.email

### 设置推送至仓库的用户名和邮箱

git config --global user.email "you@example.com"

git config --global user.name "Your Name"

–global 对当前用户所有仓库有效

–local 只对某个仓库有效

–system 对系统所有登录的用户有效

### 显示config配置

git config --list

### 刷新远程仓库分支

git fetch

### 查看仓库名对应的远程仓库的地址

git remote -v

### git远程仓库更换名称

git remote set-url origin 新的远程仓库地址

### 上传到远程仓库命令：

git push 仓库名 分支名

//默认是：git push origin master

### 显示上一次提交之前工作目录与git仓库之间的差异

git diff HEAD^

// 在git pull后，可以通过git diff HEAD^ 来查看拉下来的文件有那些具体的修改。

### git撤销本次pull

git merge --abort

// 如果不小心pull了代码，并且有冲突，不想解决。想要放弃本次pull就使用这个命令。

### 查看所有分支的所有操作记录

git reflog

### 合并到当前所在分支

如：git merge winne

// 把本地winne分支代码合并到当前master分支

如：git pull origin winne

// 把远程仓库winne分支代码合并到当前master分支

## 团队开发clone项目和提交项目

为了让同组开发人员也能把github上的资源下载下来之后，他修改的版本也能够同步到远程仓库中，那么就要在这个仓库上添加合伙人（collaborator）： 此步骤是在github上操作，找到 collaborator的设置地方，然后填好合伙人的用户名设置好，然后点击添加。之后他就会收到一个邀请信息，通过之后就能一同同步更新这个开发项目了。 git status :查看当前状态下的文件变化

1.  组员要把项目先克隆下来：git clone 地址
2.  安装需要的依赖项，运行项目，参与项目开发: npm install
3.  新建并切换到新分支（因为人多了不可能都在主分支master开发）：

## 多人协作解决代码上的冲突问题

在多人协作的时候，每次进行版本的push都要先同步一下自己本地项目和远程仓库上的最新版本代码，避免出现代码冲突问题。

使用 git pull origin 分支名 （把想要的分支内容拉取到本地）

1.  拉取github仓库代码同步合并到本地文件：git pull origin 分支名
2.  然后直接到本地文件中进行合并代码后的冲突代码的取舍（编辑器工具有智能提示，所以很容易进行对比，手动解决冲突）
3.  最后就可以把完好的没有冲突的代码提交同步到github了
4.  本地开发代码关联新创建的远程仓库
