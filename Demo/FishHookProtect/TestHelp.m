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

+ (void )nslog: (NSString *)str {
    NSLog(@"%@", str);
}

// hook NSlog的方法
void newNSLog(NSString *format, ...) {    
    printf("FishHookProtect NSLog--------- 被fishhook了");
    printf("\n");
}

// hook Dladdr方法
int newDladdr(void* imp, Dl_info* info) {
    return -999;
}

@end
