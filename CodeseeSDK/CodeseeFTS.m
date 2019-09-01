//
//  CodeseeFTS.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/3/29.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeFTS.h"
#import <sqlite3.h>

@interface CodeseeFTS()
{
    sqlite3* sqlite3_db;
}
@end

@implementation CodeseeFTS

- (BOOL) open: (NSString *) dbFile
{
    if(sqlite3_open(dbFile.UTF8String , &self->sqlite3_db) != SQLITE_OK) {
        NSLog(@"sqlite3_open fail");
        return NO;
    }
    return YES;
}

- (BOOL) addNote:(NSString*) qrcode note:(NSString *)note
{
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO qrcodes(qrcode, location, date, note) VALUES ('%@', '', '', '%@')", qrcode, note];
    
    char *errMsg;
    sqlite3_exec(self->sqlite3_db, [sql cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg);
    
    return YES;
}

- (BOOL) updateNote:(NSString*) qrcode note:(NSString *)note
{
    NSString *sql = [NSString stringWithFormat:@"UPDATE qrcodes SET note = '%@' WHERE qrcode = '%@'", note, qrcode];
    
    char *errMsg;
    sqlite3_exec(self->sqlite3_db, [sql cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg);
    
    return YES;
}

- (BOOL) removeNote: (NSString *) qrcode
{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM qrcodes WHERE qrcode='%@'", qrcode];

    char *errMsg;
    sqlite3_exec(self->sqlite3_db, [sql cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg);

    return YES;
}

- (NSArray *) search: (NSString *) searchText
{
    NSString *sql = [NSString stringWithFormat: @"SELECT * FROM qrcodes WHERE note MATCH '*%@*'", searchText];

    sqlite3_stmt *statement;
    sqlite3_prepare_v2(self->sqlite3_db, [sql UTF8String], -1, &statement, nil);
    
    NSMutableArray *searchResult = [[NSMutableArray alloc]init];
    
    while (sqlite3_step(statement) == SQLITE_ROW) {
        const char *cValue = (const char *)sqlite3_column_text(statement, 0);
        NSString *qrcode = [NSString stringWithUTF8String:cValue];
        [searchResult addObject: qrcode];
    }
    
    return searchResult;
}

- (BOOL) close
{
    BOOL retVal = NO;
    
    sqlite3_close(self->sqlite3_db);
    retVal = YES;
    
    return retVal;
}
@end
