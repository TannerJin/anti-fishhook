//
//  AppDelegate.swift
//  AntiFishHookDemo
//
//  Created by jintao on 2019/7/3.
//  Copyright © 2019 jintao. All rights reserved.
//

import UIKit

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
        
        // MARK: - test abort method, will crash
//        testAbort()
        
        return true
    }

}
