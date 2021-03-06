/*
 Copyright (c) 2003-2015, Sveinbjorn Thordarson <sveinbjornt@gmail.com>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or other
 materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may
 be used to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

// PlatypusAppSpec is a data wrapper class around an NSDictionary containing
// all the information / specifications for creating a Platypus application.


#import "PlatypusAppSpec.h"
#import "Common.h"
#import "ScriptAnalyser.h"
#import "NSWorkspace+Additions.h"

@interface PlatypusAppSpec()
{
    NSMutableDictionary *properties;
}
- (void)report:(NSString *)format, ...;
@end

@implementation PlatypusAppSpec

#pragma mark - NSMutableDictionary subclass using proxy

- (void)dealloc {
    [properties release];
    [super dealloc];
}

- (instancetype)init {
    if (self = [super init]) {
        // proxy dictionary object
        properties = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] initWithCapacity:numItems];
    }
    return self;
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        properties = [[NSMutableDictionary alloc] initWithCoder:aDecoder];
    }
    return self;
}

- (void)removeObjectForKey:(id)aKey {
    [properties removeObjectForKey:aKey];
}

- (void)setObject:(id)anObject forKey:(id <NSCopying>)aKey {
    [properties setObject:anObject forKey:aKey];
}

- (id)objectForKey:(id)aKey {
    return [properties objectForKey:aKey];
}

- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary {
    [properties addEntriesFromDictionary:otherDictionary];
}

- (NSEnumerator *)keyEnumerator {
    return [properties keyEnumerator];
}

- (NSUInteger) count {
    return [properties count];
}

#pragma mark - Create spec

- (instancetype)initWithDefaults {
    if (self = [self init]) {
        [self setDefaults];
    }
    return self;
}

- (instancetype)initWithDefaultsForScript:(NSString *)scriptPath {
    if (self = [self initWithDefaults]) {
        [self setDefaultsForScript:scriptPath];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [self init]) {
        [self setDefaults];
        [properties addEntriesFromDictionary:dict];
    }
    return self;
}

- (instancetype)initWithProfile:(NSString *)profilePath {
    NSDictionary *profileDict = [NSDictionary dictionaryWithContentsOfFile:profilePath];
    if (profileDict == nil) {
        return nil;
    }
    return [self initWithDictionary:profileDict];
}

//#if !__has_feature(objc_arc)

+ (instancetype)specWithDefaults {
    return [[[self alloc] initWithDefaults] autorelease];
}

+ (instancetype)specWithDictionary:(NSDictionary *)dict {
    return [[[self alloc] initWithDictionary:dict] autorelease];
}

+ (instancetype)specWithProfile:(NSString *)profilePath {
    return [[[self alloc] initWithProfile:profilePath] autorelease];
}

+ (instancetype)specWithDefaultsFromScript:(NSString *)scriptPath {
    return [[[self alloc] initWithDefaultsForScript:scriptPath] autorelease];
}

//#endif

#pragma mark - Set default values

/**********************************
 init a spec with default values for everything
 **********************************/

- (void)setDefaults {
    // stamp the spec with the creator
    self[@"Creator"] = PROGRAM_STAMP;
    
    //prior properties
    self[@"ExecutablePath"] = CMDLINE_EXEC_PATH;
    self[@"NibPath"] = CMDLINE_NIB_PATH;
    self[@"Destination"] = DEFAULT_DESTINATION_PATH;
    
    [properties setValue:@NO forKey:@"DestinationOverride"];
    [properties setValue:@NO forKey:@"DevelopmentVersion"];
    [properties setValue:@YES forKey:@"OptimizeApplication"];
    [properties setValue:@NO forKey:@"UseXMLPlistFormat"];
    
    // primary attributes
    self[@"Name"] = DEFAULT_APP_NAME;
    self[@"ScriptPath"] = @"";
    self[@"Output"] = DEFAULT_OUTPUT_TYPE;
    self[@"IconPath"] = CMDLINE_ICON_PATH;
    
    // secondary attributes
    self[@"Interpreter"] = DEFAULT_INTERPRETER;
    self[@"InterpreterArgs"] = [NSMutableArray array];
    self[@"ScriptArgs"] = [NSMutableArray array];
    self[@"Version"] = DEFAULT_VERSION;
    self[@"Identifier"] = [PlatypusAppSpec bundleIdentifierForAppName:DEFAULT_APP_NAME authorName:nil usingDefaults:YES];
    self[@"Author"] = NSFullUserName();
    
    [properties setValue:@NO forKey:@"Droppable"];
    [properties setValue:@NO forKey:@"Secure"];
    [properties setValue:@NO forKey:@"Authentication"];
    [properties setValue:@YES forKey:@"RemainRunning"];
    [properties setValue:@NO forKey:@"ShowInDock"];
    
    // bundled files
    self[@"BundledFiles"] = [NSMutableArray array];
    
    // file/drag acceptance properties
    self[@"Suffixes"] = [NSMutableArray arrayWithObject:@"*"];
    self[@"UniformTypes"] = [NSMutableArray array];
    self[@"AcceptsText"] = @NO;
    self[@"AcceptsFiles"] = @YES;
    self[@"DeclareService"] = @NO;
    self[@"PromptForFileOnLaunch"] = @NO;
    self[@"DocIcon"] = @"";
    
    // text output settings
    self[@"TextEncoding"] = @(DEFAULT_OUTPUT_TXT_ENCODING);
    self[@"TextFont"] = DEFAULT_OUTPUT_FONT;
    self[@"TextSize"] = @(DEFAULT_OUTPUT_FONTSIZE);
    self[@"TextForeground"] = DEFAULT_OUTPUT_FG_COLOR;
    self[@"TextBackground"] = DEFAULT_OUTPUT_BG_COLOR;
    
    // status item settings
    self[@"StatusItemDisplayType"] = DEFAULT_STATUSITEM_DTYPE;
    self[@"StatusItemTitle"] = DEFAULT_APP_NAME;
    self[@"StatusItemIcon"] = [NSData data];
    self[@"StatusItemUseSystemFont"] = @YES;
}

