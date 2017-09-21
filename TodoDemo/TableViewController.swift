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

    override func viewDidLoad() {
        
        super.viewDidLoad()
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        let dataSource = TableViewDataSource(todos: [], owner: self)
      
        store = Store<Action,State,Command>(reducer: reducer, initialState: State(dataSource: dataSource, text: ""))
        // 订阅 store
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
    // 初始化 UI
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
        // 开始异步加载 ToDos
        store.dispatch(.removeToDo(index: indexPath.row))
    }
    
    @IBAction func addTodoItem(_ sender: UIBarButtonItem) {
        store.dispatch(.addToDos(items: [store.state.text]))
        store.dispatch(.updateText(text: ""))
    }
    
}

extension TableViewController:TalbleViewInputCellDelegate{
    
    func inputValueChanged(cell: TableViewInputCell, text: String) {
      store.dispatch(.updateText(text: text))
    }
}
