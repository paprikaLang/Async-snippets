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
    
  
}


