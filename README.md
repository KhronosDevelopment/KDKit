# KDKit
A collection of tools that Khronos Development uses in nearly every game.

Please see [src/ReplicatedFirst/KDKit](src/ReplicatedFirst/KDKit) for an exhaustive list of tools, but otherwise some of the most generally useful tools are listed below the **Usage** section.

## Usage
This repository uses [Rojo](https://rojo.space/), which can be used to clone all of the scripts into your game. The project setup is noninvasive, so you can just synchronize the project once then forget about it. Alternatively, you can add this repository as a submodule in a fully managed Rojo game.

## [KDKit.Class](src/ReplicatedFirst/KDKit/Class.lua)
A simple classing library that supports single-inheritence and metamethods.

<details>
<summary>Code Demo</summary>

```lua
local KDKit = require(game:GetService("ReplicatedFirst"):WaitForChild("KDKit"))

-- Person superclass
local Person = KDKit.Class.new("Person")
function Person:__init(first, last)
    self.name = {
        first = first,
        last = last,
    }
end
function Person:__tostring()
    return self.name.first .. " " .. self.name.last
end

-- Student subclass
local Student = KDKit.Class.new("Student", Person)
function Student:__init(first, last, graduationYear)
    Student.__super.__init(self, first, last)
    self.graduationYear = graduationYear
end
function Student:__tostring()
    return Student.__super.__tostring(self) .. ", who graduates in " .. self.graduationYear
end

-- demo of working class
local student = Student.new("John", "Doe", 2024)
print(student.name.first) -- "John"
print(student.name.last) -- "Doe"
print(student.graduationYear) -- 2024
print(student) -- "John Doe, who graduates in 2024"

-- also, you can check some of the class attributes
print(student.__class == Student) -- true
print(student.__class.__super == Person) -- true
print(KDKit.Class:isSubClass(Student, Person)) -- true

-- and you can create static methods or variables
Student.static.xyz = 123
print(Student.xyz) -- 123
print(student.xyz) -- nil

-- which are inherited as well
Person.static.abc = 456
print(Student.abc) -- 456
```
</details>

## [KDKit.Utils](src/ReplicatedFirst/KDKit/Utils.lua)
A collection of mostly unrelated one-off utility methods. These are documented in-line within the code.

<details>
<summary>Non-Exhaustive Code Demo</summary>

### Copypasta that I won't be including in each demo
```lua
local KDKit = require(game:GetService("ReplicatedFirst"):WaitForChild("KDKit"))
local Utils = KDKit.Utils
```

### Utils.try
```lua
Utils:try(function()
    print(("Hello %d"):format("world"))
end)
    :catch(function(traceback)
        print("this function runs only when an error is raised")
        warn(traceback)
    end)
    :proceed(function()
        print("This function is never executed, because the `try` failed.")
    end)
    :after(function(traceback)
        print("This function will always run")
        print("and `traceback` will either be `nil` or a string, depending on whether or not an error occurred")
    end)
    :raise() -- re-raises the error, if one occurred
    :result() -- returns the result of the original function (assuming that :raise() didn't raise an error)
```

### Utils.repr
```lua
Utils:repr("hello") -- returns "'hello'"
Utils:repr(123) -- returns "123"
Utils:repr(123.456) -- returns "123.456"
Utils:repr(nil) -- returns "nil"
Utils:repr(true) -- returns "true"
Utils:repr(Enum.Material.Concrete) -- returns "Enum.Material.Concrete"
Utils:repr(Enum.Material) -- returns "Enum.Material"
Utils:repr(workspace.MyModel.MyPart) -- returns "<Instance.Part> Workspace.MyModel.MyPart"
Utils:repr({a=1,b=2,c={d=3,e='abc'}}) -- returns "{ ['a'] = 1, ['b'] = 2, ['c'] = { ['d'] = 3, ['e'] = 'abc' } }"
```

### Utils.pluck
```lua
Utils:pluck({ Vector3.new(1,2,3), Vector3.new(4,5,6) }, "X") -- returns { 1, 4 }
Utils:pluck({ workspace.a, workspace.b }, function(part) return part:GetAttribute("xyz") end)) -- returns whatever those attributes are
```

### Utils.any/Utils.all
```lua
Utils:any({false, true, false}) -- returns true
Utils:any({false, false}) -- returns false
Utils:any({}) -- returns false
Utils:any({1, 2, 3, -5}, function(x) return x < 0 end) -- returns true

Utils:all({true, true, true}) -- returns true
Utils:all({false, true}) -- returns false
Utils:all({}) -- returns true
Utils:all({1, 2, 3}, function(x) return x > 0 end) -- returns true
```

### Utils.split
```lua
Utils:split("Hello there, my name is Gabe!") -- returns { "Hello", "there,", "my", "name", "is", "Gabe!" }
Utils:split("  \r\n whitespace   is  \t\t    stripped   \n ") -- returns { "whitespace", "is", "stripped" }
Utils:split("a_b_c", "_") -- returns { "a", "b", "c" }
Utils:split("abc123xyz", "%d") -- returns { "abc", "xyz" }
```

### Utils.characters
```lua
Utils:characters("abc") -- returns { "a", "b", "c" }
```

## Utils.sum
```lua
Utils:sum({1, 2, 3}) -- returns 6
Utils:sum({1, 2, 3}, math.sqrt) -- returns 4.146264369941973
```

## Utils.min/Utils.max
```lua
Utils:min({1, 2, 3}) -- returns 1
Utils:max({1, 2, 3}) -- returns 3
Utils:max({1, 2, 3}, math.sqrt) -- returns 1.7320508075688772
```

## Utils.unique
```lua
Utils:unique({1, 1, 2, 3, 3, 2, 4}) -- {1, 2, 3, 4} (although the order is not guaranteed)
```

## Utils.select/Utils.reject
```lua
Utils:select({-3, -2, -1, 0, 1, 2, 3}, function(x) return x <= 0 end) -- {-3, -2, -1, 0}
Utils:reject({-3, -2, -1, 0, 1, 2, 3}, function(x) return x <= 0 end) -- {1, 2, 3}
```

### And many, many more
- Utils.weld
- Utils.strip
- Utils.map
- Utils.keys
- Utils.shallowEqual/Utils.deepEqual
- Utils.ensure
- Utils.isLower/Utils.isUpper
- Utils.isAlphanumeric/Utils.isAlpha/Utils.isNumeric
- Utils.startsWith/Utils.endsWith
- Utils.bisect/Utils.insort
- Utils.invert
- Utils.aggregateErrors
- Utils.find
- Utils.partTouchesPoint
- Utils.guiObjectIsOnTopOfAnother
- Utils.getBlankPart
- Utils.callable
- Utils.getattr
- Utils.lerp/Utils.unlerp
- Utils.extend
- Utils.merge
- Utils.makeSerializable
- Utils.isLinearArray
</details>

## [KDKit.API](src/ReplicatedFirst/KDKit/API)

Please see module level [README](src/ReplicatedFirst/KDKit/API/README.md).

## [KDKit.GUI](src/ReplicatedFirst/KDKit/API)

Please see module level [README](src/ReplicatedFirst/KDKit/GUI/README.md).

## [KDKit.ReplicatedTable](src/ReplicatedFirst/KDKit/ReplicatedTable)

An extraordinarily simple way of sharing data between the server and all clients.

<details>
<summary>Code Demo</summary>

On the server:
```lua
ReplicatedTable.someValue = 0
while task.wait() do
    ReplicatedTable.someValue += 1
end
```

On the clients:
```lua
while task.wait() do
    local theValue = ReplicatedTable.someValue()
    print(theValue)
end

-- or, what the module was really designed for:
ReplicatedTable.someValue(function(theValue)
    print("the value has changed to:", theValue)
end)
```

You can replicate any table in this manner (assuming it only contains data which can be stored in attributes), so maybe something like
```lua
-- on the server
ReplicatedTable.playerData = {}
game.Players.PlayerAdded:Connect(function(player)
    ReplicatedTable.playerData[player.UserId] = {
        money = 123,
        experience = 456,
        gems = 789,
    }
end)

-- on the client
ReplicatedTable.playerData[game.Players.LocalPlayer.UserId](function(myData)
    if myData == nil then
        print("data not loaded yet...")
    else
        print("I have", myData.gems, "gems")
    end
end)
```

Note that the client side will never error, so you could do something like
```lua
ReplicatedTable.invalid.path.that.doesnt.exist(function(data)
    print(data) -- will print `nil` exactly one time (for the initial call) then will never get called again
end)
```
</details>

## [KDKit.Humanize](src/ReplicatedFirst/KDKit/Humanize.lua)

This module provides several utilities to make data more presentable to humans.
<details>
<summary>Code Demo</summary>

```lua
local KDKit = require(game:GetService("ReplicatedFirst"):WaitForChild("KDKit"))
local Humanize = KDKit.Humanize
```

## Humanize.casing
Transforms the casing of strings, from any source casing to any requested destination casing.
```lua
Humanize:casing("hello world", "pascal") -- returns "HelloWorld"
Humanize:casing("hello_world", "sentence") -- returns "Hello world"
Humanize:casing("HelloWorld", "none") -- returns "hello world"
Humanize:casing("HelloWorld", "camel") -- returns "helloWorld"
Humanize:casing("complex_-_Strings are \t REASONABLY_SUPPORTED!", "upperKebab") -- returns "COMPLEX-STRINGS-ARE-REASONABLY-SUPPORTED"
```
Supported modes are:
* `none`: `hello world`
* `sentence`: `Hello world`
* `title`: `Hello World`
* `pascal`: `HelloWorld`
* `camel`: `helloWorld`
* `snake`: `hello_world`
* `upperSnake`: `HELLO_WORLD`
* `kebab`: `hello-world`
* `upperKebab`: `HELLO-WORLD`
* `acronym`: `hw`
* `upperAcronym`: `HW`
* `dottedAcronym`: `h.w.`
* `upperDottedAcronym`: `H.W.`

## Humanize.list
Creates human readable lists from Lua tables.
```lua
Humanize:list({"a", "b", "c"}) -- returns "a, b, and c"
Humanize:list({"x"}) -- returns "x"
Humanize:list({"a", "b", "c"}, 2) -- returns "a, b, and 1 other item"
Humanize:list({"a", "b", "c", "d", "e"}, 3, "letter") -- returns "a, b, c, and 2 other letters"
```

## Humanize.plural
Pluralizes English nouns, with support for irregular nouns.
```lua
Humanize:plural("item") -- returns "items"
Humanize:plural("knife") -- returns "knives"
Humanize:plural("Option") -- returns "Options"
Humanize:plural("LIST") -- returns "LISTS"
Humanize:plural("example", 5) -- returns "examples"
Humanize:plural("example", 1) -- returns "example"
Humanize:plural("example", 0) -- returns "examples"
Humanize:plural("STUFF", 5) -- returns "STUFFS"
Humanize:plural("fish", 5) -- returns "fish"
```

## Humanize.timestamp
Formats UNIX timestamps.
```lua
Humanize:timestamp(0, nil, true) -- returns "1970-01-01 12:00:00 AM GMT"
```

## Humanize.timeDelta
Formats secondly time deltas as human understandable periods.
```lua
Humanize:timeDelta(10) -- returns "10 seconds"
Humanize:timeDelta(65) -- returns "1 minute"
Humanize:timeDelta(90) -- returns "1 minute"
Humanize:timeDelta(120) -- returns "2 minutes"
Humanize:timeDelta(3600) -- returns "1 hour"
Humanize:timeDelta(86400) -- returns "1 day"
Humanize:timeDelta(86400 * 7) -- returns "1 week"
Humanize:timeDelta(86400 * 365) -- returns "1 year"

Humanize:timeDelta(10, true) -- returns "10s"
Humanize:timeDelta(300, true) -- returns "5m"
Humanize:timeDelta(86400 * 365, true) -- returns "1y"

Humanize:timeDelta(-10, true) -- returns "-10s"
Humanize:timeDelta(-86400 * 7 * 3) -- returns "-3 weeks"
```

## Humanize.percent
Opinionated way of displaying odds.
```lua
Humanize:percent(-0.5) -> "0%"
Humanize:percent(1 / 1_000_000) -> "0%"
Humanize:percent(0.1 / 100) -> "<1%"
Humanize:percent(5 / 100) -> "5%"
Humanize:percent(5.3 / 100) -> "5.3%"
Humanize:percent(73.8 / 100) -> "74%"
Humanize:percent(99.9999 / 100) -> "99%"
Humanize:percent(100 / 100) -> "100%"
Humanize:percent(500 / 100) -> "100%"
```

## Humanize.number
A way of formatting numbers, with lots of options.
```lua
Humanize:number(1) -> "1"
Humanize:number(123.456) -> "123.456"
Humanize:number(2 / 3, { decimalPlaces = 3 }) -> "0.667"
Humanize:number(math.pi * 1000000, { addCommas = true, decimalPlaces = 4 }) -> "3,141,592.6536"
Humanize:number(1, { decimalPlaces = 4, removeTrailingZeros = false }) -> "1.0000"
```

## Humanize.money
Similar to Humanize.number, but specifically designed for formatting money.
```lua
"$" .. Humanize:money(1) -> "$1.00"
"$" .. Humanize:money(15.8277) -> "$15.82"
Humanize:money(25.87, true) -> "25"
Humanize:money(13, true) -> "13"
Humanize:money(5, false, "dollar") -> "5.00 dollars"
Humanize:money(3, true, "gem") -> "5 gems"
Humanize:money(85.98, false, "pound") -> "85.98 pounds"
```

## Humanize.hex/Humanize.unhex
Useful for displaying binary data, or obfuscating potentially confusing error messages.
```lua
local hello = Humanize:hex("hello")
local whitespace = Humanize:hex("\0\n\t\v\0")

print(hello) -- 68656C6C6F
print(whitespace) -- 000A090B00

print(Humanize:unhex(hello)) -- hello
print(Humanize:unhex(whitespace)) -- "\0\n\t\v\0"
```

## Humanize.colorToHex/Humanize.hexToColor
Pretty self explanatory.
```lua
local black = Humanize:colorToHex(Color3.fromRGB(0, 0, 0))
local blue = Humanize:colorToHex(Color3.fromRGB(59, 124, 217))
local white = Humanize:colorToHex(Color3.fromRGB(255, 255, 255))

print(black, blue, white) -- 000000 3B7CD9 FFFFFF

Humanize:colorToHex(black) -- returns Color3.fromRGB(0, 0, 0)
Humanize:colorToHex(blue) -- returns Color3.fromRGB(59, 124, 217)
Humanize:colorToHex(white) -- returns Color3.fromRGB(255, 255, 255))
```
</details>

## [KDKit.LazyRequire](src/ReplicatedFirst/KDKit/LazyRequire.lua)
A non-blocking require. Using this typically indicates that your code is designed poorly, but I find it useful for configuration modules where there are sometimes circular dependencies.
Please see inline documentation for usage.

## [KDKit.Time](src/ReplicatedFirst/KDKit/Time.lua)
Pretty simple module that performs a NTP-esq time synchronization with a server of your choice.

```lua
print(KDKit.Time()) -- prints the current UNIX timestamp, as synchronized with the host server.
```

## [KDKit.Remotes](src/ReplicatedFirst/KDKit/Remotes)
An autogenerated collection of [KDKit.Remote](src/ReplicatedFirst/KDKit/Remote.lua)s. The only real reason to use KDKit remotes rather than native remotes is because they come with builtin rate limiting and error reporting options.

<details>
<summary>Code Demo</summary>

Usage is pretty simple
```lua
-- server
KDKit.Remotes.myRemote(game.Players.SomePlayer, "argument")

-- client
KDKit.Remotes.myRemote:connect(function(argument)
    print(argument) -- "argument"
end)
```
</details>

## [KDKit.Mutex](src/ReplicatedFirst/KDKit/Mutex.lua)
Pretty standard mutex lock implementation, with a timeout parameter.

<details>
<summary>Code Demo</summary>

```lua
local mtx = Mutex.new(3) -- 3 second timeout

task.defer(function()
    mtx:lock(function()
        print("E")
    end)
end)

mtx:lock(function(unlock)
    print("A")
    task.wait(5)
    print("B")
    unlock(function()
        mtx:lock(function()
            print("C")
        end)
    end)
    print("D")
end)
```

output:
```
> A
(3 seconds later)
> error: mutex lock timed out
(2 seconds later)
> B
> C
> D
```
</details>

## [KDKit.Mouse](src/ReplicatedFirst/KDKit/Mouse.lua)
Various utilities that I wish were provided in the standard Roblox Mouse class.

<details>
<summary>Code Demo</summary>

Icon Layering:
```lua
Mouse:setIcon("context1", "rbxasset://id1")
Mouse:setIcon("context2", "rbxasset://id2")

print(Mouse.instance.Icon) -- "rbxasset://id2"
Mouse:setIcon("context2", nil)
print(Mouse.instance.Icon) -- "rbxasset://id1"
Mouse:setIcon("context1", nil)
print(Mouse.instance.Icon) -- ""
```

Gui inset agnostic position:
```lua
Mouse:getPosition(true) -- 100, 100
Mouse:getPosition(false) -- 100, 64
```

ScreenPointToRay shortcut
```lua
Mouse:getRay() -- Vector3.new(whatever)
```

</details>

## [KDKit.Random](src/ReplicatedFirst/KDKit/Random)
A couple of random utilities that I wish were included in the Roblox's `Random` class.

<details>
<summary>Code Demo</summary>

```lua
KDKit.Random:choice({1, 2, 3}) -- 3
KDKit.Random:linearChoice({1, 2, 3}) -- 1 (exactly the same as :choice, but is optimized for tables with numeric keys)
KDKit.Random:keyChoice({a=1, b=2, c=3}) -- "b"
KDKit.Random:weightedChoice({a=10, b=1, c=1}) -- "a" (it is 10 times more likely to choose A then it is to choose B or C - in 120 calls, it will choose 100 A's, 10 B's, and 10 C's)

KDKit.Random:color() -- Color3.fromHSV(0.34, 0.89, 0.22)
KDKit.Random:vector() -- Vector3.new(0.08, -0.73, 0.29)
KDKit.Random:enum(Enum.Material) -- Enum.Material.Concrete

KDKit.Random:shuffle({"a", "b", "c", "d"}) -- { "c", "b", "a", "d" }

KDKit.Random:uuid(8) -- "aVj8a2LK"
KDKit.Random:withSeed(123, function() print(KDKit.Random:uuid(4)) end) -- tIaJ
KDKit.Random:withSeed(123, function() print(KDKit.Random:uuid(4)) end) -- tIaJ

KDKit.Random:number() -- a number on interval [0, 1)
KDKit.Random:number(8) -- a number on interval [0, 8)
KDKit.Random:number(10, 50) -- a number on interval [10, 50)
KDKit.Random:number(NumberRange.new(3, 4)) -- a number on interval [3, 4)
```

</details>

## [KDKit.Maid](src/ReplicatedFirst/KDKit/Maid.lua)
Basically an identical copy of the classic [Nevermore.Maid](https://github.com/Quenty/NevermoreEngine/tree/f953eb8650073a3da5b551239c87e8d9391bc858/src/maid), but it uses KDKit.Class and KDKit.Util instead of the Nevermore stuff. I also tweaked the behavior a bit to my liking.

## [KDKit.JobId](src/ReplicatedFirst/KDKit/JobId.lua)

Just a stupid macro to make JobIds work in studio, and to make them _actually_ unique. You would be surprised how frequently live game servers share duplicate JobIds.

```lua
print(KDKit.JobId) -- RobloxStudio_jhksad12sdjfgh29sdfgjh7823
```
