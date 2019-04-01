//
//  BaseTest.swift
//  Base
//
//  Created by jintao on 2019/3/31.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO
import BaseTest

// fishhook NSLog
public func fishhookNSLog() {
    let newMethod = TestHelp.getNewNSLogMehod()
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("NSLog", newMethod: newMethod, oldMethod: &oldMethod)
}

public func protectNSLog() {
    resetSymbol("NSLog")
}


// fishhook BaseTest Framework's dladdr
public func fishhookBaseTestDladdr(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
//    replaceSymbol("dladdr", newMethod: newMethod, oldMethod: &oldMethod)

    for i in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(i) {
            let imageName = String(cString: name)
            if imageName.contains("BaseTest"),
                let symbol = "dladdr".data(using: String.Encoding.utf8)?.map({$0}),
                let image = _dyld_get_image_header(i)
            {
                replaceSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
                break
            }
        }
    }
}

// protect BaseTest Framework's dladdr
public func protectBaseTestDladdr() {
//    resetSymbol("dladdr")
    
    for i in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(i) {
            let imageName = String(cString: name)
            if imageName.contains("BaseTest"),
                let symbol = "dladdr".data(using: String.Encoding.utf8)?.map({$0}),
                let image = _dyld_get_image_header(i)
            {
                resetSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
                break
            }
        }
    }
}

//public func dladdrVerification() {
//    if let testImp = class_getMethodImplementation(BaseTest.self, #selector(BaseTest.baseTest)) {
//        var info = Dl_info()
//        if dladdr(UnsafeRawPointer(testImp), &info) == -999 {
//            print("BaseTest dladdr--------- 被fishhook了")
//        } else if dladdr(UnsafeRawPointer(testImp), &info) == 1 {
//            print("BaseTest dladdr---------",  String(cString: info.dli_fname))
//        }
//    }
//}
//
//class BaseTest {
//    @objc func baseTest() {
//        print("baseTest")
//    }
//}
