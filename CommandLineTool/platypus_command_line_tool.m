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

/*
 Support files required for this program are defined in Common.h
 */

#import <Cocoa/Cocoa.h>

#import "Common.h"
#import "PlatypusAppSpec.h"

#import <stdio.h>
#import <unistd.h>
#import <errno.h>
#import <sys/stat.h>
#import <limits.h>
#import <string.h>
#import <fcntl.h>
#import <errno.h>
#import <getopt.h>

static NSString *MakeAbsolutePath(NSString *path);
static void PrintVersion(void);
static void PrintHelp(void);
static void NSPrintErr(NSString *format, ...);
static void NSPrint(NSString *format, ...);

static const char optstring[] = "P:f:a:o:i:u:p:V:I:Q:ASOZDBRFNydlvhxX:T:G:C:b:g:n:E:K:Y:L:cU:";

static struct option long_options[] = {

    {"generate-profile",          no_argument,        0, 'O'},

    {"load-profile",              required_argument,  0, 'P'},
    {"name",                      required_argument,  0, 'a'},
    {"output-type",               required_argument,  0, 'o'},
    {"interpreter",               required_argument,  0, 'p'},

    {"app-icon",                  required_argument,  0, 'i'},
    {"author",                    required_argument,  0, 'u'},
    {"document-icon",             required_argument,  0, 'Q'},
    {"app-version",               required_argument,  0, 'V'},
    {"bundle-identifier",         required_argument,  0, 'I'},

    {"admin-privileges",          no_argument,        0, 'A'},
    {"secure-script",             no_argument,        0, 'S'},
    {"droppable",                 no_argument,        0, 'D'},
    {"text-droppable",            no_argument,        0, 'F'},
    {"file-prompt",               no_argument,        0, 'Z'},
    {"service",                   no_argument,        0, 'N'},
    {"background",                no_argument,        0, 'B'},
    {"quit-after-execution",      no_argument,        0, 'R'},

    {"text-background-color",     required_argument,  0, 'b'},
    {"text-foreground-color",     required_argument,  0, 'g'},
    {"text-font",                 required_argument,  0, 'n'},
    {"text-encoding",             required_argument,  0, 'E'},
    {"suffixes",                  required_argument,  0, 'X'},
    {"uniform-type-identifiers",  required_argument,  0, 'T'},
    {"interpreter-args",          required_argument,  0, 'G'},
    {"script-args",               required_argument,  0, 'C'},

    {"status-item-kind",          required_argument,  0, 'K'},
    {"status-item-title",         required_argument,  0, 'Y'},
    {"status-item-icon",          required_argument,  0, 'L'},
    {"status-item-sysfont",       no_argument,        0, 'c'},

    {"bundled-file",              required_argument,  0, 'f'},

    {"xml-property-lists",        no_argument,        0, 'x'},
    {"force",                     no_argument,        0, 'y'},
    {"development-version",       no_argument,        0, 'd'},
    {"optimize-nib",              no_argument,        0, 'l'},
    {"help",                      no_argument,        0, 'h'},
    {"version",                   no_argument,        0, 'v'},
    
    {0,                           0,                  0,  0 }
};

#ifdef DEBUG
void exceptionHandler(NSException *exception);
void exceptionHandler(NSException *exception) {
    NSLog(@"%@", [exception reason]);
    NSLog(@"%@", [exception userInfo]);
    NSLog(@"%@", [exception callStackReturnAddresses]);
    NSLog(@"%@", [exception callStackSymbols]);
}
#endif

