---
layout: post
title: Node.js 子进程 buffer 超限导致的异常
date: 2019-07-14
Author: MinimaLife
tags: [tech, coding, node.js, javascript]
comments: true
toc: false
pinned: false
---
> 转载于 [使用node子进程spawn,exec踩过的坑](https://segmentfault.com/a/1190000004160026)，版权归原作者所有。

**编者按**：我有个项目，大概的架构是用 node.js （Electron）拉了个子程序 （python 打包的），但是持续运行一段时间后，子程序就会挂掉。而且每次都是在 print 的时候报错。后来根据这个现象怀疑是 stdio Buffer 的问题，果然在 node.js 文档中提到了 maxBuffer。<!-- more -->最后诊断原因是，在 Electron 应用打包后，子程序输出的 stdio 没有消耗。持续运行一段时间后，超过了 maxBuffer，导致子程序被杀死。（在调试环境中是不会出现这个问题的，因为调试环境的 stdio 被打印到了 Electrion main process 的调试窗口里。）

解决办法是，检测是否处于打包的环境（参考你打包工具，如 pyInstaller 的文档），如果处于打包环境，则将标准输出重定向到 devnull：

``` python
if getattr(sys, 'frozen', False):
    # running in a bundle (mean frozen)
    f_nul = open(os.devnull, 'w')
    sys.stdout = f_nul
    sys.stderr = f_nul
```

你也可以在 node.js 端及时的处理子程序产生的 stdio buffer，例如做一个调试界面，来显示这些 stdio data。

后来发现有网友遇到了类似的问题，而且写的十分详细，因此转载过来，留作记录。

以下内容为作者原文。

---

《如何在项目中实现热更新》中提到的一个坑child_process的exec使用问题，下面文章会详细介绍下，debug到node源码中的详细介绍，不容错过。

## child_process介绍

Nodejs是单线程单进程的，但是有了child_process模块，可以在程序中直接创建子进程，并使用主进程和子进程之间实现通信。

对于child_process的使用，大家可以找找其他文章，介绍还是比较多的，本文主要讲一下踩过的坑。

## 踩过的坑

在使用[EHU(esl-hot-update)](https://github.com/homkai/ehu)这个工具时（对于工具的介绍，参考前面的文章如何在项目中实现热更新），发现用子进程启动项目，经常性的挂掉。然后也不知道为什么，甚至怀疑子进程的效率比较低。

最后为了进一步验证，在同样的环境下，一个直接启动服务，一个是使用 `require('child_process').exec('...')` 方式启动。

最后发现使用子进程打开还真的就是使用到一定程度就挂掉。虽然此时也没有什么解决方案，但是至少能把问题定位在子进程上了，而不是其他工具代码导致程序挂掉。

## 定位问题

定位了问题后，网上查找child_process相关资料，发现 [exec与spawn方法的区别与陷阱](http://deadhorse.me/nodejs/2011/12/18/nodejs%E4%B8%ADchild_process%E6%A8%A1%E5%9D%97%E7%9A%84exec%E6%96%B9%E6%B3%95%E5%92%8Cspawn%E6%96%B9%E6%B3%95.html) 这篇文章提到几点：
1. exec与spawn是有区别的
2. exec是对spawn的一个封装
3. 最重要的exec比spawn多了一些默认的option

基于以上几点有些头绪了，但是还是没有明确的解决方案。

最后一个办法，直接断点到nodejs的child_process.js模块中尝试看看问题出在哪里。

## exec和spawn的源码区分

断点进去看后，豁然开朗，`exec` 是对 `execFile` 的封装，`execFile` 又是对 `spawn` 的封装。

每一层封装都是加强一些易用性以及功能。

直接看源码：

``` js
exports.exec = 
    function(command /*, options, callback*/) {
          var opts = normalizeExecArgs.apply(null, arguments);
          return exports.execFile(opts.file,
                                  opts.args,
                                  opts.options,
                                  opts.callback);
};
```

`exec` 对于 `execFile` 的封装是进行参数处理

处理的函数：

`normalizeExecArgs`

关键逻辑

``` js
if (process.platform === 'win32') {
    file = process.env.comspec || 'cmd.exe';
    args = ['/s', '/c', '"' + command + '"'];
    // Make a shallow copy before patching so we don't clobber the user's
    // options object.
    options = util._extend({}, options);
    options.windowsVerbatimArguments = true;
  } else {
    file = '/bin/sh';
    args = ['-c', command];
  }
```

将简单的 command 命名做一个，win 和 linux 的平台处理。

此时 `execFile` 接受到的就是一个区分平台的 `command` 参数。

然后重点来了，继续 debug，`execFile` 中：

``` js
var options = {
    encoding: 'utf8',
    timeout: 0,
    maxBuffer: 200 * 1024,
    killSignal: 'SIGTERM',
    cwd: null,
    env: null
};
```

有这么一段，设置了默认的参数。然后后面又是一些参数处理，最后调用 `spawn` 方法启动子进程。

上面的简单流程就是启动一个子进程。到这里都没有什么问题。

继续看，重点又来了：

用过子进程应该知道这个 ``child.stderr`

下面的代码就解答了为什么子进程会挂掉。

``` js
child.stderr.addListener('data', function(chunk) {
    stderrLen += chunk.length;

    if (stderrLen > options.maxBuffer) {
      ex = new Error('stderr maxBuffer exceeded.');
      kill();
    } else {
      if (!encoding)
        _stderr.push(chunk);
      else
        _stderr += chunk;
    }
});
```

逻辑就是，记录子进程的log大小，一旦超过 `maxBuffer` 就 `kill` 掉子进程。

原来真相在这里。我们在使用 `exec` 时，不知道设置 `maxBuffer`，默认的 `maxBuffer` 是200K,当我们子进程日志达到200K时，自动 `kill()` 掉了。

## exec和spawn的使用区分

不过exec确实比spawn在使用上面要好很多

例如我们执行一个命令

使用exec

``` js
require('child_process').exec('edp webserver start');
```

使用spawn

linux下这么搞

``` js 
var child = require('child_process').spawn(
   '/bin/sh', 
   ['-c','edp webserver start'],
   {
       cwd: null,
       env: null,
       windowsVerbatimArguments: false
   }
);
```

win下

``` js
var child = require('child_process').spawn(
   'cmd.exe',
   ['/s', '/c', 'edp webserver start'],
   {
       cwd: null,
       env: null,
       windowsVerbatimArguments: true
   }
);
```

可见spawn还是比较麻烦的。

## 解决方案

知道上面原因了，解决方案就有几个了:
1. 子进程的系统，不再输出日志
2. maxBuffer这个传一个足够大的参数
3. 直接使用spawn，放弃使用exec

我觉得最优的方案是直接使用 `spawn`，解除 `maxBuffer` 的限制。但是实际处理中，发现直接考出 `normalizeExecArgs` 这个方法去处理平台问题，在 win 下还是有些不好用，mac 下没有问题。所以暂时将 `maxBuffer` 设置了一个极大值，保证大家的正常使用。然后后续在优化成 `spawn` 方法。

## 吐槽

其实没有怎么理解，execFile对于spawn封装加maxBuffer的这个逻辑，而且感觉就算加了，是否也可以给一个方式，去掉maxBuffer的限制。

难道是子进程的log量会影响性能？

## 感想

其实在解决这个问题时，发现这个差异/坑还比较意外，因为自身对于node其实还不是很熟，这个子进程的使用其实也是在ehu中第一次遇到。

感受比较多的就是有时候正对问题去学习/研究，其实效率特别高。
