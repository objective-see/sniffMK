# sniffMK
`sniffMK` is a simple utility designed to sniff mouse and keyboard events on macOS. It is based on code from amit singh's website; (http://osxbook.com)

It was designed to facilitate malware analysis (specifically OSX/FruitFly which can simulate both mouse and keyboard events - see BlackHat/DefCon [slides](https://speakerdeck.com/patrickwardle/fruitfly-via-a-custom-c-and-c-server?slide=18) for details). 

Run `sniffMK`, as root, to start sniffing events:
```
# ./sniffMK
mouse/keyboard sniffer
based on code from amit singh (http://osxbook.com)

event: left mouse down
x: 821.285156
y: 727.726562

event: left mouse up
x: 821.285156
y: 727.726562

event: key down
key modifiers: shift 
keycode: 0x4/h

event: key up
keycode: 0x4/h

event: key down
keycode: 0x22/i

event: key up
keycode: 0x22/i

....

event: key down
key modifiers: control 
keycode: 0x8/c
```
To only capture mouse events, execute `sniffMK` with the `-mouse` commandline argument.<br>
Similarly, execute it with the `-keyboard` commandline argument to only capture keyboard events.
  
