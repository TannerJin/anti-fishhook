//
//  InserDyldFishHook.swift
//  InsertDyld
//
//  Created by jintao on 2019/4/1.
//  Copyright © 2019 jintao. All rights reserved.
//

import Foundation
import MachO
import antiFishhook

// fishhook all image's printf
public func fishhookPrintf(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("printf", newMethod: newMethod, oldMethod: &oldMethod)
}

// fishhook AntiFishHookDemo's target symbol dladdr
public func fishhookDladdr(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("dladdr", newMethod: newMethod, oldMethod: &oldMethod)
}

// fishhook all image's Swift.Foudation.NSLog
public func fishhookSwiftFoudationNSLog(_ nslogSymbol: String, newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol(nslogSymbol, newMethod: newMethod, oldMethod: &oldMethod)
}
