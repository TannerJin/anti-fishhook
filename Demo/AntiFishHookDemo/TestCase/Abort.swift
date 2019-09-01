//
//  Abort.swift
//  AntiFishHookDemo
//
//  Created by jintao on 2019/8/30.
//  Copyright © 2019 jintao. All rights reserved.
//

import antiFishhook
import Foundation

func testAbort() {
    typealias Method = @convention(thin) ()->()
    let newMethod: Method = {
        print("======> abort_fishhook success:")
        resetSymbol("abort")
        print("======> abort_antiFishhook test:")
        abort() // if crash, abort antiFishhook success
    }
    
    var oldMethod: UnsafeMutableRawPointer?
    
    print("\n======> abort_test:")
    replaceSymbol("abort", newMethod: unsafeBitCast(newMethod, to: UnsafeMutableRawPointer.self), oldMethod: &oldMethod)
    abort()
}
