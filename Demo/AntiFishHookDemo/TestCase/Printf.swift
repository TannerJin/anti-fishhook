//
//  Printf.swift
//  FishHookProtect
//
//  Created by jintao on 2019/6/17.
//  Copyright © 2019 jintao. All rights reserved.
//

import InsertDyld
import Foundation
import antiFishhook

typealias NewPrintfMethod = @convention(thin) (String, Any...) -> Void

func newPrinf(str: String, arg: Any...) -> Void {
    print("I(printf) have been fishhook 😂")
}

func testPrintf() {
    print("======> printf_test:")

    let printf: NewPrintfMethod = newPrinf
    fishhookPrintf(newMethod: unsafeBitCast(printf, to: UnsafeMutableRawPointer.self))
    PrintfTestHelp.printf("Hello World")
    
    print("begin time=>: ", mach_absolute_time())
    FishHookChecker.denyFishHook("printf")
    print("end time=>:", mach_absolute_time())
    PrintfTestHelp.printf("Hello World🚀🚀🚀\n")
}