int main(int argc, const char *argv[]) {
    
#ifdef DEBUG
    NSSetUncaughtExceptionHandler(&exceptionHandler);
#endif
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; //set up autorelease pool
    NSFileManager *fm = FILEMGR;
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    BOOL createProfile = FALSE;
    BOOL loadedProfile = FALSE;
    BOOL deleteScript = FALSE;
    
    int optch;
    int long_index = 0;
    while ((optch = getopt_long(argc, (char *const *)argv, optstring, long_options, &long_index)) != -1) {
        
        switch (optch) {

            // create a profile instead of an app
            case 'O':
            {
                createProfile = TRUE;
            }
                break;

            // load profile
            case 'P':
            {
                NSString *profilePath = MakeAbsolutePath(@(optarg));
                
                // error if profile doesn't exists, warn if w/o profile suffix
                if (![fm fileExistsAtPath:profilePath]) {
                    NSPrintErr(@"Error: No profile found at path '%@'.", profilePath);
                    exit(1);
                }
                
                // read profile dictionary from file
                NSDictionary *profileDict = [NSDictionary dictionaryWithContentsOfFile:profilePath];
                if (profileDict == nil) {
                    NSPrintErr(@"Error loading profile '%@'.", profilePath);
                    exit(1);
                }
                
                // warn if created by different version
                if (![profileDict[@"Creator"] isEqualToString:PROGRAM_STAMP]) {
                    NSPrintErr(@"Warning: Profile created with different version of %@.", PROGRAM_NAME);
                }
                
                // add entries in profile to app properties, overwriting any former values
                [properties addEntriesFromDictionary:profileDict];
                loadedProfile = TRUE;
            }
                break;

            // app name
            case 'a':
                properties[@"Name"] = @(optarg);
                break;

            // bundled file -- flag can be passed multiple times to include more than one bundled file
            case 'f':
            {
                NSString *filePath = MakeAbsolutePath(@(optarg));
                
                // make sure file exists
                if (![fm fileExistsAtPath:filePath]) {
                    NSPrintErr(@"Error: No file exists at path '%@'", filePath);
                    exit(1);
                }
                
                // create bundled files array entry in properties if it doesn't already exist
                if (properties[@"BundledFiles"] == nil) {
                    properties[@"BundledFiles"] = [NSMutableArray array];
                }
                
                // add file argument to it
                [properties[@"BundledFiles"] addObject:filePath];
            }
                break;
                
            // output type
            case 'o':
            {
                NSString *outputType = @(optarg);
                if ([PLATYPUS_OUTPUT_TYPE_NAMES containsObject:outputType] == NO) {
                    NSPrintErr(@"Error: Invalid output type '%@'.  Valid types are: %@",
                               outputType, [PLATYPUS_OUTPUT_TYPE_NAMES description]);
                    exit(1);
                }
                properties[@"Output"] = @(optarg);
            }
                break;

            // background color of text output
            case 'b':
            {
                NSString *hexColorStr = @(optarg);
                if ([hexColorStr length] != 7 || [hexColorStr characterAtIndex:0] != '#') {
                    NSPrintErr(@"Error: '%@' is not a valid color hex value.  Must be 6 digit hexadecimal, e.g. #aabbcc", hexColorStr);
                    exit(1);
                }
                properties[@"TextBackground"] = @(optarg);
            }
                break;
                
            // foreground color of text output
            case 'g':
            {
                NSString *hexColorStr = @(optarg);
                if ([hexColorStr length] != 7 || [hexColorStr characterAtIndex:0] != '#') {
                    NSPrintErr(@"Error: '%@' is not a valid color hex value.  Must be 6 digit hexadecimal, e.g. #aabbcc", hexColorStr);
                    exit(1);
                }
                properties[@"TextForeground"] = @(optarg);
            }
                break;
                
            // font and size of text output
            case 'n':
            {
                NSString *fontStr = @(optarg);
                NSMutableArray *words = [NSMutableArray arrayWithArray:[fontStr componentsSeparatedByString:@" "]];
                if ([words count] < 2) {
                    NSPrintErr(@"Error: '%@' is not a valid font.  Must be fontname followed by size, e.g. 'Monaco 10'", fontStr);
                    exit(1);
                }
                // parse string for font name and size, and set it in properties
                float fontSize = [[words lastObject] floatValue];
                [words removeLastObject];
                NSString *fontName = [words componentsJoinedByString:@" "];
                properties[@"TextFont"] = fontName;
                properties[@"TextSize"] = @(fontSize);
            }
                break;
                
            // text encoding to use
            case 'E':
            {
                NSString *encNumStr = @(optarg);
                int textEncoding = [encNumStr intValue];
                if (textEncoding <= 0) {
                    NSPrintErr(@"Error: Invalid text encoding specified");
                    exit(1);
                }
                properties[@"TextEncoding"] = @(textEncoding);
            }
                break;
                
            // author
            case 'u':
                properties[@"Author"] = @(optarg);
                break;
                
            // icon
            case 'i':
            {
                NSString *iconPath = @(optarg);
                
                // empty icon path means just default app icon, otherwise a path to an icns file
                if ([iconPath isEqualTo:@""] == NO) {
                    iconPath = MakeAbsolutePath(iconPath);
                    // if we have proper arg, make sure file exists
                    if ([fm fileExistsAtPath:iconPath] == NO) {
                        NSPrintErr(@"Error: No icon file exists at path '%@'", iconPath);
                        exit(1);
                    }
                    
                    // warn if file doesn't seem to be icns
                    NSString *fileType = [WORKSPACE typeOfFile:iconPath error:nil];
                    if ([WORKSPACE type:fileType conformsToType:(NSString *)kUTTypeAppleICNS] == FALSE) {
                        NSPrintErr(@"Warning: '%@' does not appear to be an Apple .icns file", iconPath);
                    }
                }
                properties[@"IconPath"] = iconPath;
            }
                break;
                
            // document icon
            case 'Q':
            {
                NSString *iconPath = @(optarg);
                
                // empty icon path means just default app icon, otherwise a path to an icns file
                if (![iconPath isEqualTo:@""]) {
                    iconPath = MakeAbsolutePath(iconPath);
                    // if we have proper arg, make sure file exists
                    if (![fm fileExistsAtPath:iconPath]) {
                        NSPrintErr(@"Error: No icon file exists at path '%@'", iconPath);
                        exit(1);
                    }
                    
                    // warn if file doesn't seem to be icns
                    NSString *fileType = [WORKSPACE typeOfFile:iconPath error:nil];
                    if ([WORKSPACE type:fileType conformsToType:(NSString *)kUTTypeAppleICNS] == FALSE) {
                        NSPrintErr(@"Warning: '%@' not identified as an Apple .icns file", iconPath);
                    }
                }
                properties[@"DocIcon"] = iconPath;
            }
                break;
                
            // interpreter
            case 'p':
            {
                NSString *interpreterPath = MakeAbsolutePath(@(optarg));
                if (![fm fileExistsAtPath:interpreterPath]) {
                    NSPrintErr(@"Warning: Interpreter path '%@' invalid - no file at path.", interpreterPath);
                }
                
                properties[@"Interpreter"] = interpreterPath;
            }
                break;
                
            // version
            case 'V':
                properties[@"Version"] = @(optarg);
                break;
                
            // identifier
            case 'I':
                properties[@"Identifier"] = @(optarg);
                break;
                
            // checkbox options
            case 'A':
                properties[@"Authentication"] = @YES;
                break;
                
            case 'S':
                properties[@"Secure"] = @YES;
                break;
                
            case 'D':
                properties[@"Droppable"] = @YES;
                properties[@"AcceptsFiles"] = @YES;
                break;
                
            case 'F':
                properties[@"Droppable"] = @YES;
                properties[@"AcceptsText"] = @YES;
                break;
                
            case 'N':
                properties[@"DeclareService"] = @YES;
                break;
                
            case 'B':
                properties[@"ShowInDock"] = @YES;
                break;
                
            case 'R':
                properties[@"RemainRunning"] = @NO;
                break;
                
            case 'x':
                properties[@"UseXMLPlistFormat"] = @YES;
                break;
                
            // suffixes
            case 'X':
            {
                NSString *suffixesStr = @(optarg);
                NSArray *suffixes = [suffixesStr componentsSeparatedByString:@"|"];
                properties[@"Suffixes"] = suffixes;
            }
                break;
                
            // uniform type identifiers
            case 'T':
            {
                NSString *utiStr = @(optarg);
                NSArray *utis = [utiStr componentsSeparatedByString:@"|"];
                properties[@"UniformTypes"] = utis;
            }
                break;
            
            // prompt for file on startup
            case 'Z':
                properties[@"PromptForFileOnLaunch"] = @YES;
                break;
                
            // arguments for interpreter
            case 'G':
            {
                NSString *parametersString = @(optarg);
                NSArray *parametersArray = [parametersString componentsSeparatedByString:@"|"];
                properties[@"InterpreterArgs"] = parametersArray;
            }
                break;
                
            // arguments for script
            case 'C':
            {
                NSString *parametersString = @(optarg);
                NSArray *parametersArray = [parametersString componentsSeparatedByString:@"|"];
                properties[@"ScriptArgs"] = parametersArray;
            }
                break;
                
            // force overwrite mode
            case 'y':
                properties[@"DestinationOverride"] = @YES;
                break;
                
            // development version, symlink to script
            case 'd':
                properties[@"DevelopmentVersion"] = @YES;
                break;
                
            // optimize application by stripping/compiling nib files
            case 'l':
                properties[@"OptimizeApplication"] = @YES;
                break;
                
            // set display kind for Status Menu output
            case 'K':
            {
                NSString *kind = @(optarg);
                if (![kind isEqualToString:@"Text"] && ![kind isEqualToString:@"Icon"] && ![kind isEqualToString:@"Icon and Text"]) {
                    NSPrintErr(@"Error: Invalid status item kind '%@'", kind);
                    exit(1);
                }
                properties[@"StatusItemDisplayType"] = kind;
            }
                break;
                
            // set title of status item for Status Menu output
            case 'Y':
            {
                NSString *title = @(optarg);
                if ([title isEqualToString:@""] || title == nil) {
                    NSPrintErr(@"Error: Empty status item title");
                    exit(1);
                }
                properties[@"StatusItemTitle"] = title;
            }
                break;
                
            // set if Status Menu uses system font
            case 'c':
                properties[@"StatusItemUseSystemFont"] = @YES;
                break;
                
            // set icon image of status item for Status Menu output
            case 'L':
            {
                NSString *iconPath = MakeAbsolutePath(@(optarg));
                if (![fm fileExistsAtPath:iconPath]) {
                    NSPrintErr(@"Error: No image file exists at path '%@'", iconPath);
                    exit(1);
                }
                
                // read image from file
                NSImage *iconImage = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
                if (iconImage == nil) {
                    NSPrintErr(@"Error: Unable to get image from file '%@'", iconPath);
                    exit(1);
                }
                properties[@"StatusItemIcon"] = [iconImage TIFFRepresentation];
            }
                break;
                
            // print version
            case 'v':
            {
                PrintVersion();
                exit(0);
            }
                break;
                
            // print help with list of options
            case 'h':
            default:
            {
                PrintHelp();
                exit(0);
            }
                break;
        }
    }
    
    // we always need one more argument, either script file path or app name
    if (argc - optind < 1) {
        NSPrintErr(@"Error: Missing argument");
        PrintHelp();
        exit(1);
    }    
    
    PlatypusAppSpec *appSpec = nil;
    NSString *scriptPath = nil;
    NSString *destPath = nil;
    
    // read remaining args as paths
    NSMutableArray *remainingArgs = [NSMutableArray array];
    while (optind < argc) {
        NSString *argStr = @(argv[optind]);
        if (![argStr isEqualToString:@"-"]) {
            argStr = MakeAbsolutePath(argStr);
        }
        [remainingArgs addObject:argStr];
        optind += 1;
    }
    
    if (createProfile) {
        BOOL printStdout = FALSE;
        destPath = remainingArgs[0];
        
        // append .platypus suffix to destination file if not user-specified
        if ([destPath isEqualToString:@"-"] ) {
            printStdout = TRUE;
        } else if (![destPath hasSuffix:@".platypus"]) {
            NSPrintErr(@"Warning: Appending .platypus extension");
            destPath = [destPath stringByAppendingString:@".platypus"];
        }
        
        // we then dump the profile dictionary to path and exit
        appSpec = [PlatypusAppSpec specWithDefaults];
        [appSpec addEntriesFromDictionary:properties];
        
        printStdout ? [appSpec dump] : [appSpec writeToFile:destPath];
        
        exit(0);
    }
    // if we loaded a profile, the first remaining arg is destination path, others ignored
    else if (loadedProfile) {
        destPath = remainingArgs[0];
        if (![destPath hasSuffix:@".app"]) {
            destPath = [destPath stringByAppendingString:@".app"];
        }
        appSpec = [PlatypusAppSpec specWithDefaults];
        [appSpec addEntriesFromDictionary:properties];
        appSpec[@"Destination"] = destPath;
    }
    // if we're creating an app, first argument must be script path, second (optional) argument is destination
    else {
        // get script path, generate default app name
        scriptPath = remainingArgs[0];
        
        // a script path of "-" means read from STDIN
        if ([scriptPath isEqualToString:@"-"]) {
            // read data
            NSData *inData = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
            if (inData == nil) {
                NSPrintErr(@"Empty buffer, aborting.");
                exit(1);
            }
            
            // convert to string
            NSString *inStr = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
            if (inStr == nil) {
                NSPrintErr(@"Cannot handle non-text data.");
                exit(1);
            }
            
            // write to temp file
            NSError *err;
            BOOL success = [inStr writeToFile:TMP_STDIN_PATH atomically:YES encoding:DEFAULT_OUTPUT_TXT_ENCODING error:&err];
            [inStr release];
            if (success == NO) {
                NSPrintErr(@"Error writing script to path %: %@", TMP_STDIN_PATH, [err localizedDescription]);
                exit(1);
            }
            
            // set temp file as script path
            scriptPath = TMP_STDIN_PATH;
            deleteScript = YES;
        }
        else if ([fm fileExistsAtPath:scriptPath] == NO) {
            NSPrintErr(@"Error: No script file exists at path '%@'", scriptPath);
            exit(1);
        }
        
        appSpec = [PlatypusAppSpec specWithDefaultsFromScript:scriptPath];
        if (properties[@"Name"] != nil) {
            NSString *appBundleName = [NSString stringWithFormat:@"%@.app", properties[@"Name"]];
            NSString *scriptFolder = [scriptPath stringByDeletingLastPathComponent];
            destPath = [scriptFolder stringByAppendingPathComponent:appBundleName];
            appSpec[@"Destination"] = destPath;
        }
        [appSpec addEntriesFromDictionary:properties];
        
        // if author name is supplied but no identifier, we create a default identifier with author name as clue
        if (properties[@"Author"] && properties[@"Identifier"] == nil) {
            NSString *identifier = [PlatypusAppSpec bundleIdentifierForAppName:appSpec[@"Name"]
                                                                    authorName:properties[@"Author"]
                                                                 usingDefaults:NO];
            if (identifier) {
                appSpec[@"Identifier"] = identifier;
            }
        }
        
        // if there's another argument after the script path, it means a destination path has been specified
        if ([remainingArgs count] > 1) {
            destPath = remainingArgs[1];
            appSpec[@"Destination"] = destPath;
        }
    }
    
    NSString *path = appSpec[@"ScriptPath"];
    if (path == nil || [path isEqualToString:@""]) {
        NSPrintErr(@"Error: Missing script path.");
        exit(1);
    }
    
    // create the app from spec
    if ([appSpec verify] == NO || [appSpec create] == NO) {
        NSPrintErr(@"Error: %@", [appSpec error]);
        exit(1);
    }
    
    // if script was temporary file created from stdin, we remove it
    if (deleteScript) {
        [FILEMGR removeItemAtPath:scriptPath error:nil];
    }
    
    [pool drain];
    
    return 0;
}