/********************************************************
 Init with default values and then analyse script, then
 load default values based on analysed script properties
 ********************************************************/

- (void)setDefaultsForScript:(NSString *)scriptPath {
    // start with a dict populated with defaults
    [self setDefaults];
    
    // set script path
    self[@"ScriptPath"] = scriptPath;
    
    //determine app name based on script filename
    self[@"Name"] = [ScriptAnalyser appNameFromScriptFilePath:scriptPath];
    
    //find an interpreter for it
    NSString *interpreter = [ScriptAnalyser determineInterpreterForScriptFile:scriptPath];
    if (interpreter == nil) {
        interpreter = DEFAULT_INTERPRETER;
    } else {
        // get parameters to interpreter
        NSMutableArray *shebangCmdComponents = [NSMutableArray arrayWithArray:[ScriptAnalyser parseInterpreterFromShebang:scriptPath]];
        [shebangCmdComponents removeObjectAtIndex:0];
        self[@"InterpreterArgs"] = shebangCmdComponents;
    }
    self[@"Interpreter"] = interpreter;
    
    // find parent folder wherefrom we create destination path of app bundle
    NSString *parentFolder = [scriptPath stringByDeletingLastPathComponent];
    NSString *destPath = [NSString stringWithFormat:@"%@/%@.app", parentFolder, self[@"Name"]];
    self[@"Destination"] = destPath;
    self[@"Identifier"] = [PlatypusAppSpec bundleIdentifierForAppName:self[@"Name"]
                                                           authorName:nil
                                                        usingDefaults:YES];
}

#pragma mark -

/****************************************
 This function creates the app bundle
 based on the data contained in the spec.
 ****************************************/

