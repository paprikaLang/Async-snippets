
&nbsp; 

## 一   可预测的函数式

 

&nbsp;这是一个在移动端按照 redux 状态管理模式构建出来的[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

```swift
// 图中的 Store 可以对照着 redux 的 createStore 来看
class Store<A: ActionType, S: StateType, C: CommandType> {
    // CommandType 是对副作用的抽象化, 同时将 action 从处理副作用的 action creator 中解脱出来. 
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
        /*
	 订阅了 nextState 的 subscriber 负责更新 UI;
         订阅了 command   的 subscriber 处理副作用, 比如一个异步请求完成后, 
	 command 的闭包会接收返回的数据做为 action 的 payload , 再 dispatch 给 reducer.
        */
        subscriber?(state, previousState, command)
    }
}
```

数据可回溯、可预测的关键在于隔离副作用, 确保 reducer 是一个纯函数. `Command` 和 redux 的 `action creator` 都是这个目的.

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

redux 另一种隔离副作用的方法是 `中间件`, createStore 的第三个参数 `applyMiddleware` 可以重写 dispatch , 使得 action 在进入 reducer 之前要先经过中间件的处理.


<img src="https://upic.paprikaLang.site/rxjs-redux.jpg" width="600"/>

```javascript
/* 
   中间件要先校验 action , 校验通过的经过处理后重新 dispatch 一个 action---- 
   校验未通过的传给下一个中间件 ----
   校验都未通过就可以传给 reducer 了.
   自定义中间件的话, action、dispatch、next 都是必需的参数.
*/
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
// applyMiddleware 要把中间件像这样垒起来
const reduxThunk = ({ dispatch, getState }) => next => action => {
  // reduxThunk 的处理
  ... ...
  return action => {  
    // 下游 reduxArray 的处理
    ... ...
    return next1(action) 
  }
}
/*
reduxThunk(next) 的返回值   是自己的 action => {},
reduxThunk(next) 的参数next 是 reduxArray(next1) 的返回值 action => {}, 
applyMiddleware  用 reduce 来实现最合适.
*/
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
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

## 二   可分离的响应式

&nbsp;

中间件 `redux-observable` 的响应式流可分离一个异步请求的多层回调, 并将每层回调解耦成一个 epic 函数, 函数内部借助 RxJS 操作符可处理复杂的异步操作.

```javascript
const fetchUser = username => ({ type: FETCH_USER, payload: username });
const fetchUserFulfilled = payload => ({ type: FETCH_USER_FULFILLED, payload });

// epic 函数: 传入一个 action$ 再返回一个 action$, 内部是业务逻辑
const fetchUserEpic = action$ => action$.pipe(
  ofType(FETCH_USER), 
  mergeMap(action =>  
    ajax.getJSON(`https://api.github.com/users/${action.payload}`).pipe(
      map(response => fetchUserFulfilled(response)) // action 的 type 变成了 FETCH_USER_FULFILLED
    )
  )
);
const fetchUserFulfilledEpic = action$ =>
  action$
    .ofType(FETCH_USER_FULFILLED)                 
    .delay(2000)
    .mergeMap(({ payload: { msg } }) => showMessage(msg)) 

const rootEpic = combineEpics(fetchUserEpic, fetchUserFulfilledEpic)
dispatch(fetchUser('torvalds'));
```

&nbsp;

redux-observable 的响应式流还可分离关注点, 让使用者只需专注 epics 之间的业务逻辑而忽略掉 epics 之外的事情.

<img src="http://upic.paprikalang.site/rxjs.jpg" width="500"/>


&nbsp;

RxJS 项目在测试时, 也会将一些无关的外部逻辑隔离在 "epic" 函数外, 来提高业务代码的可测试性.

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
//处理业务逻辑的纯函数 : 传入一个 observable 再返回一个 observable, 内部处理业务逻辑
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

**Flutter** 设计出了框架层面上的业务逻辑组件 ---- Bloc ( Business Logic Component):

做为生产者的 sink 可以向 `Bloc` 内部监听它的 stream 传输数据; 再由另一个 stream (是不同 StreamController 创建的)将处理好的数据传给它的观察者 StreamBuilder 并同步更新这个部件.

<!--<img src="https://i.loli.net/2020/04/01/6X8aztKG75lojIi.jpg" width="500" />-->

<img src="http://upic.paprikaLang.site/rxjs-flutter.jpg" width="500" />

&nbsp;

&nbsp;

## 三   可预测的函数式 + 可分离的响应式

&nbsp;

<div style="display:flex; justify-content: flex-start;">
<img src="http://upic.paprikalang.site/rxjs.jpg" width="350"/>
<img src="http://cyclejs.cn/img/cycle-nested-frontpage.svg" width="350"/>
</div>	

&nbsp;

**Cycle.js** 更进一步, 它的整个应用程序就是一个业务逻辑组件(纯函数); 生产者和观察者合并成了应用程序的执行环境, 不同副作用的资源和底层指令封装在各自的 driver 函数中互不干扰, 并通过读写副作用的流与应用程序进行循环交互.

&nbsp;

```javascript
/*
    这里, 将前面关于 RxJS 测试的例子中的 dom effects 封装成一个 domDriver:
    观察者现在不仅要接收纯函数返回的 observable -- sinks , 
    还要返回本该由生产者交给纯函数的 observable -- sources . 
*/
function main(sources) {                
    const click$ = sources.DOM; 
    return {
      DOM: click$.startWith(null).map(() => 
	 xs.periodic(1000)  // xstream 可以简单理解为 Rx .
	 .fold(prev => prev+1, 0)
	).flatten()
	.map(i => `${i}`)
    };
}

function domDriver(text$) {             
  text$.subscribe({
    next: str => {
	const elem = document.querySelector('#count');
	elem.textContent = str;
    }
  })	
  /*
    以上是原观察者, 以下是原生产者. 
    原本分先后的串行结构变成了环形, 这样必然会引出一个问题: circle dependencies of stream.
  */
  const domsource = fromEvent(document, 'click'); 
  return domsource;
}

function run(main, domDriver) {
  /*
    用 xstream 的 imitate 解决上面提到的 circle dependencies of stream 问题
    const sinks = main({DOM: domsource});    // 纯函数需要 domDriver 提供的 sources
    const domsource = domDriver(sinks);      // domDriver 需要纯函数返回的 sinks
  */
  const fakeDOMSink = xs.create();
  const domsource = domDriver(fakeDOMSink);
  const sinks = main({DOM: domsource});
  fakeDOMSink.imitate(sinks.DOM);     
}
```

&nbsp;
  
> 在 Cycle.js 中，可以认为“操作系统”就是围绕应用的执行环境。大致来说，DOM、console、JavaScript 和 JS API 都扮演了 web 开发中操作系统的角色。我们需要软件适配器来与浏览器或者其他环境（例如 Node.js）进行交互。Cycle.js 的 driver 就是外界（包括用户以及 JavaScript 执行环境）与 Cycle.js 工具构建的应用世界之间的适配器.

&nbsp;

cyclejs 中不会出现没有返回值的 dispatch(action) ,  我们需要声明式地消化掉这个方法和它的副作用:

```javascript
const addReducer$ = actionA$.mapTo(function addReducer(state) { return state + 1; });
// 这一步在 driver 中进行, mergedReducer$ 和 state$ 要分别加入到 sinks 和 sources 中.
const state$ = mergedReducer$.scan((state, reducer) => reducer(state), initialState);
```

&nbsp;

同时, cyclejs 的状态管理模型维持了它的分形结构, 每层模型对应的组件、组件 state$ 对应的状态树节点都需要 isolate 方法剥离出来.

```javascript
const {state: reducer$} = isolate(Component, '节点')(sources); //节点对应的 reducer 再被上一层包裹起来.
```

> When state source crosses the isolation boundary from parent into child, we “peel off” the state object using the isolation scope. Then, when crossing the isolation boundary from child back to the parent, we “wrap” the reducer function using the isolation scope. This layered structure is called an “onion architecture” in other programming contexts(如: koa 中间件的洋葱模型).

&nbsp;

```javascript
import {run} from '@cycle/run';
import {div, label, input, hr, h1, makeDOMDriver} from '@cycle/dom';
import {withState} from '@cycle/state';
import isolate from '@cycle/isolate';

function main(sources) {
  const state$ = sources.state.stream; // state object emits { foo, bar, child: { count: 2 } } 
  const childSinks = isolate(Child, 'child')(sources);  
  const vdom$ = state$.map(state => /* render virtual DOM here */);
  ... ...
  const parentReducer$ = xs.merge(initReducer$, someOtherReducer$);
  const childReducer$ = childSinks.state; 
  const reducer$ = xs.merge(parentReducer$, childReducer$); 

  return {
    DOM: vdom$,
    state: reducer$,
  };
}

const wrappedMain = withState(main);

run(wrappedMain, {
  DOM: makeDOMDriver('#app')
});
```

&nbsp; 




