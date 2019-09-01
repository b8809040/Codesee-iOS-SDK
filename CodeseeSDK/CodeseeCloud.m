//
//  CodeseeCloud.m
//  CodeseeSDK
//
//  Created by Leo Tang on 2019/1/6.
//  Copyright © 2019 Leo Tang. All rights reserved.
//

#import "CodeseeCloud.h"
#import "CodeseeDB.h"
#import "CodeseeUtilities.h"

#define MethodNotImplemented() \
@throw \
[NSException exceptionWithName:NSInternalInconsistencyException \
reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] \
userInfo:nil]

@interface CodeseeCloud()
{
    BOOL cloudOpDone;
    BOOL stopSyncFlag;
}
@end

@implementation CodeseeCloud
-(BOOL) login: (NSString *) myAccount { MethodNotImplemented(); }
-(nullable NSArray<NSDictionary *> *) search:(NSString *) name isFolder: (BOOL) isFolder ownerAccount: (nullable NSString*) ownerAccount  { MethodNotImplemented(); }
-(nullable NSArray<NSDictionary *> *) list:(NSString *) folderName ownerAccount: (nullable NSString*) ownerAccount { MethodNotImplemented(); }
-(BOOL) createFolder: (NSString *) folderName parentFolder: (nullable NSString *) parentFolderName { MethodNotImplemented(); }
-(BOOL) deleteFolder: (NSString *) folderName parentFolder: (nullable NSString *) parentFolderName { MethodNotImplemented(); }
-(BOOL) uploadFile:(NSString *) fileName parentFolder:(nullable NSString *) parentFolderName alias: (NSString *) alias { MethodNotImplemented(); }
-(BOOL) updateFile:(nonnull NSDictionary *) fileDescriptor localFile: (nonnull NSString *) localFile { MethodNotImplemented(); }
-(BOOL) downloadFile:(nonnull NSDictionary *) fileDescriptor localFile: (nonnull NSString *) localFile { MethodNotImplemented(); }
-(BOOL) downloadFiles:(nonnull NSString *) folderName localFolder: (nonnull NSString *) localFolder ownerAccount: (nullable NSString*) ownerAccount { MethodNotImplemented(); }
-(BOOL) deleteFile:(nonnull NSDictionary *) fileDescriptor { MethodNotImplemented(); }
-(BOOL) sync
{
    BOOL retVal = NO;
    self->stopSyncFlag = NO;

    NSArray *searchResult = [self search: @"Codesee" isFolder: YES ownerAccount: self.account];
    if(searchResult == nil) {
        // Setup User's Codesee cloud
        [self createFolder:@"Codesee" parentFolder: nil];
        [self createFolder:@"MyCodesee" parentFolder: @"Codesee"];
        // Copy default database as cloud database
        NSFileManager *fileManager =[NSFileManager defaultManager];
        NSError *error;
        NSString *file = [[CodeseeUtilities getDocPath: @"MyCodesee"] stringByAppendingPathComponent: @"codesee.cloud.db3"];
        if ([fileManager fileExistsAtPath:file]){
            NSLog(@"remove file %@", file);
            NSError *error;
            [fileManager removeItemAtPath: file error:&error];
        }
        [fileManager copyItemAtPath: [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"codesee.local.db3"] toPath: file error: &error];
        if(error != nil) {
            NSLog(@"Duplicate default database to codesee.cloud.db3 fail");
            return NO;
        }
        // Upload cloud database to cloud
        [self uploadFile:file parentFolder: @"MyCodesee" alias: @"codesee.cloud.db3"];
        // Upload the files in the folder one by one
        NSString *cloudDatabaseFile = [[CodeseeUtilities getDocPath: @"MyCodesee"] stringByAppendingPathComponent: @"codesee.cloud.db3"];
        NSString *localDatabaseFile = [[CodeseeUtilities getDocPath: @"MyCodesee"] stringByAppendingPathComponent: @"codesee.local.db3"];
        CodeseeDB *cloudDatabase = [[CodeseeDB alloc] init];
        if([cloudDatabase open: cloudDatabaseFile] == NO) return NO;
        CodeseeDB *localDatabase = [[CodeseeDB alloc] init];
        if([localDatabase open: localDatabaseFile] == NO) return NO;
        NSArray *localEvents = [localDatabase query: @"Select * from journal order by datetime asc"];
        NSLog(@"local events: %@", localEvents);
        NSArray *searchResult2 = [self search: @"codesee.cloud.db3" isFolder: NO ownerAccount: self.account];
        for(NSDictionary *event in localEvents) {
            if(self->stopSyncFlag == YES) break;

            [self handleLocalEvent: event ownerId: @"MyCodesee" ownerAccount: self.account];
            [cloudDatabase copyLog: event[@"filename"] dateTime: event[@"datetime"] Action: (CodeseeDBAction) [event[@"action"] integerValue]];
            // Upload cloud database to cloud
            [self updateFile: @{@"fileId": searchResult2[0][@"fileId"]} localFile: file];
        }
        [cloudDatabase close];
        [localDatabase close];
    }

    searchResult = [self search: @"codesee.cloud.db3" isFolder: NO ownerAccount: nil];

    for(NSDictionary *item in searchResult) {
        if(self->stopSyncFlag == YES) break;

        NSString *ownerId = item[@"ownerId"];
        if([item[@"ownerId"] isEqualToString: self.account] == YES) {
            ownerId = @"MyCodesee";
        }
        NSLog(@"%@ %@", item[@"fileId"], ownerId);
        // Setup Codesee local
        BOOL isDir;
        NSFileManager *fileManager =[NSFileManager defaultManager];
        if (!([fileManager fileExistsAtPath:[CodeseeUtilities getDocPath: ownerId] isDirectory:&isDir] && isDir)) {
            [fileManager createDirectoryAtPath:[CodeseeUtilities getDocPath: ownerId] withIntermediateDirectories:YES attributes:nil error: NULL];
            // Copy default database to local database
            NSError *error;
            [fileManager copyItemAtPath: [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"codesee.local.db3"] toPath: [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: @"codesee.local.db3"] error: &error];
            if(error != nil) {
                NSLog(@"Duplicate default database to codesee.local.db3 fail");
                return NO;
            }
            // Download cloud database from cloud
            NSString *cloudDatabaseFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: @"codesee.cloud.db3"];
            [self downloadFile: item localFile:cloudDatabaseFile];
            // Download the files in the cloud one by one
            NSString *localDatabaseFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: @"codesee.local.db3"];
            CodeseeDB *cloudDatabase = [[CodeseeDB alloc] init];
            if([cloudDatabase open: cloudDatabaseFile] == NO) return NO;
            CodeseeDB *localDatabase = [[CodeseeDB alloc] init];
            if([localDatabase open: localDatabaseFile] == NO) return NO;
            NSArray *cloudEvents = [cloudDatabase query: @"Select * from journal order by datetime asc"];
            NSLog(@"cloud events: %@", cloudEvents);
            for(NSDictionary *event in cloudEvents) {
                if(self->stopSyncFlag == YES) break;

                [self handleCloudEvent: event ownerId: ownerId ownerAccount: item[@"ownerId"]];
                [localDatabase copyLog: event[@"filename"] dateTime: event[@"datetime"] Action: (CodeseeDBAction) [event[@"action"] integerValue]];
            }
            [cloudDatabase close];
            [localDatabase close];
        }
    }

    for(NSDictionary *item in searchResult) {
        if(self->stopSyncFlag == YES) break;

        NSString *ownerId = item[@"ownerId"];
        if([item[@"ownerId"] isEqualToString: self.account] == YES) {
            ownerId = @"MyCodesee";
        }
        NSLog(@"%@ %@", item[@"fileId"], ownerId);
        // Download cloud database from cloud
        NSString *cloudDatabaseFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: @"codesee.cloud.db3"];
        [self downloadFile: item localFile:cloudDatabaseFile];
        // Open database and prepare to sync.
        NSString *localDatabaseFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: @"codesee.local.db3"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager contentsEqualAtPath:cloudDatabaseFile andPath:localDatabaseFile]) continue;
        CodeseeDB *cloudDatabase = [[CodeseeDB alloc] init];
        if([cloudDatabase open: cloudDatabaseFile] == NO) continue;
        CodeseeDB *localDatabase = [[CodeseeDB alloc] init];
        if([localDatabase open: localDatabaseFile] == NO) continue;
        NSOrderedSet *cloudEvents = [NSOrderedSet orderedSetWithArray: [cloudDatabase query: @"Select * from journal order by datetime asc"]];
        NSLog(@"cloud events: %@", cloudEvents);
        NSOrderedSet *localEvents = [NSOrderedSet orderedSetWithArray: [localDatabase query: @"Select * from journal order by datetime asc"]];
        NSLog(@"local events: %@", localEvents);
        NSMutableOrderedSet *cloudAddedEvents = [cloudEvents mutableCopy];
        NSMutableOrderedSet *localAddedEvents = [localEvents mutableCopy];
        [cloudAddedEvents minusOrderedSet: localEvents];
        NSLog(@"cloud added events:%@", cloudAddedEvents);
        [localAddedEvents minusOrderedSet: cloudEvents];
        NSLog(@"local added events:%@", localAddedEvents);
        // Cloud events to local
        NSArray *cloudArray = [cloudAddedEvents mutableCopy];
        for(NSDictionary *event in cloudArray) {
            if(self->stopSyncFlag == YES) break;

            [self handleCloudEvent: event ownerId: ownerId ownerAccount: item[@"ownerId"]];
            [localDatabase copyLog: event[@"filename"] dateTime: event[@"datetime"] Action: (CodeseeDBAction) [event[@"action"] integerValue]];
        } // end for(NSDictionary *event in eventsInAction)
        // Local events to cloud
        NSArray *localArray = [localAddedEvents mutableCopy];
        NSString *file = [[CodeseeUtilities getDocPath: @"MyCodesee"] stringByAppendingPathComponent: @"codesee.cloud.db3"];
        for(NSDictionary *event in localArray) {
            if(self->stopSyncFlag == YES) break;

            [self handleLocalEvent: event ownerId: ownerId ownerAccount: item[@"ownerId"]];
            [cloudDatabase copyLog: event[@"filename"] dateTime: event[@"datetime"] Action: (CodeseeDBAction) [event[@"action"] integerValue]];
            // Upload cloud database to cloud
            [self updateFile: @{@"fileId": item[@"fileId"]} localFile: file];
        } // end for(NSDictionary *event in eventsInAction)
        [localDatabase close];
        [cloudDatabase close];
    } // for(NSDictionary *item in searchResult)

    self->stopSyncFlag = NO;
    retVal = YES;

    return retVal;
}
-(BOOL) stopSync
{
    BOOL retVal = NO;
    self->stopSyncFlag = YES;
    while(self->stopSyncFlag != NO){[NSThread sleepForTimeInterval:0.01];};
    retVal = YES;
    return retVal;
}
-(BOOL) share: (nonnull NSString*) otherAccount folderName: (nonnull NSString *) folderName { MethodNotImplemented(); }
-(BOOL) unshare: (nonnull NSString*) otherAccount folderName: (nonnull NSString *) folderName { MethodNotImplemented(); }
-(nullable NSArray *) getMySharing { MethodNotImplemented(); }
-(nullable NSArray *) getSharedWithMe { MethodNotImplemented(); }
-(void) handleLocalEvent: (NSDictionary *) event ownerId: (NSString *) ownerId ownerAccount: (NSString *) ownerAccount
{
    switch([event[@"action"] integerValue]) {
        case CodeseeDBCreate:
        {
            NSLog(@"cloud upload: %@", event[@"filename"]);
            NSString *localFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            NSArray *temp = [event[@"filename"] componentsSeparatedByString: @"/"];
            NSString *parentFolder = nil;
            NSString *filename = nil;
            if([temp count] > 1) {
                parentFolder = temp[0];
                filename = temp[1];
            } else {
                parentFolder = ownerId;
                filename = temp[0];
            }
            // Workaround for Google cloud
            NSArray *searchResult2 = [self search: filename isFolder: NO ownerAccount: ownerAccount];
            if(searchResult2 != nil && searchResult2.count > 0) {
                [self updateFile: @{@"fileId": searchResult2[0][@"fileId"]} localFile: localFile];
            } else {
                //
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ([fileManager fileExistsAtPath:localFile]){
                    [self uploadFile: localFile parentFolder: parentFolder alias: filename];
                } else {
                    NSLog(@"file %@ not found", localFile);
                }
            }
            break;
        }
        case CodeseeDBUpdate:
        {
            NSLog(@"cloud update: %@", event[@"filename"]);
            NSString *localFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:localFile]){
                NSArray *temp = [event[@"filename"] componentsSeparatedByString: @"/"];
                NSString *parentFolder = nil;
                NSString *filename = nil;
                if([temp count] > 1) {
                    parentFolder = temp[0];
                    filename = temp[1];
                } else {
                    parentFolder = ownerId;
                    filename = temp[0];
                }
                NSArray *searchResult2 = [self search: filename isFolder: NO ownerAccount: ownerAccount];
                if(searchResult2 != nil && searchResult2.count > 0) {
                    [self updateFile: @{@"fileId": searchResult2[0][@"fileId"]} localFile: localFile];
                } else {
                    [self uploadFile: localFile parentFolder: parentFolder alias: filename];
                }
            } else {
                NSLog(@"file %@ not found", localFile);
            }
            break;
        }
        case CodeseeDBDelete:
        {
            NSLog(@"cloud delete: %@", event[@"filename"]);
            NSString *filename = [event[@"filename"] componentsSeparatedByString: @"/"][1];
            NSArray *searchResult2 = [self search: filename isFolder: NO ownerAccount: ownerAccount];
            if(searchResult2 != nil && searchResult2.count > 0) {
                [self deleteFile: @{@"fileId": searchResult2[0][@"fileId"]}];
            }
            break;
        }
        case CodeseeDBCreateFolder:
        {
            NSLog(@"cloud create folder: %@", event[@"filename"]);
            [self createFolder: event[@"filename"] parentFolder: ownerId];
            break;
        }
        case CodeseeDBDeleteFolder:
        {
            NSLog(@"cloud delete folder: %@", event[@"filename"]);
            [self deleteFolder: event[@"filename"] parentFolder: ownerId];
            break;
        }
    }
}
-(void) handleCloudEvent: (NSDictionary *) event ownerId: (NSString *) ownerId ownerAccount: (NSString *) ownerAccount
{
    switch([event[@"action"] integerValue]) {
        case CodeseeDBCreate:
        case CodeseeDBUpdate:
        {
            NSLog(@"local download: %@", event[@"filename"]);
            NSArray *temp = [event[@"filename"] componentsSeparatedByString: @"/"];
            NSString *filename = nil;
            if([temp count] > 1) {
                filename = temp[1];
            } else {
                filename = temp[0];
            }
            NSArray *searchResult2 = [self search: filename isFolder: NO ownerAccount: ownerAccount];
            NSString *localFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            if(searchResult2 != nil && searchResult2.count > 0) {
                [self downloadFile: searchResult2[0] localFile: localFile];
            }
            break;
        }
        case CodeseeDBDelete:
        {
            NSLog(@"local delete: %@", event[@"filename"]);
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *localFile = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            if ([fileManager fileExistsAtPath:localFile]){
                NSLog(@"remove file %@", localFile);
                NSError *error;
                [fileManager removeItemAtPath: localFile error:&error];
            } else {
                NSLog(@"file %@ not found", localFile);
            }
            break;
        }
        case CodeseeDBCreateFolder:
        {
            NSLog(@"local create folder: %@", event[@"filename"]);
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *localFolder = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            if ([fileManager fileExistsAtPath:localFolder]){
                NSLog(@"folder exist");
            } else {
                NSError *error;
                [fileManager createDirectoryAtPath:localFolder withIntermediateDirectories:YES attributes:nil error: &error];
                if(error != nil) {
                    NSLog(@"[CodeseeSDK] %s %d error: %@", __FUNCTION__, __LINE__, error.localizedDescription);
                }
            }
            break;
        }
        case CodeseeDBDeleteFolder:
        {
            NSLog(@"local delete folder: %@", event[@"filename"]);
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *localFolder = [[CodeseeUtilities getDocPath: ownerId] stringByAppendingPathComponent: event[@"filename"]];
            if ([fileManager fileExistsAtPath:localFolder]){
                NSError *error;
                [fileManager removeItemAtPath: localFolder error:&error];
                if(error != nil) {
                    NSLog(@"[CodeseeSDK] %s %d error: %@", __FUNCTION__, __LINE__, error.localizedDescription);
                }
            } else {
                NSLog(@"folder %@ not found", localFolder);
            }
            break;
        }
    }
}
@end
