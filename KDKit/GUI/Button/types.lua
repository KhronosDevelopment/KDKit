--!strict

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
    onHoveredButtonChangedCallbacks: { (Button?) -> () },
    applyToAll: (GuiObject | Button, string, ...any) -> (),
    enableWithin: (GuiObject, number?) -> (),
    disableWithin: (GuiObject, number?) -> (),
    deleteWithin: (GuiObject, boolean?) -> (),
    worldIsHovered: () -> boolean,
    otherIsHovered: () -> boolean,
    worldIsActive: () -> boolean,
    otherIsActive: () -> boolean,
    onHoveredButtonChanged: ((Button?) -> ()) -> { Disconnect: () -> () },
    new: (GuiObject, ((Button) -> ())?) -> Button,
    loadStyles: (Button) -> (),
    addCallback: (
        Button,
        (Button) -> (),
        ("press" | "release" | "click")?
    ) -> (Button, { Disconnect: () -> () }),
    onPress: (Button, (Button) -> ()) -> (Button, { Disconnect: () -> () }),
    onRelease: (Button, (Button) -> ()) -> (Button, { Disconnect: () -> () }),
    onClick: (Button, (Button) -> ()) -> (Button, { Disconnect: () -> () }),
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
    activate: (Button) -> (),
    deactivate: (Button) -> (),
    simulateMouseDown: (Button) -> (),
    simulateMouseUp: (Button, boolean?) -> (),
    click: (Button, boolean?) -> (),
    fireCallbacks: (Button, { (Button) -> () }) -> (),
    firePressCallbacks: (Button) -> (),
    fireReleaseCallbacks: (Button) -> (),
    fireClickCallbacks: (Button) -> (),
    enable: (Button, number?) -> Button,
    disable: (Button, number?) -> Button,
    delete: (Button, boolean?) -> (),
}
export type Button = typeof(setmetatable(
    {} :: {
        instance: GuiObject,
        onPressCallbacks: { (Button) -> () },
        onReleaseCallbacks: { (Button) -> () },
        onClickCallbacks: { (Button) -> () },
        loadingGroupIds: { any },
        callbackIsExecuting: boolean,
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
        _previousVisualState: ButtonVisualState?,
    },
    {} :: ButtonImpl
))

export type State = {
    active: Button?,
    hovered: Button?,
    world: Button,
    other: Button,
    sound: Sound,
    recentMouseMovementCausedByTouchInput: boolean,
}

return {}
