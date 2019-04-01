//
//  AppDelegate.swift
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

import UIKit
import InsertDyld

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("origation: ")
        // origation
        TestHelp.nslog("origation: Hello, World")
        verificationDyld()
        
        // fishhook
        fishhookNSLog(newMethod: TestHelp.getNewNSLogMehod())
        fishhookDladdr(newMethod: TestHelp.getNewDladdrMethod())
        
        print("\nverifiacate fishhook: ")
        // verifiacate fishhook
        TestHelp.nslog("verifiacate fishhook: Hello, World")
        verificationDyld()
        
        // fishhook protect
        protectNSLog()
        protectDladdr()
        
        print("\nverifiacate fishhook protect: ")
        // verifiacate fishhook protect
        TestHelp.nslog("verifiacate fishhook protect: Hello, World")
        verificationDyld()
        
        return true
    }

}

