//
//  Store.swift
//  TodoDemo
//
//  Created by paprika on 2017/9/22.
//  Copyright © 2017年 paprika. All rights reserved.
//

import Foundation
protocol ActionType {}
protocol StateType {}
protocol CommandType {}
/*
Store 接受一个 reducer 和一个初始状态 initialState 作为输入。它提供了 dispatch 方法，持有该 store 的类型可以通过 dispatch 向其发送 Action，store 将根据 reducer 提供的方式生成新的 state 和必要的 command，然后通知它的订阅者。
 */
class Store<A:ActionType,S:StateType,C:CommandType> {
    let reducer: (_ state:S,_ action:A) -> (S,C?)
    var subscriber: ((_ state:S,_ previousState:S,_ command:C?) -> Void)?
    var state: S
    //接受一个 reducer 和一个初始状态 initialState 作为输入
    init(reducer:@escaping (S,A)->(S,C?),initialState:S) {
        self.reducer = reducer
        self.state = initialState
    }
    
    func subscribe(_ handler: @escaping (S,S,C?) -> Void) {
        self.subscriber = handler
    }
    func unsubscribe(){
        
        self.subscriber = nil
    }
    //通过 dispatch 向store 发送 Action
    func dispatch(_ action:A){
        let previousState = state
        //返回元组,经过函数计算,action 作用于state 返回新的状态
        let (nextState,command) = reducer(state, action)
        state = nextState
        //订阅者获取新的状态
        subscriber?(state,previousState,command)
    }
}
