# Design assets

The visual spec for Moment. Build the Flutter UI to match these, and write golden tests against them.

## `mockups/png/`

One PNG per artboard at 2x (390 pt wide phone screens; the app map is 1240 wide, the design language board 860). These are the reference images for fidelity work.

Numbering: 00 App map, 01 Lock, 02 Home (all six card types), 03 Add, 04 Library, 05 to 10 Create (Text, Emoji, Photo, Video, Audio, Location), 11 to 16 Sections (list pages per type), 17 to 22 Details, 23 Calendar, 24 Search, 25 Settings, 26 Privacy and backup, 27 Trash, 28 Design language (colours, type, glass recipes).

The renders were made in headless Chromium without the Inter and Newsreader fonts and without real backdrop-blur fidelity, so treat them as layout, colour and spacing references. Blur strength, exact font metrics and shadows come from the HTML source below and from the design language board.

## `mockups/*.dc.html`

The editable source of each artboard: plain HTML with inline styles, wrapped in an `<x-dc>` element (a design canvas format; the `support.js` it references is not included, and the files still open as ordinary HTML in a browser). `canvas.json` holds each board's size and title. Read the inline styles for exact numbers: radii, paddings, colours, the glass recipes (`rgba` fill, border, shadow, blur and saturation).

## `generators/`

The Python scripts that produced the HTML (`lib.py` has the helpers such as `glass()`, `ic()` for icons, and the six card builders). Useful as a map of which values are shared tokens. Not needed to build the app.

## Tokens at a glance

- Type colours: Text `#1D4ED8`, Emoji `#B45309`, Photo `#BE185D`, Video `#6D28D9`, Audio `#0F766E`, Location `#15803D`.
- Primary buttons: ink `#1B1F2A`. Ground: `#EDF0F7`.
- Fonts: Newsreader for the user's words, Inter for UI. Both must be bundled in the app (no internet permission, so no runtime font download).
- Tab bar: Home, Library, + (Add), Calendar, Settings.
