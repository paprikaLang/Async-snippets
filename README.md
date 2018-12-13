#### **从 Python 的装饰器原理看闭包**

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


iOS 的 TCZKit 用**闭包**也实现了上面这三个步骤:

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

#### **从 异步回调 看 Monad**

要理解 Monad 先要理解容器.

```Swift
var arr :[Int]?  //有无Optional结果大不同 
arr = [1,2,3]
print(arr.map ({"No.\($0)"})) //map 和 flatMap 结果也不同
```

1 在 Swift 中, Array, Struct, Enum(Optional) ... 这些都是容器( [Int]? 相当于把数字包裹在了两层容器里). 

2 容器之间的映射有 map 和 flatMap . 

将 **闭包** 放入合理的容器(如:Promise)中并实现 flapMap 的链式调用, 这样就可以避免回调地狱了. 

[[Escaping Hell with Monads]](https://philipnilsson.github.io/Badness10k/escaping-hell-with-monads/).

<img src="https://paprika-dev.b0.upaiyun.com/jzvVyWwYhcIOEW1np7UpXIUduud74yiZ6GQnytag.jpeg" width="500"/>

实际上 flatMap 就是 Monad , Promise 的 then 也是 Monad .

<img src="https://paprika-dev.b0.upaiyun.com/dZYxureNahEv33uuOArlf4mv3OGBR6DeVn2ccjin.jpeg" width="500"/>

<br>

#### **从 Rx 的 IObservable, IEnumerable 看 Publish–Subscribe Pattern**

[[Pulling vs. Pushing Data]](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

>The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to RACSignal in RAC.
>The IObservable will notify all the observers automatically of any state changes. 

>The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to RACSequence in RAC. 
>The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.

在前面完成的 Async (封装异步的容器) 之中融入 Publish–Subscribe Pattern 实现简单的 Observable:

<img src="https://paprika-dev.b0.upaiyun.com/EkhrOfb6j55xxb7ho5GuFuSp6IB90SUsHLCVdMkV.jpeg" width="500"/>


[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

> No matter what method of solving asynchronous problem will you use, it will be always some variation of the same principle: something subscribes, something publishes.

> You already know this mechanism: remember setTimeout, setInterval and various event listener callbacks? They work by consuming functions as a parameters.
This characteristic is fundamental in asynchronous scenarios.

<img src="https://paprika-dev.b0.upaiyun.com/yNVQO0p9bN0XCygOUr3zxDXVRoV0GBjIAX1XEbc7.jpeg" width="500"/>

[[项目]](https://github.com/hzub/pubsub-demo/)初时 dataService.js 和 map.js 的代码是揉在一起的, publish(myPlaces) 的位置可以直接调用 renderMarkers . 可以说 publish-subscribe pattern 是 Single Responsibility Principle 的产物.

<img src="https://paprika-dev.b0.upaiyun.com/p2rfJbZHHjHNjAmvkIsfqJKnEKkljjyfGoAySLF6.jpeg" width="500"/>

<br>

#### **从闭包、纯函数、Pub–Sub、Redux 到单向数据流动的函数式 ViewController**


Redux 所有的数据保存在 State , dispatch(action) 将所有导致 State 改变的函数(如:addMarker)集中到 reducer.js , 

newState 会触发相应组件的 subscribe(handleStoreChange), UI 进而更新.

<img src="https://paprika-dev.b0.upaiyun.com/ouzwtruWwEUwId2SJeSXMjsyAXvJd8eLQPob7mDo.jpeg" width="500"/>

<img src="https://paprika-dev.b0.upaiyun.com/JCDD5U3WCuTk0KqQ4wfxwasupRQ1VILd3TOPR8ta.jpeg" width="500"/>


喵神的[[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) :

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

```Swift
struct State:StateType {
  var dataSource = TableViewDataSource(todos: [], owner: nil)
  var text : String = " "
}
```
<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="500"/>

前面提到的纯函数测试在这里的实现:

```Swift
let (nextState,command) = reducer(state, action)
```

```Swift
let initState = TableViewController.State()
let state = controller.reducer(initState, .updateText(text: "123")).state
XCTAssertEqual(state.text, "123")
```


