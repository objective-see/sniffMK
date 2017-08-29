//
//  File: sniff.m
//  Project: sniffM&K
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//
//  Compile:
//   a) Xcode, Product->Build
//
//   or ...
//
//   b) $ clang -o sniffMK sniffMK.m -framework Cocoa -framework Carbon
//
//   Run (as root):
//   # ./sniffMK
//
//  Notes:
//   a) code, largely based on altermouse.c/alterkeys.c (amit singh/http://osxbook.com)
//   b) run with '-mouse' for just mouse events or '-keyboard' for just key events
//

#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

//event tap
static CFMachPortRef eventTap = NULL;

//map a printable keycode to a string
// ->code based on: https://stackoverflow.com/a/33584460
NSString* keyCodeToString(CGEventRef event, CGEventType type)
{
    //keycode as string
    NSString* keyCodeAsString = nil;
    
    //status
    OSStatus status = !noErr;
    
    //(key) code
    CGKeyCode keyCode = 0;
    
    //keyboard layout data
    CFDataRef keylayoutData = NULL;
    
    //keyboard layout
    const UCKeyboardLayout* keyboardLayout = NULL;
    
    //key action
    UInt16 keyAction = 0;
    
    //modifer state
    UInt32 modifierState = 0;
    
    //dead key
    UInt32 deadKeyState = 0;
    
    //max length
    UniCharCount maxStringLength = 255;
    
    //actual lenth
    UniCharCount actualStringLength = 0;
    
    //string
    UniChar unicodeString[maxStringLength];
    
    //zero out
    memset(unicodeString, 0x0, sizeof(unicodeString));
    
    //get code
    keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
    //get key layout data
    keylayoutData = (CFDataRef)TISGetInputSourceProperty(TISCopyCurrentKeyboardInputSource(), kTISPropertyUnicodeKeyLayoutData);
    if(NULL == keylayoutData)
    {
        //bail
        goto bail;
    }
    
    //get keyboard layout
    keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(keylayoutData);
    if(NULL == keyboardLayout)
    {
        //bail
        goto bail;
    }
    
    //set key action down
    if(kCGEventKeyDown == type)
    {
        //down
        keyAction = kUCKeyActionDown;
    }
    //set key action up
    else
    {
        //up
        keyAction = kUCKeyActionUp;
    }
    
    //TODO:
    // set modifierState based on event flags?
    
    //translate
    status = UCKeyTranslate(keyboardLayout, keyCode, keyAction, modifierState, LMGetKbdType(), 0, &deadKeyState, maxStringLength, &actualStringLength, unicodeString);
    if( (noErr != status) ||
        (0 == actualStringLength) )
    {
        //bail
        goto bail;
    }

    //init string
    keyCodeAsString = [[NSString stringWithCharacters:unicodeString length:(NSUInteger)actualStringLength] lowercaseString];
    
bail:
    
    return keyCodeAsString;
}

//build string of key modifiers (shift, command, etc)
// ->code based on: https://stackoverflow.com/a/4425180/3854841
NSMutableString* extractKeyModifiers(CGEventRef event)
{
    //key modify(ers)
    NSMutableString* keyModifiers = nil;
    
    //flags
    CGEventFlags flags = 0;
    
    //alloc
    keyModifiers = [NSMutableString string];
    
    //get flags
    flags = CGEventGetFlags(event);
    
    //control
    if(YES == !!(flags & kCGEventFlagMaskControl))
    {
        //add
        [keyModifiers appendString:@"control "];
    }
    
    //alt
    if(YES == !!(flags & kCGEventFlagMaskAlternate))
    {
        //add
        [keyModifiers appendString:@"alt "];
    }
    
    //command
    if(YES == !!(flags & kCGEventFlagMaskCommand))
    {
        //add
        [keyModifiers appendString:@"command "];
    }
    
    //shift
    if(YES == !!(flags & kCGEventFlagMaskShift))
    {
        //add
        [keyModifiers appendString:@"shift "];
    }
    
    //caps lock
    if(YES == !!(flags & kCGEventFlagMaskAlphaShift))
    {
        //add
        [keyModifiers appendString:@"caps lock "];
    }
    
    return keyModifiers;
}

