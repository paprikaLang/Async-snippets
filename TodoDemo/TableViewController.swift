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

    enum Section:Int {
        case input = 0,todos,max
    }
    //数据源数组
    var todos : [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Todo-(0)"
        navigationItem.rightBarButtonItem?.isEnabled = false
        TodoModel.shared.getTodoItems { (array) in
            self.todos += array
            self.title = "Todo-\(self.todos.count)"
            self.tableView.reloadData()
        }
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return Section.max.rawValue
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else{
            fatalError()
        }
        switch section {
        case .input:  return 1
        case .todos:  return todos.count
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
            cell.textLabel?.text = todos[indexPath.row]
            return cell
        default:
            fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard indexPath.section == Section.todos.rawValue else {
            return
        }
        
       self.todos.remove(at: indexPath.row)
        title = "Todo-\(self.todos.count)"
        tableView.reloadData()
    }
    
    @IBAction func addTodoItem(_ sender: UIBarButtonItem) {
        
        let inputIndexPath = IndexPath(row: 0, section: Section.input.rawValue)
   
        guard let inputCell = tableView.cellForRow(at: inputIndexPath) as? TableViewInputCell,
        let text = inputCell.textfield.text
        else {
            return
        }
       todos.insert(text, at: 0)
        title = "Todo-\(todos.count)"
        tableView.reloadData()
        inputCell.textfield.text = ""
    }
    
}

extension TableViewController:TalbleViewInputCellDelegate{
    
    func inputValueChanged(cell: TableViewInputCell, text: String) {
        let isItemLenthEnough = text.count>3
        navigationItem.rightBarButtonItem?.isEnabled = isItemLenthEnough
    }
}
