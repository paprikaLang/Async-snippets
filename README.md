
&nbsp; 

> 函数式容易编写「可预测」的代码, 响应式容易编写「可分离」的代码 ---- cyclejs.cn

<br/>

&nbsp; 

## 一 可预测的函数式

喵神用 Swift 实现了[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

```swift
// 图可以说就是 redux , 这个 Store 的实现和 createStore 也几乎一样.
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
纯函数 reducer 的可预测性, 带来的是它的可测试性和可维护性. 

```
// redux 的 reducer 没有 command 来触发副作用.
lazy var reducer: (State, Action) -> (state: State, command: Command?) = {
    [weak self] (state: State, action: Action) in
    
    var state = state
    var command: Command? = nil

    switch action {
    case .updateText(let text):
        state.text = text
    // ...
    case .loadToDos:
        command = Command.loadToDos { data in
            // command 只是触发异步请求操作, 不会更改 state, 还是要再发送一次 action 的.
            self?.store.dispatch(.addToDos(items: data))
        }
    }
    return (state, command)
}
```

`Command.loadToDos` 的 handler 充当了天然的 `stub`, 通过一组 dummy 数据 (["2", "3"]) 就能检查 store 中的状态是否符合预期，同时又以同步的方式测试了异步加载的过程.

```swift
    let initState = TableViewController.State()
    let (_, command) = controller.reducer(initState, .loadToDos)
    XCTAssertNotNil(command)
    switch command! {
    case .loadToDos(let handler):
        handler(["2", "3"])
        XCTAssertEqual(controller.store.state.dataSource.todos, ["2", "3"])
    }
```

&nbsp; 

Redux 的 `reducer` 没有 `Command` , 更契合 **RxJS** 的 `scan` 操作符. 在 RxJS 项目中 scan 也是用来保存和维持当前状态的，并且各 scan 内部的状态彼此互不干扰.

```javascript
//scan 的参数 state 也是一个受 action 作用而不断累计的变量，10 为 state 的默认初始值.
//scan 可以得到 state 的每个累计值; 而 reduce 只能得到一个最终累计值, 如果它的上游是无休止的, 那这个最终值就永远无法得到; 
Rx.Observable.from([1, 2]).pipe(
  scan((state, action) => state += action, 10)) 
  .subscribe(v => console.log(v))
```

如果再把 Redux 的 action 看做是时间维度上的集合也就是 RxJS 的流, 那么 Store 其实可以这样实现了:

```javascript
// RxJS 版 Store
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

&nbsp;

RxJS 还有过滤类操作符(filter), 回压控制类操作符( throttle 和 window )，调用 AJAX 请求的操作符( mergeMap 和 switchMap) ... , netflix 开源的 redux 中间件 `Redux-Observable` 可以将 RxJS 这些处理复杂异步操作的功能都插入到 redux 处理 action 的流程之中. 

```javascript
const epic = (action$, store) => {
  return action$
    .filter( action => 
      (action.type === ActionTypes.MINUS || action.type === ActionTypes.PLUS)
    )
    .delay(1000)
    .map(action => {
      const count = store.getState().count;
      if(count ...) { 
        ... 
        return {type: 'plus'};
      } else { ... }
      return {type: 'nothing'};
    });
};

import {createEpicMiddleware} from 'redux-observable'; 
import epic from './Epic';
const epicMiddleware = createEpicMiddleware(epic);
const store = createStore(
  reducer,
  initValues,
  applyMiddleware(epicMiddleware)
);
```

`applyMiddleware` 的参数可以有多个, Redux 需要订阅 `epic` 函数返回的新 action$ 并直接 dispatch 出去, 不符合 filter 过滤条件的需要通过 next(action) 继续向下传递. 我们来简单实现这些过程:

```javascript
// 自定义一个中间件
const reduxArray = ({ dispatch, getState }) => next => action => {
  if (Array.isArray(action)) {
    return action.forEach(act => dispatch(act))
  }
  return next(action)
}

// reduxThunk
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}

//抽象化这个 reduxThunk 中间件.
const reduxThunk = ({ dispatch, getState }) => next => action => {
  // reduxThunk 的校验和处理动作
  ... ...
  return action => {
    // 下游 reduxArray 的校验和处理动作
    ... ...
    return next(action) // 这里, reduxArray 的 next(action) 可以继续往下游展开直到 dispatch 的 action => {}.
    // 这个闭包从外面的结构看是 reduxThunk 的参数 next ,从里面的内容看则是 reduxArray(...) 的返回值.
    // 也就是这样 reduxThunk(reduxArray(...))
  }
}
```

```javascript
// applyMiddleware 可以用 reduce 来连接参数中的这些中间件实现 reduxThunk(reduxArray(...)).
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  
  // 数组 fns 是 [ next => actio n=> { } ]
  // args 是 dispatch
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

&nbsp;

&nbsp;

## 二 可分离的响应式


`epic` 是 Redux-Observable 最核心的函数: 接收一个 observable , 再返回一个 observable, 内部则是中间件的业务逻辑. RxJS 项目在测试时也会用到这样的模式将一些无关的外部逻辑隔离在 "epic" 函数之外, 来提高可测试性.

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
//处理业务逻辑(Logic)的纯函数 
const counterPipe = (plus$, minus$) => {
  return Rx.Observable.merge(plus$.mapTo(1), minus$.mapTo(-1))
          .scan((count, delta) => count + delta, 0)
} 
/*
可测试性体现在如下方面:
·可以一次只测试一个功能 
·可以很容易制造各种测试前提条件
·可以很容易提高代码的测试覆盖率
·可以很容易模拟被测对象依赖的模块
*/
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

&nbsp;

**Flutter** 也有自己的 `epic` 模式 ---- **Bloc (Business Logic Component)**. 

**Dart** 内置了两种对异步的支持: Future 的 `async + await` 和 Stream 的 `async* + yield`.(Stream 具备了 Observable 所需的 迭代器模式 `yield` 和 观察者模式 `listen` ).

> 所谓迭代器模式就是通过一些通用接口(getCurrent, moveToNext, isDone)来遍历一些复杂的、未知的数据集合; 观察者模式不需要这些**拉取**数据的接口, 因为订阅了 publisher 之后, 无论数据是同步还是异步产生的, 都会自动**推送**给 observer .

&nbsp;

图中做为生产者的 sink 可以向 `Bloc` 内部监听它的 stream 传输数据; 再由另一个 stream (不同 StreamController 创建的)作为观察者将处理好的数据传给它的 StreamBuilder 并同步更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />






