#### 从Python的装饰器原理看函数式编程:


```pyt
import time
def decorator(func):
    def punch():
        print(time.strftime('%Y-%m-%d', time.localtime(time.time())))
        func()
    return punch

def punch():
    print('昵称：小明  部门：IT 上班打卡成功')

f = decorator(punch)
f()
```

1.接收一个函数作为参数

2.嵌套一个包装函数, 包装函数会接收原函数的相同参数，并执行原函数，且还会执行附加功能

3.返回嵌套函数

---- 函数式的编程原理以 @decorator作为语法糖,实现了AOP埋点.


TCZKit这段用闭包实现的代码同样实现了上面三个步骤:


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

#### 从异步回调地狱看 Monad


[[Escaping Hell with Monads]](https://philipnilsson.github.io/Badness10k/escaping-hell-with-monads/)

要理解Monad先要理解容器.

```Swift
var array12 :[Int]?   //有无Optional结果大不同
array12 = [1,2,3]
var result12 = array12.map ({"No.\($0)"})
```

在 Swift 中, Array, Struct, Enum(Optional) ... 这些都是容器( [Int]? 相当于把数字包裹在了两层容器里). 

容器之间的映射靠 map 和 flatMap 完成. 

对于异步回调其实我们也可以把它放入合理的容器(如:Promise)中实现 map 和 flapMap .

```Swift
enum Result<Value>{
   case Failure(ErrorType)
   case Success(Value)}

struct Async<T> {
    let trunk:(Result<T>->Void)->Void
    init(function:(Result<T>->Void)->Void) {
        trunk = function
    }
    func execute(callBack:Result<T>->Void) {
        trunk(callBack)
    }}
```

```Swift
enum Result<Value> {
   func map<T>(@noescape f: Value throws -> T) rethrows -> Result<T>{
       return try flatMap {.Success(try f($0))}}

   func flatMap<T>(@noescape f: Value throws -> Result<T>) rethrows->Result<T>{
       switch self {
          case let .Failure(error):
             return .Failure(error)
          case let .Success(value):
             return try f(value)}}}

extension Async{
    func map<U>(f: T throws-> U) -> Async<U> {
        return flatMap{ .unit(try f($0)) }}

    func flatMap<U>(f:T throws-> Async<U>) -> Async<U> {
        return Async<U>{ cont in
            self.execute{
                switch $0.map(f){
                case .Success(let async):
                    async.execute(cont)
                case .Failure(let error):
                    cont(.Failure(error))}}}}}
```

实际上 flatMap 就是 Monad , Promise 的 then 也是 Monad ,Rx 的 Observable 同样是 Monad:

```Swift
  class Promise<T> {
     func then<U>(body: T->U) -> Promise<U>            //map
     func then<U>(body: T-> Promise<U>) ->Promise<U>   //flatMap
  }

  class Observable<T> {
     func map<U>(body: T->U) -> Observable<U>      
     func flatMap<U>(body: T-> Observable<U>) ->Observable<U>   
  }
```


#### 从 Reactive Extensions(Rx) 的 IObservable, IEnumerable 看 Publish–Subscribe Pattern :

[[Pulling vs. Pushing Data]](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

```
IEnumerator（Pull）:                    () -> Event
IEnumerable（Pull driven stream）:      () -> (() -> Event)
IObserver  （Push）:                    Event -> ()
IObserable （Push driven stream）:      (Event -> ()) -> ()
```

>The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to RACSignal in RAC.

>The IObservable will notify all the observers automatically of any state changes. 

>The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to RACSequence in RAC. 

>The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.

```Swift
final class Observable<A> {
  //订阅者
  var callbacks: [(Result<A>) -> ()] = []
  var cached: Result<A>?

  init(compute: (@escaping (Result<A>) -> ()) -> ()) {
      compute(self.send)}

  //发送(多播)
  private func send(_ value: Result<A>) {
      assert(cached == nil)
      cached = value
      for callback in callbacks {
          callback(value)
      }
      callbacks = []
  }
  //订阅
  func onResult(callback: @escaping (Result<A>) -> ()) {
      if let value = cached {
          callback(value)
      } else {
          callbacks.append(callback)
      }
  }
  
  func flatMap<B>(transform: @escaping (A) -> Observable<B>) -> Observable<B> {
      return Observable<B> { completion in
          self.onResult { result in
              switch result {
              case .success(let value):
                  transform(value).onResult(callback: completion)
              case .error(let error):
                  completion(.error(error))}}}}}
```

从某种角度看 Promise 也是一种允许我们订阅某个延迟动作的机制, 然后在准备就绪时发布一些数据.

[[Why every beginner front-end developer should know publish-subscribe pattern?]](https://itnext.io/why-every-beginner-front-end-developer-should-know-publish-subscribe-pattern-72a12cd68d44)

文章对应[[demo]](https://github.com/hzub/pubsub-demo) 中的核心代码:
```JavaScript
export function subscribe(callbackFunction) {
  changeListeners.push(callbackFunction);
}

function publish(data) {
  changeListeners.forEach((changeListener) => { changeListener(data); });
}

export function addPlace(latLng) {
  geocoder.geocode({ 'location': latLng }, function (results) {
    try {
      const cityName = results
        .find(result => result.types.includes('locality'))
        .address_components[0]
        .long_name;

      myPlaces.push({ position: latLng, name: cityName });

      publish(myPlaces);

      localStorage.setItem('myPlaces', JSON.stringify(myPlaces));
    } catch (e) {
      console.log('No city found in this location! :(');
    }
  });
}
```

<img src="https://mmbiz.qpic.cn/mmbiz_png/XIibZ0YbvibkXKEDCRlU9GsNktIiaRZprYJ8dOyWRAhXTNX9y9hIDSzYxuiaQj5lXYxR3yVmiaqF6bphAVIW6IOLwvw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" width="400"/>

喵神在 [[单向数据流动的函数式 View Controller]](https://onevcat.com/2017/07/state-based-viewcontroller/) 中也应用了这个模式对 State 进行集中管理以便扩展和测试.

```Swift
class Store<A:ActionType,S:StateType,C:CommandType> {
    let reducer: (_ state:S,_ action:A) -> (S,C?)
    var subscriber: ((_ state:S,_ previousState:S,_ command:C?) -> Void)?
    var state: S
    init(reducer:@escaping (S,A)->(S,C?),initialState:S) {
        self.reducer = reducer
        self.state = initialState
    }
    //订阅
    func subscribe(_ handler: @escaping (S,S,C?) -> Void) {
        self.subscriber = handler
    }
    func unsubscribe(){
        self.subscriber = nil
    }
    //发送 
    func dispatch(_ action:A){
        let previousState = state
        let (nextState,command) = reducer(state, action)
        state = nextState
        //订阅者获取新的状态
        subscriber?(state,previousState,command)}}
```
几处 subscriber 的作用其实类似于 OC 的 block 传值:
```Swift
//declaration
double (^rateAndTime)(double rate, double time);
//definition
rateAndTime = ^double(double rate, double time){
    return rate*time;
};
//caller
double dx = rateAndTime(32,2);
```

所有在VC中抽象的用户行为都统一指向了 state 的 value 变化, 测试时 只需要关注 reducer 前后的状态
```Swift
//测试
let initState = TableViewController.State()
let state = controller.reducer(initState, .updateText(text: "123")).state
XCTAssertEqual(state.text, "123")
```

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

对比 Redux 与 Vuex 

<img src="https://paprika-dev.b0.upaiyun.com/EivCtaYUlSUPQsEacPEyfv8kiFJUBcQVfikIbdw9.jpeg" width="500"/>

<img src="https://ws3.sinaimg.cn/large/006tNc79gy1fk42jdhi50j316e0w6whi.jpg" width="500"/>



[OC相关单向数据流Demo可参见:Zepo/Reflow](https://github.com/Zepo/Reflow)


