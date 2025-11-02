## Configuration

Some spoons support user-specific configuration. If a spoon has a `config.example.lua` file, you can customize it by copying the example to `config.lua` in the same directory:

```bash
cp Spoons/VPNMenubar.spoon/config.example.lua Spoons/VPNMenubar.spoon/config.lua
```

Then edit `config.lua` with your values. The `config.lua` files are gitignored and won't be committed to the repository.

### Shared Config Loader

The `lib/config_loader.lua` module provides a reusable way for spoons to load their configuration. To use it in a spoon:

```lua
local configLoader = require("lib.config_loader")

local defaults = {
    option1 = "default_value1",
    option2 = "default_value2"
}

local configPath = hs.spoons.resourcePath("config.lua")
local config = configLoader.load(defaults, configPath)
```

### VPNMenubar Configuration

The VPNMenubar spoon can be configured with:

- `interface`: The network interface to check (default: `"utun4"`)
- `ipPattern`: The IP address pattern to match (default: `"10%.%d+%.%d+%.%d+"`)

## Ideas

- 🔒 Update VPN item to only show icon when disconnected
- 📆 a calendar webview item that shows a small Google Calendar month view
- 📲 an SMS menubar that loads hidden webviews of Google Voice
  - uses mutation observer to see new codes and extracts them
    - needs a way to do initial login before the mutation observer is attached
  - icon indicates when something new comes in
  - menu has clickable rows for copying the code and for toggle display of the web view
