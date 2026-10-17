-- ImPlot for imgui-luau. Port of https://github.com/epezent/implot (851cdbdd60d1dfb64c23e987969694de0f547a6b).
-- Usage: local ImPlot = require(path.to.ImPlot)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local IM_COL32, IM_ASSERT = G.IM_COL32, G.IM_ASSERT
    local ImPlot = {}
    -- [Port] internal API (implot_internal.h). Exposed as ImPlot.internal for later milestones.
    local internal = {}
    ImPlot.internal = internal

    -- [Port] module-level context pointer (C++ global GImPlot)
    local GImPlot = nil

    ImPlot.IMPLOT_AUTO = -1
    -- [Port] function instead of constexpr so each use gets a fresh ImVec4
    local function IMPLOT_AUTO_COL() return ImVec4(0, 0, 0, -1) end
    ImPlot.IMPLOT_AUTO_COL = IMPLOT_AUTO_COL

    --------------------------------------------------------------------------
    -- [SECTION] Enums (implot.h)
    -- [Port] ImPlotFlags_NoTitle -> ImPlot.ImPlotFlags.NoTitle; values identical to upstream.
    --------------------------------------------------------------------------
    do
        -- Axis indices. The values assigned may change; NEVER hardcode these.
        ImPlot.ImAxis = {
            -- horizontal axes
            X1 = 0, -- enabled by default
            X2 = 1, -- disabled by default
            X3 = 2, -- disabled by default
            -- vertical axes
            Y1 = 3, -- enabled by default
            Y2 = 4, -- disabled by default
            Y3 = 5, -- disabled by default
            -- bookkeeping
            COUNT = 6,
        }
        -- Plotting properties. These provide syntactic sugar for creating ImPlotSpecs from (ImPlotProp,value) pairs. See ImPlotSpec documentation.
        ImPlot.ImPlotProp = {
            LineColor = 0, -- line color (applies to lines, bar edges); IMPLOT_AUTO_COL will use next Colormap color or current item color
            LineColors = 1, -- array of colors for each line; if nullptr, use LineColor for all lines
            LineWeight = 2, -- line weight in pixels (applies to lines, bar edges, marker edges)
            FillColor = 3, -- fill color (applies to shaded regions, bar faces); IMPLOT_AUTO_COL will use next Colormap color or current item color
            FillColors = 4, -- array of colors for each fill; if nullptr, use FillColor for all fills
            FillAlpha = 5, -- alpha multiplier (applies to FillColor, FillColors, MarkerFillColor, and MarkerFillColors)
            Marker = 6, -- marker type; specify ImPlotMarker_Auto to use the next unused marker
            MarkerSize = 7, -- size of markers (radius) *in pixels*
            MarkerSizes = 8, -- array of sizes for each marker; if nullptr, use MarkerSize for all markers
            MarkerLineColor = 9, -- marker edge color; IMPLOT_AUTO_COL will use LineColor
            MarkerLineColors = 10, -- array of colors for each marker edge; if nullptr, use MarkerLineColor for all markers
            MarkerFillColor = 11, -- marker face color; IMPLOT_AUTO_COL will use LineColor
            MarkerFillColors = 12, -- array of colors for each marker face; if nullptr, use MarkerFillColor for all markers
            Size = 13, -- size of error bar whiskers (width or height), and digital bars (height) *in pixels*
            Offset = 14, -- data index offset
            Stride = 15, -- data stride in bytes; IMPLOT_AUTO will result in sizeof(T) where T is the type passed to PlotX
            Flags = 16, -- optional item flags; can be composed from common ImPlotItemFlags and/or specialized ImPlotXFlags
        }
        -- Options for plots (see BeginPlot).
        ImPlot.ImPlotFlags = {
            None = 0, -- default
            NoTitle = 1, -- the plot title will not be displayed (titles are also hidden if preceded by double hashes, e.g. "##MyPlot")
            NoLegend = 2, -- the legend will not be displayed
            NoMouseText = 4, -- the mouse position, in plot coordinates, will not be displayed inside of the plot
            NoInputs = 8, -- the user will not be able to interact with the plot
            NoMenus = 16, -- the user will not be able to open context menus
            NoBoxSelect = 32, -- the user will not be able to box-select
            NoFrame = 64, -- the ImGui frame will not be rendered
            Equal = 128, -- x and y axes pairs will be constrained to have the same units/pixel
            Crosshairs = 256, -- the default mouse cursor will be replaced with a crosshair when hovered
            CanvasOnly = 55,
        }
        -- Options for plot axes (see SetupAxis).
        ImPlot.ImPlotAxisFlags = {
            None = 0, -- default
            NoLabel = 1, -- the axis label will not be displayed (axis labels are also hidden if the supplied string name is nullptr)
            NoGridLines = 2, -- no grid lines will be displayed
            NoTickMarks = 4, -- no tick marks will be displayed
            NoTickLabels = 8, -- no text labels will be displayed
            NoInitialFit = 16, -- axis will not be initially fit to data extents on the first rendered frame
            NoMenus = 32, -- the user will not be able to open context menus with right-click
            NoSideSwitch = 64, -- the user will not be able to switch the axis side by dragging it
            NoHighlight = 128, -- the axis will not have its background highlighted when hovered or held
            Opposite = 256, -- axis ticks and labels will be rendered on the conventionally opposite side (i.e, right or top)
            Foreground = 512, -- grid lines will be displayed in the foreground (i.e. on top of data) instead of the background
            Invert = 1024, -- the axis will be inverted
            AutoFit = 2048, -- axis will be auto-fitting to data extents
            RangeFit = 4096, -- axis will only fit points if the point is in the visible range of the **orthogonal** axis
            PanStretch = 8192, -- panning in a locked or constrained state will cause the axis to stretch if possible
            LockMin = 16384, -- the axis minimum value will be locked when panning/zooming
            LockMax = 32768, -- the axis maximum value will be locked when panning/zooming
            Lock = 49152,
            NoDecorations = 15,
            AuxDefault = 258,
        }
        -- Options for subplots (see BeginSubplot)
        ImPlot.ImPlotSubplotFlags = {
            None = 0, -- default
            NoTitle = 1, -- the subplot title will not be displayed (titles are also hidden if preceded by double hashes, e.g. "##MySubplot")
            NoLegend = 2, -- the legend will not be displayed (only applicable if ImPlotSubplotFlags_ShareItems is enabled)
            NoMenus = 4, -- the user will not be able to open context menus with right-click
            NoResize = 8, -- resize splitters between subplot cells will be not be provided
            NoAlign = 16, -- subplot edges will not be aligned vertically or horizontally
            ShareItems = 32, -- items across all subplots will be shared and rendered into a single legend entry
            LinkRows = 64, -- link the y-axis limits of all plots in each row (does not apply to auxiliary axes)
            LinkCols = 128, -- link the x-axis limits of all plots in each column (does not apply to auxiliary axes)
            LinkAllX = 256, -- link the x-axis limits in every plot in the subplot (does not apply to auxiliary axes)
            LinkAllY = 512, -- link the y-axis limits in every plot in the subplot (does not apply to auxiliary axes)
            ColMajor = 1024, -- subplots are added in column major order instead of the default row major order
        }
        -- Options for legends (see SetupLegend)
        ImPlot.ImPlotLegendFlags = {
            None = 0, -- default
            NoButtons = 1, -- legend icons will not function as hide/show buttons
            NoHighlightItem = 2, -- plot items will not be highlighted when their legend entry is hovered
            NoHighlightAxis = 4, -- axes will not be highlighted when legend entries are hovered (only relevant if x/y-axis count > 1)
            NoMenus = 8, -- the user will not be able to open context menus with right-click
            Outside = 16, -- legend will be rendered outside of the plot area
            Horizontal = 32, -- legend entries will be displayed horizontally
            Sort = 64, -- legend entries will be displayed in alphabetical order
            Reverse = 128, -- legend entries will be displayed in reverse order
        }
        -- Options for mouse hover text (see SetupMouseText)
        ImPlot.ImPlotMouseTextFlags = {
            None = 0, -- default
            NoAuxAxes = 1, -- only show the mouse position for primary axes
            NoFormat = 2, -- axes label formatters won't be used to render text
            ShowAlways = 4, -- always display mouse position even if plot not hovered
        }
        -- Options for DragPoint, DragLine, DragRect
        ImPlot.ImPlotDragToolFlags = {
            None = 0, -- default
            NoCursors = 1, -- drag tools won't change cursor icons when hovered or held
            NoFit = 2, -- the drag tool won't be considered for plot fits
            NoInputs = 4, -- lock the tool from user inputs
            Delayed = 8, -- tool rendering will be delayed one frame; useful when applying position-constraints
        }
        -- Flags for ColormapScale
        ImPlot.ImPlotColormapScaleFlags = {
            None = 0, -- default
            NoLabel = 1, -- the colormap axis label will not be displayed
            Opposite = 2, -- render the colormap label and tick labels on the opposite side
            Invert = 4, -- invert the colormap bar and axis scale (this only affects rendering; if you only want to reverse the scale mapping, make scale_min > scale_max)
        }
        -- Flags for ANY PlotX function. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotItemFlags = {
            None = 0,
            NoLegend = 1, -- the item won't have a legend entry displayed
            NoFit = 2, -- the item won't be considered for plot fits
        }
        -- Flags for PlotLine. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotLineFlags = {
            None = 0, -- default
            Segments = 1024, -- a line segment will be rendered from every two consecutive points
            Loop = 2048, -- the last and first point will be connected to form a closed loop
            SkipNaN = 4096, -- NaNs values will be skipped instead of rendered as missing data
            NoClip = 8192, -- markers (if displayed) on the edge of a plot will not be clipped
            Shaded = 16384, -- a filled region between the line and horizontal origin will be rendered; use PlotShaded for more advanced cases
        }
        -- Flags for PlotScatter. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotScatterFlags = {
            None = 0, -- default
            NoClip = 1024, -- markers on the edge of a plot will not be clipped
        }
        -- Flags for PlotBubbles. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotBubblesFlags = {
            None = 0, -- default
        }
        -- Flags for PlotPolygon. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotPolygonFlags = {
            None = 0, -- default (closed, convex polygon)
            Concave = 1024, -- use concave polygon filling (slower but supports concave shapes)
        }
        -- Flags for PlotStairs. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotStairsFlags = {
            None = 0, -- default
            PreStep = 1024, -- the y value is continued constantly to the left from every x position, i.e. the interval (x[i-1], x[i]] has the value y[i]
            Shaded = 2048, -- a filled region between the stairs and horizontal origin will be rendered; use PlotShaded for more advanced cases
        }
        -- Flags for PlotShaded (placeholder). Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotShadedFlags = {
            None = 0, -- default
        }
        -- Flags for PlotBars. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotBarsFlags = {
            None = 0, -- default
            Horizontal = 1024, -- bars will be rendered horizontally on the current y-axis
        }
        -- Flags for PlotBarGroups. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotBarGroupsFlags = {
            None = 0, -- default
            Horizontal = 1024, -- bar groups will be rendered horizontally on the current y-axis
            Stacked = 2048, -- items in a group will be stacked on top of each other
        }
        -- Flags for PlotErrorBars. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotErrorBarsFlags = {
            None = 0, -- default
            Horizontal = 1024, -- error bars will be rendered horizontally on the current y-axis
        }
        -- Flags for PlotStems. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotStemsFlags = {
            None = 0, -- default
            Horizontal = 1024, -- stems will be rendered horizontally on the current y-axis
        }
        -- Flags for PlotInfLines. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotInfLinesFlags = {
            None = 0, -- default
            Horizontal = 1024, -- lines will be rendered horizontally on the current y-axis
        }
        -- Flags for PlotPieChart. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotPieChartFlags = {
            None = 0, -- default
            Normalize = 1024, -- force normalization of pie chart values (i.e. always make a full circle if sum < 0)
            IgnoreHidden = 2048, -- ignore hidden slices when drawing the pie chart (as if they were not there)
            Exploding = 4096, -- explode legend-hovered slice
            NoSliceBorder = 8192, -- do not draw slice borders
        }
        -- Flags for PlotHeatmap. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotHeatmapFlags = {
            None = 0, -- default
            ColMajor = 1024, -- data will be read in column major order
        }
        -- Flags for PlotHistogram and PlotHistogram2D. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotHistogramFlags = {
            None = 0, -- default
            Horizontal = 1024, -- histogram bars will be rendered horizontally (not supported by PlotHistogram2D)
            Cumulative = 2048, -- each bin will contain its count plus the counts of all previous bins (not supported by PlotHistogram2D)
            Density = 4096, -- counts will be normalized, i.e. the PDF will be visualized, or the CDF will be visualized if Cumulative is also set
            NoOutliers = 8192, -- exclude values outside the specified histogram range from the count toward normalizing and cumulative counts
            ColMajor = 16384, -- data will be read in column major order (not supported by PlotHistogram)
        }
        -- Flags for PlotDigital (placeholder). Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotDigitalFlags = {
            None = 0, -- default
        }
        -- Flags for PlotImage (placeholder). Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotImageFlags = {
            None = 0, -- default
        }
        -- Flags for PlotText. Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotTextFlags = {
            None = 0, -- default
            Vertical = 1024, -- text will be rendered vertically
        }
        -- Flags for PlotDummy (placeholder). Used by setting ImPlotSpec::Flags.
        ImPlot.ImPlotDummyFlags = {
            None = 0, -- default
        }
        -- Represents a condition for SetupAxisLimits etc. (same as ImGuiCond, but we only support a subset of those enums)
        ImPlot.ImPlotCond = {
            None = G.ImGuiCond.None, -- No condition (always set the variable), same as _Always
            Always = G.ImGuiCond.Always, -- No condition (always set the variable)
            Once = G.ImGuiCond.Once, -- Set the variable once per runtime session (only the first call will succeed)
        }
        -- Plot styling colors.
        ImPlot.ImPlotCol = {
            FrameBg = 0, -- plot frame background color (defaults to ImGuiCol_FrameBg)
            PlotBg = 1, -- plot area background color (defaults to ImGuiCol_WindowBg)
            PlotBorder = 2, -- plot area border color (defaults to ImGuiCol_Border)
            LegendBg = 3, -- legend background color (defaults to ImGuiCol_PopupBg)
            LegendBorder = 4, -- legend border color (defaults to ImPlotCol_PlotBorder)
            LegendText = 5, -- legend text color (defaults to ImPlotCol_InlayText)
            TitleText = 6, -- plot title text color (defaults to ImGuiCol_Text)
            InlayText = 7, -- color of text appearing inside of plots (defaults to ImGuiCol_Text)
            AxisText = 8, -- axis label and tick labels color (defaults to ImGuiCol_Text)
            AxisGrid = 9, -- axis grid color (defaults to 25% ImPlotCol_AxisText)
            AxisTick = 10, -- axis tick color (defaults to AxisGrid)
            AxisBg = 11, -- background color of axis hover region (defaults to transparent)
            AxisBgHovered = 12, -- axis hover color (defaults to ImGuiCol_ButtonHovered)
            AxisBgActive = 13, -- axis active color (defaults to ImGuiCol_ButtonActive)
            Selection = 14, -- box-selection color (defaults to yellow)
            Crosshairs = 15, -- crosshairs color (defaults to ImPlotCol_PlotBorder)
            COUNT = 16,
        }
        -- Plot styling variables.
        ImPlot.ImPlotStyleVar = {
            PlotDefaultSize = 0, -- ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            PlotMinSize = 1, -- ImVec2, minimum size plot frame can be when shrunk
            PlotBorderSize = 2, -- float,  thickness of border around plot area
            MinorAlpha = 3, -- float,  alpha multiplier applied to minor axis grid lines
            MajorTickLen = 4, -- ImVec2, major tick lengths for X and Y axes
            MinorTickLen = 5, -- ImVec2, minor tick lengths for X and Y axes
            MajorTickSize = 6, -- ImVec2, line thickness of major ticks
            MinorTickSize = 7, -- ImVec2, line thickness of minor ticks
            MajorGridSize = 8, -- ImVec2, line thickness of major grid lines
            MinorGridSize = 9, -- ImVec2, line thickness of minor grid lines
            PlotPadding = 10, -- ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            LabelPadding = 11, -- ImVec2, padding between axes labels, tick labels, and plot edge
            LegendPadding = 12, -- ImVec2, legend padding from plot edges
            LegendInnerPadding = 13, -- ImVec2, legend inner padding from legend edges
            LegendSpacing = 14, -- ImVec2, spacing between legend entries
            MousePosPadding = 15, -- ImVec2, padding between plot edge and interior info text
            AnnotationPadding = 16, -- ImVec2, text padding around annotation labels
            FitPadding = 17, -- ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
            DigitalPadding = 18, -- float,  digital plot padding from bottom in pixels
            DigitalSpacing = 19, -- float,  digital plot spacing gap in pixels
            COUNT = 20,
        }
        -- Axis scale
        ImPlot.ImPlotScale = {
            Linear = 0, -- default linear scale
            Time = 1, -- date/time scale
            Log10 = 2, -- base 10 logarithmic scale
            SymLog = 3, -- symmetric log scale
        }
        -- Marker specifications.
        ImPlot.ImPlotMarker = {
            None = -2, -- no marker
            Auto = -1, -- automatic marker selection
            Circle = 0, -- a circle marker (default)
            Square = 1, -- a square maker
            Diamond = 2, -- a diamond marker
            Up = 3, -- an upward-pointing triangle marker
            Down = 4, -- an downward-pointing triangle marker
            Left = 5, -- an leftward-pointing triangle marker
            Right = 6, -- an rightward-pointing triangle marker
            Cross = 7, -- a cross marker (not fill-able)
            Plus = 8, -- a plus marker (not fill-able)
            Asterisk = 9, -- a asterisk marker (not fill-able)
            Vertical = 10, -- a vertical line marker (not fill-able)
            Horizontal = 11, -- a horizontal line marker (not fill-able)
            COUNT = 12,
        }
        -- Built-in colormaps
        ImPlot.ImPlotColormap = {
            Deep = 0, -- a.k.a. seaborn deep             (qual=true,  n=10) (default)
            Dark = 1, -- a.k.a. matplotlib "Set1"        (qual=true,  n=9 )
            Pastel = 2, -- a.k.a. matplotlib "Pastel1"     (qual=true,  n=9 )
            Paired = 3, -- a.k.a. matplotlib "Paired"      (qual=true,  n=12)
            Viridis = 4, -- a.k.a. matplotlib "viridis"     (qual=false, n=11)
            Plasma = 5, -- a.k.a. matplotlib "plasma"      (qual=false, n=11)
            Hot = 6, -- a.k.a. matplotlib/MATLAB "hot"  (qual=false, n=11)
            Cool = 7, -- a.k.a. matplotlib/MATLAB "cool" (qual=false, n=11)
            Pink = 8, -- a.k.a. matplotlib/MATLAB "pink" (qual=false, n=11)
            Jet = 9, -- a.k.a. MATLAB "jet"             (qual=false, n=11)
            Twilight = 10, -- a.k.a. matplotlib "twilight"    (qual=false, n=11)
            RdBu = 11, -- red/blue, Color Brewer          (qual=false, n=11)
            BrBG = 12, -- brown/blue-green, Color Brewer  (qual=false, n=11)
            PiYG = 13, -- pink/yellow-green, Color Brewer (qual=false, n=11)
            Spectral = 14, -- color spectrum, Color Brewer    (qual=false, n=11)
            Greys = 15, -- white/black                     (qual=false, n=2 )
        }
        -- Used to position items on a plot (e.g. legends, labels, etc.)
        ImPlot.ImPlotLocation = {
            Center = 0, -- center-center
            North = 1, -- top-center
            South = 2, -- bottom-center
            West = 4, -- center-left
            East = 8, -- center-right
            NorthWest = 5, -- top-left
            NorthEast = 9, -- top-right
            SouthWest = 6, -- bottom-left
            SouthEast = 10, -- bottom-right
        }
        -- Enums for different automatic histogram binning methods (k = bin count or w = bin width)
        ImPlot.ImPlotBin = {
            Sqrt = -1, -- k = sqrt(n)
            Sturges = -2, -- k = 1 + log2(n)
            Rice = -3, -- k = 2 * cbrt(n)
            Scott = -4, -- w = 3.49 * sigma / cbrt(n)
        }
    end

    local ImPlotCol = ImPlot.ImPlotCol
    local ImPlotStyleVar = ImPlot.ImPlotStyleVar
    local ImGuiCol = G.ImGuiCol

    --------------------------------------------------------------------------
    -- [SECTION] Structs: ImPlotPoint, ImPlotRange, ImPlotRect (implot.h)
    --------------------------------------------------------------------------
    do
        -- Double precision version of ImVec2 used by ImPlot. Extensible by end users.
        local PointMT = {}
        PointMT.__index = function(self, k)
            -- [Port] operator[]: 0 -> x, 1 -> y
            if k == 0 then return rawget(self, "x") end
            if k == 1 then return rawget(self, "y") end
            return nil
        end
        function ImPlot.ImPlotPoint(x, y)
            -- [Port] ImPlotPoint(const ImVec2& p) overload: pass a table with .x/.y
            if type(x) == "table" then
                return setmetatable({ x = x.x, y = x.y }, PointMT)
            end
            return setmetatable({ x = x or 0.0, y = y or 0.0 }, PointMT)
        end
        local ImPlotPoint = ImPlot.ImPlotPoint

        -- Range defined by a min/max value.
        local RangeMT = {}
        RangeMT.__index = RangeMT
        function ImPlot.ImPlotRange(min, max)
            return setmetatable({ Min = min or 0.0, Max = max or 0.0 }, RangeMT)
        end
        function RangeMT:Contains(value) return value >= self.Min and value <= self.Max end
        function RangeMT:Size() return self.Max - self.Min end
        function RangeMT:Clamp(value)
            if value < self.Min then return self.Min end
            if value > self.Max then return self.Max end
            return value
        end

        -- Combination of two range limits for X and Y axes. Also an AABB defined by Min()/Max().
        local RectMT = {}
        RectMT.__index = RectMT
        function ImPlot.ImPlotRect(x_min, x_max, y_min, y_max)
            return setmetatable({ X = ImPlot.ImPlotRange(x_min, x_max), Y = ImPlot.ImPlotRange(y_min, y_max) }, RectMT)
        end
        -- [Port] Contains(p) / Contains(x, y) overloads
        function RectMT:Contains(x, y)
            if type(x) == "table" then x, y = x.x, x.y end
            return self.X:Contains(x) and self.Y:Contains(y)
        end
        function RectMT:Size() return ImPlotPoint(self.X:Size(), self.Y:Size()) end
        function RectMT:Clamp(x, y)
            if type(x) == "table" then x, y = x.x, x.y end
            return ImPlotPoint(self.X:Clamp(x), self.Y:Clamp(y))
        end
        function RectMT:Min() return ImPlotPoint(self.X.Min, self.Y.Min) end
        function RectMT:Max() return ImPlotPoint(self.X.Max, self.Y.Max) end
    end

    --------------------------------------------------------------------------
    -- [SECTION] ImPlotStyle (implot.h / implot.cpp Struct Implementations)
    --------------------------------------------------------------------------
    do
        -- Plot style structure
        function ImPlot.ImPlotStyle()
            local s = {}
            s.PlotDefaultSize    = ImVec2(400,300)
            s.PlotMinSize        = ImVec2(200,150)
            s.PlotBorderSize     = 1
            s.MinorAlpha         = 0.25
            s.MajorTickLen       = ImVec2(10,10)
            s.MinorTickLen       = ImVec2(5,5)
            s.MajorTickSize      = ImVec2(1,1)
            s.MinorTickSize      = ImVec2(1,1)
            s.MajorGridSize      = ImVec2(1,1)
            s.MinorGridSize      = ImVec2(1,1)
            s.PlotPadding        = ImVec2(10,10)
            s.LabelPadding       = ImVec2(5,5)
            s.LegendPadding      = ImVec2(10,10)
            s.LegendInnerPadding = ImVec2(5,5)
            s.LegendSpacing      = ImVec2(5,0)
            s.MousePosPadding    = ImVec2(10,10)
            s.AnnotationPadding  = ImVec2(2,2)
            s.FitPadding         = ImVec2(0,0)
            s.DigitalPadding     = 20
            s.DigitalSpacing     = 4

            -- [Port] Colors is keyed by 0-based ImPlotCol values: Colors[ImPlotCol.FrameBg]
            s.Colors = {}
            ImPlot.StyleColorsAuto(s)

            s.Colormap = ImPlot.ImPlotColormap.Deep

            s.UseLocalTime     = false
            s.Use24HourClock   = false
            s.UseISO8601       = false
            return s
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Style
    --------------------------------------------------------------------------
    do
        local col_names = {
            "FrameBg",
            "PlotBg",
            "PlotBorder",
            "LegendBg",
            "LegendBorder",
            "LegendText",
            "TitleText",
            "InlayText",
            "AxisText",
            "AxisGrid",
            "AxisTick",
            "AxisBg",
            "AxisBgHovered",
            "AxisBgActive",
            "Selection",
            "Crosshairs"
        }
        function ImPlot.GetStyleColorName(col)
            return col_names[col + 1] -- [Port] 0-based col
        end

        function internal.IsColorAuto(col)
            -- [Port] IsColorAuto(ImVec4) / IsColorAuto(ImPlotCol) overloads
            if type(col) == "number" then col = GImPlot.Style.Colors[col] end
            return col.w == -1
        end

        function internal.GetAutoColor(idx)
            local GetStyleColorVec4 = internal.GetStyleColorVec4
            if idx == ImPlotCol.FrameBg then return ImGui.GetStyleColorVec4(ImGuiCol.FrameBg) end
            if idx == ImPlotCol.PlotBg then return ImGui.GetStyleColorVec4(ImGuiCol.WindowBg) end
            if idx == ImPlotCol.PlotBorder then return ImGui.GetStyleColorVec4(ImGuiCol.Border) end
            if idx == ImPlotCol.LegendBg then return ImGui.GetStyleColorVec4(ImGuiCol.PopupBg) end
            if idx == ImPlotCol.LegendBorder then return GetStyleColorVec4(ImPlotCol.PlotBorder) end
            if idx == ImPlotCol.LegendText then return GetStyleColorVec4(ImPlotCol.InlayText) end
            if idx == ImPlotCol.TitleText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlotCol.InlayText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlotCol.AxisText then return ImGui.GetStyleColorVec4(ImGuiCol.Text) end
            if idx == ImPlotCol.AxisGrid then
                local c = GetStyleColorVec4(ImPlotCol.AxisText)
                return ImVec4(c.x, c.y, c.z, c.w * 0.25)
            end
            if idx == ImPlotCol.AxisTick then return GetStyleColorVec4(ImPlotCol.AxisGrid) end
            if idx == ImPlotCol.AxisBg then return ImVec4(0,0,0,0) end
            if idx == ImPlotCol.AxisBgHovered then return ImGui.GetStyleColorVec4(ImGuiCol.ButtonHovered) end
            if idx == ImPlotCol.AxisBgActive then return ImGui.GetStyleColorVec4(ImGuiCol.ButtonActive) end
            if idx == ImPlotCol.Selection then return ImVec4(1,1,0,1) end
            if idx == ImPlotCol.Crosshairs then return GetStyleColorVec4(ImPlotCol.PlotBorder) end
            return ImVec4(0,0,0,1)
        end

        -- Get styling colors (resolves IMPLOT_AUTO_COL)
        function internal.GetStyleColorVec4(idx)
            if internal.IsColorAuto(idx) then return internal.GetAutoColor(idx) end
            local c = GImPlot.Style.Colors[idx]
            return ImVec4(c.x, c.y, c.z, c.w) -- [Port] by-value copy
        end
        function internal.GetStyleColorU32(idx)
            return ImGui.ColorConvertFloat4ToU32(internal.GetStyleColorVec4(idx))
        end
        ImPlot.GetStyleColorVec4 = internal.GetStyleColorVec4
        ImPlot.GetStyleColorU32 = internal.GetStyleColorU32

        -- [Port] ImPlotStyleVarInfo: { Count, Field } (Type is always ImGuiDataType_Float), keyed by 0-based ImPlotStyleVar
        local GPlotStyleVarInfo = {
            [ImPlotStyleVar.PlotDefaultSize]    = { Count = 2, Field = "PlotDefaultSize" },
            [ImPlotStyleVar.PlotMinSize]        = { Count = 2, Field = "PlotMinSize" },
            [ImPlotStyleVar.PlotBorderSize]     = { Count = 1, Field = "PlotBorderSize" },
            [ImPlotStyleVar.MinorAlpha]         = { Count = 1, Field = "MinorAlpha" },
            [ImPlotStyleVar.MajorTickLen]       = { Count = 2, Field = "MajorTickLen" },
            [ImPlotStyleVar.MinorTickLen]       = { Count = 2, Field = "MinorTickLen" },
            [ImPlotStyleVar.MajorTickSize]      = { Count = 2, Field = "MajorTickSize" },
            [ImPlotStyleVar.MinorTickSize]      = { Count = 2, Field = "MinorTickSize" },
            [ImPlotStyleVar.MajorGridSize]      = { Count = 2, Field = "MajorGridSize" },
            [ImPlotStyleVar.MinorGridSize]      = { Count = 2, Field = "MinorGridSize" },
            [ImPlotStyleVar.PlotPadding]        = { Count = 2, Field = "PlotPadding" },
            [ImPlotStyleVar.LabelPadding]       = { Count = 2, Field = "LabelPadding" },
            [ImPlotStyleVar.LegendPadding]      = { Count = 2, Field = "LegendPadding" },
            [ImPlotStyleVar.LegendInnerPadding] = { Count = 2, Field = "LegendInnerPadding" },
            [ImPlotStyleVar.LegendSpacing]      = { Count = 2, Field = "LegendSpacing" },
            [ImPlotStyleVar.MousePosPadding]    = { Count = 2, Field = "MousePosPadding" },
            [ImPlotStyleVar.AnnotationPadding]  = { Count = 2, Field = "AnnotationPadding" },
            [ImPlotStyleVar.FitPadding]         = { Count = 2, Field = "FitPadding" },
            [ImPlotStyleVar.DigitalPadding]     = { Count = 1, Field = "DigitalPadding" },
            [ImPlotStyleVar.DigitalSpacing]     = { Count = 1, Field = "DigitalSpacing" },
        }
        local function GetPlotStyleVarInfo(idx)
            IM_ASSERT(idx >= 0 and idx < ImPlotStyleVar.COUNT)
            return GPlotStyleVarInfo[idx]
        end

        function ImPlot.GetStyle()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            return GImPlot.Style
        end

        -- [Port] PushStyleColor(idx, ImU32) / PushStyleColor(idx, ImVec4) overloads
        function ImPlot.PushStyleColor(idx, col)
            local gp = GImPlot
            local b = gp.Style.Colors[idx]
            table.insert(gp.ColorModifiers, { Col = idx, BackupValue = ImVec4(b.x, b.y, b.z, b.w) })
            if type(col) == "number" then
                gp.Style.Colors[idx] = ImGui.ColorConvertU32ToFloat4(col)
            else
                gp.Style.Colors[idx] = ImVec4(col.x, col.y, col.z, col.w)
            end
        end

        function ImPlot.PopStyleColor(count)
            if count == nil then count = 1 end
            local gp = GImPlot
            IM_ASSERT(count <= #gp.ColorModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                local backup = table.remove(gp.ColorModifiers)
                gp.Style.Colors[backup.Col] = backup.BackupValue
                count = count - 1
            end
        end

        -- [Port] float/int/ImVec2 overloads merged: number -> Count 1, table -> Count 2
        function ImPlot.PushStyleVar(idx, val)
            local gp = GImPlot
            local var_info = GetPlotStyleVarInfo(idx)
            if type(val) == "number" then
                if var_info.Count == 1 then
                    table.insert(gp.StyleModifiers, { VarIdx = idx, BackupFloat = { gp.Style[var_info.Field] } })
                    gp.Style[var_info.Field] = val
                    return
                end
                IM_ASSERT(false, "Called PushStyleVar() float variant but variable is not a float!")
            else
                if var_info.Count == 2 then
                    local p = gp.Style[var_info.Field]
                    table.insert(gp.StyleModifiers, { VarIdx = idx, BackupFloat = { p.x, p.y } })
                    gp.Style[var_info.Field] = ImVec2(val.x, val.y)
                    return
                end
                IM_ASSERT(false, "Called PushStyleVar() ImVec2 variant but variable is not a ImVec2!")
            end
        end

        function ImPlot.PopStyleVar(count)
            if count == nil then count = 1 end
            local gp = GImPlot
            IM_ASSERT(count <= #gp.StyleModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                local backup = table.remove(gp.StyleModifiers)
                local info = GetPlotStyleVarInfo(backup.VarIdx)
                if info.Count == 1 then
                    gp.Style[info.Field] = backup.BackupFloat[1]
                else
                    gp.Style[info.Field] = ImVec2(backup.BackupFloat[1], backup.BackupFloat[2])
                end
                count = count - 1
            end
        end

        -- [Port] C++ `dst ? dst : &GetStyle()`
        local function StyleOrCurrent(dst)
            if dst then return dst end
            return ImPlot.GetStyle()
        end

        function ImPlot.StyleColorsAuto(dst)
            local style                     = StyleOrCurrent(dst)
            local colors                    = style.Colors

            style.MinorAlpha                = 0.25

            colors[ImPlotCol.FrameBg]       = IMPLOT_AUTO_COL()
            colors[ImPlotCol.PlotBg]        = IMPLOT_AUTO_COL()
            colors[ImPlotCol.PlotBorder]    = IMPLOT_AUTO_COL()
            colors[ImPlotCol.LegendBg]      = IMPLOT_AUTO_COL()
            colors[ImPlotCol.LegendBorder]  = IMPLOT_AUTO_COL()
            colors[ImPlotCol.LegendText]    = IMPLOT_AUTO_COL()
            colors[ImPlotCol.TitleText]     = IMPLOT_AUTO_COL()
            colors[ImPlotCol.InlayText]     = IMPLOT_AUTO_COL()
            colors[ImPlotCol.PlotBorder]    = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisText]      = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisGrid]      = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisTick]      = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisBg]        = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisBgHovered] = IMPLOT_AUTO_COL()
            colors[ImPlotCol.AxisBgActive]  = IMPLOT_AUTO_COL()
            colors[ImPlotCol.Selection]     = IMPLOT_AUTO_COL()
            colors[ImPlotCol.Crosshairs]    = IMPLOT_AUTO_COL()
        end

        function ImPlot.StyleColorsClassic(dst)
            local style                     = StyleOrCurrent(dst)
            local colors                    = style.Colors

            style.MinorAlpha                = 0.5

            colors[ImPlotCol.FrameBg]       = ImVec4(0.43, 0.43, 0.43, 0.39)
            colors[ImPlotCol.PlotBg]        = ImVec4(0.00, 0.00, 0.00, 0.35)
            colors[ImPlotCol.PlotBorder]    = ImVec4(0.50, 0.50, 0.50, 0.50)
            colors[ImPlotCol.LegendBg]      = ImVec4(0.11, 0.11, 0.14, 0.92)
            colors[ImPlotCol.LegendBorder]  = ImVec4(0.50, 0.50, 0.50, 0.50)
            colors[ImPlotCol.LegendText]    = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlotCol.TitleText]     = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlotCol.InlayText]     = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlotCol.AxisText]      = ImVec4(0.90, 0.90, 0.90, 1.00)
            colors[ImPlotCol.AxisGrid]      = ImVec4(0.90, 0.90, 0.90, 0.25)
            colors[ImPlotCol.AxisTick]      = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBg]        = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgHovered] = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgActive]  = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.Selection]     = ImVec4(0.97, 0.97, 0.39, 1.00)
            colors[ImPlotCol.Crosshairs]    = ImVec4(0.50, 0.50, 0.50, 0.75)
        end

        function ImPlot.StyleColorsDark(dst)
            local style                     = StyleOrCurrent(dst)
            local colors                    = style.Colors

            style.MinorAlpha                = 0.25

            colors[ImPlotCol.FrameBg]       = ImVec4(1.00, 1.00, 1.00, 0.07)
            colors[ImPlotCol.PlotBg]        = ImVec4(0.00, 0.00, 0.00, 0.50)
            colors[ImPlotCol.PlotBorder]    = ImVec4(0.43, 0.43, 0.50, 0.50)
            colors[ImPlotCol.LegendBg]      = ImVec4(0.08, 0.08, 0.08, 0.94)
            colors[ImPlotCol.LegendBorder]  = ImVec4(0.43, 0.43, 0.50, 0.50)
            colors[ImPlotCol.LegendText]    = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.TitleText]     = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.InlayText]     = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.AxisText]      = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.AxisGrid]      = ImVec4(1.00, 1.00, 1.00, 0.25)
            colors[ImPlotCol.AxisTick]      = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBg]        = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgHovered] = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgActive]  = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.Selection]     = ImVec4(1.00, 0.60, 0.00, 1.00)
            colors[ImPlotCol.Crosshairs]    = ImVec4(1.00, 1.00, 1.00, 0.50)
        end

        function ImPlot.StyleColorsLight(dst)
            local style                     = StyleOrCurrent(dst)
            local colors                    = style.Colors

            style.MinorAlpha                = 1.0

            colors[ImPlotCol.FrameBg]       = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.PlotBg]        = ImVec4(0.42, 0.57, 1.00, 0.13)
            colors[ImPlotCol.PlotBorder]    = ImVec4(0.00, 0.00, 0.00, 0.00)
            colors[ImPlotCol.LegendBg]      = ImVec4(1.00, 1.00, 1.00, 0.98)
            colors[ImPlotCol.LegendBorder]  = ImVec4(0.82, 0.82, 0.82, 0.80)
            colors[ImPlotCol.LegendText]    = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlotCol.TitleText]     = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlotCol.InlayText]     = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlotCol.AxisText]      = ImVec4(0.00, 0.00, 0.00, 1.00)
            colors[ImPlotCol.AxisGrid]      = ImVec4(1.00, 1.00, 1.00, 1.00)
            colors[ImPlotCol.AxisTick]      = ImVec4(0.00, 0.00, 0.00, 0.25)
            colors[ImPlotCol.AxisBg]        = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgHovered] = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.AxisBgActive]  = IMPLOT_AUTO_COL() -- TODO
            colors[ImPlotCol.Selection]     = ImVec4(0.82, 0.64, 0.03, 1.00)
            colors[ImPlotCol.Crosshairs]    = ImVec4(0.00, 0.00, 0.00, 0.50)
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Colormap data storage (implot_internal.h ImPlotColormapData)
    -- [Port] ImVectors -> 1-based Lua arrays; offsets/indices stay 0-based values (array[off + idx + 1]).
    -- [Port] Text/TextOffsets -> Names[cmap + 1]; ImGuiStorage Map keyed by ImHashStr -> Lua table keyed by name.
    --------------------------------------------------------------------------
    do
        local band, bor, rshift = bit32.band, bit32.bor, bit32.rshift

        -- Mix color a and b by factor s in [0 256]
        local function ImMixU32(a, b, s)
            local af = 256 - s
            local bf = s
            local al = band(a, 0x00ff00ff)
            local ah = rshift(band(a, 0xff00ff00), 8)
            local bl = band(b, 0x00ff00ff)
            local bh = rshift(band(b, 0xff00ff00), 8)
            local ml = al * af + bl * bf
            local mh = ah * af + bh * bf
            return bor(band(mh, 0xff00ff00), rshift(band(ml, 0xff00ff00), 8))
        end
        internal.ImMixU32 = ImMixU32

        local CM = {}
        CM.__index = CM

        function internal.ImPlotColormapData()
            return setmetatable({
                Keys = {}, KeyCounts = {}, KeyOffsets = {},
                Tables = {}, TableSizes = {}, TableOffsets = {},
                Names = {}, Quals = {}, Map = {}, Count = 0,
            }, CM)
        end

        function CM:Append(name, keys, count, qual)
            if self:GetIndex(name) ~= -1 then
                return -1
            end
            table.insert(self.KeyOffsets, #self.Keys)
            table.insert(self.KeyCounts, count)
            for i = 1, count do
                table.insert(self.Keys, keys[i])
            end
            table.insert(self.Names, name)
            table.insert(self.Quals, qual)
            local idx = self.Count
            self.Count = self.Count + 1
            self.Map[name] = idx
            self:_AppendTable(idx)
            return idx
        end

        function CM:_AppendTable(cmap)
            local key_count = self:GetKeyCount(cmap)
            local koff = self.KeyOffsets[cmap + 1]
            local keys = self.Keys
            local tables = self.Tables
            local off = #tables
            table.insert(self.TableOffsets, off)
            if self:IsQual(cmap) then
                for i = 0, key_count - 1 do
                    table.insert(tables, keys[koff + i + 1])
                end
                table.insert(self.TableSizes, key_count)
            else
                local max_size = 255 * (key_count-1) + 1
                for i = 0, key_count - 2 do
                    for s = 0, 254 do
                        local a = keys[koff + i + 1]
                        local b = keys[koff + i + 2]
                        table.insert(tables, ImMixU32(a, b, s))
                    end
                end
                table.insert(tables, keys[koff + key_count])
                table.insert(self.TableSizes, max_size)
            end
        end

        function CM:RebuildTables()
            table.clear(self.Tables)
            table.clear(self.TableSizes)
            table.clear(self.TableOffsets)
            for i = 0, self.Count - 1 do
                self:_AppendTable(i)
            end
        end

        function CM:IsQual(cmap) return self.Quals[cmap + 1] end
        function CM:GetName(cmap)
            if cmap < self.Count then return self.Names[cmap + 1] end
            return nil
        end
        function CM:GetIndex(name)
            local v = self.Map[name]
            if v == nil then return -1 end
            return v
        end

        -- [Port] GetKeys/GetTable return (array, 0-based offset) instead of a pointer
        function CM:GetKeys(cmap) return self.Keys, self.KeyOffsets[cmap + 1] end
        function CM:GetKeyCount(cmap) return self.KeyCounts[cmap + 1] end
        function CM:GetKeyColor(cmap, idx) return self.Keys[self.KeyOffsets[cmap + 1] + idx + 1] end
        function CM:SetKeyColor(cmap, idx, value)
            self.Keys[self.KeyOffsets[cmap + 1] + idx + 1] = value
            self:RebuildTables()
        end

        function CM:GetTable(cmap) return self.Tables, self.TableOffsets[cmap + 1] end
        function CM:GetTableSize(cmap) return self.TableSizes[cmap + 1] end
        function CM:GetTableColor(cmap, idx) return self.Tables[self.TableOffsets[cmap + 1] + idx + 1] end

        function CM:LerpTable(cmap, t)
            local off = self.TableOffsets[cmap + 1]
            local siz = self.TableSizes[cmap + 1]
            local idx
            if self.Quals[cmap + 1] then
                idx = G.ImClamp(math.floor(siz * t), 0, siz - 1)
            else
                idx = math.floor((siz - 1) * t + 0.5)
            end
            return self.Tables[off + idx + 1]
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Context Utils
    --------------------------------------------------------------------------
    do
        -- Holds state information that must persist between calls to BeginPlot()/EndPlot()
        -- [Port] only Style and Colormap fields so far; later milestones add the rest.
        function internal.ImPlotContext()
            return {
                CurrentPlot = nil,
                CurrentSubplot = nil,
                CurrentItems = nil,
                CurrentItem = nil,
                PreviousItem = nil,
                -- Style and Colormaps
                Style = ImPlot.ImPlotStyle(),
                ColorModifiers = {},
                StyleModifiers = {},
                ColormapData = internal.ImPlotColormapData(),
                ColormapModifiers = {},
            }
        end

        function ImPlot.CreateContext()
            local ctx = internal.ImPlotContext()
            internal.Initialize(ctx)
            if GImPlot == nil then
                ImPlot.SetCurrentContext(ctx)
            end
            return ctx
        end

        function ImPlot.DestroyContext(ctx)
            if ctx == nil then
                ctx = GImPlot
            end
            if GImPlot == ctx then
                ImPlot.SetCurrentContext(nil)
            end
        end

        function ImPlot.GetCurrentContext()
            return GImPlot
        end

        function ImPlot.SetCurrentContext(ctx)
            GImPlot = ctx
        end

        local function IM_RGB(r, g, b) return IM_COL32(r, g, b, 255) end

        -- [Port] {name, qual, keys} in IMPLOT_APPEND_CMAP order
        local cmaps = {
            { "Deep",     true,  {IM_RGB(76,114,176),IM_RGB(221,132,82),IM_RGB(85,168,104),IM_RGB(196,78,82),IM_RGB(129,114,179),IM_RGB(147,120,96),IM_RGB(218,139,195),IM_RGB(140,140,140),IM_RGB(204,185,116),IM_RGB(100,181,205)} },
            { "Dark",     true,  {IM_RGB(228,26,28),IM_RGB(55,126,184),IM_RGB(77,175,74),IM_RGB(152,78,163),IM_RGB(255,127,0),IM_RGB(255,255,51),IM_RGB(166,86,40),IM_RGB(247,129,191),IM_RGB(153,153,153)} },
            { "Pastel",   true,  {IM_RGB(251,180,174),IM_RGB(179,205,227),IM_RGB(204,235,197),IM_RGB(222,203,228),IM_RGB(254,217,166),IM_RGB(255,255,204),IM_RGB(229,216,189),IM_RGB(253,218,236),IM_RGB(242,242,242)} },
            { "Paired",   true,  {IM_RGB(66,206,227),IM_RGB(31,120,180),IM_RGB(178,223,138),IM_RGB(51,160,44),IM_RGB(251,154,153),IM_RGB(227,26,28),IM_RGB(253,191,111),IM_RGB(255,127,0),IM_RGB(202,178,214),IM_RGB(106,61,154),IM_RGB(255,255,153),IM_RGB(177,89,40)} },
            { "Viridis",  false, {IM_RGB(68,1,84),IM_RGB(72,36,117),IM_RGB(65,68,135),IM_RGB(53,95,141),IM_RGB(42,120,142),IM_RGB(33,145,140),IM_RGB(34,168,132),IM_RGB(68,191,112),IM_RGB(122,209,81),IM_RGB(189,223,38),IM_RGB(253,231,37)} },
            { "Plasma",   false, {IM_RGB(13,8,135),IM_RGB(65,4,157),IM_RGB(106,0,168),IM_RGB(143,13,164),IM_RGB(177,42,144),IM_RGB(204,71,120),IM_RGB(225,100,98),IM_RGB(242,132,75),IM_RGB(252,166,54),IM_RGB(252,206,37),IM_RGB(240,249,33)} },
            { "Hot",      false, {IM_RGB(64,0,0),IM_RGB(128,0,0),IM_RGB(191,0,0),IM_RGB(255,0,0),IM_RGB(255,64,0),IM_RGB(255,128,0),IM_RGB(255,191,0),IM_RGB(255,255,0),IM_RGB(255,255,85),IM_RGB(255,255,170),IM_RGB(255,255,255)} },
            { "Cool",     false, {IM_RGB(0,255,255),IM_RGB(26,230,255),IM_RGB(51,204,255),IM_RGB(77,179,255),IM_RGB(102,153,255),IM_RGB(128,128,255),IM_RGB(153,102,255),IM_RGB(179,77,255),IM_RGB(204,51,255),IM_RGB(230,26,255),IM_RGB(255,0,255)} },
            { "Pink",     false, {IM_RGB(74,0,0),IM_RGB(123,66,66),IM_RGB(158,93,93),IM_RGB(186,114,114),IM_RGB(198,151,132),IM_RGB(208,180,147),IM_RGB(218,206,161),IM_RGB(228,228,174),IM_RGB(237,237,205),IM_RGB(246,246,231),IM_RGB(255,255,255)} },
            { "Jet",      false, {IM_RGB(0,0,170),IM_RGB(0,0,255),IM_RGB(0,85,255),IM_RGB(0,170,255),IM_RGB(0,255,255),IM_RGB(85,255,170),IM_RGB(170,255,85),IM_RGB(255,255,0),IM_RGB(255,170,0),IM_RGB(255,85,0),IM_RGB(255,0,0)} },
            { "Twilight", false, {IM_RGB(226,217,226),IM_RGB(166,191,202),IM_RGB(109,144,192),IM_RGB(95,88,176),IM_RGB(83,30,124),IM_RGB(47,20,54),IM_RGB(100,25,75),IM_RGB(159,60,80),IM_RGB(192,117,94),IM_RGB(208,179,158),IM_RGB(226,217,226)} },
            { "RdBu",     false, {IM_RGB(103,0,31),IM_RGB(178,24,43),IM_RGB(214,96,77),IM_RGB(244,165,130),IM_RGB(253,219,199),IM_RGB(247,247,247),IM_RGB(209,229,240),IM_RGB(146,197,222),IM_RGB(67,147,195),IM_RGB(33,102,172),IM_RGB(5,48,97)} },
            { "BrBG",     false, {IM_RGB(84,48,5),IM_RGB(140,81,10),IM_RGB(191,129,45),IM_RGB(223,194,125),IM_RGB(246,232,195),IM_RGB(245,245,245),IM_RGB(199,234,229),IM_RGB(128,205,193),IM_RGB(53,151,143),IM_RGB(1,102,94),IM_RGB(0,60,48)} },
            { "PiYG",     false, {IM_RGB(142,1,82),IM_RGB(197,27,125),IM_RGB(222,119,174),IM_RGB(241,182,218),IM_RGB(253,224,239),IM_RGB(247,247,247),IM_RGB(230,245,208),IM_RGB(184,225,134),IM_RGB(127,188,65),IM_RGB(77,146,33),IM_RGB(39,100,25)} },
            { "Spectral", false, {IM_RGB(158,1,66),IM_RGB(213,62,79),IM_RGB(244,109,67),IM_RGB(253,174,97),IM_RGB(254,224,139),IM_RGB(255,255,191),IM_RGB(230,245,152),IM_RGB(171,221,164),IM_RGB(102,194,165),IM_RGB(50,136,189),IM_RGB(94,79,162)} },
            { "Greys",    false, {G.IM_COL32_WHITE, G.IM_COL32_BLACK} },
        }

        function internal.Initialize(ctx)
            -- [Port] TODO: ResetCtxForNextPlot / ResetCtxForNextAlignedPlots / ResetCtxForNextSubplot (later milestone)
            for _, c in ipairs(cmaps) do
                ctx.ColormapData:Append(c[1], c[3], #c[3], c[2])
            end
        end
    end

    --------------------------------------------------------------------------
    -- [Section] Colormaps
    --------------------------------------------------------------------------
    do
        local IMPLOT_AUTO = ImPlot.IMPLOT_AUTO

        function ImPlot.GetColormapCount()
            return GImPlot.ColormapData.Count
        end

        function ImPlot.GetColormapName(colormap)
            return GImPlot.ColormapData:GetName(colormap)
        end

        function ImPlot.GetColormapIndex(name)
            return GImPlot.ColormapData:GetIndex(name)
        end

        -- [Port] PushColormap(ImPlotColormap) / PushColormap(const char*) overloads
        function ImPlot.PushColormap(colormap)
            local gp = GImPlot
            if type(colormap) == "string" then
                local idx = gp.ColormapData:GetIndex(colormap)
                IM_ASSERT(idx ~= -1, "The colormap name is invalid!")
                colormap = idx
            end
            IM_ASSERT(colormap >= 0 and colormap < gp.ColormapData.Count, "The colormap index is invalid!")
            table.insert(gp.ColormapModifiers, gp.Style.Colormap)
            gp.Style.Colormap = colormap
        end

        function ImPlot.PopColormap(count)
            if count == nil then count = 1 end
            local gp = GImPlot
            IM_ASSERT(count <= #gp.ColormapModifiers, "You can't pop more modifiers than have been pushed!")
            while count > 0 do
                gp.Style.Colormap = table.remove(gp.ColormapModifiers)
                count = count - 1
            end
        end

        function ImPlot.NextColormapColorU32()
            local gp = GImPlot
            IM_ASSERT(gp.CurrentItems ~= nil, "NextColormapColor() needs to be called between BeginPlot() and EndPlot()!")
            local idx = gp.CurrentItems.ColormapIdx % gp.ColormapData:GetKeyCount(gp.Style.Colormap)
            local col = gp.ColormapData:GetKeyColor(gp.Style.Colormap, idx)
            gp.CurrentItems.ColormapIdx = gp.CurrentItems.ColormapIdx + 1
            return col
        end

        function ImPlot.NextColormapColor()
            return ImGui.ColorConvertU32ToFloat4(ImPlot.NextColormapColorU32())
        end

        local function ResolveCmap(gp, cmap)
            if cmap == nil or cmap == IMPLOT_AUTO then cmap = gp.Style.Colormap end
            IM_ASSERT(cmap >= 0 and cmap < gp.ColormapData.Count, "Invalid colormap index!")
            return cmap
        end

        function ImPlot.GetColormapSize(cmap)
            local gp = GImPlot
            cmap = ResolveCmap(gp, cmap)
            return gp.ColormapData:GetKeyCount(cmap)
        end

        function ImPlot.GetColormapColorU32(idx, cmap)
            local gp = GImPlot
            cmap = ResolveCmap(gp, cmap)
            idx = idx % gp.ColormapData:GetKeyCount(cmap)
            return gp.ColormapData:GetKeyColor(cmap, idx)
        end

        function ImPlot.GetColormapColor(idx, cmap)
            return ImGui.ColorConvertU32ToFloat4(ImPlot.GetColormapColorU32(idx, cmap))
        end

        function ImPlot.SampleColormapU32(t, cmap)
            local gp = GImPlot
            cmap = ResolveCmap(gp, cmap)
            return gp.ColormapData:LerpTable(cmap, t)
        end

        function ImPlot.SampleColormap(t, cmap)
            return ImGui.ColorConvertU32ToFloat4(ImPlot.SampleColormapU32(t, cmap))
        end
    end

    return ImPlot
end
