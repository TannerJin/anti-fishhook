//
//  Dlopen.swift
//  FishHookProtect
//
//  Created by jintao on 2019/6/17.
//  Copyright © 2019 jintao. All rights reserved.
//

import MachO
import Foundation
import antiFishhook

typealias NewDlopen = @convention(thin) (_ path: UnsafePointer<Int8>?, _ mode: Int32) -> UnsafeMutableRawPointer?

func newDlopen(_ path: UnsafePointer<Int8>!, _ mode: Int32) -> UnsafeMutableRawPointer? {
    return nil
}

func testDlopen() {
    print("\n======> dlopen_test:")
    
    let myDlopen: NewDlopen = newDlopen
    fishhookDlopen(newMethod: unsafeBitCast(myDlopen, to: UnsafeMutableRawPointer.self))
    verifyDlopen()
    
    resetDlopen()
    verifyDlopen()
}

private func verifyDlopen() {
    let handle = dlopen("/usr/lib/libc.dylib", RTLD_NOW)

    if handle == nil {
        print("I(dlopen) have been fishhook 😂")
    } else {
        print("dlopen test success🚀🚀🚀")
    }
}

private func fishhookDlopen(newMethod: UnsafeMutableRawPointer) {
    var oldMethod: UnsafeMutableRawPointer?
    FishHook.replaceSymbol("dlopen", newMethod: newMethod, oldMethod: &oldMethod)
    
    for i in 0..<_dyld_image_count() {
        if let cName = _dyld_get_image_name(i), String(cString: cName).contains("AntiFishHookDemo"), let image = _dyld_get_image_header(i) {

            FishHook.replaceSymbol("dlopen", at: image, imageSlide: _dyld_get_image_vmaddr_slide(i), newMethod: newMethod, oldMethod: &oldMethod)
            break
        }
    }
}

private func resetDlopen() {
    for i in 0..<_dyld_image_count() {
        if let cName = _dyld_get_image_name(i), String(cString: cName).contains("AntiFishHookDemo"), let image = _dyld_get_image_header(i) {

            FishHookChecker.denyFishHook("dlopen", at: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
            break
        }
    }
}
