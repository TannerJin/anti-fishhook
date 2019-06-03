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
        
        // hook printf method
        fishhookPrint(newMethod: TestHelp.getNewPrintMehod())
        TestHelp.print(withStr: "printf Tanner") // print result
        
        protectPrint()
        TestHelp.print(withStr: "printf Jin\n") // print result
        
        
        // hook dladdr method
        fishhookDladdr(newMethod: TestHelp.getNewDladdrMethod())
        verificationDladdr() // print reslut

        protectDladdr()
        verificationDladdr() // print result
        
        return true
    }

}
