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
- Python

Notes
-----
Current implementation should be easy to adapt to any language using fix indentation (like the python language). For other languages, we would need to rely on another mecanism (micro has built-in syntax analysis, not sure how we can access it from the plugin).

TODO
----
- Add proper documentation to navbar.
- In addition to displaying the tree in the left panel, we need to provide a function that translate a line + action (+, -, ENTER) into a action for the script (open, fold, close). We will need to keep the tree in memory to set the open/close values of the nodes.
- We need to keep the configuration of the side (buffer + main buffer) somewhere so that we can use it for updates (avoid opening a side buffer for a side buffer, etc.).
- Add tests about having part of a tree open/closed.
- Provide an interface to add support for more languages (make sure navbar_python only contains python-specific methods)
- Add actions (keyboard, mouse) to items in the left pane (goto, open, close).
- Setup sane default (all open, all closed, level1 open).
