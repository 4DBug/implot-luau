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

    -- [Port] float* data -> the frequency is passed directly
    local function SinewaveGetter(i, f)
        return i, math.sin(f * i)
    end

    S.Demo_SubplotsSizing = {
        flags = bor(ImPlot.ImPlotSubplotFlags.ShareItems, ImPlot.ImPlotSubplotFlags.NoLegend),
        rows = 3, cols = 3, rratios = { 5, 1, 1, 1, 1, 1 }, cratios = { 5, 1, 1, 1, 1, 1 },
    }
    function D.Demo_SubplotsSizing()
        IMGUI_DEMO_MARKER("Subplots/Sizing")
        local s = S.Demo_SubplotsSizing
        local ImPlotSubplotFlags = ImPlot.ImPlotSubplotFlags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_NoResize", ImPlotSubplotFlags.NoResize)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_NoTitle", ImPlotSubplotFlags.NoTitle)

        s.rows = ImGui.SliderInt("Rows", s.rows, 1, 5)
        s.cols = ImGui.SliderInt("Cols", s.cols, 1, 5)
        local rows, cols = s.rows, s.cols
        if rows < 1 or cols < 1 then
            ImGui.TextColored(ImVec4(1, 0, 0, 1), "Nice try, but the number of rows and columns must be greater than 0!")
            return
        end
        ImGui.DragScalarN("Row Ratios", G.ImGuiDataType.Float, s.rratios, rows, 0.01, nil)
        ImGui.DragScalarN("Col Ratios", G.ImGuiDataType.Float, s.cratios, cols, 0.01, nil)
        if ImPlot.BeginSubplots("My Subplots", rows, cols, ImVec2(-1, 400), s.flags, s.rratios, s.cratios) then
            local id = 0
            for i = 0, rows * cols - 1 do
                if ImPlot.BeginPlot("", ImVec2(0, 0), ImPlotFlags.NoLegend) then
                    ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
                    local fi = 0.01 * (i + 1)
                    local col = ImPlot.GetColormapColor(0)
                    if rows * cols > 1 then
                        col = ImPlot.SampleColormap(i / (rows * cols - 1), ImPlotColormap.Jet)
                    end
                    local label = string.format("data%d", id)
                    id += 1
                    ImPlot.PlotLineG(label, SinewaveGetter, fi, 1000, ImPlot.ImPlotSpec(ImPlotProp.LineColor, col))
                    ImPlot.EndPlot()
                end
            end
            ImPlot.EndSubplots()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_SubplotItemSharing = { flags = ImPlot.ImPlotSubplotFlags.ShareItems, rows = 2, cols = 3, id = { 0, 1, 2, 3, 4, 5 }, curj = -1 }
    function D.Demo_SubplotItemSharing()
        IMGUI_DEMO_MARKER("Subplots/Item Sharing")
        local s = S.Demo_SubplotItemSharing
        local ImPlotSubplotFlags = ImPlot.ImPlotSubplotFlags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_ShareItems", ImPlotSubplotFlags.ShareItems)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_ColMajor", ImPlotSubplotFlags.ColMajor)
        ImGui.BulletText("Drag and drop items from the legend onto plots (except for 'common')")
        local rows, cols, id = s.rows, s.cols, s.id
        if ImPlot.BeginSubplots("##ItemSharing", rows, cols, ImVec2(-1, 400), s.flags) then
            ImPlot.SetupLegend(ImPlotLocation.South, bor(ImPlotLegendFlags.Sort, ImPlotLegendFlags.Horizontal))
            for i = 0, rows * cols - 1 do
                if ImPlot.BeginPlot("") then
                    ImPlot.PlotLineG("common", SinewaveGetter, 0.01, 1000)
                    for j = 0, 5 do
                        if id[j + 1] == i then
                            local fj = 0.01 * (j + 2)
                            local label = string.format("data%d", j)
                            ImPlot.PlotLineG(label, SinewaveGetter, fj, 1000)
                            if ImPlot.BeginDragDropSourceItem(label) then
                                s.curj = j
                                ImGui.SetDragDropPayload("MY_DND", nil, 0)
                                ImPlot.ItemIcon(ImPlot.GetLastItemColor()); ImGui.SameLine()
                                ImGui.TextUnformatted(label)
                                ImPlot.EndDragDropSource()
                            end
                        end
                    end
                    if ImPlot.BeginDragDropTargetPlot() then
                        if ImGui.AcceptDragDropPayload("MY_DND") then
                            id[s.curj + 1] = i
                        end
                        ImPlot.EndDragDropTarget()
                    end
                    ImPlot.EndPlot()
                end
            end
            ImPlot.EndSubplots()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_SubplotAxisLinking = {
        flags = bor(ImPlot.ImPlotSubplotFlags.LinkRows, ImPlot.ImPlotSubplotFlags.LinkCols), rows = 2, cols = 2,
    }
    function D.Demo_SubplotAxisLinking()
        IMGUI_DEMO_MARKER("Subplots/Axis Linking")
        local s = S.Demo_SubplotAxisLinking
        local ImPlotSubplotFlags = ImPlot.ImPlotSubplotFlags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_LinkRows", ImPlotSubplotFlags.LinkRows)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_LinkCols", ImPlotSubplotFlags.LinkCols)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_LinkAllX", ImPlotSubplotFlags.LinkAllX)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotSubplotFlags_LinkAllY", ImPlotSubplotFlags.LinkAllY)

        local rows, cols = s.rows, s.cols
        if ImPlot.BeginSubplots("##AxisLinking", rows, cols, ImVec2(-1, 400), s.flags) then
            for _ = 0, rows * cols - 1 do
                if ImPlot.BeginPlot("") then
                    ImPlot.SetupAxesLimits(0, 1000, -1, 1)
                    ImPlot.PlotLineG("common", SinewaveGetter, 0.01, 1000)
                    ImPlot.EndPlot()
                end
            end
            ImPlot.EndSubplots()
        end
    end

    ---------------------------------------------------------------------------

    -- [Port] MyImPlot::WaveData / SawWave
    local function WaveData(x, amp, freq, offset)
        return { X = x, Amp = amp, Freq = freq, Offset = offset }
    end
    local function SawWave(idx, wd)
        local x = idx * wd.X
        return x, wd.Offset + wd.Amp * (-2 / 3.14 * math.atan(math.cos(3.14 * wd.Freq * x) / math.sin(3.14 * wd.Freq * x)))
    end

    S.Demo_LegendOptions = {
        loc = ImPlotLocation.East, flags = 0, num_dummy_items = 25,
        data1 = WaveData(0.001, 0.2, 4, 0.2), data2 = WaveData(0.001, 0.2, 4, 0.4), data3 = WaveData(0.001, 0.2, 4, 0.6),
        data4 = WaveData(0.001, 0.2, 4, 0.8), data5 = WaveData(0.001, 0.2, 4, 1.0),
    }
    function D.Demo_LegendOptions()
        IMGUI_DEMO_MARKER("Tools/Legend Options")
        local s = S.Demo_LegendOptions
        s.loc = CHECKBOX_FLAG(s.loc, "North", ImPlotLocation.North); ImGui.SameLine()
        s.loc = CHECKBOX_FLAG(s.loc, "South", ImPlotLocation.South); ImGui.SameLine()
        s.loc = CHECKBOX_FLAG(s.loc, "West", ImPlotLocation.West); ImGui.SameLine()
        s.loc = CHECKBOX_FLAG(s.loc, "East", ImPlotLocation.East)

        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotLegendFlags_Horizontal", ImPlotLegendFlags.Horizontal)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotLegendFlags_Outside", ImPlotLegendFlags.Outside)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotLegendFlags_Sort", ImPlotLegendFlags.Sort)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotLegendFlags_Reverse", ImPlotLegendFlags.Reverse)

        local style = ImPlot.GetStyle()
        ImGui.SliderFloat2("LegendPadding", style.LegendPadding, 0.0, 20.0, "%.0f")
        ImGui.SliderFloat2("LegendInnerPadding", style.LegendInnerPadding, 0.0, 10.0, "%.0f")
        ImGui.SliderFloat2("LegendSpacing", style.LegendSpacing, 0.0, 5.0, "%.0f")

        s.num_dummy_items = ImGui.SliderInt("Num Dummy Items (Demo Scrolling)", s.num_dummy_items, 0, 100)

        if ImPlot.BeginPlot("##Legend", ImVec2(-1, 0)) then
            ImPlot.SetupLegend(s.loc, s.flags)
            ImPlot.PlotLineG("Item 002", SawWave, s.data1, 1000)         -- "Item B" added to legend
            ImPlot.PlotLineG("Item 001##IDText", SawWave, s.data2, 1000) -- "Item A" added to legend, text after ## used for ID only
            ImPlot.PlotLineG("##NotListed", SawWave, s.data3, 1000)      -- plotted, but not added to legend
            ImPlot.PlotLineG("Item 003", SawWave, s.data4, 1000)         -- "Item C" added to legend
            ImPlot.PlotLineG("Item 003", SawWave, s.data5, 1000)         -- combined with previous "Item C"

            for i = 0, s.num_dummy_items - 1 do
                ImPlot.PlotDummy(string.format("Item %03d", i + 4))
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    -- [Port] ImPlotPoint P[] -> separate X/Y arrays (PlotLine reads the first 2 handle points directly)
    S.Demo_DragPoints = {
        flags = 0, PX = { 0.05, 0.2, 0.8, 0.95 }, PY = { 0.05, 0.4, 0.6, 0.95 },
        BX = table.create(100, 0), BY = table.create(100, 0),
    }
    function D.Demo_DragPoints()
        IMGUI_DEMO_MARKER("Tools/Drag Points")
        local s = S.Demo_DragPoints
        local ImPlotDragToolFlags = ImPlot.ImPlotDragToolFlags
        ImGui.BulletText("Click and drag each point.")
        s.flags = CHECKBOX_FLAG(s.flags, "NoCursors", ImPlotDragToolFlags.NoCursors); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoFit", ImPlotDragToolFlags.NoFit); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoInput", ImPlotDragToolFlags.NoInputs)
        local ax_flags = bor(ImPlotAxisFlags.NoTickLabels, ImPlotAxisFlags.NoTickMarks)
        local hovered, held = {}, {}
        if ImPlot.BeginPlot("##Bezier", ImVec2(-1, 0), ImPlotFlags.CanvasOnly) then
            ImPlot.SetupAxes(nil, nil, ax_flags, ax_flags)
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            local PX, PY = s.PX, s.PY
            local cols = { ImVec4(0, 0.9, 0, 1), ImVec4(1, 0.5, 1, 1), ImVec4(0, 0.5, 1, 1), ImVec4(0, 0.9, 0, 1) }
            for k = 1, 4 do
                PX[k], PY[k], _, _, hovered[k], held[k] = ImPlot.DragPoint(k - 1, PX[k], PY[k], cols[k], 4, s.flags)
            end

            local BX, BY = s.BX, s.BY
            for i = 0, 99 do
                local t  = i / 99.0
                local u  = 1 - t
                local w1 = u * u * u
                local w2 = 3 * u * u * t
                local w3 = 3 * u * t * t
                local w4 = t * t * t
                BX[i + 1] = w1 * PX[1] + w2 * PX[2] + w3 * PX[3] + w4 * PX[4]
                BY[i + 1] = w1 * PY[1] + w2 * PY[2] + w3 * PY[3] + w4 * PY[4]
            end

            local spec = ImPlot.ImPlotSpec()

            spec.LineColor = ImVec4(1, 0.5, 1, 1)
            spec.LineWeight = (hovered[2] or held[2]) and 2.0 or 1.0
            ImPlot.PlotLine("##h1", { PX[1], PX[2] }, { PY[1], PY[2] }, 2, spec)

            spec.LineColor = ImVec4(0, 0.5, 1, 1)
            spec.LineWeight = (hovered[3] or held[3]) and 2.0 or 1.0
            ImPlot.PlotLine("##h2", { PX[3], PX[4] }, { PY[3], PY[4] }, 2, spec)

            spec.LineColor = ImVec4(0, 0.9, 0, 1)
            spec.LineWeight = (hovered[1] or held[1] or hovered[4] or held[4]) and 3.0 or 2.0
            ImPlot.PlotLine("##bez", BX, BY, 100, spec)

            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_DragLines = { x1 = 0.2, x2 = 0.8, y1 = 0.25, y2 = 0.75, f = 0.1, flags = 0, xs = table.create(1000, 0), ys = table.create(1000, 0) }
    function D.Demo_DragLines()
        IMGUI_DEMO_MARKER("Tools/Drag Lines")
        local s = S.Demo_DragLines
        local ImPlotDragToolFlags = ImPlot.ImPlotDragToolFlags
        ImGui.BulletText("Click and drag the horizontal and vertical lines.")
        local hovered, held = false, false
        s.flags = CHECKBOX_FLAG(s.flags, "NoCursors", ImPlotDragToolFlags.NoCursors); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoFit", ImPlotDragToolFlags.NoFit); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoInput", ImPlotDragToolFlags.NoInputs)
        if ImPlot.BeginPlot("##lines", ImVec2(-1, 0)) then
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            local white = ImVec4(1, 1, 1, 1)
            s.x1 = ImPlot.DragLineX(0, s.x1, white, 1, s.flags)
            s.x2 = ImPlot.DragLineX(1, s.x2, white, 1, s.flags)
            s.y1 = ImPlot.DragLineY(2, s.y1, white, 1, s.flags)
            s.y2 = ImPlot.DragLineY(3, s.y2, white, 1, s.flags)
            local xs, ys = s.xs, s.ys
            for i = 0, 999 do
                xs[i + 1] = (s.x2 + s.x1) / 2 + math.abs(s.x2 - s.x1) * (i / 1000.0 - 0.5)
                ys[i + 1] = (s.y1 + s.y2) / 2 + math.abs(s.y2 - s.y1) / 2 * math.sin(s.f * i / 10)
            end
            s.f, _, _, hovered, held = ImPlot.DragLineY(120482, s.f, ImVec4(1, 0.5, 1, 1), 1, s.flags)
            ImPlot.PlotLine("Interactive Data", xs, ys, 1000, ImPlot.ImPlotSpec(ImPlotProp.LineWeight, (hovered or held) and 2.0 or 1.0))
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_DragRects = {
        x_data = table.create(512, 0), y_data1 = table.create(512, 0), y_data2 = table.create(512, 0), y_data3 = table.create(512, 0),
        sampling_freq = 44100, freq = 500, rect = ImPlot.ImPlotRect(0.0025, 0.0045, 0, 0.5), flags = 0,
    }
    function D.Demo_DragRects()
        IMGUI_DEMO_MARKER("Tools/Drag Rects")
        local s = S.Demo_DragRects
        local ImPlotDragToolFlags = ImPlot.ImPlotDragToolFlags
        local x_data, y_data1, y_data2, y_data3 = s.x_data, s.y_data1, s.y_data2, s.y_data3
        local clicked, hovered, held = false, false, false
        for i = 1, 512 do
            local t = (i - 1) / s.sampling_freq
            x_data[i] = t
            local arg = 2 * 3.14 * s.freq * t
            y_data1[i] = math.sin(arg)
            y_data2[i] = y_data1[i] * -0.6 + math.sin(2 * arg) * 0.4
            y_data3[i] = y_data2[i] * -0.6 + math.sin(3 * arg) * 0.4
        end
        ImGui.BulletText("Click and drag the edges, corners, and center of the rect.")
        ImGui.BulletText("Double click edges to expand rect to plot extents.")
        local rect = s.rect
        s.flags = CHECKBOX_FLAG(s.flags, "NoCursors", ImPlotDragToolFlags.NoCursors); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoFit", ImPlotDragToolFlags.NoFit); ImGui.SameLine()
        s.flags = CHECKBOX_FLAG(s.flags, "NoInput", ImPlotDragToolFlags.NoInputs)

        if ImPlot.BeginPlot("##Main", ImVec2(-1, ImGui.GetTextLineHeight() * 10)) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoTickLabels, ImPlotAxisFlags.NoTickLabels)
            ImPlot.SetupAxesLimits(0, 0.01, -1, 1)
            ImPlot.PlotLine("Signal 1", x_data, y_data1, 512)
            ImPlot.PlotLine("Signal 2", x_data, y_data2, 512)
            ImPlot.PlotLine("Signal 3", x_data, y_data3, 512)
            _, clicked, hovered, held = ImPlot.DragRect(0, rect, ImVec4(1, 0, 1, 1), s.flags)
            ImPlot.EndPlot()
        end
        local bg_col = held and ImVec4(0.5, 0, 0.5, 1) or (hovered and ImVec4(0.25, 0, 0.25, 1) or ImPlot.GetStyle().Colors[ImPlot.ImPlotCol.PlotBg])
        ImPlot.PushStyleColor(ImPlot.ImPlotCol.PlotBg, bg_col)
        if ImPlot.BeginPlot("##rect", ImVec2(-1, ImGui.GetTextLineHeight() * 10), ImPlotFlags.CanvasOnly) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(rect.X.Min, rect.X.Max, rect.Y.Min, rect.Y.Max, ImGuiCond.Always)
            ImPlot.PlotLine("Signal 1", x_data, y_data1, 512)
            ImPlot.PlotLine("Signal 2", x_data, y_data2, 512)
            ImPlot.PlotLine("Signal 3", x_data, y_data3, 512)
            ImPlot.EndPlot()
        end
        ImPlot.PopStyleColor()
        ImGui.Text("Rect is %sclicked, %shovered, %sheld", clicked and "" or "not ", hovered and "" or "not ", held and "" or "not ")
    end

    ---------------------------------------------------------------------------

    -- [Port] ImVector<ImPlotPoint> -> separate X/Y arrays; returns avg, cnt
    local function FindCentroid(xs, ys, bounds)
        local cnt = 0
        local avg = ImPlot.ImPlotPoint()
        local bounds_fixed = ImPlot.ImPlotRect(
            math.min(bounds.X.Min, bounds.X.Max), math.max(bounds.X.Min, bounds.X.Max),
            math.min(bounds.Y.Min, bounds.Y.Max), math.max(bounds.Y.Min, bounds.Y.Max))
        for i = 1, #xs do
            if bounds_fixed:Contains(xs[i], ys[i]) then
                avg.x += xs[i]
                avg.y += ys[i]
                cnt += 1
            end
        end
        if cnt > 0 then
            avg.x = avg.x / cnt
            avg.y = avg.y / cnt
        end
        return avg, cnt
    end

    S.Demo_Querying = { xs = {}, ys = {}, rects = {}, limits = nil, select = nil, init = true }
    function D.Demo_Querying()
        IMGUI_DEMO_MARKER("Tools/Querying")
        local s = S.Demo_Querying
        local xs, ys, rects = s.xs, s.ys, s.rects
        if s.init then
            for _ = 1, 50 do
                table.insert(xs, RandomRange(0.1, 0.9))
                table.insert(ys, RandomRange(0.1, 0.9))
            end
            s.init = false
        end

        ImGui.BulletText("Box select and left click mouse to create a new query rect.")
        ImGui.BulletText("Ctrl + click in the plot area to draw points.")

        if ImGui.Button("Clear Queries") then
            table.clear(rects)
        end

        if ImPlot.BeginPlot("##Centroid") then
            ImPlot.SetupAxesLimits(0, 1, 0, 1)
            if ImPlot.IsPlotHovered() and ImGui.IsMouseClicked(0) and ImGui.GetIO().KeyCtrl then
                local pt = ImPlot.GetPlotMousePos()
                table.insert(xs, pt.x)
                table.insert(ys, pt.y)
            end
            local cent_spec = ImPlot.ImPlotSpec()
            cent_spec.Marker = ImPlotMarker.Square
            cent_spec.MarkerSize = 6
            ImPlot.PlotScatter("Points", xs, ys, #xs)
            if ImPlot.IsPlotSelected() then
                s.select = ImPlot.GetPlotSelection()
                local centroid, cnt = FindCentroid(xs, ys, s.select)
                if cnt > 0 then
                    ImPlot.PlotScatter("Centroid", { centroid.x }, { centroid.y }, 1, cent_spec)
                end
                if ImGui.IsMouseClicked(ImPlot.GetInputMap().SelectCancel) then
                    ImPlot.CancelPlotSelection()
                    table.insert(rects, s.select)
                end
            end
            for i = 1, #rects do
                local centroid, cnt = FindCentroid(xs, ys, rects[i])
                if cnt > 0 then
                    ImPlot.PlotScatter("Centroid", { centroid.x }, { centroid.y }, 1, cent_spec)
                end
                ImPlot.DragRect(i - 1, rects[i], ImVec4(1, 0, 1, 1))
            end
            s.limits = ImPlot.GetPlotLimits()
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_Annotations = { clamp = false, p = { 0.25, 0.25, 0.75, 0.75, 0.25 } }
    function D.Demo_Annotations()
        IMGUI_DEMO_MARKER("Tools/Annotations")
        local s = S.Demo_Annotations
        _, s.clamp = ImGui.Checkbox("Clamp", s.clamp)
        local clamp = s.clamp
        if ImPlot.BeginPlot("##Annotations") then
            ImPlot.SetupAxesLimits(0, 2, 0, 1)
            -- [Port] &p[0], &p[1] (overlapping pointers) -> explicit slices
            local p = s.p
            ImPlot.PlotScatter("##Points", { p[1], p[2], p[3], p[4] }, { p[2], p[3], p[4], p[5] }, 4)
            local col = ImPlot.GetLastItemColor()
            ImPlot.Annotation(0.25, 0.25, col, ImVec2(-15, 15), clamp, "BL")
            ImPlot.Annotation(0.75, 0.25, col, ImVec2(15, 15), clamp, "BR")
            ImPlot.Annotation(0.75, 0.75, col, ImVec2(15, -15), clamp, "TR")
            ImPlot.Annotation(0.25, 0.75, col, ImVec2(-15, -15), clamp, "TL")
            ImPlot.Annotation(0.5, 0.5, col, ImVec2(0, 0), clamp, "Center")

            ImPlot.Annotation(1.25, 0.75, ImVec4(0, 1, 0, 1), ImVec2(0, 0), clamp)

            local bx = { 1.2, 1.5, 1.8 }
            local by = { 0.25, 0.5, 0.75 }
            ImPlot.PlotBars("##Bars", bx, by, 3, 0.2)
            for i = 0, 2 do
                ImPlot.Annotation(bx[i + 1], by[i + 1], ImVec4(0, 0, 0, 0), ImVec2(0, -5), clamp, "B[%d]=%.2f", i, by[i + 1])
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_Tags = { show = true, drag_tag = 0.25 }
    function D.Demo_Tags()
        IMGUI_DEMO_MARKER("Tools/Tags")
        local s = S.Demo_Tags
        _, s.show = ImGui.Checkbox("Show Tags", s.show)
        if ImPlot.BeginPlot("##Tags") then
            ImPlot.SetupAxis(ImAxis.X2)
            ImPlot.SetupAxis(ImAxis.Y2)
            if s.show then
                ImPlot.TagX(0.25, ImVec4(1, 1, 0, 1))
                ImPlot.TagY(0.75, ImVec4(1, 1, 0, 1))
                s.drag_tag = ImPlot.DragLineY(0, s.drag_tag, ImVec4(1, 0, 0, 1), 1, ImPlot.ImPlotDragToolFlags.NoFit)
                ImPlot.TagY(s.drag_tag, ImVec4(1, 0, 0, 1), "Drag")
                ImPlot.SetAxes(ImAxis.X2, ImAxis.Y2)
                ImPlot.TagX(0.5, ImVec4(0, 1, 1, 1), "%s", "MyTag")
                ImPlot.TagY(0.5, ImVec4(0, 1, 1, 1), "Tag: %d", 42)
            end
            ImPlot.EndPlot()
        end
    end

    ---------------------------------------------------------------------------

    local function RandomColor()
        return ImVec4(RandomRange(0.0, 1.0), RandomRange(0.0, 1.0), RandomRange(0.0, 1.0), 1.0)
    end

    -- convenience struct to manage DND items; do this however you like
    -- [Port] MyDndItem -> table; ImVector<ImVec2> Data -> X/Y arrays; dnd[] is 0-indexed via [k + 1]
    local function MyDndItem(idx)
        local item = { Idx = idx, Plt = 0, Yax = ImAxis.Y1, Label = string.format("%02d Hz", idx + 1), Color = RandomColor(),
            X = table.create(1001, 0), Y = table.create(1001, 0) }
        for k = 0, 1000 do
            local t = k * 1.0 / 999
            item.X[k + 1] = t
            item.Y[k + 1] = 0.5 + 0.5 * math.sin(2 * 3.14 * t * (idx + 1))
        end
        return item
    end
    local function MyDndItem_Reset(item) item.Plt = 0; item.Yax = ImAxis.Y1 end

    S.Demo_DragAndDrop = { dnd = nil, dndx = nil, dndy = nil } -- [Port] dnd created on first use
    function D.Demo_DragAndDrop()
        IMGUI_DEMO_MARKER("Tools/Drag and Drop")
        local s = S.Demo_DragAndDrop
        local ImPlotCol = ImPlot.ImPlotCol
        ImGui.BulletText("Drag/drop items from the left column.")
        ImGui.BulletText("Drag/drop items between plots.")
        ImGui.Indent()
        ImGui.BulletText("Plot 1 Targets: Plot, Y-Axes, Legend")
        ImGui.BulletText("Plot 1 Sources: Legend Item Labels")
        ImGui.BulletText("Plot 2 Targets: Plot, X-Axis, Y-Axis")
        ImGui.BulletText("Plot 2 Sources: Plot, X-Axis, Y-Axis (hold Ctrl)")
        ImGui.Unindent()

        local k_dnd = 20
        if s.dnd == nil then
            s.dnd = table.create(k_dnd)
            for k = 0, k_dnd - 1 do s.dnd[k + 1] = MyDndItem(k) end
        end
        local dnd = s.dnd

        -- child window to serve as initial source for our DND items
        ImGui.BeginChild("DND_LEFT", ImVec2(100, 400))
        if ImGui.Button("Reset Data") then
            for k = 1, k_dnd do
                MyDndItem_Reset(dnd[k])
            end
            s.dndx, s.dndy = nil, nil
        end
        for k = 0, k_dnd - 1 do
            local item = dnd[k + 1]
            if item.Plt <= 0 then
                ImPlot.ItemIcon(item.Color); ImGui.SameLine()
                ImGui.Selectable(item.Label, false, 0, ImVec2(100, 0))
                if ImGui.BeginDragDropSource(0) then
                    ImGui.SetDragDropPayload("MY_DND", k, 1)
                    ImPlot.ItemIcon(item.Color); ImGui.SameLine()
                    ImGui.TextUnformatted(item.Label)
                    ImGui.EndDragDropSource()
                end
            end
        end
        ImGui.EndChild()
        if ImGui.BeginDragDropTarget() then
            local payload = ImGui.AcceptDragDropPayload("MY_DND")
            if payload then
                MyDndItem_Reset(dnd[payload.Data + 1])
            end
            ImGui.EndDragDropTarget()
        end

        ImGui.SameLine()
        ImGui.BeginChild("DND_RIGHT", ImVec2(-1, 400))
        -- plot 1 (time series)
        local flags = bor(ImPlotAxisFlags.NoTickLabels, ImPlotAxisFlags.NoGridLines, ImPlotAxisFlags.NoHighlight)
        if ImPlot.BeginPlot("##DND1", ImVec2(-1, ImGui.GetTextLineHeight() * 13)) then
            ImPlot.SetupAxis(ImAxis.X1, nil, bor(flags, ImPlotAxisFlags.Lock))
            ImPlot.SetupAxis(ImAxis.Y1, "[drop here]", flags)
            ImPlot.SetupAxis(ImAxis.Y2, "[drop here]", bor(flags, ImPlotAxisFlags.Opposite))
            ImPlot.SetupAxis(ImAxis.Y3, "[drop here]", bor(flags, ImPlotAxisFlags.Opposite))

            for k = 0, k_dnd - 1 do
                local item = dnd[k + 1]
                if item.Plt == 1 and #item.X > 0 then
                    ImPlot.SetAxis(item.Yax)
                    local spec = ImPlot.ImPlotSpec()
                    spec.LineColor = item.Color
                    ImPlot.PlotLine(item.Label, item.X, item.Y, #item.X, spec)
                    -- allow legend item labels to be DND sources
                    if ImPlot.BeginDragDropSourceItem(item.Label) then
                        ImGui.SetDragDropPayload("MY_DND", k, 1)
                        ImPlot.ItemIcon(item.Color); ImGui.SameLine()
                        ImGui.TextUnformatted(item.Label)
                        ImPlot.EndDragDropSource()
                    end
                end
            end
            -- allow the main plot area to be a DND target
            if ImPlot.BeginDragDropTargetPlot() then
                local payload = ImGui.AcceptDragDropPayload("MY_DND")
                if payload then
                    local i = payload.Data + 1; dnd[i].Plt = 1; dnd[i].Yax = ImAxis.Y1
                end
                ImPlot.EndDragDropTarget()
            end
            -- allow each y-axis to be a DND target
            for y = ImAxis.Y1, ImAxis.Y3 do
                if ImPlot.BeginDragDropTargetAxis(y) then
                    local payload = ImGui.AcceptDragDropPayload("MY_DND")
                    if payload then
                        local i = payload.Data + 1; dnd[i].Plt = 1; dnd[i].Yax = y
                    end
                    ImPlot.EndDragDropTarget()
                end
            end
            -- allow the legend to be a DND target
            if ImPlot.BeginDragDropTargetLegend() then
                local payload = ImGui.AcceptDragDropPayload("MY_DND")
                if payload then
                    local i = payload.Data + 1; dnd[i].Plt = 1; dnd[i].Yax = ImAxis.Y1
                end
                ImPlot.EndDragDropTarget()
            end
            ImPlot.EndPlot()
        end
        -- plot 2 (Lissajous)
        if ImPlot.BeginPlot("##DND2", ImVec2(-1, ImGui.GetTextLineHeight() * 13)) then
            local dndx, dndy = s.dndx, s.dndy
            local axis_bg = ImPlot.GetStyle().Colors[ImPlotCol.AxisBg]
            ImPlot.PushStyleColor(ImPlotCol.AxisBg, dndx ~= nil and dndx.Color or axis_bg)
            ImPlot.SetupAxis(ImAxis.X1, dndx == nil and "[drop here]" or dndx.Label, flags)
            ImPlot.PushStyleColor(ImPlotCol.AxisBg, dndy ~= nil and dndy.Color or axis_bg)
            ImPlot.SetupAxis(ImAxis.Y1, dndy == nil and "[drop here]" or dndy.Label, flags)
            ImPlot.PopStyleColor(2)
            if dndx ~= nil and dndy ~= nil then
                local mixed = ImVec4((dndx.Color.x + dndy.Color.x) / 2, (dndx.Color.y + dndy.Color.y) / 2,
                    (dndx.Color.z + dndy.Color.z) / 2, (dndx.Color.w + dndy.Color.w) / 2)
                local spec = ImPlot.ImPlotSpec()
                spec.LineColor = mixed
                ImPlot.PlotLine("##dndxy", dndx.Y, dndy.Y, #dndx.Y, spec)
            end
            -- allow the x-axis to be a DND target
            if ImPlot.BeginDragDropTargetAxis(ImAxis.X1) then
                local payload = ImGui.AcceptDragDropPayload("MY_DND")
                if payload then
                    s.dndx = dnd[payload.Data + 1]
                end
                ImPlot.EndDragDropTarget()
            end
            -- allow the x-axis to be a DND source
            if dndx ~= nil and ImPlot.BeginDragDropSourceAxis(ImAxis.X1) then
                ImGui.SetDragDropPayload("MY_DND", dndx.Idx, 1)
                ImPlot.ItemIcon(dndx.Color); ImGui.SameLine()
                ImGui.TextUnformatted(dndx.Label)
                ImPlot.EndDragDropSource()
            end
            -- allow the y-axis to be a DND target
            if ImPlot.BeginDragDropTargetAxis(ImAxis.Y1) then
                local payload = ImGui.AcceptDragDropPayload("MY_DND")
                if payload then
                    s.dndy = dnd[payload.Data + 1]
                end
                ImPlot.EndDragDropTarget()
            end
            -- allow the y-axis to be a DND source
            if dndy ~= nil and ImPlot.BeginDragDropSourceAxis(ImAxis.Y1) then
                ImGui.SetDragDropPayload("MY_DND", dndy.Idx, 1)
                ImPlot.ItemIcon(dndy.Color); ImGui.SameLine()
                ImGui.TextUnformatted(dndy.Label)
                ImPlot.EndDragDropSource()
            end
            -- allow the plot area to be a DND target
            if ImPlot.BeginDragDropTargetPlot() then
                local payload = ImGui.AcceptDragDropPayload("MY_DND")
                if payload then
                    s.dndx = dnd[payload.Data + 1]; s.dndy = s.dndx
                end
                ImPlot.EndDragDropTarget() -- [Port] missing upstream; required to balance BeginDragDropTargetCustom
            end
            -- allow the plot area to be a DND source
            if ImPlot.BeginDragDropSourcePlot() then
                ImGui.TextUnformatted("Yes, you can\ndrag this!")
                ImPlot.EndDragDropSource()
            end
            ImPlot.EndPlot()
        end
        ImGui.EndChild()
    end

    ---------------------------------------------------------------------------
    -- [SECTION] MyImPlot helpers (custom getters, sparkline, seaborn style, candlestick)
    ---------------------------------------------------------------------------

    -- [Port] namespace MyImPlot -> table My (keeps the locals count down)
    local My = {}

    -- [Port] &arr[base] pointer: a read-only view so Spec.Offset/Stride (in elements) index from `base`
    function My.Ptr(arr, base)
        return setmetatable({}, { __index = function(_, i) return arr[i + base] end })
    end

    function My.SineWave(idx, wd)
        local x = idx * wd.X
        return x, wd.Offset + wd.Amp * math.sin(2 * 3.14 * wd.Freq * x)
    end

    function My.Spiral(idx)
        local r = 0.9           -- outer radius
        local a = 0             -- inner radius
        local b = 0.05          -- increment per rev
        local n = (r - a) / b   -- number  of revolutions
        local th = 2 * n * 3.14 -- angle
        local Th = th * idx / (1000 - 1)
        return 0.5 + (a + b * Th / (2.0 * 3.14)) * math.cos(Th),
               0.5 + (a + b * Th / (2.0 * 3.14)) * math.sin(Th)
    end

    function My.Sparkline(id, values, count, min_v, max_v, offset, col, size)
        ImPlot.PushStyleVar(ImPlot.ImPlotStyleVar.PlotPadding, ImVec2(0, 0))
        if ImPlot.BeginPlot(id, size, ImPlotFlags.CanvasOnly) then
            ImPlot.SetupAxes(nil, nil, ImPlotAxisFlags.NoDecorations, ImPlotAxisFlags.NoDecorations)
            ImPlot.SetupAxesLimits(0, count - 1, min_v, max_v, ImGuiCond.Always)
            ImPlot.PlotLine(id, values, count, 1, 0, {
                LineColor = col,
                FillColor = col,
                FillAlpha = 0.25,
                Offset = offset,
                Flags = ImPlot.ImPlotLineFlags.Shaded,
            })
            ImPlot.EndPlot()
        end
        ImPlot.PopStyleVar()
    end

    function My.StyleSeaborn()
        local style = ImPlot.GetStyle()

        local colors = style.Colors
        local ImPlotCol = ImPlot.ImPlotCol
        colors[ImPlotCol.FrameBg]       = ImVec4(1.00, 1.00, 1.00, 1.00)
        colors[ImPlotCol.PlotBg]        = ImVec4(0.92, 0.92, 0.95, 1.00)
        colors[ImPlotCol.PlotBorder]    = ImVec4(0.00, 0.00, 0.00, 0.00)
        colors[ImPlotCol.LegendBg]      = ImVec4(0.92, 0.92, 0.95, 1.00)
        colors[ImPlotCol.LegendBorder]  = ImVec4(0.80, 0.81, 0.85, 1.00)
        colors[ImPlotCol.LegendText]    = ImVec4(0.00, 0.00, 0.00, 1.00)
        colors[ImPlotCol.TitleText]     = ImVec4(0.00, 0.00, 0.00, 1.00)
        colors[ImPlotCol.InlayText]     = ImVec4(0.00, 0.00, 0.00, 1.00)
        colors[ImPlotCol.AxisText]      = ImVec4(0.00, 0.00, 0.00, 1.00)
        colors[ImPlotCol.AxisGrid]      = ImVec4(1.00, 1.00, 1.00, 1.00)
        colors[ImPlotCol.AxisBgHovered] = ImVec4(0.92, 0.92, 0.95, 1.00)
        colors[ImPlotCol.AxisBgActive]  = ImVec4(0.92, 0.92, 0.95, 0.75)
        colors[ImPlotCol.Selection]     = ImVec4(1.00, 0.65, 0.00, 1.00)
        colors[ImPlotCol.Crosshairs]    = ImVec4(0.23, 0.10, 0.64, 0.50)

        style.MousePosPadding  = ImVec2(5, 5)
        style.PlotMinSize      = ImVec2(300, 225)
        style.PlotBorderSize   = 0
        style.MinorAlpha       = 1.0
        style.MajorTickLen     = ImVec2(0, 0)
        style.MinorTickLen     = ImVec2(0, 0)
        style.MajorTickSize    = ImVec2(0, 0)
        style.MinorTickSize    = ImVec2(0, 0)
        style.MajorGridSize    = ImVec2(1.2, 1.2)
        style.MinorGridSize    = ImVec2(1.2, 1.2)
        style.PlotPadding      = ImVec2(12, 12)
        style.LabelPadding     = ImVec2(5, 5)
        style.LegendPadding    = ImVec2(5, 5)
        style.DigitalPadding   = 20
        style.DigitalSpacing   = 4
    end

    -- [Port] ImPlotStyle assignment (deep copy)
    function My.CopyStyle(dst, src)
        for k, v in pairs(src) do
            if k == "Colors" then
                dst.Colors = {}
                for i, c in pairs(v) do dst.Colors[i] = ImVec4(c.x, c.y, c.z, c.w) end
            elseif type(v) == "table" then
                dst[k] = ImVec2(v.x, v.y)
            else
                dst[k] = v
            end
        end
        return dst
    end

    function My.BinarySearch(arr, l, r, x)
        if r >= l then
            local mid = l + (r - l) // 2
            if arr[mid + 1] == x then
                return mid
            end
            if arr[mid + 1] > x then
                return My.BinarySearch(arr, l, mid - 1, x)
            end
            return My.BinarySearch(arr, mid + 1, r, x)
        end
        return -1
    end

    -- [Port] uses ImPlot.internal (implot_internal.h); arrays are 1-based
    function My.PlotCandlestick(label_id, xs, opens, closes, lows, highs, count, tooltip, width_percent, bullCol, bearCol)
        local internal = ImPlot.internal
        if tooltip == nil then tooltip = true end
        width_percent = width_percent or 0.25
        bullCol = bullCol or ImVec4(0, 1, 0, 1)
        bearCol = bearCol or ImVec4(1, 0, 0, 1)

        -- get ImGui window DrawList
        local draw_list = ImPlot.GetPlotDrawList()
        -- calc real value width
        local half_width = width_percent
        if count > 1 then half_width = (xs[2] - xs[1]) * width_percent end

        -- custom tool
        if ImPlot.IsPlotHovered() and tooltip then
            local mouse = ImPlot.GetPlotMousePos()
            mouse.x = internal.RoundTime(internal.ImPlotTimeFromDouble(mouse.x), internal.ImPlotTimeUnit.Day):ToDouble()
            local tool_l = ImPlot.PlotToPixels(mouse.x - half_width * 1.5, mouse.y).x
            local tool_r = ImPlot.PlotToPixels(mouse.x + half_width * 1.5, mouse.y).x
            local tool_t = ImPlot.GetPlotPos().y
            local tool_b = tool_t + ImPlot.GetPlotSize().y
            ImPlot.PushPlotClipRect()
            draw_list:AddRectFilled(ImVec2(tool_l, tool_t), ImVec2(tool_r, tool_b), G.IM_COL32(128, 128, 128, 64))
            ImPlot.PopPlotClipRect()
            -- find mouse location index
            local idx = My.BinarySearch(xs, 0, count - 1, mouse.x)
            -- render tool tip (won't be affected by plot clip rect)
            if idx ~= -1 then
                ImGui.BeginTooltip()
                local buff = internal.FormatDate(internal.ImPlotTimeFromDouble(xs[idx + 1]), internal.ImPlotDateFmt.DayMoYr, ImPlot.GetStyle().UseISO8601)
                ImGui.Text("Day:   %s", buff)
                ImGui.Text("Open:  $%.2f", opens[idx + 1])
                ImGui.Text("Close: $%.2f", closes[idx + 1])
                ImGui.Text("Low:   $%.2f", lows[idx + 1])
                ImGui.Text("High:  $%.2f", highs[idx + 1])
                ImGui.EndTooltip()
            end
        end

        -- begin plot item
        if internal.BeginItem(label_id) then
            -- override legend icon color
            internal.GetCurrentItem().Color = G.IM_COL32(64, 64, 64, 255)
            -- fit data if requested
            if internal.FitThisFrame() then
                for i = 1, count do
                    internal.FitPoint(xs[i], lows[i])
                    internal.FitPoint(xs[i], highs[i])
                end
            end
            -- render data
            for i = 1, count do
                local open_pos  = ImPlot.PlotToPixels(xs[i] - half_width, opens[i])
                local close_pos = ImPlot.PlotToPixels(xs[i] + half_width, closes[i])
                local color = ImGui.GetColorU32(opens[i] > closes[i] and bearCol or bullCol)
                -- [Port] upstream passes plot-space values to AddLineV (pixel space); converted to pixels here
                local low_pos  = ImPlot.PlotToPixels(xs[i], lows[i])
                local high_pos = ImPlot.PlotToPixels(xs[i], highs[i])
                internal.AddLineV(draw_list, low_pos.x, low_pos.y, high_pos.y, color)
                draw_list:AddRectFilled(open_pos, close_pos, color)
            end

            -- end plot item
            internal.EndItem()
        end
    end

    ---------------------------------------------------------------------------

    S.Demo_Tables = {
        flags = bor(G.ImGuiTableFlags.BordersOuter, G.ImGuiTableFlags.BordersV, G.ImGuiTableFlags.RowBg,
                    G.ImGuiTableFlags.Resizable, G.ImGuiTableFlags.Reorderable),
        anim = true, offset = 0, data = table.create(100, 0),
    }
    function D.Demo_Tables()
        IMGUI_DEMO_MARKER("Subplots/Tables")
        local s = S.Demo_Tables
        ImGui.BulletText("Plots can be used inside of ImGui tables as another means of creating subplots.")
        _, s.anim = ImGui.Checkbox("Animate", s.anim)
        if s.anim then
            s.offset = (s.offset + 1) % 100
        end
        if ImGui.BeginTable("##table", 3, s.flags, ImVec2(-1, 0)) then
            ImGui.TableSetupColumn("Electrode", G.ImGuiTableColumnFlags.WidthFixed, 75.0)
            ImGui.TableSetupColumn("Voltage", G.ImGuiTableColumnFlags.WidthFixed, 75.0)
            ImGui.TableSetupColumn("EMG Signal")
            ImGui.TableHeadersRow()
            ImPlot.PushColormap(ImPlotColormap.Cool)
            local data = s.data
            for row = 0, 9 do
                ImGui.TableNextRow()
                math.randomseed(row)
                for i = 1, 100 do
                    data[i] = RandomRange(0.0, 10.0)
                end
                ImGui.TableSetColumnIndex(0)
                ImGui.Text("EMG %d", row)
                ImGui.TableSetColumnIndex(1)
                ImGui.Text("%.3f V", data[s.offset + 1])
                ImGui.TableSetColumnIndex(2)
                ImGui.PushID(row)
                My.Sparkline("##spark", data, 100, 0, 11.0, s.offset, ImPlot.GetColormapColor(row), ImVec2(-1, 35))
                ImGui.PopID()
            end
            ImPlot.PopColormap()
            ImGui.EndTable()
        end
    end

    -- [Port] ImVec2 data[20] -> flat interleaved {x0, y0, x1, y1, ...}; &data[0].x/.y -> My.Ptr views, Stride = 2
    S.Demo_ItemStylingAndSpec = { data1 = table.create(40, 0), data2 = table.create(40, 0) }
    function D.Demo_ItemStylingAndSpec()
        local s = S.Demo_ItemStylingAndSpec
        for i = 0, 19 do
            local x = i * 1 / 19.0
            s.data1[2 * i + 1] = x
            s.data1[2 * i + 2] = x * x
        end
        for i = 0, 19 do
            local x = i * 1 / 19.0
            s.data2[2 * i + 1] = x
            s.data2[2 * i + 2] = x * x * x
        end
        if ImPlot.BeginPlot("##SpecStyling") then
            ImPlot.SetupAxes("x", "y")

            -- Two options for using ImPlotSpec:

            -- 1. By declaring and defining a struct instance:
            local spec = ImPlot.ImPlotSpec()
            spec.LineColor = ImVec4(1, 1, 0, 1)
            spec.LineWeight = 1.0
            spec.FillColor = ImVec4(1, 0.5, 0, 1)
            spec.FillAlpha = 0.5
            spec.Marker = ImPlotMarker.Square
            spec.MarkerSize = 6
            spec.Stride = 2
            spec.Flags = bor(ImPlot.ImPlotItemFlags.NoLegend, ImPlot.ImPlotLineFlags.Shaded)
            ImPlot.PlotLine("Line 1", My.Ptr(s.data1, 0), My.Ptr(s.data1, 1), 20, spec)

            -- 2. Inline using ImPlotProp,value pairs (order does NOT matter):
            ImPlot.PlotLine("Line 2", My.Ptr(s.data2, 0), My.Ptr(s.data2, 1), 20, ImPlot.ImPlotSpec(
                ImPlotProp.LineColor, ImVec4(0, 1, 1, 1),
                ImPlotProp.LineWeight, 1.0,
                ImPlotProp.FillColor, ImVec4(0, 0, 1, 1),
                ImPlotProp.FillAlpha, 0.5,
                ImPlotProp.Marker, ImPlotMarker.Diamond,
                ImPlotProp.Size, 6,
                ImPlotProp.Stride, 2,
                ImPlotProp.Flags, bor(ImPlot.ImPlotItemFlags.NoLegend, ImPlot.ImPlotLineFlags.Shaded)
            ))

            ImPlot.EndPlot()
        end
    end

    S.Demo_OffsetAndStride = { offset = 0, interleaved_data = table.create(2 * 50 * 11, 0) }
    function D.Demo_OffsetAndStride()
        IMGUI_DEMO_MARKER("Tools/Offset and Stride")
        local s = S.Demo_OffsetAndStride
        local k_circles    = 11
        local k_points_per = 50
        local interleaved_data = s.interleaved_data
        for p = 0, k_points_per - 1 do
            for c = 0, k_circles - 1 do
                local r = c / (k_circles - 1) * 0.2 + 0.2
                interleaved_data[p * 2 * k_circles + 2 * c + 0 + 1] = 0.5 + r * math.cos(p / k_points_per * 6.28)
                interleaved_data[p * 2 * k_circles + 2 * c + 1 + 1] = 0.5 + r * math.sin(p / k_points_per * 6.28)
            end
        end
        ImGui.BulletText("Offsetting is useful for realtime plots (see above) and circular buffers.")
        ImGui.BulletText("Striding is useful for interleaved data (e.g. audio) or plotting structs.")
        ImGui.BulletText("Here, all circle data is stored in a single interleaved buffer:")
        ImGui.BulletText("[c0.x0 c0.y0 ... cn.x0 cn.y0 c0.x1 c0.y1 ... cn.x1 cn.y1 ... cn.xm cn.ym]")
        ImGui.BulletText("The offset value indicates which circle point index is considered the first.")
        ImGui.BulletText("Offsets can be negative and/or larger than the actual data count.")
        s.offset = ImGui.SliderInt("Offset", s.offset, -2 * k_points_per, 2 * k_points_per)
        if ImPlot.BeginPlot("##strideoffset", ImVec2(-1, 0), ImPlotFlags.Equal) then
            ImPlot.PushColormap(ImPlotColormap.Jet)
            for c = 0, k_circles - 1 do
                local buff = string.format("Circle %d", c)
                -- [Port] Stride is in elements (2*k_circles doubles)
                ImPlot.PlotLine(buff, My.Ptr(interleaved_data, c * 2 + 0), My.Ptr(interleaved_data, c * 2 + 1), k_points_per,
                    ImPlot.ImPlotSpec(ImPlotProp.Offset, s.offset, ImPlotProp.Stride, 2 * k_circles))
            end
            ImPlot.EndPlot()
            ImPlot.PopColormap()
        end
        -- offset++; uncomment for animation!
    end

    S.Demo_CustomDataAndGetters = {
        data1 = WaveData(0.001, 0.2, 2, 0.75),
        data2 = WaveData(0.001, 0.2, 4, 0.25),
    }
    function D.Demo_CustomDataAndGetters()
        IMGUI_DEMO_MARKER("Custom/Custom Data and Getters")
        local s = S.Demo_CustomDataAndGetters
        ImGui.BulletText("You can plot custom structs using the stride feature.")
        ImGui.BulletText("Most plotters can also be passed a function pointer for getting data.")
        ImGui.Indent()
            ImGui.BulletText("You can optionally pass user data to be given to your getter function.")
            ImGui.BulletText("C++ lambdas can be passed as function pointers as well!")
        ImGui.Unindent()

        -- [Port] MyImPlot::Vector2f vec2_data[2] -> flat interleaved {x0, y0, x1, y1}
        local vec2_data = { 0, 0, 1, 1 }

        if ImPlot.BeginPlot("##Custom Data") then

            -- custom structs using stride example:
            ImPlot.PlotLine("Vector2f", My.Ptr(vec2_data, 0), My.Ptr(vec2_data, 1), 2, ImPlot.ImPlotSpec(ImPlotProp.Stride, 2))

            -- custom getter example 1:
            ImPlot.PlotLineG("Spiral", My.Spiral, nil, 1000)

            -- custom getter example 2:
            ImPlot.PlotLineG("Waves", My.SineWave, s.data1, 1000)
            ImPlot.PlotLineG("Waves", SawWave, s.data2, 1000)
            ImPlot.PlotShadedG("Waves", My.SineWave, s.data1, SawWave, s.data2, 1000, ImPlot.ImPlotSpec(ImPlotProp.FillAlpha, 0.25))

            -- you can also pass C++ lambdas:
            -- auto lambda = [](void* data, int idx) { ... return ImPlotPoint(x,y); };
            -- ImPlot::PlotLine("My Lambda", lambda, data, 1000);

            ImPlot.EndPlot()
        end
    end

    -- [Port] formatter(value, data) -> string
    local MetricFormatter_v = { 1000000000, 1000000, 1000, 1, 0.001, 0.000001, 0.000000001 }
    local MetricFormatter_p = { "G", "M", "k", "", "m", "u", "n" }
    function My.MetricFormatter(value, unit)
        if value == 0 then
            return string.format("0 %s", unit)
        end
        for i = 1, 7 do
            if math.abs(value) >= MetricFormatter_v[i] then
                return string.format("%g %s%s", value / MetricFormatter_v[i], MetricFormatter_p[i], unit)
            end
        end
        return string.format("%g %s%s", value / MetricFormatter_v[7], MetricFormatter_p[7], unit)
    end

    S.Demo_TickLabels = {
        custom_fmt = true, custom_ticks = false, custom_labels = true,
        yticks = { 100, 300, 700, 900 },
        ylabels = { "One", "Three", "Seven", "Nine" },
        yticks_aux = { 0.2, 0.4, 0.6 },
        ylabels_aux = { "A", "B", "C", "D", "E", "F" },
    }
    function D.Demo_TickLabels()
        IMGUI_DEMO_MARKER("Axes/Tick Labels")
        local s = S.Demo_TickLabels
        _, s.custom_fmt = ImGui.Checkbox("Show Custom Format", s.custom_fmt)
        ImGui.SameLine()
        _, s.custom_ticks = ImGui.Checkbox("Show Custom Ticks", s.custom_ticks)
        if s.custom_ticks then
            ImGui.SameLine()
            _, s.custom_labels = ImGui.Checkbox("Show Custom Labels", s.custom_labels)
        end
        local pi = { 3.14 }
        local pi_str = { "PI" }
        if ImPlot.BeginPlot("##Ticks") then
            ImPlot.SetupAxesLimits(2.5, 5, 0, 1000)
            ImPlot.SetupAxis(ImAxis.Y2, nil, ImPlotAxisFlags.AuxDefault)
            ImPlot.SetupAxis(ImAxis.Y3, nil, ImPlotAxisFlags.AuxDefault)
            if s.custom_fmt then
                ImPlot.SetupAxisFormat(ImAxis.X1, "%g ms")
                ImPlot.SetupAxisFormat(ImAxis.Y1, My.MetricFormatter, "Hz")
                ImPlot.SetupAxisFormat(ImAxis.Y2, "%g dB")
                ImPlot.SetupAxisFormat(ImAxis.Y3, My.MetricFormatter, "m")
            end
            if s.custom_ticks then
                ImPlot.SetupAxisTicks(ImAxis.X1, pi, 1, s.custom_labels and pi_str or nil, true)
                ImPlot.SetupAxisTicks(ImAxis.Y1, s.yticks, 4, s.custom_labels and s.ylabels or nil, false)
                ImPlot.SetupAxisTicks(ImAxis.Y2, s.yticks_aux, 3, s.custom_labels and s.ylabels_aux or nil, false)
                ImPlot.SetupAxisTicks(ImAxis.Y3, 0, 1, 6, s.custom_labels and s.ylabels_aux or nil, false)
            end
            ImPlot.EndPlot()
        end
    end

    function D.Demo_CustomStyles()
        IMGUI_DEMO_MARKER("Custom/Custom Styles")
        ImPlot.PushColormap(ImPlotColormap.Deep)
        -- normally you wouldn't change the entire style each frame
        local backup = My.CopyStyle({}, ImPlot.GetStyle())
        My.StyleSeaborn()
        if ImPlot.BeginPlot("seaborn style") then
            ImPlot.SetupAxes("x-axis", "y-axis")
            ImPlot.SetupAxesLimits(-0.5, 9.5, 0, 10)
            local lin = { 8, 8, 9, 7, 8, 8, 8, 9, 7, 8 }
            local bar = { 1, 2, 5, 3, 4, 1, 2, 5, 3, 4 }
            local dot = { 7, 6, 6, 7, 8, 5, 6, 5, 8, 7 }
            ImPlot.PlotBars("Bars", bar, 10, 0.5)
            ImPlot.PlotLine("Line", lin, 10)
            ImPlot.NextColormapColor() -- skip green
            ImPlot.PlotScatter("Scatter", dot, 10)
            ImPlot.EndPlot()
        end
        My.CopyStyle(ImPlot.GetStyle(), backup)
        ImPlot.PopColormap()
    end

    function D.Demo_CustomRendering()
        IMGUI_DEMO_MARKER("Custom/Custom Rendering")
        if ImPlot.BeginPlot("##CustomRend") then
            local cntr = ImPlot.PlotToPixels(0.5, 0.5)
            local rmin = ImPlot.PlotToPixels(0.25, 0.75)
            local rmax = ImPlot.PlotToPixels(0.75, 0.25)
            ImPlot.PushPlotClipRect()
            ImPlot.GetPlotDrawList():AddCircleFilled(cntr, 20, G.IM_COL32(255, 255, 0, 255), 20)
            ImPlot.GetPlotDrawList():AddRect(rmin, rmax, G.IM_COL32(128, 0, 255, 255))
            ImPlot.PopPlotClipRect()
            ImPlot.EndPlot()
        end
    end

    S.Demo_LegendPopups = {
        frequency = 0.1, amplitude = 0.5, color = ImVec4(1, 1, 0, 1), alpha = 1.0,
        line = false, thickness = 1, markers = false, shaded = false,
        vals = table.create(101, 0),
    }
    function D.Demo_LegendPopups()
        IMGUI_DEMO_MARKER("Tools/Legend Popups")
        local s = S.Demo_LegendPopups
        ImGui.BulletText("You can implement legend context menus to inject per-item controls and widgets.")
        ImGui.BulletText("Right click the legend label/icon to edit custom item attributes.")

        for i = 0, 100 do
            s.vals[i + 1] = s.amplitude * math.sin(s.frequency * i)
        end

        if ImPlot.BeginPlot("Right Click the Legend") then
            ImPlot.SetupAxesLimits(0, 100, -1, 1)
            -- rendering logic
            if not s.line then
                ImPlot.PlotBars("Right Click Me", s.vals, 101, 0.67, 0, ImPlot.ImPlotSpec(
                    ImPlotProp.FillAlpha, s.alpha,
                    ImPlotProp.FillColor, s.color
                ))
            else
                ImPlot.PlotLine("Right Click Me", s.vals, 101, 1, 0, ImPlot.ImPlotSpec(
                    ImPlotProp.LineColor, s.color,
                    ImPlotProp.LineWeight, s.thickness
                ))
                if s.markers then
                    ImPlot.PlotScatter("Right Click Me", s.vals, 101, 1, 0, ImPlot.ImPlotSpec(
                        ImPlotProp.Marker, ImPlotMarker.Square,
                        ImPlotProp.LineColor, s.color
                    ))
                end
                if s.shaded then
                    ImPlot.PlotShaded("Right Click Me", s.vals, 101, 0, 1, 0, ImPlot.ImPlotSpec(
                        ImPlotProp.FillAlpha, s.alpha
                    ))
                end
            end
            -- custom legend context menu
            if ImPlot.BeginLegendPopup("Right Click Me") then
                s.frequency = ImGui.SliderFloat("Frequency", s.frequency, 0, 1, "%0.2f")
                s.amplitude = ImGui.SliderFloat("Amplitude", s.amplitude, 0, 1, "%0.2f")
                ImGui.Separator()
                ImGui.ColorEdit3("Color", s.color)
                s.alpha = ImGui.SliderFloat("Transparency", s.alpha, 0, 1, "%.2f")
                _, s.line = ImGui.Checkbox("Line Plot", s.line)
                if s.line then
                    s.thickness = ImGui.SliderFloat("Thickness", s.thickness, 0, 5)
                    _, s.markers = ImGui.Checkbox("Markers", s.markers)
                    _, s.shaded = ImGui.Checkbox("Shaded", s.shaded)
                end
                ImPlot.EndLegendPopup()
            end
            ImPlot.EndPlot()
        end
    end

    S.Demo_ColormapWidgets = { cmap = ImPlotColormap.Viridis, t = 0.5, col = ImVec4(0, 0, 0, 0), flags = 0, scale = { 0, 100 } }
    function D.Demo_ColormapWidgets()
        IMGUI_DEMO_MARKER("Tools/Colormap Widgets")
        local s = S.Demo_ColormapWidgets

        if ImPlot.ColormapButton("Button", ImVec2(0, 0), s.cmap) then
            s.cmap = (s.cmap + 1) % ImPlot.GetColormapCount()
        end

        ImGui.ColorButton("##Display", s.col, G.ImGuiColorEditFlags.NoInputs)
        ImGui.SameLine()
        s.t = ImPlot.ColormapSlider("Slider", s.t, s.col, "%.3f", s.cmap)

        ImPlot.ColormapIcon(s.cmap); ImGui.SameLine(); ImGui.Text("Icon")

        ImPlot.ColormapScale("Scale", s.scale[1], s.scale[2], ImVec2(0, 0), "%g dB", s.flags, s.cmap)
        ImGui.InputFloat2("Scale", s.scale)
        local ImPlotColormapScaleFlags = ImPlot.ImPlotColormapScaleFlags
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotColormapScaleFlags_NoLabel", ImPlotColormapScaleFlags.NoLabel)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotColormapScaleFlags_Opposite", ImPlotColormapScaleFlags.Opposite)
        s.flags = CHECKBOX_FLAG(s.flags, "ImPlotColormapScaleFlags_Invert", ImPlotColormapScaleFlags.Invert)
    end

    S.Demo_CustomPlottersAndTooltips = {
        tooltip = true,
        bullCol = ImVec4(0.000, 1.000, 0.441, 1.000),
        bearCol = ImVec4(0.853, 0.050, 0.310, 1.000),
        dates = { 1546300800,1546387200,1546473600,1546560000,1546819200,1546905600,1546992000,1547078400,1547164800,1547424000,1547510400,1547596800,1547683200,1547769600,1547942400,1548028800,1548115200,1548201600,1548288000,1548374400,1548633600,1548720000,1548806400,1548892800,1548979200,1549238400,1549324800,1549411200,1549497600,1549584000,1549843200,1549929600,1550016000,1550102400,1550188800,1550361600,1550448000,1550534400,1550620800,1550707200,1550793600,1551052800,1551139200,1551225600,1551312000,1551398400,1551657600,1551744000,1551830400,1551916800,1552003200,1552262400,1552348800,1552435200,1552521600,1552608000,1552867200,1552953600,1553040000,1553126400,1553212800,1553472000,1553558400,1553644800,1553731200,1553817600,1554076800,1554163200,1554249600,1554336000,1554422400,1554681600,1554768000,1554854400,1554940800,1555027200,1555286400,1555372800,1555459200,1555545600,1555632000,1555891200,1555977600,1556064000,1556150400,1556236800,1556496000,1556582400,1556668800,1556755200,1556841600,1557100800,1557187200,1557273600,1557360000,1557446400,1557705600,1557792000,1557878400,1557964800,1558051200,1558310400,1558396800,1558483200,1558569600,1558656000,1558828800,1558915200,1559001600,1559088000,1559174400,1559260800,1559520000,1559606400,1559692800,1559779200,1559865600,1560124800,1560211200,1560297600,1560384000,1560470400,1560729600,1560816000,1560902400,1560988800,1561075200,1561334400,1561420800,1561507200,1561593600,1561680000,1561939200,1562025600,1562112000,1562198400,1562284800,1562544000,1562630400,1562716800,1562803200,1562889600,1563148800,1563235200,1563321600,1563408000,1563494400,1563753600,1563840000,1563926400,1564012800,1564099200,1564358400,1564444800,1564531200,1564617600,1564704000,1564963200,1565049600,1565136000,1565222400,1565308800,1565568000,1565654400,1565740800,1565827200,1565913600,1566172800,1566259200,1566345600,1566432000,1566518400,1566777600,1566864000,1566950400,1567036800,1567123200,1567296000,1567382400,1567468800,1567555200,1567641600,1567728000,1567987200,1568073600,1568160000,1568246400,1568332800,1568592000,1568678400,1568764800,1568851200,1568937600,1569196800,1569283200,1569369600,1569456000,1569542400,1569801600,1569888000,1569974400,1570060800,1570147200,1570406400,1570492800,1570579200,1570665600,1570752000,1571011200,1571097600,1571184000,1571270400,1571356800,1571616000,1571702400,1571788800,1571875200,1571961600 },
        opens = { 1284.7,1319.9,1318.7,1328,1317.6,1321.6,1314.3,1325,1319.3,1323.1,1324.7,1321.3,1323.5,1322,1281.3,1281.95,1311.1,1315,1314,1313.1,1331.9,1334.2,1341.3,1350.6,1349.8,1346.4,1343.4,1344.9,1335.6,1337.9,1342.5,1337,1338.6,1337,1340.4,1324.65,1324.35,1349.5,1371.3,1367.9,1351.3,1357.8,1356.1,1356,1347.6,1339.1,1320.6,1311.8,1314,1312.4,1312.3,1323.5,1319.1,1327.2,1332.1,1320.3,1323.1,1328,1330.9,1338,1333,1335.3,1345.2,1341.1,1332.5,1314,1314.4,1310.7,1314,1313.1,1315,1313.7,1320,1326.5,1329.2,1314.2,1312.3,1309.5,1297.4,1293.7,1277.9,1295.8,1295.2,1290.3,1294.2,1298,1306.4,1299.8,1302.3,1297,1289.6,1302,1300.7,1303.5,1300.5,1303.2,1306,1318.7,1315,1314.5,1304.1,1294.7,1293.7,1291.2,1290.2,1300.4,1284.2,1284.25,1301.8,1295.9,1296.2,1304.4,1323.1,1340.9,1341,1348,1351.4,1351.4,1343.5,1342.3,1349,1357.6,1357.1,1354.7,1361.4,1375.2,1403.5,1414.7,1433.2,1438,1423.6,1424.4,1418,1399.5,1435.5,1421.25,1434.1,1412.4,1409.8,1412.2,1433.4,1418.4,1429,1428.8,1420.6,1441,1460.4,1441.7,1438.4,1431,1439.3,1427.4,1431.9,1439.5,1443.7,1425.6,1457.5,1451.2,1481.1,1486.7,1512.1,1515.9,1509.2,1522.3,1513,1526.6,1533.9,1523,1506.3,1518.4,1512.4,1508.8,1545.4,1537.3,1551.8,1549.4,1536.9,1535.25,1537.95,1535.2,1556,1561.4,1525.6,1516.4,1507,1493.9,1504.9,1506.5,1513.1,1506.5,1509.7,1502,1506.8,1521.5,1529.8,1539.8,1510.9,1511.8,1501.7,1478,1485.4,1505.6,1511.6,1518.6,1498.7,1510.9,1510.8,1498.3,1492,1497.7,1484.8,1494.2,1495.6,1495.6,1487.5,1491.1,1495.1,1506.4 },
        highs = { 1284.75,1320.6,1327,1330.8,1326.8,1321.6,1326,1328,1325.8,1327.1,1326,1326,1323.5,1322.1,1282.7,1282.95,1315.8,1316.3,1314,1333.2,1334.7,1341.7,1353.2,1354.6,1352.2,1346.4,1345.7,1344.9,1340.7,1344.2,1342.7,1342.1,1345.2,1342,1350,1324.95,1330.75,1369.6,1374.3,1368.4,1359.8,1359,1357,1356,1353.4,1340.6,1322.3,1314.1,1316.1,1312.9,1325.7,1323.5,1326.3,1336,1332.1,1330.1,1330.4,1334.7,1341.1,1344.2,1338.8,1348.4,1345.6,1342.8,1334.7,1322.3,1319.3,1314.7,1316.6,1316.4,1315,1325.4,1328.3,1332.2,1329.2,1316.9,1312.3,1309.5,1299.6,1296.9,1277.9,1299.5,1296.2,1298.4,1302.5,1308.7,1306.4,1305.9,1307,1297.2,1301.7,1305,1305.3,1310.2,1307,1308,1319.8,1321.7,1318.7,1316.2,1305.9,1295.8,1293.8,1293.7,1304.2,1302,1285.15,1286.85,1304,1302,1305.2,1323,1344.1,1345.2,1360.1,1355.3,1363.8,1353,1344.7,1353.6,1358,1373.6,1358.2,1369.6,1377.6,1408.9,1425.5,1435.9,1453.7,1438,1426,1439.1,1418,1435,1452.6,1426.65,1437.5,1421.5,1414.1,1433.3,1441.3,1431.4,1433.9,1432.4,1440.8,1462.3,1467,1443.5,1444,1442.9,1447,1437.6,1440.8,1445.7,1447.8,1458.2,1461.9,1481.8,1486.8,1522.7,1521.3,1521.1,1531.5,1546.1,1534.9,1537.7,1538.6,1523.6,1518.8,1518.4,1514.6,1540.3,1565,1554.5,1556.6,1559.8,1541.9,1542.9,1540.05,1558.9,1566.2,1561.9,1536.2,1523.8,1509.1,1506.2,1532.2,1516.6,1519.7,1515,1519.5,1512.1,1524.5,1534.4,1543.3,1543.3,1542.8,1519.5,1507.2,1493.5,1511.4,1525.8,1522.2,1518.8,1515.3,1518,1522.3,1508,1501.5,1503,1495.5,1501.1,1497.9,1498.7,1492.1,1499.4,1506.9,1520.9 },
        lows = { 1282.85,1315,1318.7,1309.6,1317.6,1312.9,1312.4,1319.1,1319,1321,1318.1,1321.3,1319.9,1312,1280.5,1276.15,1308,1309.9,1308.5,1312.3,1329.3,1333.1,1340.2,1347,1345.9,1338,1340.8,1335,1332,1337.9,1333,1336.8,1333.2,1329.9,1340.4,1323.85,1324.05,1349,1366.3,1351.2,1349.1,1352.4,1350.7,1344.3,1338.9,1316.3,1308.4,1306.9,1309.6,1306.7,1312.3,1315.4,1319,1327.2,1317.2,1320,1323,1328,1323,1327.8,1331.7,1335.3,1336.6,1331.8,1311.4,1310,1309.5,1308,1310.6,1302.8,1306.6,1313.7,1320,1322.8,1311,1312.1,1303.6,1293.9,1293.5,1291,1277.9,1294.1,1286,1289.1,1293.5,1296.9,1298,1299.6,1292.9,1285.1,1288.5,1296.3,1297.2,1298.4,1298.6,1302,1300.3,1312,1310.8,1301.9,1292,1291.1,1286.3,1289.2,1289.9,1297.4,1283.65,1283.25,1292.9,1295.9,1290.8,1304.2,1322.7,1336.1,1341,1343.5,1345.8,1340.3,1335.1,1341.5,1347.6,1352.8,1348.2,1353.7,1356.5,1373.3,1398,1414.7,1427,1416.4,1412.7,1420.1,1396.4,1398.8,1426.6,1412.85,1400.7,1406,1399.8,1404.4,1415.5,1417.2,1421.9,1415,1413.7,1428.1,1434,1435.7,1427.5,1429.4,1423.9,1425.6,1427.5,1434.8,1422.3,1412.1,1442.5,1448.8,1468.2,1484.3,1501.6,1506.2,1498.6,1488.9,1504.5,1518.3,1513.9,1503.3,1503,1506.5,1502.1,1503,1534.8,1535.3,1541.4,1528.6,1525.6,1535.25,1528.15,1528,1542.6,1514.3,1510.7,1505.5,1492.1,1492.9,1496.8,1493.1,1503.4,1500.9,1490.7,1496.3,1505.3,1505.3,1517.9,1507.4,1507.1,1493.3,1470.5,1465,1480.5,1501.7,1501.4,1493.3,1492.1,1505.1,1495.7,1478,1487.1,1480.8,1480.6,1487,1488.3,1484.8,1484,1490.7,1490.4,1503.1 },
        closes = { 1283.35,1315.3,1326.1,1317.4,1321.5,1317.4,1323.5,1319.2,1321.3,1323.3,1319.7,1325.1,1323.6,1313.8,1282.05,1279.05,1314.2,1315.2,1310.8,1329.1,1334.5,1340.2,1340.5,1350,1347.1,1344.3,1344.6,1339.7,1339.4,1343.7,1337,1338.9,1340.1,1338.7,1346.8,1324.25,1329.55,1369.6,1372.5,1352.4,1357.6,1354.2,1353.4,1346,1341,1323.8,1311.9,1309.1,1312.2,1310.7,1324.3,1315.7,1322.4,1333.8,1319.4,1327.1,1325.8,1330.9,1325.8,1331.6,1336.5,1346.7,1339.2,1334.7,1313.3,1316.5,1312.4,1313.4,1313.3,1312.2,1313.7,1319.9,1326.3,1331.9,1311.3,1313.4,1309.4,1295.2,1294.7,1294.1,1277.9,1295.8,1291.2,1297.4,1297.7,1306.8,1299.4,1303.6,1302.2,1289.9,1299.2,1301.8,1303.6,1299.5,1303.2,1305.3,1319.5,1313.6,1315.1,1303.5,1293,1294.6,1290.4,1291.4,1302.7,1301,1284.15,1284.95,1294.3,1297.9,1304.1,1322.6,1339.3,1340.1,1344.9,1354,1357.4,1340.7,1342.7,1348.2,1355.1,1355.9,1354.2,1362.1,1360.1,1408.3,1411.2,1429.5,1430.1,1426.8,1423.4,1425.1,1400.8,1419.8,1432.9,1423.55,1412.1,1412.2,1412.8,1424.9,1419.3,1424.8,1426.1,1423.6,1435.9,1440.8,1439.4,1439.7,1434.5,1436.5,1427.5,1432.2,1433.3,1441.8,1437.8,1432.4,1457.5,1476.5,1484.2,1519.6,1509.5,1508.5,1517.2,1514.1,1527.8,1531.2,1523.6,1511.6,1515.7,1515.7,1508.5,1537.6,1537.2,1551.8,1549.1,1536.9,1529.4,1538.05,1535.15,1555.9,1560.4,1525.5,1515.5,1511.1,1499.2,1503.2,1507.4,1499.5,1511.5,1513.4,1515.8,1506.2,1515.1,1531.5,1540.2,1512.3,1515.2,1506.4,1472.9,1489,1507.9,1513.8,1512.9,1504.4,1503.9,1512.8,1500.9,1488.7,1497.6,1483.5,1494,1498.3,1494.1,1488.1,1487.5,1495.7,1504.7,1505.3 },
    }
    function D.Demo_CustomPlottersAndTooltips()
        IMGUI_DEMO_MARKER("Custom/Custom Plotters and Tooltips")
        local s = S.Demo_CustomPlottersAndTooltips
        ImGui.BulletText("You can create custom plotters or extend ImPlot using implot_internal.h.")
        _, s.tooltip = ImGui.Checkbox("Show Tooltip", s.tooltip)
        ImGui.SameLine()
        ImGui.SameLine(); ImGui.ColorEdit4("##Bull", s.bullCol, G.ImGuiColorEditFlags.NoInputs)
        ImGui.SameLine(); ImGui.ColorEdit4("##Bear", s.bearCol, G.ImGuiColorEditFlags.NoInputs)
        ImPlot.GetStyle().UseLocalTime = false

        if ImPlot.BeginPlot("Candlestick Chart", ImVec2(-1, 0)) then
            ImPlot.SetupAxes(nil, nil, 0, bor(ImPlotAxisFlags.AutoFit, ImPlotAxisFlags.RangeFit))
            ImPlot.SetupAxesLimits(1546300800, 1571961600, 1250, 1600)
            ImPlot.SetupAxisScale(ImAxis.X1, ImPlot.ImPlotScale.Time)
            ImPlot.SetupAxisLimitsConstraints(ImAxis.X1, 1546300800, 1571961600)
            ImPlot.SetupAxisZoomConstraints(ImAxis.X1, 60 * 60 * 24 * 14, 1571961600 - 1546300800)
            ImPlot.SetupAxisFormat(ImAxis.Y1, "$%.0f")
            My.PlotCandlestick("GOOGL", s.dates, s.opens, s.closes, s.lows, s.highs, 218, s.tooltip, 0.25, s.bullCol, s.bearCol)
            ImPlot.EndPlot()
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