//callback for mouse/keyboard events
// ->for now, just format, then print the event to stdout
CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    //(mouse) location
    CGPoint location = {0};
    
    //(key) code
    CGKeyCode keyCode = 0;
    
    //key modify(ers)
    NSMutableString* keyModifiers = nil;

    //dbg msg
    printf("event: ");
    
    //what type?
    // ->pretty print
    switch(type)
    {
        //left mouse down
        case kCGEventLeftMouseDown:
            printf("left mouse down\n");
            break;
            
        //left mouse up
        case kCGEventLeftMouseUp:
            printf("left mouse up\n");
            break;
            
        //right mouse down
        case kCGEventRightMouseDown:
            printf("right mouse down\n");
            break;
            
        //right mouse up
        case kCGEventRightMouseUp:
            printf("right mouse up\n");
            break;
            
        /*
        case kCGEventMouseMoved:
            printf("kCGEventMouseMoved\n");
            break;
        */
            
        //left mouse dragged
        case kCGEventLeftMouseDragged:
            printf("left mouse dragged\n");
            break;
            
        //right mouse dragged
        case kCGEventRightMouseDragged:
            printf("right mouse dragged\n");
            break;
            
        //key down
        case kCGEventKeyDown:
            
            //get key modifiers
            keyModifiers = extractKeyModifiers(event);
            
            printf("key down\n");
            break;
            
        //key up
        case kCGEventKeyUp:
            printf("key up\n");
            break;
        
        // event tap timeout
        case kCGEventTapDisabledByTimeout:
            CGEventTapEnable(eventTap, true);
            printf("Event tap timed out: restarting tap");
            return event;
        
        default:
            printf("unknown (%d)\n", type);
    }
    
    //for key presses
    // ->dump extra info
    if( (kCGEventKeyDown == type) || (kCGEventKeyUp == type) )
    {
        //get code
        keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        //any key modifiers?
        if(0 != keyModifiers.length)
        {
            //dbg msg
            printf("key modifiers: %s\n", keyModifiers.UTF8String);
        }
        
        //dbg msg
        printf("keycode: %#x/%d/%s\n\n", keyCode, keyCode, keyCodeToString(event, type).UTF8String);
    }
    
    //for mouse
    // ->print location
    else
    {
        //get location
        location = CGEventGetLocation(event);
        
        //dbg msg
        printf("(x: %f, y: %f)\n\n", location.x, location.y);
    }
    
    return event;
}

//main interface
// ->parse args, then sniff (forever)
int main(int argc, const char * argv[])
{
    //event mask
    // ->events to sniff
    CGEventMask eventMask = 0;
    
    //run loop source
    CFRunLoopSourceRef runLoopSource = NULL;

    //pool
    @autoreleasepool
    {
        //dbg msg
        printf("mouse/keyboard sniffer\nbased on code from amit singh (http://osxbook.com)\n\n");
        
        //gotta be r00t
        // unless this program has been added to 'Security & Privacy' -> 'Accessibility'
        if(0 != geteuid())
        {
            //err msg/bail
            printf("ERROR: run as root\n\n");
            goto bail;
        }
        
        //'-mouse'
        // ->just sniff mouse
        if( (2 == argc) &&
            (0 == strcmp(argv[1], "-mouse")) )
        {
            //dbg msg
            printf("initializing event mask for 'mouse' events\n");
            
            //init event mask with mouse events
            // ->add 'CGEventMaskBit(kCGEventMouseMoved)' if you want to also capture (noisy) mouse move events
            eventMask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp) |
                        CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged);

        }
        
        //'-keyboard'
        // ->just sniff keyboard
        else if( (2 == argc) &&
                 (0 == strcmp(argv[1], "-keyboard")) )
        {
            //dbg msg
            printf("initializing event mask for 'keyboard' events\n");
            
            //init event mask with mouse events
            // ->add 'CGEventMaskBit(kCGEventMouseMoved)' for mouse move events
            eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
            
        }
        
        //sniff both!
        else
        {
            //dbg msg
            printf("initializing event mask for both 'mouse' and 'keyboard' events\n");
            
            //init event with mouse events & key presses
            eventMask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp) |
                        CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
            
        }
        
        //create event tap
        eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, eventCallback, NULL);
        if(NULL == eventTap)
        {
            //err msg/bail
            printf("ERROR: failed to create event tap\n");
            goto bail;
        }
        
        //dbg msg
        printf("created event tap\n");
        
        //run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        
        //add to current run loop.
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        
        //enable tap
        CGEventTapEnable(eventTap, true);
        
        //dbg msg
        printf("enabled event tap to commence sniffing\n\n");
        
        //go, go, go
        CFRunLoopRun();
    }
    
bail:
    
    //release event tap
    if(NULL != eventTap)
    {
        //release
        CFRelease(eventTap);
        
        //unset
        eventTap = NULL;
    }
    
    //release run loop src
    if(NULL != runLoopSource)
    {
        //release
        CFRelease(runLoopSource);
        
        //unset
        runLoopSource = NULL;
    }
    
    return 0;
}
