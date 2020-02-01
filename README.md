喵神用 Swift 实现了[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

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

```swift
  // reducer 将单向数据流动的函数式 controller 的测试变得很容易.
  let initState = TableViewController.State()
  let state = controller.reducer(initState, .updateText(text: "123")).state
  XCTAssertEqual(state.text, "123")
```

喵神这个 `Store` 里面的逻辑和 **Redux** 的 `createStore` 是一样的, 其中的 `reducer: (_ state: S, _ action: A) -> (S, C?)` 函数又和 **RxJS** 中的 `scan` 操作符非常契合:

```javascript
//scan 的参数 state 是一个累积的变量，10为state的默认初始值, action 为上游传下来的[1,2].
//scan 可以做为'全局变量'来维持应用状态，如果程序中使用了多个 scan ，这些内部状态也绝对不会互相干扰.
Rx.Observable.from([1, 2]).pipe(
  scan((state, action) => state += action, 10)) 
  .subscribe(v => console.log(v))
```

<br/>

我们可以尝试用 RxJS 再来实现一版 Store :

```javascript
const createReactiveStore = (reducer, initialState) => {
  // Subject 和 useRef 作用很像: 以 interval 为例, 
  // 如果你希望不同的subscriber或者不同周期的组件使用同一个定时器源.
  const action$ = new Subject();
  let currentState = initialState;
  // scan(reducer): scan 对比 reduce 的优势是可以随时获取当前最新的状态供 getState 调用
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

 action 在进入 Store 的 dispatch 函数之前要经过各个中间件的校验, 不符合条件的会通过 next(action) 往下传. 我们可以用与 scan 相近的操作符 reduce 来搭建这个中间件之间的通道:

```javascript
// 中间件需要把符合条件的 action 直接 dispatch 出去, 不符合的 next(action), 
// 所以 dispatch 和 nex t=> action => {} 都需要作为参数传进来
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}
```

```javascript
// 搭建通道 compose
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  // 数组fns[next=>action=>{}]经过 reduce 返回的 dispatch 是最上游的 action => {}, 
  // 它的参数 next 正好是下一个中间件 cur 的返回值 action => {}, 这样 action 的通道就打通了.
  return fns.reduce((res, cur) => (...args) => res(cur(...args))) // args 就是 dispatch
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

**redux-thunk** 对于复杂的异步操作支持不够, **Netflix** 的 `Redux-Observable` 借助 RxJS 可以解决这个问题 ---- 

在 Redux-Observable 的 `epic` 里能够灵活地处理每一个 action ，也能调用 Store 中的方法. 由于 `epic` 返回的也是一个 *Observable*，所以 Redux 可以在 `epic` 外订阅它，并对新产生的 action 进行 dispatch .

```javascript
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

对 RxJS 项目测试时就利用了类似这种 'epic' 的模式, 将一些与测试无关的、业务逻辑之外的代码隔离在了 'epic' 函数之外.

<img src="http://img.wwery.com/tourist/a13320109095059.jpg" width="500"/>

```javascript
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

Dart 内置了两种对异步的支持: Future 的 `async + await` 和 Stream 的 `async* + yield`. 

图中做为生产者的 sink 可以向 Bloc 内部用来监听生产者的 StreamController 创建的 stream 传输数据; 再由另一个 stream 作为观察者将处理好的数据传给它的 StreamBuilder 并随之更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />

Stream 具备 yield(迭代器模式) 和 listen(观察者模式) , 也可以称得上 observable 了, RxDart 正是基于 Stream 进行的封装与扩展.

迭代器能够遍历一个复杂的数据集合(数组, 树形结构, 单向链表), 它提供的通用接口(getCurrent, moveToNext, isDone)让使用者不必再关心这个数据集合是如何实现的了; 而迭代器结合了观察者模式之后, 使用者甚至无需关心如何拉取数据、数据是同步还是异步产生的, 因为订阅了 publisher 之后数据会自动推送给 observer .

<br/>

最后再想一想 **react hooks** , 我们是不是也可以说, 它的作用其实不是 **重用** , 而是 **分治** 呢.






