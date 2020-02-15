
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

Redux 的 `reducer` 更契合 **RxJS** 的 `scan` 操作符. 在 RxJS 项目中 scan 也是用来保存和维持当前状态的，并且各 scan 内部的状态彼此互不干扰.

```javascript
//scan 的参数 state 也是一个受 action 作用而不断累计的变量，10 为 state 的默认初始值.
//scan 可以得到 state 的每个累计值, 而 reduce 只能得到一个最终累计值, 如果上游是无休止的, 那这个最终值就永远无法得到; 
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

redux 的中间件既不是时间维度上的集合stream, 也不是空间维度上的集合array, 但它们可以通过函数参数和返回值在彼此一进一出的地方连接起来. 

```javascript
// 简单实现一下 redux-thunk
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
    // 下游 reduxSaga 的校验和处理动作
    ... ...
    return next(action) // 这里, reduxSaga 的 next(action) 可以继续往下游展开直到 dispatch 那里.
    // 这个闭包从外面的结构看是 reduxThunk 的参数 next ,从里面的内容看则是 reduxSaga(next) 的返回值.
  }
}
```

```javascript
// 用 reduce 来实现中间件的连接
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  // 数组 fns 是 [next=>action=>{}], args 是 dispatch
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

&nbsp;

如果把中间件的检验筛选看作是一种过滤类操作符的行为, 那么像回压控制类操作符( throttle 和 window )，还有可以调用 AJAX 请求的操作符( mergeMap 和 switchMap)等等这些处理异复杂步操作的功能应该都可以借助 RxJS 插入到 redux 处理 action 的流程之中. 恰好 netflix 的 Redux-Observable 就是这样一款中间件.


```javascript
//epic 是Redux-Observable最核心的函数: 接收一个observable, 再返回一个observable, 内部则是中间件的logic.
const epic = (action$, store) => {
  return action$
    .filter(
      action => (action.type === ActionTypes.MINUS ||
        action.type === ActionTypes.PLUS)
    )
    .delay(1000)
    .map(action => {
      const count = store.getState().count;
      if(count ...) { ... return {type: 'plus'}} ... ...
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

&nbsp;

RxJS 项目在测试时也会用到 `epic` 函数这样的模式将一些与外部逻辑隔离在 "epic" 函数之外, 来提高可测试性.

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
·可以一次只测试一个功能。 
·可以很容易制造各种测试前提条件。
·可以很容易提高代码的测试覆盖率。
·可以很容易模拟被测对象依赖的模块。
*/
// epic 模式可以提高 RxJS 代码的可测试性
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

&nbsp;

**Flutter** 也有自己的 `epic` 模式 ---- **Bloc (Business Logic Component)**. 

**Dart** 内置了两种对异步的支持: Future 的 `async + await` 和 Stream 的 `async* + yield`.(Stream 具备了 Observable 所需的 迭代器模式 `yield` 和 观察者模式 `listen` ).

> 所谓迭代器模式就是通过一些通用接口(getCurrent, moveToNext, isDone)来遍历一些复杂的、未知的数据集合; 观察者模式则不需要这些**拉取**数据的接口, 因为订阅了 publisher 之后, 无论数据是同步还是异步产生的,都会自动**推送**给 observer .

&nbsp;

图中做为生产者的 sink 可以向 `Bloc` 内部用于监听生产者的 stream 传输数据; 再由另一个 stream (不同 StreamController 创建的)作为观察者将处理好的数据传给它的 StreamBuilder 并同步更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />






