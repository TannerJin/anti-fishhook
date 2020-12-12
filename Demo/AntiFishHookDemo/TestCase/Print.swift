//
//  Print.swift
//  AntiFishHookDemo
//
//  Created by jintao on 2020/12/12.
//  Copyright © 2020 jintao. All rights reserved.
//

import Foundation
import antiFishhook

func testPrint() {
    typealias MyPrint = @convention(thin) (Any..., String, String) ->Void
    func myPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        NSLog("I(print) have been fishhook 😂")
    }
    let myprint: MyPrint = myPrint
    let myPrintPointer = unsafeBitCast(myprint, to: UnsafeMutableRawPointer.self)
    var oldMethod: UnsafeMutableRawPointer?
    
    print("======> print_test:")
    // hook
    FishHook.replaceSymbol("$ss5print_9separator10terminatoryypd_S2StF", newMethod: myPrintPointer, oldMethod: &oldMethod)
    print("I(print) has not been hooked ???")
    
    // antiHook
    FishHookChecker.denyFishHook("$ss5print_9separator10terminatoryypd_S2StF")
    print("I(print) test success 🚀🚀🚀\n")
}
