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
    func testUpdateView(){
        let state1 = TableViewController.State(
            dataSource: TableViewDataSource(todos:[], owner: nil),
            text:""
        )
        //从nil状态转换为state1
        controller.stateDidChanged(state: state1, previousState: nil, command: nil)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: TableViewDataSource.Section.todos.rawValue), 0)
        XCTAssertFalse(controller.navigationItem.rightBarButtonItem!.isEnabled)
        
        let state2 = TableViewController.State(dataSource: TableViewDataSource(todos:["1","3"],owner:nil), text: "helloWorld")
        //从state1转换到state2
        controller.stateDidChanged(state: state2, previousState: state1, command: nil)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: TableViewDataSource.Section.todos.rawValue), 2)
        XCTAssertEqual(controller.tableView.cellForRow(at: todoItemIndexPath(row: 1))?.textLabel?.text, "3")
        XCTAssertTrue(controller.navigationItem.rightBarButtonItem!.isEnabled)
    
    }
    
    func testReducerUpdateTextFromEmpty(){
        let initState = TableViewController.State()
        let state = controller.reducer(initState, .updateText(text: "123")).state
        XCTAssertEqual(state.text, "123")
    }
   
    func testLoadTodos(){
        
        let initState = TableViewController.State()
        let(_,command) = controller.reducer(initState, .loadToDos)
        XCTAssertNotNil(command)
        switch command! {
        case .loadToDos(let handler):
            handler(["2","3"])
            XCTAssertEqual(controller.store.state.dataSource.todos, ["2","3"])
        default:
            XCTFail("The command should be .loadToDos")
        }
    }
}
func todoItemIndexPath(row: Int) -> IndexPath {
    return IndexPath(row: row, section: TableViewDataSource.Section.todos.rawValue)
}


