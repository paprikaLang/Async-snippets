//
//  TodoModel.swift
//  TodoDemo
//
//  Created by paprika on 2017/9/21.
//  Copyright © 2017年 paprika. All rights reserved.
//

import Foundation
let array = [
"drink some milk",
"go biking",
"go swimming",
"go to work"
]
struct TodoModel {
    //模拟网络请求的单例
    static let shared = TodoModel()
    func getTodoItems(completionhandler:(([String])->Void)?){
        
        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            completionhandler?(array)
        }
        
    }
}
