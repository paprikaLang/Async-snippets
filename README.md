## Functional Programming

Demo暂四个分支,三个iOS端demo:

- master:最基本的编程方式
- basic1:集中UI数据,统一处理,易于测试
- reduce:在basic1基础上,实现单向数据流,完整状态变更覆盖测试

![](https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg)

简单的函数就是给定一个变量和改变变量的参数,得出一个新的变量 例如: y = x + a;

对于函数式编程,就是接收一个已有状态state和改变状态的用户行为Action,得出一个新的state的过程.

对于上面的单向数据流程图,stateDidChanged是一个典型的纯函数式的UI更新方法,reducer同样是,它们非常易于测试,不用关心controller,只需要知道前后两个state就可维护controller了.

- vuex:Vuex 是一个专为 Vue.js 应用程序开发的状态管理模式。它采用集中式存储管理应用的所有组件的状态，并以相应的规则保证状态以一种可预测的方式发生变化.


![](https://ws3.sinaimg.cn/large/006tNc79gy1fk42jdhi50j316e0w6whi.jpg)

[OC相关单向数据流Demo可参见:Zepo/Reflow](https://github.com/Zepo/Reflow)


