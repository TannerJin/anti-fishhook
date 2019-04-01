//
//  BaseTest.swift
//  BaseTest
//
//  Created by jintao on 2019/3/31.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO

public func fishhookBaseTestDladdr(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    
}

public func dladdrVerification() {
    if let testImp = class_getMethodImplementation(BaseTest.self, #selector(BaseTest.baseTest)) {
        var info = Dl_info()
        if dladdr(UnsafeRawPointer(testImp), &info) == -999 {
            print("BaseTest dladdr--------- 被fishhook了")
        } else if dladdr(UnsafeRawPointer(testImp), &info) == 1 {
            print("BaseTest dladdr---------",  String(cString: info.dli_fname))
        }
    }
}

class BaseTest {
    @objc func baseTest() {
        print("baseTest")
    }
}
