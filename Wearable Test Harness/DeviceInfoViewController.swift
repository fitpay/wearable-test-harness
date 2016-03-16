//
//  DeviceInfoViewController.swift
//  Wearable Test Harness
//
//  Created by Tim Shanahan on 3/15/16.
//  Copyright © 2016 Scott Stevelinck. All rights reserved.
//

import Cocoa
import CoreBluetooth
import SecurityFoundation


class DeviceInfoViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    
    @IBOutlet weak var tableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("DeviceInfoViewController loaded")
        tableView.setDataSource(self)
        tableView.setDelegate(self)
        
    }
    
    let myarray = ["item1", "item2", "item3"]
    
    override func viewDidAppear() {
        super.viewDidAppear()
        debugPrint("DeviceInfoViewController view did appear")
        tableView.reloadData();
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        debugPrint("numberOfRowsInTableView called")
        return myarray.count
    }
    
    func tableView(tableView: NSTableView,
        viewForTableColumn tableColumn: NSTableColumn?,
        row row: Int) -> NSView? {
            debugPrint("view for table column: \(tableColumn), row: \(row)")
            return nil
    }
    

}
