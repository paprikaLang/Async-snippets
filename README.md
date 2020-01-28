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
  // reducer 可以让 controller 的测试变得很容易.
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

<br>

我们可以尝试用 RxJS 再来实现一版 Store :

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

 action 在进入 store 的 dispatch 函数之前要经过各个中间件的校验, 不符合条件的会通过 next(action) 传给下一个. 我们可以用另一个和 **reducer** 很相近的操作符 `reduce` 来搭建中间件之间的这个通道:

```javascript
const reduxThunk = ({ dispatch, getState }) => next => action => {
  if (typeof action === 'function') {
    return action(dispatch, getState)
  }
  return next(action)
}
```

```javascript
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

<br>

**redux-thunk** 对于复杂的异步操作支持不够, **Netflix** 的 `Redux-Observable` 借助 RxJS 解决了这个问题 ---- 

在 Redux-Observable 的 `epic` 里可以灵活地处理每一个 action ，也可以调动 store 中的方法. 不过 epic 返回的也是一个 *Observable*，Redux 可以在 epic 外订阅它，再对新产生的 action 进行 dispatch .

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

对 Rxjs 项目测试时就利用了这种 'epic' 模式将一些业务逻辑之外的代码隔离在了 'epic' 函数之外.

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

<br>

**Flutter** 也有类似的模式 ---- Bloc (Business Logic Component). 

Dart 内置了两种对异步的支持: Future 的 `async + await` 和 Stream 的 `async* + yield`. 

图中做为生产者的 sink 可以向 Bloc 内部用来监听生产者的 StreamController 创建的 stream 传输数据; 再由另一个 stream 作为观察者将处理好的数据传给它的 StreamBuilder 并随之更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />

Stream 具备 yield(迭代器模式) 和 listen(观察者模式) , 也可以称得上 Observable , RxDart 正是基于 Stream 进行的封装与扩展.

迭代器能够遍历一个复杂的数据集合(数组, 树形结构, 单向链表), 它提供的通用接口(getCurrent, moveToNext, isDone)让使用者不必关心这个数据集合是如何实现的; 而迭代器结合了观察者模式之后, 使用者甚至无需关心如何拉取数据、数据是同步还是异步产生的, 因为订阅了 publisher 之后数据会自动推送给 observer .

<br>

最后再想一想 react hooks, 我们是不是也可以说, 它的作用其实不是 **重用**, 而是 **分治**呢.






