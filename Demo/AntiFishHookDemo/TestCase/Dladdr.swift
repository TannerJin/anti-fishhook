//
//  Dladdr.swift
//  FishHookProtect
//
//  Created by jintao on 2019/6/17.
//  Copyright © 2019 jintao. All rights reserved.
//

import MachO
import InsertDyld
import Foundation
import antiFishhook

typealias NewDladdrMethod = @convention(thin) (UnsafeRawPointer, UnsafeMutablePointer<Dl_info>) -> Int32

func newDladdr(a: UnsafeRawPointer, b:  UnsafeMutablePointer<Dl_info>) -> Int32 {
    return -999
}

func testDladdr() {
    print("\n======> dladdr_test:")
    
    let myDladdr: NewDladdrMethod = newDladdr
    fishhookDladdr(newMethod: unsafeBitCast(myDladdr, to: UnsafeMutableRawPointer.self))
    verifyDladdr()
    
    FishHookChecker.denyFishHook("dladdr")
    verifyDladdr()
}

private func verifyDladdr() {
    class BaseTest {
        @objc func baseTest() {
            print("baseTest")
        }
    }
    
    if let testImp = class_getMethodImplementation(BaseTest.self, #selector(BaseTest.baseTest)) {
        var info = Dl_info()
        if dladdr(UnsafeRawPointer(testImp), &info) == -999 {
            print("I(dladdr) have been fishhook 😂")
        } else if dladdr(UnsafeRawPointer(testImp), &info) == 1 {
            print("dladdr method path: ",  String(cString: info.dli_fname), "🚀🚀🚀")
        }
    }
}
