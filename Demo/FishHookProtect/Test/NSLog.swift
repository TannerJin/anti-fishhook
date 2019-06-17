//
//  NSLog.swift
//  FishHookProtect
//
//  Created by jintao on 2019/6/17.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import antiFishhook
import InsertDyld

typealias NewSwiftNSLog = @convention(thin) (_ format: String, _ args: CVarArg...) -> Void

func newNSLog(_ format: String, _ args: CVarArg...) {
    print("I(swift_nslog) have been fishhook 😂")
}

func testSwiftNSLog() {
    print("\n======> Swift_Foudation.NSLog test:")
    
    let nslogSymbol = "$s10Foundation5NSLogyySS_s7CVarArg_pdtF"
    let nslog: NewSwiftNSLog = newNSLog
    
    fishhookSwiftFoudationNSLog(nslogSymbol, newMethod: unsafeBitCast(nslog, to: UnsafeMutableRawPointer.self))
    NSLog("Swift NSLog test")
    
    resetSymbol(nslogSymbol) // original: _$s10Foundation5NSLogyySS_s7CVarArg_pdtF
    NSLog("Swift NSLog test success🚀🚀🚀")
}
