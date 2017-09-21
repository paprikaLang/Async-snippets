//
//  TodoDemoTests.swift
//  TodoDemoTests
//
//  Created by paprika on 2017/9/21.
//  Copyright © 2017年 paprika. All rights reserved.
//

import XCTest
@testable import TodoDemo

class TodoDemoTests: XCTestCase {
    
    var controller: TableViewController!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        controller = UIStoryboard(name: "Main", bundle: .main)
            .instantiateViewController(withIdentifier: "TableViewController") as! TableViewController
        _ = controller.view
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        controller = nil
        super.tearDown()
    }
    
    func testSettingState() {
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: TableViewController.Section.todos.rawValue), 0)
       
        XCTAssertFalse(controller.navigationItem.rightBarButtonItem!.isEnabled)
        
        controller.state = TableViewController.State(todos: ["1", "2", "3"], text: "abc")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: TableViewController.Section.todos.rawValue), 3)
        XCTAssertEqual(controller.tableView.cellForRow(at: todoItemIndexPath(row: 1))?.textLabel?.text, "2")
     
        XCTAssertTrue(controller.navigationItem.rightBarButtonItem!.isEnabled)
        
        controller.state = TableViewController.State(todos: [], text: "")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: TableViewController.Section.todos.rawValue), 0)
        
        XCTAssertFalse(controller.navigationItem.rightBarButtonItem!.isEnabled)
    }
    
    func testAdding() {
        let testItem = "Test Item"
        
        let originalTodos = controller.state.todos
        controller.state = TableViewController.State(todos: originalTodos, text: testItem)
        controller.addTodoItem(controller.navigationItem.rightBarButtonItem!)
        XCTAssertEqual(controller.state.todos, [testItem] + originalTodos)
        XCTAssertEqual(controller.state.text, "")
    }
    
    func testRemoving() {
        controller.state = TableViewController.State(todos: ["1", "2", "3"], text: "")
        controller.tableView(controller.tableView, didSelectRowAt: todoItemIndexPath(row: 1))
        XCTAssertEqual(controller.state.todos, ["1", "3"])
    }
    
    func testInputChanged() {
        controller.inputValueChanged(cell: TableViewInputCell(), text: "Hello")
        XCTAssertEqual(controller.state.text, "Hello")
    }
    
}


func todoItemIndexPath(row: Int) -> IndexPath {
    return IndexPath(row: row, section: TableViewController.Section.todos.rawValue)
}

