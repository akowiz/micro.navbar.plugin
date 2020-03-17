# Micro Navbar Plugin

*Written in Lua*

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
- Rename T_CONSTANT into T_VARIABLE
- Split the function about displaying a tree into a different module. Write it in a generic way so that it can handle more cases (the notion open/closed if the field is present, children in a different field, etc.)
- Provide an interface to add support for more languages (make sure navbar_python only contains python-specific methods)
- Write functional test and unit test for the export of the python structure from the buffer.
- Display the python structure in the left pane.
- Add actions (keyboard, mouse) to items in the left pane (goto, open, close).
- Setup sane default (all open, all closed, level1 open).
