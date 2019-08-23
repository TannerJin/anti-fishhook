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
//    if let name = swift_demangle("_" + nslogSymbol) {
//        print("_$s10Foundation5NSLogyySS_s7CVarArg_pdtF Demangle Name :", name, "\n")
//    }
    let nslog: NewSwiftNSLog = newNSLog
    
    fishhookSwiftFoudationNSLog(nslogSymbol, newMethod: unsafeBitCast(nslog, to: UnsafeMutableRawPointer.self))
    NSLog("Swift NSLog test。。。")
    
    resetSymbol(nslogSymbol) // original: _$s10Foundation5NSLogyySS_s7CVarArg_pdtF
    NSLog("Swift NSLog test success🚀🚀🚀")
}

public func swift_demangle(_ mangledName: String) -> String? {
    let cname = mangledName.withCString({ $0 })
    if let demangledName = get_swift_demangle(mangledName: cname, mangledNameLength: UInt(mangledName.utf8.count), outputBuffer: nil, outputBufferSize: nil, flags: 0) {
        return String(cString: demangledName)
    }
    return nil
}

// Swift/Swift libraries/SwiftDemangling/Header Files/Demangle.h
@_silgen_name("swift_demangle")
private func get_swift_demangle(mangledName: UnsafePointer<CChar>?,
                                mangledNameLength: UInt,
                                outputBuffer: UnsafeMutablePointer<UInt8>?,
                                outputBufferSize: UnsafeMutablePointer<Int>?,
                                flags: UInt32
                                ) -> UnsafeMutablePointer<CChar>?
