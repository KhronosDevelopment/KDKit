local LazyRequire = require(script:WaitForChild("LazyRequire"))

return LazyRequire(
    script,
    {
        "Class", "Decimal", "AsyncEE",
        "DeepCopy", "Quantity", "LazyRequire",
        "Button", "ButtonSound", "GUIUtility",
        "Remote",  "HumanNumbers", "FrameCounter",
        "Preload", "ReplicatedTable", "Humanize",
        "Random", "Mouse", "Ensure"
    },
    {},
    { "Time" }
)
