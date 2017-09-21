//
//  TableViewDataSource.swift
//  TodoDemo
//
//  Created by paprika on 2017/9/22.
//  Copyright © 2017年 paprika. All rights reserved.
//

import UIKit

class TableViewDataSource: NSObject ,UITableViewDataSource{
    enum Section: Int {
        case input = 0, todos, max
    }
    
    var todos: [String]
    weak var owner: TableViewController?
    
    init(todos: [String], owner: TableViewController?) {
        self.todos = todos
        self.owner = owner
    }
    
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return Section.max.rawValue
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else{
            fatalError()
        }
        switch section {
        case .input:  return 1
        case .todos:  return todos.count
        case .max:    fatalError()
        }
    }
    
     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section =  Section(rawValue: indexPath.section) else {
            fatalError()
        }
        switch section {
        case .input:
            let cell = tableView.dequeueReusableCell(withIdentifier: inputCellReuseId, for: indexPath ) as! TableViewInputCell
            cell.delegate = owner
            return cell
        case .todos:
            let cell = tableView.dequeueReusableCell(withIdentifier: todoCellReuseId, for: indexPath)
            cell.textLabel?.text = todos[indexPath.row]
            return cell
        default:
            fatalError()
        }
    }

}
