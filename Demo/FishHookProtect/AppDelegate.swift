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
        testPrintf()

        // MARK: - dladdr method
        testDladdr()
        
        // MARK: - Swift Foudation.NSLog method
        testSwiftNSLog()
        
        // MARK: - dlopen method
        testDlopen()
        
        return true
    }

}
