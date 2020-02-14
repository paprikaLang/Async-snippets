喵神用 Swift 实现了[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

`Store` 里面的逻辑和 **Redux** 的 `createStore` 是一样的.

```swift
class Store<A: ActionType, S: StateType, C: CommandType> {
    let reducer: (_ state: S, _ action: A) -> (S, C?)
    var subscriber: ((_ state: S, _ previousState: S, _ command: C?) -> Void)?
    var state: S

    init(reducer:@escaping (S, A)->(S, C?), initialState: S) {
        self.reducer = reducer
        self.state = initialState
    }
    
    func subscribe(_ handler: @escaping (S, S, C?) -> Void) {
        self.subscriber = handler
    }
    func unsubscribe(){     
        self.subscriber = nil
    }
    // dispatch 将 action 传给 reducer 更新 state
    func dispatch(_ action: A){
        let previousState = state
        let (nextState, command) = reducer(state, action)
        state = nextState
        // 订阅者获取新的状态
        subscriber?(state, previousState, command)
    }
}
```


<br>



> 函数式容易编写「可预测」的代码 ---- cyclejs

```swift
  // 函数式 controller 的测试
  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```

`reducer: (_ state: S, _ action: A) -> (S, C?)`  与 **RxJS** 中的 `scan` 操作符非常契合:

```javascript
//scan 的参数 state 是一个经过 action 不断改变而累积的变量，10 为 state 的默认初始值.
//reduce 操作符只能得到一个 state 的最终累积值, 如果这个流无休止, 那最终的值就永远得不到; 
//而 scan 则可以随时得到新的累积值, 在RxJS应用中可做为'全局变量'来维持状态，并且各 scan 内部的状态不会互相干扰.
Rx.Observable.from([1, 2]).pipe(
  scan((state, action) => state += action, 10)) 
  .subscribe(v => console.log(v))
```


<br/>



如果把 action 就看做是时间维度上的集合, `dispatch` 可以这样实现:

`action$.next(action)` + `action$.scan(reducer).do(state => { //getState ...... })`.  RxJS 版 Store 如下:

```javascript
const createReactiveStore = (reducer, initialState) => {
  const action$ = new Subject();
  let currentState = initialState;
  const store$ = action$.startWith(initialState).scan(reducer).do(state => {
    currentState = state
  });

  return {
    dispatch: (action) => {
      return action$.next(action)
    },
    getState: () => currentState,
    subscribe: (func) => {
      store$.subscribe(func);
    }
  }
}
```

action 在进入 Store 的 dispatch 函数之前还会经历各个中间件的校验, 不符合条件的会通过 next(action) 往下传递. 

```javascript
// 中间件需要把符合条件的 action 直接 dispatch 出去, 不符合的再 next(action), 
// 所以 dispatch 和 next: action => {} 都需要作为参数传进来.
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}
```

抽象分析一下中间件函数的内部结构:

```javascript
const reduxThunk = ({ dispatch, getState }) => next => action => {
  // reduxThunk 的校验动作
  ... ...
  return action => {
    // 下游 reduxYoga 的校验动作
    ... ...
    return next(action) // 这里, reduxYoga 的 next(action) 可以继续拆解下去
    // 这个闭包从外面的结构看是 reduxThunk 的参数 next , 从里面的内容看则是 reduxYoga 的返回值, 即reduxThunk(reduxYoga()) 
  }
}
```

```javascript
// reduce 实现中间件的连接: reduxThunk(reduxYoga())
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  // 数组fns是 [next=>action=>{}], args 是 dispatch
  return fns.reduce((res, cur) => (...args) => res(cur(...args))) 
}

export function applyMiddleware(...middlewares) {
  return createStore => reducer => {
    const store = createStore(reducer)
    let { getState, dispatch } = store
    const params = {
      getState: getState,
      dispatch: (...args) => dispatch(...args)
    }
    const middlewareArr = middlewares.map(middleware => middleware(params))
    dispatch = compose(...middlewareArr)(dispatch);
    return { ...store, dispatch }
  }
}
```

<br/>

> 响应式容易编写「可分离」的代码  ---- cyclejs

```javascript
// 这是 RxJS 版中间件 Redux-Observable 中最核心的函数 ---- epic
const epic = (action$, store) => {
  return action$
    .filter(
      action => (action.type === ActionTypes.MINUS ||
        action.type === ActionTypes.PLUS)
    ) // 相较于 Redux-Thunk, Redux-Observable 可以更加灵活地处理 action 的过滤、转换、返回...
    .delay(1000)
    .map(action => {
      const count = store.getState().count;
      ... ...
      return {type: 'new'};
    });
};
```

RxJS 项目测试时也会用到这种 `epic` 模式将一些与业务逻辑无关的代码隔离在进行测试的纯函数之外.

<img src="http://img.wwery.com/tourist/a13320109095059.jpg" width="500"/>

```javascript
//生产者
const plus$ = () => {
  return Rx.Observable.fromEvent(document.querySelector('#plus'), 'click');
}
//观察者
const observer = {
  next: currentCount => {
    document.querySelector('#count').innerHTML = currentCount; 
  }
};
//处理业务 Logic 的纯函数 
const counterPipe = (plus$, minus$) => {
  return Rx.Observable.merge(plus$.mapTo(1), minus$.mapTo(-1))
          .scan((count, delta) => count + delta, 0)
}
//在 epic 模式下测试会十分容易 
describe('Counter', () => {
  test('should add & subtract count on source', () => {
    const plus =     '^-a------|'; 
    const minus =    '^---c--d--|'; 
    const expected = '--x-y--z--|';
    const result$ = counterPipe(hot(plus), hot(minus));
    expectObservable(result$).toBe(expected, { x: 1, y: 0, z: -1, });
  }); 
});
```

<br/>

**Flutter** 也有类似的模式 ---- Bloc (Business Logic Component). 

**Dart** 内置了两种对异步的支持: Future 的 `async + await` 和 Stream 的 `async* + yield`(Stream 具备了 Observable 所需的迭代器模式(yield) 和 观察者模式(listen)).

> 所谓迭代器模式就是通过一些通用接口(getCurrent, moveToNext, isDone)来遍历一个复杂的、未知的数据集合(数组, 树形结构, 单向链表); 而它结合了观察者模式之后, 就可以忽略掉这些**拉取**数据的接口了, 因为订阅了 publisher 之后, 无论是同步还是异步产生的数据都会按设定好的自动**推送**给 observer .

图中做为生产者的 sink 可以向 Bloc 内部用来监听生产者的 StreamController 创建的 stream 传输数据; 再由另一个 stream 作为观察者将处理好的数据传给它的 StreamBuilder 并同步更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />


<br>





<br>

最后再想一想 **react hooks** , 我们是不是也可以说, 它的作用其实不是 **重用** , 而是 **分治** 呢.






