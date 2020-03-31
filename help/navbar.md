# Navigation Bar (navbar) Plugin #

The navbar plugin provides the user with the ability to navigate through a programming file using the symbols defined in the buffer such as classes, functions, variables, etc. This is extremely usefull for very long files or when exploring a new file to have a better idea of the content of the file.

Each programming language defines its own syntax for defining objects, classes, functions, etc. Therefore, support for a programming language is not automatic. See https://github.com/akowiz/micro.navbar.plugin on how you can contribute to add support for your favorite programming language.

Currently, the languages supported are:

- Go*
- Lua*
- Python**

* Partially: some items might not be displayed properly in the structure.
** Python has better support because of the rigid syntax of the language.

To toggle the side window with the navigation bar, simply press `Alt-n` (or use command `navbar`).

In the navbar side windows, you can navigate using your keyboard or the mouse.

- Press `g` to jump to the corresponding symbol in the main window (or use command `nvb_goto`).
- Press ` ` to toggle a node between closed and open (or use command `nvb_toggle`).
- Press `o` to open all closed nodes (or use command `nvb_open_all`).
- Press `c` to close all open nodes (or use command `nvb_close_all`).
