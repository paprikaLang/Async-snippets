
&nbsp; 

> 函数式容易编写「可预测」的代码, 响应式容易编写「可分离」的代码 ---- cyclejs.cn

&nbsp; 

## 一 可预测的函数式

这是一个移动端用 Redux 的状态管理方式构建出来的[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

```swift
// Store 可以对照着 redux 的 createStore 来看
class Store<A: ActionType, S: StateType, C: CommandType> {
    // reducer 是驱动数据单向流动的正负极
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
    func dispatch(_ action: A){
        let previousState = state
        let (nextState, command) = reducer(state, action)
        state = nextState
        // 订阅者 stateDidChanged 在得到 reducer 返回的新状态后会更新 UI.
        subscriber?(state, previousState, command)
    }
}
```

整个构建的核心, 即驱动数据单向流动的正负极是 Store 中的 `reducer` 函数.

```swift
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
            // command 只是触发异步请求操作, 不会更改 state, 所以需要再发送一次 action .
            self?.store.dispatch(.addToDos(items: data))
        }
    }
    return (state, command)
}
```

从更新状态的 reducer 到更新 UI 的 stateDidChanged 都是可回溯、可预测的纯函数, 这样就提升了整个 View Controller 可测试和可维护性. 

```swift
  /*
    测试中, `Command.loadToDos` 的 handler 充当了天然的 `stub`, 
    通过一组 dummy 数据 (["2", "3"]) 就能检查 store 中的状态是否符合预期，
    同时又以同步的方式测试了异步加载的过程.
  */
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

Redux 的 `reducer` 没有触发副作用的 `Command` , 更契合 **RxJS** 中同样用来维护应用的状态的操作符 `scan((state, action) => state += action, 10)) ` , 如果把 action 看做是时间维度上的集合 action$ , 那么 Store 就可以这样实现了:

```javascript
const createReactiveStore = (reducer, initialState) => {
  const action$ = new Subject();
  let currentState = initialState;
  /*
   state 也是一个受 action 作用而不断累计的变量，scan 可以向下游传递 state 的每个累计值;
   操作符 reduce 与 scan 的唯一区别是: reduce 只会传递一个最终的累计值, 它的上游必须是有限的数据.
  */
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

RxJS 还有过滤类操作符 filter , 回压控制类操作符 throttle 和 window ，调用 AJAX 请求的操作符 mergeMap 和 switchMap ...这些支持复杂异步操作的功能其实也可以插入到 redux 处理 action 的流程之中. `Redux-Observable` 就以中间件的形式实现了这个想法.

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

createStore 函数其实还支持第三个参数, applyMiddleware 重写了 createStore 返回的 dispatch 函数, 使得 action 进入 dispatch 之前要先经过 redux-observable 中间件 `epic` 函数的处理.

```javascript
// 先设计两个中间件
const reduxArray = ({ dispatch, getState }) => next => action => {
  if (Array.isArray(action)) {
    return action.forEach(act => dispatch(act))
  }
  return next(action)
}
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}

// applyMiddleware 要把这两个中间件像这样垒起来.
const reduxThunk = ({ dispatch, getState }) => next => action => {
  // reduxThunk 的校验和处理动作
  ... ...
  return action => {
    // 下游 reduxArray 的校验和处理动作
    ... ...
    return next1(action) // 这是reduxArray的, 还可以继续向下游展开直到 dispatch 的 action => {}. 
  }
}
```

applyMiddleware 实现的是: 中间件 reduxThunk 的返回值从外部看是 reduxThunk 的参数 next , 从内部看则是 reduxArray(next1) 的返回值, 以此类推. 

```javascript
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  
  // 数组 fns 就是 middlewares:[ next => action=> { } ], args 是 dispatch
  // reduce 可以实现applyMiddleware的套娃逻辑.
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


Redux-Observable 的 `epic` 函数: 接收一个 observable , 再返回一个 observable, 内部则是中间件的业务逻辑. 

RxJS 项目在测试时也会用到这样的模式将一些无关的外部逻辑隔离在 "epic" 函数之外, 来提高代码的可测试性.

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
//处理业务逻辑的纯函数 
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

> 所谓迭代器模式就是通过一些通用接口(getCurrent, moveToNext, isDone)来遍历一些复杂的、未知的数据集合; 观察者模式不需要这些**拉取**数据的接口遍历数据, 因为订阅了 publisher 之后, 无论数据是同步还是异步产生的, 都会自动**推送**给 observer .

&nbsp;

图中做为生产者的 sink 可以向 `Bloc` 内部监听它的 stream 传输数据; 再由另一个 stream (因为是不同 StreamController 创建的)作为观察者将处理好的数据传给它的 StreamBuilder 并同步更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />






