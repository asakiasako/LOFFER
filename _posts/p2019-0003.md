---
layout: post
title: Python 的包管理利器：pipenv
date: 2019-07-10
Author: MinimaLife
tags: [tech, coding, pipenv, python]
comments: true
toc: false
pinned: false
---
众所周知，Node 项目自带 npm 包管理机制，能够有条理的处理项目的依赖，在项目移植的时候可以很方便的建立起一致的工作环境。但 python 并没有自带类似的包管理系统。之前对待 python 项目都是采用暴力方法，运行的时候看到哪个包报错就安装哪个包，由于也不是经常把项目移来移去，倒也没有太大影响。但不管怎么说，这种方法毕竟不够规范和优雅，也无法保证工作环境的一致性。
<!-- more -->
pipenv 就是一个和 npm 类似的包管理机制。简单的讲它有两方面的功能：一是虚拟环境的创建和管理，类似于 virtralenv；二是一个包管理系统，类似于 npm。你可以利用它为每个项目创建不同的虚拟环境，在每个虚拟环境中，你可以使用不同版本的 python 解释器和安装不同的依赖，而不会互相影响。它可以生成 pipfile 和 pipfile.lock 文件，用 npm 类似的方式进行包的管理，保证项目移植过程中环境和依赖的一致性。

pipenv 是 Pipfile 主要倡导者、requests 作者 Kenneth Reitz 写的一个命令行工具。Pipfile是社区拟定的依赖管理文件，用于替代过于简陋的 requirements.txt 文件。Pipfile 和 pipenv 本来都是Kenneth Reitz的个人项目，后来贡献给了 pypi 组织。

## Pipenv 的特点
* 真正实现确定性的构建, 只需设定你想要设定的内容。
* 对锁定（lock）的依赖计算哈希值，或进行哈希校验。
* 自动安装所需的 python 版本（需要先安装 pyenv）。
* 通过 Pipfile 自动找到你的项目路径。
* 如果不存在的话，自动生成 Pipfile。
* 自动在默认路径下生成虚拟环境。
* 在安装和卸载依赖时，自动更新 Pipfile 。
* 如果存在 .env 文件会自动加载。

## 安装
``` bash
pip install pipenv
```

## 虚拟环境的创建和使用

Pipenv 会在你第一次使用 `install` / `uninstall` / `lock` 命令的时候自动生成虚拟环境，使用系统默认的 python 解释器。你也可以用一些命令手动的生成虚拟环境，来对一些选项进行控制。

``` bash
cd your-project-folder

pipenv --three / --two   # 使用当前系统的 python 3/2 创建虚拟环境
pipenv --python 3.6      # 使用具体的版本号
pipenv --python 3.6.4    # 版本号可以指定更小的版本
```

pipenv 会使用你指定的 python 版本创建一个虚拟环境。同时，它会创建/更新项目文件夹中的 pipfile 文件，如下所示：

``` toml
[source]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true

[dev-packages]

[packages]

[requires]
python_version = "3.6"
```

在文件中你可以修改源的信息，如果是国内的无梯用户，建议修改为清华的镜像源，否则包的安装速度将非常感人。

``` toml
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
```

使用 run 可以在虚拟环境中执行命令，接收的参数会直接传递给所执行的命令:

``` bash
# 在虚拟环境中启动 main.py
pipenv run python main.py
```

你也可以在项目文件夹内使用如下命令会进入虚拟环境的 shell，此时终端左边的提示文字会变成 `(package-name) $ bash-3.2` 的形式，此时所有命令都是执行在虚拟环境中的:

``` bash
pipenv shell

# 使用 exit 可以退出虚拟环境的 shell
exit
```

一些常用的命令：

``` bash
pipenv --where            # 当前路径
pipenv --venv             # 当前所使用的虚拟环境的路径
pipenv --py               # 当前所使用的 python 解释器的信息
pipenv --rm               # 移除当前路径下的虚拟环境
```

## 包管理

使用 pipenv 可以用类似 npm 的方式对 python 包进行管理，基本的命令格式和使用 pip 是类似的。其中 pipenv install 命令与 pip install 命令完全兼容。核心的命令是 `install` / `uninstall` / `lock` 。

### 安装相关

从 pipfile 安装（如果存在）：

``` bash
pipenv install
```

安装指定的包，并添加到 pipfile:

``` bash
pipenv install <package>
```

