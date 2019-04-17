[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

熟悉 Vue 原理的话, 其实不难回答上面的问题.

```javascript
  function observe(obj) {
    
    Object.keys(obj).forEach(key => {
      var subscribes = new Set()
      let internalValue = obj[key]
      Object.defineProperty(obj, key, {
        get() {
          if (activeUpdate) {
            subscribes.add(activeUpdate);        //sub
          }
          return internalValue
        },
        set(newValue) {
          internalValue = newValue
          subscribes.forEach(sub => sub())       //pub
        }
      })
    })
  }

  let activeUpdate;

  function autorun(update) {
    function wrappedUpdate() {
      activeUpdate = wrappedUpdate
      update()
      activeUpdate = null
    }
    wrappedUpdate()
  }

  const state = {
    count: 0
  }
  observe(state)
  autorun(() => {
    console.log(state.count)
  })
  state.count++
```

我们也可以将异步请求函数中的 completion handler 封装在一个响应式的 Future 容器里.

```swift
  func load<A>(_ resource: Resource<A>, completion: @escaping (Result<A>) -> ()) {...}
```

```swift
  final class Future<T> {
    var callbacks: [(Result<T>)->()] = []
    var cached: Result<T>?
    init(compute: (@escaping (Result<T>) -> ()) -> ()) {
      compute(self.send)
    }

    private func send(_ value: Result<T>) {
      assert(cached == nil)
      cached = value
      for callback in callbacks {
        callback(value)
      }
      callbacks = []
    }

    func onResult(callback: @escaping (Result<T>) -> ()) {
      if let value = cached {
          callback(value) 
      } else {
          callbacks.append(callback)
      }
    }
    //flatMap for chaining operations
    func flatMap<U>(f: @escaping (T) -> Future<U>) -> Future<U> {
      return Future<U> { completion in
        self.onResult{ result in 
          switch result {
          case .success(let value):
            f(value).onResult(callback: completion)
          case .failure(let error):
            completion(.failure(error))
          }
        }
      }
    }
  }
```

```swift
//Promise.then 的实现                               //Future.flatMap 的实现
  this.then = function (onFulfill, onReject) {     func flatMap<U>(f: @escaping (T) -> Future<U>) -> Future<U> {
    return new Promisee((resolve, reject) => {       return Future<U> { completion in
      next({                                             
        onFulfill: (val) => {                           self.onResult{ result in
          try {                                            switch result {
            resolve(onFulfill(val));                       case .success(let value):  
          } catch (err) { ... }                              f(value).onResult(callback: completion)
        },                                                  
        onReject: (err) => {                               case .failure(let error):
          reject(onReject(val));                             completion(.failure(error))
        }                                                  }
      });                                               }
    });                                              }
  }                                                }
```

`f(value).onResult(callback: completion)` 你可以这样理解:

```javascript
// Future flatmap                                       //React
future = f(value)                                       this.setState({count: this.state.count + 1});
//cached尚未赋值,调用的是callbacks.append(completion)     //this.state 尚未更新, count:0                      
future.onResult(callback: completion)                   console.log('# this.state', this.state); 
   
```
**React** 引发的事件, setState 不会同步更新 state , 一方面是因为 setState 会累积 state 的变化, 通过减少组件重绘的次数来降低性能损耗; 另一方面, 如果同步更新 `this.state`, 再调用 setState 更新组件 UI , 则有悖于 Reactive Programming 的思想.

**Future** 的 f(value0) 也是一个异步的过程, send(value1) hook 了它的异步返回结果给 cached 赋值, 并通知到所有的 subscribers , 包括这个 completion .

**RxSwift** 扩展了 Future 的功能, 也能实现数据与UI的绑定, 就像 RxDart 之于 Stream 一样.

```swift
let viewModel =
    Observable.combineLatest(locationVM, weatherVM) {
            return ($0, $1)
        }
        .filter {
            let (location, weather) = $0
            return !(location.isEmpty) && !(weather.isEmpty)
        }
        .share(replay: 1, scope: .whileConnected)
        .observeOn(MainScheduler.instance)

viewModel.map { $0.0.city }
    .bind(to: self.locationLabel.rx.text)
    .disposed(by: bag)
```


 在 Flutter 的 StatefulWidget 中, 任何 state changes 都会通过 setState 重新 build 整个部件和它的子部件, 而 StreamBuilder 可以监听一个 stream , 当 sink 传入数据时只更新当前的 StreamBuilder. 

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

同时, Bloc 将 UI 和 业务逻辑 分离开来, 业务逻辑测试只需关注 Bloc. 

*对比 RxSwift 的测试*

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

 Flutter 的状态管理模式还包含一种 flutter_redux 提供的单向数据流架构. 它的单向在于所有 states 都储存在一个 store 中.

喵神以 redux 为灵感, 用 Swift 创建了一个[[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) :

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="600"/>

*欣赏一下它的测试*:

```swift
  //let (nextState,command) = reducer(state, action)

  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```

<br>

<hr>

最后的最后, 我们聊一聊 monad . 

Haskell 告诉你 monad 是这样的. 

```haskell
Prelude> :i Monad
class Applicative m => Monad (m :: * -> *) where
  (>>=) :: m a -> (a -> m b) -> m b
  (>>) :: m a -> m b -> m b

Prelude> :{
Prelude| half x = if even x
Prelude|    then Just (x `div` 2)
Prelude|    else Nothing
Prelude| :}
Prelude> Just 20 >>= half
Just 10
Prelude> Just 20 >>= half >>= half
Just 5
```

Future 的 flatMap 就是 monad.

其实 React Hooks 的 useState 也是一个 state monad .
```swift
struct State<S, T> {
    let on: (S) -> (T, S)
}
extension State {
    static func ret(_ data: T) -> State<S, T> {
        return State { s in (data, s) }
    }
    
    func bind<O>(_ function: @escaping (T) -> State<S, O>) -> State<S, O> {
        let funct = on
        return State<S, O> { s in
            let (oldData, oldState) = funct(s)
            return function(oldData).on(oldState)
        }
    }
}

precedencegroup MonadPrecedence {
    associativity: left
    higherThan: MultiplicationPrecedence
}
infix operator >>- : MonadPrecedence
func >>- <S, T, O>(lhs: State<S, T>, f: @escaping (T) -> State<S, O>) -> State<S, O> {
    return lhs.bind(f)
}

struct Person {
    let id: Int
    let name: String
}
let data = ["My", "Name", "Is", "paprika", "Lang"].enumerated().map(Person.init)

func fetchNameWith(id: Int) -> String? {
    return data.filter { $0.id == id }.first?.name
}
typealias MState = State<Int, [String]>
func fetch(names: [String]) -> MState {
    return MState { id in
        guard let name = fetchNameWith(id: id) else { return (names, id) }
        return (names + [name], id + 1)
    }
}

let fetchState = MState.ret(["Hello"]) >>- fetch >>- fetch >>- fetch >>- fetch
let state = fetchState.on(1)
let names = state.0               //["Hello", "Name", "Is", "paprika", "Lang"]
let nums = state.1                //5
let name = state.0[nums - 1]      //Lang
```

实现起来有些复杂了, 不过 React 的官方文档如是说: 

> Hooks provide access to imperative escape hatches and don’t require you to learn complex functional or reactive programming techniques.

你可以理解为: 

> 让 monad 飞一会儿, Hooks !