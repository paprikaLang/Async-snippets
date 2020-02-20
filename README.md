
&nbsp; 

## 一   可预测的函数式

&nbsp; 

这是一个在移动端按照 redux 的状态管理模式构建出来的[[单向数据流动的函数式 View Controller]]( https://onevcat.com/2017/07/state-based-viewcontroller/). 

<img src="https://onevcat.com/assets/images/2017/view-controller-states.svg" width="600"/>

```swift
// 图中的 Store 可以对照着 redux 的 createStore 来看
class Store<A: ActionType, S: StateType, C: CommandType> {
    // CommandType 是对副作用的抽象化, 同时将 action 从副作用中解脱出来.
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
	 只有订阅了 nextState 的 subscriber 是负责更新 UI 的;
         订阅了 command 的 subscriber 可以触发副作用, 这和 redux 用 action creator 来隔离副作用不同.
	 比如一个异步请求完成后, command 的闭包会接收请求返回的数据做为 action 的 payload , 再 dispatch 给 reducer;         
        */
        subscriber?(state, previousState, command)
    }
}
```

`Command` 隔离副作用保证了 `reducer` 函数的纯粹, 这是数据可回溯、可预测的关键.  

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

redux 另一种隔离副作用的方法是 `中间件`, createStore 的第三个参数 `applyMiddleware` 可以重写 dispatch , 使得 action 在进入 dispatch 之前要先经过中间件的处理.


<img src="https://user-gold-cdn.xitu.io/2018/12/16/167b79c4d7931231?imageView2/0/w/1280/h/960/ignore-error/1" width="600"/>

```javascript
// 中间件要先校验 action , 符合条件的处理后要再 dispatch 出去一个 action ; 而校验未通过的 action 会传给下一个中间件.
// 根据这个原理先自定义两个中间件出来.
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

// applyMiddleware 要把中间件像这样垒起来.
const reduxThunk = ({ dispatch, getState }) => next => action => {
  // reduxThunk 的校验和处理动作
  ... ...
  return action => {
    // 下游 reduxArray 的校验和处理动作
    ... ...
    return next1(action) // reduxArray的返回值, 还可以继续向下游展开直到 dispatch 的 action => {}. 
  }
}

// 中间件 reduxThunk 的返回值从结构上看是 reduxThunk 的参数, 从内容上看则是 reduxArray(next1) 的返回值.
// reduxThunk(reduxArray(...)) 可用 reduce 实现.
export function compose(...fns) {
  if (fns.length === 0) return arg => arg
  if (fns.length === 1) return fns[0]
  // 数组 fns 就是 middlewares:[ next => action=> { } ], args 是 dispatch
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

可以说中间件就是 ` 判断语句 + 处理副作用的 action creator ` , 而中间件 `redux-observable` 借助了 RxJS 强大的异步和转换能力在这两个要素上都有着极其灵活的可操作性. 

```javascript
const fetchUser = username => ({ type: FETCH_USER, payload: username });
const fetchUserFulfilled = payload => ({ type: FETCH_USER_FULFILLED, payload });
/*
  先要把 action 看做是时间维度上的集合 action$ ,
  redux-observable 的核心 ---- epic 函数会接收这个 action$ , 经过它的业务逻辑处理, 最后再返回一个 action$.
*/ 
const fetchUserEpic = action$ => action$.pipe(
  ofType(FETCH_USER), //  判断语句
  mergeMap(action =>  //  处理副作用的 action creator
    ajax.getJSON(`https://api.github.com/users/${action.payload}`).pipe(
      map(response => fetchUserFulfilled(response))
    )
  )
);
/*
  如果 action$ 能传入 reducer 中, 那就相当于以流的形式实现了刚刚 applyMiddleware 构建的 action 管道, 即:
  epic(action$, state$).scan(reducer).do(state => getState());
  实际操作上, 我们可以设计一个接收 action$ 的 Store, 即:
  epic(action$, state$).subscribe(reactiveStore.dispatch) + createReactiveStore { $action.scan(reducer) }
*/
dispatch(fetchUser('torvalds'));
```

```javascript
const createReactiveStore = (reducer, initialState) => {
  const action$ = new Subject();
  let currentState = initialState;
  /*
   state 也是一个受 action 作用而不断累计的变量，scan 可以向下游传递 state 的每个累计值;
   操作符 reduce 与 scan 唯一的区别是: reduce 只会传递一个最终的累计值, 它的上游必须是有限的数据.
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

redux-observable 的响应式流成功分离了使用者的关注点, 所以你可以不必知晓 action$ 的来龙去脉而只专注中间件的业务逻辑.

RxJS 项目在测试时也会这样将一些无关的外部逻辑隔离在 "epic" 函数之外, 来提高业务代码的可测试性.

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
//处理业务逻辑的纯函数 : 传入一个 observable 再返回一个observable, 内部处理业务逻辑
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

**Flutter** 依照上面响应式的 `生产者 -- 纯函数 -- 观察者` 模型, 打造出了自己的业务逻辑组件 ---- Bloc ( Business Logic Component). 

图中做为生产者的 sink 可以向 `Bloc` 内部监听它的 stream[1] 传输数据; 再由另一个 stream (因为是不同 StreamController 创建的)将处理好的数据传给它的观察者 StreamBuilder 并同步更新这个部件.

<img src="https://upload-images.jianshu.io/upload_images/4044518-e2efb6e9dc3c1dbe.png?imageMogr2/auto-orient/strip|imageView2/2/w/561" width="500" />


&nbsp;

&nbsp;

## 三   可预测的函数式 + 可分离的响应式

&nbsp;

<div style="display:flex; justify-content: flex-start;">
<img src="http://img.wwery.com/tourist/a13320109095059.jpg" width="350"/>
<img src="http://cyclejs.cn/img/cycle-nested-frontpage.svg" width="350"/>
</div>	

&nbsp;

**Cycle.js[2]** 将生产者和观察者合并成了一个围绕应用的执行环境, 并与做为应用程序的纯函数进行循环交互.

&nbsp;

```javascript
/*
    为了还原 cyclejs 的大致原理, 将前面关于RxJS测试的例子改造一下: 
    先前的观察者做好本职的同时还要负责返回本该生产者交给纯函数的 observable,
    这样就相当于将生产者和观察者首尾相连封装在了一个函数里, 而这个函数也可以作为执行环境与纯函数循环交互了.
*/
function main(sources) {     // 纯函数
	const click$ = sources.DOM;
	return {
	     DOM: click$.startWith(null).map(() => 
                 xs.periodic(1000)  // xstream 可以简单理解为 Rx 的 observable.
                 .fold(prev => prev+1, 0)
		).flatten()
		.map(i => `Seconds elapased: ${i}`)
	};
}

function domDriver(text$) {  // 封装了生产者与观察者的执行环境
    // 如果纯函数传过来的{ DOM: text$ }能包含简单的 vdom 数据, 就可以解决这里的硬编码问题;
    // 或者我们自己实现 hyperscript helper functions, 比如: @cycle/react-native, 并把 domDriver 变成一个插件
	text$.subscribe({
		next: str => {
			const elem = document.querySelector('#count');
			elem.textContent = str;
		}
	})
	// 以上是原观察者, 以下是原生产者.
	const domsource = fromEvent(document, 'click'); // xstream 的 事件源.
	return domsource;
}
/*
domDriver 这样改动后会引出一个 circle dependencies of stream 问题, 需要 xstream 的 imitate 来解决掉它:
    const sinks = main({DOM: domsource});    // 纯函数需要 domDriver 提供的 sources
    const domsource = domDriver(sinks);      // domDriver 需要纯函数返回的 sinks
*/
function run(main, domDriver) {
	const fakeDOMSink = xs.create();
	const domsource = domDriver(fakeDOMSink);
	const sinks = main({DOM: domsource});
	// xstream 的 imitate 解决了循环依赖的问题.
	fakeDOMSink.imitate(sinks.DOM);
}
```

&nbsp;

> 在 Cycle.js 中，可以认为“操作系统”就是围绕应用的执行环境。大致来说，DOM、console、JavaScript 和 JS API 都扮演了 web 开发中操作系统的角色。我们需要软件适配器来与浏览器或者其他环境（例如 Node.js）进行交互。Cycle.js 的 driver 就是外界（包括用户以及 JavaScript 执行环境）与 Cycle.js 工具构建的应用世界之间的适配器.

&nbsp;

```javascript
import {run} from '@cycle/run';
import {div, label, input, hr, h1, makeDOMDriver} from '@cycle/dom';
import {withState} from '@cycle/state';
// cyclejs 将 state$ 做为 sources , 将 reducer$ 做为 sinks , 实现了可预测、可分离的状态管理.
function main(sources) {
  const state$ = sources.state.stream;
  const vdom$ = state$.map(state => /* render virtual DOM here */);

  const initialReducer$ = xs.of(function initialReducer() { return 0; });
  const addOneReducer$ = xs.periodic(1000)
    .mapTo(function addOneReducer(prev) { return prev + 1; });
  const reducer$ = xs.merge(initialReducer$, addOneReducer$);

  return {
    DOM: vdom$,
    state: reducer$,
  };
}
const wrappedMain = withState(main);

run(wrappedMain, {
  DOM: makeDOMDriver('#app'),
});
```

&nbsp; 

&nbsp; 

&nbsp; 

[1]  Stream 具备 observable 的迭代器模式和观察者模式. 结合了观察者模式的迭代器模式不再需要**拉取**数据的接口(getCurrent, moveToNext, isDone)来遍历各种复杂的数据集合. 因为订阅了 publisher 之后, 无论数据怎样产生, 同步还是异步, 都会自动**推送**给 observer .


[2] cyclejs 的文档和教程都做的很好, 无需再提炼出我的想法, 所以一些文字和代码就直接腾挪了来.



