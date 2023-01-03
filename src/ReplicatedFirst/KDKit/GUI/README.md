# KDKit.GUI

An all encompassing GUI framework. The [last one](https://xkcd.com/927/) that anyone will ever need.

A UI system using KDKIT.GUI is comprised of Apps that contain Pages. A typical setup would look like this:
```
ui.lua/
├── app1.lua/
│   ├── page1.lua/
│   │   └── instance <Frame>/
│   │       └── children... (ImageLabels, etc.)
│   └── page2.lua/
│       └── instance <Frame>/
│           └── children...
├── app2.lua/
│   └── similar structure to above
└── other apps...
```

## Apps & Pages
An "app" is a large portion of your user interface that encompasses related pages. For example, you might make a game with the following 3 apps:
1. A `minimalLoading` app. This would be as small as possible and exist in ReplicatedFirst. It would have a single page. The app would close as soon as loading is complete.
    - `home` - A simple frame containing your logo and a progress bar. Maybe some status text or a "tips" box.
2. A `menu` app which is shown after the loading app closes. It would have the following pages:
    - `home` - Your game's logo and a cool background image. It has a single menu with options to start a new save, load an existing save, or adjust settings.
    - `settings` - An array of game settings. Such as audio levels, optional visuals, etc.
    - `slotSelection` - Contains a list of available save slots. Clicking "load existing game" would lead to this page. Clicking on one of the slots will lead you to the `plotSelection` page below.
    - `plotSelection` - Is an interactive page where the player selects which plot of land they wish to load their base at. Clicking "new save" would immediately lead to this page. There is also a "cancel" button that would send the player back to the previous page. Upon clicking "confirm" a remote is fired to make the server set up your plot, and the `menu` app closes.
3. A `main` app that contains all of the pages for you main game. It contains the following pages:
    - `home` - A simple page that contains important information and buttons near the edges of the screen. It doesn't have any popups or modals that will block the player's vision. For example, it contains a health bar, an inventory button, and a shop button.
    - `inventory` - Contains centered modal which is a ScrollingFrame that contains all of your inventory items. Each inventory item has a button to begin placing that item on your base.
    - `placing` - UI to place an item on your base. Maybe contains a rotate button and a confirm or cancel button.
    - `shop` - Contains gamepasses with buttons to prompt a purchase for each one.

You'll notice that each of these apps contains a `home` page. This is a requirement. A good way to know when you need a new app is when there's a new "home page". Typically, apps should be opened and closed exactly once, never to be opened again. If there is a part of your UI that is to be opened multiple times, it probably belongs in a `page`.

## GUI.Button
My pride and joy. A wonderfully simple interface to creating beautiful interactive buttons.

Code within the `home` page:
```lua
local KDKit = require(game:GetService("ReplicateFirst"):WaitForChild("KDKit"))
local app = require(script.Parent)
local page = app:getPage("home")

page.buttons.close = GUI.Button.new(page.instance.closeButton, function()
    print("you clicked the close button, so I am going back to the previous page")
    -- every ui transition must have a `source` (to help debug in production)
    -- This transitions's source is "CLOSE", but you can use any that you like, i.e. "BUTTON_PRESS"
    app:goBack("CLOSE") 
end)
:hitbox("circle") -- because the button is a circle
:bind("X") -- oh yes, this does exactly what you think it does

return page
```

Video:
https://user-images.githubusercontent.com/108852550/210302445-633769a3-2929-4c6c-8f70-e2e240901ae2.mp4

Isn't that amazing? 3 lines of button code for all that? Yeah. I'm not kidding, this is the only code required to make this work. See the module level [README](./Button/README.md) for more details.