- (BOOL)create {
    NSString *contentsPath, *macosPath, *resourcesPath;
    NSString *execDestinationPath, *infoPlistPath, *iconPath, *docIconPath, *nibDestPath;
    NSString *execPath, *nibPath;
    NSData *b_enc_script = [NSData data];
    
    // get temporary directory, make sure it's kosher.  Apparently NSTemporaryDirectory() can return nil
    // see http://www.cocoadev.com/index.pl?NSTemporaryDirectory
    NSString *tmpPath = NSTemporaryDirectory();
    if (tmpPath == nil) {
        tmpPath = @"/tmp/";
    }
    
    // make sure we can write to temp path
    if ([FILEMGR isWritableFileAtPath:tmpPath] == NO) {
        _error = [NSString stringWithFormat:@"Could not write to the temp directory '%@'.", tmpPath];
        return FALSE;
    }
    
    //check if app already exists
    if ([FILEMGR fileExistsAtPath:self[@"Destination"]]) {
        if ([self[@"DestinationOverride"] boolValue] == FALSE) {
            _error = [NSString stringWithFormat:@"App already exists at path %@. Use -y flag to overwrite.", self[@"Destination"]];
            return FALSE;
        } else {
            [self report:@"Overwriting app at path %@", self[@"Destination"]];
        }
    }
    
    // check if executable exists
    execPath = self[@"ExecutablePath"];
    if (![FILEMGR fileExistsAtPath:execPath] || ![FILEMGR isReadableFileAtPath:execPath]) {
        [self report:@"Executable %@ does not exist. Aborting.", execPath];
        return NO;
    }
    
    // check if source nib exists
    nibPath = self[@"NibPath"];
    if (![FILEMGR fileExistsAtPath:nibPath] || ![FILEMGR isReadableFileAtPath:nibPath]) {
        [self report:@"Nib file %@ does not exist. Aborting.", nibPath];
        return NO;
    }
    
    ////////////////////////// CREATE THE FOLDER HIERARCHY //////////////////////////
    
    // we begin by creating the application bundle at temp path
    [self report:@"Creating application bundle folder hierarchy"];
    
    //Application.app bundle
    tmpPath = [tmpPath stringByAppendingString:[self[@"Destination"] lastPathComponent]];
    [FILEMGR createDirectoryAtPath:tmpPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    //.app/Contents
    contentsPath = [tmpPath stringByAppendingString:@"/Contents"];
    [FILEMGR createDirectoryAtPath:contentsPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    //.app/Contents/MacOS
    macosPath = [contentsPath stringByAppendingString:@"/MacOS"];
    [FILEMGR createDirectoryAtPath:macosPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    //.app/Contents/Resources
    resourcesPath = [contentsPath stringByAppendingString:@"/Resources"];
    [FILEMGR createDirectoryAtPath:resourcesPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    ////////////////////////// COPY FILES TO THE APP BUNDLE //////////////////////////////////
    
    [self report:@"Copying executable to bundle"];
    
    //copy exec file
    //.app/Contents/Resources/MacOS/ScriptExec
    execDestinationPath = [macosPath stringByAppendingString:@"/"];
    execDestinationPath = [execDestinationPath stringByAppendingString:self[@"Name"]];
    [FILEMGR copyItemAtPath:execPath toPath:execDestinationPath error:nil];
    NSDictionary *execAttrDict = @{NSFilePosixPermissions: @0755UL};
    [FILEMGR setAttributes:execAttrDict ofItemAtPath:execDestinationPath error:nil];
    
    //copy nib file to app bundle
    //.app/Contents/Resources/MainMenu.nib
    [self report:@"Copying nib file to bundle"];
    nibDestPath = [resourcesPath stringByAppendingString:@"/MainMenu.nib"];
    [FILEMGR copyItemAtPath:nibPath toPath:nibDestPath error:nil];
    
    if ([self[@"OptimizeApplication"] boolValue] == YES && [FILEMGR fileExistsAtPath:IBTOOL_PATH]) {
        [self report:@"Optimizing nib file"];
        [PlatypusAppSpec optimizeNibFile:nibDestPath];
    }
    
    // create script file in app bundle
    //.app/Contents/Resources/script
    [self report:@"Copying script"];
    
    if ([self[@"Secure"] boolValue]) {
        NSString *path = self[@"ScriptPath"];
        b_enc_script = [NSData dataWithContentsOfFile:path];
    } else {
        NSString *scriptFilePath = [resourcesPath stringByAppendingString:@"/script"];
        // make a symbolic link instead of copying script if this is a dev version
        if ([self[@"DevelopmentVersion"] boolValue] == YES) {
            [FILEMGR createSymbolicLinkAtPath:scriptFilePath withDestinationPath:self[@"ScriptPath"] error:nil];
        } else { // copy script over
            [FILEMGR copyItemAtPath:self[@"ScriptPath"] toPath:scriptFilePath error:nil];
        }
        NSDictionary *fileAttrDict = @{NSFilePosixPermissions: @0755UL};
        [FILEMGR setAttributes:fileAttrDict ofItemAtPath:scriptFilePath error:nil];
    }
    
    //create AppSettings.plist file
    //.app/Contents/Resources/AppSettings.plist
    [self report:@"Creating AppSettings property list"];
    NSMutableDictionary *appSettingsPlist = [self appSettingsPlist];
    if ([self[@"Secure"] boolValue]) {
        // if script is "secured" we encode it into AppSettings property list
        appSettingsPlist[@"TextSettings"] = [NSKeyedArchiver archivedDataWithRootObject:b_enc_script];
    }
    NSString *appSettingsPlistPath = [resourcesPath stringByAppendingString:@"/AppSettings.plist"];
    if ([self[@"UseXMLPlistFormat"] boolValue] == FALSE) {
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:appSettingsPlist
                                                                       format:NSPropertyListBinaryFormat_v1_0
                                                                      options:0
                                                                        error:nil];
        [plistData writeToFile:appSettingsPlistPath atomically:YES];
    } else {
        [appSettingsPlist writeToFile:appSettingsPlistPath atomically:YES];
    }
    
    //create icon
    //.app/Contents/Resources/appIcon.icns
    if (self[@"IconPath"] && ![self[@"IconPath"] isEqualToString:@""]) {
        [self report:@"Writing application icon"];
        iconPath = [resourcesPath stringByAppendingString:@"/appIcon.icns"];
        [FILEMGR copyItemAtPath:self[@"IconPath"] toPath:iconPath error:nil];
    }
    
    //document icon
    //.app/Contents/Resources/docIcon.icns
    if (self[@"DocIcon"] && ![self[@"DocIcon"] isEqualToString:@""]) {
        [self report:@"Writing document icon"];
        docIconPath = [resourcesPath stringByAppendingString:@"/docIcon.icns"];
        [FILEMGR copyItemAtPath:self[@"DocIcon"] toPath:docIconPath error:nil];
    }
    
    //create Info.plist file
    //.app/Contents/Info.plist
    [self report:@"Writing Info.plist"];
    NSDictionary *infoPlist = [self infoPlist];
    infoPlistPath = [contentsPath stringByAppendingString:@"/Info.plist"];
    BOOL success = YES;
    // if binary
    if ([self[@"UseXMLPlistFormat"] boolValue] == NO) {
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:infoPlist
                                                                       format:NSPropertyListBinaryFormat_v1_0
                                                                      options:0
                                                                        error:nil];
        if (plistData == nil || ![plistData writeToFile:infoPlistPath atomically:YES]) {
            success = NO;
        }
    }
    // if XML
    else {
        success = [infoPlist writeToFile:infoPlistPath atomically:YES];
    }
    // raise error on failure
    if (success == NO) {
        _error = @"Error writing Info.plist";
        return FALSE;
    }
    
    //copy bundled files to Resources folder
    //.app/Contents/Resources/*
    
    int numBundledFiles = [self[@"BundledFiles"] count];
    if (numBundledFiles) {
        [self report:@"Copying %d bundled files", numBundledFiles];
    }
    for (NSString *bundledFilePath in self[@"BundledFiles"]) {
        NSString *fileName = [bundledFilePath lastPathComponent];
        NSString *bundledFileDestPath = [resourcesPath stringByAppendingString:@"/"];
        bundledFileDestPath = [bundledFileDestPath stringByAppendingString:fileName];
        
        // if it's a development version, we just symlink it
        if ([self[@"DevelopmentVersion"] boolValue] == YES) {
            [self report:@"Symlinking to \"%@\" in bundle", fileName];
            [FILEMGR createSymbolicLinkAtPath:bundledFileDestPath withDestinationPath:bundledFilePath error:nil];
        } else {
            [self report:@"Copying \"%@\" to bundle", fileName];
            
            // otherwise we copy it
            // first remove any file in destination path
            // NB: This means any previously copied files are overwritten
            // and so users can bundle in their own MainMenu.nib etc.
            if ([FILEMGR fileExistsAtPath:bundledFileDestPath]) {
                [FILEMGR removeItemAtPath:bundledFileDestPath error:nil];
            }
            [FILEMGR copyItemAtPath:bundledFilePath toPath:bundledFileDestPath error:nil];
        }
    }
    
    // COPY APP OVER TO FINAL DESTINATION
    // we've created the application bundle in the temporary directory
    // now it's time to move it to the destination specified by the user
    [self report:@"Moving app to destination directory"];
    
    NSString *destPath = self[@"Destination"];
    
    // first, let's see if there's anything there.  If we have override set on, we just delete that stuff.
    if ([FILEMGR fileExistsAtPath:destPath] && [self[@"DestinationOverride"] boolValue]) {
        [FILEMGR removeItemAtPath:destPath error:nil];
        [WORKSPACE notifyFinderFileChangedAtPath:destPath];
    }
    
    //if delete wasn't a success and there's still something there
    if ([FILEMGR fileExistsAtPath:destPath]) {
        _error = @"Could not remove pre-existing item at destination path";
        return FALSE;
    }
    
    // now, move the newly created app to the destination
    [FILEMGR moveItemAtPath:tmpPath toPath:destPath error:nil];
    if (![FILEMGR fileExistsAtPath:destPath]) {
        //if move wasn't a success, clean up app in tmp dir
        [FILEMGR removeItemAtPath:tmpPath error:nil];
        _error = @"Failed to create application at the specified destination";
        return FALSE;
    }
    [WORKSPACE notifyFinderFileChangedAtPath:destPath];
    
    // Update Services
    if ([self[@"DeclareService"] boolValue]) {
        [self report:@"Updating Dynamic Services"];
        [WORKSPACE flushServices];
    }
    
    [self report:@"Done"];
    
    return TRUE;
}

// Generate AppSettings.plist dictionary
- (NSMutableDictionary *)appSettingsPlist {
    
    NSMutableDictionary *appSettingsPlist = [NSMutableDictionary dictionary];
    
    appSettingsPlist[@"RequiresAdminPrivileges"] = self[@"Authentication"];
    appSettingsPlist[@"Droppable"] = self[@"Droppable"];
    appSettingsPlist[@"RemainRunningAfterCompletion"] = self[@"RemainRunning"];
    appSettingsPlist[@"Secure"] = self[@"Secure"];
    appSettingsPlist[@"OutputType"] = self[@"Output"];
    appSettingsPlist[@"ScriptInterpreter"] = self[@"Interpreter"];
    appSettingsPlist[@"Creator"] = PROGRAM_STAMP;
    appSettingsPlist[@"InterpreterArgs"] = self[@"InterpreterArgs"];
    appSettingsPlist[@"ScriptArgs"] = self[@"ScriptArgs"];
    appSettingsPlist[@"PromptForFileOnLaunch"] = self[@"PromptForFileOnLaunch"];
    
    // we need only set text settings for the output types that use this information
    if (IsTextStyledOutputTypeString(self[@"Output"])) {
        appSettingsPlist[@"TextFont"] = self[@"TextFont"];
        appSettingsPlist[@"TextSize"] = self[@"TextSize"];
        appSettingsPlist[@"TextForeground"] = self[@"TextForeground"];
        appSettingsPlist[@"TextBackground"] = self[@"TextBackground"];
        appSettingsPlist[@"TextEncoding"] = self[@"TextEncoding"];
    }
    
    // likewise, status menu settings are only written if that is the output type
    if ([self[@"Output"] isEqualToString:@"Status Menu"] == YES) {
        appSettingsPlist[@"StatusItemDisplayType"] = self[@"StatusItemDisplayType"];
        appSettingsPlist[@"StatusItemTitle"] = self[@"StatusItemTitle"];
        appSettingsPlist[@"StatusItemIcon"] = self[@"StatusItemIcon"];
        appSettingsPlist[@"StatusItemUseSystemFont"] = self[@"StatusItemUseSystemFont"];
    }
    
    // we  set the suffixes/file types in the AppSettings.plist if app is droppable
    if ([self[@"Droppable"] boolValue] == YES) {
        appSettingsPlist[@"DropSuffixes"] = self[@"Suffixes"];
        appSettingsPlist[@"DropUniformTypes"] = self[@"UniformTypes"];
    }
    appSettingsPlist[@"AcceptsFiles"] = self[@"AcceptsFiles"];
    appSettingsPlist[@"AcceptsText"] = self[@"AcceptsText"];
    
    return appSettingsPlist;
}

// Generate Info.plist dictionary
- (NSDictionary *)infoPlist {
    
    // create copyright string with current year
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy"];
    NSString *yearString = [formatter stringFromDate:[NSDate date]];
    NSString *copyrightString = [NSString stringWithFormat:@"© %@ %@", yearString, self[@"Author"]];
    
    // create dict
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      
                                      @"en",                                    @"CFBundleDevelopmentRegion",
                                      self[@"Name"],                            @"CFBundleExecutable",
                                      self[@"Name"],                            @"CFBundleName",
                                      copyrightString,                          @"NSHumanReadableCopyright",
                                      self[@"Version"],                         @"CFBundleVersion",
                                      self[@"Version"],                         @"CFBundleShortVersionString",
                                      self[@"Identifier"],                      @"CFBundleIdentifier",
                                      self[@"ShowInDock"],                      @"LSUIElement",
                                      @"6.0",                                   @"CFBundleInfoDictionaryVersion",
                                      @"APPL",                                  @"CFBundlePackageType",
                                      @"????",                                  @"CFBundleSignature",
                                      @"MainMenu",                              @"NSMainNibFile",
                                      PROGRAM_MIN_SYS_VERSION,                  @"LSMinimumSystemVersion",
                                      @"NSApplication",                         @"NSPrincipalClass",
                                      @{@"NSAllowsArbitraryLoads": @YES},       @"NSAppTransportSecurity",
                                      
                                      nil];
    
    // add icon name if icon is set
    if (self[@"IconPath"] != nil && [self[@"IconPath"] isEqualToString:@""] == NO) {
        infoPlist[@"CFBundleIconFile"] = @"appIcon.icns";
    }
    
    // if droppable, we declare the accepted file types
    if ([self[@"Droppable"] boolValue] == YES) {
        
        NSMutableDictionary *typesAndSuffixesDict = [NSMutableDictionary dictionary];
        
        typesAndSuffixesDict[@"CFBundleTypeExtensions"] = self[@"Suffixes"];
        
        if (self[@"UniformTypes"] != nil && [self[@"UniformTypes"] count] > 0) {
            typesAndSuffixesDict[@"LSItemContentTypes"] = self[@"UniformTypes"];
        }
        
        // document icon
        if (self[@"DocIcon"] && [FILEMGR fileExistsAtPath:self[@"DocIcon"]])
            typesAndSuffixesDict[@"CFBundleTypeIconFile"] = @"docIcon.icns";
        
        // set file types and suffixes
        infoPlist[@"CFBundleDocumentTypes"] = @[typesAndSuffixesDict];
        
        // add service settings to Info.plist
        if ([self[@"DeclareService"] boolValue] == YES) {
            
            NSMutableDictionary *serviceDict = [NSMutableDictionary dictionary];
            
            serviceDict[@"NSMenuItem"] = @{@"default": [NSString stringWithFormat:@"Process with %@", self[@"Name"]]};
            serviceDict[@"NSMessage"] = @"dropService";
            serviceDict[@"NSPortName"] = self[@"Name"];
            serviceDict[@"NSTimeout"] = [NSNumber numberWithInt:3000];
            
            // service data type handling
            NSMutableArray *sendTypes = [NSMutableArray array];
            if ([self[@"AcceptsFiles"] boolValue]) {
                [sendTypes addObject:@"NSFilenamesPboardType"];
                serviceDict[@"NSSendFileTypes"] = @[@"public.item"];
            }
            if ([self[@"AcceptsText"] boolValue]) {
                [sendTypes addObject:@"NSStringPboardType"];
            }
            serviceDict[@"NSSendTypes"] = sendTypes;
            
//            serviceDict[@"NSSendFileTypes"] = @[];
//            serviceDict[@"NSServiceDescription"]
            
            infoPlist[@"NSServices"] = @[serviceDict];
        }
    }
    return infoPlist;
}

- (void)report:(NSString *)format, ... {
    if ([self silentMode] == YES) {
        return;
    }
    
    va_list args;
    
    va_start(args, format);
    NSString *string  = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
    va_end(args);
    
    fprintf(stderr, "%s\n", [string UTF8String]);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLATYPUS_APP_SPEC_CREATION_NOTIFICATION object:string];
}

