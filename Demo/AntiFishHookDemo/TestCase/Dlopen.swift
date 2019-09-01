//
//  Dlopen.swift
//  FishHookProtect
//
//  Created by jintao on 2019/6/17.
//  Copyright © 2019 jintao. All rights reserved.
//

import InsertDyld
import Foundation
import antiFishhook

typealias NewDlopen = @convention(thin) (_ path: UnsafePointer<Int8>?, _ mode: Int32) -> UnsafeMutableRawPointer?

func newDlopen(_ path: UnsafePointer<Int8>!, _ mode: Int32) -> UnsafeMutableRawPointer? {
    return nil
}

func testDlopen() {
    // during loading dyld, will call dlopen method. so wait dyld finish load(not thread safe),
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        print("\n======> dlopen_test:")
        
        let dlopen: NewDlopen = newDlopen
        
        fishhookDlopen(newMethod: unsafeBitCast(dlopen, to: UnsafeMutableRawPointer.self))
        verificationDlopen()
        
        resetSymbol("dlopen")
        verificationDlopen()
    }
}

private func verificationDlopen() {
    let handle = dlopen("/usr/lib/libc.dylib", RTLD_NOW)
    defer {
        dlclose(handle)
    }
    
    if handle == nil {
        print("I(dlopen) have been fishhook 😂")
    } else {
        print("dlopen test success🚀🚀🚀")
    }
}
