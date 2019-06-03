//
//  AppDelegate.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

import UIKit
import InsertDyld
import MachO

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // printf method
        print("======> printf_test:")
        fishhookPrint(newMethod: TestHelp.getNewPrintMehod())
        TestHelp.print(withStr: "Hello World") // print result
        
        protectPrint()
        TestHelp.print(withStr: "Tanner Jin\n") // print result
        
        
        // dladdr method
        print("\n======> dladdr_test:")
        fishhookDladdr(newMethod: TestHelp.getNewDladdrMethod())
        verificationDladdr() // print reslut

        protectDladdr()
        verificationDladdr() // print result
        
        // dlopen method
        print("\n======> dlopen_test:")
        // during loading dyld, will call dlopen method. so wait dyld finish load(not thread safe),
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            fishhookDlopen(newMethod: TestHelp.getNewDlopenMethod())
            verificationDlopen()
            
            protectDlopen()
            verificationDlopen()
        }
        
        return true
    }

}

public func verificationDlopen() {
    let handle = dlopen("/usr/lib/libc.dylib", RTLD_NOW)

    if handle == nil {
        print("dlopen method had been fishhooked")
    } else {
        defer {
            dlclose(handle)
        }
        print("dlopen had been protecd")
    }
}

public func verificationDladdr() {
    if let testImp = class_getMethodImplementation(BaseTest.self, #selector(BaseTest.baseTest)) {
        var info = Dl_info()
        if dladdr(UnsafeRawPointer(testImp), &info) == -999 {
            print("dladdr method had been fishhooked")
        } else if dladdr(UnsafeRawPointer(testImp), &info) == 1 {
            print("dladdr fname---------",  String(cString: info.dli_fname))
        }
    }
}

class BaseTest {
    @objc func baseTest() {
        print("baseTest")
    }
}
