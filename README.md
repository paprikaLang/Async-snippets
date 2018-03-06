## Functional Programming

### 从Python的装饰器原理看函数式编程:

```
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

@decorator 语法糖的作用和AOP埋点类似.而原理如上所示:
1.接收一个函数作为参数
2.嵌套一个包装函数, 包装函数会接收原函数的相同参数，并执行原函数，且还会执行附加功能
3.返回嵌套函数

再看下面这段TCZKit的逻辑就很好理解了.

```
//CancelableTask可看成接收Bool类型参数,无返回值的函数类型
public typealias CancelableTask = (_ cancel: Bool) -> Void
//work为原函数.
//finalTask为嵌套函数,执行work同时 附加延迟功能,最后返回
public func delay(time: TimeInterval, work: @escaping ()->()) -> CancelableTask? {
    
    var finalTask: CancelableTask?
    
    let cancelableTask: CancelableTask = { cancel in
        if cancel {
            finalTask = nil // key
            
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

### 从.NET框架Reactive Extensions(Rx)的IObservable,IEnumerable看函数响应式编程:

[Pulling vs. Pushing Data](https://msdn.microsoft.com/en-us/library/hh242985.aspx)

```
IEnumerator（Pull）:                    () -> Event
IEnumerable（Pull driven stream）:      () -> (() -> Event)
IObserver  （Push）:                    Event -> ()
IObserable （Push driven stream）:      (Event -> ()) -> ()

```

```
The IObservable will notify all the observers automatically of any state changes. The PUSH model implemented by Rx is represented by the observable pattern of IObservable<T>/IObserver<T> which is similar to HOT signals in RAC.
```

```
The PULL model implemented by Rx is represented by the iterator pattern of IEnumerable<T>/IEnumerator<T> which is similar to COLD signals in RAC. The IEnumerable<T> interface exposes a single method GetEnumerator() which returns an IEnumerator<T> to iterate through this collection.
```

### 测试


函数响应式编写的应用在测试时能很好地利用VM和VC之间的绑定关系,专注于VM;
下面看看喵神对于 Event -> () 的纯函数式改造,并对比两者测试时的不同:

- master: 最基本的编程方式
- basic1: 集中UI数据,统一处理,易于测试
- reduce: 在basic1基础上,实现单向数据流

![](https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg)

```
    func reducer(state: State, userAction: Action) -> (State, Command?) //纯函数
```

```
//所有在VC中抽象的用户行为都统一指向了state的value变化,测试时只需要关注reducer前后的状态变化
    let initState = TableViewController.State()
    let state = controller.reducer(initState, .updateText(text: "123")).state
    XCTAssertEqual(state.text, "123")
```

- vuex:Vuex 是一个专为 Vue.js 应用程序开发的状态管理模式。它采用集中式存储管理应用的所有组件的状态，并以相应的规则保证状态以一种可预测的方式发生变化.


![](https://ws3.sinaimg.cn/large/006tNc79gy1fk42jdhi50j316e0w6whi.jpg)

[OC相关单向数据流Demo可参见:Zepo/Reflow](https://github.com/Zepo/Reflow)


