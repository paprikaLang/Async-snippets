## Functional Programming


### 从Python的装饰器原理看函数式编程:


```pyt
import time
def decorator(func):
    def punch():
        print(time.strftime('%Y-%m-%d', time.localtime(time.time())))
        func()
    return punch

def punch():
    print('昵称：小明  部门：iOS 上班打卡成功')

f = decorator(punch)
f()
```

1.接收一个函数作为参数

2.嵌套一个包装函数, 包装函数会接收原函数的相同参数，并执行原函数，且还会执行附加功能

3.返回嵌套函数

---- 函数式的编程原理以 @decorator作为语法糖,实现了AOP埋点.


TCZKit这段用闭包实现的代码同样实现了上面三个步骤:


```pyt
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

### 从闭包的异步回调地狱看 Monad


[Escaping Hell with Monads](https://philipnilsson.github.io/Badness10k/escaping-hell-with-monads/)

要理解Monad先要理解容器.

```
var array12 :[Int]?   //有无Optional结果大不同
array12 = [1,2,3]
var result12 = array12.map ({"No.\($0)"})
```

在 Swift 中, Array , Struct , Enum(Optional)...这些都是容器([Int]?类型相当于把数字包裹在了嵌套的两层容器里), 容器之间的映射靠 map 和 flatMap 完成. 

对于异步回调其实我们也可以把它放入合理的容器( Promise )中实现 map 和 flapMap 方法,并像  array.map().flatMap()  这样链式的调用.

```pyt
enum Result<Value>{
   case Failure(ErrorType)
   case Success(Value)
}

struct Async<T> {
    let trunk:(Result<T>->Void)->Void
    init(function:(Result<T>->Void)->Void) {
        trunk = function
    }
    func execute(callBack:Result<T>->Void) {
        trunk(callBack)
    }
}
```

```pyt
enum Result<Value> {
   func map<T>(@noescape f: Value throws -> T) rethrows -> Result<T>{
       return try flatMap {.Success(try f($0))}
   }
   func flatMap<T>(@noescape f: Value throws -> Result<T>) rethrows->Result<T>{
       switch self {
          case let .Failure(error):
             return .Failure(error)
          case let .Success(value):
             return try f(value)
       }
   }
}

extension Async{
    func map<U>(f: T throws-> U) -> Async<U> {
        return flatMap{ .unit(try f($0)) }
    }
    func flatMap<U>(f:T throws-> Async<U>) -> Async<U> {
        return Async<U>{ cont in
            self.execute{
                switch $0.map(f){
                case .Success(let async):
                    async.execute(cont)
                case .Failure(let error):
                    cont(.Failure(error))
                }
            }
        }
    }
}
```

实际上 flatMap 就是 Monad , Promise 的 then 也是 Monad ,Rx 的 Observable 也实现了Monad:

```pyt
  class Promise<T> {
     func then<U>(body: T->U) -> Promise<U>            //map
     func then<U>(body: T-> Promise<U>) ->Promise<U>   //flatMap
  }
  class Observable<T> {
     func map<U>(body: T->U) -> Observable<U>      
     func flatMap<U>(body: T-> Observable<U>) ->Observable<U>   
  }
```


### 从.NET框架Reactive Extensions(Rx)的IObservable,IEnumerable看函数响应式编程:


[Pulling vs. Pushing Data](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

```
IEnumerator（Pull）:                    () -> Event
IEnumerable（Pull driven stream）:      () -> (() -> Event)
IObserver  （Push）:                    Event -> ()
IObserable （Push driven stream）:      (Event -> ()) -> ()
```


The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to **HOT** signals in RAC.

The IObservable will notify all the observers automatically of any state changes. 


The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to **COLD** signals in RAC. 

The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.


### 测试


以函数响应式编写的应用在测试时能很好地利用VM和VC之间的绑定关系,专注于VM进行测试;
下面看看喵神对于 Event -> () 的纯函数式改造,并对比两者测试的不同:


- master: 最原始的编程方式
- basic1: 集中UI数据,统一处理
- reduce: 在basic1基础上,实现单向数据流


![](https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg)

```
    //纯函数
    func reducer(state: State, userAction: Action) -> (State, Command?) 
```

```pyt
    //所有在VC中抽象的用户行为都统一指向了state的value变化,测试时只需要关注reducer前后的状态
    let initState = TableViewController.State()
    let state = controller.reducer(initState, .updateText(text: "123")).state
    XCTAssertEqual(state.text, "123")
```


- vuex:Vuex 是一个专为 Vue.js 应用程序开发的状态管理模式。它采用集中式存储管理应用的所有组件的状态，并以相应的规则保证状态以一种可预测的方式发生变化.



![](https://ws3.sinaimg.cn/large/006tNc79gy1fk42jdhi50j316e0w6whi.jpg)

[OC相关单向数据流Demo可参见:Zepo/Reflow](https://github.com/Zepo/Reflow)


