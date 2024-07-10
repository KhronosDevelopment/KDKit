--!strict

local Mutex = require(script.Parent.Parent.Parent:WaitForChild("Mutex"))
local Button = require(script.Parent.Parent:WaitForChild("Button"))

export type AppImpl = {
    __index: AppImpl,
    folder: PlayerGui,
    nextDisplayOrder: number,
    appsLoadingPages: { [App]: boolean },
    loadPage: (ModuleScript) -> (App, Page),
    useNextDisplayOrder: () -> number,
    getDebugState: (
    ) -> {
        AccelerometerEnabled: boolean,
        KeyboardEnabled: boolean,
        MouseEnabled: boolean,
        TouchEnabled: boolean,
    },
    new: (Folder) -> App,
    getPage: (App, string | Page) -> Page?,
    getCurrentPage: (App) -> Page,
    goHome: (App, string, any) -> (),
    goTo: (App, Page | string, string, any) -> (),
    goBack: (App, string, any) -> (),
    rawDoPageTransition: (App, Transition) -> (),
    open: (App) -> (),
    close: (App) -> (),
    waitForClose: (App) -> number,
}
export type App = typeof(setmetatable(
    {} :: {
        folder: Folder,
        mutex: Mutex.Mutex,
        opened: boolean,
        closedWithData: any?,
        instance: ScreenGui,
        pages: { [string]: Page },
        history: { Page },
    },
    {} :: AppImpl
))

export type PageImpl = {
    __index: PageImpl,
    TOP_ZINDEX: number,
    BOTTOM_ZINDEX: number,
    new: (App, ModuleScript) -> Page,
    rawOpen: (Page, Transition) -> number,
    rawClose: (Page, Transition) -> number,
    afterOpened: (Page, Transition) -> (),
    beforeClosed: (Page, Transition) -> (),
    cycle: <Arg...>(Page, number, (Arg...) -> any, Arg...) -> (),
}
export type Page = typeof(setmetatable(
    {} :: {
        app: App,
        module: ModuleScript,
        name: string,
        instance: GuiObject,
        connections: { [any]: RBXScriptConnection },
        buttons: { [any]: Button.Button },
        opened: boolean,
        ephemeral: boolean,
        nTimesOpened: number,
        nTimesClosed: number,
    },
    {} :: PageImpl
))

export type TransitionSummary = {
    app: string?,
    source: string,
    from: string?,
    to: string?,
    direction: string,
    data: any,
    clock: number,
}

export type TransitionImpl = {
    __index: TransitionImpl,
    new: (App, string, Page?, Page?, boolean, any, Transition?) -> Transition,
    isFrom: (Transition, string | Page) -> boolean,
    isTo: (Transition, string | Page) -> boolean,
    summary: (Transition) -> TransitionSummary,
}
export type Transition = typeof(setmetatable(
    {} :: {
        app: App?,
        source: string,
        from: Page?,
        to: Page?,
        direction: string,
        data: any,
        parent: Transition?,
        constructedAt: number,
        forward: boolean,
        forwards: boolean,
        backward: boolean,
        backwards: boolean,
        initial: boolean,
        builtin: boolean,
    },
    {} :: TransitionImpl
))

return {
    BUILTIN_SOURCES = { "INITIAL_SETUP", "APP_CLOSE", "APP_OPEN", "GO_HOME", "NEXT_PAGE_FAILED_TO_OPEN" },
}
