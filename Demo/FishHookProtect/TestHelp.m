//
//  Test.m
//  FishHookProtect
//
//  Created by jintao on 2019/3/25.
//  Copyright © 2019 jintao. All rights reserved.
//

#import "TestHelp.h"
#include "dlfcn.h"

@implementation TestHelp

+ (void *)getNewNSLogMehod {
    return newNSLog;
}

+ (void *)getNewDladdrMethod {
    return newDladdr;
}

// new NSlog method
void newNSLog(NSString *format, ...) {    
    printf("NSLog --------- fishhook");
    printf("\n");
}

// new dladdr method
int newDladdr(void* imp, Dl_info* info) {
    return -999;
}

@end