#pragma mark -

static NSString *MakeAbsolutePath(NSString *path) {
    path = [path stringByExpandingTildeInPath];
    if ([path isAbsolutePath] == NO) {
        path = [[FILEMGR currentDirectoryPath] stringByAppendingPathComponent:path];
    }
    return [path stringByStandardizingPath];
}

#pragma mark -

static void PrintVersion(void) {
    NSPrint(@"%@ version %@ by %@", CMDLINE_PROGNAME, PROGRAM_VERSION, PROGRAM_AUTHOR);
}

static void PrintHelp(void) {
    PrintVersion();
    
    NSPrint(@"\n\
            Options:\n\
            -O --generate-profile                Generate a profile instead of an app\n\
            \n\
            -P --load-profile [profilePath]      Load settings from profile document\n\
            -a --name [name]                     Set name of application bundle\n\
            -o --output-type [type]              Set output type.  See man page for accepted types\n\
            -p --interpreter [interpreterPath]   Set interpreter for script\n\
            \n\
            -i --app-icon [iconPath]             Set icon for application\n\
            -u --author [author]                 Set name of application author\n\
            -Q --document-icon [iconPath]        Set icon for documents\n\
            -V --app-version [version]           Set version of application\n\
            -I --bundle-identifier [identifier]  Set bundle identifier (i.e. org.yourname.appname)\n\
            \n\
            -A --admin-privileges                App runs with Administrator privileges\n\
            -S --secure-script                   Secure bundled script\n\
            -D --droppable                       App accepts dropped files as argument to script\n\
            -F --text-droppable                  App accepts dropped text as argument to script\n\
            -Z --file-prompt                     App presents Open file dialog once launched\n\
            -N --service                         App registers as a Mac OS X Service\n\
            -B --background                      App runs in background (LSUIElement)\n\
            -R --quit-after-execution            App quits after executing script\n\
            \n\
            -b --text-background-color [color]   Set background color of text output (e.g. '#ffffff')\n\
            -g --text-foreground-color [color]   Set foreground color of text output (e.g. '#000000')\n\
            -n --text-font [fontName]            Set font for text output field (e.g. 'Monaco 10')\n\
            -E --text-encoding [encoding]        Set text encoding for script output (see man page)\n\
            -X --suffixes [suffixes]             Set suffixes handled by application, separated by |\n\
            -T --uniform-type-identifiers        Set uniform type identifiers handled by application, separated by |\n\
            -G --interpreter-args [arguments]    Set arguments for script interpreter, separated by |\n\
            -C --script-args [arguments]         Set arguments for script, separated by |\n\
            \n\
            -K --status-item-kind [kind]         Set Status Item kind ('Icon','Text', 'Icon and Text')\n\
            -Y --status-item-title [title]       Set title of Status Item\n\
            -L --status-item-icon [imagePath]    Set icon of Status Item\n\
            -c --status-item-sysfont             Make Status Item use system font for menu\n\
            \n\
            -f --bundled-file [filePath]         Add a bundled file\n\
            \n\
            -x --xml-property-lists              Create XML property lists instead of binary\n\
            -y --force                           Force mode.  Overwrite any files/folders in path\n\
            -d --development-version             Development version.  Symlink to script instead of copying\n\
            -l --optimize-nib                    Optimize application.  Strip and compile bundled nib file\n\
            -h --help                            Prints help\n\
            -v --version                         Prints program name, version and author\n\n\
See 'man platypus' or %@ for further details.", PROGRAM_MANPAGE_URL);
}

#pragma mark -

// print to stdout
static void NSPrint(NSString *format, ...) {
    va_list args;
    
    va_start(args, format);
    NSString *string  = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    fprintf(stdout, "%s\n", [string UTF8String]);
    
    [string release];
}

// print to stderr
static void NSPrintErr(NSString *format, ...) {
    va_list args;
    
    va_start(args, format);
    NSString *string  = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    fprintf(stderr, "%s\n", [string UTF8String]);
    
    [string release];
}
