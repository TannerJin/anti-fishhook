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
import antiFishhook

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // MARK: -  printf method
        print("======> printf_test:")
        fishhookPrint(newMethod: TestHelp.getNewPrintMehod())
        TestHelp.print(withStr: "Hello World")

        resetSymbol("printf")
        TestHelp.print(withStr: "Hello World\n") //

        
        // MARK: - dladdr method
        print("\n======> dladdr_test:")
        fishhookDladdr(newMethod: TestHelp.getNewDladdrMethod())
        verificationDladdr() // print reslut

        func resetDladdrSymbol() {
            for i in 0..<_dyld_image_count() {
                if let name = _dyld_get_image_name(i) {
                    let imageName = String(cString: name)
                    if imageName.contains("FishHookProtect"),
                        let symbol = "dladdr".data(using: String.Encoding.utf8)?.map({$0}),
                        let image = _dyld_get_image_header(i)
                    {
                        resetSymbol(symbol, image: image, imageSlide: _dyld_get_image_vmaddr_slide(i))
                        break
                    }
                }
            }
        }
        resetDladdrSymbol()
        verificationDladdr()

        
        // MARK: - Swift Foudation.NSLog method
        print("\n======> Swift_Foudation.NSLog test:")
        fishhookSwiftFoudationNSLog(newMethod: TestHelp.getNewSwiftFoundationNSLog())
        NSLog("Swift symbol test")
        resetSymbol("$s10Foundation5NSLogyySS_s7CVarArg_pdtF") // original: _$s10Foundation5NSLogyySS_s7CVarArg_pdtF
        NSLog("Swift symbol test")
        
        
        // MARK: - dlopen method
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // during loading dyld, will call dlopen method. so wait dyld finish load(not thread safe),
            print("\n======> dlopen_test:")
            fishhookDlopen(newMethod: TestHelp.getNewDlopenMethod())
            verificationDlopen()
            
            resetSymbol("dlopen")
            verificationDlopen()
        }
        
        return true
    }

}

// MARK: - Verification Helper

private func verificationDlopen() {
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

private func verificationDladdr() {
    class BaseTest {
        @objc func baseTest() {
            print("baseTest")
        }
    }
    
    if let testImp = class_getMethodImplementation(BaseTest.self, #selector(BaseTest.baseTest)) {
        var info = Dl_info()
        if dladdr(UnsafeRawPointer(testImp), &info) == -999 {
            print("dladdr method had been fishhooked")
        } else if dladdr(UnsafeRawPointer(testImp), &info) == 1 {
            print("dladdr method path: ",  String(cString: info.dli_fname))
        }
    }
}
