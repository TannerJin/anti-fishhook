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

+ (void)printWithStr:(NSString *)str {
    const char *str2 = [str UTF8String];
    printf("%s", str2);
}

+ (void *)getNewPrintMehod {
    return newPrintf;
}

+ (void *)getNewDladdrMethod {
    return newDladdr;
}

+ (void *)getNewDlopenMethod {
    return newDlopen;
}

// new printf method
void newPrintf(const char * str, ...) {
    NSLog(@"printf method had been fishhooked");
}

// new dladdr method
int newDladdr(void* imp, Dl_info* info) {
    return -999;
}

void * newDlopen(const char * path, int model) {
    return nil;
}

@end