安装选项：
* `--two` 在使用系统默认 python2 的虚拟环境中安装
* `--three` 在使用系统默认 python3 的虚拟环境中安装
* `--python` 在使用默认 python 的虚拟环境中安装

> 注意，以上三个命令会重新构建项目的虚拟环境。

* `--dev` 从 Pipfile 同时安装 develop 和 default 包。（安装指定包时，会添加为 develop 包）
* `--system` 使用系统的 pip 命令代替虚拟环境中的命令。
* `--ignore-pipfile` 忽略 Pipfile ，只从 Pipfile.lock 中安装。
* `--skip-lock` 忽略 Pipfile.lock 并从 Pipfile 中安装。同时，不会更新 Pipfile.lock 来反映 Pipfile 的变化。

你也可以从 git 地址来安装包，采用如下的格式。其中只有 `@<branch_or_tag>` 是可选的。

``` bash
<vcs_type>+<scheme>://<location>/<user_or_organization>/<repository>@<branch_or_tag>#egg=<package_name>
```

对于这类具有版本控制的包，强烈建议加上 -e 选项（editable），这样在每次执该命令时，都能将这个包同步为最新的副本。

``` bash
pipenv install -e git+https://github.com/requests/requests.git@v2.19#egg=requests
```

指定包的版本：

与 `npm` 类似，`pipenv` 采用语义化版本进行指定。

``` bash
pipenv install "requests~=2.2"   # 锁定主要版本 (相当于 ==2.*)
pipenv install "requests>=1.4"   # 安装不低于 1.4.0 的版本
pipenv install "requests<=2.13"  # 安装不高于 2.13.0 的版本
pipenv install "requests>2.19"   # 会安装 2.19.1 但不包括 2.19.0
```

### 卸载相关

卸载所有不包含在 pipfile 中的包：

``` bash
pipenv clean
```

卸载特定的包，并从 pipfile 中移除：

``` bash
pipenv uninstall <package>
```

卸载所有 dependencies (default packages)。这个操作不会修改 pipfile 和 pipfile.lock。

```
pipenv uninstall --all
```

卸载所有 dev-dependencies (develop packages)。这个操作会从 pipfile 和 pipfile.lock 中删除 dev-dependencies (develop packages)。

```
pipenv uninstall --all-dev
```

### 其它

更新 lock 文件。在每次安装时，默认更新 lock 文件，在这种情况下不需要手动 lock。在 lock 时，需要计算 hash 值，因此需要耗费一些时间。

```
pipenv lock
```

显示项目的依赖关系

```
pipenv graph
```

检查需要更新的包：

```
pipenv update --outdated
```

更新所有包或特定包：

```
pipenv update [<package>]
```

## 高级用法

### 在项目路径下存放虚拟环境

在项目路径下存放虚拟环境最简单的办法就是在项目下建立 .venv 文件夹。如果项目的根目录存在 .venv 文件夹，它会优先于你所指定的路径。

你还可以通过设置 `PIPENV_VENV_IN_PROJECT` 环境变量为真值来实现同样的目的。

### 更改虚拟环境的存放位置

通过设置 `WORKON_HOME` 可以指定虚拟环境存放的路径：

```
export WORKON_HOME=~/.venvs
```

### 加载.env文件

pipenv 在运行时会自动加载 .env 文件。.env 文件可以设置一些环境变量，这些变量会在 pipenv 启动时加载进去。

```
# file ./.env
ENV1 = "HELLO WORLD"
```
``` python
>>> import os
>>> os.environ['ENV1']
'HELLO WORLD'
```

### 在 phpfile 中引入环境变量

在Pipfile中也可以引用环境变量的值，格式为 `${MY_ENVAR}` 或`$MY_ENVAR`。

``` toml
[source]
url = "https://${PYPI_USERNAME}:${PYPI_PASSWORD}@my_private_repo.example.com/simple"
verify_ssl = true
name = "pypi"

[dev-packages]

[packages]

[requires]
python_version = "3.6"
```

### 自定义命令

和 npm 类似，你可以在 pipfile 中自定义命令，然后用 `pipenv run <shortcut name>` 来执行它。

例如，在 Pipfile 中：

```
[scripts]
printspam = "python -c \"print('I am a silly example, no one would need to do this')\""
```

在终端内执行：

```
$ pipenv run printspam
I am a silly example, no one would need to do this
```

带参数的命令也是可行的：

``` toml
[scripts]
echospam = "echo I am really a very silly example"
```
```
$ pipenv run echospam "indeed"
I am really a very silly example indeed
```
