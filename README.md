## Functional Programming

Demo共三个分支:

- master:最基本的编程方式
- basic1:集中UI数据,统一处理,易于测试
- reduce:在basic1基础上,实现单向数据流,完整状态变更覆盖测试

![](https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg)

简单的函数就是给定一个变量和改变变量的参数,得出一个新的变量 例如: y = x + a;

对于函数式编程,就是接收一个已有状态state和改变状态的用户行为Action,得出一个新的state的过程.

对于上面的单向数据流程图,stateDidChanged是一个典型的纯函数式的UI更新方法,reducer同样是,它们非常易于测试,不用关心controller,只需要知道前后两个state就可维护controller了.

函数式编程保证了数据单向流动和完整的状态变更覆盖测试,对于学习RxSwift和前端React等都是很有帮助的


