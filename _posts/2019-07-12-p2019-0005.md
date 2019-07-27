---
layout: post
title: Python 多进程在 windows 和 unix 之间的差异
date: 2019-07-12
Author: MinimaLife
tags: [tech, coding, python]
comments: true
toc: false
pinned: false
---
我们都知道，在 unix 系统（Linux, Mac OS）中，multiprocessing 模块使用 os.fork 来创建多进程。这个命令会把当前的整个内存空间复制一份，相当于在同一个时间节点分叉成了两个时间线，它们的初始状态是完全相同的，即拥有相同的历史。因此，我们可以在主进程和子进程内访问到相同的变量。

但 Windows 系统却不一样，由于缺少了 os.fork 方法，因此实现方式与 unix 系统有所差异，因此可能与你的预期不相符合。
<!-- more -->
## 保证主模块能被安全引入

举一个简单的例子：

``` python
# main.py
import multiprocessing
import os

def say_hello():
    pid = os.getpid()
    print('Process %d say: hello' % pid)

say_hello()

p = multiprocessing.Process(target=say_hello)
p.start()
```

上述代码并不复杂：让主进程和子进程分别打印一段话，其中包含了当前进程的id号。

在 Mac 上，运行结果是这样的：

```
Process 2446 say: hello
Process 2447 say: hello
```

符合我们的预期：继承了主进程的历史，并继续往下执行。

但在 windows 上，这段代码却会报错：

(😂我现在要先去打开 PC，写个文章真不容易）

在 Windows 上，甚至不能正常运行：

```
Process 8196 say: hello
Process 10056 say: hello
Traceback (most recent call last):
  ......
RuntimeError:
  ......
```

报错信息太多，没有必要全部贴出来。这是为什么呢？

事实上，python 的 Process 对象在执行 start 方法的时候，有三种方式，分别是 spawn, fork, forkserver。其中 unix 系统默认采用的是 fork 方式。而 windows 默认采用 spawn 方式，且缺少后面两种方法。

spawn 方法会开启一个全新的解释器进程，子进程只会从主进程继承那些对运行 process 的 run() 方法有必要的资源。

在 spawn 方法运行时，需要把主模块 `__main__` 作为模块 import 进去，这样主模块中的顶层代码都会执行一遍，因此你会看到，子进程执行了代码第 9 行的函数后，在 12 行报错了，因为它造成了子进程的递归生成。

因此我们必须保证主模块能够被安全引入。修改一下代码：
``` python
# main.py
import multiprocessing
import os

def say_hello():
    pid = os.getpid()
    print('Process %d say: hello' % pid)

if __name__ == '__main__':
    say_hello()
    p = multiprocessing.Process(target=say_hello)
    p.start()
```

这样程序的结果就和我们预期的一致了：

```
Process 468 say: hello
Process 6428 say: hello
```

所以一个比较好的实践就是，不要把发起子进程的代码放到模块的顶层空间内，而是放到函数中，这样只要子进程不调用函数，就不会引起循环发起子进程导致的错误。

虽然 unix 系统不会发生类似的问题，但是为了保证代码的可移植性，遵循这样的原则也是有必要的。

## 使用 multiprocessing 时的指导原则

官方文档给出了使用 multiprocessing 时的指导原则，在这里简单列举一下，详细内容可以参考官方文档(version=3.7.3)。
 * **避免共享状态**
 尽可能避免在进程之间共享大量的数据。
 最好保证使用 queues 和 pipes 来进行进程间通讯，而不是使用更底层的同步方式。
* **Picklability**
保证你传递给 proxy 的方法的参数都是 picklable 的。
* **proxy 对象的线程安全**
 不要在多个线程里使用 proxy 对象，除非你用锁做了保护。
 （但是多个不同进程使用同一个 proxy 永远不会出现问题。）
* **避免使用 Process.terminate 终止进程**
 使用 Process.terminate 方法终止进程会导致共享的资源 (例如 locks, semaphores, pipes 和 queues) 损坏或无法被其它进程使用。因此，只在没有共享资源的地方使用。
* **显式地向子进程传递资源**
 由于在 windows 中，变量的状态并不总是和父进程一致，因此避免让函数使用外层空间的资源，而是将它显式的传递给子程序。为了保证和 windows 的兼容性，其它平台最好也这样做。
