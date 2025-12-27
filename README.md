# Moved to https://codeberg.org/LDprg/volantes-cursors
# Not closed so the pr to the original might get merged

# Volantes Cursors

## Original Repo: https://github.com/varlesh/volantes-cursors

### Why the fork?

The original repo did only support old xcursor themes, which fail to scale cleanly (for example in KDEs 'Shake cursor' feature).
Therefore this repo drastically improved the quality by using `kcursorgen` to generate svg themes.
Furthermore hyprland compatibility was added by using `hyprcursor-util`.
There are only changes to the build system, icons are still the same.

All credits belong to @varlesh, if you someday read this: I would be happy to merge this into your original repo!

### Install build version

Not available for now. Check out the original repo (no svg/hyprland fixes though).
Manual Install is currently required!

### Manual Install

1. Install dependencies:
   - git
   - tar
   - kcursorgen
   - xcursorgen
   - hyprcursor-util (only for hyprcusors)

2. Run the following commands as normal user:

   ```bash
   git clone https://github.com/varlesh/volantes-cursors.git
   cd volantes-cursors
   python gen.py
   sudo python install.py # System wide install
   ```

   For hyprcusors use following instead:

   ```bash
   git clone https://github.com/varlesh/volantes-cursors.git
   cd volantes-cursors
   python gen.py --hyprcursor
   python install_local.py # Local user install
   ```

3. Choose a theme in the Settings or in the Tweaks tool.
