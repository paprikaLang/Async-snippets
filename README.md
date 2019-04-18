[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

如果你熟悉 Vue 或者 Observable 的原理, 其实不难回答上面的问题.

```javascript
  // Vue
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
      // activeUpdate 就像一个 carrier + transporter, 给属性注册订阅者之后再清空自己, 等待下一个订阅者.
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

<br>

```swift
  // Observable
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
    // chaining operations
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
封装在 Future 容器中的 completion handler 可以像 Promise 一样实现 chaining operations .
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

如何理解 `f(value).onResult(callback: completion)` ?

```javascript
// Future flatmap                                          //React setState
future = f(value)                                          this.setState({count: this.state.count + 1});
//此时cached尚未赋值,调用的是callbacks.append(completion)     //this.state 尚未更新, count:0                      
future.onResult(callback: completion)                      console.log('# this.state', this.state); 
```

**React** 引发的事件, setState 不会同步更新 state , 一方面是因为 setState 会累积 state 的变化, 通过减少组件重绘的次数来降低性能损耗; 另一方面, 如果同步更新 `this.state`, 再调用 setState 更新组件 UI , 则有悖于 Reactive Programming 的思想.

**Future** 的 f(value0) 也是一个异步的过程, send(value1) hook 了它的异步返回结果来给 cached 赋值, 并通知所有的 observers.

**RxSwift** 可以扩展这个 Future 的功能, 实现 数据与 UI 的绑定.

```swift
// RxSwift
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

<br>

> The push model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T>. The IObservable<T> interface is a dual of the familiar IEnumerable<T> interface. It abstracts a sequence of data, and keeps a list of IObserver<T> implementations that are interested in the data sequence. The IObservable will notify all the observers automatically of any state changes. 


在 Flutter 的 StatefulWidget 中, 任何 state changes 都会通过 setState 重新 build 整个部件和它的子部件; 这时需要创建 StreamBuilder 来监听一个 stream , 当 sink 再传入数据时就可以只更新当前 StreamBuilder 对应的部件了. 

```dart
final _bloc = CounterBloc();
body: Center(
  child: StreamBuilder(
    stream: _bloc.counter,
    initialData: 0,
    builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${snapshot.data}',
            style: Theme.of(context).textTheme.display1,
          ),
        ],
      );
    },
  ),
),
class CounterBloc {
  int _counter = 0;

  final _counterStateController = StreamController<int>();
  StreamSink<int> get _inCounter => _counterStateController.sink;
  // For state, exposing only a stream which outputs data
  Stream<int> get counter => _counterStateController.stream;

  final _counterEventController = StreamController<CounterEvent>();
  // For events, exposing only a sink which is an input
  Sink<CounterEvent> get counterEventSink => _counterEventController.sink;

  CounterBloc() {
    // Whenever there is a new event, we want to map it to a new state
    _counterEventController.stream.listen(_mapEventToState);
  }

  void _mapEventToState(CounterEvent event) {
    if (event is IncrementEvent)
      _counter++;
    else
      _counter--;

    _inCounter.add(_counter);
  }

  void dispose() {
    _counterStateController.close();
    _counterEventController.close();
  }
}
```
同时, Bloc 将 UI 和 业务逻辑 分离开来, 业务逻辑测试只需关注 Bloc. 

<br>

React Hooks 可以把 逻辑, 状态, UI 分离的更加清楚,  甚至原本同一组件的状态 'loadedData' 可以作为 'hasNetError' 的输入源来监听,  这使得 React 也有了种 RxJS 的味道.
```dart
function useFriendStatusBoolean(friendID) {
  const [isOnline, setIsOnline] = useState(null);
  function handleStatusChange(status) {
    setIsOnline(status.isOnline);
  }

  useEffect(() => {
    ChatAPI.subscribeToFriendStatus(friendID, handleStatusChange);
    return () => {
      ChatAPI.unsubscribeFromFriendStatus(friendID, handleStatusChange);
    };
  });
  return isOnline;
}

function useFriendStatusString(props) {
  const isOnline = useFriendStatusBoolean(props.friend.id);
  if (isOnline === null) {
    return "Loading...";
  }
  return isOnline ? "Online" : "Offline";
}

function FriendListItem(props) {
  const isOnline = useFriendStatusBoolean(props.friend.id);
  return (
    <li style={{ color: isOnline ? "green" : "black" }}>{props.friend.name}</li>
  );
}

function FriendListStatus(props) {
  const statu = useFriendStatusString(props.friend.id);
  return <li>{statu}</li>;
}
```

另外需要注意的两点是:

1 useState 的实现类似 state monad .

```javascript
// useState                                    // setState
useEffect(() => {                              componentDidUpdate() {
  setTimeout(() => {                             setTimeout(() => {
    console.log(`You clicked ${count} times`);     console.log(`You clicked ${this.state.count} times`);
  }, 3000);                                      }, 3000);
});                                            }
```

```swift
// swift's state monad
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
// what is useState("hello")
let fetchState = MState.ret(["Hello"]) >>- fetch >>- fetch >>- fetch >>- fetch
let state = fetchState.on(1)
let names = state.0               //["Hello", "Name", "Is", "paprika", "Lang"]
let nums = state.1                //5
let name = state.0[nums - 1]      //Lang
```

2 useReducer 不能当做 redux 来看. redux 的单向数据流重点在于所有 states 都储存在一个 store 中.

<br>

喵神以 redux 为灵感, 用 Swift 设计了一个[[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) :

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="600"/>

*我们最后再看一下它的测试*:

```swift
  //let (nextState,command) = reducer(state, action)

  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```


