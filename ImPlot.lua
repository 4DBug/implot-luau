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
                -- Plot States
                -- [Port] ImPool<ImPlotPlot>; ctor resolved lazily since ImPlotPlot is defined in a later section
                Plots = G.ImPool(function() return internal.ImPlotPlot() end),
                CurrentAlignmentH = nil,
                CurrentAlignmentV = nil,
                -- [Port] TODO: NextPlotData, NextItemData, Annotations, Tags, Subplots (later milestones)
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

    --------------------------------------------------------------------------
    -- [SECTION] Axes, Ticker, Plot (implot_internal.h)
    --------------------------------------------------------------------------
    do
        local ImAxis = ImPlot.ImAxis
        local ImPlotAxisFlags = ImPlot.ImPlotAxisFlags
        local ImPlotScale = ImPlot.ImPlotScale
        local ImPlotCond = ImPlot.ImPlotCond
        local band = bit32.band
        local HUGE_VAL = math.huge
        local DBL_MAX = 1.7976931348623157e308
        local DBL_MIN = 2.2250738585072014e-308
        local DBL_EPSILON = 2.220446049250313e-16

        internal.IMPLOT_LABEL_FORMAT = "%g"
        internal.IMPLOT_NUM_X_AXES = ImAxis.Y1
        internal.IMPLOT_NUM_Y_AXES = ImAxis.COUNT - ImAxis.Y1

        local function ImHasFlag(set, flag) return band(set, flag) == flag end
        internal.ImHasFlag = ImHasFlag
        -- Returns true if val is NAN
        local function ImNan(val) return val ~= val end
        -- Returns true if val is NAN or INFINITY
        local function ImNanOrInf(val) return val ~= val or val == HUGE_VAL or val == -HUGE_VAL end
        -- Turns NANs to 0s
        local function ImConstrainNan(val)
            if ImNan(val) then return 0 end
            return val
        end
        -- Turns infinity to floating point maximums
        local function ImConstrainInf(val)
            if val >= DBL_MAX then return DBL_MAX end
            if val <= -DBL_MAX then return -DBL_MAX end
            return val
        end
        -- True if two numbers are approximately equal using units in the last place.
        local function ImAlmostEqual(v1, v2, ulp)
            ulp = ulp or 2
            return math.abs(v1 - v2) < DBL_EPSILON * math.abs(v1 + v2) * ulp or math.abs(v1 - v2) < DBL_MIN
        end
        internal.ImNanOrInf = ImNanOrInf
        internal.ImAlmostEqual = ImAlmostEqual

        -- Tick mark info
        -- [Port] the label string is stored on the tick (Text) instead of an offset into a shared ImGuiTextBuffer
        function internal.ImPlotTick(value, major, level, show_label)
            return {
                PlotPos   = value or 0,
                PixelPos  = 0,
                LabelSize = ImVec2(0, 0),
                Text      = nil,
                Major     = major or false,
                ShowLabel = show_label or false,
                Level     = level or 0,
                Idx       = -1,
            }
        end

        -- Collection of ticks
        -- [Port] Ticks is a 1-based array whose tick tables are recycled across frames (Size = live count) to avoid per-frame allocations.
        local TickerMT = {}
        TickerMT.__index = TickerMT
        function internal.ImPlotTicker()
            local t = setmetatable({ Ticks = {}, Size = 0, MaxSize = ImVec2(0, 0), LateSize = ImVec2(0, 0), Levels = 1 }, TickerMT)
            t:Reset()
            return t
        end

        -- [Port] AddTick(value, major, level, show_label, label) and AddTick(..., formatter, data) overloads:
        -- `label_or_formatter` is a string or a formatter function(value, data) -> string
        function TickerMT:AddTick(value, major, level, show_label, label_or_formatter, data)
            local n = self.Size + 1
            local tick = self.Ticks[n]
            if tick == nil then
                tick = internal.ImPlotTick()
                self.Ticks[n] = tick
            end
            tick.PlotPos = value
            tick.PixelPos = 0
            tick.Major = major
            tick.ShowLabel = show_label
            tick.Level = level
            tick.Text = nil
            tick.LabelSize.x = 0; tick.LabelSize.y = 0
            if show_label and label_or_formatter ~= nil then
                local label = label_or_formatter
                if type(label) == "function" then
                    label = label_or_formatter(value, data)
                end
                tick.Text = label
                local sz = ImGui.CalcTextSize(label)
                tick.LabelSize.x = sz.x; tick.LabelSize.y = sz.y
            end
            if tick.ShowLabel then
                if tick.LabelSize.x > self.MaxSize.x then self.MaxSize.x = tick.LabelSize.x end
                if tick.LabelSize.y > self.MaxSize.y then self.MaxSize.y = tick.LabelSize.y end
            end
            tick.Idx = self.Size
            self.Size = n
            return tick
        end
        function TickerMT:GetText(idx) return self.Ticks[idx + 1].Text end
        function TickerMT:OverrideSizeLate(size)
            if size.x > self.LateSize.x then self.LateSize.x = size.x end
            if size.y > self.LateSize.y then self.LateSize.y = size.y end
        end
        function TickerMT:Reset()
            self.Size = 0
            self.MaxSize.x = self.LateSize.x; self.MaxSize.y = self.LateSize.y
            self.LateSize.x = 0; self.LateSize.y = 0
            self.Levels = 1
        end
        function TickerMT:TickCount() return self.Size end

        -- Axis state information that must persist after EndPlot
        local AxisMT = {}
        AxisMT.__index = AxisMT
        internal.ImPlotAxisMT = AxisMT
        function internal.ImPlotAxis()
            local a = setmetatable({}, AxisMT)
            a.ID               = 0
            a.Flags            = ImPlotAxisFlags.None
            a.PreviousFlags    = ImPlotAxisFlags.None
            a.Range            = ImPlot.ImPlotRange(0, 1)
            a.RangeCond        = ImPlotCond.None
            a.Scale            = ImPlotScale.Linear
            a.FitExtents       = ImPlot.ImPlotRange(HUGE_VAL, -HUGE_VAL)
            a.OrthoAxis        = nil
            a.ConstraintRange  = ImPlot.ImPlotRange(-HUGE_VAL, HUGE_VAL)
            a.ConstraintZoom   = ImPlot.ImPlotRange(DBL_MIN, HUGE_VAL)
            a.Ticker           = internal.ImPlotTicker()
            a.Formatter        = nil
            a.FormatterData    = nil
            a.FormatSpec       = nil
            a.Locator          = nil
            a.LinkedMin        = nil
            a.LinkedMax        = nil
            a.PickerLevel      = 0
            -- [Port] TODO: PickerTimeMin/PickerTimeMax (time scale milestone)
            a.TransformForward = nil
            a.TransformInverse = nil
            a.TransformData    = nil
            a.PixelMin         = 0
            a.PixelMax         = 0
            a.ScaleMin         = 0
            a.ScaleMax         = 0
            a.ScaleToPixel     = 0
            a.Datum1           = 0
            a.Datum2           = 0
            a.HoverRect        = G.ImRect()
            a.Label            = nil -- [Port] replaces LabelOffset into plot TextBuffer
            a.ColorMaj, a.ColorMin, a.ColorTick, a.ColorTxt, a.ColorBg, a.ColorHov, a.ColorAct = 0, 0, 0, 0, 0, 0, 0
            a.ColorHiLi        = G.IM_COL32_BLACK_TRANS
            a.Enabled          = false
            a.Vertical         = false
            a.FitThisFrame     = false
            a.HasRange         = false
            a.HasFormatSpec    = false
            a.ShowDefaultTicks = true
            a.Hovered          = false
            a.Held             = false
            return a
        end

        function AxisMT:Reset()
            self.Enabled          = false
            self.Scale            = ImPlotScale.Linear
            self.TransformForward = nil
            self.TransformInverse = nil
            self.TransformData    = nil
            self.Label            = nil
            self.HasFormatSpec    = false
            self.Formatter        = nil
            self.FormatterData    = nil
            self.Locator          = nil
            self.ShowDefaultTicks = true
            self.FitThisFrame     = false
            self.FitExtents.Min   = HUGE_VAL
            self.FitExtents.Max   = -HUGE_VAL
            self.OrthoAxis        = nil
            self.ConstraintRange.Min, self.ConstraintRange.Max = -HUGE_VAL, HUGE_VAL
            self.ConstraintZoom.Min, self.ConstraintZoom.Max = DBL_MIN, HUGE_VAL
            self.Ticker:Reset()
        end

        function AxisMT:SetMin(_min, force)
            if not force and self:IsLockedMin() then
                return false
            end
            _min = ImConstrainNan(ImConstrainInf(_min))
            if _min < self.ConstraintRange.Min then
                _min = self.ConstraintRange.Min
            end
            local z = self.Range.Max - _min
            if z < self.ConstraintZoom.Min then
                _min = self.Range.Max - self.ConstraintZoom.Min
            end
            if z > self.ConstraintZoom.Max then
                _min = self.Range.Max - self.ConstraintZoom.Max
            end
            if _min >= self.Range.Max then
                return false
            end
            self.Range.Min = _min
            -- [Port] TODO: PickerTimeMin
            self:UpdateTransformCache()
            return true
        end

        function AxisMT:SetMax(_max, force)
            if not force and self:IsLockedMax() then
                return false
            end
            _max = ImConstrainNan(ImConstrainInf(_max))
            if _max > self.ConstraintRange.Max then
                _max = self.ConstraintRange.Max
            end
            local z = _max - self.Range.Min
            if z < self.ConstraintZoom.Min then
                _max = self.Range.Min + self.ConstraintZoom.Min
            end
            if z > self.ConstraintZoom.Max then
                _max = self.Range.Min + self.ConstraintZoom.Max
            end
            if _max <= self.Range.Min then
                return false
            end
            self.Range.Max = _max
            -- [Port] TODO: PickerTimeMax
            self:UpdateTransformCache()
            return true
        end

        -- [Port] SetRange(v1, v2) and SetRange(const ImPlotRange&) overloads
        function AxisMT:SetRange(v1, v2)
            if type(v1) == "table" then v1, v2 = v1.Min, v1.Max end
            self.Range.Min = math.min(v1, v2)
            self.Range.Max = math.max(v1, v2)
            self:Constrain()
            -- [Port] TODO: PickerTimeMin/PickerTimeMax
            self:UpdateTransformCache()
        end

        function AxisMT:SetAspect(unit_per_pix)
            local new_size = unit_per_pix * self:PixelSize()
            local delta    = (new_size - self.Range:Size()) * 0.5
            if self:IsLocked() then
                return
            elseif self:IsLockedMin() and not self:IsLockedMax() then
                self:SetRange(self.Range.Min, self.Range.Max + 2 * delta)
            elseif not self:IsLockedMin() and self:IsLockedMax() then
                self:SetRange(self.Range.Min - 2 * delta, self.Range.Max)
            else
                self:SetRange(self.Range.Min - delta, self.Range.Max + delta)
            end
        end

        function AxisMT:PixelSize() return math.abs(self.PixelMax - self.PixelMin) end

        function AxisMT:GetAspect() return self.Range:Size() / self:PixelSize() end

        function AxisMT:Constrain()
            local r = self.Range
            r.Min = ImConstrainNan(ImConstrainInf(r.Min))
            r.Max = ImConstrainNan(ImConstrainInf(r.Max))
            if r.Min < self.ConstraintRange.Min then
                r.Min = self.ConstraintRange.Min
            end
            if r.Max > self.ConstraintRange.Max then
                r.Max = self.ConstraintRange.Max
            end
            local z = r.Max - r.Min
            if z < self.ConstraintZoom.Min then
                local delta = (self.ConstraintZoom.Min - z) * 0.5
                r.Min -= delta
                r.Max += delta
            end
            if z > self.ConstraintZoom.Max then
                local delta = (z - self.ConstraintZoom.Max) * 0.5
                r.Min += delta
                r.Max -= delta
            end
            if r.Max <= r.Min then
                r.Max = r.Min + DBL_EPSILON
            end
        end

        function AxisMT:UpdateTransformCache()
            self.ScaleToPixel = (self.PixelMax - self.PixelMin) / (self.Range.Max - self.Range.Min)
            if self.TransformForward ~= nil then
                self.ScaleMin = self.TransformForward(self.Range.Min, self.TransformData)
                self.ScaleMax = self.TransformForward(self.Range.Max, self.TransformData)
            else
                self.ScaleMin = self.Range.Min
                self.ScaleMax = self.Range.Max
            end
        end

        function AxisMT:PlotToPixels(plt)
            if self.TransformForward ~= nil then
                local s = self.TransformForward(plt, self.TransformData)
                local t = (s - self.ScaleMin) / (self.ScaleMax - self.ScaleMin)
                plt     = self.Range.Min + (self.Range.Max - self.Range.Min) * t
            end
            return self.PixelMin + self.ScaleToPixel * (plt - self.Range.Min)
        end

        function AxisMT:PixelsToPlot(pix)
            local plt = (pix - self.PixelMin) / self.ScaleToPixel + self.Range.Min
            if self.TransformInverse ~= nil then
                local t = (plt - self.Range.Min) / (self.Range.Max - self.Range.Min)
                local s = t * (self.ScaleMax - self.ScaleMin) + self.ScaleMin
                plt = self.TransformInverse(s, self.TransformData)
            end
            return plt
        end

        function AxisMT:ExtendFit(v)
            if not ImNanOrInf(v) and v >= self.ConstraintRange.Min and v <= self.ConstraintRange.Max then
                if v < self.FitExtents.Min then self.FitExtents.Min = v end
                if v > self.FitExtents.Max then self.FitExtents.Max = v end
            end
        end

        function AxisMT:ExtendFitWith(alt, v, v_alt)
            if ImHasFlag(self.Flags, ImPlotAxisFlags.RangeFit) and not alt.Range:Contains(v_alt) then
                return
            end
            self:ExtendFit(v)
        end

        function AxisMT:ApplyFit(padding)
            local ext_size = (self.FitExtents.Max - self.FitExtents.Min) * 0.5
            self.FitExtents.Min -= ext_size * padding
            self.FitExtents.Max += ext_size * padding
            if not self:IsLockedMin() and not ImNanOrInf(self.FitExtents.Min) then
                self.Range.Min = self.FitExtents.Min
            end
            if not self:IsLockedMax() and not ImNanOrInf(self.FitExtents.Max) then
                self.Range.Max = self.FitExtents.Max
            end
            if ImAlmostEqual(self.Range.Min, self.Range.Max) then
                self.Range.Max += 0.5
                self.Range.Min -= 0.5
            end
            self:Constrain()
            self:UpdateTransformCache()
        end

        function AxisMT:HasLabel()         return self.Label ~= nil and not ImHasFlag(self.Flags, ImPlotAxisFlags.NoLabel) end
        function AxisMT:HasGridLines()     return not ImHasFlag(self.Flags, ImPlotAxisFlags.NoGridLines) end
        function AxisMT:HasTickLabels()    return not ImHasFlag(self.Flags, ImPlotAxisFlags.NoTickLabels) end
        function AxisMT:HasTickMarks()     return not ImHasFlag(self.Flags, ImPlotAxisFlags.NoTickMarks) end
        function AxisMT:WillRender()       return self.Enabled and (self:HasGridLines() or self:HasTickLabels() or self:HasTickMarks()) end
        function AxisMT:IsOpposite()       return ImHasFlag(self.Flags, ImPlotAxisFlags.Opposite) end
        function AxisMT:IsInverted()       return ImHasFlag(self.Flags, ImPlotAxisFlags.Invert) end
        function AxisMT:IsForeground()     return ImHasFlag(self.Flags, ImPlotAxisFlags.Foreground) end
        function AxisMT:IsAutoFitting()    return ImHasFlag(self.Flags, ImPlotAxisFlags.AutoFit) end
        function AxisMT:CanInitFit()       return not ImHasFlag(self.Flags, ImPlotAxisFlags.NoInitialFit) and not self.HasRange and self.LinkedMin == nil and self.LinkedMax == nil end
        function AxisMT:IsRangeLocked()    return self.HasRange and self.RangeCond == ImPlotCond.Always end
        function AxisMT:IsLockedMin()      return not self.Enabled or self:IsRangeLocked() or ImHasFlag(self.Flags, ImPlotAxisFlags.LockMin) end
        function AxisMT:IsLockedMax()      return not self.Enabled or self:IsRangeLocked() or ImHasFlag(self.Flags, ImPlotAxisFlags.LockMax) end
        function AxisMT:IsLocked()         return self:IsLockedMin() and self:IsLockedMax() end
        function AxisMT:IsInputLockedMin() return self:IsLockedMin() or self:IsAutoFitting() end
        function AxisMT:IsInputLockedMax() return self:IsLockedMax() or self:IsAutoFitting() end
        function AxisMT:IsInputLocked()    return self:IsLocked() or self:IsAutoFitting() end
        function AxisMT:HasMenus()         return not ImHasFlag(self.Flags, ImPlotAxisFlags.NoMenus) end

        -- [Port] TODO: IsPanLocked, PushLinks/PullLinks (input / linked axes milestones)

        -- Holds Plot state information that must persist after EndPlot
        -- [Port] Axes is indexed by 0-based ImAxis values; Title/axis labels are stored as strings (no TextBuffer).
        local PlotMT = {}
        PlotMT.__index = PlotMT
        function internal.ImPlotPlot()
            local p = setmetatable({}, PlotMT)
            p.ID                = 0
            p.Flags             = ImPlot.ImPlotFlags.None
            p.PreviousFlags     = ImPlot.ImPlotFlags.None
            p.MouseTextLocation = bit32.bor(ImPlot.ImPlotLocation.South, ImPlot.ImPlotLocation.East)
            p.MouseTextFlags    = ImPlot.ImPlotMouseTextFlags.None
            p.Axes = {}
            for i = 0, ImAxis.COUNT - 1 do
                p.Axes[i] = internal.ImPlotAxis()
                p.Axes[i].Vertical = i >= ImAxis.Y1
            end
            -- [Port] TODO: ImPlotItemGroup (items/legend milestone); only the ID is needed for now
            p.Items             = { ID = 0 }
            p.CurrentX          = ImAxis.X1
            p.CurrentY          = ImAxis.Y1
            p.FrameRect         = G.ImRect()
            p.CanvasRect        = G.ImRect()
            p.PlotRect          = G.ImRect()
            p.AxesRect          = G.ImRect()
            p.SelectRect        = G.ImRect()
            p.SelectStart       = ImVec2(0, 0)
            p.Title             = nil
            p.JustCreated       = true
            p.Initialized       = false
            p.SetupLocked       = false
            p.FitThisFrame      = false
            p.Hovered           = false
            p.Held              = false
            p.Selecting         = false
            p.Selected          = false
            p.ContextLocked     = false
            return p
        end

        function PlotMT:IsInputLocked()
            for i = 0, ImAxis.COUNT - 1 do
                if not self.Axes[i]:IsInputLocked() then
                    return false
                end
            end
            return true
        end
        function PlotMT:ClearTextBuffer() end -- [Port] no shared text buffer
        function PlotMT:SetTitle(title)
            if title and ImGui.FindRenderedTextEnd(title) ~= 1 then
                self.Title = title
            else
                self.Title = nil
            end
        end
        function PlotMT:HasTitle() return self.Title ~= nil and not ImHasFlag(self.Flags, ImPlot.ImPlotFlags.NoTitle) end
        function PlotMT:GetTitle() return self.Title end
        function PlotMT:XAxis(i) return self.Axes[ImAxis.X1 + i] end
        function PlotMT:YAxis(i) return self.Axes[ImAxis.Y1 + i] end
        function PlotMT:EnabledAxesX()
            local cnt = 0
            for i = 0, internal.IMPLOT_NUM_X_AXES - 1 do
                if self:XAxis(i).Enabled then cnt += 1 end
            end
            return cnt
        end
        function PlotMT:EnabledAxesY()
            local cnt = 0
            for i = 0, internal.IMPLOT_NUM_Y_AXES - 1 do
                if self:YAxis(i).Enabled then cnt += 1 end
            end
            return cnt
        end
        function PlotMT:SetAxisLabel(axis, label)
            if label and ImGui.FindRenderedTextEnd(label) ~= 1 then
                axis.Label = label
            else
                axis.Label = nil
            end
        end
        function PlotMT:GetAxisLabel(axis) return axis.Label end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Formatters, Locators
    --------------------------------------------------------------------------
    do
        -- [Port] formatters return the label string instead of writing to a char buffer
        function internal.Formatter_Default(value, data)
            return string.format(data, value)
        end

        function internal.NiceNum(x, round)
            local nf
            local expv = math.floor(math.log10(x))
            local f = x / 10 ^ expv
            if round then
                if f < 1.5 then
                    nf = 1
                elseif f < 3 then
                    nf = 2
                elseif f < 7 then
                    nf = 5
                else
                    nf = 10
                end
            elseif f <= 1 then
                nf = 1
            elseif f <= 2 then
                nf = 2
            elseif f <= 5 then
                nf = 5
            else
                nf = 10
            end
            return nf * 10 ^ expv
        end
        local NiceNum = internal.NiceNum

        local TICK_FILL_X = 0.8
        local TICK_FILL_Y = 1.0

        function internal.Locator_Default(ticker, range, pixels, vertical, formatter, formatter_data)
            if range.Min == range.Max then
                return
            end
            local nMinor        = 10
            local nMajor        = math.max(2, math.floor(pixels / ((vertical and 300.0) or 400.0) + 0.5))
            local nice_range    = NiceNum((range.Max - range.Min) * 0.99, false)
            local interval      = NiceNum(nice_range / (nMajor - 1), true)
            local graphmin      = math.floor(range.Min / interval) * interval
            local graphmax      = math.ceil(range.Max / interval) * interval
            local first_major_set = false
            local first_major_idx = 0
            local idx0 = ticker:TickCount() -- ticker may have user custom ticks
            local total_x, total_y = 0, 0
            local major = graphmin
            while major < graphmax + 0.5 * interval do
                -- is this zero? combat zero formatting issues
                if major - interval < 0 and major + interval > 0 then
                    major = 0
                end
                if range:Contains(major) then
                    if not first_major_set then
                        first_major_idx = ticker:TickCount()
                        first_major_set = true
                    end
                    local ls = ticker:AddTick(major, true, 0, true, formatter, formatter_data).LabelSize
                    total_x += ls.x; total_y += ls.y
                end
                for i = 1, nMinor - 1 do
                    local minor = major + i * interval / nMinor
                    if range:Contains(minor) then
                        local ls = ticker:AddTick(minor, false, 0, true, formatter, formatter_data).LabelSize
                        total_x += ls.x; total_y += ls.y
                    end
                end
                major += interval
            end
            -- prune if necessary
            if (not vertical and total_x > pixels * TICK_FILL_X) or (vertical and total_y > pixels * TICK_FILL_Y) then
                local ticks = ticker.Ticks
                for i = first_major_idx - 1, idx0, -2 do
                    ticks[i + 1].ShowLabel = false
                end
                for i = first_major_idx + 1, ticker:TickCount() - 1, 2 do
                    ticks[i + 1].ShowLabel = false
                end
            end
        end
        -- [Port] TODO: Locator_Time, Locator_Log10, Locator_SymLog (log/time scale milestone)
    end

    --------------------------------------------------------------------------
    -- [SECTION] Plot Utils, Rendering helpers, Setup, BeginPlot, EndPlot
    --------------------------------------------------------------------------
    do
        local ImAxis = ImPlot.ImAxis
        local ImPlotFlags = ImPlot.ImPlotFlags
        local ImPlotAxisFlags = ImPlot.ImPlotAxisFlags
        local ImPlotCond = ImPlot.ImPlotCond
        local ImPlotScale = ImPlot.ImPlotScale
        local IMPLOT_AUTO = ImPlot.IMPLOT_AUTO
        local IMPLOT_NUM_X_AXES = internal.IMPLOT_NUM_X_AXES
        local IMPLOT_NUM_Y_AXES = internal.IMPLOT_NUM_Y_AXES
        local ImHasFlag = internal.ImHasFlag
        local GetStyleColorU32 = internal.GetStyleColorU32
        local GetStyleColorVec4 = internal.GetStyleColorVec4
        local IM_COL32_BLACK_TRANS = G.IM_COL32_BLACK_TRANS
        local ImRect = G.ImRect

        -- [Port] scratch vector reused for text positions (AddText copies the position)
        local tmp_pos = ImVec2(0, 0)
        local function SetTmp(x, y) tmp_pos.x = x; tmp_pos.y = y; return tmp_pos end

        local function AddLineH(draw_list, x1, x2, y, col, thickness)
            draw_list:AddLineH(x1, x2, y, col, thickness or 1.0)
        end
        local function AddLineV(draw_list, x, y1, y2, col, thickness)
            draw_list:AddLineV(x, y1, y2, col, thickness or 1.0)
        end
        internal.AddLineH = AddLineH
        internal.AddLineV = AddLineV

        -- Calculates the size of vertical text
        function internal.CalcTextSizeVertical(text)
            local sz = ImGui.CalcTextSize(text)
            return ImVec2(sz.y, sz.x)
        end

        -- Draws vertical text. The position is the bottom left of the text rect.
        function internal.AddTextVertical(DrawList, pos, col, text)
            -- the code below is based loosely on ImFont::RenderText
            local g = ImGui.GetCurrentContext()
            local font = g.Font:GetFontBaked(g.FontSize)
            local scale = g.FontSize / font.Size
            -- Align to be pixel perfect
            local x = math.floor(pos.x)
            local y = math.floor(pos.y)
            -- [Port] PrimReserve/PrimUnreserve replaced by a reserve per glyph
            for _, c in utf8.codes(text) do
                local glyph = font:FindGlyph(c)
                if glyph ~= nil then
                    DrawList:PrimReserve(6, 4)
                    DrawList:PrimQuadUV(ImVec2(x + glyph.Y0 * scale, y - glyph.X0 * scale), ImVec2(x + glyph.Y0 * scale, y - glyph.X1 * scale),
                                        ImVec2(x + glyph.Y1 * scale, y - glyph.X1 * scale), ImVec2(x + glyph.Y1 * scale, y - glyph.X0 * scale),
                                        ImVec2(glyph.U0, glyph.V0), ImVec2(glyph.U1, glyph.V0),
                                        ImVec2(glyph.U1, glyph.V1), ImVec2(glyph.U0, glyph.V1),
                                        col)
                    y -= glyph.AdvanceX * scale
                end
            end
        end

        -- Draws multiline horizontal text centered.
        function internal.AddTextCentered(DrawList, top_center, col, text)
            local txt_ht = ImGui.GetTextLineHeight()
            local title_end = ImGui.FindRenderedTextEnd(text)
            local text_begin = 1
            local y = 0
            while true do
                local tmp = string.find(text, "\n", text_begin, true)
                if tmp == nil or tmp >= title_end then
                    break
                end
                local text_size = ImGui.CalcTextSizeEx(text, text_begin, tmp, true)
                DrawList:AddText(nil, 0.0, SetTmp(top_center.x - text_size.x * 0.5, top_center.y + y), col, text, text_begin, tmp)
                text_begin = tmp + 1
                y += txt_ht
            end
            local text_size = ImGui.CalcTextSizeEx(text, text_begin, title_end, true)
            DrawList:AddText(nil, 0.0, SetTmp(top_center.x - text_size.x * 0.5, top_center.y + y), col, text, text_begin, title_end)
        end

        function internal.ResetCtxForNextPlot(ctx)
            -- [Port] TODO: NextPlotData/NextItemData/Annotations/Tags/digital counters (later milestones)
            ctx.OpenContextThisFrame = false
            -- nullify plot
            ctx.CurrentPlot  = nil
            ctx.CurrentItem  = nil
            ctx.PreviousItem = nil
        end

        function internal.GetPlot(title)
            local Window = ImGui.GetCurrentWindow()
            return GImPlot.Plots:GetByKey(Window:GetID(title))
        end

        function internal.GetCurrentPlot()
            return GImPlot.CurrentPlot
        end

        function internal.BustPlotCache()
            GImPlot.Plots:Clear()
        end

        function internal.UpdateAxisColors(axis)
            local col_grid = GetStyleColorVec4(ImPlotCol.AxisGrid)
            axis.ColorMaj  = ImGui.GetColorU32(col_grid)
            axis.ColorMin  = ImGui.GetColorU32(ImVec4(col_grid.x, col_grid.y, col_grid.z, col_grid.w * GImPlot.Style.MinorAlpha))
            axis.ColorTick = GetStyleColorU32(ImPlotCol.AxisTick)
            axis.ColorTxt  = GetStyleColorU32(ImPlotCol.AxisText)
            axis.ColorBg   = GetStyleColorU32(ImPlotCol.AxisBg)
            axis.ColorHov  = GetStyleColorU32(ImPlotCol.AxisBgHovered)
            axis.ColorAct  = GetStyleColorU32(ImPlotCol.AxisBgActive)
            -- axis.ColorHiLi = IM_COL32_BLACK_TRANS
        end
        local UpdateAxisColors = internal.UpdateAxisColors

        -- [Port] pad_a/pad_b are returned instead of passed by reference
        function internal.PadAndDatumAxesX(plot, pad_T, pad_B, align)
            local gp = GImPlot
            local T = ImGui.GetTextLineHeight()
            local P = gp.Style.LabelPadding.y
            local K = gp.Style.MinorTickLen.x

            local count_T = 0
            local count_B = 0
            local last_T  = plot.AxesRect.Min.y
            local last_B  = plot.AxesRect.Max.y

            for i = IMPLOT_NUM_X_AXES - 1, 0, -1 do -- FYI: can iterate forward
                local axis = plot:XAxis(i)
                if axis.Enabled then
                    local label = axis:HasLabel()
                    local ticks = axis:HasTickLabels()
                    local opp   = axis:IsOpposite()
                    local time  = axis.Scale == ImPlotScale.Time
                    local time_pad = 0
                    if time then time_pad = T + P end
                    if opp then
                        if count_T > 0 then
                            pad_T += K + P
                        end
                        count_T += 1
                        if label then
                            pad_T += ImGui.CalcTextSize(plot:GetAxisLabel(axis)).y + P
                        end
                        if ticks then
                            pad_T += math.max(T, axis.Ticker.MaxSize.y) + P + time_pad
                        end
                        axis.Datum1 = plot.CanvasRect.Min.y + pad_T
                        axis.Datum2 = last_T
                        last_T = axis.Datum1
                    else
                        if count_B > 0 then
                            pad_B += K + P
                        end
                        count_B += 1
                        if label then
                            pad_B += ImGui.CalcTextSize(plot:GetAxisLabel(axis)).y + P
                        end
                        if ticks then
                            pad_B += math.max(T, axis.Ticker.MaxSize.y) + P + time_pad
                        end
                        axis.Datum1 = plot.CanvasRect.Max.y - pad_B
                        axis.Datum2 = last_B
                        last_B = axis.Datum1
                    end
                end
            end

            if align then
                -- [Port] TODO: ImPlotAlignmentData (aligned plots milestone)
            end
            return pad_T, pad_B
        end

        -- [Port] pad_L/pad_R are returned instead of passed by reference
        function internal.PadAndDatumAxesY(plot, pad_L, pad_R, align)
            --   [   pad_L   ]                 [   pad_R   ]
            --   .................CanvasRect................
            --   :TPWPK.PTPWP _____PlotRect____ PWPTP.KPWPT:
            --   :A # |- A # |-               -| # A -| # A:
            --   :X   |  X   |                 |   X  |   x:
            --   :I # |- I # |-               -| # I -| # I:
            --   :S   |  S   |                 |   S  |   S:
            --   :3 # |- 0 # |-_______________-| # 1 -| # 2:
            --   :.........................................:
            --
            --   T = text height
            --   P = label padding
            --   K = minor tick length
            --   W = label width
            local gp = GImPlot
            local T = ImGui.GetTextLineHeight()
            local P = gp.Style.LabelPadding.x
            local K = gp.Style.MinorTickLen.y

            local count_L = 0
            local count_R = 0
            local last_L  = plot.AxesRect.Min.x
            local last_R  = plot.AxesRect.Max.x

            for i = IMPLOT_NUM_Y_AXES - 1, 0, -1 do -- FYI: can iterate forward
                local axis = plot:YAxis(i)
                if axis.Enabled then
                    local label = axis:HasLabel()
                    local ticks = axis:HasTickLabels()
                    local opp   = axis:IsOpposite()
                    if opp then
                        if count_R > 0 then
                            pad_R += K + P
                        end
                        count_R += 1
                        if label then
                            pad_R += T + P
                        end
                        if ticks then
                            pad_R += axis.Ticker.MaxSize.x + P
                        end
                        axis.Datum1 = plot.CanvasRect.Max.x - pad_R
                        axis.Datum2 = last_R
                        last_R = axis.Datum1
                    else
                        if count_L > 0 then
                            pad_L += K + P
                        end
                        count_L += 1
                        if label then
                            pad_L += T + P
                        end
                        if ticks then
                            pad_L += axis.Ticker.MaxSize.x + P
                        end
                        axis.Datum1 = plot.CanvasRect.Min.x + pad_L
                        axis.Datum2 = last_L
                        last_L = axis.Datum1
                    end
                end
            end

            plot.PlotRect.Min.x = plot.CanvasRect.Min.x + pad_L
            plot.PlotRect.Max.x = plot.CanvasRect.Max.x - pad_R

            if align then
                -- [Port] TODO: ImPlotAlignmentData (aligned plots milestone)
            end
            return pad_L, pad_R
        end

        local function ColMinWithDensity(col_min, density)
            local col_min4 = ImGui.ColorConvertU32ToFloat4(col_min)
            local t = 1.0 + (density - 0.1) * (0.0 - 1.0) / (0.2 - 0.1) -- ImRemap(density, 0.1f, 0.2f, 1.0f, 0.0f)
            col_min4.w *= math.clamp(t, 0.0, 1.0)
            return ImGui.ColorConvertFloat4ToU32(col_min4)
        end

        function internal.RenderGridLinesX(DrawList, ticker, rect, col_maj, col_min, size_maj, size_min)
            local density = ticker:TickCount() / rect:GetWidth()
            col_min = ColMinWithDensity(col_min, density)
            local ticks = ticker.Ticks
            for t = 1, ticker:TickCount() do
                local xt = ticks[t]
                if not (xt.PixelPos < rect.Min.x or xt.PixelPos > rect.Max.x) and xt.Level == 0 then
                    if xt.Major then
                        AddLineV(DrawList, xt.PixelPos, rect.Min.y, rect.Max.y, col_maj, size_maj)
                    elseif density < 0.2 then
                        AddLineV(DrawList, xt.PixelPos, rect.Min.y, rect.Max.y, col_min, size_min)
                    end
                end
            end
        end

        function internal.RenderGridLinesY(DrawList, ticker, rect, col_maj, col_min, size_maj, size_min)
            local density = ticker:TickCount() / rect:GetHeight()
            col_min = ColMinWithDensity(col_min, density)
            local ticks = ticker.Ticks
            for t = 1, ticker:TickCount() do
                local yt = ticks[t]
                if not (yt.PixelPos < rect.Min.y or yt.PixelPos > rect.Max.y) then
                    if yt.Major then
                        AddLineH(DrawList, rect.Min.x, rect.Max.x, yt.PixelPos, col_maj, size_maj)
                    elseif density < 0.2 then
                        AddLineH(DrawList, rect.Min.x, rect.Max.x, yt.PixelPos, col_min, size_min)
                    end
                end
            end
        end
        local RenderGridLinesX = internal.RenderGridLinesX
        local RenderGridLinesY = internal.RenderGridLinesY

        local plot_button_flags = bit32.bor(G.ImGuiButtonFlags.AllowOverlap, G.ImGuiButtonFlags.PressedOnClick, G.ImGuiButtonFlags.PressedOnDoubleClick,
                                            G.ImGuiButtonFlags.MouseButtonLeft, G.ImGuiButtonFlags.MouseButtonRight, G.ImGuiButtonFlags.MouseButtonMiddle)

        function internal.UpdateInput(plot)
            -- BUTTON STATE -----------------------------------------------------------
            local _, hovered, held = ImGui.ButtonBehavior(plot.PlotRect, plot.ID, plot_button_flags)
            plot.Hovered = hovered
            plot.Held = held
            -- [Port] TODO: axis buttons, fit on double click, panning, zooming, box selection, context menus (input milestone)
            return false
        end

        -----------------------------------------------------------------------
        -- Setup
        -----------------------------------------------------------------------

        local function CheckSetup()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil and not GImPlot.CurrentPlot.SetupLocked,
                      "Setup needs to be called after BeginPlot and before any setup locking functions (e.g. PlotX)!")
        end

        function ImPlot.SetupAxis(idx, label, flags)
            if flags == nil then flags = ImPlotAxisFlags.None end
            CheckSetup()
            -- get plot and axis
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            -- set ID
            axis.ID = plot.ID + idx + 1
            -- check and set flags
            if plot.JustCreated or flags ~= axis.PreviousFlags then
                axis.Flags = flags
            end
            axis.PreviousFlags = flags
            -- enable axis
            axis.Enabled = true
            -- set label
            plot:SetAxisLabel(axis, label)
            -- cache colors
            UpdateAxisColors(axis)
        end

        function ImPlot.SetupAxisLimits(idx, min_lim, max_lim, cond)
            if cond == nil then cond = ImPlotCond.Once end
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            if not plot.Initialized or cond == ImPlotCond.Always then
                axis:SetRange(min_lim, max_lim)
            end
            axis.HasRange  = true
            axis.RangeCond = cond
        end

        -- [Port] only the format-string overload; TODO: SetupAxisFormat(idx, formatter, data)
        function ImPlot.SetupAxisFormat(idx, fmt)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            axis.HasFormatSpec = fmt ~= nil
            if fmt ~= nil then
                axis.FormatSpec = fmt
            end
        end

        -- [Port] TODO: SetupAxisLinks, SetupAxisTicks, SetupAxisScale, SetupAxisLimitsConstraints, SetupAxisZoomConstraints, SetupLegend, SetupMouseText

        function ImPlot.SetupAxes(x_label, y_label, x_flags, y_flags)
            ImPlot.SetupAxis(ImAxis.X1, x_label, x_flags)
            ImPlot.SetupAxis(ImAxis.Y1, y_label, y_flags)
        end

        function ImPlot.SetupAxesLimits(x_min, x_max, y_min, y_max, cond)
            ImPlot.SetupAxisLimits(ImAxis.X1, x_min, x_max, cond)
            ImPlot.SetupAxisLimits(ImAxis.Y1, y_min, y_max, cond)
        end

        -----------------------------------------------------------------------
        -- BeginPlot
        -----------------------------------------------------------------------

        function ImPlot.BeginPlot(title_id, size, flags)
            if size == nil then size = ImVec2(-1, 0) end
            if flags == nil then flags = ImPlotFlags.None end
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot == nil, "Mismatched BeginPlot()/EndPlot()!")

            -- FRONT MATTER -----------------------------------------------------------
            -- [Port] TODO: subplots (PushID(CurrentSubplot.CurrentIdx))

            -- get globals
            local Window = ImGui.GetCurrentWindow()

            -- skip if needed
            if Window.SkipItems then
                internal.ResetCtxForNextPlot(gp)
                return false
            end

            -- ID and age (TODO: keep track of plot age in frames)
            local ID           = Window:GetID(title_id)
            local just_created = gp.Plots:GetByKey(ID) == nil
            gp.CurrentPlot     = gp.Plots:GetOrAddByKey(ID)

            local plot         = gp.CurrentPlot
            plot.ID            = ID
            plot.Items.ID      = ID - 1
            plot.JustCreated   = just_created
            plot.SetupLocked   = false

            -- check flags
            if plot.JustCreated then
                plot.Flags = flags
            elseif flags ~= plot.PreviousFlags then
                plot.Flags = flags
            end
            plot.PreviousFlags = flags

            -- setup default axes
            if plot.JustCreated then
                ImPlot.SetupAxis(ImAxis.X1)
                ImPlot.SetupAxis(ImAxis.Y1)
            end

            -- reset axes
            for i = 0, ImAxis.COUNT - 1 do
                plot.Axes[i]:Reset()
                UpdateAxisColors(plot.Axes[i])
            end
            -- ensure first axes enabled
            plot.Axes[ImAxis.X1].Enabled = true
            plot.Axes[ImAxis.Y1].Enabled = true
            -- set initial axes
            plot.CurrentX = ImAxis.X1
            plot.CurrentY = ImAxis.Y1

            -- process next plot data (legacy)
            -- [Port] TODO: ApplyNextPlotData (SetNextAxis* milestone)

            -- clear text buffers
            plot:ClearTextBuffer()
            plot:SetTitle(title_id)

            -- set frame size
            local frame_size = ImGui.CalcItemSize(size, gp.Style.PlotDefaultSize.x, gp.Style.PlotDefaultSize.y)

            if frame_size.x < gp.Style.PlotMinSize.x and size.x < 0.0 then
                frame_size.x = gp.Style.PlotMinSize.x
            end
            if frame_size.y < gp.Style.PlotMinSize.y and size.y < 0.0 then
                frame_size.y = gp.Style.PlotMinSize.y
            end

            local cp = Window.DC.CursorPos
            local fr = plot.FrameRect
            fr.Min.x, fr.Min.y = cp.x, cp.y
            fr.Max.x, fr.Max.y = cp.x + frame_size.x, cp.y + frame_size.y
            ImGui.ItemSize(fr)
            if not ImGui.ItemAdd(fr, plot.ID, fr) then
                internal.ResetCtxForNextPlot(gp)
                return false
            end

            -- setup items (or dont)
            if gp.CurrentItems == nil then
                gp.CurrentItems = plot.Items
            end

            return true
        end

        -----------------------------------------------------------------------
        -- SetupFinish
        -----------------------------------------------------------------------

        local function SetRect(r, x1, y1, x2, y2)
            r.Min.x, r.Min.y, r.Max.x, r.Max.y = x1, y1, x2, y2
        end

        -- render x/y axis button, label, tick labels
        local function RenderAxisBg(DrawList, plot, ax)
            if (ax.Hovered or ax.Held) and not plot.Held and not ImHasFlag(ax.Flags, ImPlotAxisFlags.NoHighlight) then
                DrawList:AddRectFilled(ax.HoverRect.Min, ax.HoverRect.Max, (ax.Held and ax.ColorAct) or ax.ColorHov)
            elseif ax.ColorHiLi ~= IM_COL32_BLACK_TRANS then
                DrawList:AddRectFilled(ax.HoverRect.Min, ax.HoverRect.Max, ax.ColorHiLi)
                ax.ColorHiLi = IM_COL32_BLACK_TRANS
            elseif ax.ColorBg ~= IM_COL32_BLACK_TRANS then
                DrawList:AddRectFilled(ax.HoverRect.Min, ax.HoverRect.Max, ax.ColorBg)
            end
        end

        function ImPlot.SetupFinish()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "SetupFinish needs to be called after BeginPlot!")

            local g        = ImGui.GetCurrentContext()
            local DrawList = g.CurrentWindow.DrawList
            local Style    = g.Style
            local gs       = gp.Style

            local plot = gp.CurrentPlot

            -- lock setup
            plot.SetupLocked = true

            -- finalize axes and set default formatter/locator
            for i = 0, ImAxis.COUNT - 1 do
                local axis = plot.Axes[i]
                if axis.Enabled then
                    axis:Constrain()
                    if not plot.Initialized and axis:CanInitFit() then
                        plot.FitThisFrame = true
                        axis.FitThisFrame = true
                    end
                end
                if axis.Formatter == nil then
                    axis.Formatter = internal.Formatter_Default
                    if axis.HasFormatSpec then
                        axis.FormatterData = axis.FormatSpec
                    else
                        axis.FormatterData = internal.IMPLOT_LABEL_FORMAT
                    end
                end
                if axis.Locator == nil then
                    axis.Locator = internal.Locator_Default
                end
            end

            -- setup nullptr orthogonal axes
            local axis_equal = ImHasFlag(plot.Flags, ImPlotFlags.Equal)
            for k = 0, IMPLOT_NUM_X_AXES - 1 do
                local x_axis = plot.Axes[ImAxis.X1 + k]
                local y_axis = plot.Axes[ImAxis.Y1 + k]
                if x_axis.Enabled and y_axis.Enabled then
                    if x_axis.OrthoAxis == nil then x_axis.OrthoAxis = y_axis end
                    if y_axis.OrthoAxis == nil then y_axis.OrthoAxis = x_axis end
                elseif x_axis.Enabled then
                    if x_axis.OrthoAxis == nil and not axis_equal then x_axis.OrthoAxis = plot.Axes[ImAxis.Y1] end
                elseif y_axis.Enabled then
                    if y_axis.OrthoAxis == nil and not axis_equal then y_axis.OrthoAxis = plot.Axes[ImAxis.X1] end
                end
            end

            -- canvas/axes bb
            local fr = plot.FrameRect
            SetRect(plot.CanvasRect, fr.Min.x + gs.PlotPadding.x, fr.Min.y + gs.PlotPadding.y, fr.Max.x - gs.PlotPadding.x, fr.Max.y - gs.PlotPadding.y)
            SetRect(plot.AxesRect, fr.Min.x, fr.Min.y, fr.Max.x, fr.Max.y)

            -- outside legend adjustments
            -- [Port] TODO: legend milestone

            -- plot bb
            local pad_top, pad_bot, pad_left, pad_right = 0, 0, 0, 0

            -- (0) calc top padding form title
            local title_x, title_y = 0, 0
            if plot:HasTitle() then
                local ts = ImGui.CalcTextSize(plot:GetTitle(), nil, true)
                title_x, title_y = ts.x, ts.y
            end
            if title_x > 0 then
                pad_top += title_y + gs.LabelPadding.y
                plot.AxesRect.Min.y += gs.PlotPadding.y + pad_top
            end

            -- (1) calc addition top padding and bot padding
            pad_top, pad_bot = internal.PadAndDatumAxesX(plot, pad_top, pad_bot, gp.CurrentAlignmentH)

            local plot_height = plot.CanvasRect:GetHeight() - pad_top - pad_bot

            -- (2) get y tick labels (needed for left/right pad)
            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local axis = plot:YAxis(i)
                if axis:WillRender() and axis.ShowDefaultTicks and plot_height > 0 then
                    axis.Locator(axis.Ticker, axis.Range, plot_height, true, axis.Formatter, axis.FormatterData)
                end
            end

            -- (3) calc left/right pad
            pad_left, pad_right = internal.PadAndDatumAxesY(plot, pad_left, pad_right, gp.CurrentAlignmentV)

            local plot_width = plot.CanvasRect:GetWidth() - pad_left - pad_right

            -- (4) get x ticks
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local axis = plot:XAxis(i)
                if axis:WillRender() and axis.ShowDefaultTicks and plot_width > 0 then
                    axis.Locator(axis.Ticker, axis.Range, plot_width, false, axis.Formatter, axis.FormatterData)
                end
            end

            -- (4.5) recalc padding now that we have actual X-axis tick labels (handles multi-line labels)
            -- Save title padding before resetting
            local title_pad = 0.0
            if title_x > 0 then title_pad = title_y + gs.LabelPadding.y end
            pad_top = title_pad
            pad_bot = 0
            pad_top, pad_bot = internal.PadAndDatumAxesX(plot, pad_top, pad_bot, gp.CurrentAlignmentH)
            -- Update AxesRect to account for title padding (was done in step 0)
            if title_x > 0 then
                plot.AxesRect.Min.y = fr.Min.y + gs.PlotPadding.y + title_pad
            end

            -- (5) calc plot bb
            local cr = plot.CanvasRect
            local pr = plot.PlotRect
            SetRect(pr, cr.Min.x + pad_left, cr.Min.y + pad_top, cr.Max.x - pad_right, cr.Max.y - pad_bot)

            -- HOVER------------------------------------------------------------

            -- axes hover rect, pixel ranges
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local xax = plot:XAxis(i)
                SetRect(xax.HoverRect, pr.Min.x, math.min(xax.Datum1, xax.Datum2), pr.Max.x, math.max(xax.Datum1, xax.Datum2))
                if xax:IsInverted() then
                    xax.PixelMin, xax.PixelMax = pr.Max.x, pr.Min.x
                else
                    xax.PixelMin, xax.PixelMax = pr.Min.x, pr.Max.x
                end
                xax:UpdateTransformCache()
            end

            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local yax = plot:YAxis(i)
                SetRect(yax.HoverRect, math.min(yax.Datum1, yax.Datum2), pr.Min.y, math.max(yax.Datum1, yax.Datum2), pr.Max.y)
                if yax:IsInverted() then
                    yax.PixelMin, yax.PixelMax = pr.Min.y, pr.Max.y
                else
                    yax.PixelMin, yax.PixelMax = pr.Max.y, pr.Min.y
                end
                yax:UpdateTransformCache()
            end
            -- Equal axis constraint. Must happen after we set Pixels
            -- constrain equal axes for primary x and y if not approximately equal
            -- constrains x to y since x pixel size depends on y labels width, and causes feedback loops in opposite case
            if axis_equal then
                for i = 0, IMPLOT_NUM_X_AXES - 1 do
                    local x_axis = plot:XAxis(i)
                    if x_axis.OrthoAxis ~= nil then
                        local xar = x_axis:GetAspect()
                        local yar = x_axis.OrthoAxis:GetAspect()
                        -- edge case: user has set x range this frame, so fit y to x so that we honor their request for x range
                        -- NB: because of feedback across several frames, the user's x request may not be perfectly honored
                        if x_axis.HasRange then
                            x_axis.OrthoAxis:SetAspect(xar)
                        elseif not internal.ImAlmostEqual(xar, yar) and not x_axis.OrthoAxis:IsInputLocked() then
                            x_axis:SetAspect(yar)
                        end
                    end
                end
            end

            -- INPUT ------------------------------------------------------------------
            if not ImHasFlag(plot.Flags, ImPlotFlags.NoInputs) then
                internal.UpdateInput(plot)
            end

            -- fit from FitNextPlotAxes or auto fit
            for i = 0, ImAxis.COUNT - 1 do
                -- [Port] TODO: gp.NextPlotData.Fit[i]
                if plot.Axes[i]:IsAutoFitting() then
                    plot.FitThisFrame = true
                    plot.Axes[i].FitThisFrame = true
                end
            end

            -- RENDER -----------------------------------------------------------------

            local txt_height = ImGui.GetTextLineHeight()

            -- render frame
            if not ImHasFlag(plot.Flags, ImPlotFlags.NoFrame) then
                ImGui.RenderFrame(fr.Min, fr.Max, GetStyleColorU32(ImPlotCol.FrameBg), true, Style.FrameRounding)
            end

            -- grid bg
            DrawList:AddRectFilled(pr.Min, pr.Max, GetStyleColorU32(ImPlotCol.PlotBg))

            -- transform ticks
            for i = 0, ImAxis.COUNT - 1 do
                local axis = plot.Axes[i]
                if axis:WillRender() then
                    local ticks = axis.Ticker.Ticks
                    for t = 1, axis.Ticker:TickCount() do
                        local tk = ticks[t]
                        tk.PixelPos = math.floor(axis:PlotToPixels(tk.PlotPos) + 0.5)
                    end
                end
            end

            -- render grid (background)
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local x_axis = plot:XAxis(i)
                if x_axis.Enabled and x_axis:HasGridLines() and not x_axis:IsForeground() then
                    RenderGridLinesX(DrawList, x_axis.Ticker, pr, x_axis.ColorMaj, x_axis.ColorMin, gs.MajorGridSize.x, gs.MinorGridSize.x)
                end
            end
            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local y_axis = plot:YAxis(i)
                if y_axis.Enabled and y_axis:HasGridLines() and not y_axis:IsForeground() then
                    RenderGridLinesY(DrawList, y_axis.Ticker, pr, y_axis.ColorMaj, y_axis.ColorMin, gs.MajorGridSize.y, gs.MinorGridSize.y)
                end
            end

            -- render x axis button, label, tick labels
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local ax = plot:XAxis(i)
                if ax.Enabled then
                    RenderAxisBg(DrawList, plot, ax)
                    local tkr = ax.Ticker
                    local opp = ax:IsOpposite()
                    if ax:HasLabel() then
                        local label        = plot:GetAxisLabel(ax)
                        local label_size   = ImGui.CalcTextSize(label)
                        local label_offset = (tkr.Levels - 1) * (txt_height + gs.LabelPadding.y) + gs.LabelPadding.y
                        if ax:HasTickLabels() then
                            label_offset += tkr.MaxSize.y + gs.LabelPadding.y
                        end
                        local ly = ax.Datum1 + label_offset
                        if opp then ly = ax.Datum1 - label_offset - label_size.y end
                        DrawList:AddText(SetTmp((pr.Min.x + pr.Max.x) * 0.5 - label_size.x * 0.5, ly), ax.ColorTxt, label)
                    end
                    if ax:HasTickLabels() then
                        local ticks = tkr.Ticks
                        for j = 1, tkr:TickCount() do
                            local tk = ticks[j]
                            if tk.ShowLabel and tk.PixelPos >= pr.Min.x - 1 and tk.PixelPos <= pr.Max.x + 1 then
                                local datum
                                if opp then
                                    datum = ax.Datum1 + (-gs.LabelPadding.y - txt_height - tk.Level * (txt_height + gs.LabelPadding.y))
                                else
                                    datum = ax.Datum1 + gs.LabelPadding.y + tk.Level * (txt_height + gs.LabelPadding.y)
                                end
                                DrawList:AddText(SetTmp(tk.PixelPos - 0.5 * tk.LabelSize.x, datum), ax.ColorTxt, tk.Text)
                            end
                        end
                    end
                end
            end

            -- render y axis button, label, tick labels
            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local ax = plot:YAxis(i)
                if ax.Enabled then
                    RenderAxisBg(DrawList, plot, ax)
                    local tkr = ax.Ticker
                    local opp = ax:IsOpposite()
                    if ax:HasLabel() then
                        local label        = plot:GetAxisLabel(ax)
                        local label_size   = internal.CalcTextSizeVertical(label)
                        local label_offset = gs.LabelPadding.x
                        if ax:HasTickLabels() then
                            label_offset += tkr.MaxSize.x + gs.LabelPadding.x
                        end
                        local lx = ax.Datum1 - label_offset - label_size.x
                        if opp then lx = ax.Datum1 + label_offset end
                        internal.AddTextVertical(DrawList, SetTmp(lx, (pr.Min.y + pr.Max.y) * 0.5 + label_size.y * 0.5), ax.ColorTxt, label)
                    end
                    if ax:HasTickLabels() then
                        local ticks = tkr.Ticks
                        for j = 1, tkr:TickCount() do
                            local tk = ticks[j]
                            if tk.ShowLabel and tk.PixelPos >= pr.Min.y - 1 and tk.PixelPos <= pr.Max.y + 1 then
                                local datum = ax.Datum1 - gs.LabelPadding.x - tk.LabelSize.x
                                if opp then datum = ax.Datum1 + gs.LabelPadding.x end
                                DrawList:AddText(SetTmp(datum, tk.PixelPos - 0.5 * tk.LabelSize.y), ax.ColorTxt, tk.Text)
                            end
                        end
                    end
                end
            end

            -- clear legend (TODO: put elsewhere)
            -- [Port] TODO: plot.Items.Legend:Reset() (legend milestone)
            -- push ID to set item hashes (NB: !!!THIS PROBABLY NEEDS TO BE IN BEGIN PLOT!!!!)
            ImGui.PushOverrideID(gp.CurrentItems.ID)
        end

        function internal.SetupLock()
            local gp = GImPlot
            if not gp.CurrentPlot.SetupLocked then
                ImPlot.SetupFinish()
            end
            gp.CurrentPlot.SetupLocked = true
        end
        local SetupLock = internal.SetupLock

        -----------------------------------------------------------------------
        -- EndPlot()
        -----------------------------------------------------------------------

        function ImPlot.EndPlot()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "Mismatched BeginPlot()/EndPlot()!")

            SetupLock()

            local plot     = gp.CurrentPlot
            local Window   = ImGui.GetCurrentWindow()
            local DrawList = Window.DrawList
            local gs       = gp.Style
            local pr       = plot.PlotRect

            -- FINAL RENDER -----------------------------------------------------------

            local render_border = gs.PlotBorderSize > 0 and GetStyleColorVec4(ImPlotCol.PlotBorder).w > 0

            ImGui.PushClipRect(plot.FrameRect.Min, plot.FrameRect.Max, true)

            -- render grid (foreground)
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local x_axis = plot:XAxis(i)
                if x_axis.Enabled and x_axis:HasGridLines() and x_axis:IsForeground() then
                    RenderGridLinesX(DrawList, x_axis.Ticker, pr, x_axis.ColorMaj, x_axis.ColorMin, gs.MajorGridSize.x, gs.MinorGridSize.x)
                end
            end
            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local y_axis = plot:YAxis(i)
                if y_axis.Enabled and y_axis:HasGridLines() and y_axis:IsForeground() then
                    RenderGridLinesY(DrawList, y_axis.Ticker, pr, y_axis.ColorMaj, y_axis.ColorMin, gs.MajorGridSize.y, gs.MinorGridSize.y)
                end
            end

            -- render title
            if plot:HasTitle() then
                local col = GetStyleColorU32(ImPlotCol.TitleText)
                internal.AddTextCentered(DrawList, ImVec2((pr.Min.x + pr.Max.x) * 0.5, plot.CanvasRect.Min.y), col, plot:GetTitle())
            end

            -- render x ticks
            local count_B, count_T = 0, 0
            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local ax = plot:XAxis(i)
                if ax.Enabled then
                    local tkr = ax.Ticker
                    local opp = ax:IsOpposite()
                    local aux = (opp and count_T > 0) or (not opp and count_B > 0)
                    if ax:HasTickMarks() then
                        local direction = -1.0
                        if opp then direction = 1.0 end
                        local ticks = tkr.Ticks
                        for j = 1, tkr:TickCount() do
                            local tk = ticks[j]
                            if not (tk.Level ~= 0 or tk.PixelPos < pr.Min.x or tk.PixelPos > pr.Max.x) then
                                local len, thk = gs.MinorTickLen.x, gs.MinorTickSize.x
                                if not aux and tk.Major then
                                    len, thk = gs.MajorTickLen.x, gs.MajorTickSize.x
                                end
                                AddLineV(DrawList, tk.PixelPos, ax.Datum1, ax.Datum1 + direction * len, ax.ColorTick, thk)
                            end
                        end
                        if aux or not render_border then
                            AddLineH(DrawList, pr.Min.x, pr.Max.x, ax.Datum1, ax.ColorTick, gs.MinorTickSize.x)
                        end
                    end
                    if opp then count_T += 1 else count_B += 1 end
                end
            end

            -- render y ticks
            local count_L, count_R = 0, 0
            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local ax = plot:YAxis(i)
                if ax.Enabled then
                    local tkr = ax.Ticker
                    local opp = ax:IsOpposite()
                    local aux = (opp and count_R > 0) or (not opp and count_L > 0)
                    if ax:HasTickMarks() then
                        local direction = 1.0
                        if opp then direction = -1.0 end
                        local ticks = tkr.Ticks
                        for j = 1, tkr:TickCount() do
                            local tk = ticks[j]
                            if not (tk.Level ~= 0 or tk.PixelPos < pr.Min.y or tk.PixelPos > pr.Max.y) then
                                local len, thk = gs.MinorTickLen.y, gs.MinorTickSize.y
                                if not aux and tk.Major then
                                    len, thk = gs.MajorTickLen.y, gs.MajorTickSize.y
                                end
                                AddLineH(DrawList, ax.Datum1, ax.Datum1 + direction * len, tk.PixelPos, ax.ColorTick, thk)
                            end
                        end
                        if aux or not render_border then
                            AddLineV(DrawList, ax.Datum1, pr.Min.y, pr.Max.y, ax.ColorTick, gs.MinorTickSize.y)
                        end
                    end
                    if opp then count_R += 1 else count_L += 1 end
                end
            end
            ImGui.PopClipRect()

            -- [Port] TODO: annotations, selection, crosshairs, mouse text, axis side switch, legend (later milestones)

            -- render border
            if render_border then
                DrawList:AddRect(pr.Min, pr.Max, GetStyleColorU32(ImPlotCol.PlotBorder), 0, gs.PlotBorderSize, G.ImDrawFlags.None)
            end

            -- [Port] TODO: tags

            -- FIT DATA --------------------------------------------------------------
            -- [Port] TODO: ImPlotFlags_Equal aspect handling during fit
            if plot.FitThisFrame then
                for i = 0, ImAxis.COUNT - 1 do
                    local axis = plot.Axes[i]
                    if axis.FitThisFrame then
                        if axis.Vertical then
                            axis:ApplyFit(gs.FitPadding.y)
                        else
                            axis:ApplyFit(gs.FitPadding.x)
                        end
                    end
                end
                plot.FitThisFrame = false
            end

            -- CONTEXT MENUS -----------------------------------------------------------
            -- [Port] TODO: plot/axis context menus (input milestone)

            -- LINKED AXES ------------------------------------------------------------
            -- [Port] TODO: PushLinks

            -- CLEANUP ----------------------------------------------------------------

            -- remove items
            if gp.CurrentItems == plot.Items then
                gp.CurrentItems = nil
            end

            -- mark the plot as initialized, i.e. having made it through one frame completely
            plot.Initialized = true
            -- Pop ImGui::PushID at the end of BeginPlot
            ImGui.PopID()
            -- Reset context for next plot
            internal.ResetCtxForNextPlot(gp)
        end

        -----------------------------------------------------------------------
        -- Plot Tools / Utils
        -----------------------------------------------------------------------

        local function GetAxes(x_idx, y_idx, what)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, what .. "() needs to be called between BeginPlot() and EndPlot()!")
            IM_ASSERT(x_idx == nil or x_idx == IMPLOT_AUTO or (x_idx >= ImAxis.X1 and x_idx < ImAxis.Y1), "X-Axis index out of bounds!")
            IM_ASSERT(y_idx == nil or y_idx == IMPLOT_AUTO or (y_idx >= ImAxis.Y1 and y_idx < ImAxis.COUNT), "Y-Axis index out of bounds!")
            SetupLock()
            local plot = gp.CurrentPlot
            if x_idx == nil or x_idx == IMPLOT_AUTO then x_idx = plot.CurrentX end
            if y_idx == nil or y_idx == IMPLOT_AUTO then y_idx = plot.CurrentY end
            return plot.Axes[x_idx], plot.Axes[y_idx]
        end

        -- [Port] PixelsToPlot(x, y, x_idx, y_idx) and PixelsToPlot(ImVec2, x_idx, y_idx) overloads
        function ImPlot.PixelsToPlot(x, y, x_idx, y_idx)
            if type(x) == "table" then
                x, y, x_idx, y_idx = x.x, x.y, y, x_idx
            end
            local x_axis, y_axis = GetAxes(x_idx, y_idx, "PixelsToPlot")
            return ImPlot.ImPlotPoint(x_axis:PixelsToPlot(x), y_axis:PixelsToPlot(y))
        end

        -- [Port] PlotToPixels(x, y, x_idx, y_idx) and PlotToPixels(ImPlotPoint, x_idx, y_idx) overloads
        function ImPlot.PlotToPixels(x, y, x_idx, y_idx)
            if type(x) == "table" then
                x, y, x_idx, y_idx = x.x, x.y, y, x_idx
            end
            local x_axis, y_axis = GetAxes(x_idx, y_idx, "PlotToPixels")
            return ImVec2(x_axis:PlotToPixels(x), y_axis:PlotToPixels(y))
        end

        function ImPlot.GetPlotPos()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "GetPlotPos() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            local m = GImPlot.CurrentPlot.PlotRect.Min
            return ImVec2(m.x, m.y)
        end

        function ImPlot.GetPlotSize()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "GetPlotSize() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            return GImPlot.CurrentPlot.PlotRect:GetSize()
        end

        function ImPlot.GetPlotLimits(x_idx, y_idx)
            local x_axis, y_axis = GetAxes(x_idx, y_idx, "GetPlotLimits")
            return ImPlot.ImPlotRect(x_axis.Range.Min, x_axis.Range.Max, y_axis.Range.Min, y_axis.Range.Max)
        end

        function ImPlot.IsPlotHovered()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "IsPlotHovered() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            return GImPlot.CurrentPlot.Hovered
        end
    end


    return ImPlot
end
