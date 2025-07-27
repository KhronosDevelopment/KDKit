--!strict

local Signal = require(script.Parent.Parent.Parent:WaitForChild("Signal"))

export type KeyCodeReference = string | Enum.KeyCode | number
export type KeybindImpl = {
    __index: KeybindImpl,
    nextBindId: number,
    useNextBindId: () -> number,
    useNextBindString: () -> string,
    parseKeyCode: (KeyCodeReference) -> Enum.KeyCode?,
    new: (Button, KeyCodeReference) -> Keybind,
    enable: (Keybind) -> (),
    disable: (Keybind) -> (),
}
export type Keybind = typeof(setmetatable(
    {} :: {
        button: Button,
        key: Enum.KeyCode,
        active: boolean,
        bind: string?,
    },
    {} :: KeybindImpl
))

export type LoadingGroupImpl = {
    __index: LoadingGroupImpl,
    list: { [any]: LoadingGroup },
    new: (any) -> LoadingGroup,
    add: (LoadingGroup, Button) -> (),
    remove: (LoadingGroup, Button) -> (),
    update: (LoadingGroup) -> (),
    isLoading: (LoadingGroup) -> boolean,
}
export type LoadingGroup = typeof(setmetatable(
    {} :: {
        id: any,
        buttons: { [Button]: boolean },
        wasLoadingOnLastUpdate: boolean?,
    },
    {} :: LoadingGroupImpl
))

export type ButtonHitbox = (Button, xOffset: number, yOffset: number, sizeX: number, sizeY: number) -> boolean
export type ButtonStyle = { [string]: any }
export type ButtonVisualState = {
    hovered: boolean,
    active: boolean,
    loading: boolean,
    disabled: boolean,
}
export type ButtonImpl = {
    __index: ButtonImpl,
    state: State,
    list: { [GuiObject]: Button },
    applyToAll: (GuiObject | Button, string, ...any) -> (),
    enableWithin: (GuiObject, number?) -> (),
    disableWithin: (GuiObject, number?) -> (),
    deleteWithin: (GuiObject, boolean?) -> (),
    new: (GuiObject, Signal.SignalFn<(), ()>?) -> Button,
    loadStyles: (Button) -> (),
    withPressConnection: (Button, Signal.SignalFn<(), ()>) -> Button,
    withReleaseConnection: (Button, Signal.SignalFn<(), ()>) -> Button,
    withClickConnection: (Button, Signal.SignalFn<(), ()>) -> Button,
    withVisualStateChangeConnection: (Button, Signal.SignalFn<(ButtonVisualState, ButtonVisualState), ()>) -> Button,
    hitbox: (Button, string | ButtonHitbox) -> Button,
    bind: (Button, ...KeyCodeReference) -> Button,
    unbindAll: (Button) -> Button,
    loadWith: (Button, ...any) -> Button,
    disableAllStyling: (Button) -> Button,
    enableAllStyling: (Button) -> Button,
    silence: (Button) -> Button,
    unSilence: (Button) -> Button,
    style: (Button, ButtonStyle, number) -> (),
    updateStyle: (
        Button,
        "original" | "hovered" | "active" | "loading" | "disabled",
        string,
        any
    ) -> (),
    determinePropertyValueDuringState: (Button, string, ButtonVisualState) -> (),
    getVisualState: (Button) -> ButtonVisualState,
    visualStateChanged: (Button, number?) -> (),
    isBoundTo: (Button, Enum.KeyCode) -> boolean,
    isLoading: (Button) -> boolean,
    isActive: (Button) -> boolean,
    isHovered: (Button) -> boolean,
    isWorld: (Button) -> boolean,
    isOther: (Button) -> boolean,
    customHitboxContainsPoint: (Button, number, number) -> boolean,
    pressable: (Button) -> boolean,
    makeSound: (Button) -> (),
    activateMouse: (Button) -> (),
    activateKey: (Button, Enum.KeyCode) -> (),
    deactivateMouse: (Button) -> (),
    deactivateKey: (Button, Enum.KeyCode) -> (),
    mouseDown: (Button) -> (),
    keyDown: (Button, Enum.KeyCode) -> (),
    mouseUp: (Button) -> (),
    keyUp: (Button, Enum.KeyCode) -> (),
    click: (Button, boolean?) -> (),
    enable: (Button, number?) -> Button,
    disable: (Button, number?) -> Button,
    delete: (Button, boolean?) -> (),
}
export type Button = typeof(setmetatable(
    {} :: {
        instance: GuiObject,
        signals: {
            press: Signal.Signal<(), ()>,
            release: Signal.Signal<(), ()>,
            click: Signal.Signal<(), ()>,
            visualStateChange: Signal.Signal<(ButtonVisualState, ButtonVisualState), ()>,
        },
        loadingGroupIds: { any },
        isClicking: boolean,
        enabled: boolean,
        keybinds: { [Enum.KeyCode]: Keybind },
        silenced: boolean,
        stylingEnabled: boolean,
        styles: {
            original: ButtonStyle,
            hovered: ButtonStyle,
            active: ButtonStyle,
            loading: ButtonStyle,
            disabled: ButtonStyle,
        },
        customHitbox: ButtonHitbox?,
        _previousVisualState: ButtonVisualState,
    },
    {} :: ButtonImpl
))

export type State = {
    mouseActive: Button?,
    mouseHovered: Button?,
    world: Button,
    other: Button,
    sound: Sound,
    recentMouseMovementCausedByTouchInput: boolean,
}

return {}
