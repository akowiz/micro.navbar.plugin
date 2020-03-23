# Micro Navbar Plugin

*Written in Lua* (Notes: micro seems to be using lua-5.1 and not the latest lua version lua-5.3)

Navigation bar (class and functions) for micro editor.

There are 3 styles defined to display the tree: 'bare', 'ascii' and 'box'

* 'bare' style *

v Classes               > Classes
  v TestClass1            > TestClass1
    . __init__            . TestClass2
    . __str__           > Functions
  . TestClass2          > Variables
v Functions
  . TestFunction
v Variables
  . TestVariable


* 'ascii' style *

- Classes               - Classes
  - TestClass1            + TestClass1
  | . __init__            L TestClass2
  | L __str__           + Functions
  L TestClass2          + Variables
- Functions
  L TestFunction
- Variables
  L TestVariable


* 'box' style *

▾ Classes               ▾ Classes
  ├ TestClass1            ╞ TestClass1
  │ ├ __init__            └ TestClass2
  │ └ __str__           ▸ Functions
  └ TestClass2          ▸ Variables
▾ Functions
  └ TestFunction
▾ Variables
  └ TestVariable


Supported Languages
-------------------
- Python: Python is a fairly rigid programming language (use of indentation, etc.) and I wrote a line parser for it that should work in most situations.

- Lua : Lua is a fairly flexible programming language. It supports object oriented programming but not at the language level (meaning there are multiple ways to implement classes). So, I resorted to write a line parser (a bit of a hack) and it should work as long as your write "clean" code (if your code looks more like python actually). It will "break" (not display all data) if your program looks like the result of a minifier (a program on a single line) or if you use inner functions. I needed to support lua for my own development process (so I build the minimum to support my needs).

Settings
--------
- openonstart: bool (true or false), set to true to open when micro is open. Default to false.
- treestyle: string ('bare', 'ascii', 'box'), the style to use to display the tree. Default to 'bare'.
- treestyle_spacing: int (0, 1, etc.), the number of extra-characters to use for the tree branch. Default to 0.
- softwrap: bool (true or false), set to true to use wrapping in the treeview window. Default to false.
- treeview_rune_open: string (single letter), the key to use in the tree_view to open a node that is closed. Default to '+'.
- treeview_rune_close: string (single letter), the key to use in the tree_view to open a node that is closed. Default to '-'.
- treeview_rune_goto: string (single letter), the key to use in the tree_view to move the cursor in the main_view to the corresponding item. Default to ' '.

Notes
-----
Current implementation should be easy to adapt to any language using fix indentation (like the python language). For other languages, we would need to rely on another mecanism (micro has built-in syntax analysis, not sure how we can access it from the plugin).

BUGS
----
- Error if micro is not run from the development folder (this is a big issue) because extra modules (generic, etc.) can not be found.

TODO
----
- Properly handle when the screen has been splitted already.
- Add ability to save the open/close status in between sessions (using json to store the data?)
- Add proper documentation to navbar.
- In addition to displaying the tree in the left panel, we need to provide a function that translate a line + action (+, -, ENTER) into a action for the script (open, fold, close). We will need to keep the tree in memory to set the open/close values of the nodes.
- We need to keep the configuration of the side bp:ID() (buffer + main buffer and tabs) somewhere so that we can use it for updates (avoid opening a side buffer for a side buffer, etc.).
- Write a proper parser to extract objects, classes, functions, variables, constants with depth