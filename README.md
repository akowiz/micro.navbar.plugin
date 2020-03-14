# Micro Navbar Plugin

*Written in Lua*

Navigation bar (class and functions) for micro editor.


Supported Languages
-------------------
- Python

Notes
-----
Current implementation should be easy to adapt to any language using fix indentation (like the python language). For other languages, we would need to rely on another mecanism (micro has built-in syntax analysis, not sure how we can access it from the plugin).

TODO
----
- Write functional test and unit test for the export of the python structure from the buffer.
- Write functional test and unit test to validate what is being displayed of the structure depending on whether items are "open" or "closed".
- Display the python structure in the left pane.
- Add actions (keyboard, mouse) to items in the left pane (goto, open, close).
- Setup sane default (all open, all closed, level1 open).
- Add different style such as "basic" (using |,+,-, ) or "ascii" (using ascii lines) to display the tree.
