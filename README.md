[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

如果我们可以进一步聊聊上面的话题, 不妨从 Vue 或者 Observable 的原理开始.

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

如何理解 `f(value).onResult(callback: completion)` :

```javascript
// Future flatmap                                          //React setState
future = f(value)                                          this.setState({count: this.state.count + 1});
//此时cached尚未赋值,调用的是callbacks.append(completion)     //this.state 尚未更新, count:0                      
future.onResult(callback: completion)                      console.log('# this.state', this.state); 
```

**React** 引发的事件, setState 不会同步更新 state , 一方面是因为 setState 会累积 state 的变化, 通过减少组件重绘的次数来降低性能损耗; 另一方面, 如果同步更新 `this.state`, 再调用 setState 更新组件 UI , 则有悖于 Reactive Programming 的思想.

**Future** 的 f(value0) 也是一个异步的过程, send(value1) hook 了它的异步返回结果来给 cached 赋值, 并通知它的所有 observers.

<br>

**RxSwift** 可以帮助我们扩展这个 Future 的功能, 包括 实现数据与UI的绑定.

> The push model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T>. The IObservable<T> interface is a dual of the familiar IEnumerable<T> interface. It abstracts a sequence of data, and keeps a list of IObserver<T> implementations that are interested in the data sequence. The IObservable will notify all the observers automatically of any state changes. 

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

React 在重绘一个父组件时会将没有状态变化的子组件也一起更新,  React Hooks 的 useCallback 结合 React.memo 可以解决这个问题.

```javascript
export default function ButtonMemo () {
  const [text, setText] = useState(20);
  const btnCallback = useCallback(e => {
    console.log("click");
    setText(Math.floor(Math.random() + 10));
  }, []);
  return (
    <div>
      <div>The random number is: {text}</div>
      <Button callback={(btnCallback)} />
    </div>
  );
};
const Button = React.memo(({ callback }) => (
  <button onClick={callback}>
  {console.log("button re-rendered!")}
  +
  </button>
));
```

 Flutter 其实也存在上面的问题, 它的解决的办法是创建 StreamBuilder 来监听一个 stream , 当 sink 再传入数据时只重绘订阅了 stream 的部件. 

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
同时,  Bloc 这套 Flutter 的状态管理方案将 UI 和 状态 完全分离开来, 使得业务逻辑测试只需关注 Bloc . 

<br>

而 React Hooks 对 状态 与 UI 的拆分更妙, 它让原本同一组件内的状态之间有了时间维度上的因果关联,  React 似乎有了种 RxJS 的味道.

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

Flutter 还有一套状态管理方式 --- Redux .

喵神 用 Swift 设计了一个[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/)也是以 Redux 为灵感, 它同时是一个很好的学习与应用 Redux 的小范例. 

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

<img src="https://paprika-dev.b0.upaiyun.com/Z8fWmvcwRSUGBjGY0KFv7aWXeYgRwrzK95cyVxib.jpeg" width="600"/>

*redux 的测试:*

```swift
  //let (nextState,command) = reducer(state, action)

  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```




