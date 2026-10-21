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

        @native
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
                CTicker = nil, -- [Port] ImPlotTicker created lazily by ColormapScale (defined in a later section)
                -- Plot States
                -- [Port] ImPool<ImPlotPlot>; ctor resolved lazily since ImPlotPlot is defined in a later section
                Plots = G.ImPool(function() return internal.ImPlotPlot() end),
                CurrentAlignmentH = nil,
                CurrentAlignmentV = nil,
                -- Temp data for general use
                OpenContextThisFrame = false,
                DigitalPlotItemCnt = 0,
                DigitalPlotOffset = 0,
                -- [Port] ImPlotAnnotationCollection / ImPlotTagCollection: plain arrays of records with the text stored inline
                Annotations = {},
                Tags = {},
                -- [Port] ctors resolved lazily (defined in the subplots section)
                Subplots = G.ImPool(function() return internal.ImPlotSubplot() end),
                AlignmentData = G.ImPool(function() return internal.ImPlotAlignmentData() end),
                -- [Port] ctor resolved lazily (defined in the items section)
                NextItemData = nil,
                NextPlotData = internal.ImPlotNextPlotData(),
                InputMap = ImPlot.ImPlotInputMap(),
            }
        end

        -- Temporary data storage for upcoming plot
        -- [Port] LinkedMin/LinkedMax are link refs: tables whose [1] holds the linked value (replaces double*)
        local NextPlotDataMT = {}
        NextPlotDataMT.__index = NextPlotDataMT
        function internal.ImPlotNextPlotData()
            local d = setmetatable({ RangeCond = {}, Range = {}, HasRange = {}, Fit = {}, LinkedMin = {}, LinkedMax = {} }, NextPlotDataMT)
            for i = 0, ImPlot.ImAxis.COUNT - 1 do
                d.RangeCond[i] = ImPlot.ImPlotCond.None
                d.Range[i]     = ImPlot.ImPlotRange(0, 0)
            end
            d:Reset()
            return d
        end
        function NextPlotDataMT:Reset()
            for i = 0, ImPlot.ImAxis.COUNT - 1 do
                self.HasRange[i]  = false
                self.Fit[i]       = false
                self.LinkedMin[i] = nil
                self.LinkedMax[i] = nil
            end
        end

        -- Input mapping structure. Default values listed. See also MapInputDefault, MapInputReverse.
        function ImPlot.ImPlotInputMap()
            local map = {}
            ImPlot.MapInputDefault(map)
            return map
        end

        function ImPlot.GetInputMap()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            return GImPlot.InputMap
        end

        function ImPlot.MapInputDefault(dst)
            local map = dst or ImPlot.GetInputMap()
            map.Pan           = G.ImGuiMouseButton.Left
            map.PanMod        = G.ImGuiMod_None
            map.Fit           = G.ImGuiMouseButton.Left
            map.Menu          = G.ImGuiMouseButton.Right
            map.Select        = G.ImGuiMouseButton.Right
            map.SelectMod     = G.ImGuiMod_None
            map.SelectCancel  = G.ImGuiMouseButton.Left
            map.SelectHorzMod = G.ImGuiMod_Alt
            map.SelectVertMod = G.ImGuiMod_Shift
            map.OverrideMod   = G.ImGuiMod_Ctrl
            map.ZoomMod       = G.ImGuiMod_None
            map.ZoomRate      = 0.1
        end

        function ImPlot.MapInputReverse(dst)
            local map = dst or ImPlot.GetInputMap()
            map.Pan           = G.ImGuiMouseButton.Right
            map.PanMod        = G.ImGuiMod_None
            map.Fit           = G.ImGuiMouseButton.Left
            map.Menu          = G.ImGuiMouseButton.Right
            map.Select        = G.ImGuiMouseButton.Left
            map.SelectMod     = G.ImGuiMod_None
            map.SelectCancel  = G.ImGuiMouseButton.Right
            map.SelectHorzMod = G.ImGuiMod_Alt
            map.SelectVertMod = G.ImGuiMod_Shift
            map.OverrideMod   = G.ImGuiMod_Ctrl
            map.ZoomMod       = G.ImGuiMod_None
            map.ZoomRate      = 0.1
        end

        function ImPlot.CreateContext()
            local ctx = internal.ImPlotContext()
            ctx.NextItemData = internal.ImPlotNextItemData()
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
            -- [Port] ResetCtxForNext* are no-ops on a freshly built context (all fields start nil/empty)
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

        -- [Port] ImVec4* / ImU32* overloads: `colormap` is a 1-based array of ImVec4 or ImU32; size defaults to #colormap
        function ImPlot.AddColormap(name, colormap, size, qual)
            local gp = GImPlot
            size = size or #colormap
            if qual == nil then qual = true end
            IM_ASSERT(size > 1, "The colormap size must be greater than 1!")
            IM_ASSERT(gp.ColormapData:GetIndex(name) == -1, "The colormap name has already been used!")
            local buffer = table.create(size)
            for i = 1, size do
                local c = colormap[i]
                buffer[i] = type(c) == "number" and c or ImGui.ColorConvertFloat4ToU32(c)
            end
            return gp.ColormapData:Append(name, buffer, size, qual)
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
            a.PickerTimeMin    = internal.ImPlotTime(0, 0)
            a.PickerTimeMax    = internal.ImPlotTime(0, 0)
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
            self.PickerTimeMin = internal.ImPlotTimeFromDouble(self.Range.Min)
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
            self.PickerTimeMax = internal.ImPlotTimeFromDouble(self.Range.Max)
            self:UpdateTransformCache()
            return true
        end

        -- [Port] SetRange(v1, v2) and SetRange(const ImPlotRange&) overloads
        function AxisMT:SetRange(v1, v2)
            if type(v1) == "table" then v1, v2 = v1.Min, v1.Max end
            self.Range.Min = math.min(v1, v2)
            self.Range.Max = math.max(v1, v2)
            self:Constrain()
            self.PickerTimeMin = internal.ImPlotTimeFromDouble(self.Range.Min)
            self.PickerTimeMax = internal.ImPlotTimeFromDouble(self.Range.Max)
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

        @native
        function AxisMT:ExtendFit(v)
            if not ImNanOrInf(v) and v >= self.ConstraintRange.Min and v <= self.ConstraintRange.Max then
                if v < self.FitExtents.Min then self.FitExtents.Min = v end
                if v > self.FitExtents.Max then self.FitExtents.Max = v end
            end
        end

        @native
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

        function AxisMT:IsPanLocked(increasing)
            if ImHasFlag(self.Flags, ImPlotAxisFlags.PanStretch) then
                return self:IsInputLocked()
            end
            if self:IsLockedMin() or self:IsLockedMax() or self:IsAutoFitting() then
                return false
            end
            if increasing then
                return self.Range.Max == self.ConstraintRange.Max
            end
            return self.Range.Min == self.ConstraintRange.Min
        end

        -- [Port] LinkedMin/LinkedMax are link refs (tables whose [1] holds the value) instead of double*
        function AxisMT:PushLinks()
            if self.LinkedMin then self.LinkedMin[1] = self.Range.Min end
            if self.LinkedMax then self.LinkedMax[1] = self.Range.Max end
        end

        function AxisMT:PullLinks()
            if self.LinkedMin and self.LinkedMax then
                self:SetRange(self.LinkedMin[1], self.LinkedMax[1])
            elseif self.LinkedMin then
                self:SetMin(self.LinkedMin[1], true)
            elseif self.LinkedMax then
                self:SetMax(self.LinkedMax[1], true)
            end
        end

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
            p.Items             = internal.ImPlotItemGroup()
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
        local Locator_Default = internal.Locator_Default
        local DBL_MIN = 2.2250738585072014e-308
        local DBL_EPSILON = 2.220446049250313e-16
        local function ImSign(v) if v < 0 then return -1 end return 1 end
        local function Trunc(v) if v < 0 then return math.ceil(v) end return math.floor(v) end -- [Port] C (int) cast

        -----------------------------------------------------------------------
        -- Transforms (implot_internal.h)
        -----------------------------------------------------------------------
        function internal.TransformForward_Log10(v, _)
            if v <= 0.0 then v = DBL_MIN end
            return math.log10(v)
        end
        function internal.TransformInverse_Log10(v, _)
            return 10 ^ v
        end
        -- [Port] Luau has no asinh/sinh builtin for asinh; asinh(x) = log(x + sqrt(x*x+1)) (sign-symmetric to stay accurate for x < 0)
        local function ImAsinh(x)
            local a = math.abs(x)
            return ImSign(x) * math.log(a + math.sqrt(a * a + 1))
        end
        function internal.TransformForward_SymLog(v, _)
            return 2.0 * ImAsinh(v / 2.0)
        end
        function internal.TransformInverse_SymLog(v, _)
            return 2.0 * math.sinh(v / 2.0)
        end
        local TransformForward_SymLog = internal.TransformForward_SymLog

        -----------------------------------------------------------------------
        -- Log locators
        -----------------------------------------------------------------------
        -- [Port] returns ok, exp_min, exp_max, exp_step instead of out-params
        function internal.CalcLogarithmicExponents(range, pix, vertical)
            if range.Min * range.Max > 0 then
                local nMajor
                if vertical then
                    nMajor = math.max(2, math.floor(pix * 0.02 + 0.5))
                else
                    nMajor = math.max(2, math.floor(pix * 0.01 + 0.5)) -- TODO: magic numbers
                end
                local log_min = math.log10(math.abs(range.Min))
                local log_max = math.log10(math.abs(range.Max))
                local log_a = math.min(log_min, log_max)
                local log_b = math.max(log_min, log_max)
                local exp_step = math.max(1, Trunc(Trunc(log_b - log_a) / nMajor))
                local exp_min = Trunc(log_a)
                local exp_max = Trunc(log_b)
                if exp_step ~= 1 then
                    while exp_step % 3 ~= 0 do exp_step += 1 end -- make step size multiple of three
                    while math.fmod(exp_min, exp_step) ~= 0 do exp_min -= 1 end -- decrease exp_min until exp_min + N * exp_step will be 0
                end
                return true, exp_min, exp_max, exp_step
            end
            return false, 0, 0, 1
        end
        local CalcLogarithmicExponents = internal.CalcLogarithmicExponents

        function internal.AddTicksLogarithmic(range, exp_min, exp_max, exp_step, ticker, formatter, data)
            local sign = ImSign(range.Max)
            local e = exp_min - exp_step
            while e < exp_max + exp_step do
                local major1 = sign * 10 ^ e
                if major1 >= range.Min - DBL_EPSILON and major1 <= range.Max + DBL_EPSILON then
                    ticker:AddTick(major1, true, 0, true, formatter, data)
                end
                for j = 0, exp_step - 1 do
                    major1 = sign * 10 ^ (e + j)
                    local major2 = sign * 10 ^ (e + j + 1)
                    local interval = (major2 - major1) / 9
                    local n = 9
                    if j < exp_step - 1 then n = 10 end
                    for i = 1, n - 1 do
                        local minor = major1 + i * interval
                        if minor >= range.Min - DBL_EPSILON and minor <= range.Max + DBL_EPSILON then
                            ticker:AddTick(minor, false, 0, false, formatter, data)
                        end
                    end
                end
                e += exp_step
            end
        end
        local AddTicksLogarithmic = internal.AddTicksLogarithmic

        function internal.Locator_Log10(ticker, range, pixels, vertical, formatter, formatter_data)
            local ok, exp_min, exp_max, exp_step = CalcLogarithmicExponents(range, pixels, vertical)
            if ok then
                AddTicksLogarithmic(range, exp_min, exp_max, exp_step, ticker, formatter, formatter_data)
            end
        end

        local function CalcSymLogPixel(plt, range, pixels)
            local scaleToPixels = pixels / range:Size()
            local scaleMin      = TransformForward_SymLog(range.Min, nil)
            local scaleMax      = TransformForward_SymLog(range.Max, nil)
            local s             = TransformForward_SymLog(plt, nil)
            local t             = (s - scaleMin) / (scaleMax - scaleMin)
            plt                 = range.Min + range:Size() * t
            return 0 + scaleToPixels * (plt - range.Min)
        end

        function internal.Locator_SymLog(ticker, range, pixels, vertical, formatter, formatter_data)
            if range.Min >= -1 and range.Max <= 1 then
                Locator_Default(ticker, range, pixels, vertical, formatter, formatter_data)
            elseif range.Min * range.Max < 0 then -- cross zero
                local pix_min = 0
                local pix_max = pixels
                local pix_p1  = CalcSymLogPixel(1, range, pixels)
                local pix_n1  = CalcSymLogPixel(-1, range, pixels)
                local rp = ImPlot.ImPlotRange(1, range.Max)
                local rn = ImPlot.ImPlotRange(range.Min, -1)
                local _, exp_min_p, exp_max_p, exp_step_p = CalcLogarithmicExponents(rp, math.abs(pix_max - pix_p1), vertical)
                local _, exp_min_n, exp_max_n, exp_step_n = CalcLogarithmicExponents(rn, math.abs(pix_n1 - pix_min), vertical)
                local exp_step = math.max(exp_step_n, exp_step_p)
                ticker:AddTick(0, true, 0, true, formatter, formatter_data)
                AddTicksLogarithmic(rp, exp_min_p, exp_max_p, exp_step, ticker, formatter, formatter_data)
                AddTicksLogarithmic(rn, exp_min_n, exp_max_n, exp_step, ticker, formatter, formatter_data)
            else
                internal.Locator_Log10(ticker, range, pixels, vertical, formatter, formatter_data)
            end
        end

        -- [Port] labels is a 1-based array of strings (or nil); values is a 1-based array
        function internal.AddTicksCustom(values, labels, n, ticker, formatter, data)
            for i = 1, n do
                if labels ~= nil then
                    ticker:AddTick(values[i], false, 0, true, labels[i])
                else
                    ticker:AddTick(values[i], false, 0, true, formatter, data)
                end
            end
        end

        -----------------------------------------------------------------------
        -- Time Ticks and Utils
        -----------------------------------------------------------------------
        internal.IMPLOT_MIN_TIME = 0
        internal.IMPLOT_MAX_TIME = 32503680000
        local IMPLOT_MAX_TIME = internal.IMPLOT_MAX_TIME

        local ImPlotTimeUnit = {
            Us = 0,  -- microsecond
            Ms = 1,  -- millisecond
            S = 2,   -- second
            Min = 3, -- minute
            Hr = 4,  -- hour
            Day = 5, -- day
            Mo = 6,  -- month
            Yr = 7,  -- year
            COUNT = 8,
        }
        internal.ImPlotTimeUnit = ImPlotTimeUnit
        local ImPlotDateFmt = {  -- default        [ ISO 8601     ]
            None = 0,
            DayMo = 1,           -- 10/3           [ --10-03      ]
            DayMoYr = 2,         -- 10/3/91        [ 1991-10-03   ]
            MoYr = 3,            -- Oct 1991       [ 1991-10      ]
            Mo = 4,              -- Oct            [ --10         ]
            Yr = 5,              -- 1991           [ 1991         ]
        }
        internal.ImPlotDateFmt = ImPlotDateFmt
        local ImPlotTimeFmt = {  -- default        [ 24 Hour Clock ]
            None = 0,
            Us = 1,              -- .428 552       [ .428 552     ]
            SUs = 2,             -- :29.428 552    [ :29.428 552  ]
            SMs = 3,             -- :29.428        [ :29.428      ]
            S = 4,               -- :29            [ :29          ]
            MinSMs = 5,          -- 21:29.428      [ 21:29.428    ]
            HrMinSMs = 6,        -- 7:21:29.428pm  [ 19:21:29.428 ]
            HrMinS = 7,          -- 7:21:29pm      [ 19:21:29     ]
            HrMin = 8,           -- 7:21pm         [ 19:21        ]
            Hr = 9,              -- 7pm            [ 19:00        ]
        }
        internal.ImPlotTimeFmt = ImPlotTimeFmt

        function internal.ImPlotDateTimeSpec(date_fmt, time_fmt, use_24_hr_clk, use_iso_8601)
            return { Date = date_fmt, Time = time_fmt, UseISO8601 = use_iso_8601 or false, Use24HourClock = use_24_hr_clk or false }
        end
        local ImPlotDateTimeSpec = internal.ImPlotDateTimeSpec

        -- Two part timestamp struct.
        local TimeMT = {}
        TimeMT.__index = TimeMT
        -- [Port] C integer division/modulo truncate toward zero
        local function ImPlotTime(s, us)
            s = s or 0; us = us or 0
            return setmetatable({ S = s + Trunc(us / 1000000), Us = math.fmod(us, 1000000) }, TimeMT)
        end
        internal.ImPlotTime = ImPlotTime
        function TimeMT:RollOver() self.S = self.S + Trunc(self.Us / 1000000); self.Us = math.fmod(self.Us, 1000000) end
        function TimeMT:ToDouble() return self.S + self.Us / 1000000.0 end
        function internal.ImPlotTimeFromDouble(t)
            return ImPlotTime(Trunc(t), Trunc(t * 1000000 - math.floor(t) * 1000000))
        end
        local FromDouble = internal.ImPlotTimeFromDouble
        TimeMT.__add = function(l, r) return ImPlotTime(l.S + r.S, l.Us + r.Us) end
        TimeMT.__sub = function(l, r) return ImPlotTime(l.S - r.S, l.Us - r.Us) end
        TimeMT.__eq = function(l, r) return l.S == r.S and l.Us == r.Us end
        TimeMT.__lt = function(l, r)
            if l.S == r.S then return l.Us < r.Us end
            return l.S < r.S
        end
        TimeMT.__le = function(l, r) return not (r < l) end

        local function IsLeapYear(year)
            return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
        end
        local DAYS_IN_MONTH = { [0] = 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
        local function GetDaysInMonth(year, month)
            local d = DAYS_IN_MONTH[month]
            if month == 1 and IsLeapYear(year) then d += 1 end
            return d
        end
        internal.IsLeapYear = IsLeapYear
        internal.GetDaysInMonth = GetDaysInMonth

        -- [Port] tm structs are tables with C field names (tm_year since 1900, tm_mon 0-11, tm_mday, tm_hour, tm_min, tm_sec).
        -- MkGmtTime implements timegm with days-from-civil arithmetic (os.time(table) semantics differ across Lua hosts).
        local function DaysFromCivil(y, m, d) -- m 1-12
            if m <= 2 then y -= 1 end
            local era = math.floor(y / 400)
            local yoe = y - era * 400
            local mp = (m + 9) % 12
            local doy = math.floor((153 * mp + 2) / 5) + d - 1
            local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
            return era * 146097 + doe - 719468
        end
        local function TimeGm(ptm)
            local mon = ptm.tm_mon
            local year = ptm.tm_year + 1900 + math.floor(mon / 12)
            mon = mon % 12
            return DaysFromCivil(year, mon + 1, 1) * 86400 + (ptm.tm_mday - 1) * 86400
                + ptm.tm_hour * 3600 + ptm.tm_min * 60 + ptm.tm_sec
        end
        local function FromOsDate(d, ptm)
            ptm.tm_year = d.year - 1900; ptm.tm_mon = d.month - 1; ptm.tm_mday = d.day
            ptm.tm_hour = d.hour; ptm.tm_min = d.min; ptm.tm_sec = d.sec
            ptm.tm_wday = d.wday - 1; ptm.tm_yday = d.yday - 1
            return ptm
        end

        function internal.MkGmtTime(ptm)
            local t = ImPlotTime(TimeGm(ptm), 0)
            if t.S < 0 then t.S = 0 end
            return t
        end
        -- [Port] gmtime via civil-from-days arithmetic (equivalent to os.date('!*t'), but works on hosts without os.date)
        function internal.GetGmtTime(t, ptm)
            local s = t.S
            local z = math.floor(s / 86400)
            local secs = s - z * 86400
            ptm.tm_wday = (z + 4) % 7
            z += 719468
            local era = math.floor(z / 146097)
            local doe = z - era * 146097
            local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
            local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
            local mp = math.floor((5 * doy + 2) / 153)
            local d = doy - math.floor((153 * mp + 2) / 5) + 1
            local m = mp + 3
            if m > 12 then m -= 12 end
            local y = yoe + era * 400
            if m <= 2 then y += 1 end
            ptm.tm_year = y - 1900; ptm.tm_mon = m - 1; ptm.tm_mday = d
            ptm.tm_hour = math.floor(secs / 3600); ptm.tm_min = math.floor(secs / 60) % 60; ptm.tm_sec = secs % 60
            ptm.tm_yday = DaysFromCivil(y, m, d) - DaysFromCivil(y, 1, 1)
            return ptm
        end
        -- [Port] local time: offset of local clock from UTC at that instant, from os.date('*t') vs os.date('!*t')
        local function LocalOffset(s)
            local tmp = {}
            return TimeGm(FromOsDate(os.date("*t", s), tmp)) - TimeGm(FromOsDate(os.date("!*t", s), tmp))
        end
        function internal.MkLocTime(ptm)
            local s = TimeGm(ptm)
            local t = ImPlotTime(s - LocalOffset(s), 0)
            if t.S < 0 then t.S = 0 end
            return t
        end
        function internal.GetLocTime(t, ptm)
            local d = os.date("*t", t.S)
            if d == nil then return nil end
            return FromOsDate(d, ptm)
        end
        local function MkTime(ptm)
            if ImPlot.GetStyle().UseLocalTime then return internal.MkLocTime(ptm) end
            return internal.MkGmtTime(ptm)
        end
        local function GetTime(t, ptm)
            if ImPlot.GetStyle().UseLocalTime then return internal.GetLocTime(t, ptm) end
            return internal.GetGmtTime(t, ptm)
        end
        internal.MkTime = MkTime
        internal.GetTime = GetTime

        -- [Port] GImPlot->Tm is a module-level scratch table
        local Tm = { tm_year = 70, tm_mon = 0, tm_mday = 1, tm_hour = 0, tm_min = 0, tm_sec = 0, tm_wday = 0, tm_yday = 0 }

        -- Make a timestamp from time components.
        -- year[1970-3000], month[0-11], day[1-31], hour[0-23], min[0-59], sec[0-59], us[0,999999]
        function internal.MakeTime(year, month, day, hour, min, sec, us)
            month = month or 0; day = day or 1; hour = hour or 0; min = min or 0; sec = sec or 0; us = us or 0
            local yr = year - 1900
            if yr < 0 then yr = 0 end
            sec = sec + Trunc(us / 1000000)
            us  = math.fmod(us, 1000000)
            Tm.tm_sec  = sec
            Tm.tm_min  = min
            Tm.tm_hour = hour
            Tm.tm_mday = day
            Tm.tm_mon  = month
            Tm.tm_year = yr
            local t = MkTime(Tm)
            t.Us = us
            return t
        end
        local MakeTime = internal.MakeTime

        function internal.GetYear(t)
            GetTime(t, Tm)
            return Tm.tm_year + 1900
        end
        function internal.GetMonth(t)
            GetTime(t, Tm)
            return Tm.tm_mon
        end
        local GetYear = internal.GetYear

        -- Adds or subtracts time from a timestamp. #count > 0 to add, < 0 to subtract.
        function internal.AddTime(t, unit, count)
            local t_out = ImPlotTime(t.S, t.Us)
            if unit == ImPlotTimeUnit.Us then
                t_out.Us += count
            elseif unit == ImPlotTimeUnit.Ms then
                t_out.Us += count * 1000
            elseif unit == ImPlotTimeUnit.S then
                t_out.S += count
            elseif unit == ImPlotTimeUnit.Min then
                t_out.S += count * 60
            elseif unit == ImPlotTimeUnit.Hr then
                t_out.S += count * 3600
            elseif unit == ImPlotTimeUnit.Day then
                t_out.S += count * 86400
            elseif unit == ImPlotTimeUnit.Mo then
                for _ = 1, math.abs(count) do
                    GetTime(t_out, Tm)
                    if count > 0 then
                        t_out.S += 86400 * GetDaysInMonth(Tm.tm_year + 1900, Tm.tm_mon)
                    elseif count < 0 then
                        local y, m = Tm.tm_year + 1900, Tm.tm_mon - 1
                        if Tm.tm_mon == 0 then y -= 1; m = 11 end
                        t_out.S -= 86400 * GetDaysInMonth(y, m) -- NOT WORKING
                    end
                end
            elseif unit == ImPlotTimeUnit.Yr then
                for _ = 1, math.abs(count) do
                    if count > 0 then
                        t_out.S += 86400 * (365 + ((IsLeapYear(GetYear(t_out)) and 1) or 0))
                    elseif count < 0 then
                        t_out.S -= 86400 * (365 + ((IsLeapYear(GetYear(t_out) - 1) and 1) or 0))
                    end
                    -- this is incorrect if leap year and we are past Feb 28
                end
            end
            t_out:RollOver()
            return t_out
        end
        local AddTime = internal.AddTime

        -- Rounds a timestamp down to nearest unit.
        function internal.FloorTime(t, unit)
            GetTime(t, Tm)
            if unit == ImPlotTimeUnit.S then return ImPlotTime(t.S, 0) end
            if unit == ImPlotTimeUnit.Ms then return ImPlotTime(t.S, Trunc(t.Us / 1000) * 1000) end
            if unit == ImPlotTimeUnit.Us or unit > ImPlotTimeUnit.Yr then return ImPlotTime(t.S, t.Us) end
            -- [Port] switch fall-through
            if unit >= ImPlotTimeUnit.Yr then Tm.tm_mon = 0 end
            if unit >= ImPlotTimeUnit.Mo then Tm.tm_mday = 1 end
            if unit >= ImPlotTimeUnit.Day then Tm.tm_hour = 0 end
            if unit >= ImPlotTimeUnit.Hr then Tm.tm_min = 0 end
            Tm.tm_sec = 0
            return MkTime(Tm)
        end
        local FloorTime = internal.FloorTime
        -- Rounds a timestamp up to the nearest unit.
        function internal.CeilTime(t, unit)
            return AddTime(FloorTime(t, unit), unit, 1)
        end
        -- Rounds a timestamp up or down to the nearest unit.
        function internal.RoundTime(t, unit)
            local t1 = FloorTime(t, unit)
            local t2 = AddTime(t1, unit, 1)
            if t1.S == t2.S then
                if t.Us - t1.Us < t2.Us - t.Us then return t1 end
                return t2
            end
            if t.S - t1.S < t2.S - t.S then return t1 end
            return t2
        end
        -- Combines the date of one timestamp with the time-of-day of another timestamp.
        function internal.CombineDateTime(date_part, tod_part)
            GetTime(date_part, Tm)
            local y, m, d = Tm.tm_year, Tm.tm_mon, Tm.tm_mday
            GetTime(tod_part, Tm)
            Tm.tm_year = y
            Tm.tm_mon  = m
            Tm.tm_mday = d
            local t = MkTime(Tm)
            t.Us = tod_part.Us
            return t
        end
        function internal.Now() return FromDouble(os.time()) end
        function internal.Today() return FloorTime(internal.Now(), ImPlotTimeUnit.Day) end

        -- TODO: allow users to define these
        internal.MONTH_NAMES = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
        internal.WD_ABRVS    = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
        local MONTH_ABRVS    = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
        internal.MONTH_ABRVS = MONTH_ABRVS

        -- [Port] Format* return the string instead of writing to a buffer ("" for None)
        local sf = string.format
        function internal.FormatTime(t, fmt, use_24_hr_clk)
            GetTime(t, Tm)
            local us  = math.fmod(t.Us, 1000)
            local ms  = Trunc(t.Us / 1000)
            local sec = Tm.tm_sec
            local min = Tm.tm_min
            local F = ImPlotTimeFmt
            if fmt == F.Us then return sf(".%03d %03d", ms, us) end
            if fmt == F.SUs then return sf(":%02d.%03d %03d", sec, ms, us) end
            if fmt == F.SMs then return sf(":%02d.%03d", sec, ms) end
            if fmt == F.S then return sf(":%02d", sec) end
            if fmt == F.MinSMs then return sf(":%02d:%02d.%03d", min, sec, ms) end
            if use_24_hr_clk then
                local hr = Tm.tm_hour
                if fmt == F.HrMinSMs then return sf("%02d:%02d:%02d.%03d", hr, min, sec, ms) end
                if fmt == F.HrMinS then return sf("%02d:%02d:%02d", hr, min, sec) end
                if fmt == F.HrMin then return sf("%02d:%02d", hr, min) end
                if fmt == F.Hr then return sf("%02d:00", hr) end
            else
                local ap = "pm"
                if Tm.tm_hour < 12 then ap = "am" end
                local hr = Tm.tm_hour % 12
                if Tm.tm_hour == 0 or Tm.tm_hour == 12 then hr = 12 end
                if fmt == F.HrMinSMs then return sf("%d:%02d:%02d.%03d%s", hr, min, sec, ms, ap) end
                if fmt == F.HrMinS then return sf("%d:%02d:%02d%s", hr, min, sec, ap) end
                if fmt == F.HrMin then return sf("%d:%02d%s", hr, min, ap) end
                if fmt == F.Hr then return sf("%d%s", hr, ap) end
            end
            return ""
        end
        local FormatTime = internal.FormatTime

        function internal.FormatDate(t, fmt, use_iso_8601)
            GetTime(t, Tm)
            local day  = Tm.tm_mday
            local mon  = Tm.tm_mon + 1
            local year = Tm.tm_year + 1900
            local yr   = year % 100
            local F = ImPlotDateFmt
            if use_iso_8601 then
                if fmt == F.DayMo then return sf("--%02d-%02d", mon, day) end
                if fmt == F.DayMoYr then return sf("%d-%02d-%02d", year, mon, day) end
                if fmt == F.MoYr then return sf("%d-%02d", year, mon) end
                if fmt == F.Mo then return sf("--%02d", mon) end
                if fmt == F.Yr then return sf("%d", year) end
            else
                if fmt == F.DayMo then return sf("%d/%d", mon, day) end
                if fmt == F.DayMoYr then return sf("%d/%d/%02d", mon, day, yr) end
                if fmt == F.MoYr then return sf("%s %d", MONTH_ABRVS[Tm.tm_mon + 1], year) end
                if fmt == F.Mo then return MONTH_ABRVS[Tm.tm_mon + 1] end
                if fmt == F.Yr then return sf("%d", year) end
            end
            return ""
        end
        local FormatDate = internal.FormatDate

        function internal.FormatDateTime(t, fmt)
            local out = ""
            if fmt.Date ~= ImPlotDateFmt.None then
                out = FormatDate(t, fmt.Date, fmt.UseISO8601)
            end
            if fmt.Time ~= ImPlotTimeFmt.None then
                if fmt.Date ~= ImPlotDateFmt.None then
                    out ..= " "
                end
                out ..= FormatTime(t, fmt.Time, fmt.Use24HourClock)
            end
            return out
        end
        local FormatDateTime = internal.FormatDateTime

        local t_max_width = nil
        local function GetDateTimeWidth(fmt)
            if t_max_width == nil then
                t_max_width = MakeTime(2888, 12, 22, 12, 58, 58, 888888) -- best guess at time that maximizes pixel width
            end
            return ImGui.CalcTextSize(FormatDateTime(t_max_width, fmt)).x
        end

        local function TimeLabelSame(l1, l2)
            local n = math.min(#l1, #l2)
            return string.sub(l1, #l1 - n + 1) == string.sub(l2, #l2 - n + 1)
        end

        local D, T = ImPlotDateFmt, ImPlotTimeFmt
        -- [Port] spec tables are indexed by ImPlotTimeUnit (0-based)
        local TimeFormatLevel0 = {
            [0] = ImPlotDateTimeSpec(D.None, T.Us),
            ImPlotDateTimeSpec(D.None, T.SMs),
            ImPlotDateTimeSpec(D.None, T.S),
            ImPlotDateTimeSpec(D.None, T.HrMin),
            ImPlotDateTimeSpec(D.None, T.Hr),
            ImPlotDateTimeSpec(D.DayMo, T.None),
            ImPlotDateTimeSpec(D.Mo, T.None),
            ImPlotDateTimeSpec(D.Yr, T.None),
        }
        local TimeFormatLevel1 = {
            [0] = ImPlotDateTimeSpec(D.None, T.HrMin),
            ImPlotDateTimeSpec(D.None, T.HrMinS),
            ImPlotDateTimeSpec(D.None, T.HrMin),
            ImPlotDateTimeSpec(D.None, T.HrMin),
            ImPlotDateTimeSpec(D.DayMoYr, T.None),
            ImPlotDateTimeSpec(D.DayMoYr, T.None),
            ImPlotDateTimeSpec(D.Yr, T.None),
            ImPlotDateTimeSpec(D.Yr, T.None),
        }
        local TimeFormatLevel1First = {
            [0] = ImPlotDateTimeSpec(D.DayMoYr, T.HrMinS),
            ImPlotDateTimeSpec(D.DayMoYr, T.HrMinS),
            ImPlotDateTimeSpec(D.DayMoYr, T.HrMin),
            ImPlotDateTimeSpec(D.DayMoYr, T.HrMin),
            ImPlotDateTimeSpec(D.DayMoYr, T.None),
            ImPlotDateTimeSpec(D.DayMoYr, T.None),
            ImPlotDateTimeSpec(D.Yr, T.None),
            ImPlotDateTimeSpec(D.Yr, T.None),
        }
        internal.TimeFormatMouseCursor = {
            [0] = ImPlotDateTimeSpec(D.None, T.Us),
            ImPlotDateTimeSpec(D.None, T.SUs),
            ImPlotDateTimeSpec(D.None, T.SMs),
            ImPlotDateTimeSpec(D.None, T.HrMinS),
            ImPlotDateTimeSpec(D.None, T.HrMin),
            ImPlotDateTimeSpec(D.DayMo, T.Hr),
            ImPlotDateTimeSpec(D.DayMoYr, T.None),
            ImPlotDateTimeSpec(D.MoYr, T.None),
        }

        local function GetDateTimeFmt(ctx, idx)
            local style = ImPlot.GetStyle()
            local src = ctx[idx]
            return ImPlotDateTimeSpec(src.Date, src.Time, style.Use24HourClock, style.UseISO8601)
        end
        internal.GetDateTimeFmt = GetDateTimeFmt

        -- this may not be thread safe?
        local TimeUnitSpans = { [0] = 0.000001, 0.001, 1, 60, 3600, 86400, 2629800, 31557600 }
        local TimeUnitCutoffs = { [0] = 0.001, 1, 60, 3600, 86400, 2629800, 31557600, IMPLOT_MAX_TIME }
        local function GetUnitForRange(range)
            for i = 0, ImPlotTimeUnit.COUNT - 1 do
                if range <= TimeUnitCutoffs[i] then
                    return i
                end
            end
            return ImPlotTimeUnit.Yr
        end
        internal.GetUnitForRange = GetUnitForRange

        local function LowerBoundStep(max_divs, divs, step)
            if max_divs < divs[1] then
                return 0
            end
            for i = 2, #divs do
                if max_divs < divs[i] then
                    return step[i - 1]
                end
            end
            return step[#step]
        end
        local function GetTimeStep(max_divs, unit)
            if unit == ImPlotTimeUnit.Ms or unit == ImPlotTimeUnit.Us then
                return LowerBoundStep(max_divs, { 2, 4, 5, 10, 20, 40, 50, 100, 200, 500, 1000 }, { 500, 250, 200, 100, 50, 25, 20, 10, 5, 2, 1 })
            end
            if unit == ImPlotTimeUnit.S or unit == ImPlotTimeUnit.Min then
                return LowerBoundStep(max_divs, { 2, 4, 6, 12, 60 }, { 30, 15, 10, 5, 1 })
            elseif unit == ImPlotTimeUnit.Hr then
                return LowerBoundStep(max_divs, { 2, 4, 8, 12, 24 }, { 12, 6, 3, 2, 1 })
            elseif unit == ImPlotTimeUnit.Day then
                return LowerBoundStep(max_divs, { 2, 4, 14, 28 }, { 14, 7, 2, 1 })
            elseif unit == ImPlotTimeUnit.Mo then
                return LowerBoundStep(max_divs, { 2, 4, 6, 12 }, { 6, 3, 2, 1 })
            end
            return 0
        end

        -- [Port] Formatter_Time_Data is a table { Time, Spec, UserFormatter, UserFormatterData }
        function internal.Formatter_Time(_, ftd)
            return FormatDateTime(ftd.Time, ftd.Spec)
        end
        local Formatter_Time = internal.Formatter_Time

        function internal.Locator_Time(ticker, range, pixels, vertical, formatter, formatter_data)
            IM_ASSERT(vertical == false, "Cannot locate Time ticks on vertical axis!")
            -- get units for level 0 and level 1 labels
            local unit0 = GetUnitForRange(range:Size() / (pixels / 100)) -- level = 0 (top)
            local unit1 = math.clamp(unit0 + 1, 0, ImPlotTimeUnit.COUNT - 1) -- level = 1 (bottom)
            -- get time format specs
            local fmt0 = GetDateTimeFmt(TimeFormatLevel0, unit0)
            local fmt1 = GetDateTimeFmt(TimeFormatLevel1, unit1)
            local fmtf = GetDateTimeFmt(TimeFormatLevel1First, unit1)
            -- min max times
            local t_min = FromDouble(range.Min)
            local t_max = FromDouble(range.Max)
            -- maximum allowable density of labels
            local max_density = 0.5
            -- book keeping
            local last_major = nil -- [Port] label string instead of last_major_offset
            -- formatter data
            local ftd = { Time = nil, Spec = nil, UserFormatter = formatter, UserFormatterData = formatter_data }
            if unit0 ~= ImPlotTimeUnit.Yr then
                -- pixels per major (level 1) division
                local pix_per_major_div = pixels / (range:Size() / TimeUnitSpans[unit1])
                -- nominal pixels taken up by labels
                local fmt0_width = GetDateTimeWidth(fmt0)
                local fmt1_width = GetDateTimeWidth(fmt1)
                local fmtf_width = GetDateTimeWidth(fmtf)
                -- the maximum number of minor (level 0) labels that can fit between major (level 1) divisions
                local minor_per_major = Trunc(max_density * pix_per_major_div / fmt0_width)
                -- the minor step size (level 0)
                local step = GetTimeStep(minor_per_major, unit0)
                -- generate ticks
                local t1 = FloorTime(FromDouble(range.Min), unit1)
                while t1 < t_max do
                    -- get next major
                    local t2 = AddTime(t1, unit1, 1)
                    -- add major tick
                    if t1 >= t_min and t1 <= t_max then
                        -- minor level 0 tick
                        ftd.Time = t1; ftd.Spec = fmt0
                        ticker:AddTick(t1:ToDouble(), true, 0, true, Formatter_Time, ftd)
                        -- major level 1 tick
                        ftd.Time = t1
                        if last_major == nil then ftd.Spec = fmtf else ftd.Spec = fmt1 end
                        local tick_maj = ticker:AddTick(t1:ToDouble(), true, 1, true, Formatter_Time, ftd)
                        local this_major = tick_maj.Text
                        if last_major ~= nil and TimeLabelSame(last_major, this_major) then
                            tick_maj.ShowLabel = false
                        end
                        last_major = this_major
                    end
                    -- add minor ticks up until next major
                    if minor_per_major > 1 and (t_min <= t2 and t1 <= t_max) then
                        local t12 = AddTime(t1, unit0, step)
                        while t12 < t2 do
                            local px_to_t2 = ((t2 - t12):ToDouble() / range:Size()) * pixels
                            if t12 >= t_min and t12 <= t_max then
                                ftd.Time = t12; ftd.Spec = fmt0
                                ticker:AddTick(t12:ToDouble(), false, 0, px_to_t2 >= fmt0_width, Formatter_Time, ftd)
                                if last_major == nil and px_to_t2 >= fmt0_width and px_to_t2 >= (fmt1_width + fmtf_width) / 2 then
                                    ftd.Time = t12; ftd.Spec = fmtf
                                    local tick_maj = ticker:AddTick(t12:ToDouble(), true, 1, true, Formatter_Time, ftd)
                                    last_major = tick_maj.Text
                                end
                            end
                            t12 = AddTime(t12, unit0, step)
                        end
                    end
                    t1 = t2
                end
            else
                local fmty        = GetDateTimeFmt(TimeFormatLevel0, ImPlotTimeUnit.Yr)
                local label_width = GetDateTimeWidth(fmty)
                local max_labels  = Trunc(max_density * pixels / label_width)
                local year_min    = GetYear(t_min)
                local year_max    = GetYear(internal.CeilTime(t_max, ImPlotTimeUnit.Yr))
                local nice_range  = internal.NiceNum((year_max - year_min) * 0.99, false)
                local interval    = internal.NiceNum(nice_range / (max_labels - 1), true)
                local graphmin    = Trunc(math.floor(year_min / interval) * interval)
                local graphmax    = Trunc(math.ceil(year_max / interval) * interval)
                local step        = Trunc(interval)
                if step <= 0 then step = 1 end
                local y = graphmin
                while y < graphmax do
                    local t = MakeTime(y)
                    if t >= t_min and t <= t_max then
                        ftd.Time = t; ftd.Spec = fmty
                        ticker:AddTick(t:ToDouble(), true, 0, true, Formatter_Time, ftd)
                    end
                    y += step
                end
            end
        end
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
        local HUGE_VAL = math.huge
        local DBL_EPSILON = 2.220446049250313e-16

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
            -- reset annotations
            table.clear(ctx.Annotations)
            table.clear(ctx.Tags)
            -- reset legend items
            ctx.NextItemData:Reset()
            ctx.NextPlotData:Reset()
            ctx.OpenContextThisFrame = false
            -- reset digital plot items count
            ctx.DigitalPlotItemCnt = 0
            ctx.DigitalPlotOffset = 0
            -- nullify plot
            ctx.CurrentPlot  = nil
            ctx.CurrentItem  = nil
            ctx.PreviousItem = nil
        end

        function internal.ResetCtxForNextAlignedPlots(ctx)
            ctx.CurrentAlignmentH = nil
            ctx.CurrentAlignmentV = nil
        end

        function internal.ResetCtxForNextSubplot(ctx)
            ctx.CurrentSubplot    = nil
            ctx.CurrentAlignmentH = nil
            ctx.CurrentAlignmentV = nil
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
                count_T, count_B = 0, 0
                local delta_T, delta_B
                pad_T, pad_B, delta_T, delta_B = align:Update(pad_T, pad_B)
                for i = IMPLOT_NUM_X_AXES - 1, 0, -1 do
                    local axis = plot:XAxis(i)
                    if axis.Enabled then
                        if axis:IsOpposite() then
                            axis.Datum1 += delta_T
                            if count_T > 1 then axis.Datum2 += delta_T end
                            count_T += 1
                        else
                            axis.Datum1 -= delta_B
                            if count_B > 1 then axis.Datum2 -= delta_B end
                            count_B += 1
                        end
                    end
                end
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
                count_L, count_R = 0, 0
                local delta_L, delta_R
                pad_L, pad_R, delta_L, delta_R = align:Update(pad_L, pad_R)
                for i = IMPLOT_NUM_Y_AXES - 1, 0, -1 do
                    local axis = plot:YAxis(i)
                    if axis.Enabled then
                        if axis:IsOpposite() then
                            axis.Datum1 -= delta_R
                            if count_R > 1 then axis.Datum2 -= delta_R end
                            count_R += 1
                        else
                            axis.Datum1 += delta_L
                            if count_L > 1 then axis.Datum2 += delta_L end
                            count_L += 1
                        end
                    end
                end
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

        -----------------------------------------------------------------------
        -- Context Menu
        -----------------------------------------------------------------------

        -- [Port] DragFloat<double> -> ImGui.DragScalar(Double); returns (value, changed)
        local function DragFloat(label, v, v_speed, v_min, v_max)
            return ImGui.DragScalar(label, G.ImGuiDataType.Double, v, v_speed, v_min, v_max, "%.3g", 1)
        end

        local function BeginDisabledControls(cond)
            if cond then
                ImGui.PushItemFlag(G.ImGuiItemFlags.Disabled, true)
                ImGui.PushStyleVar(G.ImGuiStyleVar.Alpha, ImGui.GetStyle().Alpha * 0.25)
            end
        end

        local function EndDisabledControls(cond)
            if cond then
                ImGui.PopItemFlag()
                ImGui.PopStyleVar()
            end
        end

        local function ImFlipFlag(flags, flag)
            if ImHasFlag(flags, flag) then
                return bit32.band(flags, bit32.bnot(flag))
            end
            return bit32.bor(flags, flag)
        end

        internal.BeginDisabledControls = BeginDisabledControls
        internal.EndDisabledControls = EndDisabledControls

        function internal.ShowAxisContextMenu(axis, equal_axis, _time_allowed)
            ImGui.PushItemWidth(75)
            local always_locked = axis:IsRangeLocked() or axis:IsAutoFitting()
            local label         = axis:HasLabel()
            local grid          = axis:HasGridLines()
            local ticks         = axis:HasTickMarks()
            local labels        = axis:HasTickLabels()
            local drag_speed    = 0.01 * axis.Range:Size()
            if axis.Range:Size() <= DBL_EPSILON then
                drag_speed = DBL_EPSILON * 1.0e+13 -- recover from almost equal axis limits.
            end
            local _

            if axis.Scale == ImPlotScale.Time then
                local FromDouble, AddTime, S_ = internal.ImPlotTimeFromDouble, internal.AddTime, internal.ImPlotTimeUnit.S
                local tmin = FromDouble(axis.Range.Min)
                local tmax = FromDouble(axis.Range.Max)
                local clk

                BeginDisabledControls(always_locked)
                _, axis.Flags = ImGui.CheckboxFlags("##LockMin", axis.Flags, ImPlotAxisFlags.LockMin)
                EndDisabledControls(always_locked)
                ImGui.SameLine()
                local dis_min = axis:IsLockedMin() or always_locked
                BeginDisabledControls(dis_min)
                if ImGui.BeginMenu("Min Time") then
                    clk, tmin = internal.ShowTimePicker("mintime", tmin)
                    if clk then
                        if tmin >= tmax then tmax = AddTime(tmin, S_, 1) end
                        axis:SetRange(tmin:ToDouble(), tmax:ToDouble())
                    end
                    ImGui.Separator()
                    clk, axis.PickerLevel, axis.PickerTimeMin = internal.ShowDatePicker("mindate", axis.PickerLevel, axis.PickerTimeMin, tmin, tmax)
                    if clk then
                        tmin = internal.CombineDateTime(axis.PickerTimeMin, tmin)
                        if tmin >= tmax then tmax = AddTime(tmin, S_, 1) end
                        axis:SetRange(tmin:ToDouble(), tmax:ToDouble())
                    end
                    ImGui.EndMenu()
                end
                EndDisabledControls(dis_min)

                BeginDisabledControls(always_locked)
                _, axis.Flags = ImGui.CheckboxFlags("##LockMax", axis.Flags, ImPlotAxisFlags.LockMax)
                EndDisabledControls(always_locked)
                ImGui.SameLine()
                local dis_max = axis:IsLockedMax() or always_locked
                BeginDisabledControls(dis_max)
                if ImGui.BeginMenu("Max Time") then
                    clk, tmax = internal.ShowTimePicker("maxtime", tmax)
                    if clk then
                        if tmax <= tmin then tmin = AddTime(tmax, S_, -1) end
                        axis:SetRange(tmin:ToDouble(), tmax:ToDouble())
                    end
                    ImGui.Separator()
                    clk, axis.PickerLevel, axis.PickerTimeMax = internal.ShowDatePicker("maxdate", axis.PickerLevel, axis.PickerTimeMax, tmin, tmax)
                    if clk then
                        tmax = internal.CombineDateTime(axis.PickerTimeMax, tmax)
                        if tmax <= tmin then tmin = AddTime(tmax, S_, -1) end
                        axis:SetRange(tmin:ToDouble(), tmax:ToDouble())
                    end
                    ImGui.EndMenu()
                end
                EndDisabledControls(dis_max)
            else
                BeginDisabledControls(always_locked)
                _, axis.Flags = ImGui.CheckboxFlags("##LockMin", axis.Flags, ImPlotAxisFlags.LockMin)
                EndDisabledControls(always_locked)
                ImGui.SameLine()
                local dis_min = axis:IsLockedMin() or always_locked
                BeginDisabledControls(dis_min)
                local temp_min, changed_min = DragFloat("Min", axis.Range.Min, drag_speed, -HUGE_VAL, axis.Range.Max - DBL_EPSILON)
                if changed_min then
                    axis:SetMin(temp_min, true)
                    if equal_axis ~= nil then
                        equal_axis:SetAspect(axis:GetAspect())
                    end
                end
                EndDisabledControls(dis_min)

                BeginDisabledControls(always_locked)
                _, axis.Flags = ImGui.CheckboxFlags("##LockMax", axis.Flags, ImPlotAxisFlags.LockMax)
                EndDisabledControls(always_locked)
                ImGui.SameLine()
                local dis_max = axis:IsLockedMax() or always_locked
                BeginDisabledControls(dis_max)
                local temp_max, changed_max = DragFloat("Max", axis.Range.Max, drag_speed, axis.Range.Min + DBL_EPSILON, HUGE_VAL)
                if changed_max then
                    axis:SetMax(temp_max, true)
                    if equal_axis ~= nil then
                        equal_axis:SetAspect(axis:GetAspect())
                    end
                end
                EndDisabledControls(dis_max)
            end

            ImGui.Separator()

            _, axis.Flags = ImGui.CheckboxFlags("Auto-Fit", axis.Flags, ImPlotAxisFlags.AutoFit)
            ImGui.Separator()
            _, axis.Flags = ImGui.CheckboxFlags("Invert", axis.Flags, ImPlotAxisFlags.Invert)
            _, axis.Flags = ImGui.CheckboxFlags("Opposite", axis.Flags, ImPlotAxisFlags.Opposite)
            ImGui.Separator()
            -- [Port] LabelOffset == -1 -> Label == nil
            local no_label = axis.Label == nil
            BeginDisabledControls(no_label)
            if ImGui.Checkbox("Label", label) then
                axis.Flags = ImFlipFlag(axis.Flags, ImPlotAxisFlags.NoLabel)
            end
            EndDisabledControls(no_label)
            if ImGui.Checkbox("Grid Lines", grid) then
                axis.Flags = ImFlipFlag(axis.Flags, ImPlotAxisFlags.NoGridLines)
            end
            if ImGui.Checkbox("Tick Marks", ticks) then
                axis.Flags = ImFlipFlag(axis.Flags, ImPlotAxisFlags.NoTickMarks)
            end
            if ImGui.Checkbox("Tick Labels", labels) then
                axis.Flags = ImFlipFlag(axis.Flags, ImPlotAxisFlags.NoTickLabels)
            end
            -- [Port] upstream never pops this item width
            ImGui.PopItemWidth()
        end

        function internal.ShowSubplotsContextMenu(subplot)
            local F = ImPlot.ImPlotSubplotFlags
            if ImGui.BeginMenu("Linking") then
                if ImGui.MenuItem("Link Rows", nil, ImHasFlag(subplot.Flags, F.LinkRows)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.LinkRows) end
                if ImGui.MenuItem("Link Cols", nil, ImHasFlag(subplot.Flags, F.LinkCols)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.LinkCols) end
                if ImGui.MenuItem("Link All X", nil, ImHasFlag(subplot.Flags, F.LinkAllX)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.LinkAllX) end
                if ImGui.MenuItem("Link All Y", nil, ImHasFlag(subplot.Flags, F.LinkAllY)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.LinkAllY) end
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("Settings") then
                BeginDisabledControls(not subplot.HasTitle)
                if ImGui.MenuItem("Title", nil, subplot.HasTitle and not ImHasFlag(subplot.Flags, F.NoTitle)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.NoTitle) end
                EndDisabledControls(not subplot.HasTitle)
                if ImGui.MenuItem("Resizable", nil, not ImHasFlag(subplot.Flags, F.NoResize)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.NoResize) end
                if ImGui.MenuItem("Align", nil, not ImHasFlag(subplot.Flags, F.NoAlign)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.NoAlign) end
                if ImGui.MenuItem("Share Items", nil, ImHasFlag(subplot.Flags, F.ShareItems)) then subplot.Flags = ImFlipFlag(subplot.Flags, F.ShareItems) end
                ImGui.EndMenu()
            end
        end

        function internal.ShowPlotContextMenu(plot)
            local gp = GImPlot
            local owns_legend = gp.CurrentItems == plot.Items
            local equal = ImHasFlag(plot.Flags, ImPlotFlags.Equal)

            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local x_axis = plot:XAxis(i)
                if x_axis.Enabled and x_axis:HasMenus() then
                    ImGui.PushID(i)
                    local buf = "X-Axis"
                    if i ~= 0 then buf = string.format("X-Axis %d", i + 1) end
                    if x_axis:HasLabel() then buf = plot:GetAxisLabel(x_axis) end
                    if ImGui.BeginMenu(buf) then
                        internal.ShowAxisContextMenu(x_axis, equal and x_axis.OrthoAxis or nil, false)
                        ImGui.EndMenu()
                    end
                    ImGui.PopID()
                end
            end

            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local y_axis = plot:YAxis(i)
                if y_axis.Enabled and y_axis:HasMenus() then
                    ImGui.PushID(i)
                    local buf = "Y-Axis"
                    if i ~= 0 then buf = string.format("Y-Axis %d", i + 1) end
                    if y_axis:HasLabel() then buf = plot:GetAxisLabel(y_axis) end
                    if ImGui.BeginMenu(buf) then
                        internal.ShowAxisContextMenu(y_axis, equal and y_axis.OrthoAxis or nil, false)
                        ImGui.EndMenu()
                    end
                    ImGui.PopID()
                end
            end

            ImGui.Separator()
            if not ImHasFlag(gp.CurrentItems.Legend.Flags, ImPlot.ImPlotLegendFlags.NoMenus) then
                if ImGui.BeginMenu("Legend") then
                    if owns_legend then
                        if internal.ShowLegendContextMenu(plot.Items.Legend, not ImHasFlag(plot.Flags, ImPlotFlags.NoLegend)) then
                            plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.NoLegend)
                        end
                    elseif gp.CurrentSubplot ~= nil then
                        local sp = gp.CurrentSubplot
                        if internal.ShowLegendContextMenu(sp.Items.Legend, not ImHasFlag(sp.Flags, ImPlot.ImPlotSubplotFlags.NoLegend)) then
                            sp.Flags = ImFlipFlag(sp.Flags, ImPlot.ImPlotSubplotFlags.NoLegend)
                        end
                    end
                    ImGui.EndMenu()
                end
            end
            if ImGui.BeginMenu("Settings") then
                if ImGui.MenuItem("Equal", nil, ImHasFlag(plot.Flags, ImPlotFlags.Equal)) then
                    plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.Equal)
                end
                if ImGui.MenuItem("Box Select", nil, not ImHasFlag(plot.Flags, ImPlotFlags.NoBoxSelect)) then
                    plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.NoBoxSelect)
                end
                local no_title = plot.Title == nil
                BeginDisabledControls(no_title)
                if ImGui.MenuItem("Title", nil, plot:HasTitle()) then
                    plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.NoTitle)
                end
                EndDisabledControls(no_title)
                if ImGui.MenuItem("Mouse Position", nil, not ImHasFlag(plot.Flags, ImPlotFlags.NoMouseText)) then
                    plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.NoMouseText)
                end
                if ImGui.MenuItem("Crosshairs", nil, ImHasFlag(plot.Flags, ImPlotFlags.Crosshairs)) then
                    plot.Flags = ImFlipFlag(plot.Flags, ImPlotFlags.Crosshairs)
                end
                ImGui.EndMenu()
            end
            if gp.CurrentSubplot ~= nil and not ImHasFlag(gp.CurrentSubplot.Flags, ImPlot.ImPlotSubplotFlags.NoMenus) then
                ImGui.Separator()
                if ImGui.BeginMenu("Subplots") then
                    internal.ShowSubplotsContextMenu(gp.CurrentSubplot)
                    ImGui.EndMenu()
                end
            end
        end

        -----------------------------------------------------------------------
        -- Input Handling
        -----------------------------------------------------------------------

        local MOUSE_CURSOR_DRAG_THRESHOLD = 5.0
        local BOX_SELECT_DRAG_THRESHOLD   = 4.0

        function internal.RenderSelectionRect(DrawList, p_min, p_max, col)
            local col_bg = ImGui.GetColorU32(ImVec4(col.x, col.y, col.z, col.w * 0.25))
            local col_bd = ImGui.GetColorU32(col)
            DrawList:AddRectFilled(p_min, p_max, col_bg)
            DrawList:AddRect(p_min, p_max, col_bd)
        end

        local function AllAxesInputLocked(plot, first, count)
            for i = first, first + count - 1 do
                local a = plot.Axes[i]
                if a.Enabled and not a:IsInputLocked() then
                    return false
                end
            end
            return true
        end

        local function AnyAxesHeld(plot, first, count)
            for i = first, first + count - 1 do
                if plot.Axes[i].Enabled and plot.Axes[i].Held then
                    return true
                end
            end
            return false
        end

        local function AnyAxesHovered(plot, first, count)
            for i = first, first + count - 1 do
                if plot.Axes[i].Enabled and plot.Axes[i].Hovered then
                    return true
                end
            end
            return false
        end

        local plot_button_flags = bit32.bor(G.ImGuiButtonFlags.AllowOverlap, G.ImGuiButtonFlags.PressedOnClick, G.ImGuiButtonFlags.PressedOnDoubleClick,
                                            G.ImGuiButtonFlags.MouseButtonLeft, G.ImGuiButtonFlags.MouseButtonRight, G.ImGuiButtonFlags.MouseButtonMiddle)
        local axis_button_flags = bit32.bor(G.ImGuiButtonFlags.FlattenChildren, plot_button_flags)

        -- [Port] scratch per-axis arrays (0-based, reused every call)
        local x_hov, x_held = {}, {}
        local y_hov, y_held = {}, {}

        function internal.UpdateInput(plot)
            local changed = false

            local gp = GImPlot
            local IO = ImGui.GetIO()
            local map = gp.InputMap

            -- BUTTON STATE -----------------------------------------------------------

            local plot_clicked
            plot_clicked, plot.Hovered, plot.Held = ImGui.ButtonBehavior(plot.PlotRect, plot.ID, plot_button_flags)

            if plot_clicked then
                if not ImHasFlag(plot.Flags, ImPlotFlags.NoBoxSelect) and IO.MouseClicked[map.Select] and ImHasFlag(IO.KeyMods, map.SelectMod) then
                    plot.Selecting   = true
                    plot.SelectStart = ImVec2(IO.MousePos.x, IO.MousePos.y)
                    local sr = plot.SelectRect
                    sr.Min.x, sr.Min.y, sr.Max.x, sr.Max.y = 0, 0, 0, 0
                end
                if IO.MouseDoubleClicked[map.Fit] then
                    plot.FitThisFrame = true
                    for i = 0, ImAxis.COUNT - 1 do
                        plot.Axes[i].FitThisFrame = true
                    end
                end
            end

            local can_pan = IO.MouseDown[map.Pan] and ImHasFlag(IO.KeyMods, map.PanMod)

            plot.Held = plot.Held and can_pan

            for i = 0, IMPLOT_NUM_X_AXES - 1 do
                local xax = plot:XAxis(i)
                x_hov[i], x_held[i] = false, false
                if xax.Enabled then
                    ImGui.KeepAliveID(xax.ID)
                    local x_click
                    x_click, xax.Hovered, xax.Held = ImGui.ButtonBehavior(xax.HoverRect, xax.ID, axis_button_flags)
                    if x_click and IO.MouseDoubleClicked[map.Fit] then
                        plot.FitThisFrame = true
                        xax.FitThisFrame = true
                    end
                    xax.Held  = xax.Held and can_pan
                    x_hov[i]  = xax.Hovered or plot.Hovered
                    x_held[i] = xax.Held or plot.Held
                end
            end

            for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                local yax = plot:YAxis(i)
                y_hov[i], y_held[i] = false, false
                if yax.Enabled then
                    ImGui.KeepAliveID(yax.ID)
                    local y_click
                    y_click, yax.Hovered, yax.Held = ImGui.ButtonBehavior(yax.HoverRect, yax.ID, axis_button_flags)
                    if y_click and IO.MouseDoubleClicked[map.Fit] then
                        plot.FitThisFrame = true
                        yax.FitThisFrame = true
                    end
                    yax.Held  = yax.Held and can_pan
                    y_hov[i]  = yax.Hovered or plot.Hovered
                    y_held[i] = yax.Held or plot.Held
                end
            end

            -- cancel due to DND activity
            if ImGui.GetCurrentContext().DragDropActive or (IO.KeyMods == map.OverrideMod and map.OverrideMod ~= 0) then
                return false
            end

            -- STATE -------------------------------------------------------------------

            local axis_equal     = ImHasFlag(plot.Flags, ImPlotFlags.Equal)

            local any_x_hov      = plot.Hovered or AnyAxesHovered(plot, ImAxis.X1, IMPLOT_NUM_X_AXES)
            local any_x_held     = plot.Held    or AnyAxesHeld(plot, ImAxis.X1, IMPLOT_NUM_X_AXES)
            local any_y_hov      = plot.Hovered or AnyAxesHovered(plot, ImAxis.Y1, IMPLOT_NUM_Y_AXES)
            local any_y_held     = plot.Held    or AnyAxesHeld(plot, ImAxis.Y1, IMPLOT_NUM_Y_AXES)
            local any_hov        = any_x_hov    or any_y_hov
            local any_held       = any_x_held   or any_y_held

            local select_drag    = ImGui.GetMouseDragDelta(map.Select)
            local pan_drag       = ImGui.GetMouseDragDelta(map.Pan)
            local select_drag_sq = select_drag.x * select_drag.x + select_drag.y * select_drag.y
            local pan_drag_sq    = pan_drag.x * pan_drag.x + pan_drag.y * pan_drag.y
            local selecting      = plot.Selecting and select_drag_sq > MOUSE_CURSOR_DRAG_THRESHOLD
            local panning        = any_held       and pan_drag_sq    > MOUSE_CURSOR_DRAG_THRESHOLD

            -- CONTEXT MENU -----------------------------------------------------------

            if IO.MouseReleased[map.Menu] and not plot.ContextLocked then
                gp.OpenContextThisFrame = true
            end

            if selecting or panning then
                plot.ContextLocked = true
            elseif not (IO.MouseDown[map.Menu] or IO.MouseReleased[map.Menu]) then
                plot.ContextLocked = false
            end

            -- DRAG INPUT -------------------------------------------------------------

            local delta = IO.MouseDelta
            if any_held and not plot.Selecting then
                local drag_direction = 0
                for i = 0, IMPLOT_NUM_X_AXES - 1 do
                    local x_axis = plot:XAxis(i)
                    if x_held[i] and not x_axis:IsInputLocked() then
                        drag_direction = bit32.bor(drag_direction, 2)
                        local increasing = delta.x < 0
                        if x_axis:IsInverted() then increasing = delta.x > 0 end
                        if delta.x ~= 0 and not x_axis:IsPanLocked(increasing) then
                            local plot_l = x_axis:PixelsToPlot(plot.PlotRect.Min.x - delta.x)
                            local plot_r = x_axis:PixelsToPlot(plot.PlotRect.Max.x - delta.x)
                            if x_axis:IsInverted() then plot_l, plot_r = plot_r, plot_l end
                            x_axis:SetMin(plot_l)
                            x_axis:SetMax(plot_r)
                            if axis_equal and x_axis.OrthoAxis ~= nil then
                                x_axis.OrthoAxis:SetAspect(x_axis:GetAspect())
                            end
                            changed = true
                        end
                    end
                end
                for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                    local y_axis = plot:YAxis(i)
                    if y_held[i] and not y_axis:IsInputLocked() then
                        drag_direction = bit32.bor(drag_direction, 4)
                        local increasing = delta.y > 0
                        if y_axis:IsInverted() then increasing = delta.y < 0 end
                        if delta.y ~= 0 and not y_axis:IsPanLocked(increasing) then
                            local plot_t = y_axis:PixelsToPlot(plot.PlotRect.Min.y - delta.y)
                            local plot_b = y_axis:PixelsToPlot(plot.PlotRect.Max.y - delta.y)
                            if y_axis:IsInverted() then plot_t, plot_b = plot_b, plot_t end
                            y_axis:SetMin(plot_b)
                            y_axis:SetMax(plot_t)
                            if axis_equal and y_axis.OrthoAxis ~= nil then
                                y_axis.OrthoAxis:SetAspect(y_axis:GetAspect())
                            end
                            changed = true
                        end
                    end
                end
                if IO.MouseDragMaxDistanceSqr[map.Pan] > MOUSE_CURSOR_DRAG_THRESHOLD then
                    if drag_direction == 0 then
                        ImGui.SetMouseCursor(G.ImGuiMouseCursor.NotAllowed)
                    elseif drag_direction == 2 then
                        ImGui.SetMouseCursor(G.ImGuiMouseCursor.ResizeEW)
                    elseif drag_direction == 4 then
                        ImGui.SetMouseCursor(G.ImGuiMouseCursor.ResizeNS)
                    else
                        ImGui.SetMouseCursor(G.ImGuiMouseCursor.ResizeAll)
                    end
                end
            end

            -- SCROLL INPUT -----------------------------------------------------------

            if any_hov and ImHasFlag(IO.KeyMods, map.ZoomMod) then
                local zoom_rate = map.ZoomRate
                if IO.MouseWheel == 0.0 then
                    zoom_rate = 0
                elseif IO.MouseWheel > 0 then
                    zoom_rate = (-zoom_rate) / (1.0 + (2.0 * zoom_rate))
                end
                local prc = plot.PlotRect
                local rect_w, rect_h = prc:GetWidth(), prc:GetHeight()
                local tx = (IO.MousePos.x - prc.Min.x) / (prc.Max.x - prc.Min.x) -- ImRemap(.., 0, 1)
                local ty = (IO.MousePos.y - prc.Min.y) / (prc.Max.y - prc.Min.y)

                -- Track which axis to use as reference for equal aspect
                local equal_ref_axis = nil

                for i = 0, IMPLOT_NUM_X_AXES - 1 do
                    local x_axis = plot:XAxis(i)
                    local equal_zoom   = axis_equal and x_axis.OrthoAxis ~= nil
                    local equal_locked = equal_zoom and x_axis.OrthoAxis:IsInputLocked()
                    if x_hov[i] and not x_axis:IsInputLocked() and not equal_locked then
                        ImGui.SetKeyOwner(G.ImGuiKey.MouseWheelY, plot.ID)
                        if zoom_rate ~= 0.0 then
                            local plot_l = x_axis:PixelsToPlot(prc.Min.x - rect_w * tx * zoom_rate)
                            local plot_r = x_axis:PixelsToPlot(prc.Max.x + rect_w * (1 - tx) * zoom_rate)
                            if x_axis:IsInverted() then plot_l, plot_r = plot_r, plot_l end
                            x_axis:SetMin(plot_l)
                            x_axis:SetMax(plot_r)
                            if equal_zoom then
                                equal_ref_axis = x_axis
                            end
                            changed = true
                        end
                    end
                end
                for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                    local y_axis = plot:YAxis(i)
                    local equal_zoom   = axis_equal and y_axis.OrthoAxis ~= nil
                    local equal_locked = equal_zoom and y_axis.OrthoAxis:IsInputLocked()
                    if y_hov[i] and not y_axis:IsInputLocked() and not equal_locked then
                        ImGui.SetKeyOwner(G.ImGuiKey.MouseWheelY, plot.ID)
                        if zoom_rate ~= 0.0 then
                            local plot_t = y_axis:PixelsToPlot(prc.Min.y - rect_h * ty * zoom_rate)
                            local plot_b = y_axis:PixelsToPlot(prc.Max.y + rect_h * (1 - ty) * zoom_rate)
                            if y_axis:IsInverted() then plot_t, plot_b = plot_b, plot_t end
                            y_axis:SetMin(plot_b)
                            y_axis:SetMax(plot_t)
                            if equal_zoom then
                                equal_ref_axis = y_axis
                            end
                            changed = true
                        end
                    end
                end

                -- Apply equal aspect constraint after zooming both axes
                if equal_ref_axis ~= nil and equal_ref_axis.OrthoAxis ~= nil then
                    equal_ref_axis.OrthoAxis:SetAspect(equal_ref_axis:GetAspect())
                end
            end

            -- BOX-SELECTION ----------------------------------------------------------

            if plot.Selecting then
                local mp = IO.MousePos
                local dx, dy = plot.SelectStart.x - mp.x, plot.SelectStart.y - mp.y
                local x_can_change = not ImHasFlag(IO.KeyMods, map.SelectHorzMod) and math.abs(dx) > 2
                local y_can_change = not ImHasFlag(IO.KeyMods, map.SelectVertMod) and math.abs(dy) > 2
                -- confirm
                if IO.MouseReleased[map.Select] then
                    for i = 0, IMPLOT_NUM_X_AXES - 1 do
                        local x_axis = plot:XAxis(i)
                        if not x_axis:IsInputLocked() and x_can_change then
                            local p1 = x_axis:PixelsToPlot(plot.SelectStart.x)
                            local p2 = x_axis:PixelsToPlot(mp.x)
                            x_axis:SetMin(math.min(p1, p2))
                            x_axis:SetMax(math.max(p1, p2))
                            changed = true
                        end
                    end
                    for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                        local y_axis = plot:YAxis(i)
                        if not y_axis:IsInputLocked() and y_can_change then
                            local p1 = y_axis:PixelsToPlot(plot.SelectStart.y)
                            local p2 = y_axis:PixelsToPlot(mp.y)
                            y_axis:SetMin(math.min(p1, p2))
                            y_axis:SetMax(math.max(p1, p2))
                            changed = true
                        end
                    end
                    if x_can_change or y_can_change or (ImHasFlag(IO.KeyMods, map.SelectHorzMod) and ImHasFlag(IO.KeyMods, map.SelectVertMod)) then
                        gp.OpenContextThisFrame = false
                    end
                    plot.Selected = false
                    plot.Selecting = false
                -- cancel
                elseif IO.MouseReleased[map.SelectCancel] then
                    plot.Selected = false
                    plot.Selecting = false
                    gp.OpenContextThisFrame = false
                elseif dx * dx + dy * dy > BOX_SELECT_DRAG_THRESHOLD then
                    -- bad selection
                    if plot:IsInputLocked() then
                        ImGui.SetMouseCursor(G.ImGuiMouseCursor.NotAllowed)
                        gp.OpenContextThisFrame = false
                        plot.Selected = false
                    else
                        -- TODO: Handle only min or max locked cases
                        local full_width  = ImHasFlag(IO.KeyMods, map.SelectHorzMod) or AllAxesInputLocked(plot, ImAxis.X1, IMPLOT_NUM_X_AXES)
                        local full_height = ImHasFlag(IO.KeyMods, map.SelectVertMod) or AllAxesInputLocked(plot, ImAxis.Y1, IMPLOT_NUM_Y_AXES)
                        local prc, sr, ss = plot.PlotRect, plot.SelectRect, plot.SelectStart
                        if full_width then
                            sr.Min.x, sr.Max.x = prc.Min.x, prc.Max.x
                        else
                            sr.Min.x, sr.Max.x = math.min(ss.x, mp.x), math.max(ss.x, mp.x)
                        end
                        if full_height then
                            sr.Min.y, sr.Max.y = prc.Min.y, prc.Max.y
                        else
                            sr.Min.y, sr.Max.y = math.min(ss.y, mp.y), math.max(ss.y, mp.y)
                        end
                        sr.Min.x -= prc.Min.x; sr.Min.y -= prc.Min.y
                        sr.Max.x -= prc.Min.x; sr.Max.y -= prc.Min.y
                        plot.Selected = true
                    end
                else
                    plot.Selected = false
                end
            end
            return changed
        end

        -----------------------------------------------------------------------
        -- Next Plot Data (Legacy)
        -----------------------------------------------------------------------

        function internal.ApplyNextPlotData(idx)
            local gp   = GImPlot
            local plot = gp.CurrentPlot
            local axis = plot.Axes[idx]
            if not axis.Enabled then
                return
            end
            local npd = gp.NextPlotData
            axis.LinkedMin = npd.LinkedMin[idx]
            axis.LinkedMax = npd.LinkedMax[idx]
            axis:PullLinks()
            if npd.HasRange[idx] then
                if not plot.Initialized or npd.RangeCond[idx] == ImPlotCond.Always then
                    axis:SetRange(npd.Range[idx])
                end
            end
            axis.HasRange  = npd.HasRange[idx]
            axis.RangeCond = npd.RangeCond[idx]
        end

        function ImPlot.SetNextAxisLimits(axis, v_min, v_max, cond)
            if cond == nil then cond = ImPlotCond.Once end
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot == nil, "SetNextAxisLimits() needs to be called before BeginPlot()!")
            IM_ASSERT(cond == ImPlotCond.None or cond == ImPlotCond.Once or cond == ImPlotCond.Always) -- Make sure the user only passes a single condition flag
            gp.NextPlotData.HasRange[axis]  = true
            gp.NextPlotData.RangeCond[axis] = cond
            gp.NextPlotData.Range[axis].Min = v_min
            gp.NextPlotData.Range[axis].Max = v_max
        end

        -- [Port] link_min/link_max are link refs (tables whose [1] holds the value)
        function ImPlot.SetNextAxisLinks(axis, link_min, link_max)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot == nil, "SetNextAxisLinks() needs to be called before BeginPlot()!")
            gp.NextPlotData.LinkedMin[axis] = link_min
            gp.NextPlotData.LinkedMax[axis] = link_max
        end

        function ImPlot.SetNextAxisToFit(axis)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot == nil, "SetNextAxisToFit() needs to be called before BeginPlot()!")
            gp.NextPlotData.Fit[axis] = true
        end

        function ImPlot.SetNextAxesLimits(x_min, x_max, y_min, y_max, cond)
            ImPlot.SetNextAxisLimits(ImAxis.X1, x_min, x_max, cond)
            ImPlot.SetNextAxisLimits(ImAxis.Y1, y_min, y_max, cond)
        end

        function ImPlot.SetNextAxesToFit()
            for i = 0, ImAxis.COUNT - 1 do
                ImPlot.SetNextAxisToFit(i)
            end
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

        -- [Port] SetupAxisFormat(idx, fmt) and SetupAxisFormat(idx, formatter, data) overloads:
        -- `fmt_or_formatter` is a format string or a formatter function(value, data) -> string
        function ImPlot.SetupAxisFormat(idx, fmt, data)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            if type(fmt) == "function" then
                axis.Formatter = fmt
                axis.FormatterData = data
                return
            end
            axis.HasFormatSpec = fmt ~= nil
            if fmt ~= nil then
                axis.FormatSpec = fmt
            end
        end

        -- [Port] min_lnk/max_lnk are link refs (tables whose [1] holds the value) instead of double*
        function ImPlot.SetupAxisLinks(idx, min_lnk, max_lnk)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            axis.LinkedMin = min_lnk
            axis.LinkedMax = max_lnk
            axis:PullLinks()
        end

        -- [Port] SetupAxisTicks(idx, values, n_ticks, labels, show_default) and
        -- SetupAxisTicks(idx, v_min, v_max, n_ticks, labels, show_default) overloads (values/labels are 1-based arrays)
        function ImPlot.SetupAxisTicks(idx, a, b, c, d, e)
            if type(a) == "number" then
                local v_min, v_max, n_ticks, labels, show_default = a, b, c, d, e
                IM_ASSERT(labels == nil or n_ticks >= 2, "When providing custom labels, n_ticks must be at least 2!")
                if n_ticks < 2 then n_ticks = 2 end
                local values = table.create(n_ticks)
                local step = (v_max - v_min) / (n_ticks - 1)
                for i = 1, n_ticks do
                    values[i] = v_min + (i - 1) * step
                end
                return ImPlot.SetupAxisTicks(idx, values, n_ticks, labels, show_default)
            end
            local values, labels, show_default = a, c, d
            local n_ticks = b or #values
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            axis.ShowDefaultTicks = show_default or false
            local formatter = axis.Formatter or internal.Formatter_Default
            local data
            if axis.Formatter ~= nil and axis.FormatterData ~= nil then
                data = axis.FormatterData
            elseif axis.HasFormatSpec then
                data = axis.FormatSpec
            else
                data = internal.IMPLOT_LABEL_FORMAT
            end
            internal.AddTicksCustom(values, labels, n_ticks, axis.Ticker, formatter, data)
        end

        -- [Port] SetupAxisScale(idx, scale) and SetupAxisScale(idx, fwd, inv, data) overloads
        function ImPlot.SetupAxisScale(idx, scale, inv, data)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            if type(scale) == "function" then
                axis.Scale = IMPLOT_AUTO
                axis.TransformForward = scale
                axis.TransformInverse = inv
                axis.TransformData = data
                return
            end
            axis.Scale = scale
            if scale == ImPlotScale.Time then
                axis.TransformForward = nil
                axis.TransformInverse = nil
                axis.TransformData    = nil
                axis.Locator          = internal.Locator_Time
                axis.ConstraintRange  = ImPlot.ImPlotRange(internal.IMPLOT_MIN_TIME, internal.IMPLOT_MAX_TIME)
                axis.Ticker.Levels    = 2
            elseif scale == ImPlotScale.Log10 then
                axis.TransformForward = internal.TransformForward_Log10
                axis.TransformInverse = internal.TransformInverse_Log10
                axis.TransformData    = nil
                axis.Locator          = internal.Locator_Log10
                axis.ConstraintRange  = ImPlot.ImPlotRange(2.2250738585072014e-308, math.huge)
            elseif scale == ImPlotScale.SymLog then
                axis.TransformForward = internal.TransformForward_SymLog
                axis.TransformInverse = internal.TransformInverse_SymLog
                axis.TransformData    = nil
                axis.Locator          = internal.Locator_SymLog
                axis.ConstraintRange  = ImPlot.ImPlotRange(-math.huge, math.huge)
            else
                axis.TransformForward = nil
                axis.TransformInverse = nil
                axis.TransformData    = nil
                axis.Locator          = nil
                axis.ConstraintRange  = ImPlot.ImPlotRange(-math.huge, math.huge)
            end
        end

        function ImPlot.SetupAxisLimitsConstraints(idx, v_min, v_max)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            axis.ConstraintRange.Min = v_min
            axis.ConstraintRange.Max = v_max
        end

        function ImPlot.SetupAxisZoomConstraints(idx, z_min, z_max)
            CheckSetup()
            local plot = GImPlot.CurrentPlot
            local axis = plot.Axes[idx]
            IM_ASSERT(axis.Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            axis.ConstraintZoom.Min = z_min
            axis.ConstraintZoom.Max = z_max
        end

        function ImPlot.SetupMouseText(location, flags)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil and not gp.CurrentPlot.SetupLocked,
                "Setup needs to be called after BeginPlot and before any setup locking functions (e.g. PlotX)!")
            gp.CurrentPlot.MouseTextLocation = location
            gp.CurrentPlot.MouseTextFlags = flags or ImPlot.ImPlotMouseTextFlags.None
        end

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
            if gp.CurrentSubplot ~= nil then
                ImGui.PushID(gp.CurrentSubplot.CurrentIdx)
            end

            -- get globals
            local Window = ImGui.GetCurrentWindow()

            -- skip if needed
            if Window.SkipItems and not gp.CurrentSubplot then
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
            -- [Luau] the cached colours do not depend on the axis: resolved once (X1) and copied to the other axes
            -- (resolving the auto colours walks the auto colour chain and allocates: ~1.5 us per axis per frame)
            local a0 = plot.Axes[0]
            for i = 0, ImAxis.COUNT - 1 do
                local axis = plot.Axes[i]
                axis:Reset()
                if i == 0 then
                    UpdateAxisColors(axis)
                else
                    axis.ColorMaj, axis.ColorMin, axis.ColorTick, axis.ColorTxt = a0.ColorMaj, a0.ColorMin, a0.ColorTick, a0.ColorTxt
                    axis.ColorBg, axis.ColorHov, axis.ColorAct = a0.ColorBg, a0.ColorHov, a0.ColorAct
                end
            end
            -- ensure first axes enabled
            plot.Axes[ImAxis.X1].Enabled = true
            plot.Axes[ImAxis.Y1].Enabled = true
            -- set initial axes
            plot.CurrentX = ImAxis.X1
            plot.CurrentY = ImAxis.Y1

            -- process next plot data (legacy)
            for i = 0, ImAxis.COUNT - 1 do
                internal.ApplyNextPlotData(i)
            end

            -- clear text buffers
            plot:ClearTextBuffer()
            plot:SetTitle(title_id)

            -- set frame size
            local frame_size
            if gp.CurrentSubplot ~= nil then
                frame_size = ImVec2(gp.CurrentSubplot.CellSize.x, gp.CurrentSubplot.CellSize.y)
            else
                frame_size = ImGui.CalcItemSize(size, gp.Style.PlotDefaultSize.x, gp.Style.PlotDefaultSize.y)
            end

            if frame_size.x < gp.Style.PlotMinSize.x and (size.x < 0.0 or gp.CurrentSubplot ~= nil) then
                frame_size.x = gp.Style.PlotMinSize.x
            end
            if frame_size.y < gp.Style.PlotMinSize.y and (size.y < 0.0 or gp.CurrentSubplot ~= nil) then
                frame_size.y = gp.Style.PlotMinSize.y
            end

            local cp = Window.DC.CursorPos
            local fr = plot.FrameRect
            fr.Min.x, fr.Min.y = cp.x, cp.y
            fr.Max.x, fr.Max.y = cp.x + frame_size.x, cp.y + frame_size.y
            ImGui.ItemSize(fr)
            if not ImGui.ItemAdd(fr, plot.ID, fr) and not gp.CurrentSubplot then
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
            internal.AdjustForOutsideLegend(plot)

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
                if gp.NextPlotData.Fit[i] or plot.Axes[i]:IsAutoFitting() then
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
            plot.Items.Legend:Reset()
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

        local function AxisPrecision(axis)
            local ticker = axis.Ticker
            local range
            if ticker:TickCount() > 1 then
                range = ticker.Ticks[2].PlotPos - ticker.Ticks[1].PlotPos
            else
                range = axis.Range:Size()
            end
            -- Precision(range)
            local order = 0
            if range ~= 0 then order = math.floor(math.log10(math.abs(range))) end
            if order > 0 then return 0 end
            return 1 - order
        end

        local function RoundAxisValue(axis, value)
            local p = 10 ^ AxisPrecision(axis)
            return math.floor(value * p + 0.5) / p
        end

        -- [Port] returns the label string instead of writing into buff
        function internal.LabelAxisValue(axis, value, round)
            local gp = GImPlot
            -- TODO: We shouldn't explicitly check that the axis is Time here. Ideally,
            -- Formatter_Time would handle the formatting for us, but the code below
            -- needs additional arguments which are not currently available in ImPlotFormatter
            if axis.Locator == internal.Locator_Time then
                local unit
                if axis.Vertical then
                    unit = internal.GetUnitForRange(axis.Range:Size() / (gp.CurrentPlot.PlotRect:GetHeight() / 100)) -- TODO: magic value!
                else
                    unit = internal.GetUnitForRange(axis.Range:Size() / (gp.CurrentPlot.PlotRect:GetWidth() / 100)) -- TODO: magic value!
                end
                return internal.FormatDateTime(internal.ImPlotTimeFromDouble(value), internal.GetDateTimeFmt(internal.TimeFormatMouseCursor, unit))
            end
            if round then
                value = RoundAxisValue(axis, value)
            end
            return axis.Formatter(value, axis.FormatterData)
        end
        local LabelAxisValue = internal.LabelAxisValue

        local function ClampLabelPos(pos, size, Min, Max)
            if pos.x < Min.x then pos.x = Min.x end
            if pos.y < Min.y then pos.y = Min.y end
            if (pos.x + size.x) > Max.x then pos.x = Max.x - size.x end
            if (pos.y + size.y) > Max.y then pos.y = Max.y - size.y end
            return pos
        end

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

            -- render selection
            if plot.Selected then
                local sr = plot.SelectRect
                internal.RenderSelectionRect(DrawList, ImVec2(sr.Min.x + pr.Min.x, sr.Min.y + pr.Min.y), ImVec2(sr.Max.x + pr.Min.x, sr.Max.y + pr.Min.y), GetStyleColorVec4(ImPlotCol.Selection))
            end

            -- render annotations
            internal.PushPlotClipRect()
            for i = 1, #gp.Annotations do
                local an       = gp.Annotations[i]
                local txt      = an.Text
                local txt_size = ImGui.CalcTextSize(txt)
                local size     = ImVec2(txt_size.x + gs.AnnotationPadding.x * 2, txt_size.y + gs.AnnotationPadding.y * 2)
                local pos      = ImVec2(an.Pos.x, an.Pos.y)
                if an.Offset.x == 0 then
                    pos.x -= size.x / 2
                elseif an.Offset.x > 0 then
                    pos.x += an.Offset.x
                else
                    pos.x -= size.x - an.Offset.x
                end
                if an.Offset.y == 0 then
                    pos.y -= size.y / 2
                elseif an.Offset.y > 0 then
                    pos.y += an.Offset.y
                else
                    pos.y -= size.y - an.Offset.y
                end
                if an.Clamp then
                    pos = ClampLabelPos(pos, size, pr.Min, pr.Max)
                end
                local rect = ImRect(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
                if an.Offset.x ~= 0 or an.Offset.y ~= 0 then
                    local corners = { rect:GetTL(), rect:GetTR(), rect:GetBR(), rect:GetBL() }
                    local min_corner = 1
                    local min_len = math.huge
                    for c = 1, 4 do
                        local dx, dy = an.Pos.x - corners[c].x, an.Pos.y - corners[c].y
                        local len = dx * dx + dy * dy
                        if len < min_len then
                            min_corner = c
                            min_len = len
                        end
                    end
                    DrawList:AddLine(an.Pos, corners[min_corner], an.ColorBg)
                end
                DrawList:AddRectFilled(rect.Min, rect.Max, an.ColorBg)
                DrawList:AddText(SetTmp(pos.x + gs.AnnotationPadding.x, pos.y + gs.AnnotationPadding.y), an.ColorFg, txt)
            end

            -- render crosshairs
            local any_x_held = plot.Held or AnyAxesHeld(plot, ImAxis.X1, IMPLOT_NUM_X_AXES)
            local any_y_held = plot.Held or AnyAxesHeld(plot, ImAxis.Y1, IMPLOT_NUM_Y_AXES)
            if ImHasFlag(plot.Flags, ImPlotFlags.Crosshairs) and plot.Hovered and not (any_x_held or any_y_held) and not plot.Selecting and not plot.Items.Legend.Hovered then
                ImGui.SetMouseCursor(G.ImGuiMouseCursor.None)
                local xy = ImGui.GetIO().MousePos
                local col = GetStyleColorU32(ImPlotCol.Crosshairs)
                AddLineH(DrawList, pr.Min.x, xy.x - 5, xy.y, col)
                AddLineH(DrawList, xy.x + 5, pr.Max.x, xy.y, col)
                AddLineV(DrawList, xy.x, pr.Min.y, xy.y - 5, col)
                AddLineV(DrawList, xy.x, xy.y + 5, pr.Max.y, col)
            end

            -- render mouse pos
            if not ImHasFlag(plot.Flags, ImPlotFlags.NoMouseText) and (plot.Hovered or ImHasFlag(plot.MouseTextFlags, ImPlot.ImPlotMouseTextFlags.ShowAlways)) then
                local no_aux = ImHasFlag(plot.MouseTextFlags, ImPlot.ImPlotMouseTextFlags.NoAuxAxes)
                local no_fmt = ImHasFlag(plot.MouseTextFlags, ImPlot.ImPlotMouseTextFlags.NoFormat)
                local mouse_pos = ImGui.GetIO().MousePos
                -- [Port] ImGuiTextBuffer builder -> table of string parts
                local builder = {}
                local num_x = IMPLOT_NUM_X_AXES
                if no_aux then num_x = 1 end
                for i = 0, num_x - 1 do
                    local x_axis = plot:XAxis(i)
                    if x_axis.Enabled then
                        if i > 0 then table.insert(builder, ", (") end
                        local v = x_axis:PixelsToPlot(mouse_pos.x)
                        if no_fmt then
                            table.insert(builder, internal.Formatter_Default(v, internal.IMPLOT_LABEL_FORMAT))
                        else
                            table.insert(builder, LabelAxisValue(x_axis, v, true))
                        end
                        if i > 0 then table.insert(builder, ")") end
                    end
                end
                table.insert(builder, ", ")
                local num_y = IMPLOT_NUM_Y_AXES
                if no_aux then num_y = 1 end
                for i = 0, num_y - 1 do
                    local y_axis = plot:YAxis(i)
                    if y_axis.Enabled then
                        if i > 0 then table.insert(builder, ", (") end
                        local v = y_axis:PixelsToPlot(mouse_pos.y)
                        if no_fmt then
                            table.insert(builder, internal.Formatter_Default(v, internal.IMPLOT_LABEL_FORMAT))
                        else
                            table.insert(builder, LabelAxisValue(y_axis, v, true))
                        end
                        if i > 0 then table.insert(builder, ")") end
                    end
                end
                local str = table.concat(builder)
                if str ~= "" then
                    local size = ImGui.CalcTextSize(str)
                    local pos = internal.GetLocationPos(pr, size, plot.MouseTextLocation, gs.MousePosPadding)
                    DrawList:AddText(pos, GetStyleColorU32(ImPlotCol.InlayText), str)
                end
            end
            internal.PopPlotClipRect()

            -- axis side switch
            if not plot.Held then
                local mouse_pos = ImGui.GetIO().MousePos
                for i = 0, IMPLOT_NUM_X_AXES - 1 do
                    local x_axis = plot:XAxis(i)
                    if not ImHasFlag(x_axis.Flags, ImPlotAxisFlags.NoSideSwitch) and x_axis.Held and pr:Contains(mouse_pos) then
                        local rect
                        if not x_axis:IsOpposite() then
                            rect = ImRect(pr.Min.x - 5, pr.Min.y - 5, pr.Max.x + 5, pr.Min.y + 5)
                            if mouse_pos.y < pr.Max.y - 10 then DrawList:AddRectFilled(rect.Min, rect.Max, x_axis.ColorHov) end
                            if rect:Contains(mouse_pos) then x_axis.Flags = bit32.bor(x_axis.Flags, ImPlotAxisFlags.Opposite) end
                        else
                            rect = ImRect(pr.Min.x - 5, pr.Max.y - 5, pr.Max.x + 5, pr.Max.y + 5)
                            if mouse_pos.y > pr.Min.y + 10 then DrawList:AddRectFilled(rect.Min, rect.Max, x_axis.ColorHov) end
                            if rect:Contains(mouse_pos) then x_axis.Flags = bit32.band(x_axis.Flags, bit32.bnot(ImPlotAxisFlags.Opposite)) end
                        end
                    end
                end
                for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                    local y_axis = plot:YAxis(i)
                    if not ImHasFlag(y_axis.Flags, ImPlotAxisFlags.NoSideSwitch) and y_axis.Held and pr:Contains(mouse_pos) then
                        local rect
                        if not y_axis:IsOpposite() then
                            rect = ImRect(pr.Max.x - 5, pr.Min.y - 5, pr.Max.x + 5, pr.Max.y + 5)
                            if mouse_pos.x > pr.Min.x + 10 then DrawList:AddRectFilled(rect.Min, rect.Max, y_axis.ColorHov) end
                            if rect:Contains(mouse_pos) then y_axis.Flags = bit32.bor(y_axis.Flags, ImPlotAxisFlags.Opposite) end
                        else
                            rect = ImRect(pr.Min.x - 5, pr.Min.y - 5, pr.Min.x + 5, pr.Max.y + 5)
                            if mouse_pos.x < pr.Max.x - 10 then DrawList:AddRectFilled(rect.Min, rect.Max, y_axis.ColorHov) end
                            if rect:Contains(mouse_pos) then y_axis.Flags = bit32.band(y_axis.Flags, bit32.bnot(ImPlotAxisFlags.Opposite)) end
                        end
                    end
                end
            end

            -- render legend
            internal.RenderPlotLegend(plot, DrawList)

            -- render border
            if render_border then
                DrawList:AddRect(pr.Min, pr.Max, GetStyleColorU32(ImPlotCol.PlotBorder), 0, gs.PlotBorderSize, G.ImDrawFlags.None)
            end

            -- render tags
            for i = 1, #gp.Tags do
                local tag  = gp.Tags[i]
                local axis = plot.Axes[tag.Axis]
                if axis.Enabled and axis.Range:Contains(tag.Value) then
                    local txt = tag.Text
                    local text_size = ImGui.CalcTextSize(txt)
                    local size = ImVec2(text_size.x + gs.AnnotationPadding.x * 2, text_size.y + gs.AnnotationPadding.y * 2)
                    local pos
                    axis.Ticker:OverrideSizeLate(size)
                    local pix = math.floor(axis:PlotToPixels(tag.Value) + 0.5) -- IM_ROUND
                    if axis.Vertical then
                        if axis:IsOpposite() then
                            pos = ImVec2(axis.Datum1 + gs.LabelPadding.x, pix - size.y * 0.5)
                            DrawList:AddTriangleFilled(ImVec2(axis.Datum1, pix), pos, ImVec2(pos.x, pos.y + size.y), tag.ColorBg)
                        else
                            pos = ImVec2(axis.Datum1 - size.x - gs.LabelPadding.x, pix - size.y * 0.5)
                            DrawList:AddTriangleFilled(ImVec2(pos.x + size.x, pos.y), ImVec2(axis.Datum1, pix), ImVec2(pos.x + size.x, pos.y + size.y), tag.ColorBg)
                        end
                    else
                        if axis:IsOpposite() then
                            pos = ImVec2(pix - size.x * 0.5, axis.Datum1 - size.y - gs.LabelPadding.y)
                            DrawList:AddTriangleFilled(ImVec2(pos.x, pos.y + size.y), ImVec2(pos.x + size.x, pos.y + size.y), ImVec2(pix, axis.Datum1), tag.ColorBg)
                        else
                            pos = ImVec2(pix - size.x * 0.5, axis.Datum1 + gs.LabelPadding.y)
                            DrawList:AddTriangleFilled(pos, ImVec2(pix, axis.Datum1), ImVec2(pos.x + size.x, pos.y), tag.ColorBg)
                        end
                    end
                    DrawList:AddRectFilled(pos, ImVec2(pos.x + size.x, pos.y + size.y), tag.ColorBg)
                    DrawList:AddText(SetTmp(pos.x + gs.AnnotationPadding.x, pos.y + gs.AnnotationPadding.y), tag.ColorFg, txt)
                end
            end

            -- FIT DATA --------------------------------------------------------------
            local fit_equal = ImHasFlag(plot.Flags, ImPlotFlags.Equal)
            if plot.FitThisFrame then
                for i = 0, IMPLOT_NUM_X_AXES - 1 do
                    local x_axis = plot:XAxis(i)
                    if x_axis.FitThisFrame then
                        x_axis:ApplyFit(gs.FitPadding.x)
                        if fit_equal and x_axis.OrthoAxis ~= nil then
                            local aspect = x_axis:GetAspect()
                            local y_axis = x_axis.OrthoAxis
                            if y_axis.FitThisFrame then
                                y_axis:ApplyFit(gs.FitPadding.y)
                                y_axis.FitThisFrame = false
                                aspect = math.max(aspect, y_axis:GetAspect())
                            end
                            x_axis:SetAspect(aspect)
                            y_axis:SetAspect(aspect)
                        end
                    end
                end
                for i = 0, IMPLOT_NUM_Y_AXES - 1 do
                    local y_axis = plot:YAxis(i)
                    if y_axis.FitThisFrame then
                        y_axis:ApplyFit(gs.FitPadding.y)
                        if fit_equal and y_axis.OrthoAxis ~= nil then
                            local aspect = y_axis:GetAspect()
                            local x_axis = y_axis.OrthoAxis
                            if x_axis.FitThisFrame then
                                x_axis:ApplyFit(gs.FitPadding.x)
                                x_axis.FitThisFrame = false
                                aspect = math.max(x_axis:GetAspect(), aspect)
                            end
                            x_axis:SetAspect(aspect)
                            y_axis:SetAspect(aspect)
                        end
                    end
                end
                plot.FitThisFrame = false
            end

            -- CONTEXT MENUS -----------------------------------------------------------
            ImGui.PushOverrideID(plot.ID)

            local can_ctx = gp.OpenContextThisFrame and not ImHasFlag(plot.Flags, ImPlotFlags.NoMenus) and not plot.Items.Legend.Hovered
            local axis_equal = ImHasFlag(plot.Flags, ImPlotFlags.Equal)

            -- main ctx menu
            if can_ctx and plot.Hovered then
                ImGui.OpenPopup("##PlotContext")
            end
            if ImGui.BeginPopup("##PlotContext") then
                internal.ShowPlotContextMenu(plot)
                ImGui.EndPopup()
            end

            -- axes ctx menus
            for i = 0, ImAxis.COUNT - 1 do
                local axis = plot.Axes[i]
                local is_x = i < IMPLOT_NUM_X_AXES
                local n = i
                if not is_x then n = i - IMPLOT_NUM_X_AXES end
                local popup = "##YContext"
                if is_x then popup = "##XContext" end
                ImGui.PushID(n)
                if can_ctx and axis.Hovered and axis:HasMenus() then
                    ImGui.OpenPopup(popup)
                end
                if ImGui.BeginPopup(popup) then
                    local name = "Y-Axis"
                    if is_x then name = "X-Axis" end
                    if n ~= 0 then name = string.format("%s %d", name, n + 1) end
                    if axis:HasLabel() then name = plot:GetAxisLabel(axis) end
                    ImGui.Text(name)
                    ImGui.Separator()
                    internal.ShowAxisContextMenu(axis, axis_equal and axis.OrthoAxis or nil, is_x)
                    ImGui.EndPopup()
                end
                ImGui.PopID()
            end
            ImGui.PopID()

            -- LINKED AXES ------------------------------------------------------------

            for i = 0, ImAxis.COUNT - 1 do
                plot.Axes[i]:PushLinks()
            end

            -- CLEANUP ----------------------------------------------------------------

            -- remove items
            if gp.CurrentItems == plot.Items then
                gp.CurrentItems = nil
            end
            -- reset the plot items for the next frame
            for i = 0, plot.Items:GetItemCount() - 1 do
                local it = plot.Items:GetItemByIndex(i)
                if it then it.SeenThisFrame = false end
            end

            -- mark the plot as initialized, i.e. having made it through one frame completely
            plot.Initialized = true
            -- Pop ImGui::PushID at the end of BeginPlot
            ImGui.PopID()
            -- Reset context for next plot
            internal.ResetCtxForNextPlot(gp)

            -- setup next subplot
            if gp.CurrentSubplot ~= nil then
                ImGui.PopID()
                internal.SubplotNextCell()
            end
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

        function ImPlot.IsAxisHovered(axis)
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "IsPlotXAxisHovered() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            return GImPlot.CurrentPlot.Axes[axis].Hovered
        end

        function ImPlot.IsPlotSelected()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "IsPlotSelected() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            return GImPlot.CurrentPlot.Selected
        end

        function ImPlot.GetPlotSelection(x_idx, y_idx)
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "GetPlotSelection() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            local plot = GImPlot.CurrentPlot
            if not plot.Selected then
                return ImPlot.ImPlotRect(0, 0, 0, 0)
            end
            local sr, pm = plot.SelectRect, plot.PlotRect.Min
            local p1 = ImPlot.PixelsToPlot(sr.Min.x + pm.x, sr.Min.y + pm.y, x_idx, y_idx)
            local p2 = ImPlot.PixelsToPlot(sr.Max.x + pm.x, sr.Max.y + pm.y, x_idx, y_idx)
            return ImPlot.ImPlotRect(math.min(p1.x, p2.x), math.max(p1.x, p2.x), math.min(p1.y, p2.y), math.max(p1.y, p2.y))
        end

        function ImPlot.CancelPlotSelection()
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "CancelPlotSelection() needs to be called between BeginPlot() and EndPlot()!")
            SetupLock()
            local plot = GImPlot.CurrentPlot
            if plot.Selected then
                plot.Selected = false
                plot.Selecting = false
            end
        end

        function ImPlot.SetAxis(axis)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "SetAxis() needs to be called between BeginPlot() and EndPlot()!")
            IM_ASSERT(axis >= ImAxis.X1 and axis < ImAxis.COUNT, "Axis index out of bounds!")
            IM_ASSERT(gp.CurrentPlot.Axes[axis].Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            SetupLock()
            if axis < ImAxis.Y1 then
                gp.CurrentPlot.CurrentX = axis
            else
                gp.CurrentPlot.CurrentY = axis
            end
        end

        function ImPlot.SetAxes(x_idx, y_idx)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "SetAxes() needs to be called between BeginPlot() and EndPlot()!")
            IM_ASSERT(x_idx >= ImAxis.X1 and x_idx < ImAxis.Y1, "X-Axis index out of bounds!")
            IM_ASSERT(y_idx >= ImAxis.Y1 and y_idx < ImAxis.COUNT, "Y-Axis index out of bounds!")
            IM_ASSERT(gp.CurrentPlot.Axes[x_idx].Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            IM_ASSERT(gp.CurrentPlot.Axes[y_idx].Enabled, "Axis is not enabled! Did you forget to call SetupAxis()?")
            SetupLock()
            gp.CurrentPlot.CurrentX = x_idx
            gp.CurrentPlot.CurrentY = y_idx
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Items, Legend, Getters, Fitters, Transformers, Renderers, PlotLine, PlotScatter
    -- (implot_items.cpp + item/legend parts of implot.cpp / implot_internal.h)
    -- [Port] Data arrays are 1-based Lua arrays; indices passed to getters/indexers stay 0-based like upstream.
    -- [Port] Spec.Stride is measured in elements (IMPLOT_AUTO -> 1) instead of bytes.
    -- [Port] Getters return (x, y) numbers instead of an ImPlotPoint so hot loops never allocate.
    --------------------------------------------------------------------------
    do
        local ImAxis = ImPlot.ImAxis
        local ImPlotCol = ImPlot.ImPlotCol
        local ImPlotMarker = ImPlot.ImPlotMarker
        local ImPlotItemFlags = ImPlot.ImPlotItemFlags
        local ImPlotLineFlags = ImPlot.ImPlotLineFlags
        local ImPlotScatterFlags = ImPlot.ImPlotScatterFlags
        local ImPlotLegendFlags = ImPlot.ImPlotLegendFlags
        local ImPlotLocation = ImPlot.ImPlotLocation
        local ImPlotFlags = ImPlot.ImPlotFlags
        local IMPLOT_AUTO = ImPlot.IMPLOT_AUTO
        local ImHasFlag = internal.ImHasFlag
        local GetStyleColorU32 = internal.GetStyleColorU32
        local band, bor, bnot, lshift, rshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift, bit32.rshift
        local writef64, writeu32 = buffer.writef64, buffer.writeu32
        local sqrt, floor, min, max = math.sqrt, math.floor, math.min, math.max
        local ImPlotMarker_Invalid = -3
        internal.ImPlotMarker_Invalid = ImPlotMarker_Invalid

        local SQRT_1_2 = 0.70710678118
        local SQRT_3_2 = 0.86602540378
        -- [Port] ImDrawIdx is unsigned int in the core
        local MAX_IDX = 4294967295

        local function IsColorAuto(col) return col.w == -1 end

        local function ImAlphaU32(col, alpha)
            return band(col, bnot(lshift(floor((1 - alpha) * 255), 24)))
        end
        internal.ImAlphaU32 = ImAlphaU32

        -- [Port] scalar alpha multiply on a packed color (replaces ColorConvertU32ToFloat4 + GetColorU32 per point)
        @native
        local function MulAlphaU32(col, alpha)
            local a = floor(rshift(col, 24) * alpha + 0.5)
            if a > 255 then a = 255 elseif a < 0 then a = 0 end
            return bor(band(col, 0x00FFFFFF), lshift(a, 24))
        end

        local function CopyVec4(dst, src) dst.x, dst.y, dst.z, dst.w = src.x, src.y, src.z, src.w end

        -----------------------------------------------------------------------
        -- ImPlotSpec
        -----------------------------------------------------------------------

        local ImPlotProp = ImPlot.ImPlotProp
        local PROP_FIELD = {}
        for name, v in ImPlotProp do PROP_FIELD[v] = name end
        local VEC4_FIELDS = { "LineColor", "FillColor", "MarkerLineColor", "MarkerFillColor" }
        local SCALAR_FIELDS = { "LineColors", "LineWeight", "FillColors", "FillAlpha", "Marker", "MarkerSize", "MarkerSizes",
                                "MarkerLineColors", "MarkerFillColors", "Size", "Offset", "Stride", "Flags" }

        local function SpecDefaults(s)
            for _, f in VEC4_FIELDS do
                local c = s[f]
                if c then c.x, c.y, c.z, c.w = 0, 0, 0, -1 else s[f] = IMPLOT_AUTO_COL() end
            end
            s.LineColors = nil; s.LineWeight = 1.0
            s.FillColors = nil; s.FillAlpha = 1.0
            s.Marker = ImPlotMarker.None; s.MarkerSize = 4; s.MarkerSizes = nil
            s.MarkerLineColors = nil; s.MarkerFillColors = nil
            s.Size = 4; s.Offset = 0; s.Stride = IMPLOT_AUTO; s.Flags = ImPlotItemFlags.None
            return s
        end

        local SpecMT = {}
        SpecMT.__index = SpecMT
        -- Set properties from (ImPlotProp, value) pairs in any order. Colors may be ImVec4 or ImU32.
        function SpecMT:SetProp(...)
            local n = select("#", ...)
            IM_ASSERT(n % 2 == 0, "Odd number of arguments! You must provide (ImPlotProp,value) pairs!")
            for i = 1, n, 2 do
                local prop, v = select(i, ...)
                local f = PROP_FIELD[prop]
                IM_ASSERT(f ~= nil, "Invalid ImPlotProp")
                if type(v) == "number" and (f == "LineColor" or f == "FillColor" or f == "MarkerLineColor" or f == "MarkerFillColor") then
                    v = ImGui.ColorConvertU32ToFloat4(v)
                end
                self[f] = v
            end
            return self
        end

        -- [Port] ImPlotSpec(): ImPlotSpec(), ImPlotSpec(prop, value, ...) or ImPlotSpec({ LineWeight = 2, ... })
        function ImPlot.ImPlotSpec(...)
            local s = setmetatable(SpecDefaults({}), SpecMT)
            local first = ...
            if type(first) == "table" then
                for k, v in first do s[k] = v end
            elseif first ~= nil then
                s:SetProp(...)
            end
            return s
        end

        local function CopySpec(dst, src)
            for _, f in VEC4_FIELDS do CopyVec4(dst[f], src[f]) end
            for _, f in SCALAR_FIELDS do dst[f] = src[f] end
        end

        -----------------------------------------------------------------------
        -- ImPlotItem, ImPlotLegend, ImPlotItemGroup, ImPlotNextItemData
        -----------------------------------------------------------------------

        -- State information for Plot items
        -- [Port] NameOffset into Legend.Labels -> Label string stored on the item
        function internal.ImPlotItem()
            return {
                ID              = 0,
                Color           = G.IM_COL32_WHITE,
                Marker          = ImPlotMarker.None,
                LegendHoverRect = G.ImRect(),
                Label           = nil,
                Show            = true,
                LegendHovered   = false,
                SeenThisFrame   = false,
            }
        end

        -- Holds Legend state
        local LegendMT = {}
        LegendMT.__index = LegendMT
        function internal.ImPlotLegend()
            return setmetatable({
                Flags = ImPlotLegendFlags.None, PreviousFlags = ImPlotLegendFlags.None,
                Location = ImPlotLocation.NorthWest, PreviousLocation = ImPlotLocation.NorthWest,
                Scroll = ImVec2(0, 0),
                Indices = {}, -- [Port] 1-based array of 0-based ItemPool indices
                Rect = G.ImRect(), RectClamped = G.ImRect(),
                Hovered = false, Held = false, CanGoInside = true,
            }, LegendMT)
        end
        function LegendMT:Reset() table.clear(self.Indices) end

        -- Holds Items and Legend data
        local GroupMT = {}
        GroupMT.__index = GroupMT
        function internal.ImPlotItemGroup()
            return setmetatable({
                ID = 0,
                Legend = internal.ImPlotLegend(),
                ItemPool = G.ImPool(internal.ImPlotItem),
                ColormapIdx = 0,
                MarkerIdx = 0,
            }, GroupMT)
        end
        function GroupMT:GetItemCount()          return self.ItemPool:GetMapSize() end
        function GroupMT:GetItemID(label_id)     return ImGui.GetID(label_id) end
        function GroupMT:GetItem(id)
            if type(id) == "string" then id = self:GetItemID(id) end
            return self.ItemPool:GetByKey(id)
        end
        function GroupMT:GetOrAddItem(id)        return self.ItemPool:GetOrAddByKey(id) end
        function GroupMT:GetItemByIndex(i)       return self.ItemPool:GetByIndex(i) end
        function GroupMT:GetItemIndex(item)      return self.ItemPool:GetIndex(item) end
        function GroupMT:GetLegendCount()        return #self.Legend.Indices end
        function GroupMT:GetLegendItem(i)        return self.ItemPool:GetByIndex(self.Legend.Indices[i + 1]) end
        function GroupMT:GetLegendLabel(i)       return self:GetLegendItem(i).Label end
        function GroupMT:Reset()
            self.ItemPool:Clear(); self.Legend:Reset(); self.ColormapIdx = 0
        end

        -- Temporary data storage for upcoming item
        -- [Port] Override holds values set by the obsolete SetNext*Style() helpers; applied on top of the spec passed to PlotX
        local NextItemMT = {}
        NextItemMT.__index = NextItemMT
        function internal.ImPlotNextItemData()
            local d = setmetatable({ Spec = SpecDefaults({}), Override = {} }, NextItemMT)
            d:Reset()
            return d
        end
        function NextItemMT:Reset()
            SpecDefaults(self.Spec)
            table.clear(self.Override)
            self.HasHidden = false; self.Hidden = false
            self.HiddenCond = ImPlot.ImPlotCond.None
        end

        local function GetItemData() return GImPlot.NextItemData end
        internal.GetItemData = GetItemData

        -- [Port] resolves the user spec (nil / plain table / ImPlotSpec) + SetNext*Style overrides into a reused scratch spec
        local scratch_spec = SpecDefaults({})
        local function ResolveSpec(spec)
            SpecDefaults(scratch_spec)
            if spec ~= nil then
                for k, v in spec do
                    if type(v) == "table" and scratch_spec[k] ~= nil and v.w ~= nil then CopyVec4(scratch_spec[k], v)
                    else scratch_spec[k] = v end
                end
            end
            for k, v in GImPlot.NextItemData.Override do
                if type(v) == "table" then CopyVec4(scratch_spec[k], v) else scratch_spec[k] = v end
            end
            return scratch_spec
        end
        internal.ResolveSpec = ResolveSpec

        -- [Port] obsolete upstream (v1.0) helpers, kept for compatibility: values apply to the next PlotX call only
        local function SetOverride(field, v, is_col)
            if v == nil then return end
            if is_col then
                if IsColorAuto(v) then return end
                v = ImVec4(v.x, v.y, v.z, v.w)
            elseif v == IMPLOT_AUTO then
                return
            end
            GImPlot.NextItemData.Override[field] = v
        end
        function ImPlot.SetNextLineStyle(col, weight)
            SetOverride("LineColor", col, true); SetOverride("LineWeight", weight)
        end
        function ImPlot.SetNextFillStyle(col, alpha_mod)
            SetOverride("FillColor", col, true); SetOverride("FillAlpha", alpha_mod)
        end
        function ImPlot.SetNextMarkerStyle(marker, size, fill, weight, outline)
            SetOverride("Marker", marker); SetOverride("MarkerSize", size)
            SetOverride("MarkerFillColor", fill, true); SetOverride("LineWeight", weight)
            SetOverride("MarkerLineColor", outline, true)
        end
        function ImPlot.SetNextErrorBarStyle(col, size, weight)
            SetOverride("LineColor", col, true); SetOverride("Size", size); SetOverride("LineWeight", weight)
        end

        -----------------------------------------------------------------------
        -- Item Utils
        -----------------------------------------------------------------------

        function ImPlot.NextMarker()
            local gp = GImPlot
            IM_ASSERT(gp.CurrentItems ~= nil, "NextMarker() needs to be called between BeginPlot() and EndPlot()!")
            local idx = gp.CurrentItems.MarkerIdx % ImPlotMarker.COUNT
            gp.CurrentItems.MarkerIdx += 1
            return idx
        end

        -- [Port] just_created is returned as a second value
        function internal.RegisterOrGetItem(label_id, flags)
            local Items = GImPlot.CurrentItems
            local id = Items:GetItemID(label_id)
            local just_created = Items:GetItem(id) == nil
            local item = Items:GetOrAddItem(id)
            if item.SeenThisFrame then
                return item, just_created
            end
            item.SeenThisFrame = true
            local idx = Items:GetItemIndex(item)
            item.ID = id
            if not ImHasFlag(flags, ImPlotItemFlags.NoLegend) and ImGui.FindRenderedTextEnd(label_id) ~= 1 then
                table.insert(Items.Legend.Indices, idx)
                item.Label = label_id
            else
                item.Show = true
            end
            return item, just_created
        end

        function internal.GetItem(label_id)
            return GImPlot.CurrentItems:GetItem(label_id)
        end

        function ImPlot.IsItemHidden(label_id)
            local item = internal.GetItem(label_id)
            return item ~= nil and not item.Show
        end

        function internal.GetCurrentItem() return GImPlot.CurrentItem end

        function ImPlot.GetLastItemColor()
            local gp = GImPlot
            if gp.PreviousItem then
                return ImGui.ColorConvertU32ToFloat4(gp.PreviousItem.Color)
            end
            return ImVec4(0, 0, 0, 0)
        end

        function internal.BustItemCache()
            local gp = GImPlot
            for p = 0, gp.Plots:GetMapSize() - 1 do
                local plot = gp.Plots:GetByIndex(p)
                if plot then plot.Items:Reset() end
            end
            for p = 0, gp.Subplots:GetMapSize() - 1 do
                local subplot = gp.Subplots:GetByIndex(p)
                if subplot then subplot.Items:Reset() end
            end
        end

        function ImPlot.BustColorCache(plot_title_id)
            if plot_title_id == nil then
                internal.BustItemCache()
            else
                local plot = GImPlot.Plots:GetByKey(ImGui.GetCurrentWindow():GetID(plot_title_id))
                if plot ~= nil then plot.Items:Reset() end
            end
        end

        function internal.GetPlotDrawList() return ImGui.GetWindowDrawList() end

        function internal.PushPlotClipRect(expand)
            expand = expand or 0
            local r = GImPlot.CurrentPlot.PlotRect
            ImGui.PushClipRect(ImVec2(r.Min.x - expand, r.Min.y - expand), ImVec2(r.Max.x + expand, r.Max.y + expand), true)
        end
        function internal.PopPlotClipRect() ImGui.PopClipRect() end
        local PushPlotClipRect, PopPlotClipRect = internal.PushPlotClipRect, internal.PopPlotClipRect

        -- public versions (with SetupLock, like upstream)
        function ImPlot.GetPlotDrawList() return internal.GetPlotDrawList() end
        function ImPlot.PushPlotClipRect(expand)
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "PushPlotClipRect() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()
            PushPlotClipRect(expand)
        end
        function ImPlot.PopPlotClipRect()
            internal.SetupLock()
            PopPlotClipRect()
        end

        function ImPlot.HideNextItem(hidden, cond)
            if hidden == nil then hidden = true end
            local d = GImPlot.NextItemData
            d.HasHidden  = true
            d.Hidden     = hidden
            d.HiddenCond = cond or ImPlot.ImPlotCond.Once
        end

        -- ItemIcon(ImVec4) / ItemIcon(ImU32)
        function ImPlot.ItemIcon(col)
            if type(col) == "table" then col = ImGui.ColorConvertFloat4ToU32(col) end
            local txt_size = ImGui.GetTextLineHeight()
            local size = ImVec2(txt_size - 4, txt_size)
            local pos = ImGui.GetCurrentWindow().DC.CursorPos
            ImGui.GetWindowDrawList():AddRectFilled(ImVec2(pos.x, pos.y + 2), ImVec2(pos.x + size.x, pos.y + size.y - 2), col)
            ImGui.Dummy(size)
        end

        -----------------------------------------------------------------------
        -- BeginItem / EndItem
        -----------------------------------------------------------------------

        local ITEM_HIGHLIGHT_LINE_SCALE = 2.0
        local ITEM_HIGHLIGHT_MARK_SCALE = 1.25

        -- Begins a new item. Returns false if the item should not be plotted.
        function internal.BeginItem(label_id, spec, item_col, item_mkr)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "PlotX() needs to be called between BeginPlot() and EndPlot()!")
            spec = spec or ResolveSpec(nil)
            item_col = item_col or IMPLOT_AUTO_COL()
            item_mkr = item_mkr or ImPlotMarker_Invalid
            internal.SetupLock()
            local item, just_created = internal.RegisterOrGetItem(label_id, spec.Flags)
            -- set current item
            gp.CurrentItem = item
            local s = gp.NextItemData
            -- set/override item color
            if not IsColorAuto(item_col) then
                item.Color = ImGui.ColorConvertFloat4ToU32(item_col)
            elseif just_created then
                item.Color = ImPlot.NextColormapColorU32()
            end
            if s.HasHidden then
                if just_created or s.HiddenCond == G.ImGuiCond.Always then
                    item.Show = not s.Hidden
                end
            end
            -- set/override item marker
            if item_mkr ~= ImPlotMarker_Invalid then
                if item_mkr ~= ImPlotMarker.Auto then
                    item.Marker = item_mkr
                elseif just_created then
                    item.Marker = ImPlot.NextMarker()
                elseif item.Marker == ImPlotMarker.None then
                    item.Marker = ImPlot.NextMarker()
                end
            end
            -- return false if not shown
            if not item.Show then
                s:Reset()
                gp.PreviousItem = item
                gp.CurrentItem  = nil
                return false
            end
            local ss = s.Spec
            local c = item.Color
            local r, g_, b, a = band(c, 0xFF) / 255, band(rshift(c, 8), 0xFF) / 255, band(rshift(c, 16), 0xFF) / 255, rshift(c, 24) / 255
            -- stage next item spec
            CopySpec(ss, spec)
            if IsColorAuto(ss.LineColor) then ss.LineColor.x, ss.LineColor.y, ss.LineColor.z, ss.LineColor.w = r, g_, b, a end
            if IsColorAuto(ss.FillColor) then ss.FillColor.x, ss.FillColor.y, ss.FillColor.z, ss.FillColor.w = r, g_, b, a end
            ss.FillColor.w *= ss.FillAlpha
            ss.Marker = item.Marker
            if IsColorAuto(ss.MarkerLineColor) then CopyVec4(ss.MarkerLineColor, ss.LineColor) end
            if IsColorAuto(ss.MarkerFillColor) then CopyVec4(ss.MarkerFillColor, ss.LineColor) end
            ss.MarkerFillColor.w *= ss.FillAlpha
            -- apply highlight mods
            if item.LegendHovered then
                local lflags = gp.CurrentItems.Legend.Flags
                if not ImHasFlag(lflags, ImPlotLegendFlags.NoHighlightItem) then
                    ss.LineWeight *= ITEM_HIGHLIGHT_LINE_SCALE
                    ss.MarkerSize *= ITEM_HIGHLIGHT_MARK_SCALE
                    ss.Size *= ITEM_HIGHLIGHT_MARK_SCALE
                end
                if not ImHasFlag(lflags, ImPlotLegendFlags.NoHighlightAxis) then
                    local plot = gp.CurrentPlot
                    if plot:EnabledAxesX() > 1 then plot.Axes[plot.CurrentX].ColorHiLi = item.Color end
                    if plot:EnabledAxesY() > 1 then plot.Axes[plot.CurrentY].ColorHiLi = item.Color end
                end
            end
            -- set render flags
            s.RenderLine       = ss.LineColor.w > 0 and ss.LineWeight > 0
            s.RenderFill       = ss.FillColor.w > 0
            s.RenderMarkerLine = ss.MarkerLineColor.w > 0 and ss.LineWeight > 0
            s.RenderMarkerFill = ss.MarkerFillColor.w > 0
            s.RenderMarkers    = ss.Marker >= 0 and (s.RenderMarkerFill or s.RenderMarkerLine)
            -- push rendering clip rect
            PushPlotClipRect()
            return true
        end
        local BeginItem = internal.BeginItem

        -- Same as above but with fitting functionality. fitter: table with Fit(self, x_axis, y_axis)
        function internal.BeginItemEx(label_id, fitter, spec, item_col, item_mkr)
            if BeginItem(label_id, spec, item_col, item_mkr) then
                local plot = GImPlot.CurrentPlot
                if plot.FitThisFrame and not ImHasFlag(spec.Flags, ImPlotItemFlags.NoFit) then
                    fitter:Fit(plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY])
                end
                return true
            end
            return false
        end
        local BeginItemEx = internal.BeginItemEx

        -- Ends an item (call only if BeginItem returns true)
        function internal.EndItem()
            local gp = GImPlot
            PopPlotClipRect()
            gp.NextItemData:Reset()
            gp.PreviousItem = gp.CurrentItem
            gp.CurrentItem  = nil
        end
        local EndItem = internal.EndItem

        -----------------------------------------------------------------------
        -- Indexers
        -----------------------------------------------------------------------

        -- [Port] IndexData switch -> one At function per case, picked at construction
        @native
        local function IdxAt3(self, i) return self.Data[i + 1] end
        @native
        local function IdxAt2(self, i) return self.Data[(self.Offset + i) % self.Count + 1] end
        @native
        local function IdxAt1(self, i) return self.Data[i * self.Stride + 1] end
        @native
        local function IdxAt0(self, i) return self.Data[((self.Offset + i) % self.Count) * self.Stride + 1] end

        function internal.IndexerIdx(data, count, offset, stride)
            offset = offset or 0
            if stride == nil or stride == IMPLOT_AUTO then stride = 1 end
            if count ~= 0 then offset = offset % count else offset = 0 end
            local at
            if offset == 0 and stride == 1 then at = IdxAt3
            elseif stride == 1 then at = IdxAt2
            elseif offset == 0 then at = IdxAt1
            else at = IdxAt0 end
            return { Data = data, Count = count, Offset = offset, Stride = stride, At = at }
        end

        @native
        -- [Luau] the array behind a plain (offset 0, stride 1) IndexerIdx, or nil: hot loops read it directly instead of
        -- calling At per value (same values)
        local function PlainData(indexer) return indexer.At == IdxAt3 and indexer.Data or nil end
        internal.PlainData = PlainData

        @native
        local function LinAt(self, i) return self.M * i + self.B end
        function internal.IndexerLin(m, b) return { M = m, B = b, At = LinAt } end

        @native
        local function ConstAt(self) return self.Ref end
        function internal.IndexerConst(ref) return { Ref = ref, At = ConstAt } end

        -----------------------------------------------------------------------
        -- Getters
        -----------------------------------------------------------------------

        @native
        local function XYGet(self, i)
            local ix, iy = self.IndexerX, self.IndexerY
            return ix.At(ix, i), iy.At(iy, i)
        end
        function internal.GetterXY(ix, iy, count) return { IndexerX = ix, IndexerY = iy, Count = count, Get = XYGet } end

        @native
        local function OverrideXGet(self, i) local g = self.Getter; local _, y = g.Get(g, i); return self.X, y end
        function internal.GetterOverrideX(getter, x) return { Getter = getter, X = x, Count = getter.Count, Get = OverrideXGet } end

        @native
        local function OverrideYGet(self, i) local g = self.Getter; local x = g.Get(g, i); return x, self.Y end
        function internal.GetterOverrideY(getter, y) return { Getter = getter, Y = y, Count = getter.Count, Get = OverrideYGet } end

        @native
        local function LoopGet(self, i) local g = self.Getter; return g.Get(g, i % (self.Count - 1)) end
        function internal.GetterLoop(getter) return { Getter = getter, Count = getter.Count + 1, Get = LoopGet } end

        -- [Port] getter(idx, data) may return an ImPlotPoint or (x, y)
        local function FuncGet(self, i)
            local x, y = self.Getter(i, self.Data)
            if type(x) == "table" then return x.x, x.y end
            return x, y
        end
        function internal.GetterFuncPtr(getter, data, count) return { Getter = getter, Data = data, Count = count, Get = FuncGet } end

        -----------------------------------------------------------------------
        -- Fitters
        -----------------------------------------------------------------------

        @native
        local function Fitter1Fit(self, x_axis, y_axis)
            local g = self.Getter
            local get = g.Get
            for i = 0, g.Count - 1 do
                local x, y = get(g, i)
                x_axis:ExtendFitWith(y_axis, x, y)
                y_axis:ExtendFitWith(x_axis, y, x)
            end
        end
        function internal.Fitter1(getter) return { Getter = getter, Fit = Fitter1Fit } end

        @native
        local function FitterXFit(self, x_axis)
            local g = self.Getter
            for i = 0, g.Count - 1 do local x = g.Get(g, i); x_axis:ExtendFit(x) end
        end
        function internal.FitterX(getter) return { Getter = getter, Fit = FitterXFit } end

        @native
        local function FitterYFit(self, _, y_axis)
            local g = self.Getter
            for i = 0, g.Count - 1 do local _, y = g.Get(g, i); y_axis:ExtendFit(y) end
        end
        function internal.FitterY(getter) return { Getter = getter, Fit = FitterYFit } end

        local function Fitter2Fit(self, x_axis, y_axis)
            Fitter1Fit({ Getter = self.Getter1 }, x_axis, y_axis)
            Fitter1Fit({ Getter = self.Getter2 }, x_axis, y_axis)
        end
        function internal.Fitter2(g1, g2) return { Getter1 = g1, Getter2 = g2, Fit = Fitter2Fit } end

        local function FitterRectFit(self, x_axis, y_axis)
            x_axis:ExtendFitWith(y_axis, self.MinX, self.MinY)
            y_axis:ExtendFitWith(x_axis, self.MinY, self.MinX)
            x_axis:ExtendFitWith(y_axis, self.MaxX, self.MaxY)
            y_axis:ExtendFitWith(x_axis, self.MaxY, self.MaxX)
        end
        function internal.FitterRect(min_x, min_y, max_x, max_y)
            return { MinX = min_x, MinY = min_y, MaxX = max_x, MaxY = max_y, Fit = FitterRectFit }
        end

        -----------------------------------------------------------------------
        -- Transformers
        -- [Port] Transformer2 state lives in upvalues (set per RenderPrimitives call) so transforms are plain calls.
        -----------------------------------------------------------------------

        local tx_pixmin, tx_pltmin, tx_pltmax, tx_m, tx_scamin, tx_scamax, tx_fwd, tx_data = 0, 0, 1, 1, 0, 1, nil, nil
        local ty_pixmin, ty_pltmin, ty_pltmax, ty_m, ty_scamin, ty_scamax, ty_fwd, ty_data = 0, 0, 1, 1, 0, 1, nil, nil

        local function TransformX(p)
            if tx_fwd ~= nil then
                local s = tx_fwd(p, tx_data)
                local t = (s - tx_scamin) / (tx_scamax - tx_scamin)
                p = tx_pltmin + (tx_pltmax - tx_pltmin) * t
            end
            return tx_pixmin + tx_m * (p - tx_pltmin)
        end
        local function TransformY(p)
            if ty_fwd ~= nil then
                local s = ty_fwd(p, ty_data)
                local t = (s - ty_scamin) / (ty_scamax - ty_scamin)
                p = ty_pltmin + (ty_pltmax - ty_pltmin) * t
            end
            return ty_pixmin + ty_m * (p - ty_pltmin)
        end

        function internal.SetTransformer(x_axis, y_axis)
            tx_pixmin, tx_pltmin, tx_pltmax, tx_m = x_axis.PixelMin, x_axis.Range.Min, x_axis.Range.Max, x_axis.ScaleToPixel
            tx_scamin, tx_scamax, tx_fwd, tx_data = x_axis.ScaleMin, x_axis.ScaleMax, x_axis.TransformForward, x_axis.TransformData
            ty_pixmin, ty_pltmin, ty_pltmax, ty_m = y_axis.PixelMin, y_axis.Range.Min, y_axis.Range.Max, y_axis.ScaleToPixel
            ty_scamin, ty_scamax, ty_fwd, ty_data = y_axis.ScaleMin, y_axis.ScaleMax, y_axis.TransformForward, y_axis.TransformData
        end
        internal.TransformX, internal.TransformY = TransformX, TransformY

        -----------------------------------------------------------------------
        -- Primitive writers (match ImDrawList: VtxBuffer.Buf, VTX_STRIDE = 36, 1-based write ptrs/_VtxCurrentIdx)
        -----------------------------------------------------------------------

        local VTX_STRIDE = G.VTX_STRIDE or 36

        @native
        local function WV(b, o, x, y, u, v, col)
            writef64(b, o, x); writef64(b, o + 8, y); writef64(b, o + 16, u); writef64(b, o + 24, v); writeu32(b, o + 32, col)
        end

        @native
        local function PrimLine(dl, x1, y1, x2, y2, hw, col, u0, v0, u1, v1)
            local dx, dy = x2 - x1, y2 - y1
            local d2 = dx * dx + dy * dy
            if d2 > 0 then local inv = 1 / sqrt(d2); dx *= inv; dy *= inv end
            dx *= hw; dy *= hw
            local b = dl.VtxBuffer.Buf
            local vw = dl._VtxWritePtr
            local o = (vw - 1) * VTX_STRIDE
            WV(b, o,                  x1 + dy, y1 - dx, u0, v0, col)
            WV(b, o + VTX_STRIDE,     x2 + dy, y2 - dx, u0, v0, col)
            WV(b, o + VTX_STRIDE * 2, x2 - dy, y2 + dx, u1, v1, col)
            WV(b, o + VTX_STRIDE * 3, x1 - dy, y1 + dx, u1, v1, col)
            local idx = dl._VtxCurrentIdx
            local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
            id[iw] = idx; id[iw + 1] = idx + 1; id[iw + 2] = idx + 2
            id[iw + 3] = idx; id[iw + 4] = idx + 2; id[iw + 5] = idx + 3
            dl._VtxWritePtr = vw + 4; dl._IdxWritePtr = iw + 6; dl._VtxCurrentIdx = idx + 4
        end
        internal.PrimLine = PrimLine

        @native
        local function PrimRectFill(dl, x1, y1, x2, y2, col, u, v)
            local b = dl.VtxBuffer.Buf
            local vw = dl._VtxWritePtr
            local o = (vw - 1) * VTX_STRIDE
            WV(b, o,                  x1, y1, u, v, col)
            WV(b, o + VTX_STRIDE,     x2, y2, u, v, col)
            WV(b, o + VTX_STRIDE * 2, x1, y2, u, v, col)
            WV(b, o + VTX_STRIDE * 3, x2, y1, u, v, col)
            local idx = dl._VtxCurrentIdx
            local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
            id[iw] = idx; id[iw + 1] = idx + 1; id[iw + 2] = idx + 2
            id[iw + 3] = idx; id[iw + 4] = idx + 1; id[iw + 5] = idx + 3
            dl._VtxWritePtr = vw + 4; dl._IdxWritePtr = iw + 6; dl._VtxCurrentIdx = idx + 4
        end
        internal.PrimRectFill = PrimRectFill

        -- [Port] GetLineRenderProps returns (half_weight, u0, v0, u1, v1)
        local function GetLineRenderProps(dl, half_weight)
            local u0, v0, u1, v1, fringe = dl:_SelectLineTexture(half_weight * 2.0, dl.Flags)
            return half_weight + fringe * 0.5, u0, v0, u1, v1
        end

        local function Overlaps(cr, x1, y1, x2, y2)
            -- cull_rect.Overlaps(ImRect(ImMin(P1,P2), ImMax(P1,P2)))
            local minx, maxx = x1, x2
            if x2 < x1 then minx, maxx = x2, x1 end
            local miny, maxy = y1, y2
            if y2 < y1 then miny, maxy = y2, y1 end
            return miny < cr.Max.y and maxy > cr.Min.y and minx < cr.Max.x and maxx > cr.Min.x
        end

        -- [Port] color/size getters collapsed into renderer fields: Cols (1-based U32 array or nil) + Col, Sizes or Size
        local function GetCol(r, prim)
            local cols = r.Cols
            if cols == nil then return r.Col end
            IM_ASSERT(prim >= 0 and prim < r.ColCount)
            local c = cols[prim + 1]
            if r.ColAlpha < 1 then c = MulAlphaU32(c, r.ColAlpha) end
            return c
        end

        local function ConstColor(col, alpha)
            if alpha ~= nil and alpha < 1 then return MulAlphaU32(col, alpha) end
            return col
        end

        local function SetColors(r, cols, count, col, alpha)
            r.Cols, r.ColCount, r.Col, r.ColAlpha = cols, count, ConstColor(col, alpha), alpha or 1
            return r
        end

        -----------------------------------------------------------------------
        -- Renderers
        -- [Port] renderer = table { Prims, IdxConsumed, VtxConsumed, Init(r, dl), Render(r, dl, cull_rect, prim) -> bool }
        -----------------------------------------------------------------------

        local function LineInit(r, dl)
            r.HalfWeight, r.U0, r.V0, r.U1, r.V1 = GetLineRenderProps(dl, r.HalfWeight)
        end
        local function WhiteInit(r, dl)
            local uv = dl._Data.TexUvWhitePixel
            r.U, r.V = uv.x, uv.y
        end

        @native
        local function LineStripRender(r, dl, cr, prim)
            local g = r.Getter
            local x, y = g.Get(g, prim + 1)
            local p2x, p2y = TransformX(x), TransformY(y)
            local p1x, p1y = r.P1x, r.P1y
            if not Overlaps(cr, p1x, p1y, p2x, p2y) then
                if not r.Skip or (p2x == p2x and p2y == p2y) then r.P1x, r.P1y = p2x, p2y end
                return false
            end
            PrimLine(dl, p1x, p1y, p2x, p2y, r.HalfWeight, GetCol(r, prim), r.U0, r.V0, r.U1, r.V1)
            if not r.Skip or (p2x == p2x and p2y == p2y) then r.P1x, r.P1y = p2x, p2y end
            return true
        end

        -- [Port] prims i0..i1 in one call when the getter reads two plain arrays (no axis transform functions):
        -- LineStripRender + XYGet + TransformX/Y + Overlaps + GetCol + PrimLine inlined, same math. Returns culled count.
        @native
        local function LineStripRange(r, dl, cr, i0, i1)
            local g = r.Getter
            local ix, iy = g.IndexerX, g.IndexerY
            local cols, alpha = r.Cols, r.ColAlpha
            if g.Get ~= XYGet or ix.At ~= IdxAt3 or iy.At ~= IdxAt3 or tx_fwd ~= nil or ty_fwd ~= nil or (cols ~= nil and (i0 < 0 or i1 >= r.ColCount)) then
                local culled = 0
                for i = i0, i1 do
                    if not LineStripRender(r, dl, cr, i) then culled += 1 end
                end
                return culled
            end
            local xs, ys = ix.Data, iy.Data
            local cminx, cminy, cmaxx, cmaxy = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
            local xpm, xm, xpl, ypm, ym, ypl = tx_pixmin, tx_m, tx_pltmin, ty_pixmin, ty_m, ty_pltmin
            local hw, col, u0, v0, u1, v1, skip = r.HalfWeight, r.Col, r.U0, r.V0, r.U1, r.V1, r.Skip
            local b, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
            local vw, iw, idx = dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx
            local p1x, p1y = r.P1x, r.P1y
            local culled = 0
            for i = i0, i1 do
                local p2x, p2y = xpm + xm * (xs[i + 2] - xpl), ypm + ym * (ys[i + 2] - ypl)
                local minx, maxx = p1x, p2x
                if p2x < p1x then minx, maxx = p2x, p1x end
                local miny, maxy = p1y, p2y
                if p2y < p1y then miny, maxy = p2y, p1y end
                if miny < cmaxy and maxy > cminy and minx < cmaxx and maxx > cminx then
                    local c = col
                    if cols ~= nil then
                        c = cols[i + 1]
                        if alpha < 1 then c = MulAlphaU32(c, alpha) end
                    end
                    local dx, dy = p2x - p1x, p2y - p1y
                    local d2 = dx * dx + dy * dy
                    if d2 > 0 then local inv = 1 / sqrt(d2); dx *= inv; dy *= inv end
                    dx *= hw; dy *= hw
                    local o = (vw - 1) * VTX_STRIDE
                    WV(b, o,                  p1x + dy, p1y - dx, u0, v0, c)
                    WV(b, o + VTX_STRIDE,     p2x + dy, p2y - dx, u0, v0, c)
                    WV(b, o + VTX_STRIDE * 2, p2x - dy, p2y + dx, u1, v1, c)
                    WV(b, o + VTX_STRIDE * 3, p1x - dy, p1y + dx, u1, v1, c)
                    id[iw] = idx; id[iw + 1] = idx + 1; id[iw + 2] = idx + 2
                    id[iw + 3] = idx; id[iw + 4] = idx + 2; id[iw + 5] = idx + 3
                    vw += 4; iw += 6; idx += 4
                else
                    culled += 1
                end
                if not skip or (p2x == p2x and p2y == p2y) then p1x, p1y = p2x, p2y end
            end
            dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx = vw, iw, idx
            r.P1x, r.P1y = p1x, p1y
            return culled
        end

        -- RendererLineStrip / RendererLineStripSkip (skip = true skips NaNs)
        function internal.RendererLineStrip(getter, weight, skip)
            local x, y = getter.Get(getter, 0)
            return {
                Prims = getter.Count - 1, IdxConsumed = 6, VtxConsumed = 4,
                Getter = getter, HalfWeight = max(1.0, weight) * 0.5, Skip = skip or false,
                P1x = TransformX(x), P1y = TransformY(y),
                Init = LineInit, Render = LineStripRender, RenderRange = LineStripRange,
            }
        end

        @native
        local function LineSegments1Render(r, dl, cr, prim)
            local g = r.Getter
            local x1, y1 = g.Get(g, prim * 2)
            local x2, y2 = g.Get(g, prim * 2 + 1)
            local p1x, p1y, p2x, p2y = TransformX(x1), TransformY(y1), TransformX(x2), TransformY(y2)
            if not Overlaps(cr, p1x, p1y, p2x, p2y) then return false end
            PrimLine(dl, p1x, p1y, p2x, p2y, r.HalfWeight, GetCol(r, prim * 2), r.U0, r.V0, r.U1, r.V1)
            return true
        end
        function internal.RendererLineSegments1(getter, weight)
            return {
                Prims = getter.Count // 2, IdxConsumed = 6, VtxConsumed = 4,
                Getter = getter, HalfWeight = max(1.0, weight) * 0.5,
                Init = LineInit, Render = LineSegments1Render,
            }
        end

        @native
        local function LineSegments2Render(r, dl, cr, prim)
            local g1, g2 = r.Getter1, r.Getter2
            local x1, y1 = g1.Get(g1, prim)
            local x2, y2 = g2.Get(g2, prim)
            local p1x, p1y, p2x, p2y = TransformX(x1), TransformY(y1), TransformX(x2), TransformY(y2)
            if not Overlaps(cr, p1x, p1y, p2x, p2y) then return false end
            PrimLine(dl, p1x, p1y, p2x, p2y, r.HalfWeight, GetCol(r, prim), r.U0, r.V0, r.U1, r.V1)
            return true
        end
        function internal.RendererLineSegments2(getter1, getter2, weight)
            return {
                Prims = min(getter1.Count, getter2.Count), IdxConsumed = 6, VtxConsumed = 4,
                Getter1 = getter1, Getter2 = getter2, HalfWeight = max(1.0, weight) * 0.5,
                Init = LineInit, Render = LineSegments2Render,
            }
        end

        @native
        local function ShadedRender(r, dl, cr, prim)
            local g1, g2 = r.Getter1, r.Getter2
            local ax, ay = g1.Get(g1, prim + 1)
            local bx, by = g2.Get(g2, prim + 1)
            local p21x, p21y, p22x, p22y = TransformX(ax), TransformY(ay), TransformX(bx), TransformY(by)
            local p11x, p11y, p12x, p12y = r.P11x, r.P11y, r.P12x, r.P12y
            local minx, miny = min(p11x, p12x, p21x, p22x), min(p11y, p12y, p21y, p22y)
            local maxx, maxy = max(p11x, p12x, p21x, p22x), max(p11y, p12y, p21y, p22y)
            r.P11x, r.P11y, r.P12x, r.P12y = p21x, p21y, p22x, p22y
            if not (miny < cr.Max.y and maxy > cr.Min.y and minx < cr.Max.x and maxx > cr.Min.x) then
                return false
            end
            local col = GetCol(r, prim)
            local intersect = ((p11y > p12y and p22y > p21y) or (p12y > p11y and p21y > p22y)) and 1 or 0
            local ix, iy = 0, 0
            if intersect == 1 then
                -- Intersection(P11,P21,P12,P22)
                local v1 = p11x * p21y - p11y * p21x
                local v2 = p12x * p22y - p12y * p22x
                local v3 = (p11x - p21x) * (p12y - p22y) - (p11y - p21y) * (p12x - p22x)
                ix = (v1 * (p12x - p22x) - v2 * (p11x - p21x)) / v3
                iy = (v1 * (p12y - p22y) - v2 * (p11y - p21y)) / v3
            end
            local u, v = r.U, r.V
            local b = dl.VtxBuffer.Buf
            local vw = dl._VtxWritePtr
            local o = (vw - 1) * VTX_STRIDE
            WV(b, o,                  p11x, p11y, u, v, col)
            WV(b, o + VTX_STRIDE,     p21x, p21y, u, v, col)
            WV(b, o + VTX_STRIDE * 2, ix, iy, u, v, col)
            WV(b, o + VTX_STRIDE * 3, p12x, p12y, u, v, col)
            WV(b, o + VTX_STRIDE * 4, p22x, p22y, u, v, col)
            local idx = dl._VtxCurrentIdx
            local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
            id[iw] = idx; id[iw + 1] = idx + 1 + intersect; id[iw + 2] = idx + 3
            id[iw + 3] = idx + 1; id[iw + 4] = idx + 4; id[iw + 5] = idx + 3 - intersect
            dl._VtxWritePtr = vw + 5; dl._IdxWritePtr = iw + 6; dl._VtxCurrentIdx = idx + 5
            return true
        end
        -- [Luau] prims i0..i1 in one call when both getters are GetterXY and there are no axis transform functions:
        -- ShadedRender + XYGet + TransformX/Y + GetCol inlined (plain arrays read directly), same math. Returns culled count.
        @native
        local function ShadedRange(r, dl, cr, i0, i1)
            local g1, g2 = r.Getter1, r.Getter2
            local cols, alpha = r.Cols, r.ColAlpha
            if g1.Get ~= XYGet or g2.Get ~= XYGet or tx_fwd ~= nil or ty_fwd ~= nil or (cols ~= nil and (i0 < 0 or i1 >= r.ColCount)) then
                local culled = 0
                for i = i0, i1 do
                    if not ShadedRender(r, dl, cr, i) then culled += 1 end
                end
                return culled
            end
            local iax, iay, ibx, iby = g1.IndexerX, g1.IndexerY, g2.IndexerX, g2.IndexerY
            local dax, day, dbx, dby = PlainData(iax), PlainData(iay), PlainData(ibx), PlainData(iby)
            local cminx, cminy, cmaxx, cmaxy = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
            local xpm, xm, xpl, ypm, ym, ypl = tx_pixmin, tx_m, tx_pltmin, ty_pixmin, ty_m, ty_pltmin
            local p11x, p11y, p12x, p12y = r.P11x, r.P11y, r.P12x, r.P12y
            local col, u, v = r.Col, r.U, r.V
            local b, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
            local vw, iw, idx = dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx
            local culled = 0
            for prim = i0, i1 do
                local j = prim + 1
                local ax = dax and dax[j + 1] or iax.At(iax, j)
                local ay = day and day[j + 1] or iay.At(iay, j)
                local bx = dbx and dbx[j + 1] or ibx.At(ibx, j)
                local by = dby and dby[j + 1] or iby.At(iby, j)
                local p21x, p21y = xpm + xm * (ax - xpl), ypm + ym * (ay - ypl)
                local p22x, p22y = xpm + xm * (bx - xpl), ypm + ym * (by - ypl)
                local minx, miny = min(p11x, p12x, p21x, p22x), min(p11y, p12y, p21y, p22y)
                local maxx, maxy = max(p11x, p12x, p21x, p22x), max(p11y, p12y, p21y, p22y)
                if miny < cmaxy and maxy > cminy and minx < cmaxx and maxx > cminx then
                    local c = col
                    if cols ~= nil then
                        c = cols[prim + 1]
                        if alpha < 1 then c = MulAlphaU32(c, alpha) end
                    end
                    local intersect = ((p11y > p12y and p22y > p21y) or (p12y > p11y and p21y > p22y)) and 1 or 0
                    local ix, iy = 0, 0
                    if intersect == 1 then
                        -- Intersection(P11,P21,P12,P22)
                        local v1 = p11x * p21y - p11y * p21x
                        local v2 = p12x * p22y - p12y * p22x
                        local v3 = (p11x - p21x) * (p12y - p22y) - (p11y - p21y) * (p12x - p22x)
                        ix = (v1 * (p12x - p22x) - v2 * (p11x - p21x)) / v3
                        iy = (v1 * (p12y - p22y) - v2 * (p11y - p21y)) / v3
                    end
                    local o = (vw - 1) * VTX_STRIDE
                    WV(b, o,                  p11x, p11y, u, v, c)
                    WV(b, o + VTX_STRIDE,     p21x, p21y, u, v, c)
                    WV(b, o + VTX_STRIDE * 2, ix, iy, u, v, c)
                    WV(b, o + VTX_STRIDE * 3, p12x, p12y, u, v, c)
                    WV(b, o + VTX_STRIDE * 4, p22x, p22y, u, v, c)
                    id[iw] = idx; id[iw + 1] = idx + 1 + intersect; id[iw + 2] = idx + 3
                    id[iw + 3] = idx + 1; id[iw + 4] = idx + 4; id[iw + 5] = idx + 3 - intersect
                    vw += 5; iw += 6; idx += 5
                else
                    culled += 1
                end
                p11x, p11y, p12x, p12y = p21x, p21y, p22x, p22y
            end
            dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx = vw, iw, idx
            r.P11x, r.P11y, r.P12x, r.P12y = p11x, p11y, p12x, p12y
            return culled
        end
        function internal.RendererShaded(getter1, getter2)
            local ax, ay = getter1.Get(getter1, 0)
            local bx, by = getter2.Get(getter2, 0)
            return {
                Prims = min(getter1.Count, getter2.Count) - 1, IdxConsumed = 6, VtxConsumed = 5,
                Getter1 = getter1, Getter2 = getter2,
                P11x = TransformX(ax), P11y = TransformY(ay), P12x = TransformX(bx), P12y = TransformY(by),
                Init = WhiteInit, Render = ShadedRender, RenderRange = ShadedRange,
            }
        end

        @native
        local function MarkersFillRender(r, dl, cr, prim)
            local g = r.Getter
            local x, y = g.Get(g, prim)
            local px, py = TransformX(x), TransformY(y)
            if px >= cr.Min.x and py >= cr.Min.y and px <= cr.Max.x and py <= cr.Max.y then
                local col = GetCol(r, prim)
                local size = r.Size
                if r.Sizes then size = r.Sizes[prim + 1] end
                local m, count, u, v = r.Marker, r.Count, r.U, r.V
                local b = dl.VtxBuffer.Buf
                local vw = dl._VtxWritePtr
                local o = (vw - 1) * VTX_STRIDE
                for i = 0, count - 1 do
                    WV(b, o + i * VTX_STRIDE, px + m[i * 2 + 1] * size, py + m[i * 2 + 2] * size, u, v, col)
                end
                local idx = dl._VtxCurrentIdx
                local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
                for i = 2, count - 1 do
                    id[iw] = idx; id[iw + 1] = idx + i - 1; id[iw + 2] = idx + i
                    iw += 3
                end
                dl._VtxWritePtr = vw + count; dl._IdxWritePtr = iw; dl._VtxCurrentIdx = idx + count
                return true
            end
            return false
        end
        -- [Port] plain-array getter, no axis transform functions, one colour: point read + transform inlined
        local function PlainXY(r)
            local g = r.Getter
            return g.Get == XYGet and g.IndexerX.At == IdxAt3 and g.IndexerY.At == IdxAt3 and tx_fwd == nil
                and ty_fwd == nil and r.Cols == nil
        end

        @native
        local function MarkersFillRange(r, dl, cr, i0, i1)
            if not PlainXY(r) then
                local culled = 0
                for i = i0, i1 do
                    if not MarkersFillRender(r, dl, cr, i) then culled += 1 end
                end
                return culled
            end
            local g = r.Getter
            local xs, ys = g.IndexerX.Data, g.IndexerY.Data
            local cminx, cminy, cmaxx, cmaxy = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
            local m, count, u, v, col, sizes, size = r.Marker, r.Count, r.U, r.V, r.Col, r.Sizes, r.Size
            local b, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
            local vw, iw, idx = dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx
            local culled = 0
            for prim = i0, i1 do
                local px, py = tx_pixmin + tx_m * (xs[prim + 1] - tx_pltmin), ty_pixmin + ty_m * (ys[prim + 1] - ty_pltmin)
                if px >= cminx and py >= cminy and px <= cmaxx and py <= cmaxy then
                    local sz = size
                    if sizes then sz = sizes[prim + 1] end
                    local o = (vw - 1) * VTX_STRIDE
                    for i = 0, count - 1 do
                        WV(b, o + i * VTX_STRIDE, px + m[i * 2 + 1] * sz, py + m[i * 2 + 2] * sz, u, v, col)
                    end
                    for i = 2, count - 1 do
                        id[iw] = idx; id[iw + 1] = idx + i - 1; id[iw + 2] = idx + i
                        iw += 3
                    end
                    vw += count; idx += count
                else
                    culled += 1
                end
            end
            dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx = vw, iw, idx
            return culled
        end

        function internal.RendererMarkersFill(getter, marker, count)
            return {
                Prims = getter.Count, IdxConsumed = (count - 2) * 3, VtxConsumed = count,
                Getter = getter, Marker = marker, Count = count,
                Init = WhiteInit, Render = MarkersFillRender, RenderRange = MarkersFillRange,
            }
        end

        @native
        local function MarkersLineRender(r, dl, cr, prim)
            local g = r.Getter
            local x, y = g.Get(g, prim)
            local px, py = TransformX(x), TransformY(y)
            if px >= cr.Min.x and py >= cr.Min.y and px <= cr.Max.x and py <= cr.Max.y then
                local col = GetCol(r, prim)
                local size = r.Size
                if r.Sizes then size = r.Sizes[prim + 1] end
                local m, hw, u0, v0, u1, v1 = r.Marker, r.HalfWeight, r.U0, r.V0, r.U1, r.V1
                for i = 0, r.Count - 1, 2 do
                    PrimLine(dl, px + m[i * 2 + 1] * size, py + m[i * 2 + 2] * size,
                                 px + m[i * 2 + 3] * size, py + m[i * 2 + 4] * size, hw, col, u0, v0, u1, v1)
                end
                return true
            end
            return false
        end
        @native
        local function MarkersLineRange(r, dl, cr, i0, i1)
            if not PlainXY(r) then
                local culled = 0
                for i = i0, i1 do
                    if not MarkersLineRender(r, dl, cr, i) then culled += 1 end
                end
                return culled
            end
            local g = r.Getter
            local xs, ys = g.IndexerX.Data, g.IndexerY.Data
            local cminx, cminy, cmaxx, cmaxy = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
            local m, count, col, sizes, size = r.Marker, r.Count, r.Col, r.Sizes, r.Size
            local hw, u0, v0, u1, v1 = r.HalfWeight, r.U0, r.V0, r.U1, r.V1
            local b, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
            local vw, iw, idx = dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx
            local culled = 0
            for prim = i0, i1 do
                local px, py = tx_pixmin + tx_m * (xs[prim + 1] - tx_pltmin), ty_pixmin + ty_m * (ys[prim + 1] - ty_pltmin)
                if px >= cminx and py >= cminy and px <= cmaxx and py <= cmaxy then
                    local sz = size
                    if sizes then sz = sizes[prim + 1] end
                    for i = 0, count - 1, 2 do
                        -- PrimLine inlined
                        local x1, y1 = px + m[i * 2 + 1] * sz, py + m[i * 2 + 2] * sz
                        local x2, y2 = px + m[i * 2 + 3] * sz, py + m[i * 2 + 4] * sz
                        local dx, dy = x2 - x1, y2 - y1
                        local d2 = dx * dx + dy * dy
                        if d2 > 0 then local inv = 1 / sqrt(d2); dx *= inv; dy *= inv end
                        dx *= hw; dy *= hw
                        local o = (vw - 1) * VTX_STRIDE
                        WV(b, o,                  x1 + dy, y1 - dx, u0, v0, col)
                        WV(b, o + VTX_STRIDE,     x2 + dy, y2 - dx, u0, v0, col)
                        WV(b, o + VTX_STRIDE * 2, x2 - dy, y2 + dx, u1, v1, col)
                        WV(b, o + VTX_STRIDE * 3, x1 - dy, y1 + dx, u1, v1, col)
                        id[iw] = idx; id[iw + 1] = idx + 1; id[iw + 2] = idx + 2
                        id[iw + 3] = idx; id[iw + 4] = idx + 2; id[iw + 5] = idx + 3
                        vw += 4; iw += 6; idx += 4
                    end
                else
                    culled += 1
                end
            end
            dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx = vw, iw, idx
            return culled
        end

        function internal.RendererMarkersLine(getter, marker, count, weight)
            return {
                Prims = getter.Count, IdxConsumed = count // 2 * 6, VtxConsumed = count // 2 * 4,
                Getter = getter, Marker = marker, Count = count, HalfWeight = max(1.0, weight) * 0.5,
                Init = LineInit, Render = MarkersLineRender, RenderRange = MarkersLineRange,
            }
        end

        @native
        function internal.RenderPrimitivesEx(renderer, draw_list, cull_rect)
            local prims        = renderer.Prims
            local prims_culled = 0
            local idx          = 0
            local idx_c, vtx_c = renderer.IdxConsumed, renderer.VtxConsumed
            local render, range = renderer.Render, renderer.RenderRange
            renderer.Init(renderer, draw_list)
            while prims > 0 do
                -- find how many can be reserved up to end of current draw command's limit
                local cnt = min(prims, (MAX_IDX - draw_list._VtxCurrentIdx) // vtx_c)
                -- make sure at least this many elements can be rendered to avoid situations where at the end of buffer this slow path is not taken all the time
                if cnt >= min(64, prims) then
                    if prims_culled >= cnt then
                        prims_culled -= cnt -- reuse previous reservation
                    else
                        -- add more elements to previous reservation
                        draw_list:PrimReserve((cnt - prims_culled) * idx_c, (cnt - prims_culled) * vtx_c)
                        prims_culled = 0
                    end
                else
                    if prims_culled > 0 then
                        draw_list:PrimUnreserve(prims_culled * idx_c, prims_culled * vtx_c)
                        prims_culled = 0
                    end
                    cnt = min(prims, MAX_IDX // vtx_c)
                    -- reserve new draw command
                    draw_list:PrimReserve(cnt * idx_c, cnt * vtx_c)
                end
                prims -= cnt
                if range then
                    prims_culled += range(renderer, draw_list, cull_rect, idx, idx + cnt - 1)
                else
                    for i = idx, idx + cnt - 1 do
                        if not render(renderer, draw_list, cull_rect, i) then
                            prims_culled += 1
                        end
                    end
                end
                idx += cnt
            end
            if prims_culled > 0 then
                draw_list:PrimUnreserve(prims_culled * idx_c, prims_culled * vtx_c)
            end
        end
        local RenderPrimitivesEx = internal.RenderPrimitivesEx

        -- [Port] RenderPrimitives1/2/3 collapse to UseCurrentTransformer() + renderer ctor + Render()
        -- builds the renderer, applies colors/sizes, renders
        local function Render(r, cols, count, col, alpha)
            if col ~= nil then SetColors(r, cols, count, col, alpha) end
            RenderPrimitivesEx(r, internal.GetPlotDrawList(), GImPlot.CurrentPlot.PlotRect)
        end
        local function UseCurrentTransformer()
            local plot = GImPlot.CurrentPlot
            internal.SetTransformer(plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY])
        end

        -----------------------------------------------------------------------
        -- Markers
        -- [Port] ImVec2 arrays flattened to {x1, y1, x2, y2, ...}
        -----------------------------------------------------------------------

        local MARKER_FILL_CIRCLE  = {1.0, 0.0, 0.809017, 0.58778524, 0.30901697, 0.95105654, -0.30901703, 0.9510565, -0.80901706, 0.5877852, -1.0, 0.0, -0.80901694, -0.58778536, -0.3090171, -0.9510565, 0.30901712, -0.9510565, 0.80901694, -0.5877853}
        local MARKER_FILL_SQUARE  = {SQRT_1_2, SQRT_1_2, SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, SQRT_1_2}
        local MARKER_FILL_DIAMOND = {1, 0, 0, -1, -1, 0, 0, 1}
        local MARKER_FILL_UP      = {SQRT_3_2, 0.5, 0, -1, -SQRT_3_2, 0.5}
        local MARKER_FILL_DOWN    = {SQRT_3_2, -0.5, 0, 1, -SQRT_3_2, -0.5}
        local MARKER_FILL_LEFT    = {-1, 0, 0.5, SQRT_3_2, 0.5, -SQRT_3_2}
        local MARKER_FILL_RIGHT   = {1, 0, -0.5, SQRT_3_2, -0.5, -SQRT_3_2}

        -- line markers are pairs of segment endpoints; circle built from the fill circle
        local MARKER_LINE_CIRCLE = {}
        for i = 0, 9 do
            local j = (i + 1) % 10
            table.insert(MARKER_LINE_CIRCLE, MARKER_FILL_CIRCLE[i * 2 + 1]); table.insert(MARKER_LINE_CIRCLE, MARKER_FILL_CIRCLE[i * 2 + 2])
            table.insert(MARKER_LINE_CIRCLE, MARKER_FILL_CIRCLE[j * 2 + 1]); table.insert(MARKER_LINE_CIRCLE, MARKER_FILL_CIRCLE[j * 2 + 2])
        end
        local MARKER_LINE_SQUARE     = {SQRT_1_2, SQRT_1_2, SQRT_1_2, -SQRT_1_2, SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, SQRT_1_2, -SQRT_1_2, SQRT_1_2, SQRT_1_2, SQRT_1_2}
        local MARKER_LINE_DIAMOND    = {1, 0, 0, -1, 0, -1, -1, 0, -1, 0, 0, 1, 0, 1, 1, 0}
        local MARKER_LINE_UP         = {SQRT_3_2, 0.5, 0, -1, 0, -1, -SQRT_3_2, 0.5, -SQRT_3_2, 0.5, SQRT_3_2, 0.5}
        local MARKER_LINE_DOWN       = {SQRT_3_2, -0.5, 0, 1, 0, 1, -SQRT_3_2, -0.5, -SQRT_3_2, -0.5, SQRT_3_2, -0.5}
        local MARKER_LINE_LEFT       = {-1, 0, 0.5, SQRT_3_2, 0.5, SQRT_3_2, 0.5, -SQRT_3_2, 0.5, -SQRT_3_2, -1, 0}
        local MARKER_LINE_RIGHT      = {1, 0, -0.5, SQRT_3_2, -0.5, SQRT_3_2, -0.5, -SQRT_3_2, -0.5, -SQRT_3_2, 1, 0}
        local MARKER_LINE_ASTERISK   = {-SQRT_3_2, -0.5, SQRT_3_2, 0.5, -SQRT_3_2, 0.5, SQRT_3_2, -0.5, 0, -1, 0, 1}
        local MARKER_LINE_PLUS       = {-1, 0, 1, 0, 0, -1, 0, 1}
        local MARKER_LINE_CROSS      = {-SQRT_1_2, -SQRT_1_2, SQRT_1_2, SQRT_1_2, SQRT_1_2, -SQRT_1_2, -SQRT_1_2, SQRT_1_2}
        local MARKER_LINE_VERTICAL   = {0, -1, 0, 1}
        local MARKER_LINE_HORIZONTAL = {-1, 0, 1, 0}

        local MARKER_FILL = {
            [ImPlotMarker.Circle] = MARKER_FILL_CIRCLE, [ImPlotMarker.Square] = MARKER_FILL_SQUARE,
            [ImPlotMarker.Diamond] = MARKER_FILL_DIAMOND, [ImPlotMarker.Up] = MARKER_FILL_UP,
            [ImPlotMarker.Down] = MARKER_FILL_DOWN, [ImPlotMarker.Left] = MARKER_FILL_LEFT,
            [ImPlotMarker.Right] = MARKER_FILL_RIGHT,
        }
        local MARKER_LINE = {
            [ImPlotMarker.Circle] = MARKER_LINE_CIRCLE, [ImPlotMarker.Square] = MARKER_LINE_SQUARE,
            [ImPlotMarker.Diamond] = MARKER_LINE_DIAMOND, [ImPlotMarker.Up] = MARKER_LINE_UP,
            [ImPlotMarker.Down] = MARKER_LINE_DOWN, [ImPlotMarker.Left] = MARKER_LINE_LEFT,
            [ImPlotMarker.Right] = MARKER_LINE_RIGHT, [ImPlotMarker.Asterisk] = MARKER_LINE_ASTERISK,
            [ImPlotMarker.Plus] = MARKER_LINE_PLUS, [ImPlotMarker.Cross] = MARKER_LINE_CROSS,
            [ImPlotMarker.Vertical] = MARKER_LINE_VERTICAL, [ImPlotMarker.Horizontal] = MARKER_LINE_HORIZONTAL,
        }

        -- [Port] color/size getters passed as (array-or-nil, const, alpha) instead of getter objects
        function internal.RenderMarkers(getter, marker, rend_fill, fill_cols, fill_col, fill_alpha, rend_line, line_cols, line_col, sizes, size, weight)
            UseCurrentTransformer()
            if rend_fill then
                local m = MARKER_FILL[marker]
                if m then
                    local r = internal.RendererMarkersFill(getter, m, #m // 2)
                    r.Sizes, r.Size = sizes, size
                    Render(r, fill_cols, getter.Count, fill_col, fill_alpha)
                end
            end
            if rend_line then
                local m = MARKER_LINE[marker]
                if m then
                    local r = internal.RendererMarkersLine(getter, m, #m // 2, weight)
                    r.Sizes, r.Size = sizes, size
                    Render(r, line_cols, getter.Count, line_col, 1)
                end
            end
        end

        function internal.RenderColoredMarkers(getter, s)
            local sp = s.Spec
            internal.RenderMarkers(getter, sp.Marker,
                s.RenderMarkerFill, sp.MarkerFillColors, ImGui.GetColorU32(sp.MarkerFillColor), sp.MarkerFillColors and sp.FillAlpha or 1,
                s.RenderMarkerLine, sp.MarkerLineColors, ImGui.GetColorU32(sp.MarkerLineColor),
                sp.MarkerSizes, sp.MarkerSize, sp.LineWeight)
        end

        -----------------------------------------------------------------------
        -- PlotLine
        -----------------------------------------------------------------------

        function internal.PlotLineEx(label_id, getter, spec)
            if BeginItemEx(label_id, internal.Fitter1(getter), spec, spec.LineColor, spec.Marker) then
                if getter.Count <= 0 then
                    EndItem()
                    return
                end
                local s = GetItemData()
                local sp = s.Spec
                local flags = spec.Flags
                if getter.Count > 1 then
                    if ImHasFlag(flags, ImPlotLineFlags.Shaded) and s.RenderFill then
                        UseCurrentTransformer()
                        local getter2 = internal.GetterOverrideY(getter, 0)
                        if sp.FillColors ~= nil then
                            Render(internal.RendererShaded(getter, getter2), sp.FillColors, getter.Count, 0, sp.FillAlpha)
                        else
                            Render(internal.RendererShaded(getter, getter2), nil, 0, ImGui.GetColorU32(sp.FillColor), sp.FillAlpha)
                        end
                    end
                    if s.RenderLine then
                        UseCurrentTransformer()
                        local col_line = ImGui.GetColorU32(sp.LineColor)
                        local r
                        if ImHasFlag(flags, ImPlotLineFlags.Segments) then
                            r = internal.RendererLineSegments1(getter, sp.LineWeight)
                        elseif ImHasFlag(flags, ImPlotLineFlags.Loop) then
                            r = internal.RendererLineStrip(internal.GetterLoop(getter), sp.LineWeight, ImHasFlag(flags, ImPlotLineFlags.SkipNaN))
                        else
                            r = internal.RendererLineStrip(getter, sp.LineWeight, ImHasFlag(flags, ImPlotLineFlags.SkipNaN))
                        end
                        Render(r, sp.LineColors, getter.Count, col_line, 1)
                    end
                end
                -- render markers
                if s.RenderMarkers then
                    if ImHasFlag(flags, ImPlotLineFlags.NoClip) then
                        PopPlotClipRect()
                        PushPlotClipRect(sp.MarkerSize)
                    end
                    internal.RenderColoredMarkers(getter, s)
                end
                EndItem()
            end
        end

        -- [Port] overloads dispatched on argument types:
        --   PlotX(label_id, values, count?, xscale?, xstart?, spec?)   values-only (b is a number or nil)
        --   PlotX(label_id, xs, ys, count?, spec?)                     xs/ys arrays (b is a table)
        -- spec: nil, an ImPlotSpec, or a plain table of ImPlotSpec fields. count defaults to #ys.
        local function MakeGetter(a, b, c, d, e)
            local spec, count
            local getter
            if type(b) == "table" and getmetatable(b) ~= SpecMT and (b[1] ~= nil or next(b) == nil) then
                -- xs, ys
                count = c or math.min(#a, #b)
                spec = ResolveSpec(d)
                getter = internal.GetterXY(internal.IndexerIdx(a, count, spec.Offset, spec.Stride), internal.IndexerIdx(b, count, spec.Offset, spec.Stride), count)
            else
                -- values, count, xscale, x0
                local cnt, xscale, x0, sp = b, c, d, e
                if type(cnt) == "table" then sp, cnt, xscale, x0 = cnt, nil, nil, nil end
                count = cnt or #a
                spec = ResolveSpec(sp)
                getter = internal.GetterXY(internal.IndexerLin(xscale or 1, x0 or 0), internal.IndexerIdx(a, count, spec.Offset, spec.Stride), count)
            end
            return getter, spec
        end

        function ImPlot.PlotLine(label_id, a, b, c, d, e)
            local getter, spec = MakeGetter(a, b, c, d, e)
            internal.PlotLineEx(label_id, getter, spec)
        end

        -- custom getter: getter_func(idx, data) -> ImPlotPoint or (x, y)
        function ImPlot.PlotLineG(label_id, getter_func, data, count, spec)
            internal.PlotLineEx(label_id, internal.GetterFuncPtr(getter_func, data, count), ResolveSpec(spec))
        end

        -----------------------------------------------------------------------
        -- PlotScatter
        -----------------------------------------------------------------------

        function internal.PlotScatterEx(label_id, getter, spec)
            -- force scatter to render a marker even if none
            local marker = spec.Marker
            if marker == ImPlotMarker.None then marker = ImPlotMarker.Auto end
            if BeginItemEx(label_id, internal.Fitter1(getter), spec, spec.MarkerLineColor, marker) then
                if getter.Count <= 0 then
                    EndItem()
                    return
                end
                local s = GetItemData()
                if s.RenderMarkers then
                    if ImHasFlag(spec.Flags, ImPlotScatterFlags.NoClip) then
                        PopPlotClipRect()
                        PushPlotClipRect(s.Spec.MarkerSize)
                    end
                    internal.RenderColoredMarkers(getter, s)
                end
                EndItem()
            end
        end

        function ImPlot.PlotScatter(label_id, a, b, c, d, e)
            local getter, spec = MakeGetter(a, b, c, d, e)
            internal.PlotScatterEx(label_id, getter, spec)
        end

        function ImPlot.PlotScatterG(label_id, getter_func, data, count, spec)
            internal.PlotScatterEx(label_id, internal.GetterFuncPtr(getter_func, data, count), ResolveSpec(spec))
        end

        -----------------------------------------------------------------------
        -- PlotPolygon
        -----------------------------------------------------------------------

        function internal.PlotPolygonEx(label_id, getter, spec)
            if BeginItemEx(label_id, internal.Fitter1(getter), spec, spec.FillColor, spec.Marker) then
                if getter.Count < 2 then
                    EndItem()
                    return
                end
                local s = GetItemData()
                local is_concave = ImHasFlag(spec.Flags, ImPlot.ImPlotPolygonFlags.Concave)

                local draw_list = internal.GetPlotDrawList()
                local plot = GImPlot.CurrentPlot
                local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
                internal.SetTransformer(x_axis, y_axis)

                -- Flip points to make sure they are in counter-clockwise order for correct filling when one axis is inverted
                local x_inv = ImHasFlag(x_axis.Flags, ImPlot.ImPlotAxisFlags.Invert)
                local y_inv = ImHasFlag(y_axis.Flags, ImPlot.ImPlotAxisFlags.Invert)
                local flip = x_inv == y_inv

                -- Transform all points to screen space
                local n = getter.Count
                local points = table.create(n)
                for i = 0, n - 1 do
                    local x, y
                    if flip then x, y = getter.Get(getter, n - 1 - i) else x, y = getter.Get(getter, i) end
                    points[i + 1] = ImVec2(TransformX(x), TransformY(y))
                end

                if s.RenderFill and n >= 3 then
                    local col_fill = ImGui.GetColorU32(s.Spec.FillColor)
                    if is_concave then
                        draw_list:AddConcavePolyFilled(points, n, col_fill)
                    else
                        draw_list:AddConvexPolyFilled(points, n, col_fill)
                    end
                end
                if s.RenderLine and n >= 2 then
                    local col_line = ImGui.GetColorU32(s.Spec.LineColor)
                    draw_list:AddPolyline(points, n, col_line, s.Spec.LineWeight, G.ImDrawFlags.Closed)
                end

                EndItem()
            end
        end

        -- PlotPolygon(label_id, xs, ys, count?, spec?)
        function ImPlot.PlotPolygon(label_id, xs, ys, count, spec)
            if type(count) == "table" then spec, count = count, nil end
            count = count or math.min(#xs, #ys)
            local sp = ResolveSpec(spec)
            local getter = internal.GetterXY(internal.IndexerIdx(xs, count, sp.Offset, sp.Stride), internal.IndexerIdx(ys, count, sp.Offset, sp.Stride), count)
            internal.PlotPolygonEx(label_id, getter, sp)
        end

        -----------------------------------------------------------------------
        -- PlotStairs, PlotShaded, PlotBars, PlotBarGroups (+ their primitives/renderers/fitters)
        -----------------------------------------------------------------------
        do
            local ImPlotStairsFlags = ImPlot.ImPlotStairsFlags
            local ImPlotBarsFlags = ImPlot.ImPlotBarsFlags
            local ImPlotBarGroupsFlags = ImPlot.ImPlotBarGroupsFlags

            local function IsArray(t)
                return type(t) == "table" and getmetatable(t) ~= SpecMT and (t[1] ~= nil or next(t) == nil)
            end

            @native
            local function PrimRectLine(dl, x1, y1, x2, y2, weight, col, u, v)
                local b = dl.VtxBuffer.Buf
                local vw = dl._VtxWritePtr
                local o = (vw - 1) * VTX_STRIDE
                WV(b, o,                  x1, y1, u, v, col)
                WV(b, o + VTX_STRIDE,     x1, y2, u, v, col)
                WV(b, o + VTX_STRIDE * 2, x2, y2, u, v, col)
                WV(b, o + VTX_STRIDE * 3, x2, y1, u, v, col)
                WV(b, o + VTX_STRIDE * 4, x1 + weight, y1 + weight, u, v, col)
                WV(b, o + VTX_STRIDE * 5, x1 + weight, y2 - weight, u, v, col)
                WV(b, o + VTX_STRIDE * 6, x2 - weight, y2 - weight, u, v, col)
                WV(b, o + VTX_STRIDE * 7, x2 - weight, y1 + weight, u, v, col)
                local idx = dl._VtxCurrentIdx
                local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
                id[iw]      = idx;     id[iw + 1]  = idx + 1; id[iw + 2]  = idx + 5
                id[iw + 3]  = idx;     id[iw + 4]  = idx + 5; id[iw + 5]  = idx + 4
                id[iw + 6]  = idx + 1; id[iw + 7]  = idx + 2; id[iw + 8]  = idx + 6
                id[iw + 9]  = idx + 1; id[iw + 10] = idx + 6; id[iw + 11] = idx + 5
                id[iw + 12] = idx + 2; id[iw + 13] = idx + 3; id[iw + 14] = idx + 7
                id[iw + 15] = idx + 2; id[iw + 16] = idx + 7; id[iw + 17] = idx + 6
                id[iw + 18] = idx + 3; id[iw + 19] = idx;     id[iw + 20] = idx + 4
                id[iw + 21] = idx + 3; id[iw + 22] = idx + 4; id[iw + 23] = idx + 7
                dl._VtxWritePtr = vw + 8; dl._IdxWritePtr = iw + 24; dl._VtxCurrentIdx = idx + 8
            end
            internal.PrimRectLine = PrimRectLine

            -------------------------------------------------------------------
            -- Fitters
            -------------------------------------------------------------------

            local function FitterBarVFit(self, x_axis, y_axis)
                local g1, g2, hw = self.Getter1, self.Getter2, self.HalfWidth
                for i = 0, min(g1.Count, g2.Count) - 1 do
                    local x1, y1 = g1.Get(g1, i)
                    local x2, y2 = g2.Get(g2, i)
                    x1 -= hw; x2 += hw
                    x_axis:ExtendFitWith(y_axis, x1, y1)
                    y_axis:ExtendFitWith(x_axis, y1, x1)
                    x_axis:ExtendFitWith(y_axis, x2, y2)
                    y_axis:ExtendFitWith(x_axis, y2, x2)
                end
            end
            function internal.FitterBarV(g1, g2, width) return { Getter1 = g1, Getter2 = g2, HalfWidth = width * 0.5, Fit = FitterBarVFit } end

            local function FitterBarHFit(self, x_axis, y_axis)
                local g1, g2, hh = self.Getter1, self.Getter2, self.HalfHeight
                for i = 0, min(g1.Count, g2.Count) - 1 do
                    local x1, y1 = g1.Get(g1, i)
                    local x2, y2 = g2.Get(g2, i)
                    y1 -= hh; y2 += hh
                    x_axis:ExtendFitWith(y_axis, x1, y1)
                    y_axis:ExtendFitWith(x_axis, y1, x1)
                    x_axis:ExtendFitWith(y_axis, x2, y2)
                    y_axis:ExtendFitWith(x_axis, y2, x2)
                end
            end
            function internal.FitterBarH(g1, g2, height) return { Getter1 = g1, Getter2 = g2, HalfHeight = height * 0.5, Fit = FitterBarHFit } end

            -------------------------------------------------------------------
            -- Renderers
            -------------------------------------------------------------------

            -- [Port] RendererBarsFillV/H + RendererBarsLineV/H share the rect computation; returns PMin/PMax or nil if culled
            @native
            local function BarRect(r, cr, prim)
                local g1, g2, hs = r.Getter1, r.Getter2, r.HalfSize
                local x1, y1 = g1.Get(g1, prim)
                local x2, y2 = g2.Get(g2, prim)
                if r.Horz then y1 += hs; y2 -= hs else x1 += hs; x2 -= hs end
                local p1x, p1y, p2x, p2y = TransformX(x1), TransformY(y1), TransformX(x2), TransformY(y2)
                if r.Horz then
                    local height_px = math.abs(p1y - p2y)
                    if height_px < 1.0 then
                        if p1y > p2y then p1y += (1 - height_px) / 2 else p1y += (height_px - 1) / 2 end
                        if p2y > p1y then p2y += (1 - height_px) / 2 else p2y += (height_px - 1) / 2 end
                    end
                else
                    local width_px = math.abs(p1x - p2x)
                    if width_px < 1.0 then
                        if p1x > p2x then p1x += (1 - width_px) / 2 else p1x += (width_px - 1) / 2 end
                        if p2x > p1x then p2x += (1 - width_px) / 2 else p2x += (width_px - 1) / 2 end
                    end
                end
                local minx, miny, maxx, maxy = min(p1x, p2x), min(p1y, p2y), max(p1x, p2x), max(p1y, p2y)
                if not (miny < cr.Max.y and maxy > cr.Min.y and minx < cr.Max.x and maxx > cr.Min.x) then
                    return nil
                end
                return minx, miny, maxx, maxy
            end

            @native
            local function BarsFillRender(r, dl, cr, prim)
                local minx, miny, maxx, maxy = BarRect(r, cr, prim)
                if minx == nil then return false end
                PrimRectFill(dl, minx, miny, maxx, maxy, GetCol(r, prim), r.U, r.V)
                return true
            end
            @native
            local function BarsLineRender(r, dl, cr, prim)
                local minx, miny, maxx, maxy = BarRect(r, cr, prim)
                if minx == nil then return false end
                PrimRectLine(dl, minx, miny, maxx, maxy, r.Weight, GetCol(r, prim), r.U, r.V)
                return true
            end

            function internal.RendererBarsFillV(getter1, getter2, width)
                return {
                    Prims = min(getter1.Count, getter2.Count), IdxConsumed = 6, VtxConsumed = 4,
                    Getter1 = getter1, Getter2 = getter2, HalfSize = width / 2, Horz = false,
                    Init = WhiteInit, Render = BarsFillRender,
                }
            end
            function internal.RendererBarsFillH(getter1, getter2, height)
                local r = internal.RendererBarsFillV(getter1, getter2, height)
                r.Horz = true
                return r
            end
            function internal.RendererBarsLineV(getter1, getter2, width, weight)
                return {
                    Prims = min(getter1.Count, getter2.Count), IdxConsumed = 24, VtxConsumed = 8,
                    Getter1 = getter1, Getter2 = getter2, HalfSize = width / 2, Horz = false, Weight = weight,
                    Init = WhiteInit, Render = BarsLineRender,
                }
            end
            function internal.RendererBarsLineH(getter1, getter2, height, weight)
                local r = internal.RendererBarsLineV(getter1, getter2, height, weight)
                r.Horz = true
                return r
            end

            @native
            local function StairsPreRender(r, dl, cr, prim)
                local g = r.Getter
                local x, y = g.Get(g, prim + 1)
                local p2x, p2y = TransformX(x), TransformY(y)
                local p1x, p1y = r.P1x, r.P1y
                r.P1x, r.P1y = p2x, p2y
                if not Overlaps(cr, p1x, p1y, p2x, p2y) then return false end
                local col, hw, u, v = GetCol(r, prim), r.HalfWeight, r.U, r.V
                PrimRectFill(dl, p1x - hw, p1y, p1x + hw, p2y, col, u, v)
                PrimRectFill(dl, p1x, p2y + hw, p2x, p2y - hw, col, u, v)
                return true
            end
            @native
            local function StairsPostRender(r, dl, cr, prim)
                local g = r.Getter
                local x, y = g.Get(g, prim + 1)
                local p2x, p2y = TransformX(x), TransformY(y)
                local p1x, p1y = r.P1x, r.P1y
                r.P1x, r.P1y = p2x, p2y
                if not Overlaps(cr, p1x, p1y, p2x, p2y) then return false end
                local col, hw, u, v = GetCol(r, prim), r.HalfWeight, r.U, r.V
                PrimRectFill(dl, p1x, p1y + hw, p2x, p1y - hw, col, u, v)
                PrimRectFill(dl, p2x - hw, p2y, p2x + hw, p1y, col, u, v)
                return true
            end
            @native
            local function StairsPreShadedRender(r, dl, cr, prim)
                local g = r.Getter
                local x, y = g.Get(g, prim + 1)
                local p2x, p2y = TransformX(x), TransformY(y)
                local p1x = r.P1x
                local y0 = r.Y0
                r.P1x, r.P1y = p2x, p2y
                local minx, miny, maxx, maxy = min(p1x, p2x), min(y0, p2y), max(p1x, p2x), max(y0, p2y)
                if not (miny < cr.Max.y and maxy > cr.Min.y and minx < cr.Max.x and maxx > cr.Min.x) then return false end
                PrimRectFill(dl, minx, miny, maxx, maxy, GetCol(r, prim), r.U, r.V)
                return true
            end
            @native
            local function StairsPostShadedRender(r, dl, cr, prim)
                local g = r.Getter
                local x, y = g.Get(g, prim + 1)
                local p2x, p2y = TransformX(x), TransformY(y)
                local p1x, p1y = r.P1x, r.P1y
                local y0 = r.Y0
                r.P1x, r.P1y = p2x, p2y
                local minx, miny, maxx, maxy = min(p1x, p2x), min(p1y, y0), max(p1x, p2x), max(p1y, y0)
                if not (miny < cr.Max.y and maxy > cr.Min.y and minx < cr.Max.x and maxx > cr.Min.x) then return false end
                PrimRectFill(dl, minx, miny, maxx, maxy, GetCol(r, prim), r.U, r.V)
                return true
            end

            local function StairsRenderer(getter, render, vtx, weight)
                local x, y = getter.Get(getter, 0)
                return {
                    Prims = getter.Count - 1, IdxConsumed = vtx // 4 * 6, VtxConsumed = vtx,
                    Getter = getter, HalfWeight = max(1.0, weight or 1) * 0.5,
                    P1x = TransformX(x), P1y = TransformY(y), Y0 = TransformY(0),
                    Init = WhiteInit, Render = render,
                }
            end
            function internal.RendererStairsPre(getter, weight) return StairsRenderer(getter, StairsPreRender, 8, weight) end
            function internal.RendererStairsPost(getter, weight) return StairsRenderer(getter, StairsPostRender, 8, weight) end
            function internal.RendererStairsPreShaded(getter) return StairsRenderer(getter, StairsPreShadedRender, 4) end
            function internal.RendererStairsPostShaded(getter) return StairsRenderer(getter, StairsPostShadedRender, 4) end

            -------------------------------------------------------------------
            -- PlotStairs
            -------------------------------------------------------------------

            function internal.PlotStairsEx(label_id, getter, spec)
                if BeginItemEx(label_id, internal.Fitter1(getter), spec, spec.LineColor, spec.Marker) then
                    if getter.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp = s.Spec
                    local pre = ImHasFlag(spec.Flags, ImPlotStairsFlags.PreStep)
                    if getter.Count > 1 then
                        if s.RenderFill and ImHasFlag(spec.Flags, ImPlotStairsFlags.Shaded) then
                            UseCurrentTransformer()
                            local r
                            if pre then r = internal.RendererStairsPreShaded(getter) else r = internal.RendererStairsPostShaded(getter) end
                            Render(r, sp.FillColors, getter.Count, ImGui.GetColorU32(sp.FillColor), sp.FillAlpha)
                        end
                        if s.RenderLine then
                            UseCurrentTransformer()
                            local r
                            if pre then r = internal.RendererStairsPre(getter, sp.LineWeight) else r = internal.RendererStairsPost(getter, sp.LineWeight) end
                            Render(r, sp.LineColors, getter.Count, ImGui.GetColorU32(sp.LineColor), 1)
                        end
                    end
                    -- render markers
                    if s.RenderMarkers then
                        PopPlotClipRect()
                        PushPlotClipRect(sp.MarkerSize)
                        internal.RenderColoredMarkers(getter, s)
                    end
                    EndItem()
                end
            end

            function ImPlot.PlotStairs(label_id, a, b, c, d, e)
                local getter, spec = MakeGetter(a, b, c, d, e)
                internal.PlotStairsEx(label_id, getter, spec)
            end

            function ImPlot.PlotStairsG(label_id, getter_func, data, count, spec)
                internal.PlotStairsEx(label_id, internal.GetterFuncPtr(getter_func, data, count), ResolveSpec(spec))
            end

            -------------------------------------------------------------------
            -- PlotShaded
            -------------------------------------------------------------------

            function internal.PlotShadedEx(label_id, getter1, getter2, spec)
                if BeginItemEx(label_id, internal.Fitter2(getter1, getter2), spec, spec.FillColor) then
                    if getter1.Count <= 0 or getter2.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    if s.RenderFill and min(getter1.Count, getter2.Count) > 1 then
                        local sp = s.Spec
                        UseCurrentTransformer()
                        Render(internal.RendererShaded(getter1, getter2), sp.FillColors, getter1.Count, ImGui.GetColorU32(sp.FillColor), sp.FillAlpha)
                    end
                    EndItem()
                end
            end

            local function ResolveYRef(y_ref)
                y_ref = y_ref or 0
                if y_ref == -math.huge then y_ref = ImPlot.GetPlotLimits(IMPLOT_AUTO, IMPLOT_AUTO).Y.Min end
                if y_ref == math.huge then y_ref = ImPlot.GetPlotLimits(IMPLOT_AUTO, IMPLOT_AUTO).Y.Max end
                return y_ref
            end

            -- [Port] overloads dispatched on argument types:
            --   PlotShaded(label_id, values, count?, y_ref?, xscale?, x0?, spec?)
            --   PlotShaded(label_id, xs, ys, count?, y_ref?, spec?)
            --   PlotShaded(label_id, xs, ys1, ys2, count?, spec?)
            -- a trailing table (spec) may appear in place of any optional argument.
            function ImPlot.PlotShaded(label_id, a, b, c, d, e, f)
                local getter1, getter2
                if IsArray(b) and IsArray(c) then
                    -- xs, ys1, ys2
                    local count, sp = d, e
                    if type(count) == "table" then sp, count = count, nil end
                    count = count or min(#a, #b, #c)
                    local spec = ResolveSpec(sp)
                    local ix = internal.IndexerIdx(a, count, spec.Offset, spec.Stride)
                    getter1 = internal.GetterXY(ix, internal.IndexerIdx(b, count, spec.Offset, spec.Stride), count)
                    getter2 = internal.GetterXY(ix, internal.IndexerIdx(c, count, spec.Offset, spec.Stride), count)
                    internal.PlotShadedEx(label_id, getter1, getter2, spec)
                elseif IsArray(b) then
                    -- xs, ys, count, y_ref
                    local count, y_ref, sp = c, d, e
                    if type(count) == "table" then sp, count, y_ref = count, nil, nil
                    elseif type(y_ref) == "table" then sp, y_ref = y_ref, nil end
                    count = count or min(#a, #b)
                    local spec = ResolveSpec(sp)
                    y_ref = ResolveYRef(y_ref)
                    local ix = internal.IndexerIdx(a, count, spec.Offset, spec.Stride)
                    getter1 = internal.GetterXY(ix, internal.IndexerIdx(b, count, spec.Offset, spec.Stride), count)
                    getter2 = internal.GetterXY(ix, internal.IndexerConst(y_ref), count)
                    internal.PlotShadedEx(label_id, getter1, getter2, spec)
                else
                    -- values, count, y_ref, xscale, x0
                    local count, y_ref, xscale, x0, sp = b, c, d, e, f
                    if type(count) == "table" then sp, count, y_ref, xscale, x0 = count, nil, nil, nil, nil
                    elseif type(y_ref) == "table" then sp, y_ref, xscale, x0 = y_ref, nil, nil, nil
                    elseif type(xscale) == "table" then sp, xscale, x0 = xscale, nil, nil
                    elseif type(x0) == "table" then sp, x0 = x0, nil end
                    count = count or #a
                    local spec = ResolveSpec(sp)
                    y_ref = ResolveYRef(y_ref)
                    local ix = internal.IndexerLin(xscale or 1, x0 or 0)
                    getter1 = internal.GetterXY(ix, internal.IndexerIdx(a, count, spec.Offset, spec.Stride), count)
                    getter2 = internal.GetterXY(ix, internal.IndexerConst(y_ref), count)
                    internal.PlotShadedEx(label_id, getter1, getter2, spec)
                end
            end

            function ImPlot.PlotShadedG(label_id, getter_func1, data1, getter_func2, data2, count, spec)
                internal.PlotShadedEx(label_id, internal.GetterFuncPtr(getter_func1, data1, count), internal.GetterFuncPtr(getter_func2, data2, count), ResolveSpec(spec))
            end

            -------------------------------------------------------------------
            -- PlotBars
            -------------------------------------------------------------------

            -- [Port] PlotBarsVEx/PlotBarsHEx merged; horz selects FitterBarH + RendererBars*H
            local function PlotBarsEx(label_id, getter1, getter2, size, spec, horz)
                local fitter
                if horz then fitter = internal.FitterBarH(getter1, getter2, size) else fitter = internal.FitterBarV(getter1, getter2, size) end
                if BeginItemEx(label_id, fitter, spec, spec.FillColor) then
                    if getter1.Count <= 0 or getter2.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp = s.Spec
                    local col_fill = ImGui.GetColorU32(sp.FillColor)
                    local col_line = ImGui.GetColorU32(sp.LineColor)
                    local rend_fill = s.RenderFill
                    local rend_line = s.RenderLine
                    if rend_fill then
                        UseCurrentTransformer()
                        local r
                        if horz then r = internal.RendererBarsFillH(getter1, getter2, size) else r = internal.RendererBarsFillV(getter1, getter2, size) end
                        Render(r, sp.FillColors, getter1.Count, col_fill, sp.FillAlpha)
                        if rend_line and col_fill == col_line then
                            rend_line = false
                        end
                    end
                    if rend_line then
                        UseCurrentTransformer()
                        local r
                        if horz then r = internal.RendererBarsLineH(getter1, getter2, size, sp.LineWeight) else r = internal.RendererBarsLineV(getter1, getter2, size, sp.LineWeight) end
                        Render(r, sp.LineColors, getter1.Count, col_line, 1)
                    end
                    EndItem()
                end
            end
            function internal.PlotBarsVEx(label_id, getter1, getter2, width, spec) PlotBarsEx(label_id, getter1, getter2, width, spec, false) end
            function internal.PlotBarsHEx(label_id, getter1, getter2, height, spec) PlotBarsEx(label_id, getter1, getter2, height, spec, true) end

            -- values indexer -> bars at x = shift + i
            local function PlotBarsIdx(label_id, values_idx, count, bar_size, shift, spec)
                local lin = internal.IndexerLin(1.0, shift)
                local zero = internal.IndexerConst(0)
                if ImHasFlag(spec.Flags, ImPlotBarsFlags.Horizontal) then
                    PlotBarsEx(label_id, internal.GetterXY(values_idx, lin, count), internal.GetterXY(zero, lin, count), bar_size, spec, true)
                else
                    PlotBarsEx(label_id, internal.GetterXY(lin, values_idx, count), internal.GetterXY(lin, zero, count), bar_size, spec, false)
                end
            end

            -- [Port] overloads dispatched on argument types:
            --   PlotBars(label_id, values, count?, bar_size = 0.67, shift = 0, spec?)
            --   PlotBars(label_id, xs, ys, count?, bar_size = 0.67, spec?)
            function ImPlot.PlotBars(label_id, a, b, c, d, e)
                if IsArray(b) then
                    local count, bar_size, sp = c, d, e
                    if type(count) == "table" then sp, count, bar_size = count, nil, nil
                    elseif type(bar_size) == "table" then sp, bar_size = bar_size, nil end
                    count = count or min(#a, #b)
                    bar_size = bar_size or 0.67
                    local spec = ResolveSpec(sp)
                    local ix = internal.IndexerIdx(a, count, spec.Offset, spec.Stride)
                    local iy = internal.IndexerIdx(b, count, spec.Offset, spec.Stride)
                    if ImHasFlag(spec.Flags, ImPlotBarsFlags.Horizontal) then
                        PlotBarsEx(label_id, internal.GetterXY(ix, iy, count), internal.GetterXY(internal.IndexerConst(0), iy, count), bar_size, spec, true)
                    else
                        PlotBarsEx(label_id, internal.GetterXY(ix, iy, count), internal.GetterXY(ix, internal.IndexerConst(0), count), bar_size, spec, false)
                    end
                else
                    local count, bar_size, shift, sp = b, c, d, e
                    if type(count) == "table" then sp, count, bar_size, shift = count, nil, nil, nil
                    elseif type(bar_size) == "table" then sp, bar_size, shift = bar_size, nil, nil
                    elseif type(shift) == "table" then sp, shift = shift, nil end
                    count = count or #a
                    local spec = ResolveSpec(sp)
                    PlotBarsIdx(label_id, internal.IndexerIdx(a, count, spec.Offset, spec.Stride), count, bar_size or 0.67, shift or 0, spec)
                end
            end

            function ImPlot.PlotBarsG(label_id, getter_func, data, count, bar_size, spec)
                spec = ResolveSpec(spec)
                local getter1 = internal.GetterFuncPtr(getter_func, data, count)
                if ImHasFlag(spec.Flags, ImPlotBarsFlags.Horizontal) then
                    PlotBarsEx(label_id, getter1, internal.GetterOverrideX(getter1, 0), bar_size, spec, true)
                else
                    PlotBarsEx(label_id, getter1, internal.GetterOverrideY(getter1, 0), bar_size, spec, false)
                end
            end

            -------------------------------------------------------------------
            -- PlotBarGroups
            -------------------------------------------------------------------

            -- [Port] &values[i*group_count] -> slice indexer over the shared IndexerIdx (Offset/Stride apply to the whole array)
            local function SliceAt(self, i) local ix = self.Indexer; return ix.At(ix, self.Base + i) end
            -- [Port] TempDouble1 split into four reusable arrays
            local bg_neg, bg_pos, bg_curr_min, bg_curr_max = {}, {}, {}, {}
            local bg_spec = SpecDefaults({})

            -- label_ids: array of strings; values: item_count*group_count array (row = item)
            function ImPlot.PlotBarGroups(label_ids, values, item_count, group_count, group_size, shift, spec)
                if type(group_size) == "table" then spec, group_size, shift = group_size, nil, nil
                elseif type(shift) == "table" then spec, shift = shift, nil end
                group_size = group_size or 0.67
                shift = shift or 0
                spec = ResolveSpec(spec)
                local indexer = internal.IndexerIdx(values, item_count * group_count, spec.Offset, spec.Stride)
                local horz = ImHasFlag(spec.Flags, ImPlotBarGroupsFlags.Horizontal)
                local stack = ImHasFlag(spec.Flags, ImPlotBarGroupsFlags.Stacked)
                local spec_bars = SpecDefaults(bg_spec)
                for _, fld in VEC4_FIELDS do CopyVec4(spec_bars[fld], spec[fld]) end
                for _, fld in SCALAR_FIELDS do spec_bars[fld] = spec[fld] end
                spec_bars.Flags = 0
                if stack then
                    internal.SetupLock()
                    local neg, pos, curr_min, curr_max = bg_neg, bg_pos, bg_curr_min, bg_curr_max
                    for g = 1, group_count do
                        neg[g] = 0; pos[g] = 0
                        if curr_min[g] == nil then curr_min[g] = 0; curr_max[g] = 0 end
                    end
                    local lin = internal.IndexerLin(1.0, shift)
                    local imin = internal.IndexerIdx(curr_min, group_count)
                    local imax = internal.IndexerIdx(curr_max, group_count)
                    for i = 0, item_count - 1 do
                        if not ImPlot.IsItemHidden(label_ids[i + 1]) then
                            for g = 1, group_count do
                                local v = indexer.At(indexer, i * group_count + g - 1)
                                if v > 0 then
                                    curr_min[g] = pos[g]
                                    curr_max[g] = curr_min[g] + v
                                    pos[g]      += v
                                else
                                    curr_max[g] = neg[g]
                                    curr_min[g] = curr_max[g] + v
                                    neg[g]      += v
                                end
                            end
                        end
                        if horz then
                            PlotBarsEx(label_ids[i + 1], internal.GetterXY(imin, lin, group_count), internal.GetterXY(imax, lin, group_count), group_size, spec_bars, true)
                        else
                            PlotBarsEx(label_ids[i + 1], internal.GetterXY(lin, imin, group_count), internal.GetterXY(lin, imax, group_count), group_size, spec_bars, false)
                        end
                    end
                else
                    local subsize = group_size / item_count
                    if horz then
                        spec_bars.Flags = ImPlotBarsFlags.Horizontal
                    end
                    for i = 0, item_count - 1 do
                        local subshift = (i + 0.5) * subsize - group_size / 2
                        local slice = { Indexer = indexer, Base = i * group_count, At = SliceAt }
                        PlotBarsIdx(label_ids[i + 1], slice, group_count, subsize, subshift + shift, spec_bars)
                    end
                end
            end
        end

        -----------------------------------------------------------------------
        -- PlotBubbles, PlotErrorBars, PlotStems, PlotInfLines, PlotDigital, PlotText, PlotDummy
        -----------------------------------------------------------------------
        do
            local ImPlotErrorBarsFlags = ImPlot.ImPlotErrorBarsFlags
            local ImPlotStemsFlags = ImPlot.ImPlotStemsFlags
            local ImPlotInfLinesFlags = ImPlot.ImPlotInfLinesFlags
            local ImPlotTextFlags = ImPlot.ImPlotTextFlags
            local SetupLock, AddLineH, AddLineV = internal.SetupLock, internal.AddLineH, internal.AddLineV
            local ImNanOrInf = internal.ImNanOrInf
            local DBL_MAX = 1.7976931348623157e308
            -- [Port] ImConstrainNan(ImConstrainInf(v)) inlined (the helpers are local to the Utils section)
            local function ImConstrainNanInf(val)
                if val ~= val then return 0 end
                return math.clamp(val, -DBL_MAX, DBL_MAX)
            end

            local function IsArray(t)
                return type(t) == "table" and getmetatable(t) ~= SpecMT and (t[1] ~= nil or next(t) == nil)
            end

            -- [Port] IndexerAdd<I1,I2>(i1, i2, s1, s2)
            local function AddAt(self, i) local a, b = self.Indexer1, self.Indexer2; return self.Scale1 * a.At(a, i) + self.Scale2 * b.At(b, i) end
            function internal.IndexerAdd(i1, i2, s1, s2) return { Indexer1 = i1, Indexer2 = i2, Scale1 = s1, Scale2 = s2, At = AddAt } end

            -- [Port] GetterXYZ: Get returns (x, y, z)
            @native
            local function XYZGet(self, i)
                local ix, iy, iz = self.IndexerX, self.IndexerY, self.IndexerZ
                return ix.At(ix, i), iy.At(iy, i), iz.At(iz, i)
            end
            function internal.GetterXYZ(ix, iy, iz, count) return { IndexerX = ix, IndexerY = iy, IndexerZ = iz, Count = count, Get = XYZGet } end

            local function FitterBubbles1Fit(self, x_axis, y_axis)
                local g = self.Getter
                for i = 0, g.Count - 1 do
                    local x, y, half_size = g.Get(g, i)
                    -- Fit left and right edges
                    x_axis:ExtendFitWith(y_axis, x - half_size, y)
                    x_axis:ExtendFitWith(y_axis, x + half_size, y)
                    -- Fit top and bottom edges
                    y_axis:ExtendFitWith(x_axis, y - half_size, x)
                    y_axis:ExtendFitWith(x_axis, y + half_size, x)
                end
            end
            function internal.FitterBubbles1(getter) return { Getter = getter, Fit = FitterBubbles1Fit } end

            -------------------------------------------------------------------
            -- PlotBubbles
            -------------------------------------------------------------------

            -- [Port] RendererCircleFill/RendererCircleLine reserve 64 segments and PrimUnreserve the rest mid-batch;
            -- here each visible bubble reserves exactly what it uses instead (same output, no write-ptr rewind).
            local circle_state = {}
            @native
            local function RenderCircles(getter, line, cols, col, alpha, weight)
                UseCurrentTransformer()
                local plot = GImPlot.CurrentPlot
                local dl, cr = internal.GetPlotDrawList(), plot.PlotRect
                local m = plot.Axes[plot.CurrentX].ScaleToPixel
                local r = SetColors(circle_state, cols, getter.Count, col, alpha)
                local hw, u0, v0, u1, v1
                if line then
                    hw, u0, v0, u1, v1 = GetLineRenderProps(dl, max(1.0, weight) * 0.5)
                else
                    local uv = dl._Data.TexUvWhitePixel
                    u0, v0 = uv.x, uv.y
                end
                local a_max = math.pi * 2.0
                for prim = 0, getter.Count - 1 do
                    local x, y, rad = getter.Get(getter, prim)
                    -- Compute approximate radius in pixels for LOD
                    local num_segments = G.ImClamp(floor(math.abs(rad * m)), 10, 64)
                    -- Compute bounding box of the bubble in pixel coordinates (handle axis inversion)
                    local p1x, p1y = TransformX(x - rad), TransformY(y - rad)
                    local p2x, p2y = TransformX(x + rad), TransformY(y + rad)
                    if Overlaps(cr, p1x, p1y, p2x, p2y) then
                        local c = GetCol(r, prim)
                        local a_step = a_max / num_segments
                        if line then
                            dl:PrimReserve(num_segments * 6, num_segments * 4)
                            local qx, qy = TransformX(x + rad), TransformY(y)
                            for i = 1, num_segments do
                                local a = a_step * (i % num_segments)
                                local nx, ny = TransformX(x + math.cos(a) * rad), TransformY(y + math.sin(a) * rad)
                                PrimLine(dl, qx, qy, nx, ny, hw, c, u0, v0, u1, v1)
                                qx, qy = nx, ny
                            end
                        else
                            dl:PrimReserve((num_segments - 2) * 3, num_segments)
                            local b = dl.VtxBuffer.Buf
                            local vw = dl._VtxWritePtr
                            local o = (vw - 1) * VTX_STRIDE
                            for i = 0, num_segments - 1 do
                                local a = a_step * i
                                WV(b, o + i * VTX_STRIDE, TransformX(x + math.cos(a) * rad), TransformY(y + math.sin(a) * rad), u0, v0, c)
                            end
                            local vtx_base = dl._VtxCurrentIdx
                            local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
                            for i = 2, num_segments - 1 do
                                id[iw] = vtx_base; id[iw + 1] = vtx_base + i - 1; id[iw + 2] = vtx_base + i
                                iw += 3
                            end
                            dl._VtxWritePtr = vw + num_segments; dl._IdxWritePtr = iw; dl._VtxCurrentIdx = vtx_base + num_segments
                        end
                    end
                end
            end

            function internal.PlotBubblesEx(label_id, getter, spec)
                if BeginItemEx(label_id, internal.FitterBubbles1(getter), spec, spec.FillColor, spec.Marker) then
                    if getter.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp = s.Spec
                    if s.RenderFill then
                        RenderCircles(getter, false, sp.FillColors, ImGui.GetColorU32(sp.FillColor), sp.FillColors and sp.FillAlpha or 1)
                    end
                    if s.RenderLine then
                        RenderCircles(getter, true, sp.LineColors, ImGui.GetColorU32(sp.LineColor), 1, sp.LineWeight)
                    end
                    EndItem()
                end
            end

            -- [Port] overloads dispatched on argument types:
            --   PlotBubbles(label_id, values, szs, count?, xscale = 1, x0 = 0, spec?)
            --   PlotBubbles(label_id, xs, ys, szs, count?, spec?)
            function ImPlot.PlotBubbles(label_id, a, b, c, d, e, f)
                if IsArray(c) then
                    local count, sp = d, e
                    if type(count) == "table" then sp, count = count, nil end
                    count = count or min(#a, #b, #c)
                    local spec = ResolveSpec(sp)
                    internal.PlotBubblesEx(label_id, internal.GetterXYZ(internal.IndexerIdx(a, count, spec.Offset, spec.Stride),
                        internal.IndexerIdx(b, count, spec.Offset, spec.Stride), internal.IndexerIdx(c, count, spec.Offset, spec.Stride), count), spec)
                else
                    local count, xscale, x0, sp = c, d, e, f
                    if type(count) == "table" then sp, count, xscale, x0 = count, nil, nil, nil
                    elseif type(xscale) == "table" then sp, xscale, x0 = xscale, nil, nil
                    elseif type(x0) == "table" then sp, x0 = x0, nil end
                    count = count or min(#a, #b)
                    local spec = ResolveSpec(sp)
                    internal.PlotBubblesEx(label_id, internal.GetterXYZ(internal.IndexerLin(xscale or 1, x0 or 0),
                        internal.IndexerIdx(a, count, spec.Offset, spec.Stride), internal.IndexerIdx(b, count, spec.Offset, spec.Stride), count), spec)
                end
            end

            -------------------------------------------------------------------
            -- PlotErrorBars
            -------------------------------------------------------------------

            -- [Port] PlotErrorBarsVEx/PlotErrorBarsHEx merged; horz selects vertical whiskers
            local function PlotErrorBarsEx(label_id, getter_pos, getter_neg, spec, horz)
                if BeginItemEx(label_id, internal.Fitter2(getter_pos, getter_neg), spec, IMPLOT_AUTO_COL()) then
                    if getter_pos.Count <= 0 or getter_neg.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp = s.Spec
                    local draw_list = internal.GetPlotDrawList()
                    local col
                    if IsColorAuto(spec.LineColor) then col = ImGui.GetColorU32(ImGui.GetStyleColorVec4(G.ImGuiCol.Text)) else col = ImGui.GetColorU32(sp.LineColor) end
                    local rend_whisker = sp.Size > 0
                    local half_whisker = sp.Size * 0.5
                    local weight = sp.LineWeight
                    local plot = GImPlot.CurrentPlot
                    local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
                    local p1, p2 = ImVec2(0, 0), ImVec2(0, 0)
                    for i = 0, getter_pos.Count - 1 do
                        local nx, ny = getter_neg.Get(getter_neg, i)
                        local px, py = getter_pos.Get(getter_pos, i)
                        p1.x, p1.y = x_axis:PlotToPixels(nx), y_axis:PlotToPixels(ny)
                        p2.x, p2.y = x_axis:PlotToPixels(px), y_axis:PlotToPixels(py)
                        draw_list:AddLine(p1, p2, col, weight)
                        if rend_whisker then
                            if horz then
                                AddLineV(draw_list, p1.x, p1.y - half_whisker, p1.y + half_whisker, col, weight)
                                AddLineV(draw_list, p2.x, p2.y - half_whisker, p2.y + half_whisker, col, weight)
                            else
                                AddLineH(draw_list, p1.x - half_whisker, p1.x + half_whisker, p1.y, col, weight)
                                AddLineH(draw_list, p2.x - half_whisker, p2.x + half_whisker, p2.y, col, weight)
                            end
                        end
                    end
                    EndItem()
                end
            end
            function internal.PlotErrorBarsVEx(label_id, getter_pos, getter_neg, spec) PlotErrorBarsEx(label_id, getter_pos, getter_neg, spec, false) end
            function internal.PlotErrorBarsHEx(label_id, getter_pos, getter_neg, spec) PlotErrorBarsEx(label_id, getter_pos, getter_neg, spec, true) end

            -- [Port] overloads dispatched on argument types:
            --   PlotErrorBars(label_id, xs, ys, err, count?, spec?)
            --   PlotErrorBars(label_id, xs, ys, neg, pos, count?, spec?)
            function ImPlot.PlotErrorBars(label_id, xs, ys, neg, pos, count, sp)
                if not IsArray(pos) then
                    count, sp = pos, count
                    pos = neg
                end
                if type(count) == "table" then sp, count = count, nil end
                count = count or min(#xs, #ys, #neg, #pos)
                local spec = ResolveSpec(sp)
                local indexer_x = internal.IndexerIdx(xs, count, spec.Offset, spec.Stride)
                local indexer_y = internal.IndexerIdx(ys, count, spec.Offset, spec.Stride)
                local indexer_n = internal.IndexerIdx(neg, count, spec.Offset, spec.Stride)
                local indexer_p = internal.IndexerIdx(pos, count, spec.Offset, spec.Stride)
                if ImHasFlag(spec.Flags, ImPlotErrorBarsFlags.Horizontal) then
                    local getter_p = internal.GetterXY(internal.IndexerAdd(indexer_x, indexer_p, 1, 1), indexer_y, count)
                    local getter_n = internal.GetterXY(internal.IndexerAdd(indexer_x, indexer_n, 1, -1), indexer_y, count)
                    PlotErrorBarsEx(label_id, getter_p, getter_n, spec, true)
                else
                    local getter_p = internal.GetterXY(indexer_x, internal.IndexerAdd(indexer_y, indexer_p, 1, 1), count)
                    local getter_n = internal.GetterXY(indexer_x, internal.IndexerAdd(indexer_y, indexer_n, 1, -1), count)
                    PlotErrorBarsEx(label_id, getter_p, getter_n, spec, false)
                end
            end

            -------------------------------------------------------------------
            -- PlotStems
            -------------------------------------------------------------------

            function internal.PlotStemsEx(label_id, getter_mark, getter_base, spec)
                if BeginItemEx(label_id, internal.Fitter2(getter_mark, getter_base), spec, spec.LineColor, spec.Marker) then
                    if getter_mark.Count <= 0 or getter_base.Count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp = s.Spec
                    -- render stems
                    if s.RenderLine then
                        UseCurrentTransformer()
                        Render(internal.RendererLineSegments2(getter_mark, getter_base, sp.LineWeight), sp.LineColors, getter_mark.Count, ImGui.GetColorU32(sp.LineColor), 1)
                    end
                    -- render markers
                    if s.RenderMarkers then
                        PopPlotClipRect()
                        PushPlotClipRect(sp.MarkerSize)
                        internal.RenderColoredMarkers(getter_mark, s)
                    end
                    EndItem()
                end
            end

            -- [Port] overloads dispatched on argument types:
            --   PlotStems(label_id, values, count?, ref = 0, scale = 1, start = 0, spec?)
            --   PlotStems(label_id, xs, ys, count?, ref = 0, spec?)
            function ImPlot.PlotStems(label_id, a, b, c, d, e, f)
                if IsArray(b) then
                    local count, ref, sp = c, d, e
                    if type(count) == "table" then sp, count, ref = count, nil, nil
                    elseif type(ref) == "table" then sp, ref = ref, nil end
                    count = count or min(#a, #b)
                    local spec = ResolveSpec(sp)
                    local ix = internal.IndexerIdx(a, count, spec.Offset, spec.Stride)
                    local iy = internal.IndexerIdx(b, count, spec.Offset, spec.Stride)
                    local iref = internal.IndexerConst(ref or 0)
                    if ImHasFlag(spec.Flags, ImPlotStemsFlags.Horizontal) then
                        internal.PlotStemsEx(label_id, internal.GetterXY(ix, iy, count), internal.GetterXY(iref, iy, count), spec)
                    else
                        internal.PlotStemsEx(label_id, internal.GetterXY(ix, iy, count), internal.GetterXY(ix, iref, count), spec)
                    end
                else
                    local count, ref, scale, start, sp = b, c, d, e, f
                    if type(count) == "table" then sp, count, ref, scale, start = count, nil, nil, nil, nil
                    elseif type(ref) == "table" then sp, ref, scale, start = ref, nil, nil, nil
                    elseif type(scale) == "table" then sp, scale, start = scale, nil, nil
                    elseif type(start) == "table" then sp, start = start, nil end
                    count = count or #a
                    local spec = ResolveSpec(sp)
                    local iv = internal.IndexerIdx(a, count, spec.Offset, spec.Stride)
                    local lin = internal.IndexerLin(scale or 1, start or 0)
                    local iref = internal.IndexerConst(ref or 0)
                    if ImHasFlag(spec.Flags, ImPlotStemsFlags.Horizontal) then
                        internal.PlotStemsEx(label_id, internal.GetterXY(iv, lin, count), internal.GetterXY(iref, lin, count), spec)
                    else
                        internal.PlotStemsEx(label_id, internal.GetterXY(lin, iv, count), internal.GetterXY(lin, iref, count), spec)
                    end
                end
            end

            -------------------------------------------------------------------
            -- PlotInfLines
            -------------------------------------------------------------------

            -- [Port] the horizontal/vertical branches differ only in getters + fitter; merged
            function ImPlot.PlotInfLines(label_id, values, count, sp)
                if type(count) == "table" then sp, count = count, nil end
                count = count or #values
                local spec = ResolveSpec(sp)
                local lims = ImPlot.GetPlotLimits(IMPLOT_AUTO, IMPLOT_AUTO)
                local iv = internal.IndexerIdx(values, count, spec.Offset, spec.Stride)
                local getter_min, getter_max, fitter
                if ImHasFlag(spec.Flags, ImPlotInfLinesFlags.Horizontal) then
                    getter_min = internal.GetterXY(internal.IndexerConst(lims.X.Min), iv, count)
                    getter_max = internal.GetterXY(internal.IndexerConst(lims.X.Max), iv, count)
                    fitter = internal.FitterY(getter_min)
                else
                    getter_min = internal.GetterXY(iv, internal.IndexerConst(lims.Y.Min), count)
                    getter_max = internal.GetterXY(iv, internal.IndexerConst(lims.Y.Max), count)
                    fitter = internal.FitterX(getter_min)
                end
                if BeginItemEx(label_id, fitter, spec, spec.LineColor) then
                    if count <= 0 then
                        EndItem()
                        return
                    end
                    local s = GetItemData()
                    local sp_ = s.Spec
                    if s.RenderLine then
                        UseCurrentTransformer()
                        Render(internal.RendererLineSegments2(getter_min, getter_max, sp_.LineWeight), sp_.LineColors, count, ImGui.GetColorU32(sp_.LineColor), 1)
                    end
                    EndItem()
                end
            end

            -------------------------------------------------------------------
            -- PlotDigital
            -------------------------------------------------------------------

            -- TODO: Make this behave like all the other plot types (.e. not fixed in y axis)
            -- TODO: Currently broken if x or y axis is inverted! (what should happen in this case, anyway?)
            local digital_min, digital_max = ImVec2(0, 0), ImVec2(0, 0)
            function internal.PlotDigitalEx(label_id, getter, spec)
                if BeginItem(label_id, spec, spec.FillColor) then
                    local gp = GImPlot
                    local draw_list = internal.GetPlotDrawList()
                    local s = GetItemData()
                    if getter.Count > 1 and s.RenderFill then
                        local plot   = gp.CurrentPlot
                        local x_axis = plot.Axes[plot.CurrentX]
                        local y_axis = plot.Axes[plot.CurrentY]
                        local pr     = plot.PlotRect
                        local col    = ImGui.GetColorU32(s.Spec.FillColor)
                        local size   = s.Spec.Size
                        local pMin, pMax = digital_min, digital_max

                        local pixYMax = 0
                        local x1, y1 = getter.Get(getter, 0)
                        local i = 0
                        while i < getter.Count do
                            local x2, y2 = getter.Get(getter, i)
                            if ImNanOrInf(y1) then
                                x1, y1 = x2, y2
                            else
                                if ImNanOrInf(y2) then
                                    y2 = ImConstrainNanInf(y2)
                                end
                                local pixY_0 = floor(s.Spec.LineWeight)
                                y1 = max(0.0, y1)
                                local pixY_1 = size * y1
                                local pixY_chPosOffset = floor(max(size, pixY_1) + gp.Style.DigitalSpacing)
                                pixYMax = max(pixYMax, pixY_chPosOffset)
                                pMin.x = x_axis:PlotToPixels(x1)
                                pMax.x = x_axis:PlotToPixels(x2)
                                local pixY_Offset = floor(gp.Style.DigitalPadding)
                                local y_ref
                                if y_axis:IsInverted() then y_ref = y_axis.PixelMax else y_ref = y_axis.PixelMin end
                                pMin.y = y_ref - (gp.DigitalPlotOffset + pixY_Offset)
                                pMax.y = y_ref - (gp.DigitalPlotOffset + pixY_0 + floor(pixY_1) + pixY_Offset)
                                --plot only one rectangle for same digital state
                                while (i + 2) < getter.Count and y1 == y2 do
                                    local in_ = i + 1
                                    x2, y2 = getter.Get(getter, in_)
                                    if ImNanOrInf(y2) then break end
                                    pMax.x = x_axis:PlotToPixels(x2)
                                    i += 1
                                end
                                -- do not extend plot outside plot range
                                local lo, hi
                                if not x_axis:IsInverted() then lo, hi = x_axis.PixelMin, x_axis.PixelMax - 1 else lo, hi = x_axis.PixelMax, x_axis.PixelMin - 1 end
                                pMin.x = G.ImClamp(pMin.x, lo, hi)
                                pMax.x = G.ImClamp(pMax.x, lo, hi)
                                --plot a rectangle that extends up to x2 with y1 height
                                if pr:Contains(pMin) or pr:Contains(pMax) then
                                    draw_list:AddRectFilled(pMin, pMax, col)
                                end
                                x1, y1 = x2, y2
                            end
                            i += 1
                        end
                        gp.DigitalPlotItemCnt += 1
                        gp.DigitalPlotOffset += pixYMax
                    end
                    EndItem()
                end
            end

            function ImPlot.PlotDigital(label_id, xs, ys, count, sp)
                if type(count) == "table" then sp, count = count, nil end
                count = count or min(#xs, #ys)
                local spec = ResolveSpec(sp)
                internal.PlotDigitalEx(label_id, internal.GetterXY(internal.IndexerIdx(xs, count, spec.Offset, spec.Stride), internal.IndexerIdx(ys, count, spec.Offset, spec.Stride), count), spec)
            end

            -- custom
            function ImPlot.PlotDigitalG(label_id, getter_func, data, count, spec)
                internal.PlotDigitalEx(label_id, internal.GetterFuncPtr(getter_func, data, count), ResolveSpec(spec))
            end

            -------------------------------------------------------------------
            -- PlotText
            -------------------------------------------------------------------

            local function FitPoint(x, y)
                local plot = GImPlot.CurrentPlot
                local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
                x_axis:ExtendFitWith(y_axis, x, y)
                y_axis:ExtendFitWith(x_axis, y, x)
            end
            local function FitPixel(px, py)
                local plot = GImPlot.CurrentPlot
                FitPoint(plot.Axes[plot.CurrentX]:PixelsToPlot(px), plot.Axes[plot.CurrentY]:PixelsToPlot(py))
            end

            -- PlotText(text, x, y, pixel_offset?, spec?)
            function ImPlot.PlotText(text, x, y, pixel_offset, sp)
                IM_ASSERT(GImPlot.CurrentPlot ~= nil, "PlotText() needs to be called between BeginPlot() and EndPlot()!")
                if type(pixel_offset) == "table" and pixel_offset.x == nil then sp, pixel_offset = pixel_offset, nil end
                local offx, offy = 0, 0
                if pixel_offset ~= nil then offx, offy = pixel_offset.x, pixel_offset.y end
                local spec = ResolveSpec(sp)
                SetupLock()
                local draw_list = internal.GetPlotDrawList()
                PushPlotClipRect()
                local colTxt = GetStyleColorU32(ImPlotCol.InlayText)
                local plot = GImPlot.CurrentPlot
                local fit = plot.FitThisFrame and not ImHasFlag(spec.Flags, ImPlotItemFlags.NoFit)
                local px, py = plot.Axes[plot.CurrentX]:PlotToPixels(x), plot.Axes[plot.CurrentY]:PlotToPixels(y)
                if ImHasFlag(spec.Flags, ImPlotTextFlags.Vertical) then
                    local siz = internal.CalcTextSizeVertical(text)
                    local sizx, sizy = siz.x * 0.5, siz.y * 0.5
                    local posx, posy = px - sizx * 0.5 + offx, py + sizy * 0.5 + offy
                    if fit then
                        FitPixel(posx, posy)
                        FitPixel(posx + sizx, posy - sizy)
                    end
                    internal.AddTextVertical(draw_list, ImVec2(posx, posy), colTxt, text)
                else
                    local siz = ImGui.CalcTextSize(text)
                    local posx, posy = px - siz.x * 0.5 + offx, py - siz.y * 0.5 + offy
                    if fit then
                        FitPixel(posx, posy)
                        FitPixel(posx + siz.x, posy + siz.y)
                    end
                    draw_list:AddText(nil, 0.0, ImVec2(posx, posy), colTxt, text, 1, #text + 1)
                end
                PopPlotClipRect()
            end

            -------------------------------------------------------------------
            -- PlotDummy
            -------------------------------------------------------------------

            function ImPlot.PlotDummy(label_id, sp)
                local spec = ResolveSpec(sp)
                -- Pick the first non-auto color from the spec to override the legend icon color
                local item_col = spec.LineColor
                if IsColorAuto(item_col) then item_col = spec.FillColor end
                if IsColorAuto(item_col) then item_col = spec.MarkerLineColor end
                if IsColorAuto(item_col) then item_col = spec.MarkerFillColor end
                if BeginItem(label_id, spec, item_col, spec.Marker) then
                    EndItem()
                end
            end
        end

        -----------------------------------------------------------------------
        -- PlotPieChart, PlotHeatmap, PlotHistogram, PlotHistogram2D, PlotImage
        -----------------------------------------------------------------------
        do
            local ImPlotPieChartFlags = ImPlot.ImPlotPieChartFlags
            local ImPlotHeatmapFlags = ImPlot.ImPlotHeatmapFlags
            local ImPlotHistogramFlags = ImPlot.ImPlotHistogramFlags
            local ImPlotBarsFlags = ImPlot.ImPlotBarsFlags
            local ImPlotBin = ImPlot.ImPlotBin
            local IM_COL32_A_MASK = 0xFF000000

            -- [Port] CalcTextColor(ImVec4) / CalcTextColor(ImU32) overloads (implot_internal.h)
            local function CalcTextColorU32(c)
                local r, g_, b = band(c, 0xFF) / 255, band(rshift(c, 8), 0xFF) / 255, band(rshift(c, 16), 0xFF) / 255
                if (r * 0.299 + g_ * 0.587 + b * 0.114) > 0.5 then return G.IM_COL32_BLACK end
                return G.IM_COL32_WHITE
            end
            function internal.CalcTextColor(bg)
                if type(bg) == "number" then return CalcTextColorU32(bg) end
                if (bg.x * 0.299 + bg.y * 0.587 + bg.z * 0.114) > 0.5 then return G.IM_COL32_BLACK end
                return G.IM_COL32_WHITE
            end

            -- Returns true if a plot item legend entry is hovered.
            function ImPlot.IsLegendEntryHovered(label_id)
                IM_ASSERT(GImPlot.CurrentItems ~= nil, "IsPlotItemHighlight() needs to be called within an itemized context!")
                local item = internal.GetItem(label_id)
                return item ~= nil and item.LegendHovered
            end

            -- [Port] ImMinMaxIndexer -> returns (min, max)
            @native
            local function ImMinMaxIndexer(indexer, count)
                local min_out, max_out = indexer.At(indexer, 0), indexer.At(indexer, 0)
                local d = PlainData(indexer)
                for i = 1, count - 1 do
                    local v = d and d[i + 1] or indexer.At(indexer, i)
                    if v < min_out then min_out = v end
                    if v > max_out then max_out = v end
                end
                return min_out, max_out
            end

            @native
            local function ImStdDev(indexer, count)
                local den = 1.0 / (count - 1.0)
                local mu = 0
                for i = 0, count - 1 do mu += indexer.At(indexer, i) * (1.0 / count) end
                local x = 0
                for i = 0, count - 1 do
                    local d = indexer.At(indexer, i) - mu
                    x += d * d * den
                end
                return sqrt(x)
            end

            -- Calculate histogram bin counts and widths
            -- [Port] returns (bins_out, width_out)
            local function CalculateBins(values, count, meth, range_min, range_max)
                local bins_out, width_out = 0, 0
                if meth == ImPlotBin.Sqrt then
                    bins_out = math.ceil(sqrt(count))
                elseif meth == ImPlotBin.Sturges then
                    bins_out = math.ceil(1.0 + math.log(count, 2))
                elseif meth == ImPlotBin.Rice then
                    bins_out = math.ceil(2 * count ^ (1 / 3))
                elseif meth == ImPlotBin.Scott then
                    width_out = 3.49 * ImStdDev(values, count) / count ^ (1 / 3)
                    bins_out = floor((range_max - range_min) / width_out + 0.5)
                end
                width_out = (range_max - range_min) / bins_out
                return bins_out, width_out
            end
            internal.CalculateBins = CalculateBins

            -------------------------------------------------------------------
            -- PlotPieChart
            -------------------------------------------------------------------

            -- [Port] ImVec2 buffer[52] flattened to {x1, y1, x2, y2, ...}, reused across calls
            local pie_buf = table.create(104, 0)

            local function RenderPieSliceFill(dl, buf, count, col)
                local uv = dl._Data.TexUvWhitePixel
                -- Triangle fan: n-2 triangles for n vertices, so (n-2)*3 indices
                dl:PrimReserve((count - 2) * 3, count)
                local b = dl.VtxBuffer.Buf
                local vw = dl._VtxWritePtr
                local o = (vw - 1) * VTX_STRIDE
                for i = 0, count - 1 do
                    WV(b, o + i * VTX_STRIDE, buf[i * 2 + 1], buf[i * 2 + 2], uv.x, uv.y, col)
                end
                local vtx_base = dl._VtxCurrentIdx
                local id, iw = dl.IdxBuffer.Data, dl._IdxWritePtr
                for i = 2, count - 1 do
                    id[iw] = vtx_base; id[iw + 1] = vtx_base + i - 1; id[iw + 2] = vtx_base + i
                    iw += 3
                end
                dl._VtxWritePtr = vw + count; dl._IdxWritePtr = iw; dl._VtxCurrentIdx = vtx_base + count
            end

            local function RenderPieSliceLine(dl, buf, count, col)
                local half_weight = 1.0 -- Weight of 2.0f -> half_weight of 1.0f
                local hw, u0, v0, u1, v1 = GetLineRenderProps(dl, half_weight)
                -- Polyline with n points has n-1 segments, each needs 4 vertices and 6 indices
                local segments = count - 1
                dl:PrimReserve(segments * 6, segments * 4)
                for i = 0, segments - 1 do
                    PrimLine(dl, buf[i * 2 + 1], buf[i * 2 + 2], buf[i * 2 + 3], buf[i * 2 + 4], hw, col, u0, v0, u1, v1)
                end
            end

            local function RenderPieSlice(dl, cx, cy, radius, a0, a1, col, flags, detached)
                local resolution = 50 / (2 * math.pi)
                local buf = pie_buf
                local plot = GImPlot.CurrentPlot
                local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
                local n = max(3, floor((a1 - a0) * resolution))
                local da = (a1 - a0) / (n - 1)
                if detached then
                    local offset = 0.08 -- Offset of the detached slice
                    local width_scale = 0.95 -- Scale factor for the width of the detached slice
                    local a_mid = (a0 + a1) / 2
                    local new_a0 = a_mid - (a1 - a0) * width_scale / 2
                    local new_a1 = a_mid + (a1 - a0) * width_scale / 2
                    local new_da = (new_a1 - new_a0) / (n - 1)
                    local ocx, ocy = cx + offset * math.cos(a_mid), cy + offset * math.sin(a_mid)
                    -- Start point (center of the offset)
                    buf[1], buf[2] = x_axis:PlotToPixels(ocx), y_axis:PlotToPixels(ocy)
                    for i = 0, n - 1 do
                        local a = new_a0 + i * new_da
                        buf[i * 2 + 3] = x_axis:PlotToPixels(ocx + (radius + offset / 2) * math.cos(a))
                        buf[i * 2 + 4] = y_axis:PlotToPixels(ocy + (radius + offset / 2) * math.sin(a))
                    end
                else
                    buf[1], buf[2] = x_axis:PlotToPixels(cx), y_axis:PlotToPixels(cy)
                    for i = 0, n - 1 do
                        local a = a0 + i * da
                        buf[i * 2 + 3] = x_axis:PlotToPixels(cx + radius * math.cos(a))
                        buf[i * 2 + 4] = y_axis:PlotToPixels(cy + radius * math.sin(a))
                    end
                end
                -- Close the shape
                buf[n * 2 + 3], buf[n * 2 + 4] = buf[1], buf[2]
                -- fill
                RenderPieSliceFill(dl, buf, n + 2, col)
                -- border (for AA)
                if not ImHasFlag(flags, ImPlotPieChartFlags.NoSliceBorder) then
                    RenderPieSliceLine(dl, buf, n + 2, col)
                end
            end

            local function PieChartSum(indexer, ignore_hidden)
                local sum = 0
                if ignore_hidden then
                    local Items = GImPlot.CurrentItems
                    for i = 0, indexer.Count - 1 do
                        if i >= Items:GetItemCount() then
                            break
                        end
                        local item = Items:GetItemByIndex(i)
                        IM_ASSERT(item ~= nil)
                        if item.Show then
                            sum += indexer.At(indexer, i)
                        end
                    end
                else
                    for i = 0, indexer.Count - 1 do
                        sum += indexer.At(indexer, i)
                    end
                end
                return sum
            end

            -- [Port] label_ids is a 1-based array of strings
            function internal.PlotPieChartEx(label_ids, indexer, cx, cy, radius, angle0, spec)
                local draw_list = internal.GetPlotDrawList()
                local ignore_hidden = ImHasFlag(spec.Flags, ImPlotPieChartFlags.IgnoreHidden)
                local sum = PieChartSum(indexer, ignore_hidden)
                local normalize = ImHasFlag(spec.Flags, ImPlotPieChartFlags.Normalize) or sum > 1.0
                local a0 = angle0 * 2 * math.pi / 360.0
                local a1 = angle0 * 2 * math.pi / 360.0
                for i = 0, indexer.Count - 1 do
                    local label = label_ids[i + 1]
                    local item = internal.GetItem(label)
                    local v = indexer.At(indexer, i)
                    local percent = v
                    if normalize then percent = v / sum end
                    local skip = sum <= 0.0 or (ignore_hidden and item ~= nil and not item.Show)
                    if not skip then
                        a1 = a0 + 2 * math.pi * percent
                    end
                    if BeginItemEx(label, internal.FitterRect(cx - radius, cy - radius, cx + radius, cy + radius), spec) then
                        local hovered = ImPlot.IsLegendEntryHovered(label) and ImHasFlag(spec.Flags, ImPlotPieChartFlags.Exploding)
                        if sum > 0.0 then
                            local col = internal.GetCurrentItem().Color
                            if percent < 0.5 then
                                RenderPieSlice(draw_list, cx, cy, radius, a0, a1, col, spec.Flags, hovered)
                            else
                                RenderPieSlice(draw_list, cx, cy, radius, a0, a0 + (a1 - a0) * 0.5, col, spec.Flags, hovered)
                                RenderPieSlice(draw_list, cx, cy, radius, a0 + (a1 - a0) * 0.5, a1, col, spec.Flags, hovered)
                            end
                        end
                        EndItem()
                    end
                    if not skip then
                        a0 = a1
                    end
                end
            end

            local function PieChartFormatter(value, data)
                return string.format(data, value)
            end

            -- [Port] PlotPieChart(label_ids, values, count, x, y, radius, fmt = "%.1f", angle0 = 90, spec?) and
            --        PlotPieChart(label_ids, values, count, x, y, radius, formatter, fmt_data, angle0 = 90, spec?) overloads,
            --        dispatched on type(fmt). Pass fmt = false to disable labels (upstream nullptr).
            --        Formatters return the label string (see Formatter_Default).
            function ImPlot.PlotPieChart(label_ids, values, count, x, y, radius, fmt, a, b, c)
                IM_ASSERT(GImPlot.CurrentPlot ~= nil, "PlotPieChart() needs to be called between BeginPlot() and EndPlot()!")
                local fmt_data, angle0, sp
                if type(fmt) == "function" then
                    fmt_data, angle0, sp = a, b, c
                else
                    angle0, sp = a, b
                    if fmt == nil then fmt = "%.1f" end
                    if fmt ~= false then
                        fmt_data = fmt
                        fmt = PieChartFormatter
                    end
                end
                if type(angle0) == "table" then sp, angle0 = angle0, nil end
                angle0 = angle0 or 90
                count = count or #values
                local spec = ResolveSpec(sp)
                local draw_list = internal.GetPlotDrawList()
                local indexer = internal.IndexerIdx(values, count, spec.Offset, spec.Stride)
                local ignore_hidden = ImHasFlag(spec.Flags, ImPlotPieChartFlags.IgnoreHidden)
                local sum = PieChartSum(indexer, ignore_hidden)
                local normalize = ImHasFlag(spec.Flags, ImPlotPieChartFlags.Normalize) or sum > 1.0

                PushPlotClipRect()
                internal.PlotPieChartEx(label_ids, indexer, x, y, radius, angle0, spec)
                if fmt then
                    local a0 = angle0 * 2 * math.pi / 360.0
                    local a1 = angle0 * 2 * math.pi / 360.0
                    local plot = GImPlot.CurrentPlot
                    local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
                    for i = 0, count - 1 do
                        local item = internal.GetItem(label_ids[i + 1])
                        IM_ASSERT(item ~= nil)
                        local v = indexer.At(indexer, i)
                        local percent = v
                        if normalize then percent = v / sum end
                        local skip = ignore_hidden and item ~= nil and not item.Show
                        if not skip then
                            a1 = a0 + 2 * math.pi * percent
                            if item.Show then
                                local buffer = fmt(v, fmt_data)
                                local size = ImGui.CalcTextSize(buffer)
                                local angle = a0 + (a1 - a0) * 0.5
                                local hovered = ImPlot.IsLegendEntryHovered(label_ids[i + 1]) and ImHasFlag(spec.Flags, ImPlotPieChartFlags.Exploding)
                                local offset = 0.5 * radius
                                if hovered then offset = 0.6 * radius end
                                local px = x_axis:PlotToPixels(x + offset * math.cos(angle))
                                local py = y_axis:PlotToPixels(y + offset * math.sin(angle))
                                local col = CalcTextColorU32(item.Color)
                                draw_list:AddText(nil, 0.0, ImVec2(px - size.x * 0.5, py - size.y * 0.5), col, buffer, 1, #buffer + 1)
                            end
                            a0 = a1
                        end
                    end
                end
                PopPlotClipRect()
            end

            -------------------------------------------------------------------
            -- PlotHeatmap
            -------------------------------------------------------------------

            -- [Port] GetterHeatmapRowMaj/ColMaj + RendererRectC fused into one renderer; the RectC is computed in Render
            -- (renderer table reused across calls, so nothing is allocated per cell)
            @native
            local function HeatmapRender(r, dl, cr, prim)
                local ix, d = r.Indexer, r.Data
                local val = d and d[prim + 1] or ix.At(ix, prim)
                local row, c
                if r.ColMaj then
                    row, c = prim % r.Rows, prim // r.Rows
                else
                    row, c = prim // r.Cols, prim % r.Cols
                end
                local hx, hy = r.Width * 0.5, r.Height * 0.5
                local px = r.XRef + hx + c * r.Width
                local py = r.YRef + r.YDir * (hy + row * r.Height)
                local t = math.clamp((val - r.ScaleMin) / (r.ScaleMax - r.ScaleMin), 0.0, 1.0)
                local col = r.Colormaps:LerpTable(r.Cmap, t)
                local p1x, p1y = TransformX(px - hx), TransformY(py - hy)
                local p2x, p2y = TransformX(px + hx), TransformY(py + hy)
                if band(col, IM_COL32_A_MASK) == 0 or not Overlaps(cr, p1x, p1y, p2x, p2y) then
                    return false
                end
                PrimRectFill(dl, p1x, p1y, p2x, p2y, col, r.U, r.V)
                return true
            end
            -- [Luau] cells i0..i1 in one call when there are no axis transform functions: HeatmapRender + LerpTable +
            -- TransformX/Y + Overlaps + PrimRectFill inlined, same math. Returns culled count.
            @native
            local function HeatmapRange(r, dl, cr, i0, i1)
                if tx_fwd ~= nil or ty_fwd ~= nil then
                    local culled = 0
                    for i = i0, i1 do
                        if not HeatmapRender(r, dl, cr, i) then culled += 1 end
                    end
                    return culled
                end
                local ix, d = r.Indexer, r.Data
                local rows, cols, col_maj = r.Rows, r.Cols, r.ColMaj
                local w, h = r.Width, r.Height
                local hx, hy = w * 0.5, h * 0.5
                local xref, yref, ydir = r.XRef, r.YRef, r.YDir
                local smin, smax = r.ScaleMin, r.ScaleMax
                local cm, cmap = r.Colormaps, r.Cmap
                local tables, off, siz, qual = cm.Tables, cm.TableOffsets[cmap + 1], cm.TableSizes[cmap + 1], cm.Quals[cmap + 1]
                local cminx, cminy, cmaxx, cmaxy = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
                local xpm, xm, xpl, ypm, ym, ypl = tx_pixmin, tx_m, tx_pltmin, ty_pixmin, ty_m, ty_pltmin
                local u, v = r.U, r.V
                local b, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
                local vw, iw, vi = dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx
                local culled = 0
                for prim = i0, i1 do
                    local val = d and d[prim + 1] or ix.At(ix, prim)
                    local row, c
                    if col_maj then
                        row, c = prim % rows, prim // rows
                    else
                        row, c = prim // cols, prim % cols
                    end
                    local px = xref + hx + c * w
                    local py = yref + ydir * (hy + row * h)
                    local t = math.clamp((val - smin) / (smax - smin), 0.0, 1.0)
                    local idx
                    if qual then
                        idx = min(max(floor(siz * t), 0), siz - 1) -- ImClamp
                    else
                        idx = floor((siz - 1) * t + 0.5)
                    end
                    local col = tables[off + idx + 1]
                    local x1, y1 = xpm + xm * ((px - hx) - xpl), ypm + ym * ((py - hy) - ypl)
                    local x2, y2 = xpm + xm * ((px + hx) - xpl), ypm + ym * ((py + hy) - ypl)
                    local minx, maxx = x1, x2
                    if x2 < x1 then minx, maxx = x2, x1 end
                    local miny, maxy = y1, y2
                    if y2 < y1 then miny, maxy = y2, y1 end
                    if band(col, IM_COL32_A_MASK) ~= 0 and miny < cmaxy and maxy > cminy and minx < cmaxx and maxx > cminx then
                        local o = (vw - 1) * VTX_STRIDE
                        WV(b, o,                  x1, y1, u, v, col)
                        WV(b, o + VTX_STRIDE,     x2, y2, u, v, col)
                        WV(b, o + VTX_STRIDE * 2, x1, y2, u, v, col)
                        WV(b, o + VTX_STRIDE * 3, x2, y1, u, v, col)
                        id[iw] = vi; id[iw + 1] = vi + 1; id[iw + 2] = vi + 2
                        id[iw + 3] = vi; id[iw + 4] = vi + 1; id[iw + 5] = vi + 3
                        vw += 4; iw += 6; vi += 4
                    else
                        culled += 1
                    end
                end
                dl._VtxWritePtr, dl._IdxWritePtr, dl._VtxCurrentIdx = vw, iw, vi
                return culled
            end
            local heat_r = { IdxConsumed = 6, VtxConsumed = 4, Init = WhiteInit, Render = HeatmapRender, RenderRange = HeatmapRange }

            local label_pos = ImVec2(0, 0)

            -- [Port] bounds passed as (min_x, min_y, max_x, max_y); fmt = nil -> no labels
            function internal.RenderHeatmap(draw_list, indexer, rows, cols, scale_min, scale_max, fmt, bmin_x, bmin_y, bmax_x, bmax_y, reverse_y, col_maj)
                local gp = GImPlot
                UseCurrentTransformer()
                if scale_min == 0 and scale_max == 0 then
                    scale_min, scale_max = ImMinMaxIndexer(indexer, rows * cols)
                end
                if scale_min == scale_max then
                    local col = ImPlot.GetColormapColorU32(0, gp.Style.Colormap)
                    draw_list:AddRectFilled(ImVec2(TransformX(bmin_x), TransformY(bmin_y)), ImVec2(TransformX(bmax_x), TransformY(bmax_y)), col)
                    return
                end
                local yref, ydir = bmin_y, 1
                if reverse_y then yref, ydir = bmax_y, -1 end
                local r = heat_r
                r.Indexer, r.Prims, r.Rows, r.Cols, r.ColMaj = indexer, rows * cols, rows, cols, col_maj
                r.Data = PlainData(indexer)
                r.ScaleMin, r.ScaleMax = scale_min, scale_max
                r.Width, r.Height = (bmax_x - bmin_x) / cols, (bmax_y - bmin_y) / rows
                r.XRef, r.YRef, r.YDir = bmin_x, yref, ydir
                r.Colormaps, r.Cmap = gp.ColormapData, gp.Style.Colormap
                RenderPrimitivesEx(r, draw_list, gp.CurrentPlot.PlotRect)
                r.Indexer, r.Data = nil, nil
                -- labels
                if fmt ~= nil then
                    local w = (bmax_x - bmin_x) / cols
                    local h = (bmax_y - bmin_y) / rows
                    local i = 0
                    -- [Port] row/col-major loops merged; (r, c) derived from the loop order
                    local outer, inner = rows, cols
                    if col_maj then outer, inner = cols, rows end
                    for o = 0, outer - 1 do
                        for n = 0, inner - 1 do
                            local row, c = o, n
                            if col_maj then row, c = n, o end
                            local px = TransformX(bmin_x + 0.5 * w + c * w)
                            local py = TransformY(yref + ydir * (0.5 * h + row * h))
                            local v = indexer.At(indexer, i)
                            local buff = string.format(fmt, v)
                            local size = ImGui.CalcTextSize(buff)
                            local t = math.clamp((v - scale_min) / (scale_max - scale_min), 0.0, 1.0)
                            local col = CalcTextColorU32(ImPlot.SampleColormapU32(t))
                            label_pos.x, label_pos.y = px - size.x * 0.5, py - size.y * 0.5
                            draw_list:AddText(nil, 0.0, label_pos, col, buff, 1, #buff + 1)
                            i += 1
                        end
                    end
                end
            end

            -- PlotHeatmap(label_id, values, rows, cols, scale_min = 0, scale_max = 0, fmt = "%.1f", bounds_min = (0,0), bounds_max = (1,1), spec?)
            -- [Port] pass fmt = false to disable labels (upstream nullptr)
            function ImPlot.PlotHeatmap(label_id, values, rows, cols, scale_min, scale_max, fmt, bounds_min, bounds_max, sp)
                if type(scale_min) == "table" then sp, scale_min = scale_min, nil end
                if fmt == nil then fmt = "%.1f" end
                if fmt == false then fmt = nil end
                local bminx, bminy, bmaxx, bmaxy = 0, 0, 1, 1
                if bounds_min ~= nil then bminx, bminy = bounds_min.x, bounds_min.y end
                if bounds_max ~= nil then bmaxx, bmaxy = bounds_max.x, bounds_max.y end
                local spec = ResolveSpec(sp)
                if BeginItemEx(label_id, internal.FitterRect(bminx, bminy, bmaxx, bmaxy), spec) then
                    if rows <= 0 or cols <= 0 then
                        EndItem()
                        return
                    end
                    local draw_list = internal.GetPlotDrawList()
                    local col_maj = ImHasFlag(spec.Flags, ImPlotHeatmapFlags.ColMajor)
                    local indexer = internal.IndexerIdx(values, rows * cols, spec.Offset, spec.Stride)
                    internal.RenderHeatmap(draw_list, indexer, rows, cols, scale_min or 0, scale_max or 0, fmt, bminx, bminy, bmaxx, bmaxy, true, col_maj)
                    EndItem()
                end
            end

            -------------------------------------------------------------------
            -- PlotHistogram
            -------------------------------------------------------------------

            -- [Port] gp.TempDouble1/TempDouble2 -> reused module arrays
            local bin_centers, bin_counts = {}, {}
            local hist_spec = SpecDefaults({})

            -- PlotHistogram(label_id, values, count?, bins = ImPlotBin.Sturges, bar_scale = 1.0, range = ImPlotRange(), spec?)
            @native
            function ImPlot.PlotHistogram(label_id, values, count, bins, bar_scale, range, sp)
                count = count or #values
                bins = bins or ImPlotBin.Sturges
                bar_scale = bar_scale or 1.0
                local spec = ResolveSpec(sp)
                local cumulative = ImHasFlag(spec.Flags, ImPlotHistogramFlags.Cumulative)
                local density    = ImHasFlag(spec.Flags, ImPlotHistogramFlags.Density)
                local outliers   = not ImHasFlag(spec.Flags, ImPlotHistogramFlags.NoOutliers)

                local indexer = internal.IndexerIdx(values, count, spec.Offset, spec.Stride)

                if count <= 0 or bins == 0 then
                    return 0
                end

                -- [Port] range copied into locals (ImPlotRange passed by value)
                local rmin, rmax = 0, 0
                if range ~= nil then rmin, rmax = range.Min, range.Max end
                if rmin == 0 and rmax == 0 then
                    rmin, rmax = ImMinMaxIndexer(indexer, count)
                end

                local width
                if bins < 0 then
                    bins, width = CalculateBins(indexer, count, bins, rmin, rmax)
                else
                    width = (rmax - rmin) / bins
                end

                local below = 0
                for b = 1, bins do
                    bin_centers[b] = rmin + (b - 1) * width + width * 0.5
                    bin_counts[b] = 0
                end
                local counted = 0
                local max_count = 0
                local d = PlainData(indexer)
                for i = 0, count - 1 do
                    local val = d and d[i + 1] or indexer.At(indexer, i)
                    if val >= rmin and val <= rmax then
                        local b = math.clamp(floor((val - rmin) / width), 0, bins - 1) + 1
                        bin_counts[b] += 1.0
                        if bin_counts[b] > max_count then
                            max_count = bin_counts[b]
                        end
                        counted += 1
                    elseif val < rmin then
                        below += 1
                    end
                end
                if cumulative and density then
                    if outliers then
                        bin_counts[1] += below
                    end
                    for b = 2, bins do
                        bin_counts[b] += bin_counts[b - 1]
                    end
                    local n_total = counted
                    if outliers then n_total = count end
                    local scale = 1.0 / n_total
                    for b = 1, bins do
                        bin_counts[b] *= scale
                    end
                    max_count = bin_counts[bins]
                elseif cumulative then
                    if outliers then
                        bin_counts[1] += below
                    end
                    for b = 2, bins do
                        bin_counts[b] += bin_counts[b - 1]
                    end
                    max_count = bin_counts[bins]
                elseif density then
                    local n_total = counted
                    if outliers then n_total = count end
                    local scale = 1.0 / (n_total * width)
                    for b = 1, bins do
                        bin_counts[b] *= scale
                    end
                    max_count *= scale
                end
                local spec_bars = SpecDefaults(hist_spec)
                for _, fld in VEC4_FIELDS do CopyVec4(spec_bars[fld], spec[fld]) end
                for _, fld in SCALAR_FIELDS do spec_bars[fld] = spec[fld] end
                -- [Port] bins are read from the reused arrays directly (Offset/Stride already applied to values)
                spec_bars.Offset, spec_bars.Stride = 0, IMPLOT_AUTO
                local ic = internal.IndexerIdx(bin_centers, bins)
                local in_ = internal.IndexerIdx(bin_counts, bins)
                local zero = internal.IndexerConst(0)
                if ImHasFlag(spec.Flags, ImPlotHistogramFlags.Horizontal) then
                    spec_bars.Flags = ImPlotBarsFlags.Horizontal
                    internal.PlotBarsHEx(label_id, internal.GetterXY(in_, ic, bins), internal.GetterXY(zero, ic, bins), bar_scale * width, spec_bars)
                else
                    spec_bars.Flags = 0
                    internal.PlotBarsVEx(label_id, internal.GetterXY(ic, in_, bins), internal.GetterXY(ic, zero, bins), bar_scale * width, spec_bars)
                end
                return max_count
            end

            -------------------------------------------------------------------
            -- PlotHistogram2D
            -------------------------------------------------------------------

            local bin_counts_2d = {}

            -- PlotHistogram2D(label_id, xs, ys, count?, x_bins = ImPlotBin.Sturges, y_bins = ImPlotBin.Sturges, range = ImPlotRect(), spec?)
            @native
            function ImPlot.PlotHistogram2D(label_id, xs, ys, count, x_bins, y_bins, range, sp)
                count = count or min(#xs, #ys)
                x_bins = x_bins or ImPlotBin.Sturges
                y_bins = y_bins or ImPlotBin.Sturges
                local spec = ResolveSpec(sp)
                -- const bool cumulative = ImHasFlag(flags, ImPlotHistogramFlags_Cumulative); NOT SUPPORTED
                local density  = ImHasFlag(spec.Flags, ImPlotHistogramFlags.Density)
                local outliers = not ImHasFlag(spec.Flags, ImPlotHistogramFlags.NoOutliers)
                local col_maj  = ImHasFlag(spec.Flags, ImPlotHistogramFlags.ColMajor)

                local indexer_x = internal.IndexerIdx(xs, count, spec.Offset, spec.Stride)
                local indexer_y = internal.IndexerIdx(ys, count, spec.Offset, spec.Stride)

                if count <= 0 or x_bins == 0 or y_bins == 0 then
                    return 0
                end

                local xmin, xmax, ymin, ymax = 0, 0, 0, 0
                if range ~= nil then xmin, xmax, ymin, ymax = range.X.Min, range.X.Max, range.Y.Min, range.Y.Max end
                if xmin == 0 and xmax == 0 then
                    -- [Port] upstream writes &range.X.Min twice here (leaving X.Max = 0); fixed to fill X.Max
                    xmin, xmax = ImMinMaxIndexer(indexer_x, count)
                end
                if ymin == 0 and ymax == 0 then
                    ymin, ymax = ImMinMaxIndexer(indexer_y, count)
                end

                local width, height
                if x_bins < 0 then
                    x_bins, width = CalculateBins(indexer_x, count, x_bins, xmin, xmax)
                else
                    width = (xmax - xmin) / x_bins
                end
                if y_bins < 0 then
                    y_bins, height = CalculateBins(indexer_y, count, y_bins, ymin, ymax)
                else
                    height = (ymax - ymin) / y_bins
                end

                local bins = x_bins * y_bins
                local counts = bin_counts_2d
                for b = 1, bins do
                    counts[b] = 0
                end

                local counted = 0
                local max_count = 0
                local dx, dy = PlainData(indexer_x), PlainData(indexer_y)
                for i = 0, count - 1 do
                    local x = dx and dx[i + 1] or indexer_x.At(indexer_x, i)
                    local y = dy and dy[i + 1] or indexer_y.At(indexer_y, i)
                    if x >= xmin and x <= xmax and y >= ymin and y <= ymax then
                        local xb = math.clamp(floor((x - xmin) / width), 0, x_bins - 1)
                        local yb = math.clamp(floor((y - ymin) / height), 0, y_bins - 1)
                        local b  = yb * x_bins + xb + 1
                        counts[b] += 1.0
                        if counts[b] > max_count then
                            max_count = counts[b]
                        end
                        counted += 1
                    end
                end
                if density then
                    local n_total = counted
                    if outliers then n_total = count end
                    local scale = 1.0 / (n_total * width * height)
                    for b = 1, bins do
                        counts[b] *= scale
                    end
                    max_count *= scale
                end

                if BeginItemEx(label_id, internal.FitterRect(xmin, ymin, xmax, ymax), spec) then
                    if y_bins <= 0 or x_bins <= 0 then
                        EndItem()
                        return max_count
                    end
                    local draw_list = internal.GetPlotDrawList()
                    local indexer_bin = internal.IndexerIdx(counts, y_bins * x_bins)
                    internal.RenderHeatmap(draw_list, indexer_bin, y_bins, x_bins, 0, max_count, nil, xmin, ymin, xmax, ymax, false, col_maj)
                    EndItem()
                end
                return max_count
            end

            -------------------------------------------------------------------
            -- PlotImage
            -------------------------------------------------------------------

            local IMAGE_UV0, IMAGE_UV1, IMAGE_TINT = ImVec2(0, 0), ImVec2(1, 1), ImVec4(1, 1, 1, 1)

            -- PlotImage(label_id, tex_ref, bmin, bmax, uv0 = (0,0), uv1 = (1,1), tint_col = (1,1,1,1), spec?)
            -- [Port] tex_ref is passed through unchanged to ImDrawList:AddImage
            function ImPlot.PlotImage(label_id, tex_ref, bmin, bmax, uv0, uv1, tint_col, sp)
                uv0 = uv0 or IMAGE_UV0
                uv1 = uv1 or IMAGE_UV1
                tint_col = tint_col or IMAGE_TINT
                local spec = ResolveSpec(sp)
                if BeginItemEx(label_id, internal.FitterRect(bmin.x, bmin.y, bmax.x, bmax.y), spec) then
                    local tint_col32 = ImGui.ColorConvertFloat4ToU32(tint_col)
                    internal.GetCurrentItem().Color = tint_col32
                    local draw_list = internal.GetPlotDrawList()
                    local p1 = ImPlot.PlotToPixels(bmin.x, bmax.y, IMPLOT_AUTO, IMPLOT_AUTO)
                    local p2 = ImPlot.PlotToPixels(bmax.x, bmin.y, IMPLOT_AUTO, IMPLOT_AUTO)
                    PushPlotClipRect()
                    draw_list:AddImage(tex_ref, p1, p2, uv0, uv1, tint_col32)
                    PopPlotClipRect()
                    EndItem()
                end
            end
        end

        -----------------------------------------------------------------------
        -- RenderColorBar, ColormapScale, ColormapSlider, ColormapButton, ColormapIcon (implot.cpp)
        -----------------------------------------------------------------------
        do
            local ImPlotColormapScaleFlags = ImPlot.ImPlotColormapScaleFlags
            local ImGuiCol, ImGuiStyleVar = G.ImGuiCol, G.ImGuiStyleVar
            local cb_min, cb_max = ImVec2(0, 0), ImVec2(0, 0)

            local function CalcTextColorU32(c) return internal.CalcTextColor(c) end

            -- [Port] colors passed as (array, 0-based offset) as returned by ImPlotColormapData:GetKeys; bounds as ImRect
            function internal.RenderColorBar(colors, offset, size, DrawList, bounds, vert, reversed, continuous)
                local n = size
                if continuous then n = size - 1 end
                local col1, col2
                if vert then
                    local step = bounds:GetHeight() / n
                    cb_min.x, cb_min.y, cb_max.x, cb_max.y = bounds.Min.x, bounds.Min.y, bounds.Max.x, bounds.Min.y + step
                    for i = 0, n - 1 do
                        if reversed then
                            col1 = colors[offset + size - i]
                            col2 = col1
                            if continuous then col2 = colors[offset + size - i - 1] end
                        else
                            col1 = colors[offset + i + 1]
                            col2 = col1
                            if continuous then col2 = colors[offset + i + 2] end
                        end
                        DrawList:AddRectFilledMultiColor(cb_min, cb_max, col1, col1, col2, col2)
                        cb_min.y += step; cb_max.y += step
                    end
                else
                    local step = bounds:GetWidth() / n
                    cb_min.x, cb_min.y, cb_max.x, cb_max.y = bounds.Min.x, bounds.Min.y, bounds.Min.x + step, bounds.Max.y
                    for i = 0, n - 1 do
                        if reversed then
                            col1 = colors[offset + size - i]
                            col2 = col1
                            if continuous then col2 = colors[offset + size - i - 1] end
                        else
                            col1 = colors[offset + i + 1]
                            col2 = col1
                            if continuous then col2 = colors[offset + i + 2] end
                        end
                        DrawList:AddRectFilledMultiColor(cb_min, cb_max, col1, col2, col2, col1)
                        cb_min.x += step; cb_max.x += step
                    end
                end
            end
            local RenderColorBar = internal.RenderColorBar

            local function ResolveCmap(gp, cmap)
                if cmap == nil or cmap == IMPLOT_AUTO then cmap = gp.Style.Colormap end
                IM_ASSERT(cmap >= 0 and cmap < gp.ColormapData.Count, "Invalid colormap index!")
                return cmap
            end

            -- ColormapScale(label, scale_min, scale_max, size = (0,0), format = "%g", flags = 0, cmap = IMPLOT_AUTO)
            function ImPlot.ColormapScale(label, scale_min, scale_max, size, format, flags, cmap)
                size = size or ImVec2(0, 0)
                format = format or "%g"
                flags = flags or 0
                local Window = ImGui.GetCurrentWindow()
                if Window.SkipItems then
                    return
                end

                local ID = Window:GetID(label)
                local label_size = ImVec2(0, 0)
                if not ImHasFlag(flags, ImPlotColormapScaleFlags.NoLabel) then
                    label_size = ImGui.CalcTextSize(label, nil, true)
                end

                local gp = GImPlot
                cmap = ResolveCmap(gp, cmap)
                local style = gp.Style

                local frame_size = ImGui.CalcItemSize(size, 0, style.PlotDefaultSize.y)
                if frame_size.y < style.PlotMinSize.y and size.y < 0.0 then
                    frame_size.y = style.PlotMinSize.y
                end

                local range = ImPlot.ImPlotRange(min(scale_min, scale_max), max(scale_min, scale_max))
                if gp.CTicker == nil then gp.CTicker = internal.ImPlotTicker() end
                local ticker = gp.CTicker
                ticker:Reset()
                internal.Locator_Default(ticker, range, frame_size.y, true, internal.Formatter_Default, format)

                local rend_label = label_size.x > 0
                local txt_off = style.LabelPadding.x
                local pad = txt_off + ticker.MaxSize.x
                if rend_label then pad += txt_off + label_size.y end
                local bar_w = 20
                if frame_size.x == 0 then
                    frame_size.x = bar_w + pad + 2 * style.PlotPadding.x
                else
                    bar_w = frame_size.x - (pad + 2 * style.PlotPadding.x)
                    if bar_w < style.MajorTickLen.y then
                        bar_w = style.MajorTickLen.y
                    end
                end

                local DrawList = Window.DrawList
                local cp = Window.DC.CursorPos
                local bb_frame = G.ImRect(cp.x, cp.y, cp.x + frame_size.x, cp.y + frame_size.y)
                ImGui.ItemSize(bb_frame)
                if not ImGui.ItemAdd(bb_frame, ID, bb_frame) then
                    return
                end

                ImGui.RenderFrame(bb_frame.Min, bb_frame.Max, GetStyleColorU32(ImPlotCol.FrameBg), true, ImGui.GetStyle().FrameRounding)

                local opposite = ImHasFlag(flags, ImPlotColormapScaleFlags.Opposite)
                local inverted = ImHasFlag(flags, ImPlotColormapScaleFlags.Invert)
                local reversed = scale_min > scale_max

                local bb_grad_shift = 0
                if opposite then bb_grad_shift = pad end
                local bb_grad = G.ImRect(bb_frame.Min.x + style.PlotPadding.x + bb_grad_shift, bb_frame.Min.y + style.PlotPadding.y,
                    bb_frame.Min.x + bar_w + style.PlotPadding.x + bb_grad_shift, bb_frame.Min.y + frame_size.y - style.PlotPadding.y)

                ImGui.PushClipRect(bb_frame.Min, bb_frame.Max, true)
                local col_text = ImGui.GetColorU32(ImGuiCol.Text)

                local invert_scale = inverted ~= reversed
                local y_min, y_max = bb_grad.Min.y, bb_grad.Max.y
                if invert_scale then y_min, y_max = bb_grad.Max.y, bb_grad.Min.y end

                local keys, keys_off = gp.ColormapData:GetKeys(cmap)
                RenderColorBar(keys, keys_off, gp.ColormapData:GetKeyCount(cmap), DrawList, bb_grad, true, not inverted, not gp.ColormapData:IsQual(cmap))
                for i = 0, ticker:TickCount() - 1 do
                    local tick = ticker.Ticks[i + 1]
                    local y_pos_plt = tick.PlotPos
                    -- ImRemap(y_pos_plt, range.Max, range.Min, y_min, y_max)
                    local y_pos = y_min + (y_max - y_min) * (y_pos_plt - range.Max) / (range.Min - range.Max)
                    local tick_width = style.MinorTickLen.y
                    local tick_thick = style.MinorTickSize.y
                    if tick.Major then tick_width, tick_thick = style.MajorTickLen.y, style.MajorTickSize.y end
                    local tick_t = (y_pos_plt - scale_min) / (scale_max - scale_min)
                    local tick_col = CalcTextColorU32(gp.ColormapData:LerpTable(cmap, tick_t))
                    if y_pos < bb_grad.Max.y - 2 and y_pos > bb_grad.Min.y + 2 then
                        if opposite then
                            internal.AddLineH(DrawList, bb_grad.Min.x + 1, bb_grad.Min.x + tick_width, y_pos, tick_col, tick_thick)
                        else
                            internal.AddLineH(DrawList, bb_grad.Max.x - 1, bb_grad.Max.x - tick_width, y_pos, tick_col, tick_thick)
                        end
                    end
                    local txt_x = bb_grad.Max.x + txt_off
                    if opposite then txt_x = bb_grad.Min.x - txt_off - tick.LabelSize.x end
                    local txt_y = y_pos - tick.LabelSize.y * 0.5
                    local text = ticker:GetText(i)
                    if text ~= nil then
                        DrawList:AddText(nil, 0.0, ImVec2(txt_x, txt_y), col_text, text, 1, #text + 1)
                    end
                end

                if rend_label then
                    local pos_x = bb_grad.Max.x + 2 * txt_off + ticker.MaxSize.x
                    if opposite then pos_x = bb_frame.Min.x + style.PlotPadding.x end
                    local pos_y = (bb_grad.Min.y + bb_grad.Max.y) * 0.5 + label_size.x * 0.5
                    local label_end = ImGui.FindRenderedTextEnd(label)
                    internal.AddTextVertical(DrawList, ImVec2(pos_x, pos_y), col_text, string.sub(label, 1, label_end - 1))
                end
                DrawList:AddRect(bb_grad.Min, bb_grad.Max, GetStyleColorU32(ImPlotCol.PlotBorder))
                ImGui.PopClipRect()
            end

            -- [Port] float* t / ImVec4* out: takes t by value and returns (t, changed) like ImGui.SliderFloat;
            --        if `out` (ImVec4) is given it is filled in place with the sampled color.
            function ImPlot.ColormapSlider(label, t, out, format, cmap)
                format = format or ""
                t = math.clamp(t, 0.0, 1.0)
                local Window = ImGui.GetCurrentWindow()
                if Window.SkipItems then
                    return t, false
                end
                local gp = GImPlot
                cmap = ResolveCmap(gp, cmap)
                local keys, keys_off = gp.ColormapData:GetKeys(cmap)
                local count = gp.ColormapData:GetKeyCount(cmap)
                local qual = gp.ColormapData:IsQual(cmap)
                local pos = Window.DC.CursorPos
                local w = ImGui.CalcItemWidth()
                local h = ImGui.GetFrameHeight()
                local rect = G.ImRect(pos.x, pos.y, pos.x + w, pos.y + h)
                RenderColorBar(keys, keys_off, count, ImGui.GetWindowDrawList(), rect, false, false, not qual)
                local grab = CalcTextColorU32(gp.ColormapData:LerpTable(cmap, t))
                -- const ImU32 text = CalcTextColor(gp.ColormapData.LerpTable(cmap,0.5f));
                ImGui.PushStyleColor(ImGuiCol.FrameBg, G.IM_COL32_BLACK_TRANS)
                ImGui.PushStyleColor(ImGuiCol.FrameBgActive, G.IM_COL32_BLACK_TRANS)
                ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, ImVec4(1, 1, 1, 0.1))
                ImGui.PushStyleColor(ImGuiCol.SliderGrab, grab)
                ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, grab)
                ImGui.PushStyleVar(ImGuiStyleVar.GrabMinSize, 2)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0)
                local changed
                t, changed = ImGui.SliderFloat(label, t, 0, 1, format)
                ImGui.PopStyleColor(5)
                ImGui.PopStyleVar(2)
                if out ~= nil then
                    local c = ImGui.ColorConvertU32ToFloat4(gp.ColormapData:LerpTable(cmap, t))
                    out.x, out.y, out.z, out.w = c.x, c.y, c.z, c.w
                end
                return t, changed
            end

            -- ColormapButton(label, size_arg = (0,0), cmap = IMPLOT_AUTO)
            function ImPlot.ColormapButton(label, size_arg, cmap)
                size_arg = size_arg or ImVec2(0, 0)
                local style = ImGui.GetStyle()
                local Window = ImGui.GetCurrentWindow()
                if Window.SkipItems then
                    return false
                end
                local gp = GImPlot
                cmap = ResolveCmap(gp, cmap)
                local keys, keys_off = gp.ColormapData:GetKeys(cmap)
                local count = gp.ColormapData:GetKeyCount(cmap)
                local qual = gp.ColormapData:IsQual(cmap)
                local pos = Window.DC.CursorPos
                local label_size = ImGui.CalcTextSize(label, nil, true)
                local size = ImGui.CalcItemSize(size_arg, label_size.x + style.FramePadding.x * 2.0, label_size.y + style.FramePadding.y * 2.0)
                local rect = G.ImRect(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
                RenderColorBar(keys, keys_off, count, ImGui.GetWindowDrawList(), rect, false, false, not qual)
                local text = CalcTextColorU32(gp.ColormapData:LerpTable(cmap, style.ButtonTextAlign.x))
                ImGui.PushStyleColor(ImGuiCol.Button, G.IM_COL32_BLACK_TRANS)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(1, 1, 1, 0.1))
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImVec4(1, 1, 1, 0.2))
                ImGui.PushStyleColor(ImGuiCol.Text, text)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0)
                local pressed = ImGui.Button(label, size)
                ImGui.PopStyleColor(4)
                ImGui.PopStyleVar(1)
                return pressed
            end

            function ImPlot.ColormapIcon(cmap)
                local gp = GImPlot
                local txt_size = ImGui.GetTextLineHeight()
                local size = ImVec2(txt_size - 4, txt_size)
                local pos = ImGui.GetCurrentWindow().DC.CursorPos
                local rect = G.ImRect(pos.x, pos.y + 2, pos.x + size.x, pos.y + size.y - 2)
                local keys, keys_off = gp.ColormapData:GetKeys(cmap)
                RenderColorBar(keys, keys_off, gp.ColormapData:GetKeyCount(cmap), ImGui.GetWindowDrawList(), rect, false, false, not gp.ColormapData:IsQual(cmap))
                ImGui.Dummy(size)
            end
        end

        -----------------------------------------------------------------------
        -- Legend Utils (implot.cpp)
        -----------------------------------------------------------------------

        function internal.GetLocationPos(outer_rect, inner_size, loc, pad)
            pad = pad or ImVec2(0, 0)
            local x, y
            if ImHasFlag(loc, ImPlotLocation.West) and not ImHasFlag(loc, ImPlotLocation.East) then
                x = outer_rect.Min.x + pad.x
            elseif not ImHasFlag(loc, ImPlotLocation.West) and ImHasFlag(loc, ImPlotLocation.East) then
                x = outer_rect.Max.x - pad.x - inner_size.x
            else
                x = (outer_rect.Min.x + outer_rect.Max.x) * 0.5 - inner_size.x * 0.5
            end
            -- legend reference point y
            if ImHasFlag(loc, ImPlotLocation.North) and not ImHasFlag(loc, ImPlotLocation.South) then
                y = outer_rect.Min.y + pad.y
            elseif not ImHasFlag(loc, ImPlotLocation.North) and ImHasFlag(loc, ImPlotLocation.South) then
                y = outer_rect.Max.y - pad.y - inner_size.y
            else
                y = (outer_rect.Min.y + outer_rect.Max.y) * 0.5 - inner_size.y * 0.5
            end
            return ImVec2(floor(x + 0.5), floor(y + 0.5))
        end

        function internal.CalcLegendSize(items, pad, spacing, vertical)
            -- vars
            local nItems    = items:GetLegendCount()
            local txt_ht    = ImGui.GetTextLineHeight()
            local icon_size = txt_ht
            -- get label max width
            local max_label_width = 0
            local sum_label_width = 0
            for i = 0, nItems - 1 do
                local label_width = ImGui.CalcTextSize(items:GetLegendLabel(i), nil, true).x
                max_label_width   = max(label_width, max_label_width)
                sum_label_width  += label_width
            end
            -- calc legend size
            if vertical then
                return ImVec2(pad.x * 2 + icon_size + max_label_width, pad.y * 2 + nItems * txt_ht + (nItems - 1) * spacing.y)
            end
            return ImVec2(pad.x * 2 + icon_size * nItems + sum_label_width + (nItems - 1) * spacing.x, pad.y * 2 + txt_ht)
        end

        function internal.ClampLegendRect(legend_rect, outer_rect, pad)
            local clamped = false
            local minx, miny = outer_rect.Min.x + pad.x, outer_rect.Min.y + pad.y
            local maxx, maxy = outer_rect.Max.x - pad.x, outer_rect.Max.y - pad.y
            if legend_rect.Min.x < minx then legend_rect.Min.x = minx; clamped = true end
            if legend_rect.Min.y < miny then legend_rect.Min.y = miny; clamped = true end
            if legend_rect.Max.x > maxx then legend_rect.Max.x = maxx; clamped = true end
            if legend_rect.Max.y > maxy then legend_rect.Max.y = maxy; clamped = true end
            return clamped
        end

        local legend_indices = {} -- [Port] gp.TempInt1 (0-based legend indices, 1-based array)

        function internal.ShowLegendEntries(items, legend_bb, hovered, pad, spacing, vertical, DrawList)
            -- vars
            local txt_ht      = ImGui.GetTextLineHeight()
            local icon_size   = txt_ht
            local icon_shrink = 2
            local col_txt     = GetStyleColorU32(ImPlotCol.LegendText)
            local col_txt_dis = ImAlphaU32(col_txt, 0.25)
            -- render each legend item
            local sum_label_width = 0
            local any_item_hovered = false

            local num_items = items:GetLegendCount()
            if num_items < 1 then
                return hovered
            end
            -- build render order
            local indices = legend_indices
            table.clear(indices)
            for i = 0, num_items - 1 do indices[i + 1] = i end
            local lflags = items.Legend.Flags
            if ImHasFlag(lflags, ImPlotLegendFlags.Sort) and num_items > 1 then
                table.sort(indices, function(a, b) return items:GetLegendLabel(a) < items:GetLegendLabel(b) end)
            end
            -- render
            for i = 0, num_items - 1 do
                local idx = indices[i + 1]
                if ImHasFlag(lflags, ImPlotLegendFlags.Reverse) then idx = indices[num_items - i] end
                local item        = items:GetLegendItem(idx)
                local label       = items:GetLegendLabel(idx)
                local label_width = ImGui.CalcTextSize(label, nil, true).x
                local tlx, tly
                if vertical then
                    tlx, tly = legend_bb.Min.x + pad.x, legend_bb.Min.y + pad.y + i * (txt_ht + spacing.y)
                else
                    tlx, tly = legend_bb.Min.x + pad.x + i * (icon_size + spacing.x) + sum_label_width, legend_bb.Min.y + pad.y
                end
                sum_label_width += label_width
                local icon_bb  = G.ImRect(tlx + icon_shrink, tly + icon_shrink, tlx + icon_size - icon_shrink, tly + icon_size - icon_shrink)
                local label_bb = G.ImRect(tlx, tly, tlx + label_width + icon_size, tly + icon_size)
                local col_txt_hl
                local col_item = ImAlphaU32(item.Color, 1)

                local button_bb = G.ImRect(icon_bb.Min, label_bb.Max)

                ImGui.KeepAliveID(item.ID)

                local item_clk, item_hov, item_hld = false, false, false
                if not ImHasFlag(lflags, ImPlotLegendFlags.NoButtons) then
                    item_clk, item_hov, item_hld = ImGui.ButtonBehavior(button_bb, item.ID)
                end

                if item_clk then
                    item.Show = not item.Show
                end

                local can_hover = item_hov and (not ImHasFlag(lflags, ImPlotLegendFlags.NoHighlightItem) or not ImHasFlag(lflags, ImPlotLegendFlags.NoHighlightAxis))

                if can_hover then
                    item.LegendHoverRect.Min.x, item.LegendHoverRect.Min.y = icon_bb.Min.x, icon_bb.Min.y
                    item.LegendHoverRect.Max.x, item.LegendHoverRect.Max.y = label_bb.Max.x, label_bb.Max.y
                    item.LegendHovered = true
                    col_txt_hl = internal.ImMixU32(col_txt, col_item, 64)
                    any_item_hovered = true
                else
                    col_txt_hl = col_txt
                end
                local col_icon
                if item_hld then
                    col_icon = item.Show and ImAlphaU32(col_item, 0.5) or ImGui.GetColorU32(G.ImGuiCol.TextDisabled, 0.5)
                elseif item_hov then
                    col_icon = item.Show and ImAlphaU32(col_item, 0.75) or ImGui.GetColorU32(G.ImGuiCol.TextDisabled, 0.75)
                else
                    col_icon = item.Show and col_item or col_txt_dis
                end

                DrawList:AddRectFilled(icon_bb.Min, icon_bb.Max, col_icon)
                local text_display_end = ImGui.FindRenderedTextEnd(label)
                if text_display_end ~= 1 then
                    DrawList:AddText(nil, 0.0, ImVec2(tlx + icon_size, tly), item.Show and col_txt_hl or col_txt_dis, label, 1, text_display_end)
                end
            end
            return hovered and not any_item_hovered
        end

        function internal.ShowLegendContextMenu(legend, visible)
            local s = ImGui.GetFrameHeight()
            local ret = false
            local pressed
            pressed, visible = ImGui.Checkbox("Show", visible)
            if pressed then ret = true end
            if legend.CanGoInside then
                _, legend.Flags = ImGui.CheckboxFlags("Outside", legend.Flags, ImPlotLegendFlags.Outside)
            end
            if ImGui.RadioButtonEx("H", ImHasFlag(legend.Flags, ImPlotLegendFlags.Horizontal)) then
                legend.Flags = bor(legend.Flags, ImPlotLegendFlags.Horizontal)
            end
            ImGui.SameLine()
            if ImGui.RadioButtonEx("V", not ImHasFlag(legend.Flags, ImPlotLegendFlags.Horizontal)) then
                legend.Flags = band(legend.Flags, bnot(ImPlotLegendFlags.Horizontal))
            end
            ImGui.PushStyleVar(G.ImGuiStyleVar.ItemSpacing, ImVec2(2, 2))
            local bs = ImVec2(1.5 * s, s)
            if ImGui.Button("NW", bs) then legend.Location = ImPlotLocation.NorthWest end; ImGui.SameLine()
            if ImGui.Button("N", bs)  then legend.Location = ImPlotLocation.North     end; ImGui.SameLine()
            if ImGui.Button("NE", bs) then legend.Location = ImPlotLocation.NorthEast end
            if ImGui.Button("W", bs)  then legend.Location = ImPlotLocation.West      end; ImGui.SameLine()
            ImGui.InvisibleButton("C", bs); ImGui.SameLine()
            if ImGui.Button("E", bs)  then legend.Location = ImPlotLocation.East      end
            if ImGui.Button("SW", bs) then legend.Location = ImPlotLocation.SouthWest end; ImGui.SameLine()
            if ImGui.Button("S", bs)  then legend.Location = ImPlotLocation.South     end; ImGui.SameLine()
            if ImGui.Button("SE", bs) then legend.Location = ImPlotLocation.SouthEast end
            ImGui.PopStyleVar()
            return ret
        end

        function ImPlot.SetupLegend(location, flags)
            flags = flags or ImPlotLegendFlags.None
            local gp = GImPlot
            IM_ASSERT((gp.CurrentPlot ~= nil and not gp.CurrentPlot.SetupLocked) or (gp.CurrentSubplot ~= nil and gp.CurrentPlot == nil),
                "Setup needs to be called after BeginPlot or BeginSubplots and before any setup locking functions (e.g. PlotX)!")
            if gp.CurrentItems then
                local legend = gp.CurrentItems.Legend
                -- check and set location
                if location ~= legend.PreviousLocation then legend.Location = location end
                legend.PreviousLocation = location
                -- check and set flags
                if flags ~= legend.PreviousFlags then legend.Flags = flags end
                legend.PreviousFlags = flags
            end
        end

        -- outside legend adjustments (called from SetupFinish)
        function internal.AdjustForOutsideLegend(plot)
            local gs = GImPlot.Style
            if ImHasFlag(plot.Flags, ImPlotFlags.NoLegend) or plot.Items:GetLegendCount() <= 0 or not ImHasFlag(plot.Items.Legend.Flags, ImPlotLegendFlags.Outside) then
                return
            end
            local legend = plot.Items.Legend
            local horz = ImHasFlag(legend.Flags, ImPlotLegendFlags.Horizontal)
            local legend_size = internal.CalcLegendSize(plot.Items, gs.LegendInnerPadding, gs.LegendSpacing, not horz)
            local loc = legend.Location
            local west  = ImHasFlag(loc, ImPlotLocation.West) and not ImHasFlag(loc, ImPlotLocation.East)
            local east  = ImHasFlag(loc, ImPlotLocation.East) and not ImHasFlag(loc, ImPlotLocation.West)
            local north = ImHasFlag(loc, ImPlotLocation.North) and not ImHasFlag(loc, ImPlotLocation.South)
            local south = ImHasFlag(loc, ImPlotLocation.South) and not ImHasFlag(loc, ImPlotLocation.North)
            local cr, ar = plot.CanvasRect, plot.AxesRect
            if (west and not horz) or (west and horz and not north and not south) then
                cr.Min.x += legend_size.x + gs.LegendPadding.x
                ar.Min.x += legend_size.x + gs.PlotPadding.x
            end
            if (east and not horz) or (east and horz and not north and not south) then
                cr.Max.x -= legend_size.x + gs.LegendPadding.x
                ar.Max.x -= legend_size.x + gs.PlotPadding.x
            end
            if (north and horz) or (north and not horz and not west and not east) then
                cr.Min.y += legend_size.y + gs.LegendPadding.y
                ar.Min.y += legend_size.y + gs.PlotPadding.y
            end
            if (south and horz) or (south and not horz and not west and not east) then
                cr.Max.y -= legend_size.y + gs.LegendPadding.y
                ar.Max.y -= legend_size.y + gs.PlotPadding.y
            end
        end

        local legend_button_flags = bor(G.ImGuiButtonFlags.AllowOverlap, G.ImGuiButtonFlags.PressedOnClick, G.ImGuiButtonFlags.PressedOnDoubleClick,
                                        G.ImGuiButtonFlags.MouseButtonLeft, G.ImGuiButtonFlags.MouseButtonRight, G.ImGuiButtonFlags.MouseButtonMiddle,
                                        G.ImGuiButtonFlags.FlattenChildren)

        -- legend section of EndPlot
        function internal.RenderPlotLegend(plot, DrawList)
            local gp = GImPlot
            local gs = gp.Style
            -- reset legend hovers
            plot.Items.Legend.Hovered = false
            for i = 0, plot.Items:GetItemCount() - 1 do
                local it = plot.Items:GetItemByIndex(i)
                if it then it.LegendHovered = false end
            end
            -- render legend
            if ImHasFlag(plot.Flags, ImPlotFlags.NoLegend) or plot.Items:GetLegendCount() <= 0 then
                local r = plot.Items.Legend.Rect
                r.Min.x, r.Min.y, r.Max.x, r.Max.y = 0, 0, 0, 0
                return
            end
            local legend     = plot.Items.Legend
            local legend_out = ImHasFlag(legend.Flags, ImPlotLegendFlags.Outside)
            local legend_contextable = internal.RenderItemsLegend(plot.Items,
                legend_out and plot.FrameRect or plot.PlotRect, legend_out and gs.PlotPadding or gs.LegendPadding, ImGui.IsWindowHovered(), DrawList)

            -- main ctx menu
            if gp.OpenContextThisFrame and legend_contextable and not ImHasFlag(plot.Flags, ImPlotFlags.NoMenus) then
                ImGui.OpenPopup("##LegendContext")
            end
            if ImGui.BeginPopup("##LegendContext") then
                ImGui.Text("Legend"); ImGui.Separator()
                if internal.ShowLegendContextMenu(legend, not ImHasFlag(plot.Flags, ImPlotFlags.NoLegend)) then
                    plot.Flags = bit32.bxor(plot.Flags, ImPlotFlags.NoLegend)
                end
                ImGui.EndPopup()
            end
        end

        -- [Port] shared legend box/scroll/entries rendering of EndPlot and EndSubplots; returns legend_contextable
        function internal.RenderItemsLegend(items, outer, outer_pad, can_hover, DrawList)
            local gs = GImPlot.Style
            local IO = ImGui.GetIO()
            local legend      = items.Legend
            local legend_horz = ImHasFlag(legend.Flags, ImPlotLegendFlags.Horizontal)
            local legend_size = internal.CalcLegendSize(items, gs.LegendInnerPadding, gs.LegendSpacing, not legend_horz)
            local legend_pos  = internal.GetLocationPos(outer, legend_size, legend.Location, outer_pad)
            local lr, lc = legend.Rect, legend.RectClamped
            lr.Min.x, lr.Min.y, lr.Max.x, lr.Max.y = legend_pos.x, legend_pos.y, legend_pos.x + legend_size.x, legend_pos.y + legend_size.y
            lc.Min.x, lc.Min.y, lc.Max.x, lc.Max.y = lr.Min.x, lr.Min.y, lr.Max.x, lr.Max.y
            local legend_scrollable = internal.ClampLegendRect(lc, outer, outer_pad)
            ImGui.KeepAliveID(items.ID)
            _, legend.Hovered, legend.Held = ImGui.ButtonBehavior(lc, items.ID, legend_button_flags)
            legend.Hovered = legend.Hovered or (can_hover and lc:Contains(IO.MousePos))

            if legend_scrollable then
                if legend.Hovered then
                    ImGui.SetKeyOwner(G.ImGuiKey.MouseWheelY, items.ID)
                    if IO.MouseWheel ~= 0.0 then
                        local max_step_x = (lr.Max.x - lr.Min.x) * 0.67
                        local font_size = ImGui.GetCurrentWindow().FontRefSize or ImGui.GetFontSize()
                        local scroll_step = floor(min(2 * font_size, max_step_x))
                        legend.Scroll.x += scroll_step * IO.MouseWheel
                        legend.Scroll.y += scroll_step * IO.MouseWheel
                    end
                end
                local min_sx = (lc.Max.x - lc.Min.x) - (lr.Max.x - lr.Min.x)
                local min_sy = (lc.Max.y - lc.Min.y) - (lr.Max.y - lr.Min.y)
                legend.Scroll.x = G.ImClamp(legend.Scroll.x, min_sx, 0.0)
                legend.Scroll.y = G.ImClamp(legend.Scroll.y, min_sy, 0.0)
                local ox = lc.Min.x - lr.Min.x + (legend_horz and legend.Scroll.x or 0)
                local oy = lc.Min.y - lr.Min.y + (legend_horz and 0 or legend.Scroll.y)
                lr.Min.x += ox; lr.Min.y += oy; lr.Max.x += ox; lr.Max.y += oy
            else
                legend.Scroll.x, legend.Scroll.y = 0, 0
            end

            local col_bg = GetStyleColorU32(ImPlotCol.LegendBg)
            local col_bd = GetStyleColorU32(ImPlotCol.LegendBorder)
            ImGui.PushClipRect(lc.Min, lc.Max, true)
            DrawList:AddRectFilled(lc.Min, lc.Max, col_bg)
            local legend_contextable = internal.ShowLegendEntries(items, lr, legend.Hovered, gs.LegendInnerPadding, gs.LegendSpacing, not legend_horz, DrawList)
                                       and not ImHasFlag(legend.Flags, ImPlotLegendFlags.NoMenus)
            DrawList:AddRect(lc.Min, lc.Max, col_bd)
            ImGui.PopClipRect()
            return legend_contextable
        end

        -- Legend Utils and Tools

        function ImPlot.BeginLegendPopup(label_id, mouse_button)
            if mouse_button == nil then mouse_button = G.ImGuiMouseButton.Right end
            local gp = GImPlot
            IM_ASSERT(gp.CurrentItems ~= nil, "BeginLegendPopup() needs to be called within an itemized context!")
            internal.SetupLock()
            if ImGui.GetCurrentWindow().SkipItems then
                return false
            end
            local id = gp.CurrentItems:GetItemID(label_id)
            if ImGui.IsMouseReleased(mouse_button) then
                local item = gp.CurrentItems:GetItem(id)
                if item and item.LegendHovered then
                    ImGui.OpenPopupEx(id)
                end
            end
            return ImGui.BeginPopupEx(id, bor(G.ImGuiWindowFlags.AlwaysAutoResize, G.ImGuiWindowFlags.NoTitleBar, G.ImGuiWindowFlags.NoSavedSettings))
        end

        function ImPlot.EndLegendPopup()
            internal.SetupLock()
            ImGui.EndPopup()
        end
    end


    --------------------------------------------------------------------------
    -- [SECTION] Plot Tools
    -- [Port] double* / bool* args: scalars are passed by value and returned, following the core
    --        (ImGui.DragFloat returns (v, changed)). Drag tools return the new values first, then
    --        modified, clicked, hovered, held (replacing out_clicked/out_hovered/out_held).
    --        DragRect(id, ImPlotRect, ...) edits the ImPlotRect in place (struct pointer).
    -- [Port] Printf-style overloads: pass a format string + varargs where upstream takes fmt, ...
    --------------------------------------------------------------------------
    do
        local ImPlotCol = ImPlot.ImPlotCol
        local ImPlotDragToolFlags = ImPlot.ImPlotDragToolFlags
        local IMPLOT_AUTO = ImPlot.IMPLOT_AUTO
        local ImHasFlag = internal.ImHasFlag
        local GetStyleColorU32 = internal.GetStyleColorU32
        local ImRect = G.ImRect
        local ImGuiMouseCursor = G.ImGuiMouseCursor

        local function ImGuiFormat(fmt, ...)
            if select("#", ...) == 0 then return fmt end
            return string.format(fmt, ...)
        end

        local function ResolveColor(col)
            if col == nil or internal.IsColorAuto(col) then
                return ImGui.GetStyleColorVec4(ImGuiCol.Text)
            end
            return col
        end

        local function FitThisFrame()
            return GImPlot.CurrentPlot.FitThisFrame
        end

        local function FitPoint(x, y)
            local plot = GImPlot.CurrentPlot
            local x_axis, y_axis = plot.Axes[plot.CurrentX], plot.Axes[plot.CurrentY]
            x_axis:ExtendFitWith(y_axis, x, y)
            y_axis:ExtendFitWith(x_axis, y, x)
        end
        -- [Port] FitPoint(ImPlotPoint) -> FitPoint(x, y)
        internal.FitThisFrame, internal.FitPoint = FitThisFrame, FitPoint

        function ImPlot.GetPlotMousePos(x_idx, y_idx)
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "GetPlotMousePos() needs to be called between BeginPlot() and EndPlot()!")
            return ImPlot.PixelsToPlot(ImGui.GetIO().MousePos, x_idx, y_idx)
        end

        -- Annotation(x, y, col, offset, clamp, round = false)
        -- Annotation(x, y, col, offset, clamp, fmt, ...)
        function ImPlot.Annotation(x, y, col, offset, clamp, fmt, ...)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "Annotation() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()
            local txt
            if type(fmt) == "string" then
                txt = ImGuiFormat(fmt, ...)
            else
                local x_axis = gp.CurrentPlot.Axes[gp.CurrentPlot.CurrentX]
                local y_axis = gp.CurrentPlot.Axes[gp.CurrentPlot.CurrentY]
                txt = internal.LabelAxisValue(x_axis, x, fmt == true) .. ", " .. internal.LabelAxisValue(y_axis, y, fmt == true)
            end
            local pos = ImPlot.PlotToPixels(x, y, IMPLOT_AUTO, IMPLOT_AUTO)
            local bg = ImGui.GetColorU32(col)
            local fg
            if col.w == 0 then fg = GetStyleColorU32(ImPlotCol.InlayText) else fg = internal.CalcTextColor(col) end
            table.insert(gp.Annotations, { Pos = pos, Offset = ImVec2(offset.x, offset.y), ColorBg = bg, ColorFg = fg, Clamp = clamp or false, Text = txt })
        end

        -- Tag(axis, v, col, round = false) / Tag(axis, v, col, fmt, ...)
        function internal.Tag(axis, v, col, fmt, ...)
            local gp = GImPlot
            internal.SetupLock()
            local txt
            if type(fmt) == "string" then
                txt = ImGuiFormat(fmt, ...)
            else
                txt = internal.LabelAxisValue(gp.CurrentPlot.Axes[axis], v, fmt == true)
            end
            local bg = ImGui.GetColorU32(col)
            local fg
            if col.w == 0 then fg = GetStyleColorU32(ImPlotCol.AxisText) else fg = internal.CalcTextColor(col) end
            table.insert(gp.Tags, { Axis = axis, Value = v, ColorBg = bg, ColorFg = fg, Text = txt })
        end

        function ImPlot.TagX(x, color, fmt, ...)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "TagX() needs to be called between BeginPlot() and EndPlot()!")
            internal.Tag(gp.CurrentPlot.CurrentX, x, color, fmt, ...)
        end

        function ImPlot.TagY(y, color, fmt, ...)
            local gp = GImPlot
            IM_ASSERT(gp.CurrentPlot ~= nil, "TagY() needs to be called between BeginPlot() and EndPlot()!")
            internal.Tag(gp.CurrentPlot.CurrentY, y, color, fmt, ...)
        end

        local DRAG_GRAB_HALF_SIZE = 4.0

        -- DragPoint(id, x, y, col, size = 4, flags = 0) -> x, y, modified, clicked, hovered, held
        function ImPlot.DragPoint(n_id, x, y, col, radius, flags)
            radius = radius or 4
            flags = flags or 0
            ImGui.PushID("#IMPLOT_DRAG_POINT")
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "DragPoint() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()

            if not ImHasFlag(flags, ImPlotDragToolFlags.NoFit) and FitThisFrame() then
                FitPoint(x, y)
            end

            local input = not ImHasFlag(flags, ImPlotDragToolFlags.NoInputs)
            local show_curs = not ImHasFlag(flags, ImPlotDragToolFlags.NoCursors)
            local no_delay = not ImHasFlag(flags, ImPlotDragToolFlags.Delayed)
            local grab_half_size = math.max(DRAG_GRAB_HALF_SIZE, radius)
            local col32 = ImGui.ColorConvertFloat4ToU32(ResolveColor(col))

            local pos = ImPlot.PlotToPixels(x, y, IMPLOT_AUTO, IMPLOT_AUTO)
            local id = ImGui.GetCurrentWindow():GetID(n_id)
            local rect = ImRect(pos.x - grab_half_size, pos.y - grab_half_size, pos.x + grab_half_size, pos.y + grab_half_size)
            local clicked, hovered, held = false, false, false

            ImGui.KeepAliveID(id)
            if input then
                clicked, hovered, held = ImGui.ButtonBehavior(rect, id)
            end

            local modified = false
            if held and ImGui.IsMouseDragging(0) then
                local mp = ImPlot.GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO)
                x = mp.x
                y = mp.y
                modified = true
            end

            internal.PushPlotClipRect()
            local DrawList = internal.GetPlotDrawList()
            if (hovered or held) and show_curs then
                ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
            end
            if modified and no_delay then
                pos = ImPlot.PlotToPixels(x, y, IMPLOT_AUTO, IMPLOT_AUTO)
            end
            DrawList:AddCircleFilled(pos, radius, col32)
            internal.PopPlotClipRect()

            ImGui.PopID()
            return x, y, modified, clicked, hovered, held
        end

        -- [Port] DragLineX/DragLineY share one body (is_y selects DragLineY)
        local function DragLine(n_id, value, col, thickness, flags, is_y)
            thickness = thickness or 1
            flags = flags or 0
            local gp = GImPlot
            local plot = gp.CurrentPlot
            local pr = plot.PlotRect

            if not ImHasFlag(flags, ImPlotDragToolFlags.NoFit) and FitThisFrame() then
                if is_y then
                    plot.Axes[plot.CurrentY]:ExtendFit(value) -- FitPointY
                else
                    plot.Axes[plot.CurrentX]:ExtendFit(value) -- FitPointX
                end
            end

            local input = not ImHasFlag(flags, ImPlotDragToolFlags.NoInputs)
            local show_curs = not ImHasFlag(flags, ImPlotDragToolFlags.NoCursors)
            local no_delay = not ImHasFlag(flags, ImPlotDragToolFlags.Delayed)
            local grab_half_size = math.max(DRAG_GRAB_HALF_SIZE, thickness / 2)
            local function ToPix(v)
                if is_y then
                    return math.floor(ImPlot.PlotToPixels(0, v, IMPLOT_AUTO, IMPLOT_AUTO).y + 0.5)
                end
                return math.floor(ImPlot.PlotToPixels(v, 0, IMPLOT_AUTO, IMPLOT_AUTO).x + 0.5)
            end
            local p = ToPix(value)
            local id = ImGui.GetCurrentWindow():GetID(n_id)
            local rect
            if is_y then
                rect = ImRect(pr.Min.x, p - grab_half_size, pr.Max.x, p + grab_half_size)
            else
                rect = ImRect(p - grab_half_size, pr.Min.y, p + grab_half_size, pr.Max.y)
            end
            local clicked, hovered, held = false, false, false

            ImGui.KeepAliveID(id)
            if input then
                clicked, hovered, held = ImGui.ButtonBehavior(rect, id)
            end

            if (hovered or held) and show_curs then
                if is_y then
                    ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeNS)
                else
                    ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
                end
            end

            local col32 = ImGui.ColorConvertFloat4ToU32(ResolveColor(col))

            local modified = false
            if held and ImGui.IsMouseDragging(0) then
                local mp = ImPlot.GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO)
                if is_y then value = mp.y else value = mp.x end
                modified = true
            end

            internal.PushPlotClipRect()
            local DrawList = internal.GetPlotDrawList()
            if modified and no_delay then
                p = ToPix(value)
            end
            if is_y then
                local len = gp.Style.MajorTickLen.y
                local xl, xr = pr.Min.x, pr.Max.x
                internal.AddLineH(DrawList, xl, xr, p, col32, thickness)
                internal.AddLineH(DrawList, xl, xl + len, p, col32, 3 * thickness)
                internal.AddLineH(DrawList, xr, xr - len, p, col32, 3 * thickness)
            else
                local len = gp.Style.MajorTickLen.x
                local yt, yb = pr.Min.y, pr.Max.y
                internal.AddLineV(DrawList, p, yt, yb, col32, thickness)
                internal.AddLineV(DrawList, p, yt, yt + len, col32, 3 * thickness)
                internal.AddLineV(DrawList, p, yb, yb - len, col32, 3 * thickness)
            end
            internal.PopPlotClipRect()

            return value, modified, clicked, hovered, held
        end

        -- DragLineX(id, x, col, thickness = 1, flags = 0) -> x, modified, clicked, hovered, held
        function ImPlot.DragLineX(n_id, value, col, thickness, flags)
            -- ImGui::PushID("#IMPLOT_DRAG_LINE_X");
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "DragLineX() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()
            -- ImGui::PopID();
            return DragLine(n_id, value, col, thickness, flags, false)
        end

        -- DragLineY(id, y, col, thickness = 1, flags = 0) -> y, modified, clicked, hovered, held
        function ImPlot.DragLineY(n_id, value, col, thickness, flags)
            ImGui.PushID("#IMPLOT_DRAG_LINE_Y")
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "DragLineY() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()
            local v, modified, clicked, hovered, held = DragLine(n_id, value, col, thickness, flags, true)
            ImGui.PopID()
            return v, modified, clicked, hovered, held
        end

        -- DragRect(id, x_min, y_min, x_max, y_max, col, flags = 0) -> x_min, y_min, x_max, y_max, modified, clicked, hovered, held
        -- DragRect(id, ImPlotRect bounds, col, flags = 0) -> modified, clicked, hovered, held (bounds edited in place)
        function ImPlot.DragRect(n_id, x_min, y_min, x_max, y_max, col, flags)
            if type(x_min) == "table" then
                local bounds = x_min
                local m, c, h, hd
                bounds.X.Min, bounds.Y.Min, bounds.X.Max, bounds.Y.Max, m, c, h, hd =
                    ImPlot.DragRect(n_id, bounds.X.Min, bounds.Y.Min, bounds.X.Max, bounds.Y.Max, y_min, x_max)
                return m, c, h, hd
            end
            flags = flags or 0
            ImGui.PushID("#IMPLOT_DRAG_RECT")
            IM_ASSERT(GImPlot.CurrentPlot ~= nil, "DragRect() needs to be called between BeginPlot() and EndPlot()!")
            internal.SetupLock()

            if not ImHasFlag(flags, ImPlotDragToolFlags.NoFit) and FitThisFrame() then
                FitPoint(x_min, y_min)
                FitPoint(x_max, y_max)
            end

            local input = not ImHasFlag(flags, ImPlotDragToolFlags.NoInputs)
            local show_curs = not ImHasFlag(flags, ImPlotDragToolFlags.NoCursors)
            local no_delay = not ImHasFlag(flags, ImPlotDragToolFlags.Delayed)
            local h = { true, false, true, false }
            -- [Port] double* x[]/y[] -> index maps into v = { x_min, y_min, x_max, y_max }
            local v = { x_min, y_min, x_max, y_max }
            local xi = { 1, 3, 3, 1 }
            local yi = { 2, 2, 4, 4 }
            local p = {}
            for i = 1, 4 do
                p[i] = ImPlot.PlotToPixels(v[xi[i]], v[yi[i]], IMPLOT_AUTO, IMPLOT_AUTO)
            end
            local pc = ImPlot.PlotToPixels((v[1] + v[3]) / 2, (v[2] + v[4]) / 2, IMPLOT_AUTO, IMPLOT_AUTO)
            local rect = ImRect(math.min(p[1].x, p[3].x), math.min(p[1].y, p[3].y), math.max(p[1].x, p[3].x), math.max(p[1].y, p[3].y))
            local rect_grab = ImRect(rect.Min.x - DRAG_GRAB_HALF_SIZE, rect.Min.y - DRAG_GRAB_HALF_SIZE, rect.Max.x + DRAG_GRAB_HALF_SIZE, rect.Max.y + DRAG_GRAB_HALF_SIZE)

            local cur = {}
            if show_curs then
                local NWSE, NESW = ImGuiMouseCursor.ResizeNWSE, ImGuiMouseCursor.ResizeNESW
                if (rect.Min.x == p[1].x and rect.Min.y == p[1].y) or (rect.Max.x == p[1].x and rect.Max.y == p[1].y) then
                    cur[1] = NWSE
                else
                    cur[1] = NESW
                end
                for i = 2, 4 do
                    if cur[i - 1] == NWSE then cur[i] = NESW else cur[i] = NWSE end
                end
            end

            local color = ResolveColor(col)
            local col32 = ImGui.ColorConvertFloat4ToU32(color)
            local col32_a = ImGui.ColorConvertFloat4ToU32(ImVec4(color.x, color.y, color.z, color.w * 0.25))
            local id = ImGui.GetCurrentWindow():GetID(n_id)

            local modified = false
            local clicked, hovered, held = false, false, false
            local out_clicked, out_hovered, out_held = false, false, false

            local is_movable = x_min ~= x_max or y_min ~= y_max
            if is_movable then
                ImGui.KeepAliveID(id)
                if input then
                    -- middle point
                    local b_rect = ImRect(pc.x - DRAG_GRAB_HALF_SIZE, pc.y - DRAG_GRAB_HALF_SIZE, pc.x + DRAG_GRAB_HALF_SIZE, pc.y + DRAG_GRAB_HALF_SIZE)
                    clicked, hovered, held = ImGui.ButtonBehavior(b_rect, id)
                    out_clicked, out_hovered, out_held = clicked, hovered, held
                end

                if (hovered or held) and show_curs then
                    ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeAll)
                end
                if held and ImGui.IsMouseDragging(0) then
                    local delta = ImGui.GetIO().MouseDelta
                    for i = 1, 4 do
                        local pp = ImPlot.PixelsToPlot(p[i].x + delta.x, p[i].y + delta.y, IMPLOT_AUTO, IMPLOT_AUTO)
                        v[yi[i]] = pp.y
                        v[xi[i]] = pp.x
                    end
                    modified = true
                end
            end

            for i = 1, 4 do
                -- points
                local b_rect = ImRect(p[i].x - DRAG_GRAB_HALF_SIZE, p[i].y - DRAG_GRAB_HALF_SIZE, p[i].x + DRAG_GRAB_HALF_SIZE, p[i].y + DRAG_GRAB_HALF_SIZE)
                local p_id = (id + i) % 0x100000000
                ImGui.KeepAliveID(p_id)
                if input then
                    clicked, hovered, held = ImGui.ButtonBehavior(b_rect, p_id)
                    out_clicked = out_clicked or clicked
                    out_hovered = out_hovered or hovered
                    out_held    = out_held or held
                end
                if (hovered or held) and show_curs then
                    ImGui.SetMouseCursor(cur[i])
                end

                if held and ImGui.IsMouseDragging(0) then
                    local mp = ImPlot.GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO)
                    v[xi[i]] = mp.x
                    v[yi[i]] = mp.y
                    modified = true
                end

                -- edges
                local q = p[i % 4 + 1]
                local e_min_x, e_min_y = math.min(p[i].x, q.x), math.min(p[i].y, q.y)
                local e_max_x, e_max_y = math.max(p[i].x, q.x), math.max(p[i].y, q.y)
                if h[i] then
                    b_rect = ImRect(e_min_x + DRAG_GRAB_HALF_SIZE, e_min_y - DRAG_GRAB_HALF_SIZE, e_max_x - DRAG_GRAB_HALF_SIZE, e_max_y + DRAG_GRAB_HALF_SIZE)
                else
                    b_rect = ImRect(e_min_x - DRAG_GRAB_HALF_SIZE, e_min_y + DRAG_GRAB_HALF_SIZE, e_max_x + DRAG_GRAB_HALF_SIZE, e_max_y - DRAG_GRAB_HALF_SIZE)
                end
                local e_id = (id + i + 4) % 0x100000000
                ImGui.KeepAliveID(e_id)
                if input then
                    clicked, hovered, held = ImGui.ButtonBehavior(b_rect, e_id)
                    out_clicked = out_clicked or clicked
                    out_hovered = out_hovered or hovered
                    out_held    = out_held or held
                end
                if (hovered or held) and show_curs then
                    if h[i] then
                        ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeNS)
                    else
                        ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
                    end
                end
                if held and ImGui.IsMouseDragging(0) then
                    local mp = ImPlot.GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO)
                    if h[i] then
                        v[yi[i]] = mp.y
                    else
                        v[xi[i]] = mp.x
                    end
                    modified = true
                end
                if hovered and ImGui.IsMouseDoubleClicked(0) then
                    local b = ImPlot.GetPlotLimits(IMPLOT_AUTO, IMPLOT_AUTO)
                    if h[i] then
                        local k = yi[i]
                        if (k == 2 and v[2] < v[4]) or (k == 4 and v[4] < v[2]) then v[k] = b.Y.Min else v[k] = b.Y.Max end
                    else
                        local k = xi[i]
                        if (k == 1 and v[1] < v[3]) or (k == 3 and v[3] < v[1]) then v[k] = b.X.Min else v[k] = b.X.Max end
                    end
                    modified = true
                end
            end

            local mouse_inside = rect_grab:Contains(ImGui.GetMousePos())
            local mouse_clicked = ImGui.IsMouseClicked(0)
            local mouse_down = ImGui.IsMouseDown(0)
            if input and mouse_inside then
                out_clicked = out_clicked or mouse_clicked
                out_hovered = true
                out_held    = out_held or mouse_down
            end

            internal.PushPlotClipRect()
            local DrawList = internal.GetPlotDrawList()
            if modified and no_delay then
                for i = 1, 4 do
                    p[i] = ImPlot.PlotToPixels(v[xi[i]], v[yi[i]], IMPLOT_AUTO, IMPLOT_AUTO)
                end
                pc = ImPlot.PlotToPixels((v[1] + v[3]) / 2, (v[2] + v[4]) / 2, IMPLOT_AUTO, IMPLOT_AUTO)
                rect = ImRect(math.min(p[1].x, p[3].x), math.min(p[1].y, p[3].y), math.max(p[1].x, p[3].x), math.max(p[1].y, p[3].y))
            end
            DrawList:AddRectFilled(rect.Min, rect.Max, col32_a)
            DrawList:AddRect(rect.Min, rect.Max, col32)
            if input and (modified or mouse_inside) then
                DrawList:AddCircleFilled(pc, DRAG_GRAB_HALF_SIZE, col32)
                for i = 1, 4 do
                    DrawList:AddCircleFilled(p[i], DRAG_GRAB_HALF_SIZE, col32)
                end
            end
            internal.PopPlotClipRect()
            ImGui.PopID()
            return v[1], v[2], v[3], v[4], modified, out_clicked, out_hovered, out_held
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Subplots, Aligned Plots, Drag and Drop Utils
    -- [Port] BeginSubplots row_sizes/col_sizes: optional plain arrays (1-based), updated in place
    --------------------------------------------------------------------------
    do
        local ImAxis = ImPlot.ImAxis
        local ImPlotSubplotFlags = ImPlot.ImPlotSubplotFlags
        local ImPlotLegendFlags = ImPlot.ImPlotLegendFlags
        local ImPlotLocation = ImPlot.ImPlotLocation
        local ImHasFlag = internal.ImHasFlag
        local GetStyleColorU32 = internal.GetStyleColorU32
        local ImRect = G.ImRect
        local bor = bit32.bor

        local SUBPLOT_BORDER_SIZE             = 1.0
        local SUBPLOT_SPLITTER_HALF_THICKNESS = 4.0
        local SUBPLOT_SPLITTER_FEEDBACK_TIMER = 0.06

        local function IM_ROUND(v) return math.floor(v + 0.5) end

        local AlignMT = {}
        AlignMT.__index = AlignMT
        function internal.ImPlotAlignmentData()
            return setmetatable({ Vertical = true, PadA = 0, PadB = 0, PadAMax = 0, PadBMax = 0 }, AlignMT)
        end
        function AlignMT:Begin() self.PadAMax = 0; self.PadBMax = 0 end
        -- [Port] returns (pad_a, pad_b, delta_a, delta_b) instead of writing through references
        function AlignMT:Update(pad_a, pad_b)
            local bak_a, bak_b = pad_a, pad_b
            local delta_a, delta_b = 0, 0
            if self.PadAMax < pad_a then self.PadAMax = pad_a end
            if self.PadBMax < pad_b then self.PadBMax = pad_b end
            if pad_a < self.PadA then pad_a = self.PadA; delta_a = pad_a - bak_a end
            if pad_b < self.PadB then pad_b = self.PadB; delta_b = pad_b - bak_b end
            return pad_a, pad_b, delta_a, delta_b
        end
        function AlignMT:End() self.PadA = self.PadAMax; self.PadB = self.PadBMax end
        function AlignMT:Reset() self.PadA = 0; self.PadB = 0; self.PadAMax = 0; self.PadBMax = 0 end

        -- [Port] Row/ColLinkData entries are { Min = ref, Max = ref } link refs (see SetNextAxisLinks)
        function internal.ImPlotSubplot()
            local items = internal.ImPlotItemGroup()
            items.Legend.Location    = ImPlotLocation.North
            items.Legend.Flags       = bor(ImPlotLegendFlags.Horizontal, ImPlotLegendFlags.Outside)
            items.Legend.CanGoInside = false
            return {
                ID = 0, Flags = ImPlotSubplotFlags.None, PreviousFlags = ImPlotSubplotFlags.None,
                Items = items, Rows = 0, Cols = 0, CurrentIdx = 0,
                FrameRect = ImRect(), GridRect = ImRect(), CellSize = ImVec2(0, 0),
                RowAlignmentData = {}, ColAlignmentData = {}, RowRatios = {}, ColRatios = {},
                RowLinkData = {}, ColLinkData = {}, -- [Port] all 1-based arrays
                TempSizes = { 0, 0 }, FrameHovered = false, HasTitle = false,
            }
        end

        function internal.SubplotSetCell(row, col)
            local gp = GImPlot
            local subplot = gp.CurrentSubplot
            if row >= subplot.Rows or col >= subplot.Cols then
                return
            end
            local xoff, yoff = 0, 0
            for c = 1, col do xoff += subplot.ColRatios[c] end
            for r = 1, row do yoff += subplot.RowRatios[r] end
            local gr = subplot.GridRect
            local cp = ImGui.GetCurrentWindow().DC.CursorPos
            cp.x = IM_ROUND(gr.Min.x + xoff * gr:GetWidth())
            cp.y = IM_ROUND(gr.Min.y + yoff * gr:GetHeight())
            -- set cell size
            subplot.CellSize.x = IM_ROUND(gr:GetWidth() * subplot.ColRatios[col + 1])
            subplot.CellSize.y = IM_ROUND(gr:GetHeight() * subplot.RowRatios[row + 1])
            -- setup links
            local lx = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.LinkAllX)
            local ly = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.LinkAllY)
            local lr = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.LinkRows)
            local lc = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.LinkCols)
            local xl = (lx and subplot.ColLinkData[1]) or (lc and subplot.ColLinkData[col + 1]) or nil
            local yl = (ly and subplot.RowLinkData[1]) or (lr and subplot.RowLinkData[row + 1]) or nil
            ImPlot.SetNextAxisLinks(ImAxis.X1, xl and xl.Min, xl and xl.Max)
            ImPlot.SetNextAxisLinks(ImAxis.Y1, yl and yl.Min, yl and yl.Max)
            -- setup alignment
            if not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoAlign) then
                gp.CurrentAlignmentH = subplot.RowAlignmentData[row + 1]
                gp.CurrentAlignmentV = subplot.ColAlignmentData[col + 1]
            end
            -- set idx
            if ImHasFlag(subplot.Flags, ImPlotSubplotFlags.ColMajor) then
                subplot.CurrentIdx = col * subplot.Rows + row
            else
                subplot.CurrentIdx = row * subplot.Cols + col
            end
        end

        function internal.SubplotSetCellIdx(idx)
            local subplot = GImPlot.CurrentSubplot
            if idx >= subplot.Rows * subplot.Cols then
                return
            end
            if ImHasFlag(subplot.Flags, ImPlotSubplotFlags.ColMajor) then
                internal.SubplotSetCell(idx % subplot.Rows, idx // subplot.Rows)
            else
                internal.SubplotSetCell(idx // subplot.Cols, idx % subplot.Cols)
            end
        end

        function internal.SubplotNextCell()
            local subplot = GImPlot.CurrentSubplot
            subplot.CurrentIdx += 1
            internal.SubplotSetCellIdx(subplot.CurrentIdx)
        end

        local function RenderSplitter(subplot, sep_bb, sep_id, ratios, i, vertical, line_pos, hov_col, act_col, DrawList)
            local g = ImGui.GetCurrentContext()
            ImGui.KeepAliveID(sep_id)
            local sep_clk, sep_hov, sep_hld = ImGui.ButtonBehavior(sep_bb, sep_id,
                bor(G.ImGuiButtonFlags.FlattenChildren, G.ImGuiButtonFlags.PressedOnClick, G.ImGuiButtonFlags.PressedOnDoubleClick))
            if (sep_hov and g.HoveredIdTimer > SUBPLOT_SPLITTER_FEEDBACK_TIMER) or sep_hld then
                if sep_clk and ImGui.IsMouseDoubleClicked(0) then
                    local p = (ratios[i] + ratios[i + 1]) / 2
                    ratios[i], ratios[i + 1] = p, p
                end
                if sep_clk then
                    subplot.TempSizes[1] = ratios[i]
                    subplot.TempSizes[2] = ratios[i + 1]
                end
                if sep_hld then
                    local dp
                    if vertical then
                        dp = ImGui.GetMouseDragDelta(0).y / subplot.GridRect:GetHeight()
                    else
                        dp = ImGui.GetMouseDragDelta(0).x / subplot.GridRect:GetWidth()
                    end
                    if subplot.TempSizes[1] + dp > 0.1 and subplot.TempSizes[2] - dp > 0.1 then
                        ratios[i]     = subplot.TempSizes[1] + dp
                        ratios[i + 1] = subplot.TempSizes[2] - dp
                    end
                end
                local gr = subplot.GridRect
                if vertical then
                    internal.AddLineH(DrawList, IM_ROUND(gr.Min.x), IM_ROUND(gr.Max.x), IM_ROUND(line_pos), sep_hld and act_col or hov_col, SUBPLOT_BORDER_SIZE)
                    ImGui.SetMouseCursor(G.ImGuiMouseCursor.ResizeNS)
                else
                    internal.AddLineV(DrawList, IM_ROUND(line_pos), IM_ROUND(gr.Min.y), IM_ROUND(gr.Max.y), sep_hld and act_col or hov_col, SUBPLOT_BORDER_SIZE)
                    ImGui.SetMouseCursor(G.ImGuiMouseCursor.ResizeEW)
                end
            end
        end

        function ImPlot.BeginSubplots(title, rows, cols, size, flags, row_sizes, col_sizes)
            if flags == nil then flags = ImPlotSubplotFlags.None end
            IM_ASSERT(rows > 0 and cols > 0, "Invalid sizing arguments!")
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentSubplot == nil, "Mismatched BeginSubplots()/EndSubplots()!")
            local Window = ImGui.GetCurrentWindow()
            if Window.SkipItems then
                return false
            end
            local ID = Window:GetID(title)
            local just_created = gp.Subplots:GetByKey(ID) == nil
            gp.CurrentSubplot = gp.Subplots:GetOrAddByKey(ID)
            local subplot = gp.CurrentSubplot
            subplot.ID       = ID
            subplot.Items.ID = ID - 1
            subplot.HasTitle = ImGui.FindRenderedTextEnd(title) ~= 1
            -- push ID
            ImGui.PushID(ID)

            if just_created or flags ~= subplot.PreviousFlags then
                subplot.Flags = flags
            end
            subplot.PreviousFlags = flags

            -- check for change in rows and cols
            if subplot.Rows ~= rows or subplot.Cols ~= cols then
                table.clear(subplot.RowAlignmentData); table.clear(subplot.RowLinkData); table.clear(subplot.RowRatios)
                for r = 1, rows do
                    subplot.RowAlignmentData[r] = internal.ImPlotAlignmentData()
                    subplot.RowLinkData[r] = { Min = { 0 }, Max = { 1 } }
                    subplot.RowRatios[r] = 1.0 / rows
                end
                table.clear(subplot.ColAlignmentData); table.clear(subplot.ColLinkData); table.clear(subplot.ColRatios)
                for c = 1, cols do
                    subplot.ColAlignmentData[c] = internal.ImPlotAlignmentData()
                    subplot.ColLinkData[c] = { Min = { 0 }, Max = { 1 } }
                    subplot.ColRatios[c] = 1.0 / cols
                end
            end
            -- check incoming size requests
            local row_sum, col_sum = 0, 0
            if row_sizes ~= nil then
                for r = 1, rows do row_sum += row_sizes[r] end
                for r = 1, rows do subplot.RowRatios[r] = row_sizes[r] / row_sum end
            end
            if col_sizes ~= nil then
                for c = 1, cols do col_sum += col_sizes[c] end
                for c = 1, cols do subplot.ColRatios[c] = col_sizes[c] / col_sum end
            end
            subplot.Rows = rows
            subplot.Cols = cols

            -- calc plot frame sizes
            local gs = gp.Style
            local title_size = ImVec2(0, 0)
            if not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoTitle) then
                title_size = ImGui.CalcTextSize(title, nil, true)
            end
            local pad_top = title_size.x > 0 and (title_size.y + gs.LabelPadding.y) or 0
            local half_pad = ImVec2(gs.PlotPadding.x / 2, gs.PlotPadding.y / 2)
            local frame_size = ImGui.CalcItemSize(size or ImVec2(-1, 0), gs.PlotDefaultSize.x, gs.PlotDefaultSize.y)
            local cp = Window.DC.CursorPos
            local fr, gr = subplot.FrameRect, subplot.GridRect
            fr.Min.x, fr.Min.y, fr.Max.x, fr.Max.y = cp.x, cp.y, cp.x + frame_size.x, cp.y + frame_size.y
            gr.Min.x, gr.Min.y = fr.Min.x + half_pad.x, fr.Min.y + half_pad.y + pad_top
            gr.Max.x, gr.Max.y = fr.Max.x - half_pad.x, fr.Max.y - half_pad.y
            subplot.FrameHovered = fr:Contains(ImGui.GetMousePos())
                and ImGui.IsWindowHovered(bor(G.ImGuiHoveredFlags.ChildWindows, G.ImGuiHoveredFlags.AllowWhenBlockedByActiveItem))

            -- outside legend adjustments (TODO: make function)
            local share_items = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.ShareItems)
            if share_items then
                gp.CurrentItems = subplot.Items
            end
            if share_items and not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoLegend) and subplot.Items:GetLegendCount() > 0 then
                local legend = subplot.Items.Legend
                local horz = ImHasFlag(legend.Flags, ImPlotLegendFlags.Horizontal)
                local legend_size = internal.CalcLegendSize(subplot.Items, gs.LegendInnerPadding, gs.LegendSpacing, not horz)
                local loc = legend.Location
                local west  = ImHasFlag(loc, ImPlotLocation.West) and not ImHasFlag(loc, ImPlotLocation.East)
                local east  = ImHasFlag(loc, ImPlotLocation.East) and not ImHasFlag(loc, ImPlotLocation.West)
                local north = ImHasFlag(loc, ImPlotLocation.North) and not ImHasFlag(loc, ImPlotLocation.South)
                local south = ImHasFlag(loc, ImPlotLocation.South) and not ImHasFlag(loc, ImPlotLocation.North)
                if (west and not horz) or (west and horz and not north and not south) then gr.Min.x += legend_size.x + gs.LegendPadding.x end
                if (east and not horz) or (east and horz and not north and not south) then gr.Max.x -= legend_size.x + gs.LegendPadding.x end
                if (north and horz) or (north and not horz and not west and not east) then gr.Min.y += legend_size.y + gs.LegendPadding.y end
                if (south and horz) or (south and not horz and not west and not east) then gr.Max.y -= legend_size.y + gs.LegendPadding.y end
            end

            -- render single background frame
            ImGui.RenderFrame(fr.Min, fr.Max, GetStyleColorU32(ImPlot.ImPlotCol.FrameBg), true, ImGui.GetStyle().FrameRounding)
            -- render title
            if title_size.x > 0 and not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoTitle) then
                local col = GetStyleColorU32(ImPlot.ImPlotCol.TitleText)
                internal.AddTextCentered(ImGui.GetWindowDrawList(), ImVec2(gr:GetCenter().x, gr.Min.y - pad_top + half_pad.y), col, title)
            end

            -- render splitters
            if not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoResize) then
                local DrawList = ImGui.GetWindowDrawList()
                local colors = ImGui.GetStyle().Colors
                local hov_col = ImGui.ColorConvertFloat4ToU32(colors[G.ImGuiCol.SeparatorHovered])
                local act_col = ImGui.ColorConvertFloat4ToU32(colors[G.ImGuiCol.SeparatorActive])
                local xpos, ypos = gr.Min.x, gr.Min.y
                local separator = 1
                for r = 1, subplot.Rows - 1 do
                    ypos += subplot.RowRatios[r] * gr:GetHeight()
                    local sep_bb = ImRect(gr.Min.x, ypos - SUBPLOT_SPLITTER_HALF_THICKNESS, gr.Max.x, ypos + SUBPLOT_SPLITTER_HALF_THICKNESS)
                    RenderSplitter(subplot, sep_bb, subplot.ID + separator, subplot.RowRatios, r, true, ypos, hov_col, act_col, DrawList)
                    separator += 1
                end
                for c = 1, subplot.Cols - 1 do
                    xpos += subplot.ColRatios[c] * gr:GetWidth()
                    local sep_bb = ImRect(xpos - SUBPLOT_SPLITTER_HALF_THICKNESS, gr.Min.y, xpos + SUBPLOT_SPLITTER_HALF_THICKNESS, gr.Max.y)
                    RenderSplitter(subplot, sep_bb, subplot.ID + separator, subplot.ColRatios, c, false, xpos, hov_col, act_col, DrawList)
                    separator += 1
                end
            end

            -- set outgoing sizes
            if row_sizes ~= nil then
                for r = 1, rows do row_sizes[r] = subplot.RowRatios[r] * row_sum end
            end
            if col_sizes ~= nil then
                for c = 1, cols do col_sizes[c] = subplot.ColRatios[c] * col_sum end
            end

            -- push styling
            ImPlot.PushStyleColor(ImPlot.ImPlotCol.FrameBg, G.IM_COL32_BLACK_TRANS)
            ImPlot.PushStyleVar(ImPlot.ImPlotStyleVar.PlotPadding, half_pad)
            ImPlot.PushStyleVar(ImPlot.ImPlotStyleVar.PlotMinSize, ImVec2(0, 0))
            ImGui.PushStyleVar(G.ImGuiStyleVar.FrameBorderSize, 0)

            -- set initial cursor pos
            cp.x, cp.y = gr.Min.x, gr.Min.y
            -- begin alignments
            for r = 1, subplot.Rows do subplot.RowAlignmentData[r]:Begin() end
            for c = 1, subplot.Cols do subplot.ColAlignmentData[c]:Begin() end
            -- clear legend data
            subplot.Items.Legend:Reset()
            -- Setup first subplot
            internal.SubplotSetCell(0, 0)
            return true
        end

        function ImPlot.EndSubplots()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentSubplot ~= nil, "Mismatched BeginSubplots()/EndSubplots()!")
            local subplot = gp.CurrentSubplot
            local gs = gp.Style
            -- set alignments
            for r = 1, subplot.Rows do subplot.RowAlignmentData[r]:End() end
            for c = 1, subplot.Cols do subplot.ColAlignmentData[c]:End() end
            -- pop styling
            ImPlot.PopStyleColor()
            ImPlot.PopStyleVar()
            ImPlot.PopStyleVar()
            ImGui.PopStyleVar()
            -- legend
            subplot.Items.Legend.Hovered = false
            for i = 0, subplot.Items:GetItemCount() - 1 do
                local it = subplot.Items:GetItemByIndex(i)
                if it then it.LegendHovered = false end
            end
            -- render legend
            local share_items = ImHasFlag(subplot.Flags, ImPlotSubplotFlags.ShareItems)
            if share_items and not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoLegend) and subplot.Items:GetLegendCount() > 0 then
                local legend = subplot.Items.Legend
                local legend_contextable = internal.RenderItemsLegend(subplot.Items, subplot.FrameRect, gs.PlotPadding, subplot.FrameHovered, ImGui.GetWindowDrawList())
                if legend_contextable and not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoMenus) and ImGui.GetIO().MouseReleased[gp.InputMap.Menu] then
                    ImGui.OpenPopup("##LegendContext")
                end
                if ImGui.BeginPopup("##LegendContext") then
                    ImGui.Text("Legend"); ImGui.Separator()
                    if internal.ShowLegendContextMenu(legend, not ImHasFlag(subplot.Flags, ImPlotSubplotFlags.NoLegend)) then
                        subplot.Flags = bit32.bxor(subplot.Flags, ImPlotSubplotFlags.NoLegend)
                    end
                    ImGui.EndPopup()
                end
            else
                local r = subplot.Items.Legend.Rect
                r.Min.x, r.Min.y, r.Max.x, r.Max.y = 0, 0, 0, 0
            end
            -- remove items
            if gp.CurrentItems == subplot.Items then
                gp.CurrentItems = nil
            end
            -- reset the plot items for the next frame (TODO: put this elsewhere)
            for i = 0, subplot.Items:GetItemCount() - 1 do
                local it = subplot.Items:GetItemByIndex(i)
                if it then it.SeenThisFrame = false end
            end
            -- pop id
            ImGui.PopID()
            -- set DC back correctly
            local fr = subplot.FrameRect
            local cp = ImGui.GetCurrentWindow().DC.CursorPos
            cp.x, cp.y = fr.Min.x, fr.Min.y
            ImGui.Dummy(fr:GetSize())
            internal.ResetCtxForNextSubplot(gp)
        end

        function ImPlot.IsSubplotsHovered()
            IM_ASSERT(GImPlot.CurrentSubplot ~= nil, "IsSubplotsHovered() needs to be called between BeginSubplots() and EndSubplots()!")
            return GImPlot.CurrentSubplot.FrameHovered
        end

        -- Aligned Plots

        function ImPlot.BeginAlignedPlots(group_id, vertical)
            if vertical == nil then vertical = true end
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentAlignmentH == nil and gp.CurrentAlignmentV == nil, "Mismatched BeginAlignedPlots()/EndAlignedPlots()!")
            local Window = ImGui.GetCurrentWindow()
            if Window.SkipItems then
                return false
            end
            local alignment = gp.AlignmentData:GetOrAddByKey(Window:GetID(group_id))
            if vertical then
                gp.CurrentAlignmentV = alignment
            else
                gp.CurrentAlignmentH = alignment
            end
            if alignment.Vertical ~= vertical then
                alignment:Reset()
            end
            alignment.Vertical = vertical
            alignment:Begin()
            return true
        end

        function ImPlot.EndAlignedPlots()
            IM_ASSERT(GImPlot ~= nil, "No current context. Did you call ImPlot::CreateContext() or ImPlot::SetCurrentContext()?")
            local gp = GImPlot
            IM_ASSERT(gp.CurrentAlignmentH ~= nil or gp.CurrentAlignmentV ~= nil, "Mismatched BeginAlignedPlots()/EndAlignedPlots()!")
            local alignment = gp.CurrentAlignmentH or gp.CurrentAlignmentV
            if alignment then
                alignment:End()
            end
            internal.ResetCtxForNextAlignedPlots(gp)
        end

        -- Drag and Drop Utils

        function ImPlot.BeginDragDropTargetPlot()
            internal.SetupLock()
            local plot = GImPlot.CurrentPlot
            return ImGui.BeginDragDropTargetCustom(plot.PlotRect, plot.ID)
        end

        function ImPlot.BeginDragDropTargetAxis(axis)
            internal.SetupLock()
            local ax = GImPlot.CurrentPlot.Axes[axis]
            local rect = ImRect(ax.HoverRect.Min, ax.HoverRect.Max)
            rect:Expand(-3.5)
            return ImGui.BeginDragDropTargetCustom(rect, ax.ID)
        end

        function ImPlot.BeginDragDropTargetLegend()
            internal.SetupLock()
            local items = GImPlot.CurrentItems
            return ImGui.BeginDragDropTargetCustom(items.Legend.RectClamped, items.ID)
        end

        function ImPlot.EndDragDropTarget()
            internal.SetupLock()
            ImGui.EndDragDropTarget()
        end

        function ImPlot.BeginDragDropSourcePlot(flags)
            internal.SetupLock()
            local gp = GImPlot
            local g = ImGui.GetCurrentContext()
            local plot = gp.CurrentPlot
            if g.IO.KeyMods == gp.InputMap.OverrideMod or g.DragDropPayload.SourceId == plot.ID then
                return ImGui.ItemAdd(plot.PlotRect, plot.ID) and ImGui.BeginDragDropSource(flags or 0)
            end
            return false
        end

        function ImPlot.BeginDragDropSourceAxis(idx, flags)
            internal.SetupLock()
            local gp = GImPlot
            local g = ImGui.GetCurrentContext()
            local axis = gp.CurrentPlot.Axes[idx]
            if g.IO.KeyMods == gp.InputMap.OverrideMod or g.DragDropPayload.SourceId == axis.ID then
                return ImGui.ItemAdd(axis.HoverRect, axis.ID) and ImGui.BeginDragDropSource(flags or 0)
            end
            return false
        end

        function ImPlot.BeginDragDropSourceItem(label_id, flags)
            internal.SetupLock()
            local gp = GImPlot
            IM_ASSERT(gp.CurrentItems ~= nil, "BeginDragDropSourceItem() needs to be called within an itemized context!")
            local item = gp.CurrentItems:GetItem(label_id)
            if item ~= nil then
                return ImGui.ItemAdd(item.LegendHoverRect, item.ID) and ImGui.BeginDragDropSource(flags or 0)
            end
            return false
        end

        function ImPlot.EndDragDropSource()
            internal.SetupLock()
            ImGui.EndDragDropSource()
        end
    end

    --------------------------------------------------------------------------
    -- [SECTION] Style Editor, Selectors, User Guide
    -- [Port] function-local statics live in the `S` table below
    --------------------------------------------------------------------------
    do
        local ImPlotCol = ImPlot.ImPlotCol
        local S = { style_idx = -1, map_idx = -1, ref_saved_style = nil, colors_output_dest = 0, output_only_modified = false,
                    filter = nil, alpha_flags = nil, cmap_output_dest = 0, edit = false }

        local function HelpMarker(desc)
            ImGui.TextDisabled("(?)")
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
                ImGui.TextUnformatted(desc)
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end
        end

        -- [Port] ImPlotStyle assignment (deep copy)
        local function CopyStyle(dst, src)
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

        local function ColorsDiffer(a, b)
            return a.x ~= b.x or a.y ~= b.y or a.z ~= b.z or a.w ~= b.w
        end

        function ImPlot.ShowStyleSelector(label)
            local changed
            S.style_idx, changed = ImGui.Combo(label, S.style_idx, "Auto\0Classic\0Dark\0Light\0")
            if changed then
                if S.style_idx == 0 then ImPlot.StyleColorsAuto()
                elseif S.style_idx == 1 then ImPlot.StyleColorsClassic()
                elseif S.style_idx == 2 then ImPlot.StyleColorsDark()
                elseif S.style_idx == 3 then ImPlot.StyleColorsLight()
                end
                return true
            end
            return false
        end

        function ImPlot.ShowColormapSelector(label)
            local gp = GImPlot
            local set = false
            if ImGui.BeginCombo(label, gp.ColormapData:GetName(gp.Style.Colormap)) then
                for i = 0, gp.ColormapData.Count - 1 do
                    local name = gp.ColormapData:GetName(i)
                    if ImGui.Selectable(name, gp.Style.Colormap == i) then
                        gp.Style.Colormap = i
                        internal.BustItemCache()
                        set = true
                    end
                end
                ImGui.EndCombo()
            end
            return set
        end

        function ImPlot.ShowInputMapSelector(label)
            local changed
            S.map_idx, changed = ImGui.Combo(label, S.map_idx, "Default\0Reversed\0")
            if changed then
                if S.map_idx == 0 then ImPlot.MapInputDefault()
                elseif S.map_idx == 1 then ImPlot.MapInputReverse()
                end
                return true
            end
            return false
        end

        local function Slider2(label, v, v_min, v_max, fmt) ImGui.SliderFloat2(label, v, v_min, v_max, fmt) end

        function ImPlot.ShowStyleEditor(ref)
            local gp = GImPlot
            local style = ImPlot.GetStyle()
            -- Default to using internal storage as reference
            if S.ref_saved_style == nil then
                S.ref_saved_style = CopyStyle({}, style)
            end
            if ref == nil then
                ref = S.ref_saved_style
            end

            if ImPlot.ShowStyleSelector("Colors##Selector") then
                CopyStyle(S.ref_saved_style, style)
            end

            -- Save/Revert button
            if ImGui.Button("Save Ref") then
                CopyStyle(ref, style)
                CopyStyle(S.ref_saved_style, style)
            end
            ImGui.SameLine()
            if ImGui.Button("Revert Ref") then
                CopyStyle(style, ref)
            end
            ImGui.SameLine()
            HelpMarker("Save/Revert in local non-persistent storage. Default Colors definition are not affected. " ..
                       "Use \"Export\" below to save them somewhere.")
            local _
            if ImGui.BeginTabBar("##StyleEditor") then
                if ImGui.BeginTabItem("Variables") then
                    ImGui.Text("Plot Styling")
                    Slider2("PlotDefaultSize", style.PlotDefaultSize, 0.0, 1000, "%.0f")
                    Slider2("PlotMinSize", style.PlotMinSize, 0.0, 300, "%.0f")
                    style.PlotBorderSize = ImGui.SliderFloat("PlotBorderSize", style.PlotBorderSize, 0.0, 2.0, "%.0f")
                    style.MinorAlpha = ImGui.SliderFloat("MinorAlpha", style.MinorAlpha, 0.0, 1.0, "%.2f")
                    Slider2("MajorTickLen", style.MajorTickLen, 0.0, 20.0, "%.0f")
                    Slider2("MinorTickLen", style.MinorTickLen, 0.0, 20.0, "%.0f")
                    Slider2("MajorTickSize", style.MajorTickSize, 0.0, 2.0, "%.1f")
                    Slider2("MinorTickSize", style.MinorTickSize, 0.0, 2.0, "%.1f")
                    Slider2("MajorGridSize", style.MajorGridSize, 0.0, 2.0, "%.1f")
                    Slider2("MinorGridSize", style.MinorGridSize, 0.0, 2.0, "%.1f")
                    ImGui.Text("Plot Padding")
                    Slider2("PlotPadding", style.PlotPadding, 0.0, 20.0, "%.0f")
                    Slider2("LabelPadding", style.LabelPadding, 0.0, 20.0, "%.0f")
                    Slider2("LegendPadding", style.LegendPadding, 0.0, 20.0, "%.0f")
                    Slider2("LegendInnerPadding", style.LegendInnerPadding, 0.0, 10.0, "%.0f")
                    Slider2("LegendSpacing", style.LegendSpacing, 0.0, 5.0, "%.0f")
                    Slider2("MousePosPadding", style.MousePosPadding, 0.0, 20.0, "%.0f")
                    Slider2("AnnotationPadding", style.AnnotationPadding, 0.0, 5.0, "%.0f")
                    Slider2("FitPadding", style.FitPadding, 0, 0.2, "%.2f")
                    style.DigitalPadding = ImGui.SliderFloat("DigitalPadding", style.DigitalPadding, 0.0, 20.0, "%.1f")
                    style.DigitalSpacing = ImGui.SliderFloat("DigitalSpacing", style.DigitalSpacing, 0.0, 10.0, "%.1f")
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Colors") then
                    if ImGui.Button("Export", ImVec2(75, 0)) then
                        if S.colors_output_dest == 0 then ImGui.LogToClipboard() else ImGui.LogToTTY() end
                        ImGui.LogText("ImVec4* colors = ImPlot::GetStyle().Colors;\n")
                        for i = 0, ImPlotCol.COUNT - 1 do
                            local col = style.Colors[i]
                            local name = ImPlot.GetStyleColorName(i)
                            if not S.output_only_modified or ColorsDiffer(col, ref.Colors[i]) then
                                local padding = string.rep(" ", math.max(0, 14 - #name))
                                if internal.IsColorAuto(i) then
                                    ImGui.LogText("colors[ImPlotCol_%s]%s= IMPLOT_AUTO_COL;\n", name, padding)
                                else
                                    ImGui.LogText("colors[ImPlotCol_%s]%s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);\n", name, padding, col.x, col.y, col.z, col.w)
                                end
                            end
                        end
                        ImGui.LogFinish()
                    end
                    ImGui.SameLine(); ImGui.SetNextItemWidth(120); S.colors_output_dest = ImGui.Combo("##output_type", S.colors_output_dest, "To Clipboard\0To TTY\0")
                    ImGui.SameLine(); _, S.output_only_modified = ImGui.Checkbox("Only Modified Colors", S.output_only_modified)

                    if S.filter == nil then S.filter = G.ImGuiTextFilter() end
                    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 16)
                    S.filter:Draw("Filter colors")

                    local CEF = G.ImGuiColorEditFlags
                    if S.alpha_flags == nil then S.alpha_flags = CEF.AlphaPreviewHalf end
                    if ImGui.RadioButtonEx("Opaque", S.alpha_flags == CEF.AlphaOpaque) then S.alpha_flags = CEF.AlphaOpaque end; ImGui.SameLine()
                    if ImGui.RadioButtonEx("Alpha", S.alpha_flags == CEF.None) then S.alpha_flags = CEF.None end; ImGui.SameLine()
                    if ImGui.RadioButtonEx("Both", S.alpha_flags == CEF.AlphaPreviewHalf) then S.alpha_flags = CEF.AlphaPreviewHalf end; ImGui.SameLine()
                    HelpMarker("In the color list:\n" ..
                               "Left-click on colored square to open color picker,\n" ..
                               "Right-click to open edit options menu.")
                    ImGui.Separator()
                    ImGui.PushItemWidth(-160)
                    for i = 0, ImPlotCol.COUNT - 1 do
                        local name = ImPlot.GetStyleColorName(i)
                        if S.filter:PassFilter(name) then
                            ImGui.PushID(i)
                            local temp = internal.GetStyleColorVec4(i)
                            temp = ImVec4(temp.x, temp.y, temp.z, temp.w)
                            local is_auto = internal.IsColorAuto(i)
                            if not is_auto then ImGui.PushStyleVar(G.ImGuiStyleVar.Alpha, 0.25) end
                            if ImGui.Button("Auto") then
                                if is_auto then
                                    style.Colors[i] = temp
                                else
                                    style.Colors[i] = ImPlot.IMPLOT_AUTO_COL()
                                end
                                internal.BustItemCache()
                            end
                            if not is_auto then ImGui.PopStyleVar() end
                            ImGui.SameLine()
                            if ImGui.ColorEdit4(name, temp, bit32.bor(CEF.NoInputs, S.alpha_flags)) then
                                style.Colors[i] = temp
                                internal.BustItemCache()
                            end
                            if ColorsDiffer(style.Colors[i], ref.Colors[i]) then
                                ImGui.SameLine(175)
                                if ImGui.Button("Save") then
                                    local c = style.Colors[i]
                                    ref.Colors[i] = ImVec4(c.x, c.y, c.z, c.w)
                                end
                                ImGui.SameLine()
                                if ImGui.Button("Revert") then
                                    local c = ref.Colors[i]
                                    style.Colors[i] = ImVec4(c.x, c.y, c.z, c.w)
                                    internal.BustItemCache()
                                end
                            end
                            ImGui.PopID()
                        end
                    end
                    ImGui.PopItemWidth()
                    ImGui.Separator()
                    ImGui.Text("Colors that are set to Auto (i.e. IMPLOT_AUTO_COL) will\n" ..
                               "be automatically deduced from your ImGui style.")
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Colormaps") then
                    if ImGui.Button("Export", ImVec2(75, 0)) then
                        if S.cmap_output_dest == 0 then ImGui.LogToClipboard() else ImGui.LogToTTY() end
                        local size = ImPlot.GetColormapSize()
                        local name = ImPlot.GetColormapName(gp.Style.Colormap)
                        ImGui.LogText("static const ImU32 %s_Data[%d] = {\n", name, size)
                        for i = 0, size - 1 do
                            local col = ImPlot.GetColormapColorU32(i, gp.Style.Colormap)
                            ImGui.LogText("    %d%s\n", col, i == size - 1 and "" or ",")
                        end
                        ImGui.LogText("};\nImPlotColormap %s = ImPlot::AddColormap(\"%s\", %s_Data, %d);", name, name, name, size)
                        ImGui.LogFinish()
                    end
                    ImGui.SameLine(); ImGui.SetNextItemWidth(120); S.cmap_output_dest = ImGui.Combo("##output_type", S.cmap_output_dest, "To Clipboard\0To TTY\0")
                    ImGui.SameLine()
                    _, S.edit = ImGui.Checkbox("Edit Mode", S.edit)

                    -- built-in/added
                    ImGui.Separator()
                    for i = 0, gp.ColormapData.Count - 1 do
                        ImGui.PushID(i)
                        local size = gp.ColormapData:GetKeyCount(i)
                        local selected = i == gp.Style.Colormap
                        local name = ImPlot.GetColormapName(i)
                        if not selected then ImGui.PushStyleVar(G.ImGuiStyleVar.Alpha, 0.25) end
                        if ImGui.Button(name, ImVec2(100, 0)) then
                            gp.Style.Colormap = i
                            internal.BustItemCache()
                        end
                        if not selected then ImGui.PopStyleVar() end
                        ImGui.SameLine()
                        ImGui.BeginGroup()
                        if S.edit then
                            for c = 0, size - 1 do
                                ImGui.PushID(c)
                                local col4 = ImGui.ColorConvertU32ToFloat4(gp.ColormapData:GetKeyColor(i, c))
                                if ImGui.ColorEdit4("", col4, G.ImGuiColorEditFlags.NoInputs) then
                                    gp.ColormapData:SetKeyColor(i, c, ImGui.ColorConvertFloat4ToU32(col4))
                                    internal.BustItemCache()
                                end
                                if (c + 1) % 12 ~= 0 and c ~= size - 1 then ImGui.SameLine() end
                                ImGui.PopID()
                            end
                        else
                            if ImPlot.ColormapButton("##", ImVec2(-1, 0), i) then
                                S.edit = true
                            end
                        end
                        ImGui.EndGroup()
                        ImGui.PopID()
                    end
                    if S.custom == nil then
                        S.custom = { ImVec4(1, 0, 0, 1), ImVec4(0, 1, 0, 1), ImVec4(0, 0, 1, 1) }
                        S.cmap_name = ImGui.NewTextBuffer("MyColormap", 16)
                        S.qual = true
                    end
                    local custom = S.custom
                    ImGui.Separator()
                    ImGui.BeginGroup()
                    local half = (100 - ImGui.GetStyle().ItemSpacing.x) / 2
                    if ImGui.Button("+", ImVec2(half, 0)) then
                        table.insert(custom, ImVec4(0, 0, 0, 1))
                    end
                    ImGui.SameLine()
                    if ImGui.Button("-", ImVec2(half, 0)) and #custom > 2 then
                        table.remove(custom)
                    end
                    ImGui.SetNextItemWidth(100)
                    ImGui.InputText("##Name", S.cmap_name, 16, G.ImGuiInputTextFlags.CharsNoBlank)
                    _, S.qual = ImGui.Checkbox("Qualitative", S.qual)
                    local cname = ImGui.TextBufferToString(S.cmap_name)
                    if ImGui.Button("Add", ImVec2(100, 0)) and gp.ColormapData:GetIndex(cname) == -1 then
                        ImPlot.AddColormap(cname, custom, #custom, S.qual)
                    end
                    ImGui.EndGroup()
                    ImGui.SameLine()
                    ImGui.BeginGroup()
                    for c = 1, #custom do
                        ImGui.PushID(c - 1)
                        ImGui.ColorEdit4("##Col1", custom[c], G.ImGuiColorEditFlags.NoInputs)
                        if c % 12 ~= 0 then ImGui.SameLine() end
                        ImGui.PopID()
                    end
                    ImGui.EndGroup()
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end
        end

        function ImPlot.ShowUserGuide()
            ImGui.BulletText("Left-click drag within the plot area to pan X and Y axes.")
            ImGui.Indent()
            ImGui.BulletText("Left-click drag on axis labels to pan an individual axis.")
            ImGui.Unindent()
            ImGui.BulletText("Scroll in the plot area to zoom both X and Y axes.")
            ImGui.Indent()
            ImGui.BulletText("Scroll on axis labels to zoom an individual axis.")
            ImGui.Unindent()
            ImGui.BulletText("Right-click drag to box select data.")
            ImGui.Indent()
            ImGui.BulletText("Hold Alt to expand box selection horizontally.")
            ImGui.BulletText("Hold Shift to expand box selection vertically.")
            ImGui.BulletText("Left-click while box selecting to cancel the selection.")
            ImGui.Unindent()
            ImGui.BulletText("Double left-click to fit all visible data.")
            ImGui.Indent()
            ImGui.BulletText("Double left-click axis labels to fit the individual axis.")
            ImGui.Unindent()
            ImGui.BulletText("Right-click open the full plot context menu.")
            ImGui.Indent()
            ImGui.BulletText("Right-click axis labels to open an individual axis context menu.")
            ImGui.Unindent()
            ImGui.BulletText("Click legend label icons to show/hide plot items.")
        end

        function ImPlot.ShowAltLegend(title_id, vertical, size, interactable)
            if vertical == nil then vertical = true end
            size = size or ImVec2(0, 0)
            if interactable == nil then interactable = true end
            local gp = GImPlot
            local Window = ImGui.GetCurrentWindow()
            if Window.SkipItems then
                return
            end
            local DrawList = Window.DrawList
            local plot = internal.GetPlot(title_id)
            local legend_size = ImVec2(0, 0)
            local pad = gp.Style.LegendPadding
            local default_size = ImVec2(pad.x * 2, pad.y * 2)
            if plot ~= nil then
                legend_size  = internal.CalcLegendSize(plot.Items, gp.Style.LegendInnerPadding, gp.Style.LegendSpacing, vertical)
                default_size = ImVec2(legend_size.x + pad.x * 2, legend_size.y + pad.y * 2)
            end
            local frame_size = ImGui.CalcItemSize(size, default_size.x, default_size.y)
            local cp = Window.DC.CursorPos
            local bb_frame = G.ImRect(cp.x, cp.y, cp.x + frame_size.x, cp.y + frame_size.y)
            ImGui.ItemSize(bb_frame)
            if not ImGui.ItemAdd(bb_frame, 0, bb_frame) then
                return
            end
            ImGui.RenderFrame(bb_frame.Min, bb_frame.Max, ImPlot.GetStyleColorU32(ImPlotCol.FrameBg), true, ImGui.GetStyle().FrameRounding)
            DrawList:PushClipRect(bb_frame.Min, bb_frame.Max, true)
            if plot ~= nil then
                local legend_pos = internal.GetLocationPos(bb_frame, legend_size, 0, pad)
                local legend_bb  = G.ImRect(legend_pos.x, legend_pos.y, legend_pos.x + legend_size.x, legend_pos.y + legend_size.y)
                interactable = interactable and bb_frame:Contains(ImGui.GetIO().MousePos)
                DrawList:AddRectFilled(legend_bb.Min, legend_bb.Max, ImPlot.GetStyleColorU32(ImPlotCol.LegendBg))
                DrawList:AddRect(legend_bb.Min, legend_bb.Max, ImPlot.GetStyleColorU32(ImPlotCol.LegendBorder))
                internal.ShowLegendEntries(plot.Items, legend_bb, interactable, gp.Style.LegendInnerPadding, gp.Style.LegendSpacing, vertical, DrawList)
            end
            DrawList:PopClipRect()
        end

        local M = { show_plot_rects = false, show_axes_rects = false, show_axis_rects = false, show_canvas_rects = false,
                    show_frame_rects = false, show_subplot_frame_rects = false, show_subplot_grid_rects = false,
                    show_legend_rects = false, t = 0.5 }

        local function ShowAxisMetrics(plot, axis)
            ImGui.BulletText("Label: %s", axis.Label == nil and "[none]" or plot:GetAxisLabel(axis))
            ImGui.BulletText("Flags: 0x%08X", axis.Flags)
            ImGui.BulletText("Range: [%f,%f]", axis.Range.Min, axis.Range.Max)
            ImGui.BulletText("Pixels: %f", axis:PixelSize())
            ImGui.BulletText("Aspect: %f", axis:GetAspect())
            if axis.OrthoAxis == nil then ImGui.BulletText("OrthoAxis: NULL") else ImGui.BulletText("OrthoAxis: 0x%08X", axis.OrthoAxis.ID) end
            ImGui.BulletText("LinkedMin: %s", tostring(axis.LinkedMin))
            ImGui.BulletText("LinkedMax: %s", tostring(axis.LinkedMax))
            ImGui.BulletText("HasRange: %s", tostring(axis.HasRange))
            ImGui.BulletText("Hovered: %s", tostring(axis.Hovered))
            ImGui.BulletText("Held: %s", tostring(axis.Held))
            if ImGui.TreeNode("Transform") then
                ImGui.BulletText("PixelMin: %f", axis.PixelMin)
                ImGui.BulletText("PixelMax: %f", axis.PixelMax)
                ImGui.BulletText("ScaleToPixel: %f", axis.ScaleToPixel)
                ImGui.BulletText("ScaleMax: %f", axis.ScaleMax)
                ImGui.TreePop()
            end
            if ImGui.TreeNode("Ticks") then
                ImGui.BulletText("Size: %d", axis.Ticker:TickCount())
                ImGui.BulletText("MaxSize: [%f,%f]", axis.Ticker.MaxSize.x, axis.Ticker.MaxSize.y)
                ImGui.TreePop()
            end
        end

        local function ShowItemsMetrics(items, legend_hovered_label, show_marker)
            local n_items = items:GetItemCount()
            if ImGui.TreeNode("Items", "Items (%d)", n_items) then
                for i = 0, n_items - 1 do
                    local item = items:GetItemByIndex(i)
                    ImGui.PushID(i)
                    if ImGui.TreeNode("Item", "Item [0x%08X]", item.ID) then
                        local _
                        ImGui.Bullet(); _, item.Show = ImGui.Checkbox("Show", item.Show)
                        ImGui.Bullet()
                        local temp = ImGui.ColorConvertU32ToFloat4(item.Color)
                        if ImGui.ColorEdit4("Color", temp, G.ImGuiColorEditFlags.NoInputs) then
                            item.Color = ImGui.ColorConvertFloat4ToU32(temp)
                        end
                        if show_marker then ImGui.BulletText("Marker: %d", item.Marker) end
                        ImGui.BulletText("Name: %s", item.Label or "N/A") -- [Port] NameOffset -> Label
                        ImGui.BulletText("Hovered: %s", tostring(item.LegendHovered))
                        ImGui.TreePop()
                    end
                    ImGui.PopID()
                end
                ImGui.TreePop()
            end
        end

        -- [Port] bool* p_popen: pass the current open state, returns the updated one (like ImGui.Begin)
        function ImPlot.ShowMetricsWindow(p_open)
            local fg = ImGui.GetForegroundDrawList()
            local gp = GImPlot
            local io = ImGui.GetIO()
            local _
            p_open = ImGui.Begin("ImPlot Metrics", p_open)
            ImGui.Text("ImPlot (Luau port)")
            ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate)
            ImGui.Text("Mouse Position: [%.0f,%.0f]", io.MousePos.x, io.MousePos.y)
            ImGui.Separator()
            if ImGui.TreeNode("Tools") then
                if ImGui.Button("Bust Plot Cache") then internal.BustPlotCache() end
                ImGui.SameLine()
                if ImGui.Button("Bust Item Cache") then internal.BustItemCache() end
                _, M.show_frame_rects = ImGui.Checkbox("Show Frame Rects", M.show_frame_rects)
                _, M.show_canvas_rects = ImGui.Checkbox("Show Canvas Rects", M.show_canvas_rects)
                _, M.show_plot_rects = ImGui.Checkbox("Show Plot Rects", M.show_plot_rects)
                _, M.show_axes_rects = ImGui.Checkbox("Show Axes Rects", M.show_axes_rects)
                _, M.show_axis_rects = ImGui.Checkbox("Show Axis Rects", M.show_axis_rects)
                _, M.show_subplot_frame_rects = ImGui.Checkbox("Show Subplot Frame Rects", M.show_subplot_frame_rects)
                _, M.show_subplot_grid_rects = ImGui.Checkbox("Show Subplot Grid Rects", M.show_subplot_grid_rects)
                _, M.show_legend_rects = ImGui.Checkbox("Show Legend Rects", M.show_legend_rects)
                ImGui.TreePop()
            end
            -- [Port] pools may hold freed slots; collect live entries
            local plots, subplots = {}, {}
            for p = 0, gp.Plots:GetMapSize() - 1 do
                local plot = gp.Plots:GetByIndex(p)
                if plot then table.insert(plots, plot) end
            end
            for p = 0, gp.Subplots:GetMapSize() - 1 do
                local sp = gp.Subplots:GetByIndex(p)
                if sp then table.insert(subplots, sp) end
            end
            local function legend_rects(items)
                if M.show_legend_rects and items:GetLegendCount() > 0 then
                    fg:AddRect(items.Legend.Rect.Min, items.Legend.Rect.Max, IM_COL32(255, 192, 0, 255))
                    fg:AddRect(items.Legend.RectClamped.Min, items.Legend.RectClamped.Max, IM_COL32(255, 128, 0, 255))
                end
            end
            for _, plot in plots do
                if M.show_frame_rects then fg:AddRect(plot.FrameRect.Min, plot.FrameRect.Max, IM_COL32(255, 0, 255, 255)) end
                if M.show_canvas_rects then fg:AddRect(plot.CanvasRect.Min, plot.CanvasRect.Max, IM_COL32(0, 255, 255, 255)) end
                if M.show_plot_rects then fg:AddRect(plot.PlotRect.Min, plot.PlotRect.Max, IM_COL32(255, 255, 0, 255)) end
                if M.show_axes_rects then fg:AddRect(plot.AxesRect.Min, plot.AxesRect.Max, IM_COL32(0, 255, 128, 255)) end
                if M.show_axis_rects then
                    for i = 0, ImPlot.ImAxis.COUNT - 1 do
                        local ax = plot.Axes[i]
                        if ax.Enabled then fg:AddRect(ax.HoverRect.Min, ax.HoverRect.Max, IM_COL32(0, 255, 0, 255)) end
                    end
                end
                legend_rects(plot.Items)
            end
            for _, sp in subplots do
                if M.show_subplot_frame_rects then fg:AddRect(sp.FrameRect.Min, sp.FrameRect.Max, IM_COL32(255, 0, 0, 255)) end
                if M.show_subplot_grid_rects then fg:AddRect(sp.GridRect.Min, sp.GridRect.Max, IM_COL32(0, 0, 255, 255)) end
                legend_rects(sp.Items)
            end
            if ImGui.TreeNode("Plots", "Plots (%d)", #plots) then
                for p, plot in plots do
                    ImGui.PushID(p - 1)
                    if ImGui.TreeNode("Plot", "Plot [0x%08X]", plot.ID) then
                        ShowItemsMetrics(plot.Items, nil, true)
                        for i = 0, ImPlot.ImAxis.COUNT - 1 do
                            local ax = plot.Axes[i]
                            local is_x = i < ImPlot.ImAxis.Y1
                            local n = is_x and (i + 1) or (i - ImPlot.ImAxis.Y1 + 1)
                            local buff = string.format("%s-Axis %d", is_x and "X" or "Y", n)
                            if ax.Enabled and ImGui.TreeNode(buff, "%s [0x%08X]", buff, ax.ID) then
                                ShowAxisMetrics(plot, ax)
                                ImGui.TreePop()
                            end
                        end
                        ImGui.BulletText("Title: %s", plot:HasTitle() and plot:GetTitle() or "none")
                        ImGui.BulletText("Flags: 0x%08X", plot.Flags)
                        ImGui.BulletText("Initialized: %s", tostring(plot.Initialized))
                        ImGui.BulletText("Selecting: %s", tostring(plot.Selecting))
                        ImGui.BulletText("Selected: %s", tostring(plot.Selected))
                        ImGui.BulletText("Hovered: %s", tostring(plot.Hovered))
                        ImGui.BulletText("Held: %s", tostring(plot.Held))
                        ImGui.BulletText("LegendHovered: %s", tostring(plot.Items.Legend.Hovered))
                        ImGui.BulletText("ContextLocked: %s", tostring(plot.ContextLocked))
                        ImGui.TreePop()
                    end
                    ImGui.PopID()
                end
                ImGui.TreePop()
            end
            if ImGui.TreeNode("Subplots", "Subplots (%d)", #subplots) then
                for p, sp in subplots do
                    ImGui.PushID(p - 1)
                    if ImGui.TreeNode("Subplot", "Subplot [0x%08X]", sp.ID) then
                        ShowItemsMetrics(sp.Items, nil, false)
                        ImGui.BulletText("Flags: 0x%08X", sp.Flags)
                        ImGui.BulletText("FrameHovered: %s", tostring(sp.FrameHovered))
                        ImGui.BulletText("LegendHovered: %s", tostring(sp.Items.Legend.Hovered))
                        ImGui.TreePop()
                    end
                    ImGui.PopID()
                end
                ImGui.TreePop()
            end
            if ImGui.TreeNode("Colormaps") then
                local cd = gp.ColormapData
                ImGui.BulletText("Colormaps:  %d", cd.Count)
                ImGui.BulletText("Memory: %d bytes", #cd.Tables * 4)
                if ImGui.TreeNode("Data") then
                    for m = 0, cd.Count - 1 do
                        if ImGui.TreeNode(cd:GetName(m)) then
                            local size = cd:GetTableSize(m)
                            ImGui.BulletText("Qualitative: %s", tostring(cd:IsQual(m)))
                            ImGui.BulletText("Key Count: %d", cd:GetKeyCount(m))
                            ImGui.BulletText("Table Size: %d", size)
                            ImGui.Indent()
                            local samp = ImVec4(0, 0, 0, 0)
                            local wid = 32 * 10 - ImGui.GetFrameHeight() - ImGui.GetStyle().ItemSpacing.x
                            ImGui.SetNextItemWidth(wid)
                            M.t = ImPlot.ColormapSlider("##Sample", M.t, samp, "%.3f", m)
                            ImGui.SameLine()
                            ImGui.ColorButton("Sampler", samp)
                            ImGui.PushStyleColor(G.ImGuiCol.FrameBg, ImVec4(0, 0, 0, 0))
                            ImGui.PushStyleVar(G.ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
                            for c = 0, size - 1 do
                                ImGui.PushID(m * 1000 + c)
                                ImGui.ColorButton("", ImGui.ColorConvertU32ToFloat4(cd:GetTableColor(m, c)), 0, ImVec2(10, 10))
                                ImGui.PopID()
                                if (c + 1) % 32 ~= 0 and c ~= size - 1 then ImGui.SameLine() end
                            end
                            ImGui.PopStyleVar()
                            ImGui.PopStyleColor()
                            ImGui.Unindent()
                            ImGui.TreePop()
                        end
                    end
                    ImGui.TreePop()
                end
                ImGui.TreePop()
            end
            ImGui.End()
            return p_open
        end

        local PTm = { tm_year = 70, tm_mon = 0, tm_mday = 1, tm_hour = 0, tm_min = 0, tm_sec = 0, tm_wday = 0, tm_yday = 0 }

        -- [Port] int* level / ImPlotTime* t by value: returns (clicked, level, t)
        function internal.ShowDatePicker(id, level, t, t1, t2)
            local TU = internal.ImPlotTimeUnit
            local GetTime, FloorTime, AddTime, MakeTime = internal.GetTime, internal.FloorTime, internal.AddTime, internal.MakeTime
            local BeginDis, EndDis = internal.BeginDisabledControls, internal.EndDisabledControls
            local Up, Down = G.ImGuiDir.Up, G.ImGuiDir.Down
            ImGui.PushID(id)
            ImGui.BeginGroup()

            local style   = ImGui.GetStyle()
            local col_txt = style.Colors[G.ImGuiCol.Text]
            local col_dis = style.Colors[G.ImGuiCol.TextDisabled]
            local col_btn = style.Colors[G.ImGuiCol.Button]
            ImGui.PushStyleColor(G.ImGuiCol.Button, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleVar(G.ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))

            local ht = ImGui.GetFrameHeight()
            local cell_size = ImVec2(ht * 1.25, ht)
            local clk = false
            local min_yr, max_yr = 1970, 2999

            local t1_mo, t1_md, t1_yr = 0, 0, 0
            if t1 ~= nil then
                GetTime(t1, PTm)
                t1_mo, t1_md, t1_yr = PTm.tm_mon, PTm.tm_mday, PTm.tm_year + 1900
            end
            local t2_mo, t2_md, t2_yr = 0, 0, 0
            if t2 ~= nil then
                GetTime(t2, PTm)
                t2_mo, t2_md, t2_yr = PTm.tm_mon, PTm.tm_mday, PTm.tm_year + 1900
            end

            if level == 0 then
                t = FloorTime(t, TU.Day)
                GetTime(t, PTm)
                local this_year = PTm.tm_year + 1900
                local last_year = this_year - 1
                local next_year = this_year + 1
                local this_mon  = PTm.tm_mon
                local last_mon  = this_mon == 0 and 11 or this_mon - 1
                local next_mon  = this_mon == 11 and 0 or this_mon + 1
                local days_this_mo = internal.GetDaysInMonth(this_year, this_mon)
                local days_last_mo = internal.GetDaysInMonth(this_mon == 0 and last_year or this_year, last_mon)
                GetTime(FloorTime(t, TU.Mo), PTm)
                local first_wd = PTm.tm_wday
                if ImGui.Button(string.format("%s %d", internal.MONTH_NAMES[this_mon + 1], this_year)) then
                    level = 1
                end
                ImGui.SameLine(5 * cell_size.x)
                local dis = this_year <= min_yr and this_mon == 0
                BeginDis(dis)
                if ImGui.ArrowButtonEx("##Up", Up, cell_size) then t = AddTime(t, TU.Mo, -1) end
                EndDis(dis)
                ImGui.SameLine()
                dis = this_year >= max_yr and this_mon == 11
                BeginDis(dis)
                if ImGui.ArrowButtonEx("##Down", Down, cell_size) then t = AddTime(t, TU.Mo, 1) end
                EndDis(dis)
                ImGui.PushItemFlag(G.ImGuiItemFlags.Disabled, true)
                for i = 1, 7 do
                    ImGui.Button(internal.WD_ABRVS[i], cell_size)
                    if i ~= 7 then ImGui.SameLine() end
                end
                ImGui.PopItemFlag()
                -- 0 = last mo, 1 = this mo, 2 = next mo
                local mo = first_wd > 0 and 0 or 1
                local day = mo == 1 and 1 or days_last_mo - first_wd + 1
                for i = 0, 5 do
                    for j = 0, 6 do
                        if mo == 0 and day > days_last_mo then
                            mo = 1; day = 1
                        elseif mo == 1 and day > days_this_mo then
                            mo = 2; day = 1
                        end
                        local now_yr = (mo == 0 and this_mon == 0) and last_year or ((mo == 2 and this_mon == 11) and next_year or this_year)
                        local now_mo = mo == 0 and last_mon or (mo == 1 and this_mon or next_mon)
                        local now_md = day
                        local off_mo = mo == 0 or mo == 2
                        local t1_or_t2 = (t1 ~= nil and t1_mo == now_mo and t1_yr == now_yr and t1_md == now_md) or
                                         (t2 ~= nil and t2_mo == now_mo and t2_yr == now_yr and t2_md == now_md)
                        if off_mo then ImGui.PushStyleColor(G.ImGuiCol.Text, col_dis) end
                        if t1_or_t2 then
                            ImGui.PushStyleColor(G.ImGuiCol.Button, col_btn)
                            ImGui.PushStyleColor(G.ImGuiCol.Text, col_txt)
                        end
                        ImGui.PushID(i * 7 + j)
                        if now_yr == min_yr - 1 or now_yr == max_yr + 1 then
                            ImGui.Dummy(cell_size)
                        elseif ImGui.Button(tostring(day), cell_size) and not clk then
                            t = MakeTime(now_yr, now_mo, now_md)
                            clk = true
                        end
                        ImGui.PopID()
                        if t1_or_t2 then ImGui.PopStyleColor(2) end
                        if off_mo then ImGui.PopStyleColor() end
                        if j ~= 6 then ImGui.SameLine() end
                        day += 1
                    end
                end
            elseif level == 1 then
                t = FloorTime(t, TU.Mo)
                GetTime(t, PTm)
                local this_yr = PTm.tm_year + 1900
                if ImGui.Button(tostring(this_yr)) then level = 2 end
                BeginDis(this_yr <= min_yr)
                ImGui.SameLine(5 * cell_size.x)
                if ImGui.ArrowButtonEx("##Up", Up, cell_size) then t = AddTime(t, TU.Yr, -1) end
                EndDis(this_yr <= min_yr)
                ImGui.SameLine()
                BeginDis(this_yr >= max_yr)
                if ImGui.ArrowButtonEx("##Down", Down, cell_size) then t = AddTime(t, TU.Yr, 1) end
                EndDis(this_yr >= max_yr)
                cell_size = ImVec2(cell_size.x * 7 / 4, cell_size.y * 7 / 3)
                local mo = 0
                for _ = 0, 2 do
                    for j = 0, 3 do
                        local t1_or_t2 = (t1 ~= nil and t1_yr == this_yr and t1_mo == mo) or (t2 ~= nil and t2_yr == this_yr and t2_mo == mo)
                        if t1_or_t2 then ImGui.PushStyleColor(G.ImGuiCol.Button, col_btn) end
                        if ImGui.Button(internal.MONTH_ABRVS[mo + 1], cell_size) and not clk then
                            t = MakeTime(this_yr, mo)
                            level = 0
                        end
                        if t1_or_t2 then ImGui.PopStyleColor() end
                        if j ~= 3 then ImGui.SameLine() end
                        mo += 1
                    end
                end
            elseif level == 2 then
                t = FloorTime(t, TU.Yr)
                local this_yr = internal.GetYear(t)
                local yr = this_yr - this_yr % 20
                ImGui.PushItemFlag(G.ImGuiItemFlags.Disabled, true)
                ImGui.Button(string.format("%d-%d", yr, yr + 19))
                ImGui.PopItemFlag()
                ImGui.SameLine(5 * cell_size.x)
                BeginDis(yr <= min_yr)
                if ImGui.ArrowButtonEx("##Up", Up, cell_size) then t = MakeTime(yr - 20) end
                EndDis(yr <= min_yr)
                ImGui.SameLine()
                BeginDis(yr + 20 >= max_yr)
                if ImGui.ArrowButtonEx("##Down", Down, cell_size) then t = MakeTime(yr + 20) end
                EndDis(yr + 20 >= max_yr)
                cell_size = ImVec2(cell_size.x * 7 / 4, cell_size.y * 7 / 5)
                for _ = 0, 4 do
                    for j = 0, 3 do
                        local t1_or_t2 = (t1 ~= nil and t1_yr == yr) or (t2 ~= nil and t2_yr == yr)
                        if t1_or_t2 then ImGui.PushStyleColor(G.ImGuiCol.Button, col_btn) end
                        if yr < 1970 or yr > 3000 then
                            ImGui.Dummy(cell_size)
                        elseif ImGui.Button(tostring(yr), cell_size) then
                            t = MakeTime(yr)
                            level = 1
                        end
                        if t1_or_t2 then ImGui.PopStyleColor() end
                        if j ~= 3 then ImGui.SameLine() end
                        yr += 1
                    end
                end
            end
            ImGui.PopStyleVar()
            ImGui.PopStyleColor()
            ImGui.EndGroup()
            ImGui.PopID()
            return clk, level, t
        end
        ImPlot.ShowDatePicker = internal.ShowDatePicker

        local NUMS = {}
        for i = 0, 59 do NUMS[i] = string.format("%02d", i) end

        -- [Port] ImPlotTime* t by value: returns (changed, t)
        function internal.ShowTimePicker(id, t)
            local gp = GImPlot
            ImGui.PushID(id)
            internal.GetTime(t, PTm)
            local hour24 = gp.Style.Use24HourClock
            local hr  = hour24 and PTm.tm_hour or ((PTm.tm_hour == 0 or PTm.tm_hour == 12) and 12 or PTm.tm_hour % 12)
            local min = PTm.tm_min
            local sec = PTm.tm_sec
            local ap  = PTm.tm_hour < 12 and 0 or 1
            local changed = false

            local spacing = ImVec2(0, ImGui.GetStyle().ItemSpacing.y)
            local width  = ImGui.CalcTextSize("888").x
            local height = ImGui.GetFrameHeight()

            ImGui.PushStyleVar(G.ImGuiStyleVar.ItemSpacing, spacing)
            ImGui.PushStyleVar(G.ImGuiStyleVar.ScrollbarSize, 2.0)
            ImGui.PushStyleColor(G.ImGuiCol.FrameBg, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(G.ImGuiCol.Button, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(G.ImGuiCol.FrameBgHovered, ImGui.GetStyleColorVec4(G.ImGuiCol.ButtonHovered))

            local function combo(label, cur, ia, ib)
                ImGui.SetNextItemWidth(width)
                if ImGui.BeginCombo(label, NUMS[cur], G.ImGuiComboFlags.NoArrowButton) then
                    for i = ia, ib - 1 do
                        if ImGui.Selectable(NUMS[i], i == cur) then
                            cur = i
                            changed = true
                        end
                    end
                    ImGui.EndCombo()
                end
                return cur
            end
            hr = combo("##hr", hr, hour24 and 0 or 1, hour24 and 24 or 13)
            ImGui.SameLine(); ImGui.Text(":"); ImGui.SameLine()
            min = combo("##min", min, 0, 60)
            ImGui.SameLine(); ImGui.Text(":"); ImGui.SameLine()
            sec = combo("##sec", sec, 0, 60)
            if not hour24 then
                ImGui.SameLine()
                if ImGui.Button(ap == 0 and "am" or "pm", ImVec2(0, height)) then
                    ap = 1 - ap
                    changed = true
                end
            end

            ImGui.PopStyleColor(3)
            ImGui.PopStyleVar(2)
            ImGui.PopID()

            if changed then
                if not hour24 then hr = hr % 12 + ap * 12 end
                PTm.tm_hour = hr
                PTm.tm_min  = min
                PTm.tm_sec  = sec
                t = internal.MkTime(PTm)
            end
            return changed, t
        end
        ImPlot.ShowTimePicker = internal.ShowTimePicker
    end


    return ImPlot
end
