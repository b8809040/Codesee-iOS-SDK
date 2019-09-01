//
//  CodeseeDB.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/1/4.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeDB.h"
#import <sqlite3.h>

@interface CodeseeDB()
{
    sqlite3* sqlite3_db;
}
@end

@implementation CodeseeDB

- (BOOL) open: (NSString *) dbFile
{
    if(sqlite3_open(dbFile.UTF8String , &self->sqlite3_db) != SQLITE_OK) {
        NSLog(@"sqlite3_open fail");
        return NO;
    }
    return YES;
}

- (void) log: (NSString *) file Action: (CodeseeDBAction) action
{
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO journal VALUES ('%@', (SELECT datetime('now', 'localtime')), '%d')", file, action];

    char *errMsg;
    sqlite3_exec(self->sqlite3_db, [sql cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg);
}

- (void) copyLog: (NSString *) file dateTime: (NSString*) dateTime Action: (CodeseeDBAction) action
{
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO journal VALUES ('%@', '%@', '%d')", file, dateTime, action];

    char *errMsg;
    sqlite3_exec(self->sqlite3_db, [sql cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg);
}

- (NSArray *) query: (NSString *) query
{
    sqlite3_stmt *statement;
    sqlite3_prepare_v2(self->sqlite3_db, [query UTF8String], -1, &statement, nil);

    NSMutableArray *queryResult = [[NSMutableArray alloc]init];

    while (sqlite3_step(statement) == SQLITE_ROW) {
        int columnCount = sqlite3_column_count(statement);
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < columnCount; i++) {
            const char *cKey = sqlite3_column_name(statement, i);
            NSString *key = [NSString stringWithUTF8String:cKey];

            const char *cValue = (const char *)sqlite3_column_text(statement, i);
            NSString *value = [NSString stringWithUTF8String:cValue];

            [dict setObject:value forKey:key];
        }
        [queryResult addObject:dict];
    }

    return queryResult;
}

- (BOOL) close
{
    BOOL retVal = NO;

    sqlite3_close(self->sqlite3_db);
    retVal = YES;

    return retVal;
}
@end
