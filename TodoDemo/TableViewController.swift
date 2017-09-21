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
    //和UI相关的model进行简单的封装,统一按照状态更新UI
    struct State {
        let todos :[String]
        let text : String
    }

    var state  = State(todos: [], text: ""){
        didSet{
            if oldValue.todos != state.todos {
            //在didSet方法里含有oldValue属性,前后不一致就更新tableVIew
                tableView.reloadData()
                 title = "Todo - (\(state.todos.count))"
            }
            if oldValue.text != state.text {
                let isItemLengthEnough = state.text.count >= 3
                navigationItem.rightBarButtonItem?.isEnabled = isItemLengthEnough
                
                let inputIndexPath = IndexPath(row: 0, section: Section.input.rawValue)
                let inputCell = tableView.cellForRow(at: inputIndexPath) as? TableViewInputCell
                inputCell?.textfield.text = state.text
            }
        }
    }
    enum Section:Int {
        case input = 0,todos,max
    }
    //数据源数组
    //var todos : [String] = []
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        navigationItem.rightBarButtonItem?.isEnabled = false
        TodoModel.shared.getTodoItems { (array) in
            //调用self.state同时didSet会调用
            self.state = State(todos: array + self.state.todos, text: self.state.text)
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
      
        return Section.max.rawValue
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else{
            fatalError()
        }
        switch section {
        case .input:  return 1
        case .todos:  return state.todos.count
        case .max:    fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section =  Section(rawValue: indexPath.section) else {
             fatalError()
        }
        switch section {
        case .input:
            let cell = tableView.dequeueReusableCell(withIdentifier: inputCellReuseId, for: indexPath ) as! TableViewInputCell
            cell.delegate = self
            return cell
        case .todos:
            let cell = tableView.dequeueReusableCell(withIdentifier: todoCellReuseId, for: indexPath)
            cell.textLabel?.text = state.todos[indexPath.row]
            return cell
        default:
            fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard indexPath.section == Section.todos.rawValue else {
            return
        }
        //抛出点击的cell重新组建数组
        let newTodos = Array(state.todos[..<indexPath.row]+state.todos[(indexPath.row+1)...])
        state = State(todos: newTodos, text: state.text)
    }
    
    @IBAction func addTodoItem(_ sender: UIBarButtonItem) {
        
      state = State(todos: [state.text] + state.todos, text: "")
    }
    
}

extension TableViewController:TalbleViewInputCellDelegate{
    
    func inputValueChanged(cell: TableViewInputCell, text: String) {
       state = State(todos: state.todos, text: text)
    }
}
