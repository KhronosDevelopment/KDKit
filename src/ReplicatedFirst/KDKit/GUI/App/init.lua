--[[
    KDKit.GUI.App is a very opinionated framework which forces you to structure your GUI as a sequence of pages.
    I will write more documentation for KDKit.GUI.App when I feel like it.
--]]

local Class = require(script.Parent.Parent:WaitForChild("Class"))
local Preload = require(script.Parent.Parent:WaitForChild("Preload"))
local Utils = require(script.Parent.Parent:WaitForChild("Utils"))
local Humanize = require(script.Parent.Parent:WaitForChild("Humanize"))
local Remote = require(script.Parent.Parent:WaitForChild("Remote"))
local Mutex = require(script.Parent.Parent:WaitForChild("Mutex"))

local App = Class.new("KDKit.GUI.App")
App.static.Page = require(script:WaitForChild("Page"))
App.static.Transition = require(script:WaitForChild("Transition"))
App.static.folder = game.Players.LocalPlayer:WaitForChild("PlayerGui")
App.static.nextDisplayOrder = 0
function App.static:useNextDisplayOrder()
    App.static.nextDisplayOrder += 1
    return App.static.nextDisplayOrder - 1
end

App.static.GET_DEBUG_UIS_STATE = function()
    local UserInputService = game:GetService("UserInputService")
    return {
        AccelerometerEnabled = UserInputService.AccelerometerEnabled,
        KeyboardEnabled = UserInputService.KeyboardEnabled,
        MouseEnabled = UserInputService.MouseEnabled,
        TouchEnabled = UserInputService.TouchEnabled,
    }
end

App.static.BUILTIN_SOURCES = { "INITIAL_SETUP", "APP_CLOSE", "APP_OPEN", "GO_HOME", "NEXT_PAGE_FAILED_TO_OPEN" }

function App:__init(module: ModuleScript)
    self.module = module
    self.mutex = Mutex.new(15)

    self.instance = Instance.new("ScreenGui", App.folder)
    self.instance.Name = self.module:GetFullName()
    self.instance.Enabled = false
    self.instance.IgnoreGuiInset = true
    self.instance.ResetOnSpawn = false
    self.instance.DisplayOrder = App:useNextDisplayOrder()
    self.instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    self.opened = false
    self.closedWithData = nil

    self.pages = {}
    self.history = {}

    Preload:ensureDescendants(module)

    self.proxy = require(self.module)
    self.common = table.clone(self.proxy)
    table.clear(self.proxy)
    setmetatable(self.proxy, {
        __index = self,
        __newindex = function(_, key)
            error(
                ("Apps are readonly. Perhaps you meant to write to app.common[%s] instead of app[%s]?"):format(
                    Utils:repr(key),
                    Utils:repr(key)
                )
            )
        end,
    })

    if type(self.common.transitionSources) ~= "table" then
        error("You must define a `transitionSources` table within your top level app.")
    else
        for _, name in App.BUILTIN_SOURCES do
            if self.common.transitionSources[name] then
                error(
                    ("You cannot define a transition source named `%s` since it will be created automatically."):format(
                        Utils:repr(name)
                    )
                )
            end
            self.common.transitionSources[name] = name
        end

        for key, value in self.common.transitionSources do
            if typeof(key) ~= "string" or key:len() < 1 then
                error(("Invalid transition source `%s`. Only non-empty strings are allowed."):format(Utils:repr(key)))
            elseif key ~= value then
                error(
                    ("Invalid transition source `%s`. Expected to find value `%s` but instead found `%s`."):format(
                        Utils:repr(key),
                        Utils:repr(key),
                        Utils:repr(value)
                    )
                )
            elseif Humanize:casing(key, "upperSnake") ~= key then
                error(
                    ("Invalid transition source `%s`. Expected to find value `%s` but instead found `%s`."):format(
                        Utils:repr(key),
                        Utils:repr(Humanize:casing(key, "upperSnake")),
                        Utils:repr(key)
                    )
                )
            end
        end

        function self.common.transitionSources.validate(transitionSources, name)
            return rawget(transitionSources, name) or error(("Invalid transition source `%s`"):format(Utils:repr(name)))
        end

        setmetatable(self.common.transitionSources, {
            __index = function(transitionSources, name)
                return transitionSources:validate(name) -- will error 100% of the time if __index is being called
            end,
            __newindex = function(_transitionSources, name)
                error(
                    ("You must define all transition sources statically in your app file. You cannot define them dynamically, like you tried to do with `%s`"):format(
                        Utils:repr(name)
                    )
                )
            end,
        })
    end

    for _, pageInstance in
        Utils:sort(self.module:GetChildren(), function(pageInstance)
            return if pageInstance.Name == "home" then 0 else 1
        end)
    do
        if not pageInstance:IsA("ModuleScript") then
            -- not actually a page instance
            continue
        end

        local page = App.Page.new(self, pageInstance)

        if page.name ~= Humanize:casing(page.name, "camel") and page.name ~= Humanize:casing(page.name, "snake") then
            error(
                ("Pages must be named using camelCase or snake_case, but found a page named `%s`. Please rename the page to `%s` or `%s`"):format(
                    page.name,
                    Humanize:casing(page.name, "camel"),
                    Humanize:casing(page.name, "snake")
                )
            )
        end

        if self.pages[page.name] then
            error(("You cannot have two pages with the same name `%s`"):format(page.name))
        end

        self.pages[page.name] = page
        if require(page.module) ~= page then
            error(
                ("Your module `%s` was expected to call `app:getPage(%s)` and return that page. Instead, the module returned `%s`."):format(
                    page.module:GetFullName(),
                    Utils:repr(page.name),
                    Utils:repr(require(page.module))
                )
            )
        end

        page:rawOpen(App.Transition.new(self, self.common.transitionSources.INITIAL_SETUP, nil, page, true))
        page:rawClose(App.Transition.new(self, self.common.transitionSources.INITIAL_SETUP, page, nil, false))
    end

    if not self.pages.home then
        error("You must have a page called `home`.")
    end

    self.last16Transitions = table.create(16)
    self.rawDoPageTransition = Remote:wrapWithClientErrorLogging(
        self.rawDoPageTransition,
        "App.rawDoPageTransition",
        function()
            return Utils:merge(App.GET_DEBUG_UIS_STATE(), {
                history = Utils:map(function(page)
                    return page.name
                end, self.history),
                last16Transitions = self.last16Transitions,
            })
        end
    )
