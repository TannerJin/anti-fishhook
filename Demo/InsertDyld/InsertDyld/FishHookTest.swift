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
    for i in 0..<_dyld_image_count() {
        if let name = _dyld_get_image_name(i) {
            let imageName = String(cString: name)
            if imageName.contains("AntiFishHookDemo"),
                let image = _dyld_get_image_header(i) {
                replaceSymbol("dladdr", image: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
                break
            }
        }
    }
}

// fishhook all image's dlopen
public func fishhookDlopen(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol("dlopen", newMethod: newMethod, oldMethod: &oldMethod)
}

// fishhook all image's Swift.Foudation.NSLog
public func fishhookSwiftFoudationNSLog(_ nslogSymbol: String, newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    replaceSymbol(nslogSymbol, newMethod: newMethod, oldMethod: &oldMethod)
}
