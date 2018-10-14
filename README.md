#### **从Python的装饰器原理看函数式编程**

```pyt
import time
def decorator(func):
    def punch():
        print(time.strftime('%Y-%m-%d', time.localtime(time.time())))
        func()
    return punch

def origin():
    print('昵称：tiyo  部门：IT 打卡成功')

f = decorator(origin)
f()
```
装饰器的原理:

1.接收一个函数(func)作为参数

2.嵌套一个包装函数(punch), 包装函数接收原函数的参数，执行原函数的同时还会插入附加功能(打点)

3.返回嵌套函数(punch)


iOS 的 TCZKit 用闭包也实现了上面这三个步骤:

```Swift
public typealias CancelableTask = (_ cancel: Bool) -> Void
public func delay(time: TimeInterval, work: @escaping ()->()) -> CancelableTask? {
  var finalTask: CancelableTask?
  let cancelableTask: CancelableTask = { cancel in
    if cancel {
      finalTask = nil  
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
  finalTask = cancelableTask
  DispatchQueue.main.asyncAfter(deadline: .now() + time) {
    if let task = finalTask {
      task(false)
    }
  }
  return finalTask
}
```

<br>

#### **从异步回调地狱看 Monad**

要理解 Monad 先要理解容器.

```Swift
var arr :[Int]?  //有无Optional结果大不同 
arr = [1,2,3]
print(arr.map ({"No.\($0)"})) //map 和 flatMap 结果也不同
```

1. 在 Swift 中, Array, Struct, Enum(Optional) ... 这些都是容器( [Int]? 相当于把数字包裹在了两层容器里). 

2. 容器之间的映射靠 map 和 flatMap 完成. 

将 **异步回调** 放入合理的容器(如:Promise)中并实现 flapMap 的链式调用, 这样就可以避免异步回调地狱了. 
[[Escaping Hell with Monads]](https://philipnilsson.github.io/Badness10k/escaping-hell-with-monads/).

<img src="https://paprika-dev.b0.upaiyun.com/jzvVyWwYhcIOEW1np7UpXIUduud74yiZ6GQnytag.jpeg" width="500"/>

实际上 flatMap 就是 Monad, Promise 的 then 也是 Monad .
<img src="https://paprika-dev.b0.upaiyun.com/dZYxureNahEv33uuOArlf4mv3OGBR6DeVn2ccjin.jpeg" width="500"/>

<br>

#### **从 Rx 的 IObservable, IEnumerable 看 Publish–Subscribe Pattern**

[[Pulling vs. Pushing Data]](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

>The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to RACSignal in RAC.
>The IObservable will notify all the observers automatically of any state changes. 

>The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to RACSequence in RAC. 
>The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.

参照前面完成的 Async (封装异步的容器), 揉进 Publish–Subscribe Pattern 实现 Observable:

<img src="https://paprika-dev.b0.upaiyun.com/EkhrOfb6j55xxb7ho5GuFuSp6IB90SUsHLCVdMkV.jpeg" width="500"/>

[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

文章中说到 **函数** 可以替代 异步回调 被 JavaScript 应用在 subscribe 中.

<img src="https://paprika-dev.b0.upaiyun.com/p2rfJbZHHjHNjAmvkIsfqJKnEKkljjyfGoAySLF6.jpeg" width="500"/>

<img src="https://paprika-dev.b0.upaiyun.com/yNVQO0p9bN0XCygOUr3zxDXVRoV0GBjIAX1XEbc7.jpeg" width="500"/>

不过随着[[上面项目]](https://github.com/hzub/pubsub-demo/)的进展, 组件层级会越来越复杂, 组件间传值变得更加混乱, subscribe 散布在各个角落.

<img src="https://paprika-dev.b0.upaiyun.com/vmw1ArDZaNzX8IihBhPNJFmx5gzZLHlgcaYpa2Mc.jpeg" width="500"/>

<img src="https://paprika-dev.b0.upaiyun.com/JCDD5U3WCuTk0KqQ4wfxwasupRQ1VILd3TOPR8ta.jpeg" width="500"/>

Redux 的 dispatch(action) 会把所有 subscribe 中的函数集中到 reducer.js , 函数(如: renderMarkers)用到的所有参数由 state 统一管理,
返回的 newState 触发 subscribe(handleStoreChange), 组件更新.

<img src="https://paprika-dev.b0.upaiyun.com/ouzwtruWwEUwId2SJeSXMjsyAXvJd8eLQPob7mDo.jpeg" width="500"/>


喵神的[[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) :

```Swift
struct State:StateType {
  var dataSource = TableViewDataSource(todos: [], owner: nil)
  var text : String = " "
}
```
<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="500"/>

测试

```Swift
let (nextState,command) = reducer(state, action)
```

```Swift
let initState = TableViewController.State()
let state = controller.reducer(initState, .updateText(text: "123")).state
XCTAssertEqual(state.text, "123")
```

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

[OC相关单向数据流Demo可参见:Zepo/Reflow](https://github.com/Zepo/Reflow)