end
App.__init = Remote:wrapWithClientErrorLogging(App.__init, "App.__init", App.GET_DEBUG_UIS_STATE)

function App:getPage(page)
    if type(page) == "string" then
        return self.pages[page]
    elseif type(page) == "table" and page.__class == App.Page then
        return page
    end
end

function App:getCurrentPage()
    return self.history[#self.history] or self.pages.home
end

function App:goHome(transitionSource, data)
    self.mutex:wait()
    self.common.transitionSources:validate(transitionSource)

    while next(self.history) do
        self:goBack(self.common.transitionSources.GO_HOME, { transitionSource = transitionSource, data = data })
    end
end

function App:goTo(pageReference, transitionSource, data)
    self.mutex:wait()
    self.common.transitionSources:validate(transitionSource)

    local nextPage = self:getPage(pageReference)
    if not nextPage then
        error(("Cannot goTo unknown page `%s`"):format(Utils:repr(pageReference)))
    end

    if nextPage == self.pages.home then
        return self:rawGoHome(transitionSource, data)
    end

    return self:rawDoPageTransition(
        App.Transition.new(self, transitionSource, self:getCurrentPage(), nextPage, true, data)
    )
end

function App:goBack(transitionSource, data)
    self.mutex:wait()
    self.common.transitionSources:validate(transitionSource)

    if not next(self.history) then
        warn(
            ("Called `app:goBack(%s, %s)` when there was nothing to go back to, already on the home page with no history. Doing nothing."):format(
                Utils:repr(transitionSource),
                Utils:repr(data)
            )
        )
        return
    end

    return self:rawDoPageTransition(
        App.Transition.new(
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
    table.insert(self.last16Transitions, transition:summary())
    while #self.last16Transitions > 16 do
        table.remove(self.last16Transitions, 1)
    end

    if not self.opened then
        error("Cannot do a page transition while the app is closed.")
    end

    return self.mutex:lock(function(unlock)
        if transition.from == transition.to and not transition.to._silenceSelfTraversalWarning then
            warn(
                ("Tried to transition from a page to itself (`%s` -> `%s`) with transitionSource = `%s` and data = `%s`, which might be a bug in your code. The page will be reloaded. To hide this warning, set `%s._silenceSelfTraversalWarning = true`."):format(
                    Utils:repr(transition.from.name),
                    Utils:repr(transition.to.name),
                    Utils:repr(transition.source),
                    Utils:repr(transition.data),
                    Utils:repr(transition.from.name)
                )
            )
        end

        transition.from:rawClose(transition)
        return Utils:ensure(function(failedToOpenNextPage, openNextPageTraceback)
            if failedToOpenNextPage then
                -- attempt to re-open the previous page
                Utils:ensure(
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
                    App.Transition.new(
                        self,
                        self.common.transitionSources.NEXT_PAGE_FAILED_TO_OPEN,
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
        error("You cannot open an app that is already open. Consider closing it and re-opening it.")
    end
    self.opened = true
    self.instance.Enabled = true

    self.pages.home:rawOpen(
        App.Transition.new(self, self.common.transitionSources.APP_OPEN, self.pages.home, nil, true)
    )
end

function App:close()
    if not self.opened then
        error("You cannot close an app that is already closed. Consider opening it and re-closing it.")
    end

    self:goHome(self.common.transitionSources.APP_CLOSE)
    task.delay(
        self.pages.home:rawClose(
            App.Transition.new(self, self.common.transitionSources.APP_CLOSE, self.pages.home, nil, false)
        ),
        function()
            if not self.opened then
                self.instance.Enabled = false
            end
        end
    )

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
