//
//  TableViewController.swift
//  TodoDemo
//
//  Created by paprika on 2017/9/21.
//  Copyright © 2017年 paprika. All rights reserved.
//

import UIKit

let inputCellReuseId = "inputCellId"
let todoCellReuseId = "todoCellId"

class TableViewController: UITableViewController{
    public typealias CancelableTask = (_ cancel: Bool) -> Void
    public func delay(time: TimeInterval, work: @escaping ()->()) -> CancelableTask? {
        var finalTask: CancelableTask?
        let cancelableTask: CancelableTask = { cancel in
            if cancel {
                finalTask = nil
                
            } else {
                //执行原函数
                DispatchQueue.main.async(execute: work)
            }
        }
        finalTask = cancelableTask
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            if let task = finalTask {
                task(false)
            }
        }
        return finalTask
    }
    struct State:StateType {
        var dataSource = TableViewDataSource(todos: [], owner: nil)
        var text : String = ""
    }
    
    enum Action:ActionType {
        case updateText(text:String)
        case addToDos(items:[String])
        case removeToDo(index:Int)
        case loadToDos
    }
    
    enum Command:CommandType{
        
        case loadToDos(completion:([String])->Void)
        case someOtherCommand
        
    }

    lazy var reducer:(State, Action) -> (state: State , command: Command?) = {
        [weak self] (state : State, action : Action) in

        var state = state
        var command :Command? = nil
        //将用户操作抽象为action,并将所有的状态更新集中处理了
        switch action {
        case .updateText(let text):
            state.text = text
        case .addToDos(let items):
            state.dataSource = TableViewDataSource(todos: items + state.dataSource.todos, owner: state.dataSource.owner)
        case .removeToDo(let index):
            let oldTodos = state.dataSource.todos
            state.dataSource = TableViewDataSource(todos: Array(oldTodos[..<index]+oldTodos[(index + 1)...]), owner: state.dataSource.owner)
        case .loadToDos:
            //加载TodoModel的数据源
            command = Command.loadToDos{self?.store.dispatch(.addToDos(items: $0))}
        }
        return(state,command)
    }

    var store: Store<Action,State,Command>!
    
    var cancelTask: CancelableTask?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.cancelTask =  delay(time:6) {
            print("-------------cancel-------------")
        }

        navigationItem.rightBarButtonItem?.isEnabled = false
        //此时DataSource为nil
        let dataSource = TableViewDataSource(todos: [], owner: self)
        //store中存储了reducer的变化,还有订阅reducer的方法subscribe,否则没法得知数据的变化,所以这里要订阅store,实际是订阅reducer,为了监听数据的更改.
        store = Store<Action,State,Command>(reducer: reducer, initialState: State(dataSource: dataSource, text: ""))
        // 订阅 store,为了拿到新旧状态在比较中(如果更新数据)相应地去改变View
        store.subscribe { [weak self]state, previousState, command in
            //每次dispatch得到新的状态都会通知订阅者,订阅者内部调用statedidchanged方法
            self?.stateDidChanged(state: state, previousState: previousState, command: command)
        }
        stateDidChanged(state: store.state, previousState: nil, command: nil)
        store.dispatch(.loadToDos)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.dismiss(animated: true, completion: nil)
        }
    }
    // 改变 UI
    func stateDidChanged(state:State,previousState:State?,command:Command?) {
        if let command = command {
            switch command{
            case .loadToDos(let handler):
                TodoModel.shared.getTodoItems(completionhandler:handler)
            case .someOtherCommand:
                //placeHolder command.
                break
            }
        }
        if previousState == nil || previousState!.dataSource.todos != state.dataSource.todos {
            let dataSource = state.dataSource
            tableView.dataSource = dataSource
            tableView.reloadData()
        }
        if previousState == nil || previousState!.text != state.text {
            let isItemLengthEnough = state.text.count >= 3
            navigationItem.rightBarButtonItem?.isEnabled = isItemLengthEnough
            
            let inputIndexPath = IndexPath(row: 0, section: TableViewDataSource.Section.input.rawValue)
       
            let inputCell = tableView.cellForRow(at: inputIndexPath) as? TableViewInputCell
            inputCell?.textfield.text = state.text
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == TableViewDataSource.Section.todos.rawValue else {
            return
        }
        //1.用户操作导致state改变(传给dispatch action 返回新的state)
        //2.订阅者订阅前后的状态变化,并在内部调用statedidchange方法.
        //3.在statedidchange里对比前后state的变化更改View
        store.dispatch(.removeToDo(index: indexPath.row))
    }
    
    @IBAction func addTodoItem(_ sender: UIBarButtonItem) {
        store.dispatch(.addToDos(items: [store.state.text]))
        store.dispatch(.updateText(text: ""))
        self.cancelTask!(false)
    }
    
}

extension TableViewController:TalbleViewInputCellDelegate{
    
    func inputValueChanged(cell: TableViewInputCell, text: String) {
      store.dispatch(.updateText(text: text))
    }
}
