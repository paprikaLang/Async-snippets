//
//  TableViewInputCell.swift
//  TodoDemo
//
//  Created by paprika on 2017/9/21.
//  Copyright © 2017年 paprika. All rights reserved.
//

import UIKit

protocol TalbleViewInputCellDelegate :class{
    //代理方法的参数很固定:第一个是self本身,第二个是你要传的值
    func inputValueChanged(cell:TableViewInputCell,text:String)
}

class TableViewInputCell: UITableViewCell {

    //想用weak修饰delegate属于引用类型
    weak var delegate : TalbleViewInputCellDelegate?
    @IBOutlet weak var textfield: UITextField!
    
    // text field 的 .editingChanged 事件绑到 textFieldValueChanged 上
    @IBAction func textfieldValueChanged(_ sender: UITextField) {
      delegate?.inputValueChanged(cell: self, text: sender.text ?? "")
    }

}
