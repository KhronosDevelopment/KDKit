# KDKit
A collection of tools that Khronos Development uses in every game.

## Installation

### Manual

<details>
    <summary>Copy and paste code into Roblox.</summary>
  
If you know what you want, and don't care about versioning, you can simply copy and paste whatever you want into the game.

This is what a full KDKit installation looks like in-game:
<img height="400px" src=".github/readme-static/kdkit-ingame.png" />

Many of the features do not rely on each other, so you may choose to only add one or a few modules.
</details>

### Rojo

<details>
    <summary>Add KDKit as a git submodule.</summary>
  
Lets say you have the following [Rojo](https://rojo.space/) project for your game:
```
YourGame/
├── src/
│   ├── ReplicatedStorage/
│   │   └── YourReplicatedCode.lua
│   └── ServerScriptService/
│       └── YourServerCode.lua
└── default.project.json
```

Where `default.project.json` is:
```json
{
    "name": "YourGame",
    "tree": {
        "$className": "DataModel",
        "ServerScriptService": {
            "$ignoreUnknownInstances": true,
            "$path": "src/ServerScriptService"
        },
        "ReplicatedStorage": {
            "$ignoreUnknownInstances": true,
            "$path": "src/ReplicatedStorage"
        }
    }
}
```

And you want to install `KDKit` to `ReplicatedStorage/KDKit`. You can add it as a submodule:
```sh
cd YourGame/src/ReplicatedStorage
git submodule add "https://github.com/KhronosDevelopment/KDKit" KDKit
```

And you're done! Now you can use KDKit:
```lua
local KDKit = require(game:GetService("ReplicatedStorage"):WaitForChild("KDKit"))

print(KDKit.Utils.sum({ 1, 2, 3 }))
```
</details>

> [!NOTE]
> This repository does not use [Wally](https://wally.run/) due to [incompatibilities](https://discord.com/channels/385151591524597761/872225914149302333/1257773007577809027).