/****************************************
 Make sure the data in the spec is sane
 ****************************************/

- (BOOL)verify {
    BOOL isDir;
    
    if ([self[@"Destination"] hasSuffix:@"app"] == FALSE) {
        _error = @"Destination must end with .app";
        return NO;
    }
    
    // warn if font can't be instantiated
    if ([NSFont fontWithName:self[@"TextFont"] size:13] == nil) {
        [self report:@"Warning: Font \"%@\" cannot be instantiated.", self[@"TextFont"]];
    }
    
    if ([self[@"Name"] isEqualToString:@""]) {
        _error = @"Empty app name";
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:self[@"ScriptPath"] isDirectory:&isDir] || isDir) {
        _error = [NSString stringWithFormat:@"Script not found at path '%@'", self[@"ScriptPath"], nil];
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:self[@"NibPath"] isDirectory:&isDir]) {
        _error = [NSString stringWithFormat:@"Nib not found at path '%@'", self[@"NibPath"], nil];
        return NO;
    }
    
    if (![FILEMGR fileExistsAtPath:self[@"ExecutablePath"] isDirectory:&isDir] || isDir) {
        _error = [NSString stringWithFormat:@"Executable not found at path '%@'", self[@"ExecutablePath"], nil];
        return NO;
    }
    
    //make sure destination directory exists
    if (![FILEMGR fileExistsAtPath:[self[@"Destination"] stringByDeletingLastPathComponent] isDirectory:&isDir] || !isDir) {
        _error = [NSString stringWithFormat:@"Destination directory '%@' does not exist.", [self[@"Destination"] stringByDeletingLastPathComponent], nil];
        return NO;
    }
    
    //make sure we have write privileges for the destination directory
    if (![FILEMGR isWritableFileAtPath:[self[@"Destination"] stringByDeletingLastPathComponent]]) {
        _error = [NSString stringWithFormat:@"Don't have permission to write to the destination directory '%@'", self[@"Destination"]];
        return NO;
    }
    
    return YES;
}

