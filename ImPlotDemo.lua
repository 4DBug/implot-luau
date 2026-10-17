-- ImPlot demo (Luau port of implot_demo.cpp). Optional: ImPlot.lua never calls into this file.
-- Usage: require(path.to.ImPlotDemo)(G, ImPlot) -- defines ImPlot.ShowDemoWindow(p_open) -> new p_open
-- [Port] Lua has no function-level 'static': they are fields of the file-level table S (S.FunctionName.x).
-- [Port] Demo_* functions live in the table D (keeps the file chunk under the 200-locals limit).
return function(G, ImPlot)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local ImGuiCond = G.ImGuiCond
    local ImAxis = ImPlot.ImAxis
    local ImPlotProp = ImPlot.ImPlotProp
    local ImPlotFlags = ImPlot.ImPlotFlags
    local ImPlotAxisFlags = ImPlot.ImPlotAxisFlags
    local ImPlotMarker = ImPlot.ImPlotMarker
    local ImPlotLocation = ImPlot.ImPlotLocation
    local ImPlotLegendFlags = ImPlot.ImPlotLegendFlags
    local ImPlotColormap = ImPlot.ImPlotColormap
    local ImPlotBin = ImPlot.ImPlotBin
    local ImPlotHistogramFlags = ImPlot.ImPlotHistogramFlags
    local band, bor = bit32.band, bit32.bor
    local _

    local S = {}
    local D = {}

    -- [Port] IMGUI_DEMO_MARKER: forwarded to ImGui.DemoMarker when available (no __LINE__ in Lua: line is 0)
    local function IMGUI_DEMO_MARKER(section)
        if ImGui.DemoMarker then ImGui.DemoMarker("implot_demo.cpp", 0, section) end
    end

    -- [Port] CHECKBOX_FLAG(flags, flag) macro: label is the upstream flag name; returns the new flags
    local function CHECKBOX_FLAG(flags, name, flag)
        local _, v = ImGui.CheckboxFlags(name, flags, flag)
        return v
    end

    -- [Port] rand() -> math.random
    local function RandomRange(min, max)
        return min + math.random() * (max - min)
    end

    local Gauss = { V1 = 0, V2 = 0, S = 0, phase = 0 }
    local function RandomGauss()
        local X
        if Gauss.phase == 0 then
            repeat
                local U1 = math.random()
                local U2 = math.random()
                Gauss.V1 = 2 * U1 - 1
                Gauss.V2 = 2 * U2 - 1
                Gauss.S = Gauss.V1 * Gauss.V1 + Gauss.V2 * Gauss.V2
            until not (Gauss.S >= 1 or Gauss.S == 0)
            X = Gauss.V1 * math.sqrt(-2 * math.log(Gauss.S) / Gauss.S)
        else
            X = Gauss.V2 * math.sqrt(-2 * math.log(Gauss.S) / Gauss.S)
        end
        Gauss.phase = 1 - Gauss.phase
        return X
    end

    -- [Port] NormalDistribution<N> -> returns the Data array
    local function NormalDistribution(N, mean, sd)
        local data = table.create(N)
        for i = 1, N do
            data[i] = RandomGauss() * sd + mean
        end
        return data
    end

    -- utility structure for realtime plot
    -- [Port] ImVector<ImVec2> Data -> separate X/Y arrays (Spec.Stride is in elements, no interleaving needed)
    local function ScrollingBuffer(max_size)
        return { MaxSize = max_size or 2000, Offset = 0, X = {}, Y = {} }
    end
    local function ScrollingBuffer_AddPoint(b, x, y)
        if #b.X < b.MaxSize then
            table.insert(b.X, x)
            table.insert(b.Y, y)
        else
            b.X[b.Offset + 1] = x
            b.Y[b.Offset + 1] = y
            b.Offset = (b.Offset + 1) % b.MaxSize
        end
    end

    -- utility structure for realtime plot
    local function RollingBuffer()
        return { Span = 10.0, X = {}, Y = {} }
    end
    local function RollingBuffer_AddPoint(b, x, y)
        local xmod = math.fmod(x, b.Span)
        if #b.X > 0 and xmod < b.X[#b.X] then
            table.clear(b.X)
            table.clear(b.Y)
        end
        table.insert(b.X, xmod)
        table.insert(b.Y, y)
    end

    ---------------------------------------------------------------------------
    -- [SECTION] Demo Functions
    ---------------------------------------------------------------------------

    function D.Demo_Help()
        IMGUI_DEMO_MARKER("Demo_Help")
        ImGui.Text("ABOUT THIS DEMO:")
        ImGui.BulletText("Sections below are demonstrating many aspects of the library.")
        ImGui.BulletText("The \"Tools\" menu above gives access to: Style Editors (ImPlot/ImGui)\n" ..
                            "and Metrics (general purpose Dear ImGui debugging tool).")
        ImGui.Separator()
        ImGui.Text("PROGRAMMER GUIDE:")
        ImGui.BulletText("See the ShowDemoWindow() code in implot_demo.cpp. <- you are here!")
        ImGui.BulletText("If you see visual artifacts, do one of the following:")
        ImGui.Indent()
        ImGui.BulletText("Handle ImGuiBackendFlags_RendererHasVtxOffset for 16-bit indices in your backend.")
        ImGui.BulletText("Or, enable 32-bit indices in imconfig.h.")
        ImGui.BulletText("Your current configuration is:")
        ImGui.Indent()
        ImGui.BulletText("ImDrawIdx: %d-bit", 32) -- [Port] ImDrawIdx is unsigned int in the core
        local has_vtx_offset = "False"
        if band(ImGui.GetIO().BackendFlags, G.ImGuiBackendFlags.RendererHasVtxOffset) ~= 0 then has_vtx_offset = "True" end
        ImGui.BulletText("ImGuiBackendFlags_RendererHasVtxOffset: %s", has_vtx_offset)
        ImGui.Unindent()
        ImGui.Unindent()
        ImGui.Separator()
        ImGui.Text("USER GUIDE:")
        ImPlot.ShowUserGuide()
    end

    ---------------------------------------------------------------------------

    function D.Demo_Config()
        IMGUI_DEMO_MARKER("Config")
        ImGui.ShowFontSelector("Font")
        ImGui.ShowStyleSelector("ImGui Style")
        ImPlot.ShowStyleSelector("ImPlot Style")
        ImPlot.ShowColormapSelector("ImPlot Colormap")
        ImPlot.ShowInputMapSelector("Input Map")
        ImGui.Separator()
        local style = ImPlot.GetStyle()
        _, style.UseLocalTime = ImGui.Checkbox("Use Local Time", style.UseLocalTime)
        _, style.UseISO8601 = ImGui.Checkbox("Use ISO 8601", style.UseISO8601)
        _, style.Use24HourClock = ImGui.Checkbox("Use 24 Hour Clock", style.Use24HourClock)
        ImGui.Separator()
        if ImPlot.BeginPlot("Preview") then
            S.Demo_Config = S.Demo_Config or { now = os.time() }
            local now = S.Demo_Config.now
            ImPlot.SetupAxisScale(ImAxis.X1, ImPlot.ImPlotScale.Time)
            ImPlot.SetupAxisLimits(ImAxis.X1, now, now + 24 * 3600)
            for i = 0, 9 do
                local x = { now, now + 24 * 3600 }
                local y = { 0, i / 9.0 }
                ImGui.PushID(i)
                ImPlot.PlotLine("##Line", x, y, 2)
                ImGui.PopID()
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_LinePlots = { xs1 = table.create(1001, 0), ys1 = table.create(1001, 0), xs2 = table.create(20, 0), ys2 = table.create(20, 0) }
    function D.Demo_LinePlots()
        IMGUI_DEMO_MARKER("Plots/Line Plots")
        local s = S.Demo_LinePlots
        local xs1, ys1, xs2, ys2 = s.xs1, s.ys1, s.xs2, s.ys2
        local t = ImGui.GetTime()
        for i = 0, 1000 do
            xs1[i + 1] = i * 0.001
            ys1[i + 1] = 0.5 + 0.5 * math.sin(50 * (xs1[i + 1] + t / 10))
        end
        for i = 0, 19 do
            xs2[i + 1] = i * 1 / 19.0
            ys2[i + 1] = xs2[i + 1] * xs2[i + 1]
        end
        if ImPlot.BeginPlot("Line Plots") then
            ImPlot.SetupAxes("x", "y")
            ImPlot.PlotLine("f(x)", xs1, ys1, 1001)
            ImPlot.PlotLine("g(x)", xs2, ys2, 20, {
                Marker = ImPlotMarker.Circle,
                Flags = ImPlot.ImPlotLineFlags.Segments,
            })
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_FilledLinePlots = {
        xs1 = table.create(101, 0), ys1 = table.create(101, 0), ys2 = table.create(101, 0), ys3 = table.create(101, 0),
        show_lines = true, show_fills = true, fill_ref = 0, shade_mode = 0, flags = 0,
    }
    function D.Demo_FilledLinePlots()
        IMGUI_DEMO_MARKER("Plots/Filled Line Plots")
        local s = S.Demo_FilledLinePlots
        local xs1, ys1, ys2, ys3 = s.xs1, s.ys1, s.ys2, s.ys3
        math.randomseed(0)
        for i = 1, 101 do
            xs1[i] = i - 1
            ys1[i] = RandomRange(400.0, 450.0)
            ys2[i] = RandomRange(275.0, 350.0)
            ys3[i] = RandomRange(150.0, 225.0)
        end
        _, s.show_lines = ImGui.Checkbox("Lines", s.show_lines); ImGui.SameLine()
        _, s.show_fills = ImGui.Checkbox("Fills", s.show_fills)
        if s.show_fills then
            ImGui.SameLine()
            _, s.shade_mode = ImGui.RadioButton("To -INF", s.shade_mode, 0)
            ImGui.SameLine()
            _, s.shade_mode = ImGui.RadioButton("To +INF", s.shade_mode, 1)
            ImGui.SameLine()
            _, s.shade_mode = ImGui.RadioButton("To Ref", s.shade_mode, 2)
            if s.shade_mode == 2 then
                ImGui.SameLine()
                ImGui.SetNextItemWidth(100)
                s.fill_ref = ImGui.DragFloat("##Ref", s.fill_ref, 1, -100, 500)
            end
        end

        if ImPlot.BeginPlot("Stock Prices") then
            ImPlot.SetupAxes("Days", "Price")
            ImPlot.SetupAxesLimits(0, 100, 0, 500)
            if s.show_fills then
                local spec = ImPlot.ImPlotSpec()
                spec.Flags = s.flags
                spec.FillAlpha = 0.25
                local ref = s.fill_ref
                if s.shade_mode == 0 then ref = -math.huge elseif s.shade_mode == 1 then ref = math.huge end
                ImPlot.PlotShaded("Stock 1", xs1, ys1, 101, ref, spec)
                ImPlot.PlotShaded("Stock 2", xs1, ys2, 101, ref, spec)
                ImPlot.PlotShaded("Stock 3", xs1, ys3, 101, ref, spec)
            end
            if s.show_lines then
                ImPlot.PlotLine("Stock 1", xs1, ys1, 101)
                ImPlot.PlotLine("Stock 2", xs1, ys2, 101)
                ImPlot.PlotLine("Stock 3", xs1, ys3, 101)
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_ShadedPlots = {
        xs = table.create(1001, 0), ys = table.create(1001, 0), ys1 = table.create(1001, 0),
        ys2 = table.create(1001, 0), ys3 = table.create(1001, 0), ys4 = table.create(1001, 0),
        spec = nil, -- [Port] created on first use (ImPlotSpec(ImPlotProp_FillAlpha, 0.25f))
    }
    function D.Demo_ShadedPlots()
        IMGUI_DEMO_MARKER("Plots/Shaded Plots")
        local s = S.Demo_ShadedPlots
        local xs, ys, ys1, ys2, ys3, ys4 = s.xs, s.ys, s.ys1, s.ys2, s.ys3, s.ys4
        math.randomseed(0)
        for i = 1, 1001 do
            xs[i]  = (i - 1) * 0.001
            ys[i]  = 0.25 + 0.25 * math.sin(25 * xs[i]) * math.sin(5 * xs[i]) + RandomRange(-0.01, 0.01)
            ys1[i] = ys[i] + RandomRange(0.1, 0.12)
            ys2[i] = ys[i] - RandomRange(0.1, 0.12)
            ys3[i] = 0.75 + 0.2 * math.sin(25 * xs[i])
            ys4[i] = 0.75 + 0.1 * math.cos(25 * xs[i])
        end
        if s.spec == nil then s.spec = ImPlot.ImPlotSpec(ImPlotProp.FillAlpha, 0.25) end
        local spec = s.spec
        spec.FillAlpha = ImGui.DragFloat("Alpha", spec.FillAlpha, 0.01, 0, 1)

        if ImPlot.BeginPlot("Shaded Plots") then
            ImPlot.SetupLegend(ImPlotLocation.NorthWest, ImPlotLegendFlags.Reverse) -- reverse legend to match vertical order on plot
            ImPlot.PlotShaded("Uncertain Data", xs, ys1, ys2, 1001, spec)
            ImPlot.PlotLine("Uncertain Data", xs, ys, 1001, spec)
            ImPlot.PlotShaded("Overlapping", xs, ys3, ys4, 1001, spec)
            ImPlot.PlotLine("Overlapping", xs, ys3, 1001, spec)
            ImPlot.PlotLine("Overlapping", xs, ys4, 1001, spec)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_ScatterPlots = { xs1 = table.create(100, 0), ys1 = table.create(100, 0), xs2 = table.create(50, 0), ys2 = table.create(50, 0) }
    function D.Demo_ScatterPlots()
        IMGUI_DEMO_MARKER("Plots/Scatter Plots")
        local s = S.Demo_ScatterPlots
        math.randomseed(0)
        for i = 1, 100 do
            s.xs1[i] = (i - 1) * 0.01
            s.ys1[i] = s.xs1[i] + 0.1 * math.random()
        end
        for i = 1, 50 do
            s.xs2[i] = 0.25 + 0.2 * math.random()
            s.ys2[i] = 0.75 + 0.2 * math.random()
        end

        if ImPlot.BeginPlot("Scatter Plot") then
            ImPlot.PlotScatter("Data 1", s.xs1, s.ys1, 100)
            ImPlot.PlotScatter("Data 2", s.xs2, s.ys2, 50, {
                Marker = ImPlotMarker.Square,
                MarkerSize = 6,
                LineColor = ImPlot.GetColormapColor(1),
                FillColor = ImPlot.GetColormapColor(1),
                FillAlpha = 0.25,
            })
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_BubblePlots = { xs = table.create(20, 0), ys1 = table.create(20, 0), ys2 = table.create(20, 0), szs1 = table.create(20, 0), szs2 = table.create(20, 0) }
    function D.Demo_BubblePlots()
        IMGUI_DEMO_MARKER("Plots/Bubble Plots")
        local s = S.Demo_BubblePlots
        math.randomseed(0)
        for i = 1, 20 do
            s.xs[i] = (i - 1) * 0.1
            s.ys1[i] = math.random()
            s.ys2[i] = math.random()

            s.szs1[i] = 0.02 + 0.08 * math.random()
            s.szs2[i] = 0.02 + 0.08 * math.random()
        end

        if ImPlot.BeginPlot("Bubble Plot", ImVec2(-1, 0), ImPlotFlags.Equal) then
            ImPlot.PlotBubbles("Data 1", s.xs, s.ys1, s.szs1, 20, { FillAlpha = 0.5 })
            ImPlot.PlotBubbles("Data 2", s.xs, s.ys2, s.szs2, 20, { FillAlpha = 0.5, LineColor = ImVec4(0, 0, 0, 0.0) })

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_PolygonPlots = {
        -- Triangle (convex)
        tri_xs = { 0.5, 1.0, 0.0 },
        tri_ys = { 1.0, 0.0, 0.0 },
        pent_xs = table.create(5, 0), pent_ys = table.create(5, 0),
        star_xs = table.create(10, 0), star_ys = table.create(10, 0),
    }
    function D.Demo_PolygonPlots()
        IMGUI_DEMO_MARKER("Plots/Polygon Plots")
        local s = S.Demo_PolygonPlots
        -- Pentagon (convex)
        for i = 0, 4 do
            local angle = i * 2.0 * 3.14159 / 5.0 - 3.14159 / 2.0
            s.pent_xs[i + 1] = 3.0 + 0.8 * math.cos(angle)
            s.pent_ys[i + 1] = 0.5 + 0.8 * math.sin(angle)
        end

        -- Star (concave), counter-clockwise
        for i = 0, 9 do
            local angle = i * 2.0 * 3.14159 / 10.0 - 3.14159 / 2.0
            local radius = 0.3
            if i % 2 == 0 then radius = 0.8 end
            s.star_xs[i + 1] = 5.5 + radius * math.cos(angle)
            s.star_ys[i + 1] = 0.5 + radius * math.sin(angle)
        end

        -- [Port] PlotPolygon is not ported yet in ImPlot.lua
        if ImPlot.PlotPolygon == nil then
            ImGui.TextDisabled("[Port] TODO: PlotPolygon is not ported yet")
            return
        end
        if ImPlot.BeginPlot("Polygon Plot", ImVec2(-1, 0), ImPlotFlags.Equal) then
            ImPlot.PlotPolygon("Triangle", s.tri_xs, s.tri_ys, 3, {
                FillAlpha = 0.5,
            })
            ImPlot.PlotPolygon("Pentagon", s.pent_xs, s.pent_ys, 5, {
                FillAlpha = 0.5,
                FillColor = ImVec4(0, 1, 0, 1),
            })
            ImPlot.PlotPolygon("Star (Concave)", s.star_xs, s.star_ys, 10, {
                FillAlpha = 0.5,
                FillColor = ImVec4(1, 1, 0, 1),
                Flags = ImPlot.ImPlotPolygonFlags.Concave,
            })

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_StairstepPlots = { ys1 = table.create(21, 0), ys2 = table.create(21, 0), flags = 0 }
    function D.Demo_StairstepPlots()
        IMGUI_DEMO_MARKER("Plots/Stairstep Plots")
        local s = S.Demo_StairstepPlots
        for i = 0, 20 do
            s.ys1[i + 1] = 0.75 + 0.2 * math.sin(10 * i * 0.05)
            s.ys2[i + 1] = 0.25 + 0.2 * math.sin(10 * i * 0.05)
        end
        local ImPlotStairsFlags = ImPlot.ImPlotStairsFlags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotStairsFlags_Shaded", ImPlotStairsFlags.Shaded)
        if ImPlot.BeginPlot("Stairstep Plot") then
            ImPlot.SetupAxes("x", "f(x)")
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            ImPlot.PlotLine("##1", s.ys1, 21, 0.05, 0, { LineColor = ImVec4(0.5, 0.5, 0.5, 1.0) })
            ImPlot.PlotLine("##2", s.ys2, 21, 0.05, 0, { LineColor = ImVec4(0.5, 0.5, 0.5, 1.0) })

            local spec = ImPlot.ImPlotSpec()
            spec.Flags = s.flags
            spec.FillAlpha = 0.25
            spec.Marker = ImPlotMarker.Auto
            ImPlot.PlotStairs("Post Step (default)", s.ys1, 21, 0.05, 0, spec)

            spec.Flags = bor(s.flags, ImPlotStairsFlags.PreStep)
            spec.FillAlpha = 0.25
            spec.Marker = ImPlotMarker.Auto
            ImPlot.PlotStairs("Pre Step", s.ys2, 21, 0.05, 0, spec)

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_BarPlots = { data = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } }
    function D.Demo_BarPlots()
        IMGUI_DEMO_MARKER("Plots/Bar Plots")
        local data = S.Demo_BarPlots.data
        if ImPlot.BeginPlot("Bar Plot") then
            ImPlot.PlotBars("Vertical", data, 10, 0.7, 1)
            ImPlot.PlotBars("Horizontal", data, 10, 0.4, 1, { Flags = ImPlot.ImPlotBarsFlags.Horizontal })
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_BarGroups = {
        data = { 83, 67, 23, 89, 83, 78, 91, 82, 85, 90,  -- midterm
                 80, 62, 56, 99, 55, 78, 88, 78, 90, 100, -- final
                 80, 69, 52, 92, 72, 78, 75, 76, 89, 95 }, -- course
        ilabels = { "Midterm Exam", "Final Exam", "Course Grade" },
        glabels = { "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10" },
        positions = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        items = 3,
        groups = 10,
        size = 0.67,
        flags = 0,
        horz = false,
    }
    function D.Demo_BarGroups()
        IMGUI_DEMO_MARKER("Plots/Bar Groups")
        local s = S.Demo_BarGroups
        local ImPlotBarGroupsFlags = ImPlot.ImPlotBarGroupsFlags

        _, s.flags = ImGui.CheckboxFlags("Stacked", s.flags, ImPlotBarGroupsFlags.Stacked)
        ImGui.SameLine()
        _, s.horz = ImGui.Checkbox("Horizontal", s.horz)

        s.items = ImGui.SliderInt("Items", s.items, 1, 3)
        s.size = ImGui.SliderFloat("Size", s.size, 0, 1)

        if ImPlot.BeginPlot("Bar Group") then
            ImPlot.SetupLegend(ImPlotLocation.East, ImPlotLegendFlags.Outside)
            if s.horz then
                ImPlot.SetupAxes("Score", "Student", ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.AutoFit)
                ImPlot.SetupAxisTicks(ImAxis.Y1, s.positions, s.groups, s.glabels)
                ImPlot.PlotBarGroups(s.ilabels, s.data, s.items, s.groups, s.size, 0, { Flags = bor(s.flags, ImPlotBarGroupsFlags.Horizontal) })
            else
                ImPlot.SetupAxes("Student", "Score", ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.AutoFit)
                ImPlot.SetupAxisTicks(ImAxis.X1, s.positions, s.groups, s.glabels)
                ImPlot.PlotBarGroups(s.ilabels, s.data, s.items, s.groups, s.size, 0, { Flags = s.flags })
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_BarStacks = {
        Liars = -1,
        diverging = true,
        politicians = { "Trump", "Bachman", "Cruz", "Gingrich", "Palin", "Santorum", "Walker", "Perry", "Ryan", "McCain", "Rubio", "Romney", "Rand Paul", "Christie", "Biden", "Kasich", "Sanders", "J Bush", "H Clinton", "Obama" },
        data_reg = { 18, 26, 7, 14, 10, 8, 6, 11, 4, 4, 3, 8, 6, 8, 6, 5, 0, 3, 1, 2,                -- Pants on Fire
                     43, 36, 30, 21, 30, 27, 25, 17, 11, 22, 15, 16, 16, 17, 12, 12, 14, 6, 13, 12,  -- False
                     16, 13, 28, 22, 15, 21, 15, 18, 30, 17, 24, 18, 13, 10, 14, 15, 17, 22, 14, 12, -- Mostly False
                     17, 10, 13, 25, 12, 22, 19, 26, 23, 17, 22, 27, 20, 26, 29, 17, 18, 22, 21, 27, -- Half True
                     5, 7, 16, 10, 10, 12, 23, 13, 17, 20, 22, 16, 23, 19, 20, 26, 36, 29, 27, 26,   -- Mostly True
                     1, 8, 6, 8, 23, 10, 12, 15, 15, 20, 14, 15, 22, 20, 19, 25, 15, 18, 24, 21 },   -- True
        labels_reg = { "Pants on Fire", "False", "Mostly False", "Half True", "Mostly True", "True" },
        data_div = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,                                         -- Pants on Fire (dummy, to order legend logically)
                     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,                                         -- False         (dummy, to order legend logically)
                     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,                                         -- Mostly False  (dummy, to order legend logically)
                     -16, -13, -28, -22, -15, -21, -15, -18, -30, -17, -24, -18, -13, -10, -14, -15, -17, -22, -14, -12, -- Mostly False
                     -43, -36, -30, -21, -30, -27, -25, -17, -11, -22, -15, -16, -16, -17, -12, -12, -14, -6, -13, -12,  -- False
                     -18, -26, -7, -14, -10, -8, -6, -11, -4, -4, -3, -8, -6, -8, -6, -5, 0, -3, -1, -2,                 -- Pants on Fire
                     17, 10, 13, 25, 12, 22, 19, 26, 23, 17, 22, 27, 20, 26, 29, 17, 18, 22, 21, 27,                     -- Half True
                     5, 7, 16, 10, 10, 12, 23, 13, 17, 20, 22, 16, 23, 19, 20, 26, 36, 29, 27, 26,                       -- Mostly True
                     1, 8, 6, 8, 23, 10, 12, 15, 15, 20, 14, 15, 22, 20, 19, 25, 15, 18, 24, 21 },                       -- True
        labels_div = { "Pants on Fire", "False", "Mostly False", "Mostly False", "False", "Pants on Fire", "Half True", "Mostly True", "True" },
    }
    function D.Demo_BarStacks()
        IMGUI_DEMO_MARKER("Plots/Bar Stacks")
        local s = S.Demo_BarStacks

        if s.Liars == -1 then
            -- [Port] reuse the colormap if a previous demo run (same context) already added it
            s.Liars = ImPlot.GetColormapIndex("Liars")
            if s.Liars == -1 then
                local Liars_Data = { 4282515870, 4282609140, 4287357182, 4294630301, 4294945280, 4294921472 }
                s.Liars = ImPlot.AddColormap("Liars", Liars_Data, 6)
            end
        end

        _, s.diverging = ImGui.Checkbox("Diverging", s.diverging)

        ImPlot.PushColormap(s.Liars)
        if ImPlot.BeginPlot("PolitiFact: Who Lies More?", ImVec2(-1, ImGui.GetTextLineHeight() * 25), ImPlotFlags.NoMouseText) then
            ImPlot.SetupLegend(ImPlotLocation.South, bor(ImPlotLegendFlags.Outside, ImPlotLegendFlags.Horizontal))
            ImPlot.SetupAxes(nil, nil, bor(ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.NoDecorations), bor(ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.Invert))
            ImPlot.SetupAxisTicks(ImAxis.Y1, 0, 19, 20, s.politicians, false)
            local spec = ImPlot.ImPlotSpec(); spec.Flags = bor(ImPlot.ImPlotBarGroupsFlags.Stacked, ImPlot.ImPlotBarGroupsFlags.Horizontal)
            if s.diverging then
                ImPlot.PlotBarGroups(s.labels_div, s.data_div, 9, 20, 0.75, 0, spec)
            else
                ImPlot.PlotBarGroups(s.labels_reg, s.data_reg, 6, 20, 0.75, 0, spec)
            end
            ImPlot.EndPlot()
        end
        ImPlot.PopColormap()
    end

    ---------------------------------------------------------------------------

    S.Demo_ErrorBars = {
        xs   = { 1, 2, 3, 4, 5 },
        bar  = { 1, 2, 5, 3, 4 },
        lin1 = { 8, 8, 9, 7, 8 },
        lin2 = { 6, 7, 6, 9, 6 },
        err1 = { 0.2, 0.4, 0.2, 0.6, 0.4 },
        err2 = { 0.4, 0.2, 0.4, 0.8, 0.6 },
        err3 = { 0.09, 0.14, 0.09, 0.12, 0.16 },
        err4 = { 0.02, 0.08, 0.15, 0.05, 0.2 },
    }
    function D.Demo_ErrorBars()
        IMGUI_DEMO_MARKER("Plots/Error Bars")
        local s = S.Demo_ErrorBars
        local xs = s.xs

        if ImPlot.BeginPlot("##ErrorBars") then
            ImPlot.SetupAxesLimits(0, 6, 0, 10)

            ImPlot.PlotBars("Bar", xs, s.bar, 5, 0.5)
            ImPlot.PlotErrorBars("Bar", xs, s.bar, s.err1, 5)

            ImPlot.PlotErrorBars("Line", xs, s.lin1, s.err1, s.err2, 5, { LineColor = ImPlot.GetColormapColor(1), Size = 0 })
            ImPlot.PlotLine("Line", xs, s.lin1, 5, { Marker = ImPlotMarker.Square })

            local spec = ImPlot.ImPlotSpec()
            spec.LineColor = ImPlot.GetColormapColor(2)
            spec.Size = 6
            spec.LineWeight = 1.5
            ImPlot.PlotErrorBars("Scatter", xs, s.lin2, s.err2, 5, spec)
            spec.Flags = ImPlot.ImPlotErrorBarsFlags.Horizontal
            ImPlot.PlotErrorBars("Scatter", xs, s.lin2, s.err3, s.err4, 5, spec)
            ImPlot.PlotScatter("Scatter", xs, s.lin2, 5)

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_StemPlots = { xs = table.create(51, 0), ys1 = table.create(51, 0), ys2 = table.create(51, 0) }
    function D.Demo_StemPlots()
        IMGUI_DEMO_MARKER("Plots/Stem Plots")
        local s = S.Demo_StemPlots
        for i = 1, 51 do
            local x = (i - 1) * 0.02
            s.xs[i] = x
            s.ys1[i] = 1.0 + 0.5 * math.sin(25 * x) * math.cos(2 * x)
            s.ys2[i] = 0.5 + 0.25 * math.sin(10 * x) * math.sin(x)
        end
        if ImPlot.BeginPlot("Stem Plots") then
            ImPlot.SetupAxisLimits(ImAxis.X1, 0, 1.0)
            ImPlot.SetupAxisLimits(ImAxis.Y1, 0, 1.6)
            ImPlot.PlotStems("Stems 1", s.xs, s.ys1, 51)
            ImPlot.PlotStems("Stems 2", s.xs, s.ys2, 51, 0, { Marker = ImPlotMarker.Circle })
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_InfiniteLines = { vals = { 0.25, 0.5, 0.75 } }
    function D.Demo_InfiniteLines()
        IMGUI_DEMO_MARKER("Plots/Infinite Lines")
        local vals = S.Demo_InfiniteLines.vals
        if ImPlot.BeginPlot("##Infinite") then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoInitialFit, ImPlotAxisFlags.NoInitialFit)
            ImPlot.PlotInfLines("Vertical", vals, 3)
            ImPlot.PlotInfLines("Horizontal", vals, 3, { Flags = ImPlot.ImPlotInfLinesFlags.Horizontal })
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_PieCharts = {
        labels1 = { "Frogs", "Hogs", "Dogs", "Logs" },
        data1   = { 0.15, 0.30, 0.2, 0.05 },
        flags   = 0,
        labels2 = { "A", "B", "C", "D", "E" },
        data2   = { 1, 1, 2, 3, 5 },
    }
    function D.Demo_PieCharts()
        IMGUI_DEMO_MARKER("Plots/Pie Charts")
        local s = S.Demo_PieCharts
        local ImPlotPieChartFlags = ImPlot.ImPlotPieChartFlags
        ImGui.SetNextItemWidth(250)
        ImGui.DragFloat4("Values", s.data1, 0.01, 0, 1)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotPieChartFlags_Normalize", ImPlotPieChartFlags.Normalize)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotPieChartFlags_IgnoreHidden", ImPlotPieChartFlags.IgnoreHidden)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotPieChartFlags_Exploding", ImPlotPieChartFlags.Exploding)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotPieChartFlags_NoSliceBorder", ImPlotPieChartFlags.NoSliceBorder)

        local sz = ImGui.GetTextLineHeight() * 16
        if ImPlot.BeginPlot("##Pie1", ImVec2(sz, sz), bor(ImPlotFlags.Equal, ImPlotFlags.NoMouseText)) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            ImPlot.PlotPieChart(s.labels1, s.data1, 4, 0.5, 0.5, 0.4, "%.2f", 90, { Flags = s.flags })
            ImPlot.EndPlot()
        end

        ImGui.SameLine()

        ImPlot.PushColormap(ImPlotColormap.Pastel)
        if ImPlot.BeginPlot("##Pie2", ImVec2(sz, sz), bor(ImPlotFlags.Equal, ImPlotFlags.NoMouseText)) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            ImPlot.PlotPieChart(s.labels2, s.data2, 5, 0.5, 0.5, 0.4, "%.0f", 180, { Flags = s.flags })
            ImPlot.EndPlot()
        end
        ImPlot.PopColormap()
    end

    ---------------------------------------------------------------------------

    S.Demo_Heatmaps = {
        -- [Port] float values1[7][7] -> flat row-major array
        values1 = { 0.8, 2.4, 2.5, 3.9, 0.0, 4.0, 0.0,
                    2.4, 0.0, 4.0, 1.0, 2.7, 0.0, 0.0,
                    1.1, 2.4, 0.8, 4.3, 1.9, 4.4, 0.0,
                    0.6, 0.0, 0.3, 0.0, 3.1, 0.0, 0.0,
                    0.7, 1.7, 0.6, 2.6, 2.2, 6.2, 0.0,
                    1.3, 1.2, 0.0, 0.0, 0.0, 3.2, 5.1,
                    0.1, 2.0, 0.0, 1.4, 0.0, 1.9, 6.3 },
        scale_min = 0,
        scale_max = 6.3,
        xlabels = { "C1", "C2", "C3", "C4", "C5", "C6", "C7" },
        ylabels = { "R1", "R2", "R3", "R4", "R5", "R6", "R7" },
        map = ImPlotColormap.Viridis,
        hm_flags = 0,
        axes_flags = bor(ImPlotAxisFlags.Lock, ImPlotAxisFlags.NoGridLines, ImPlotAxisFlags.NoTickMarks),
        values2 = table.create(80 * 80, 0),
    }
    function D.Demo_Heatmaps()
        IMGUI_DEMO_MARKER("Plots/Heatmaps")
        local s = S.Demo_Heatmaps

        if ImPlot.ColormapButton(ImPlot.GetColormapName(s.map), ImVec2(225, 0), s.map) then
            s.map = (s.map + 1) % ImPlot.GetColormapCount()
            -- We bust the color cache of our plots so that item colors will
            -- resample the new colormap in the event that they have already
            -- been created. See documentation in implot.h.
            ImPlot.BustColorCache("##Heatmap1")
            ImPlot.BustColorCache("##Heatmap2")
        end

        ImGui.SameLine()
        ImGui.LabelText("##Colormap Index", "%s", "Change Colormap")
        ImGui.SetNextItemWidth(225)
        s.scale_min, s.scale_max = ImGui.DragFloatRange2("Min / Max", s.scale_min, s.scale_max, 0.01, -20, 20)

        _, s.hm_flags = ImGui.CheckboxFlags("Column Major", s.hm_flags, ImPlot.ImPlotHeatmapFlags.ColMajor)

        local axes_flags = s.axes_flags

        ImPlot.PushColormap(s.map)

        local sz = ImGui.GetTextLineHeight() * 14
        if ImPlot.BeginPlot("##Heatmap1", ImVec2(sz, sz), bor(ImPlotFlags.NoLegend, ImPlotFlags.NoMouseText)) then
            ImPlot.SetupAxes(nil, nil, axes_flags, axes_flags)
            ImPlot.SetupAxisTicks(ImAxis.X1, 0 + 1.0 / 14.0, 1 - 1.0 / 14.0, 7, s.xlabels)
            ImPlot.SetupAxisTicks(ImAxis.Y1, 1 - 1.0 / 14.0, 0 + 1.0 / 14.0, 7, s.ylabels)
            ImPlot.PlotHeatmap("heat", s.values1, 7, 7, s.scale_min, s.scale_max, "%g", ImPlot.ImPlotPoint(0, 0), ImPlot.ImPlotPoint(1, 1), { Flags = s.hm_flags })
            ImPlot.EndPlot()
        end
        ImGui.SameLine()
        ImPlot.ColormapScale("##HeatScale", s.scale_min, s.scale_max, ImVec2(60, 225))

        ImGui.SameLine()

        local size = 80
        local values2 = s.values2
        math.randomseed(math.floor(ImGui.GetTime() * 1000000))
        for i = 1, size * size do
            values2[i] = RandomRange(0.0, 1.0)
        end

        if ImPlot.BeginPlot("##Heatmap2", ImVec2(sz, sz)) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(-1, 1, -1, 1)
            ImPlot.PlotHeatmap("heat1", values2, size, size, 0, 1, false)
            ImPlot.PlotHeatmap("heat2", values2, size, size, 0, 1, false, ImPlot.ImPlotPoint(-1, -1), ImPlot.ImPlotPoint(0, 0))
            ImPlot.EndPlot()
        end
        ImPlot.PopColormap()
    end

    ---------------------------------------------------------------------------

    S.Demo_Histogram = {
        hist_flags = ImPlotHistogramFlags.Density,
        bins = 50,
        mu = 5,
        sigma = 2,
        range = false,
        rrange = { -3, 13 }, -- [Port] rmin, rmax -> one array for DragFloat2
        dist = nil, -- [Port] NormalDistribution<10000> created on first use
        x = table.create(100, 0),
        y = table.create(100, 0),
    }
    function D.Demo_Histogram()
        IMGUI_DEMO_MARKER("Plots/Histogram")
        local s = S.Demo_Histogram
        ImGui.SetNextItemWidth(200)
        _, s.bins = ImGui.RadioButton("Sqrt", s.bins, ImPlotBin.Sqrt); ImGui.SameLine()
        _, s.bins = ImGui.RadioButton("Sturges", s.bins, ImPlotBin.Sturges); ImGui.SameLine()
        _, s.bins = ImGui.RadioButton("Rice", s.bins, ImPlotBin.Rice); ImGui.SameLine()
        _, s.bins = ImGui.RadioButton("Scott", s.bins, ImPlotBin.Scott); ImGui.SameLine()
        if ImGui.RadioButtonEx("N Bins", s.bins >= 0) then s.bins = 50 end
        if s.bins >= 0 then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(200)
            s.bins = ImGui.SliderInt("##Bins", s.bins, 1, 100)
        end
        _, s.hist_flags = ImGui.CheckboxFlags("Horizontal", s.hist_flags, ImPlotHistogramFlags.Horizontal)
        ImGui.SameLine()
        _, s.hist_flags = ImGui.CheckboxFlags("Density", s.hist_flags, ImPlotHistogramFlags.Density)
        ImGui.SameLine()
        _, s.hist_flags = ImGui.CheckboxFlags("Cumulative", s.hist_flags, ImPlotHistogramFlags.Cumulative)

        _, s.range = ImGui.Checkbox("Range", s.range)
        if s.range then
            ImGui.SameLine()
            ImGui.SetNextItemWidth(200)
            ImGui.DragFloat2("##Range", s.rrange, 0.1, -3, 13)
            ImGui.SameLine()
            _, s.hist_flags = ImGui.CheckboxFlags("Exclude Outliers", s.hist_flags, ImPlotHistogramFlags.NoOutliers)
        end
        if s.dist == nil then s.dist = NormalDistribution(10000, s.mu, s.sigma) end
        local mu, sigma, x, y = s.mu, s.sigma, s.x, s.y
        local hist_flags = s.hist_flags
        if band(hist_flags, ImPlotHistogramFlags.Density) ~= 0 then
            for i = 1, 100 do
                x[i] = -3 + 16 * (i - 1) / 99.0
                y[i] = math.exp(-(x[i] - mu) * (x[i] - mu) / (2 * sigma * sigma)) / (sigma * math.sqrt(2 * 3.141592653589793238))
            end
            if band(hist_flags, ImPlotHistogramFlags.Cumulative) ~= 0 then
                for i = 2, 100 do
                    y[i] += y[i - 1]
                end
                for i = 1, 100 do
                    y[i] /= y[100]
                end
            end
        end

        if ImPlot.BeginPlot("##Histograms") then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.AutoFit)
            local range = ImPlot.ImPlotRange()
            if s.range then range = ImPlot.ImPlotRange(s.rrange[1], s.rrange[2]) end
            ImPlot.PlotHistogram("Empirical", s.dist, 10000, s.bins, 1.0, range, {
                FillAlpha = 0.5,
                Flags = hist_flags,
            })
            if band(hist_flags, ImPlotHistogramFlags.Density) ~= 0 and band(hist_flags, ImPlotHistogramFlags.NoOutliers) == 0 then
                if band(hist_flags, ImPlotHistogramFlags.Horizontal) ~= 0 then
                    ImPlot.PlotLine("Theoretical", y, x, 100)
                else
                    ImPlot.PlotLine("Theoretical", x, y, 100)
                end
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_Histogram2D = { count = 50000, xybins = { 100, 100 }, hist_flags = 0, dist1 = nil, dist2 = nil }
    function D.Demo_Histogram2D()
        IMGUI_DEMO_MARKER("Plots/Histogram 2D")
        local s = S.Demo_Histogram2D

        s.count = ImGui.SliderInt("Count", s.count, 100, 100000)
        ImGui.SliderInt2("Bins", s.xybins, 1, 500)
        ImGui.SameLine()
        _, s.hist_flags = ImGui.CheckboxFlags("Density", s.hist_flags, ImPlotHistogramFlags.Density)

        if s.dist1 == nil then
            s.dist1 = NormalDistribution(100000, 1, 2)
            s.dist2 = NormalDistribution(100000, 1, 1)
        end
        local max_count = 0
        local flags = bor(ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.Foreground)
        ImPlot.PushColormap("Hot")
        if ImPlot.BeginPlot("##Hist2D", ImVec2(ImGui.GetContentRegionAvail().x - 100 - ImGui.GetStyle().ItemSpacing.x, 0)) then
            ImPlot.SetupAxes(nil, nil, flags, flags)
            ImPlot.SetupAxesLimits(-6, 6, -6, 6)
            max_count = ImPlot.PlotHistogram2D("Hist2D", s.dist1, s.dist2, s.count, s.xybins[1], s.xybins[2], ImPlot.ImPlotRect(-6, 6, -6, 6), { Flags = s.hist_flags })
            ImPlot.EndPlot()
        end
        ImGui.SameLine()
        local label = "Count"
        if band(s.hist_flags, ImPlotHistogramFlags.Density) ~= 0 then label = "Density" end
        ImPlot.ColormapScale(label, 0, max_count, ImVec2(100, 0))
        ImPlot.PopColormap()
    end

    ---------------------------------------------------------------------------

    S.Demo_DigitalPlots = {
        paused = false,
        dataDigital = { ScrollingBuffer(), ScrollingBuffer(), ScrollingBuffer() },
        dataAnalog = { ScrollingBuffer(), ScrollingBuffer() },
        showDigital = { true, false, false },
        showAnalog = { true, false },
        t = 0,
        last_t = 0,
    }
    function D.Demo_DigitalPlots()
        IMGUI_DEMO_MARKER("Plots/Digital Plots")
        local s = S.Demo_DigitalPlots
        ImGui.BulletText("Digital plots do not respond to Y drag and zoom, so that")
        ImGui.Indent()
        ImGui.Text("you can drag analog plots over the rising/falling digital edge.")
        ImGui.Unindent()

        local dataDigital, dataAnalog, showDigital, showAnalog = s.dataDigital, s.dataAnalog, s.showDigital, s.showAnalog

        _, s.paused = ImGui.Checkbox("Pause", s.paused)
        _, showDigital[1] = ImGui.Checkbox("digital_0", showDigital[1]); ImGui.SameLine()
        _, showDigital[2] = ImGui.Checkbox("digital_1", showDigital[2]); ImGui.SameLine()
        _, showDigital[3] = ImGui.Checkbox("digital_2", showDigital[3]); ImGui.SameLine()
        _, showAnalog[1] = ImGui.Checkbox("analog_0", showAnalog[1]); ImGui.SameLine()
        _, showAnalog[2] = ImGui.Checkbox("analog_1", showAnalog[2])

        -- [Port] bool -> 0/1 for digital signal values
        local function b2n(b) if b then return 1 end return 0 end
        if not s.paused then
            s.t += ImGui.GetIO().DeltaTime
            local t = s.t
            if t - s.last_t >= 0.01 then
                s.last_t = t
                -- Digital signal values
                if showDigital[1] then
                    ScrollingBuffer_AddPoint(dataDigital[1], t, b2n(math.sin(2 * t) > 0.45))
                end
                if showDigital[2] then
                    ScrollingBuffer_AddPoint(dataDigital[2], t, b2n(math.sin(2 * t) < 0.45))
                end
                if showDigital[3] then
                    ScrollingBuffer_AddPoint(dataDigital[3], t, b2n(math.sin(50 * t) > 0.5))
                end
                -- Analog signal values
                if showAnalog[1] then
                    ScrollingBuffer_AddPoint(dataAnalog[1], t, math.sin(2 * t))
                end
                if showAnalog[2] then
                    ScrollingBuffer_AddPoint(dataAnalog[2], t, math.cos(2 * t))
                end
            end
        end
        if ImPlot.BeginPlot("##Digital") then
            local cond = ImGuiCond.Always
            if s.paused then cond = ImGuiCond.Once end
            ImPlot.SetupAxisLimits(ImAxis.X1, s.t - 10.0, s.t, cond)
            ImPlot.SetupAxisLimits(ImAxis.Y1, -1, 1)
            for i = 1, 3 do
                local d = dataDigital[i]
                if showDigital[i] and #d.X > 0 then
                    ImPlot.PlotDigital(string.format("digital_%d", i - 1), d.X, d.Y, #d.X, {
                        Offset = d.Offset,
                        Size = i * 4,
                    })
                end
            end
            for i = 1, 2 do
                local d = dataAnalog[i]
                if showAnalog[i] then
                    if #d.X > 0 then
                        ImPlot.PlotLine(string.format("analog_%d", i - 1), d.X, d.Y, #d.X, {
                            Offset = d.Offset,
                        })
                    end
                end
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    -- [Port] ImVec2/ImVec4 statics -> arrays for SliderFloat2/ColorEdit4
    S.Demo_Images = { bmin = { 0, 0 }, bmax = { 1, 1 }, uv0 = { 0, 0 }, uv1 = { 1, 1 }, tint = { 1, 1, 1, 1 } }
    function D.Demo_Images()
        IMGUI_DEMO_MARKER("Plots/Images")
        local s = S.Demo_Images
        ImGui.BulletText("Below we are displaying the font texture, which is the only texture we have\naccess to in this demo.")
        ImGui.BulletText("Use the 'ImTextureID' type as storage to pass pointers or identifiers to your\nown texture data.")
        ImGui.BulletText("See ImGui Wiki page 'Image Loading and Displaying Examples'.")
        ImGui.SliderFloat2("Min", s.bmin, -2, 2, "%.1f")
        ImGui.SliderFloat2("Max", s.bmax, -2, 2, "%.1f")
        ImGui.SliderFloat2("UV0", s.uv0, -2, 2, "%.1f")
        ImGui.SliderFloat2("UV1", s.uv1, -2, 2, "%.1f")
        ImGui.ColorEdit4("Tint", s.tint)
        if ImPlot.BeginPlot("##image") then
            -- We use the font atlas ImTextureRef for this demo, but in your real code when you submit
            -- an image that you have loaded yourself, you would normally have a ImTextureID which works
            -- just as well (as ImTextureRef can be constructed from ImTextureID).
            ImPlot.PlotImage("my image", ImGui.GetIO().Fonts.TexRef, ImPlot.ImPlotPoint(s.bmin[1], s.bmin[2]), ImPlot.ImPlotPoint(s.bmax[1], s.bmax[2]),
                ImVec2(s.uv0[1], s.uv0[2]), ImVec2(s.uv1[1], s.uv1[2]), ImVec4(s.tint[1], s.tint[2], s.tint[3], s.tint[4]))
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_RealtimePlots = {
        sdata1 = ScrollingBuffer(), sdata2 = ScrollingBuffer(),
        rdata1 = RollingBuffer(), rdata2 = RollingBuffer(),
        t = 0, last_t = 0.0,
        history = 10.0,
        flags = ImPlotAxisFlags.NoTickLabels,
    }
    function D.Demo_RealtimePlots()
        IMGUI_DEMO_MARKER("Plots/Realtime Plots")
        local s = S.Demo_RealtimePlots
        ImGui.BulletText("Move your mouse to change the data!")
        local sdata1, sdata2, rdata1, rdata2 = s.sdata1, s.sdata2, s.rdata1, s.rdata2
        local mouse = ImGui.GetMousePos()

        -- Add points to the buffers every 0.02 seconds
        if s.t == 0 or s.t - s.last_t >= 0.02 then
            ScrollingBuffer_AddPoint(sdata1, s.t, mouse.x * 0.0005)
            RollingBuffer_AddPoint(rdata1, s.t, mouse.x * 0.0005)
            ScrollingBuffer_AddPoint(sdata2, s.t, mouse.y * 0.0005)
            RollingBuffer_AddPoint(rdata2, s.t, mouse.y * 0.0005)
            s.last_t = s.t
        end
        s.t += ImGui.GetIO().DeltaTime
        local t = s.t

        s.history = ImGui.SliderFloat("History", s.history, 1, 30, "%.1f s")
        local history = s.history
        rdata1.Span = history
        rdata2.Span = history

        local flags = s.flags

        if ImPlot.BeginPlot("##Scrolling", ImVec2(-1, ImGui.GetTextLineHeight() * 10)) then
            ImPlot.SetupAxes(nil, nil, flags, flags)
            ImPlot.SetupAxisLimits(ImAxis.X1, t - history, t, ImGuiCond.Always)
            ImPlot.SetupAxisLimits(ImAxis.Y1, 0, 1)
            local spec = ImPlot.ImPlotSpec()
            spec.Offset = sdata1.Offset
            spec.FillAlpha = 0.5
            ImPlot.PlotShaded("Mouse X", sdata1.X, sdata1.Y, #sdata1.X, -math.huge, spec)
            spec.Offset = sdata2.Offset
            ImPlot.PlotLine("Mouse Y", sdata2.X, sdata2.Y, #sdata2.X, spec)
            ImPlot.EndPlot()
        end
        if ImPlot.BeginPlot("##Rolling", ImVec2(-1, ImGui.GetTextLineHeight() * 10)) then
            ImPlot.SetupAxes(nil, nil, flags, flags)
            ImPlot.SetupAxisLimits(ImAxis.X1, 0, history, ImGuiCond.Always)
            ImPlot.SetupAxisLimits(ImAxis.Y1, 0, 1)
            local spec = ImPlot.ImPlotSpec()
            spec.Offset = 0
            ImPlot.PlotLine("Mouse X", rdata1.X, rdata1.Y, #rdata1.X, spec)
            ImPlot.PlotLine("Mouse Y", rdata2.X, rdata2.Y, #rdata2.X, spec)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_MarkersAndText = { spec = nil } -- [Port] created on first use (ImPlotSpec(ImPlotProp_Marker, ImPlotMarker_Auto))
    function D.Demo_MarkersAndText()
        IMGUI_DEMO_MARKER("Plots/Markers and Text")
        local s = S.Demo_MarkersAndText
        if s.spec == nil then s.spec = ImPlot.ImPlotSpec(ImPlotProp.Marker, ImPlotMarker.Auto) end
        local spec = s.spec
        spec.MarkerSize = ImGui.DragFloat("Marker Size", spec.MarkerSize, 0.1, 2.0, 10.0, "%.2f px")
        spec.LineWeight = ImGui.DragFloat("Marker Weight", spec.LineWeight, 0.05, 0.5, 3.0, "%.2f px")

        if ImPlot.BeginPlot("##MarkerStyles", ImVec2(-1, 0), ImPlotFlags.CanvasOnly) then

            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(0, 10, -2, 12)

            local xs = { 1, 4 }
            local ys = { 10, 11 }

            -- filled markers
            for m = 0, ImPlotMarker.COUNT - 1 do
                ImGui.PushID(m)
                spec.FillAlpha = 1.0
                ImPlot.PlotLine("##Filled", xs, ys, 2, spec)
                ImGui.PopID()
                ys[1] -= 1; ys[2] -= 1
            end
            xs[1] = 6; xs[2] = 9; ys[1] = 10; ys[2] = 11
            -- open markers
            for m = 0, ImPlotMarker.COUNT - 1 do
                ImGui.PushID(m)
                spec.FillAlpha = 0.0
                ImPlot.PlotLine("##Open", xs, ys, 2, spec)
                ImGui.PopID()
                ys[1] -= 1; ys[2] -= 1
            end

            ImPlot.PlotText("Filled Markers", 2.5, 5.0)
            ImPlot.PlotText("Open Markers", 7.5, 5.0)

            ImPlot.PushStyleColor(ImPlot.ImPlotCol.InlayText, ImVec4(1, 0, 1, 1))
            ImPlot.PlotText("Vertical Text", 5.0, 5.0, ImVec2(0, 0), { Flags = ImPlot.ImPlotTextFlags.Vertical })
            ImPlot.PopStyleColor()

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_NaNValues = { include_nan = true, flags = 0 }
    function D.Demo_NaNValues()
        IMGUI_DEMO_MARKER("Plots/NaN Values")
        local s = S.Demo_NaNValues

        local data1 = { 0.0, 0.25, 0.5, 0.75, 1.0 }
        local data2 = { 0.0, 0.25, 0.5, 0.75, 1.0 }

        if s.include_nan then
            data1[3] = 0 / 0
        end

        _, s.include_nan = ImGui.Checkbox("Include NaN", s.include_nan)
        ImGui.SameLine()
        _, s.flags = ImGui.CheckboxFlags("Skip NaN", s.flags, ImPlot.ImPlotLineFlags.SkipNaN)

        if ImPlot.BeginPlot("##NaNValues") then
            ImPlot.PlotLine("line", data1, data2, 5, {
                Flags = s.flags,
                Marker = ImPlotMarker.Square,
            })
            ImPlot.PlotBars("bars", data1, 5)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    -- [Port] ImColor::HSV(...) -> ImU32 and ImGui::GetColorU32(SampleColormap(...))
    local function HSV_U32(h, s, v) return G.ImColor.HSV(h, s, v):U32() end
    local function Viridis_U32(t) return ImGui.GetColorU32(ImPlot.SampleColormap(t, ImPlotColormap.Viridis)) end

    S.Demo_PerIndexColors = { flags_stairs = 0, data_bars = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, vals1 = { 1.0, 2.5, 4.0, 5.5, 7.0 } }
    function D.Demo_PerIndexColors()
        local s = S.Demo_PerIndexColors
        -- Colorful Lines
        local xs1, ys1, colors1 = table.create(1001, 0), table.create(1001, 0), table.create(1001, 0)
        local t = ImGui.GetTime()
        for i = 0, 1000 do
            xs1[i + 1] = i * 0.001
            ys1[i + 1] = 0.5 + 0.5 * math.sin(50 * (xs1[i + 1] + t / 10))
            -- Rainbow colors for f(x)
            colors1[i + 1] = HSV_U32(i / 1000.0, 0.8, 0.9)
        end
        local xs2, ys2, colors2 = table.create(20, 0), table.create(20, 0), table.create(20, 0)
        for i = 0, 19 do
            xs2[i + 1] = i * 1 / 19.0
            ys2[i + 1] = xs2[i + 1] * xs2[i + 1]
            -- Colormap colors for g(x)
            colors2[i + 1] = Viridis_U32(i / 19.0)
        end
        if ImPlot.BeginPlot("Colorful Lines") then
            ImPlot.SetupAxes("x", "y")
            ImPlot.PlotLine("f(x)", xs1, ys1, 1001, {
                LineColors = colors1,
            })
            ImPlot.PlotLine("g(x)", xs2, ys2, 20, {
                Marker = ImPlotMarker.Circle,
                Flags = ImPlot.ImPlotLineFlags.Segments,
                LineColors = colors2,
                MarkerFillColors = colors2,
                MarkerLineColors = colors2,
            })
            ImPlot.EndPlot()
        end

        -- Colorful Shaded Plots
        local xs_shaded, ys_shaded = table.create(1001, 0), table.create(1001, 0)
        local ys1_shaded, ys2_shaded, ys3_shaded, ys4_shaded = table.create(1001, 0), table.create(1001, 0), table.create(1001, 0), table.create(1001, 0)
        local colors_shaded1, colors_shaded2 = table.create(1001, 0), table.create(1001, 0)
        math.randomseed(0)
        for i = 1, 1001 do
            xs_shaded[i]  = (i - 1) * 0.001
            ys_shaded[i]  = 0.25 + 0.25 * math.sin(25 * xs_shaded[i]) * math.sin(5 * xs_shaded[i]) + RandomRange(-0.01, 0.01)
            ys1_shaded[i] = ys_shaded[i] + RandomRange(0.1, 0.12)
            ys2_shaded[i] = ys_shaded[i] - RandomRange(0.1, 0.12)
            ys3_shaded[i] = 0.75 + 0.2 * math.sin(25 * xs_shaded[i])
            ys4_shaded[i] = 0.75 + 0.1 * math.cos(25 * xs_shaded[i])

            -- Rainbow colors for Uncertain Data
            colors_shaded1[i] = HSV_U32((i - 1) / 1000.0, 0.8, 0.9)

            -- Colormap colors for Overlapping
            colors_shaded2[i] = Viridis_U32((i - 1) / 1000.0)
        end
        local fill_alpha = 0.25 -- [Port] static ImPlotSpec spec_shaded(ImPlotProp_FillAlpha, 0.25f): only FillAlpha is read

        if ImPlot.BeginPlot("Colorful Shaded Plots") then
            ImPlot.SetupLegend(ImPlotLocation.NorthWest, ImPlotLegendFlags.Reverse)
            ImPlot.PlotShaded("Uncertain Data", xs_shaded, ys1_shaded, ys2_shaded, 1001, {
                FillColors = colors_shaded1,
                FillAlpha = fill_alpha,
            })
            ImPlot.PlotLine("Uncertain Data", xs_shaded, ys_shaded, 1001, {
                LineColors = colors_shaded1,
            })
            ImPlot.PlotShaded("Overlapping", xs_shaded, ys3_shaded, ys4_shaded, 1001, {
                FillColors = colors_shaded2,
                FillAlpha = fill_alpha,
            })
            ImPlot.PlotLine("Overlapping", xs_shaded, ys3_shaded, 1001, {
                LineColors = colors_shaded2,
            })
            ImPlot.PlotLine("Overlapping", xs_shaded, ys4_shaded, 1001, {
                LineColors = colors_shaded2,
            })
            ImPlot.EndPlot()
        end

        -- Colorful Scatter
        math.randomseed(0)
        local xs_scatter1, ys_scatter1 = table.create(100, 0), table.create(100, 0)
        local colors_scatter1_fill, colors_scatter1_line, sizes_scatter1 = table.create(100, 0), table.create(100, 0), table.create(100, 0)
        for i = 1, 100 do
            xs_scatter1[i] = (i - 1) * 0.01
            ys_scatter1[i] = xs_scatter1[i] + 0.1 * math.random()
            -- Rainbow hue colors
            local hue = (i - 1) / 99.0
            colors_scatter1_fill[i] = HSV_U32(hue, 0.8, 0.9)
            colors_scatter1_line[i] = HSV_U32(hue, 0.9, 0.7)
            -- Random sizes between 2 and 6
            sizes_scatter1[i] = 2.0 + 4.0 * math.random()
        end
        local xs_scatter2, ys_scatter2, colors_scatter2, sizes_scatter2 = table.create(50, 0), table.create(50, 0), table.create(50, 0), table.create(50, 0)
        for i = 1, 50 do
            xs_scatter2[i] = 0.25 + 0.2 * math.random()
            ys_scatter2[i] = 0.75 + 0.2 * math.random()
            -- Colormap colors (Viridis)
            colors_scatter2[i] = Viridis_U32((i - 1) / 49.0)
            -- Random sizes between 2 and 6
            sizes_scatter2[i] = 2.0 + 4.0 * math.random()
        end

        if ImPlot.BeginPlot("Colorful Scatter", ImVec2(-1, 0)) then
            ImPlot.PlotScatter("Data 1", xs_scatter1, ys_scatter1, 100, {
                MarkerFillColors = colors_scatter1_fill,
                MarkerLineColors = colors_scatter1_line,
                MarkerSizes = sizes_scatter1,
            })
            ImPlot.PlotScatter("Data 2", xs_scatter2, ys_scatter2, 50, {
                Marker = ImPlotMarker.Square,
                MarkerFillColors = colors_scatter2,
                MarkerLineColors = colors_scatter2,
                MarkerSizes = sizes_scatter2,
                FillAlpha = 0.5,
            })
            ImPlot.EndPlot()
        end

        -- Colorful Bubbles
        math.randomseed(0)
        local xs_bubble, ys1_bubble, ys2_bubble = table.create(20, 0), table.create(20, 0), table.create(20, 0)
        local szs1_bubble, szs2_bubble = table.create(20, 0), table.create(20, 0)
        local colors1_bubble, colors2_bubble = table.create(20, 0), table.create(20, 0)
        for i = 1, 20 do
            xs_bubble[i] = (i - 1) * 0.1
            ys1_bubble[i] = math.random()
            ys2_bubble[i] = math.random()

            szs1_bubble[i] = 0.02 + 0.08 * math.random()
            szs2_bubble[i] = 0.02 + 0.08 * math.random()

            -- Rainbow colors for Data 1
            colors1_bubble[i] = HSV_U32((i - 1) / 19.0, 0.8, 0.9)

            -- Colormap colors for Data 2
            colors2_bubble[i] = Viridis_U32((i - 1) / 19.0)
        end

        if ImPlot.BeginPlot("Colorful Bubbles", ImVec2(-1, 0), ImPlotFlags.Equal) then
            ImPlot.PlotBubbles("Data 1", xs_bubble, ys1_bubble, szs1_bubble, 20, {
                FillAlpha = 0.5,
                FillColors = colors1_bubble,
                LineColors = colors1_bubble,
            })
            ImPlot.PlotBubbles("Data 2", xs_bubble, ys2_bubble, szs2_bubble, 20, {
                FillAlpha = 0.5,
                LineColor = ImVec4(0, 0, 0, 0.0),
                FillColors = colors2_bubble,
            })

            ImPlot.EndPlot()
        end

        -- Colorful Stairstep
        local ys1_stairs, ys2_stairs = table.create(21, 0), table.create(21, 0)
        local colors1_stairs, colors2_stairs = table.create(21, 0), table.create(21, 0)
        for i = 0, 20 do
            ys1_stairs[i + 1] = 0.75 + 0.2 * math.sin(10 * i * 0.05)
            ys2_stairs[i + 1] = 0.25 + 0.2 * math.sin(10 * i * 0.05)

            -- Rainbow colors for Post Step
            colors1_stairs[i + 1] = HSV_U32(i / 20.0, 0.8, 0.9)

            -- Colormap colors for Pre Step
            colors2_stairs[i + 1] = Viridis_U32(i / 20.0)
        end
        local ImPlotStairsFlags = ImPlot.ImPlotStairsFlags
        s.flags_stairs = CHECKBOX_FLAG(s.flags_stairs, "ImPlotStairsFlags_Shaded", ImPlotStairsFlags.Shaded)

        if ImPlot.BeginPlot("Colorful Stairstep Plot") then
            ImPlot.SetupAxes("x", "f(x)")
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            ImPlot.PlotLine("##1", ys1_stairs, 21, 0.05, 0, {
                LineColor = ImVec4(0.5, 0.5, 0.5, 1.0),
            })
            ImPlot.PlotLine("##2", ys2_stairs, 21, 0.05, 0, {
                LineColor = ImVec4(0.5, 0.5, 0.5, 1.0),
            })

            ImPlot.PlotStairs("Post Step (default)", ys1_stairs, 21, 0.05, 0, {
                Flags = s.flags_stairs,
                FillAlpha = 0.25,
                Marker = ImPlotMarker.Auto,
                LineColors = colors1_stairs,
                FillColors = colors1_stairs,
                MarkerFillColors = colors1_stairs,
                MarkerLineColors = colors1_stairs,
            })

            ImPlot.PlotStairs("Pre Step", ys2_stairs, 21, 0.05, 0, {
                Flags = bor(s.flags_stairs, ImPlotStairsFlags.PreStep),
                FillAlpha = 0.25,
                Marker = ImPlotMarker.Auto,
                LineColors = colors2_stairs,
                FillColors = colors2_stairs,
                MarkerFillColors = colors2_stairs,
                MarkerLineColors = colors2_stairs,
            })

            ImPlot.EndPlot()
        end

        -- Colorful Bar Plots
        local data_bars = s.data_bars
        local colors_bars_v, colors_bars_h = table.create(10, 0), table.create(10, 0)
        for i = 0, 9 do
            -- Rainbow colors for Vertical
            colors_bars_v[i + 1] = HSV_U32(i / 9.0, 0.8, 0.9)

            -- Colormap colors for Horizontal
            colors_bars_h[i + 1] = Viridis_U32(i / 9.0)
        end

        if ImPlot.BeginPlot("Colorful Bar Plot") then
            ImPlot.PlotBars("Vertical", data_bars, 10, 0.7, 1, {
                FillColors = colors_bars_v,
                LineColors = colors_bars_v,
            })
            ImPlot.PlotBars("Horizontal", data_bars, 10, 0.4, 1, {
                Flags = ImPlot.ImPlotBarsFlags.Horizontal,
                FillColors = colors_bars_h,
                LineColors = colors_bars_h,
            })
            ImPlot.EndPlot()
        end

        -- Colorful Stem Plots
        local xs_stems, ys1_stems, ys2_stems = table.create(51, 0), table.create(51, 0), table.create(51, 0)
        local colors1_stems, colors2_stems = table.create(51, 0), table.create(51, 0)
        for i = 0, 50 do
            local x = i * 0.02
            xs_stems[i + 1] = x
            ys1_stems[i + 1] = 1.0 + 0.5 * math.sin(25 * x) * math.cos(2 * x)
            ys2_stems[i + 1] = 0.5 + 0.25 * math.sin(10 * x) * math.sin(x)

            -- Rainbow colors for Stems 1
            colors1_stems[i + 1] = HSV_U32(i / 50.0, 0.8, 0.9)

            -- Colormap colors for Stems 2
            colors2_stems[i + 1] = Viridis_U32(i / 50.0)
        end

        if ImPlot.BeginPlot("Colorful Stem Plots") then
            ImPlot.SetupAxisLimits(ImAxis.X1, 0, 1.0)
            ImPlot.SetupAxisLimits(ImAxis.Y1, 0, 1.6)
            ImPlot.PlotStems("Stems 1", xs_stems, ys1_stems, 51, 0, {
                LineColors = colors1_stems,
                MarkerFillColors = colors1_stems,
                MarkerLineColors = colors1_stems,
            })
            ImPlot.PlotStems("Stems 2", xs_stems, ys2_stems, 51, 0, {
                Marker = ImPlotMarker.Circle,
                LineColors = colors2_stems,
                MarkerFillColors = colors2_stems,
                MarkerLineColors = colors2_stems,
            })
            ImPlot.EndPlot()
        end

        -- Colorful Infinite Lines
        if ImPlot.BeginPlot("Colorful Infinite Lines", ImVec2(-1, 0)) then
            ImPlot.SetupAxes("x", "y")
            ImPlot.SetupAxesLimits(0, 10, -1, 10)

            -- 1. Constant color infinite lines
            ImPlot.PlotInfLines("Const Color", s.vals1, 5, {
                LineColor = ImVec4(0.0, 0.7, 1.0, 1.0),
            })

            -- 2. Per-line rainbow colors (horizontal)
            local vals2, colors_infline_rainbow = table.create(8, 0), table.create(8, 0)
            for i = 0, 7 do
                vals2[i + 1] = 1.0 + i * 1.0
                colors_infline_rainbow[i + 1] = ImGui.GetColorU32(ImPlot.SampleColormap(i / 7.0, ImPlotColormap.Jet))
            end
            ImPlot.PlotInfLines("Rainbow Horizontal", vals2, 8, {
                LineColors = colors_infline_rainbow,
                Flags = ImPlot.ImPlotInfLinesFlags.Horizontal,
            })

            -- 3. Per-line colormap colors (vertical)
            local vals3, colors_infline_viridis = table.create(6, 0), table.create(6, 0)
            for i = 0, 5 do
                vals3[i + 1] = 1.5 + i * 1.5
                colors_infline_viridis[i + 1] = ImGui.GetColorU32(ImPlot.SampleColormap(i / 5.0, ImPlotColormap.Plasma))
            end
            ImPlot.PlotInfLines("Plasma Vertical", vals3, 6, {
                LineColors = colors_infline_viridis,
            })

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_LogScale = { xs = table.create(1001, 0), ys1 = table.create(1001, 0), ys2 = table.create(1001, 0), ys3 = table.create(1001, 0) }
    function D.Demo_LogScale()
        IMGUI_DEMO_MARKER("Axes/Log Scale")
        local s = S.Demo_LogScale
        local xs, ys1, ys2, ys3 = s.xs, s.ys1, s.ys2, s.ys3
        for i = 1, 1001 do
            xs[i]  = (i - 1) * 0.1
            ys1[i] = math.sin(xs[i]) + 1
            ys2[i] = math.log(xs[i])
            ys3[i] = math.pow(10.0, xs[i])
        end
        if ImPlot.BeginPlot("Log Plot", ImVec2(-1, 0)) then
            ImPlot.SetupAxisScale(ImAxis.X1, ImPlot.ImPlotScale.Log10)
            ImPlot.SetupAxesLimits(0.1, 100, 0, 10)
            ImPlot.PlotLine("f(x) = x",        xs, xs,  1001)
            ImPlot.PlotLine("f(x) = sin(x)+1", xs, ys1, 1001)
            ImPlot.PlotLine("f(x) = log(x)",   xs, ys2, 1001)
            ImPlot.PlotLine("f(x) = 10^x",     xs, ys3, 21)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_SymmetricLogScale = { xs = table.create(1001, 0), ys1 = table.create(1001, 0), ys2 = table.create(1001, 0) }
    function D.Demo_SymmetricLogScale()
        IMGUI_DEMO_MARKER("Axes/Symmetric Log Scale")
        local s = S.Demo_SymmetricLogScale
        local xs, ys1, ys2 = s.xs, s.ys1, s.ys2
        for i = 0, 1000 do
            xs[i + 1]  = i * 0.1 - 50
            ys1[i + 1] = math.sin(xs[i + 1])
            ys2[i + 1] = i * 0.002 - 1
        end
        if ImPlot.BeginPlot("SymLog Plot", ImVec2(-1, 0)) then
            ImPlot.SetupAxisScale(ImAxis.X1, ImPlot.ImPlotScale.SymLog)
            ImPlot.PlotLine("f(x) = a*x+b", xs, ys2, 1001)
            ImPlot.PlotLine("f(x) = sin(x)", xs, ys1, 1001)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    -- Huge data used by Time Formatting example (~500 MB allocation!)
    local HugeTimeData_Size = 60 * 60 * 24 * 366
    local function HugeTimeData_GetY(t)
        return 0.5 + 0.25 * math.sin(t / 86400 / 12) + 0.005 * math.sin(t / 3600)
    end
    local function HugeTimeData(min)
        local Ts, Ys = table.create(HugeTimeData_Size), table.create(HugeTimeData_Size)
        for i = 1, HugeTimeData_Size do
            Ts[i] = min + (i - 1)
            Ys[i] = HugeTimeData_GetY(Ts[i])
        end
        return { Ts = Ts, Ys = Ys }
    end

    S.Demo_TimeScale = {
        t_min = 1609459200, -- 01/01/2021 @ 12:00:00am (UTC)
        t_max = 1640995200, -- 01/01/2022 @ 12:00:00am (UTC)
        data = nil,
    }
    function D.Demo_TimeScale()
        IMGUI_DEMO_MARKER("Axes/Time Scale")
        local s = S.Demo_TimeScale
        local t_min, t_max = s.t_min, s.t_max

        ImGui.BulletText("When ImPlotAxisFlags_Time is enabled on the X-Axis, values are interpreted as\n" ..
                            "UNIX timestamps in seconds and axis labels are formated as date/time.")
        ImGui.BulletText("By default, labels are in UTC time but can be set to use local time instead.")

        local style = ImPlot.GetStyle()
        _, style.UseLocalTime = ImGui.Checkbox("Local Time", style.UseLocalTime)
        ImGui.SameLine()
        _, style.UseISO8601 = ImGui.Checkbox("ISO 8601", style.UseISO8601)
        ImGui.SameLine()
        _, style.Use24HourClock = ImGui.Checkbox("24 Hour Clock", style.Use24HourClock)

        if s.data == nil then
            ImGui.SameLine()
            if ImGui.Button("Generate Huge Data (~500MB!)") then
                s.data = HugeTimeData(t_min)
            end
        end

        if ImPlot.BeginPlot("##Time", ImVec2(-1, 0)) then
            ImPlot.SetupAxisScale(ImAxis.X1, ImPlot.ImPlotScale.Time)
            ImPlot.SetupAxesLimits(t_min, t_max, 0, 1)
            local data = s.data
            if data ~= nil then
                -- downsample our data
                local limits = ImPlot.GetPlotLimits()
                local downsample = math.floor(limits.X:Size() / 1000) + 1
                local start = math.floor(limits.X.Min - t_min)
                start = math.clamp(start, 0, HugeTimeData_Size - 1)
                local stop = math.floor(limits.X.Max - t_min) + 1000
                stop = math.clamp(stop, 0, HugeTimeData_Size - 1)
                local size = (stop - start) // downsample
                -- [Port] &data->Ts[start] + Stride: no pointer arithmetic, copy the strided slice instead
                local ts, ys = table.create(size), table.create(size)
                for i = 1, size do
                    local j = start + (i - 1) * downsample + 1
                    ts[i] = data.Ts[j]
                    ys[i] = data.Ys[j]
                end
                -- plot it
                ImPlot.PlotLine("Time Series", ts, ys, size)
            end
            -- plot time now
            local t_now = os.time()
            local y_now = HugeTimeData_GetY(t_now)
            ImPlot.PlotScatter("Now", { t_now }, { y_now }, 1)
            ImPlot.Annotation(t_now, y_now, ImPlot.GetLastItemColor(), ImVec2(10, 10), false, "Now")
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    local function TransformForward_Sqrt(v, _data)
        return math.sqrt(v)
    end

    local function TransformInverse_Sqrt(v, _data)
        return v * v
    end

    S.Demo_CustomScale = { v = table.create(100, 0) }
    function D.Demo_CustomScale()
        IMGUI_DEMO_MARKER("Axes/Custom Scale")
        local v = S.Demo_CustomScale.v
        for i = 0, 99 do
            v[i + 1] = i * 0.01
        end
        if ImPlot.BeginPlot("Sqrt") then
            ImPlot.SetupAxis(ImAxis.X1, "Linear")
            ImPlot.SetupAxis(ImAxis.Y1, "Sqrt")
            ImPlot.SetupAxisScale(ImAxis.Y1, TransformForward_Sqrt, TransformInverse_Sqrt)
            ImPlot.SetupAxisLimitsConstraints(ImAxis.Y1, 0, math.huge)
            ImPlot.PlotLine("##data", v, v, 100)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_MultipleAxes = {
        xs = table.create(1001, 0), xs2 = table.create(1001, 0), ys1 = table.create(1001, 0),
        ys2 = table.create(1001, 0), ys3 = table.create(1001, 0),
        x2_axis = true, y2_axis = true, y3_axis = true,
    }
    function D.Demo_MultipleAxes()
        IMGUI_DEMO_MARKER("Axes/Multiple Axes")
        local s = S.Demo_MultipleAxes
        local xs, xs2, ys1, ys2, ys3 = s.xs, s.xs2, s.ys1, s.ys2, s.ys3
        for i = 1, 1001 do
            xs[i]  = (i - 1) * 0.1
            xs2[i] = xs[i] + 10.0
            ys1[i] = math.sin(xs[i]) * 3 + 1
            ys2[i] = math.cos(xs[i]) * 0.2 + 0.5
            ys3[i] = math.sin(xs[i] + 0.5) * 100 + 200
        end

        _, s.x2_axis = ImGui.Checkbox("X-Axis 2", s.x2_axis)
        ImGui.SameLine()
        _, s.y2_axis = ImGui.Checkbox("Y-Axis 2", s.y2_axis)
        ImGui.SameLine()
        _, s.y3_axis = ImGui.Checkbox("Y-Axis 3", s.y3_axis)

        ImGui.BulletText("You can drag axes to the opposite side of the plot.")
        ImGui.BulletText("Hover over legend items to see which axis they are plotted on.")

        if ImPlot.BeginPlot("Multi-Axis Plot", ImVec2(-1, 0)) then
            ImPlot.SetupAxes("X-Axis 1", "Y-Axis 1")
            ImPlot.SetupAxesLimits(0, 100, 0, 10)
            if s.x2_axis then
                ImPlot.SetupAxis(ImAxis.X2, "X-Axis 2", ImPlotAxisFlags.AuxDefault)
                ImPlot.SetupAxisLimits(ImAxis.X2, 0, 100)
            end
            if s.y2_axis then
                ImPlot.SetupAxis(ImAxis.Y2, "Y-Axis 2", ImPlotAxisFlags.AuxDefault)
                ImPlot.SetupAxisLimits(ImAxis.Y2, 0, 1)
            end
            if s.y3_axis then
                ImPlot.SetupAxis(ImAxis.Y3, "Y-Axis 3", ImPlotAxisFlags.AuxDefault)
                ImPlot.SetupAxisLimits(ImAxis.Y3, 0, 300)
            end

            ImPlot.PlotLine("f(x) = x", xs, xs, 1001)
            if s.x2_axis then
                ImPlot.SetAxes(ImAxis.X2, ImAxis.Y1)
                ImPlot.PlotLine("f(x) = sin(x)*3+1", xs2, ys1, 1001)
            end
            if s.y2_axis then
                ImPlot.SetAxes(ImAxis.X1, ImAxis.Y2)
                ImPlot.PlotLine("f(x) = cos(x)*.2+.5", xs, ys2, 1001)
            end
            if s.x2_axis and s.y3_axis then
                ImPlot.SetAxes(ImAxis.X2, ImAxis.Y3)
                ImPlot.PlotLine("f(x) = sin(x+.5)*100+200 ", xs2, ys3, 1001)
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    -- [Port] static ImPlotRect lims: link refs (tables whose [1] holds the value) replace &lims.X.Min etc.
    S.Demo_LinkedAxes = { xmin = { 0 }, xmax = { 1 }, ymin = { 0 }, ymax = { 1 }, linkx = true, linky = true }
    function D.Demo_LinkedAxes()
        IMGUI_DEMO_MARKER("Axes/Linked Axes")
        local s = S.Demo_LinkedAxes
        local data = { 0, 1 }
        _, s.linkx = ImGui.Checkbox("Link X", s.linkx)
        ImGui.SameLine()
        _, s.linky = ImGui.Checkbox("Link Y", s.linky)

        local lims = { s.xmin[1], s.xmax[1], s.ymin[1], s.ymax[1] }
        ImGui.DragScalarN("Limits", G.ImGuiDataType.Double, lims, 4, 0.01)
        s.xmin[1], s.xmax[1], s.ymin[1], s.ymax[1] = lims[1], lims[2], lims[3], lims[4]

        if ImPlot.BeginAlignedPlots("AlignedGroup") then
            for _, title in { "Plot A", "Plot B" } do
                if ImPlot.BeginPlot(title) then
                    ImPlot.SetupAxisLinks(ImAxis.X1, s.linkx and s.xmin or nil, s.linkx and s.xmax or nil)
                    ImPlot.SetupAxisLinks(ImAxis.Y1, s.linky and s.ymin or nil, s.linky and s.ymax or nil)
                    ImPlot.PlotLine("Line", data, 2)
                    ImPlot.EndPlot()
                end
            end
            ImPlot.EndAlignedPlots()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_AxisConstraints = { limits = { -10, 10 }, zoom = { 1, 20 }, flags = 0 } -- [Port] constraints[4] -> two DragFloat2 arrays
    function D.Demo_AxisConstraints()
        IMGUI_DEMO_MARKER("Axes/Axis Constraints")
        local s = S.Demo_AxisConstraints
        ImGui.DragFloat2("Limits Constraints", s.limits, 0.01)
        ImGui.DragFloat2("Zoom Constraints", s.zoom, 0.01)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotAxisFlags_PanStretch", ImPlotAxisFlags.PanStretch)
        if ImPlot.BeginPlot("##AxisConstraints", ImVec2(-1, 0)) then
            ImPlot.SetupAxes("X", "Y", s.flags, s.flags)
            ImPlot.SetupAxesLimits(-1, 1, -1, 1)
            ImPlot.SetupAxisLimitsConstraints(ImAxis.X1, s.limits[1], s.limits[2])
            ImPlot.SetupAxisZoomConstraints(ImAxis.X1, s.zoom[1], s.zoom[2])
            ImPlot.SetupAxisLimitsConstraints(ImAxis.Y1, s.limits[1], s.limits[2])
            ImPlot.SetupAxisZoomConstraints(ImAxis.Y1, s.zoom[1], s.zoom[2])
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_EqualAxes = { xs1 = table.create(360, 0), ys1 = table.create(360, 0), xs2 = { -1, 0, 1, 0, -1 }, ys2 = { 0, 1, 0, -1, 0 } }
    function D.Demo_EqualAxes()
        IMGUI_DEMO_MARKER("Axes/Equal Axes")
        local s = S.Demo_EqualAxes
        ImGui.BulletText("Equal constraint applies to axis pairs (e.g ImAxis_X1/Y1, ImAxis_X2/Y2)")
        for i = 0, 359 do
            local angle = i * 2 * math.pi / 359.0
            s.xs1[i + 1] = math.cos(angle); s.ys1[i + 1] = math.sin(angle)
        end
        if ImPlot.BeginPlot("##EqualAxes", ImVec2(-1, 0), ImPlotFlags.Equal) then
            ImPlot.SetupAxis(ImAxis.X2, nil, ImPlotAxisFlags.AuxDefault)
            ImPlot.SetupAxis(ImAxis.Y2, nil, ImPlotAxisFlags.AuxDefault)
            ImPlot.PlotLine("Circle", s.xs1, s.ys1, 360)
            ImPlot.SetAxes(ImAxis.X2, ImAxis.Y2)
            ImPlot.PlotLine("Diamond", s.xs2, s.ys2, 5)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_AutoFittingData = {
        xflags = ImPlotAxisFlags.None,
        yflags = bor(ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.RangeFit),
        data = table.create(101, 0),
    }
    function D.Demo_AutoFittingData()
        IMGUI_DEMO_MARKER("Axes/Auto-Fitting Data")
        local s = S.Demo_AutoFittingData
        ImGui.BulletText("The Y-axis has been configured to auto-fit to only the data visible in X-axis range.")
        ImGui.BulletText("Zoom and pan the X-axis. Disable Stems to see a difference in fit.")
        ImGui.BulletText("If ImPlotAxisFlags_RangeFit is disabled, the axis will fit ALL data.")

        ImGui.TextUnformatted("X: "); ImGui.SameLine()
        _, s.xflags = ImGui.CheckboxFlags("ImPlotAxisFlags_AutoFit##X", s.xflags, ImPlotAxisFlags.AutoFit); ImGui.SameLine()
        _, s.xflags = ImGui.CheckboxFlags("ImPlotAxisFlags_RangeFit##X", s.xflags, ImPlotAxisFlags.RangeFit)

        ImGui.TextUnformatted("Y: "); ImGui.SameLine()
        _, s.yflags = ImGui.CheckboxFlags("ImPlotAxisFlags_AutoFit##Y", s.yflags, ImPlotAxisFlags.AutoFit); ImGui.SameLine()
        _, s.yflags = ImGui.CheckboxFlags("ImPlotAxisFlags_RangeFit##Y", s.yflags, ImPlotAxisFlags.RangeFit)

        local data = s.data
        for i = 0, 100 do
            data[i + 1] = 1 + math.sin(i / 10.0)
        end

        if ImPlot.BeginPlot("##DataFitting") then
            ImPlot.SetupAxes("X", "Y", s.xflags, s.yflags)
            ImPlot.PlotLine("Line", data, 101)
            ImPlot.PlotStems("Stems", data, 101)
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------
    -- [Port] TODO: the remaining demos are not ported yet; stubs show a placeholder
    ---------------------------------------------------------------------------

    for _, name in {
        "TickLabels", "SubplotsSizing",
        "SubplotItemSharing", "SubplotAxisLinking", "Tables", "LegendOptions", "LegendPopups", "DragPoints", "DragLines",
        "DragRects", "Querying", "Annotations", "Tags", "DragAndDrop", "ColormapWidgets", "ItemStylingAndSpec",
        "OffsetAndStride", "CustomStyles", "CustomDataAndGetters", "CustomRendering", "CustomPlottersAndTooltips",
    } do
        if D["Demo_" .. name] == nil then
            D["Demo_" .. name] = function()
                ImGui.TextDisabled("[Port] TODO: Demo_" .. name)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- DEMO WINDOW
    ---------------------------------------------------------------------------

    local function DemoHeader(label, demo)
        if ImGui.TreeNodeEx(label) then
            demo()
            ImGui.TreePop()
        end
    end

    S.ShowDemoWindow = {
        show_implot_metrics      = false,
        show_implot_style_editor = false,
        show_imgui_metrics       = false,
        show_imgui_style_editor  = false,
        show_imgui_demo          = false,
    }

    -- [Port] p_open: true/false/nil (nil = no close button). Returns the new p_open value.
    function ImPlot.ShowDemoWindow(p_open)
        local s = S.ShowDemoWindow

        if s.show_implot_metrics then
            s.show_implot_metrics = ImPlot.ShowMetricsWindow(s.show_implot_metrics)
        end
        if s.show_implot_style_editor then
            ImGui.SetNextWindowSize(ImVec2(415, 762), ImGuiCond.Appearing)
            s.show_implot_style_editor = ImGui.Begin("Style Editor (ImPlot)", s.show_implot_style_editor)
            ImPlot.ShowStyleEditor()
            ImGui.End()
        end
        if s.show_imgui_style_editor then
            s.show_imgui_style_editor = ImGui.Begin("Style Editor (ImGui)", s.show_imgui_style_editor)
            ImGui.ShowStyleEditor()
            ImGui.End()
        end
        if s.show_imgui_metrics then
            s.show_imgui_metrics = ImGui.ShowMetricsWindow(s.show_imgui_metrics)
        end
        if s.show_imgui_demo then
            s.show_imgui_demo = ImGui.ShowDemoWindow(s.show_imgui_demo)
        end
        ImGui.SetNextWindowPos(ImVec2(50, 50), ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSize(ImVec2(600, 750), ImGuiCond.FirstUseEver)
        p_open = ImGui.Begin("ImPlot Demo", p_open, G.ImGuiWindowFlags.MenuBar)
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("Tools") then
                _, s.show_implot_metrics = ImGui.MenuItem("Metrics", nil, s.show_implot_metrics)
                _, s.show_implot_style_editor = ImGui.MenuItem("Style Editor", nil, s.show_implot_style_editor)
                ImGui.Separator()
                _, s.show_imgui_metrics = ImGui.MenuItem("ImGui Metrics", nil, s.show_imgui_metrics)
                _, s.show_imgui_style_editor = ImGui.MenuItem("ImGui Style Editor", nil, s.show_imgui_style_editor)
                _, s.show_imgui_demo = ImGui.MenuItem("ImGui Demo", nil, s.show_imgui_demo)
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        -------------------------------------------------------------------------
        ImGui.Text("ImPlot says hello! (%s)", "Luau port") -- [Port] no IMPLOT_VERSION/IMPLOT_VERSION_NUM
        -- display warning about 16-bit indices
        -- [Port] ImDrawIdx is 32-bit in the core: the warning never shows.

        ImGui.Spacing()

        if ImGui.BeginTabBar("ImPlotDemoTabs") then
            if ImGui.BeginTabItem("Plots") then
                DemoHeader("Line Plots", D.Demo_LinePlots)
                DemoHeader("Filled Line Plots", D.Demo_FilledLinePlots)
                DemoHeader("Shaded Plots##", D.Demo_ShadedPlots)
                DemoHeader("Scatter Plots", D.Demo_ScatterPlots)
                DemoHeader("Bubble Plots", D.Demo_BubblePlots)
                DemoHeader("Polygon Plots", D.Demo_PolygonPlots)
                DemoHeader("Realtime Plots", D.Demo_RealtimePlots)
                DemoHeader("Stairstep Plots", D.Demo_StairstepPlots)
                DemoHeader("Bar Plots", D.Demo_BarPlots)
                DemoHeader("Bar Groups", D.Demo_BarGroups)
                DemoHeader("Bar Stacks", D.Demo_BarStacks)
                DemoHeader("Error Bars", D.Demo_ErrorBars)
                DemoHeader("Stem Plots##", D.Demo_StemPlots)
                DemoHeader("Infinite Lines", D.Demo_InfiniteLines)
                DemoHeader("Pie Charts", D.Demo_PieCharts)
                DemoHeader("Heatmaps", D.Demo_Heatmaps)
                DemoHeader("Histogram", D.Demo_Histogram)
                DemoHeader("Histogram 2D", D.Demo_Histogram2D)
                DemoHeader("Digital Plots", D.Demo_DigitalPlots)
                DemoHeader("Images", D.Demo_Images)
                DemoHeader("Markers and Text", D.Demo_MarkersAndText)
                DemoHeader("NaN Values", D.Demo_NaNValues)
                DemoHeader("Per-Index Colors", D.Demo_PerIndexColors)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Subplots") then
                DemoHeader("Sizing", D.Demo_SubplotsSizing)
                DemoHeader("Item Sharing", D.Demo_SubplotItemSharing)
                DemoHeader("Axis Linking", D.Demo_SubplotAxisLinking)
                DemoHeader("Tables", D.Demo_Tables)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Axes") then
                DemoHeader("Log Scale", D.Demo_LogScale)
                DemoHeader("Symmetric Log Scale", D.Demo_SymmetricLogScale)
                DemoHeader("Time Scale", D.Demo_TimeScale)
                DemoHeader("Custom Scale", D.Demo_CustomScale)
                DemoHeader("Multiple Axes", D.Demo_MultipleAxes)
                DemoHeader("Tick Labels", D.Demo_TickLabels)
                DemoHeader("Linked Axes", D.Demo_LinkedAxes)
                DemoHeader("Axis Constraints", D.Demo_AxisConstraints)
                DemoHeader("Equal Axes", D.Demo_EqualAxes)
                DemoHeader("Auto-Fitting Data", D.Demo_AutoFittingData)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Tools") then
                DemoHeader("Item Styling and Spec", D.Demo_ItemStylingAndSpec)
                DemoHeader("Offset and Stride", D.Demo_OffsetAndStride)
                DemoHeader("Drag Points", D.Demo_DragPoints)
                DemoHeader("Drag Lines", D.Demo_DragLines)
                DemoHeader("Drag Rects", D.Demo_DragRects)
                DemoHeader("Querying", D.Demo_Querying)
                DemoHeader("Annotations", D.Demo_Annotations)
                DemoHeader("Tags", D.Demo_Tags)
                DemoHeader("Drag and Drop", D.Demo_DragAndDrop)
                DemoHeader("Legend Options", D.Demo_LegendOptions)
                DemoHeader("Legend Popups", D.Demo_LegendPopups)
                DemoHeader("Colormap Widgets", D.Demo_ColormapWidgets)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Custom") then
                DemoHeader("Custom Styles", D.Demo_CustomStyles)
                DemoHeader("Custom Data and Getters", D.Demo_CustomDataAndGetters)
                DemoHeader("Custom Rendering", D.Demo_CustomRendering)
                DemoHeader("Custom Plotters and Tooltips", D.Demo_CustomPlottersAndTooltips)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Config") then
                D.Demo_Config()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Help") then
                D.Demo_Help()
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
        ImGui.End()
        return p_open
    end

    return ImPlot.ShowDemoWindow
end
