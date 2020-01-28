喵神用 Swift 实现了[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://ws1.sinaimg.cn/large/006tKfTcgy1fjs0fvb71bj31e40ncmze.jpg" width="600"/>

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

```
  // reducer 让 controller 的测试变得很容易.
  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```

 `Store` 里面的逻辑和 `redux` 的 createStore 是一样的, 而其中 `reducer` 函数和 `RxJS` 中维护应用状态的 `scan` 操作符又非常契合, 那么我们不妨用 RxJS 再来实现一版 :

```
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

```
//state是一个累积的变量，10为state的默认初始值.
//scan 完全可以替代全局变量来维持应用状态，如果程序中使用了多个scan，这些内部状态也绝对不会互相干扰.
Rx.Observable.from([1, 2]).pipe(
  scan((state, action) => state += action, 10)) 
  .subscribe(v => console.log(v))
```

 action 在进入 store 的 dispatch 函数之前会经过每个中间件的校验, 不符合条件的会通过 next(action) 传给下一个中间件, 我们可以用另一个和 `reducer` 很相近的操作符 `reduce` 来搭建 `redux 中间件` 之间的通道:

```
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}
```

```
export function applyMiddleware(...middlewares) {
  return createStore => reducer => {
    const store = createStore(reducer)
    let { getState, dispatch } = store
    const params = {
      getState: getState,
      dispatch: (...args) => dispatch(...args)
    }
    // 符合条件的action在当前中间件直接dispatch出去, 不必再往后传递.
    const middlewareArr = middlewares.map(middleware => middleware(params))
    // 数组[next=>action=>{}]经过 reduce 返回的dispatch是最上游的 action => {}, 
    // 它的参数next正是下一个中间件cur的返回值action => {}, 这样通道就打通了.
    dispatch = compose(...middlewareArr)(dispatch);
    return { ...store, dispatch }
  }
}

export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  return fns.reduce((res, cur) => (...args) => res(cur(...args))) //args就是dispatch
}
```

redux-thunk 功能简单，对于复杂的异步操作支持不够. Netflix 的 `Redux-Observable` 借助 RxJS 可以解决这个问题:

在 Redux-Observable 的 `epic` 里可以灵活地处理每一个action，也可以调动 store 中的方法, 不过 epic 返回的也是一个 `Observable`，Redux 可以在 epic 外订阅它，再对新产生的 action 进行 dispatch .

```
const epic = (action$, store) => {
  return action$
    .filter(
      action => (action.type === ActionTypes.MINUS ||
        action.type === ActionTypes.PLUS)
    ) // 可以灵活地处理 action 过滤、转换、返回的时机
    .delay(1000)
    .map(action => {
      const count = store.getState().count;
      ... ...
      return {type: 'new'};
    });
};
```

在对 Rxjs 项目进行单元测试时, 就利用了这种 epic 模式将一些业务逻辑之外的代码隔离在了 "epic" 函数之外.

<img src="http://img.wwery.com/tourist/a13320109095059.jpg" width="500"/>

```
//生产者
const createPlus$ = () => {
  return Rx.Observable.fromEvent(document.querySelector('#plus'), 'click');
}
//观察者
const observer = {
  next: currentCount => {
    document.querySelector('#count').innerHTML = currentCount; 
  }
};
//处理业务的纯函数 
const counterPipe = (plus$, minus$) => {
  return Rx.Observable.merge(plus$.mapTo(1), minus$.mapTo(-1))
          .scan((count, delta) => count + delta, 0)
}
//在epic模式下测试会十分容易 
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

Flutter 也有类似的模式 ---- Business Logic Component. Dart 内置了两种对异步的支持: Future的 `async + await` 和 Stream 的 `async* + yield`. 图中做为生产者的 sink 可以向 Bloc 内部用来监听生产者的 StreamController 创建的 stream 传输数据, 再由另一个 stream 作为观察者将处理好的数据传给它的 StreamBuilder 并随之更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />

Stream 具备 yield 和 listen , 也就是 `迭代器模式` 和 `观察者模式`, 已经可以称的上 observable 了. 而 RxDart 正是基于 Stream 进行的封装与扩展.

迭代器能够遍历一个复杂的数据集合(数组, 树形结构, 单向链表)的对象, 它提供的通用接口(getCurrent, moveToNext, isDone)让使用者不用关心这个数据集合是如何实现的. 当迭代器模式结合观察者模式之后,使用者甚至无需关心如何拉取数据或者数据是同步还是异步产生的,因为订阅了publisher之后数据会自动推送给observer.






