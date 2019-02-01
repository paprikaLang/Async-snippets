### **从 装饰器 看 闭包**

```python
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
Python 的装饰器原理:

1.接收一个函数(func)作为参数

2.嵌套一个包装函数(punch), 包装函数接收原函数的参数，执行原函数的同时还会插入附加功能(打点)

3.返回嵌套函数(punch)

<br>

iOS 的 TCZKit 用**闭包**也实现了上面这三个步骤:

```swift
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

### **从 Monad 看 Promise**

要理解 Monad 先要理解容器.

```swift
var arr :[Int]?  //有无Optional结果大不同 
arr = [1,2,3]
print(arr.map ({"No.\($0)"})) //map 和 flatMap 结果也不同
```

1 在 Swift 中, Array, Struct, Enum(Optional) ... 这些都是容器. [Int]? 相当于把数字包裹在了两层容器里.

2 容器之间的映射关系通过 map flatMap 等函数建立. 这些函数无副作用, 在测试 、重构等方面具有优势. 

3 将 **闭包** 放入合理的容器(如: Promise)中并实现 flapMap 的链式调用, 这样就可以避免异步回调地狱了.

[[Escaping Hell with Monads]](https://philipnilsson.github.io/Badness10k/escaping-hell-with-monads/).

<img src="https://paprika-dev.b0.upaiyun.com/jzvVyWwYhcIOEW1np7UpXIUduud74yiZ6GQnytag.jpeg" width="500"/>

实际上 flatMap 就是 Monad , Promise 的 [[then]](https://github.com/ElemeFE/node-practice) 也是 Monad .

```javascript
function Promisee(fn){
   ... ...
  function fulfill(result) {
    state = FULFILLED;
    value = result;
    handler.forEach(next);
    handler = null;
  }
  function reject(err) { ... ... }

  function resolve(result) {
    try {
      let then = typeof result.then == 'function' ? result.then : null;
      if (then) {
        then.bind(result)(resolve, reject);
        return;
      }
      fulfill(result);
    } catch(err) {
      reject(err);
    }
  }

  function next({onFulfill, onReject}) {
    switch(state) {
      case FULFILLED:
        onFulfill && onFulfill(value);
        break;
      case REJECTED:
        onReject && onReject(value);
        break;
      case PENDING:
        handler.push({onFulfill, onReject});
    }
  }

  this.then = function (onFulfill, onReject) {
    return new Promisee((resolve, reject) => {
      next({
        onFulfill: (val) => {
          try {
            resolve(onFulfill(val));
          } catch (err) { ... }
        }, 
        onReject: (err) => {
          reject(onReject(val));
        }
      });
    });
  }  
  fn(resolve, reject);
}
```
<br>

### **从 Pub–Sub 看 Observable**

[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

> No matter what method of solving asynchronous problem will you use, it will be always some variation of the same principle: something subscribes, something publishes.

[]()
> You already know this mechanism: remember setTimeout, setInterval and various event listener callbacks? They work by consuming functions as a parameters.
This characteristic is fundamental in asynchronous scenarios.

[[文中的例子]](https://github.com/hzub/pubsub-demo/)介绍了在项目业务逻辑分类重组之后, 如何通过 pub-sub 共享数据.

<img src="https://paprika-dev.b0.upaiyun.com/yNVQO0p9bN0XCygOUr3zxDXVRoV0GBjIAX1XEbc7.jpeg" width="500"/>

函数可以搭配 pub-sub , 闭包当然也可以. 而封装闭包的容器与 pub-sub 结合就构成了传说中的 Observable .

<img src="https://paprika-dev.b0.upaiyun.com/EkhrOfb6j55xxb7ho5GuFuSp6IB90SUsHLCVdMkV.jpeg" width="500"/>

*对比前面实现的 Async 封装容器*:

<img src="https://paprika-dev.b0.upaiyun.com/jzvVyWwYhcIOEW1np7UpXIUduud74yiZ6GQnytag.jpeg" width="500"/>


在 Flutter 的范畴里, 上面实现的只是 stream , Reactive Extensions Dart 扩展了 stream 的功能并实现了 observable . 

[[What is Reactive Extensions]](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

>The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to RACSequence in RAC. 
>The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.

[]()
>The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to RACSignal in RAC.
>The IObservable will notify all the observers automatically of any state changes. 

<br>

### **从 Bloc 看 redux 单向数据流**

> Observable will notify all the observers automatically of any state changes. 

在 Flutter StatefulWidget 中任何 state changes 都会通过 setState 重新 build 整个部件和它的子部件, 而 StreamBuilder 可以监听某个 stream , 当 sink 传入数据时只需更新当前 StreamBuilder 即可. 
```dart
Widget build(BuildContext context) {
  CounterBloc _bloc = CounterProvider.of(context).bloc;
  return Center(
      child: StreamBuilder(
    initialData: 0,
    stream: _bloc.revCount, 
    builder: (context, snapshot) {
      return ActionChip(
        label: Text('${snapshot.data}'),
        onPressed: () {
          _bloc.counter.add(1);
        },
      );
    },
  ));
}

class CounterBloc {
  int _count = 0;
  final _dataController = StreamController<int>();
  final _controller = StreamController<int>();
  StreamSink<int> get counter => _controller.sink;
  Stream<int> get revCount => _dataController.stream;
  CounterBloc() {
    _controller.stream.listen(onData);
  }
  void onData(data) {
    print(data);
    _count = _count + data;
    _dataController.add(_count);
  }
}
```

同时, Bloc 还可以将 UI 和 业务逻辑 分离, 业务逻辑测试只需要关注 Bloc. 类似 RxSwift 和 MVVM 的结合.
```swift
var registerViewModel = RegisterViewModel()
var disposeBag = DisposeBag()
func testInputNumber() {
  // TestScheduler 相当于一个 Flutter 的 StreamController
  // 它会模拟响应式环境中，用户在某一时刻进行某个交互（输入）的情况, initialClock 虚拟时间
  let scheduler = TestScheduler(initialClock: 0) 

  // 相当于 Stream<bool> get canSendObserver => controller.stream;
  let canSendObserver = scheduler.createObserver(Bool.self)

  // 从 scheduler 创建热信号，通过 next 方法模拟输入手机号。相当于 sink.add 方法.
  let inputPhoneNumberObservable = scheduler.createHotObservable([next(100, ("1862222")),
                                                                  next(200, ("18622222222"))])
  // 相当于 stream.listen
  self.registerViewModel.canSendCode
      .subscribe(canSendObserver)
      .addDisposableTo(self.disposeBag)

  // 相当于在部件中 设置 stream . 这样信号发出来后，ViewModel 才会有反应
  inputPhoneNumberObservable
      .bind(to: self.registerViewModel.phoneNumber)
      .addDisposableTo(self.disposeBag)

  scheduler.start()

  // 这是期望的测试结果如: 在 0 这个时间点，由于没有输入，canSendCode 是 false
  let expectedCanSendEvents = [
      next(0, false),
      next(100, false),
      next(200, true)]

  // Assert Equal 一下 Observer 真实的 events（结果）和期望的结果，一样就测试通过
  XCTAssertEqual(canSendObserver.events, expectedCanSendEvents)
```

关于 Flutter 状态管理模式还有一种 flutter_redux 提供的单向数据流架构. 单向在于所有的 states 都储存在 store 中, view 同样不会直接修改数据, 它需要发起一个 action 给 reducer, 通过遍历 action 表进行匹配, 并生成对应的新 state . store 更新 state 最后通知订阅了的 views 重新渲染.

<img src="https://paprika-dev.b0.upaiyun.com/JCDD5U3WCuTk0KqQ4wfxwasupRQ1VILd3TOPR8ta.jpeg" width="500"/>

喵神以 redux 为灵感, 用 Swift 创建了一个[[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) :

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>


```swift
struct State:StateType {
  var dataSource = TableViewDataSource(todos: [], owner: nil)
  var text : String = " "
}
```
<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="500"/>

*对比 redux* :

<img src="https://paprika-dev.b0.upaiyun.com/ouzwtruWwEUwId2SJeSXMjsyAXvJd8eLQPob7mDo.jpeg" width="500"/>

*对比前面 MVVM 的测试*:

```swift
let (nextState,command) = reducer(state, action)
```

```swift
let initState = TableViewController.State()
let state = controller.reducer(initState, .updateText(text: "123")).state
XCTAssertEqual(state.text, "123")
```