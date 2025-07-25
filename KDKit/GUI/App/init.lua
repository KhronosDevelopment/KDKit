--!strict

local UserInputService = game:GetService("UserInputService")

local Preload = require(script.Parent.Parent:WaitForChild("Preload"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Mutex = require(script.Parent.Parent:WaitForChild("Mutex"))

local T = require(script:WaitForChild("types"))
local Page = require(script:WaitForChild("Page"))
local Transition = require(script:WaitForChild("Transition"))

type AppImpl = T.AppImpl
export type App = T.App
export type Page = T.Page
export type Transition = T.Transition

local App: AppImpl = {
    folder = game.Players.LocalPlayer:WaitForChild("PlayerGui"),
    nextDisplayOrder = 0,
    appsLoadingPages = {},
} :: AppImpl
App.__index = App

function App.loadPage(module)
    for app in App.appsLoadingPages do
        if not module:IsDescendantOf(app.folder) then
            continue
        end

        if not app.pages[module.Name] then
            continue
        end

        return app :: App, app.pages[module.Name] :: Page
    end

    error(("[KDKit.GUI.App] No app found for script '%s'."):format(module:GetFullName()))
end

function App.useNextDisplayOrder()
    App.nextDisplayOrder += 1
    return App.nextDisplayOrder - 1
end

function App.getDebugState()
    return {
        AccelerometerEnabled = UserInputService.AccelerometerEnabled,
        KeyboardEnabled = UserInputService.KeyboardEnabled,
        MouseEnabled = UserInputService.MouseEnabled,
        TouchEnabled = UserInputService.TouchEnabled,
    }
end

function App.new(folder)
    local self = setmetatable({
        folder = folder,
        mutex = Mutex.new(15),
        opened = false,
        closedWithData = nil,
        pages = {},
        history = {},
    }, App) :: App

    self.instance = Instance.new("ScreenGui", App.folder)
    self.instance.Name = self.folder:GetFullName()
    self.instance.Enabled = false
    self.instance.IgnoreGuiInset = true
    self.instance.ResetOnSpawn = false
    self.instance.DisplayOrder = App.useNextDisplayOrder()
    self.instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Preload.ensureDescendants(self.folder)

    for _, pageInstance in
        Utils.sort(self.folder:GetChildren(), function(pageInstance): { number | string }
            return { if pageInstance.Name == "home" then 0 else 1, pageInstance.Name }
        end)
    do
        if not pageInstance:IsA("ModuleScript") then
            -- not actually a page instance
            continue
        end

        local page = Page.new(self, pageInstance)

        if self.pages[page.name] then
            error(("[KDKit.GUI.App] You cannot have two pages with the same name `%s`"):format(page.name))
        end

        self.pages[page.name] = page
    end

    if not self.pages.home then
        error("[KDKit.GUI.App] You must have a page called `home`.")
    end

    App.appsLoadingPages[self] = true

    Utils.ensure(function()
        App.appsLoadingPages[self] = nil
    end, function()
        for _, p in self.pages do
            local page = p :: Page -- type checker fails on templates

            local required = require(page.module) :: any

            if required ~= page then
                error(
                    ("[KDKit.GUI.App] Your module `%s` was expected to call `KDKit.GUI.App.loadPage(%s)` and return that page. Instead, the module returned `%s`."):format(
                        page.module:GetFullName(),
                        Utils.repr(page.name),
                        Utils.repr(required)
                    )
                )
            end

            page:rawOpen(Transition.new(self, "INITIAL_SETUP", nil, page, true))
            page:rawClose(Transition.new(self, "INITIAL_SETUP", page, nil, false))
        end
    end)

    return self
end

function App:getPage(page)
    if type(page) == "string" then
        return self.pages[page]
    end

    return page
end

function App:getCurrentPage()
    return self.history[#self.history] or self.pages.home
end

function App:goHome(transitionSource, data)
    self.mutex:wait()

    while next(self.history) do
        self:goBack(transitionSource, data)
    end
end

function App:goTo(pageReference, transitionSource, data)
    self.mutex:wait()

    local nextPage = self:getPage(pageReference)
    if not nextPage then
        error(("[KDKit.GUI.App] Cannot goTo unknown page `%s`"):format(Utils.repr(pageReference)))
    end

    if nextPage == self.pages.home then
        return self:goHome(transitionSource, data)
    end

    return self:rawDoPageTransition(Transition.new(self, transitionSource, self:getCurrentPage(), nextPage, true, data))
end

function App:goBack(transitionSource, data)
    self.mutex:wait()

    if not next(self.history) then
        warn(
            ("[KDKit.GUI.App] Called `app:goBack(%s, %s)` when there was nothing to go back to, already on the home page with no history. Doing nothing."):format(
                Utils.repr(transitionSource),
                Utils.repr(data)
            )
        )
        return
    end

    return self:rawDoPageTransition(
        Transition.new(
            self,
            transitionSource,
            self:getCurrentPage(),
            self.history[#self.history - 1] or self.pages.home,
            false,
            data
        )
    )
end

function App:rawDoPageTransition(transition)
    if not self.opened then
        error("[KDKit.GUI.App] Cannot do a page transition while the app is closed.")
    end

    if not transition.from or not transition.to then
        error("[KDKit.GUI.App] Cannot rawDoPageTransition with missing `from` or `to`!")
    end

    return self.mutex:lock(function(unlock)
        transition.from:rawClose(transition)
        return Utils.ensure(function(failedToOpenNextPage, openNextPageTraceback)
            if failedToOpenNextPage then
                -- attempt to re-open the previous page
                Utils.ensure(
                    function(failedToReopenPreviousPage)
                        if failedToReopenPreviousPage then
                            -- hail mary, if this fails then app is fucked & the player will need to rejoin the game
                            unlock(function()
                                self:close()
                                self:open()
                            end)
                        end
                    end,
                    transition.from.rawOpen,
                    transition.from,
                    Transition.new(
                        self,
                        "NEXT_PAGE_FAILED_TO_OPEN",
                        transition.to,
                        transition.from,
                        false,
                        { traceback = openNextPageTraceback },
                        transition
                    )
                )
            elseif transition.backward then
                table.remove(self.history, #self.history)
            elseif transition.from ~= transition.to then
                if transition.from.ephemeral then
                    table.remove(self.history, #self.history)
                end
                table.insert(self.history, transition.to)
            end
        end, transition.to.rawOpen, transition.to, transition)
    end)
end

function App:open()
    if self.opened then
        error("[KDKit.GUI.App] You cannot open an app that is already open. Consider closing it and re-opening it.")
    end
    self.opened = true
    self.instance.Enabled = true

    self.pages.home:rawOpen(Transition.new(self, "APP_OPEN", self.pages.home, nil, true))
end

function App:close()
    if not self.opened then
        error("[KDKit.GUI.App] You cannot close an app that is already closed. Consider opening it and re-closing it.")
    end

    self:goHome("APP_CLOSE")

    task.delay(self.pages.home:rawClose(Transition.new(self, "APP_CLOSE", self.pages.home, nil, false)), function()
        if not self.opened then
            self.instance.Enabled = false
        end
    end)

    self.opened = false
end

function App:waitForClose()
    local start = os.clock()
    while self.opened do
        task.wait()
    end
    return os.clock() - start
end

return App