#pragma mark -

- (void)writeToFile:(NSString *)filePath {
    [properties writeToFile:filePath atomically:YES];
}

- (void)dump {
    fprintf(stdout, "%s\n", [[properties description] UTF8String]);
}

- (NSString *)description {
    return [properties description];
}

#pragma mark - Command string generation

- (NSString *)commandString:(BOOL)shortOpts {
    BOOL longOpts = !shortOpts;
    NSString *checkboxParamStr = @"";
    NSString *iconParamStr = @"";
    NSString *versionString = @"";
    NSString *authorString = @"";
    NSString *suffixesString = @"";
    NSString *uniformTypesString = @"";
    NSString *parametersString = @"";
    NSString *textEncodingString = @"";
    NSString *textOutputString = @"";
    NSString *statusMenuOptionsString = @"";
    
    // checkbox parameters
    if ([self[@"Authentication"] boolValue]) {
        NSString *str = longOpts ? @"-A " : @"--admin-privileges ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"Secure"] boolValue]) {
        NSString *str = longOpts ? @"-S " : @"--secure-script ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"AcceptsFiles"] boolValue] && [self[@"Droppable"] boolValue]) {
        NSString *str = longOpts ? @"-D " : @"--droppable ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"AcceptsText"] boolValue] && [self[@"Droppable"] boolValue]) {
        NSString *str = longOpts ? @"-F " : @"--text-droppable ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"DeclareService"] boolValue] && [self[@"Droppable"] boolValue]) {
        NSString *str = longOpts ? @"-N " : @"--service ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"ShowInDock"] boolValue]) {
        NSString *str = longOpts ? @"-B " : @"--background ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"RemainRunning"] boolValue] == FALSE) {
        NSString *str = longOpts ? @"-R " : @"--quit-after-execution ";
        checkboxParamStr = [checkboxParamStr stringByAppendingString:str];
    }
    
    if ([self[@"Version"] isEqualToString:@"1.0"] == FALSE) {
        NSString *str = longOpts ? @"-V" : @"--app-version";
        versionString = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"Version"]];
    }
    
    if (![self[@"Author"] isEqualToString:NSFullUserName()]) {
        NSString *str = longOpts ? @"-u" : @"--author";
        authorString = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"Author"]];
    }
    
    NSString *promptForFileString = @"";
    if ([self[@"Droppable"] boolValue]) {
        //  suffixes param
        if ([self[@"Suffixes"] count]) {
            NSString *str = longOpts ? @"-X" : @"--suffixes";
            suffixesString = [self[@"Suffixes"] componentsJoinedByString:@"|"];
            suffixesString = [NSString stringWithFormat:@"%@ '%@' ", str, suffixesString];
        }
        // uniform type identifier params
        if ([self[@"UniformTypes"] count]) {
            NSString *str = longOpts ? @"-T" : @"--uniform-type-identifiers";
            uniformTypesString = [self[@"UniformTypes"] componentsJoinedByString:@"|"];
            uniformTypesString = [NSString stringWithFormat:@"%@ '%@' ", str, uniformTypesString];
        }
        // file prompt
        if ([self[@"PromptForFileOnLaunch"] boolValue]) {
            NSString *str = longOpts ? @"-Z" : @"--file-prompt";
            promptForFileString = [NSString stringWithFormat:@"%@ ", str];
        }
    }
    
    //create bundled files string
    NSString *bundledFilesCmdString = @"";
    NSArray *bundledFiles = (NSArray *)self[@"BundledFiles"];
    for (int i = 0; i < [bundledFiles count]; i++) {
        NSString *str = longOpts ? @"-f" : @"--bundled-file";
        bundledFilesCmdString = [bundledFilesCmdString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, bundledFiles[i]]];
    }
    
    // create interpreter and script args flags
    if ([(NSArray *)self[@"InterpreterArgs"] count]) {
        NSString *str = longOpts ? @"-G" : @"--interpreter-args";
        NSString *arg = [self[@"InterpreterArgs"] componentsJoinedByString:@"|"];
        parametersString = [parametersString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, arg]];
    }
    if ([(NSArray *)self[@"ScriptArgs"] count]) {
        NSString *str = longOpts ? @"-C" : @"--script-args";
        NSString *arg = [self[@"ScriptArgs"] componentsJoinedByString:@"|"];
        parametersString = [parametersString stringByAppendingString:[NSString stringWithFormat:@"%@ '%@' ", str, arg]];
    }
    
    //  create args for text settings
    if (IsTextStyledOutputTypeString(self[@"Output"])) {
        
        NSString *textFgString = @"", *textBgString = @"", *textFontString = @"";
        if (![self[@"TextForeground"] isEqualToString:DEFAULT_OUTPUT_FG_COLOR]) {
            NSString *str = longOpts ? @"-g" : @"--text-foreground-color";
            textFgString = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"TextForeground"]];
        }
        
        if (![self[@"TextBackground"] isEqualToString:DEFAULT_OUTPUT_BG_COLOR]) {
            NSString *str = longOpts ? @"-b" : @"--text-background-color";
            textBgString = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"TextForeground"]];
        }
        
        if ([self[@"TextSize"] floatValue] != DEFAULT_OUTPUT_FONTSIZE ||
            ![self[@"TextFont"] isEqualToString:DEFAULT_OUTPUT_FONT]) {
            NSString *str = longOpts ? @"-n" : @"--text-font";
            textFontString = [NSString stringWithFormat:@" %@ '%@ %2.f' ", str, self[@"TextFont"], [self[@"TextSize"] floatValue]];
        }
        
        textOutputString = [NSString stringWithFormat:@"%@%@%@", textFgString, textBgString, textFontString];
    }
    
    //text encoding
    if ([self[@"TextEncoding"] intValue] != DEFAULT_OUTPUT_TXT_ENCODING) {
        NSString *str = longOpts ? @"-E" : @"--text-encoding";
        textEncodingString = [NSString stringWithFormat:@" %@ %d ", str, [self[@"TextEncoding"] intValue]];
    }
    
    //create custom icon string
    if (![self[@"IconPath"] isEqualToString:CMDLINE_ICON_PATH] && ![self[@"IconPath"] isEqualToString:@""]) {
        NSString *str = longOpts ? @"-i" : @"--app-icon";
        iconParamStr = [NSString stringWithFormat:@"%@ '%@' ", str, self[@"IconPath"]];
    }
    
    //create custom icon string
    if (self[@"DocIcon"] && ![self[@"DocIcon"] isEqualToString:@""]) {
        NSString *str = longOpts ? @"-Q" : @"--document-icon";
        iconParamStr = [iconParamStr stringByAppendingFormat:@" %@ '%@' ", str, self[@"DocIcon"]];
    }
    
    //status menu settings, if output mode is status menu
    if ([self[@"Output"] isEqualToString:@"Status Menu"]) {
        // -K kind
        NSString *str = longOpts ? @"-K" : @"--status-item-kind";
        statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '%@' ", str, self[@"StatusItemDisplayType"]];
        
        // -L /path/to/image
        if (![self[@"StatusItemDisplayType"] isEqualToString:@"Text"]) {
            str = longOpts ? @"-L" : @"--status-item-icon";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '/path/to/image' ", str];
        }
        
        // -Y 'Title'
        if (![self[@"StatusItemDisplayType"] isEqualToString:@"Icon"]) {
            str = longOpts ? @"-Y" : @"--status-item-title";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ '%@' ", str, self[@"StatusItemTitle"]];
        }
        
        // -c
        if ([self[@"StatusItemUseSystemFont"] boolValue]) {
            str = longOpts ? @"-c" : @"--status-item-sysfont";
            statusMenuOptionsString = [statusMenuOptionsString stringByAppendingFormat:@"%@ ", str];
        }
    }
    
    // only set app name arg if we have a proper value
    NSString *appNameArg = @"";
    if ([self[@"Name"] isEqualToString:@""] == FALSE) {
        NSString *str = longOpts ? @"-a" : @"--name";
        appNameArg = [NSString stringWithFormat: @" %@ '%@' ", str,  self[@"Name"]];
    }
    
    // only add identifier argument if it varies from default
    NSString *identifierArg = @"";
    NSString *standardIdentifier = [PlatypusAppSpec bundleIdentifierForAppName:self[@"Name"] authorName:nil usingDefaults: NO];
    if ([self[@"Identifier"] isEqualToString:standardIdentifier] == FALSE) {
        NSString *str = longOpts ? @"-I" : @"--bundle-identifier";
        identifierArg = [NSString stringWithFormat: @" %@ %@ ", str, self[@"Identifier"]];
    }
    
    // output type
    NSString *str = longOpts ? @"-o" : @"--output-type";
    NSString *outputArg = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"Output"]];
    
    // interpreter
    str = longOpts ? @"-p" : @"--interpreter";
    NSString *interpreterArg = [NSString stringWithFormat:@" %@ '%@' ", str, self[@"Interpreter"]];
    
    
    // finally, generate the command
    NSString *commandStr = [NSString stringWithFormat:
                            @"%@ %@%@%@%@%@%@ %@%@%@%@%@%@%@%@%@%@ '%@'",
                            CMDLINE_TOOL_PATH,
                            checkboxParamStr,
                            iconParamStr,
                            appNameArg,
                            outputArg,
                            interpreterArg,
                            authorString,
                            versionString,
                            identifierArg,
                            suffixesString,
                            uniformTypesString,
                            promptForFileString,
                            bundledFilesCmdString,
                            parametersString,
                            textEncodingString,
                            textOutputString,
                            statusMenuOptionsString,
                            self[@"ScriptPath"],
                            nil];
    
    return commandStr;
}

#pragma mark - Class Methods

/*******************************************************************
 - Return the bundle identifier for the application to be generated
 - based on username etc. e.g. org.username.AppName
 ******************************************************************/

+ (NSString *)bundleIdentifierForAppName:(NSString *)appName authorName:(NSString *)authorName usingDefaults:(BOOL)def {
    
    NSString *defaults = def ? [DEFAULTS stringForKey:@"DefaultBundleIdentifierPrefix"] : nil;
    NSString *author = authorName ? [authorName stringByReplacingOccurrencesOfString:@" " withString:@""] : NSUserName();
    NSString *pre = defaults == nil ? [NSString stringWithFormat:@"org.%@.", author] : defaults;
    NSString *bundleId = [NSString stringWithFormat:@"%@%@", pre, appName];
    bundleId = [bundleId stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    return bundleId;
}

+ (void)optimizeNibFile:(NSString *)nibPath {
    NSTask *ibToolTask = [[NSTask alloc] init];
    [ibToolTask setLaunchPath:IBTOOL_PATH];
    [ibToolTask setArguments:@[@"--strip", nibPath, nibPath]];
    [ibToolTask launch];
    [ibToolTask waitUntilExit];
    [ibToolTask release];
}

@end
