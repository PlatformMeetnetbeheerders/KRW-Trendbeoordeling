function output = guiWFDTrendAnalysis( event, h, m)
% guiWFDTrendAnalysis - GUI for WFD groundwater head trend assesment
%                       
%
% INPUT
%  input:
%    type, description of input
%
% OUTPUT
%  output:
%    type, description of output
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International)

%%  Catch any errors
try
    
    % Initialize parameters
    output = [];
    if ~exist( 'event', 'var')
        event = 'StartUp';
    end
    if ~exist( 'h', 'var')
        h = defaultH( 0);
        m = defaultM( 0);
    end

    % Find or create figure    
    fig       = findobj( 'Tag', mfilename);
    is_newfig = isempty( fig);
    if ~is_newfig    
        
        % Bring fig to foreground 
        figure( fig); 
        updateModel( fig, h);    % Update model with new input
    else        
        fig = createView( h, m);  % Create figure and uicontrols, include d and v in appdata       
    end
          
    % Call controller, also updates view
    controller( gcbo, event)
    
    % Wait for output, if d.Output exists
    if is_newfig && ishandle( fig) % So external calls to GUI do not call uiwait repeatedly
       output = getOuputWhenClosing( fig);    
    end
    
catch me
           
    % Show error message
    kwrErrorHelpdlg( me,  ['Menyanthes - ' mfilename ' Error']); % Or use full GUI name.....   
    if ishandle( fig)
        delete ( fig)
    end
end
end

function [C, d, v] = initGUIData( varargin)
% initGUIData - create GUI constants, local data model and view state
%
% INPUT
%  fig:
%    type, description of fig
%  input:
%    type, description of input

% Global data
global SHAPE
if isempty( SHAPE) %Laad SHAPE indien nodig   
   load( [ appdatadir 'MenyanthesOS\ActiveGISData.mat'], 'SHAPE') % Is created in initProgram if needed
end

% C = GUI constants
C             = getGuiConstants( @controller);

% d = local database
d.H           = varargin{1};
d.M           = varargin{2};
d.W           = [];
d.SHAPE       = [];
d.PeriodAVG   = createPeriodAVGTable(); 
d.TubeTrend   = createTubeTrendTable();
%d.Output      = [];          % Uncomment in case of GUI without output, used as flag in getOuputWhenClosing

d.DbName       = 'untitled.krw';
d.DbDir        = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Metadata';
d.Saved        = true;        % acts as a save flag in closeView

% v = local View State or settings
v.Fig.Name              = ['KRW Trendbeoordeling - ' d.DbName];
v.Fig.Tag               = mfilename;
v.Fig.Position          = [0.025 0.05 .95 .87];  % For Figure maximalisation, use State and restwindow in stead of Position
%v.Fig.Renderer          = 'painters';
%v.Fig.PaperPositionMode = 'auto';
%v.Fig.PaperUnits        = 'normalized';
%v.Fig.InvertHardcopy    = 'off';
v.Fig.NextPlot          = 'add';
v.iH                    = 1;
v.iM                    = 1;
v.iWFD                  = 1;
 
% v.FigState       = struct( 'MinX', -1, 'MinY', -1, 'MaxX', -1, 'MaxY', -1, 'NormalLeft', 25, 'NormalRight', 1234, 'NormalTop', 4, 'NormalBottom', 784, 'ShowCmd', 3);
end

function fig = createView( varargin)
% createView - Create new figure, including appdata
%
% OUTPUT
%   fig:
%       Handle of created figure


% Initialize GUI constants, local database and view state
[C, d, v] = initGUIData( varargin{:});

% Create figure
fig       = figure( C.FIGURE, v.Fig);
% set( fig, 'Color', [153 51 1]/255)
icons     = getGuiIcons();
seticon( fig, icons.meny); %... and icon

%% Create toolbar
v.Gh.Toolbar = uitoolbar( 'Tag', 'Toolbar', 'Parent', fig);
uipushtool  ( v.Gh.Toolbar, 'Tag', 'Open',          'ClickedCallback', @controller, 'Cdata', icons.open,    'Tooltipstring', 'Open');
uipushtool  ( v.Gh.Toolbar, 'Tag', 'Save',          'ClickedCallback', @controller, 'Cdata', icons.save,    'Tooltipstring', 'Save', 'Enable', 'off');
%uitoggletool( v.Gh.Toolbar, 'tag', 'tool_zoom_in',     'Userdata', 'mouseaction', 'ClickedCallback', 'toolbar(''tool_zoom_in'');', 'cdata', icons.zoomin, 'tooltipstring', 'Zoom In', 'Separator', 'on');
%uitoggletool( v.Gh.Toolbar, 'tag', 'tool_zoom_out',    'Userdata', 'mouseaction', 'ClickedCallback', 'toolbar(''tool_zoom_out'');', 'cdata', icons.zoomout, 'tooltipstring', 'Zoom Out');
%uitoggletool( v.Gh.Toolbar, 'tag', 'pan',              'Userdata', 'mouseaction', 'ClickedCallback', 'toolbar(''pan'')', 'cdata', icons.hand, 'tooltipstring', 'Pan');
%uipushtool  ( v.Gh.Toolbar, 'tag', 'tool_zoom_full', 'ClickedCallback', 'toolbar(''full zoom'')', 'cdata', icons.restzoom, 'tooltipstring', 'Full Zoom', 'Separator', 'on');
uitoggletool( v.Gh.Toolbar, 'tag', 'figlayexp'    , 'Userdata', 'mouseaction', 'ClickedCallback', 'toolbar(''figlayexp'')', 'cdata', icons.camera, 'tooltipstring', 'Copy & Export Graphs', 'OffCallback', 'toolbar(''reset'')');
axesTools   ( fig, v.Gh.Toolbar); % Create axes zoom tools

%% Add glue - Get java toolbar, but flush eventqueue first
drawnow
java_tbar = get( v.Gh.Toolbar, 'Java');
glue      = javax.swing.Box.createHorizontalGlue(); % Add glue
java_tbar.add( glue);
drawnow
uipushtool( v.Gh.Toolbar, 'Tag', 'OpenErrorLog',  'ClickedCallback', @controller, 'Cdata', icons.report,  'Tooltipstring', 'Open Error Log', 'separator', 'on');
uipushtool( v.Gh.Toolbar, 'Tag', 'Help', 'ClickedCallback', @controller, 'cdata', icons.email, 'tooltipstring', 'Contact support'); 

%% Create main panel and button panel
v     = fillMainPanel( C, v, fig); % Create 'AxesPanel', 'ControlPanel'

%% Create tabs in AxesPanel
v.Gh.MainTabGroup = uitabgroup( 'Parent', v.Gh.AxesPanel, 'Position', [0 0 1 1], 'Tag', 'MainTabGroup');
v.Gh.MapTab       = uitab( v.Gh.MainTabGroup, 'Title', 'Kaart',  'Tag', 'MapTab');
v.Gh.ATab         = uitab( v.Gh.MainTabGroup, 'Title', 'A) Stijghoogtemetingen', 'Tag', 'ATab');
v.Gh.BTab         = uitab( v.Gh.MainTabGroup, 'Title', 'B) Meteorologische invloed', 'Tag', 'BTab');
v.Gh.CTab         = uitab( v.Gh.MainTabGroup, 'Title', 'C) Verdieping',  'Tag', 'CTab');
%v.Gh.MapTab       = uitab( v.Gh.MainTabGroup, 'Title', 'C2) Kaart en interpolatie',  'Tag', 'MapTab');
v.Gh.DTab         = uitab( v.Gh.MainTabGroup, 'Title', 'D) Aggregatie en histogram', 'Tag', 'DTab');

% fill
fillControlPanel( C, v.Gh.ControlPanel)
fillMapTab( C, v.Gh.MapTab)
fillATab( C, v.Gh.ATab)
fillBTab( C, v.Gh.BTab)
fillDTab( C, v.Gh.DTab)

%% Store handles in View State and save d, v to appdata
v.Gh         = guihandles( fig);
saveModelViewState( fig, d, v);
end

function controller( object, event)
% controller - The controller is the link between the interface and
%              datamodel. As such this function calls model-related
%              functions, does some post-processing, and passes the data to
%              the interface.

%% Get view and data
fig    = findobj   ( 'Tag', mfilename);
[d, v] = getModelViewState( fig);

%% Transform eventless callbacks and java events to event string 
[event, eventdata] = all2EventString( object, event); %#ok<*NASGU> % eventdata kan nodig zijn voor Java ( bijv. popupselectie tabellen)

%% Deal with events
try
    update_type = 'None'; % do not update view by default
    switch event
        case 'StartUp'
            % Instruct updateView() to initialize view
            update_type = 'StartUp';

        case 'Open'
            % Instruct updateView to update All
            update_type = 'Full';
            
             % Get KRW file from user and load data
             [data, d.DbDir, d.DbName] = loadKRWFile( d, fig);             
             if isempty( data) % Cancelled by user
                 return
             end
             
            % Copy data to local database d            
            v.Fig.Name  = [strtok( v.Fig.Name, '-') '- ' d.DbName];
            d.W         = data.W;
            d.SHAPE     = data.SHAPE;
            %d.M         = data.M;
            clear data % from memory                                                        
                       
            % Load men file
            d = loadMenFile( d, v);
            
        case 'WFDListbox'
            % Instruct updateView() to update Well
            update_type = 'WFDBody';
            
            % Get selection
            v.iWFD      = get( v.Gh.WFDListbox, 'value');                   
            
            % Get trends of WFDPoints
            wfdbody = d.SHAPE( 1).map( v.iWFD).gwbnaam;
            is_body = strcmp( d.W{ :, 'Grondwaterlichaam'}, wfdbody);
            if any( is_body) && strcmp( get( get( v.Gh.MainTabGroup, 'SelectedTab'), 'Tag') , 'DTab')
                % Get trend data
                d.TubeTrend = calcWFDBodyTrends( d,  wfdbody);
           
            elseif any( is_body)
                % Load men file of selected well           
                v.iH = get( v.Gh.WellListbox, 'value');    
                d    = loadMenFile( d, v);
            
            else
                % No wells found
                d.TubeTrend(:,:) = [];
                v.iH  = [];
            end
                        
        case 'WellListbox'
            % Instruct updateView() to update Well
            update_type = 'Well';
            
            % Get selection
            v.iH        = get( v.Gh.WellListbox, 'value');       
            % disp( string( v.iH))
            
            % Load men file
            d = loadMenFile( d, v);
            
        case 'MainTabGroup'
            
            % Get trends of WFDPoints            
            if strcmp( get( get( v.Gh.MainTabGroup, 'SelectedTab'), 'Tag') , 'DTab')
                
                % Instruct updateView() to update DTab
                update_type = 'DTab';
                
                % Calculate trend per WFD groundwater 'body'
                wfdbody      = d.SHAPE( 1).map( v.iWFD).gwbnaam;
                [d.TubeTrend] = calcWFDBodyTrends( d, wfdbody);                
            end
            
        case {'Cancel' 'Close'}
            % Instruct updateView() to close view
            update_type = 'Close';
            
        case 'Save'
            % Instruct updateView() to update view
            update_type = 'None'; 
            
            % Save local data to global database
            %d = save( d);
            
            % Export figure to jpg
            [filename, pathname] = uiputfile( {'jpg' 'JPEG - 300 dpi (*.jpg)'}, 'Save Figure as', [desktopdir '\untitled.jpg']);
            if ~( isequal( filename, 0) || isequal( pathname, 0))
                print( '-djpeg90', '-r300', fullfile( pathname, filename))
            end

        case 'OK'
            % Instruct updateView() to close view
            update_type = 'Close';
            
            % Return output, if changed
            if ~d.Saved
                d.Output = 'Some output';            
                d.Saved  = true; 
            end
            
        otherwise
            error( ['Menyanthes:' mfilename ':FunctionNotImplemented'], ['Function ' event ' is not implemented.'])
    end
    
    %% Save view, data
    saveModelViewState( fig, d, v);

catch me      
    
    % Show error message
    kwrErrorHelpdlg( me,  ['Menyanthes - ' mfilename ' Error']); % Or use full GUI name.....   
end

%% update GUI ( after catch to ensure that possible input errors are corrected)
updateView( fig, update_type);
end

function updateView( fig, update_type)
% updateView - Update interface in line with current user view settings
%
% INPUT
%  fig:
%    Double, handle of figure to be updated
%
%  update_type:
%    String, type of update ( 'Start Up', 'WFDBody', 'Close', etc....)
%
%    Start Up   = executed once, at startup 
%    Normal     = .........
%    Full       = interface is fully updated ( incl. e.g. maplayers, locations, 
%                 uicontrols strings)
%    Close      = close view


%%  Catch any errors
try
    
    %% Initialize vars
    [d, v] = getModelViewState( fig);
    
    %% Update view
    switch  update_type
        case { 'StartUp'  'Full'} % Executed once, at startup
                    
            % Update Map interface
            v = updateMap( d, v);
                       
            % Update listboxes and monitoring points 
            if ~isempty( d.SHAPE) && isfield ( d.SHAPE( 1).map, 'gwbnaam')
                
                % WFD bodies
                set( v.Gh.WFDListbox, 'String', {d.SHAPE( 1).map.gwbnaam}', 'value', v.iWFD)                
                
                % Update WFD body monitoring points                 
                v = updateWFDBody( d, v);
                
                % Update Axes
                updateView( fig, 'Well')
            end
            
            % Set SelectionChangeCallback last, to avoid firing at tab creation
            set( v.Gh.MainTabGroup, 'SelectionChangeCallback', @controller);

            % Set CloseRequestFcn and Resizefcn last ( after setting position or restwindow)
            set( fig, 'Name', v.Fig.Name, 'CloseRequestFcn', @(o,e)controller( fig, 'Close'), 'Resizefcn', @(o,e)resizeView( fig), 'Visible', 'On');
            
        case 'DTab'
            
            % Update table
            updateHTable( v, d.TubeTrend)
            
            % Update HistogramAxes
            delete( get( v.Gh.HistogramAxes, 'children'))
            %inan = isnan( d.TubeTrend{ :, 'TrendA'});
            %d.TubeTrend( inan, :) = [] 
            if ~isempty( d.TubeTrend)
                [no_el, cntr] = hist( v.Gh.HistogramAxes, [d.TubeTrend{ :, 'TrendA'}], 5);
                hist( v.Gh.HistogramAxes, [d.TubeTrend{ :, 'TrendA'}], 5);
                set( v.Gh.HistogramAxes, 'xlim', [ min( [ -1  cntr-1])*1.2 max( [ 1  cntr+1])*1.2 ], 'ylim', [0 max( [1 no_el])*1.1]);
                plot( v.Gh.HistogramAxes, [0 0], [0 100], '--', 'color', [1 0 0], 'linewidth', 3);
                title( v.Gh.HistogramAxes, [ 'Trendhistogram ' d.SHAPE( 1).map( v.iWFD).gwbnaam], 'fontsize', 14);               
            end
            
        case 'WFDBody' % or use other, more informative term            
                        
            % Update WFD body monitoring points                 
             v = updateWFDBody( d, v);
            
            % Update Atab 
            updateView( fig, 'Well')
             
            % Update Dtab table, if relevant
            updateView( fig, 'DTab')
                         
            % Update axes
            %updateGWHeadAxes( d, v);
            
        case 'Well' % or use other, more informative term
        
            % Update selected locations on map        
            set( v.Gh.LocationLabels, 'Visible', 'Off');
            set( v.Gh.LocationLabels( v.iH), 'Visible', 'On');
    
            % Update axes
            updateGWHeadAxes( d, v);
            updateTSModelAxes( d, v);
            updateResidualsAxes( d, v);
            linkaxes( [ v.Gh.TSModelAxes  v.Gh.ResidualsAxes], 'x');
            
            % Axes ticks and labels
            setAxesPosTicksLocal( [ v.Gh.TSModelAxes  v.Gh.ResidualsAxes])
            %align_ylabs(  v.Gh.( mfilename)); %correct position ylabels            
            
        case 'Close'
            closeView( fig, @save);
            
        otherwise
            % Set Save related controls
            enable = {'on', 'off'};
            set( v.Gh.Save, 'enable', enable{ d.Saved + 1})
    end

drawnow;
   
catch me
    
    % Show error message
    kwrErrorHelpdlg( me,  ['Menyanthes - ' mfilename ' Error']); % Or use full GUI name.....
end
end

function v = fillMainPanel( C, v, fig)
% fillMainPanel - Description of fillMainPanel.
%
% INPUT
%  C:
%    Struct, GUI style definition
%  v:
%    Struct, GUI View
%
% OUTPUT
%  v:
%    Struct, GUI View
%
% Written by J.R. von Asmuth d.d. : 10-Dec-2014.
% Copyright ( c) KWR Watercycle Research Institute.

% Define GUI controls and layout
C.PANEL.Bordertype = 'etchedin';
gui                = repmat( struct( C.CREATEGUI), 1, 2);
[gui.Tag]          = deal( 'ControlPanel', 'AxesPanel');
[gui.Style]        = deal( 'PANEL');
[gui.Xfactor]      = deal( 1, 4);
[gui.Xmargin]      = deal( 0);
[gui.Ymargin]      = deal( 0);

% Create GUI for editting labels
v = createGui3( C, fig, gui, v);
%set( v.Gh.ControlPanel, 'BorderType', 'etchedin');
end

function fillControlPanel( C, parent)

% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 3, 1);
[gui.Style]    = deal( 'Panel', 'Panel', 'Guipanel');
[gui.Tag]      = deal( 'ListboxPanel', 'OptionPanel', 'ButtonPanel');
%[gui.Title]    = deal( '', 'Controleer op', 'Acties');
[gui.Yfactor]  = deal( 3, .7, 1);
[gui.Xmargin]  = deal( 10);
[gui.Ymargin]  = deal( 5);

% Create GUI
v = createGui3( C, parent, flipud( gui));

% Fill sub panels
fillListboxPanel( C, v.Gh.ListboxPanel)
fillOptionPanel( C, v.Gh.OptionPanel)
fillButtonPanel( C, v.Gh.ButtonPanel)
end

function fillListboxPanel( C, parent)

% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 4, 1);
[gui.Style]    = deal( 'HEAD2TEXT', 'Listbox', 'HEAD2TEXT', 'Listbox');
[gui.Tag]      = deal( 'WFDBodyTxT', 'WFDListbox', 'Well1ListboxTxT', 'WellListbox');
[gui.String]   = deal( 'Grondwaterlichaam:', 'Onbekend', 'KRW-Meetpunt:', 'Geen');
[gui.Yfactor]  = deal( .6, 10, .6, 3);
%[gui.Xmargin]  = deal( 0, 20);
[gui.Ymargin]  = deal( 7);

% Create GUI
v = createGui3( C, parent, flipud( gui));

% Set listboxe selection mode
set( v.Gh.WFDListbox, 'Max', 1);
set( v.Gh.WellListbox, 'Max', realmax);
end

function fillButtonPanel( C, parent)

% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 3, 1);
[gui.Style]    = deal( 'Pushbutton');
[gui.Tag]      = deal( 'Button1', 'Button2', 'Button3');
[gui.String]   = deal(  gui.Tag);
%[gui.Yfactor]  = deal( .7, 1, 1);
%[gui.Xmargin]  = deal( 0, 20);
[gui.Ymargin]  = deal( 0, 0, 6);

% Create GUI
createGui3( C, parent, flipud( gui));
end

function fillOptionPanel( C, parent)

% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 3, 1);
[gui.Style]    = deal( 'HEAD2TEXT', 'PopUpMenu', 'Checkbox');
[gui.Tag]      = deal( 'QCOptionsTxT', 'QCOptionsPopUp', 'SelectProblemsCheck');
[gui.String]   = deal(  'Beoordelingsperiode:', { 'Langjarig' 'Laatste'}, 'Selecteer dalingen');
%[gui.Yfactor]  = deal( .7, 1, 1);
%[gui.Xmargin]  = deal( 0, 20);
[gui.Ymargin]  = deal( 5);

% Create GUI
createGui3( C, parent, flipud( gui));
end

function fillMapTab( C, parent)
%Create overviewPanel - Links axes rechts listbox

axes( C.MAPAXES, ....   % Also sets Tag = 'Mapaxes'
    'Parent'  , parent, ...
    'Position', [0 0 1 1]);

%% Create location listbox panel
%createListboxPanel( C, overviewPanel, 'LocListbox');
end

function fillATab( C, parent)

axespanel = uipanel( C.PANEL, 'parent', parent, 'BackgroundColor', [1 1 1]);

% Two axes
v.Gh.GWHeadAxes  = axes( 'Position', [0.06 0.07 0.93 0.87], 'Parent', axespanel, 'Tag', 'GWHeadAxes', 'nextplot', 'add', 'parent', axespanel);
end

function fillBTab( C, parent)

axespanel = uipanel( C.PANEL, 'parent', parent, 'BackgroundColor', [1 1 1]);

% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 2, 1);
[gui.Style]    = deal( 'Axes', 'Axes');
[gui.Tag]      = deal( 'TSModelAxes', 'ResidualsAxes');
[gui.Yfactor]  = deal( 1, 1);
[gui.Xmargin]  = deal( 60);
[gui.Ymargin]  = deal( 30);
[gui.XGrid]    = deal( 'on');
[gui.YGrid]    = deal( 'on');

% Create GUI
v = createGui3( C, axespanel, flipud( gui));

% Link axes
linkaxes( [v.Gh.TSModelAxes v.Gh.ResidualsAxes], 'x')
end

function fillDTab( C, parent)

Dpanel = uipanel( C.PANEL, 'parent', parent, 'BackgroundColor', [1 1 1]);

% % Define GUI controls and layout
% gui            = repmat( struct( C.CREATEGUI), 2, 1);
% [gui.Style]    = deal( 'Axes', 'Axes');
% [gui.Tag]      = deal( 'DAxes2', 'HistogramAxes');
% [gui.Yfactor]  = deal( 3, 1);
% [gui.Xmargin]  = deal( 0, 30);
% [gui.Ymargin]  = deal( 0, 30);
% [gui.XGrid]    = deal( 'on');
% [gui.YGrid]    = deal( 'on');
% 
% % Create GUI
% v = createGui3( C, Dpanel, flipud( gui));

% Create table
jtable = jacontrol( Dpanel, C.HTABLE);

% Set position and editcallback
mtable = get( jtable, 'MatlabHandle');
set( mtable, 'Position', [0.01 0.5 .98 0.49])

% Create axes
v.Gh.HistogramAxes = axes( C.AXES, ...
    'position', [0.5 0.05 .475 .415], ...
    'Parent'  , parent, ...
    'Tag'     , 'HistogramAxes');

% Link axes
%linkaxes( [v.Gh.TSModelAxes v.Gh.ResidualsAxes], 'x')
xlabel( v.Gh.HistogramAxes, 'Gemiddelde trend [cm]', 'fontsize', 12)
ylabel( v.Gh.HistogramAxes, 'Aantal meetpunten [-]', 'fontsize', 12)
end

function updateModel( fig, input)
% updateModel - update Model with new input 
      
% Get data and view
[d, v]  = getModelViewState( fig);

% Store input
d.Input = input;

% Save data and view
saveModelViewState( fig, d, v);
end

function updateGWHeadAxes( d, v)

% Clear axes
delete( get( v.Gh.GWHeadAxes, 'Children'));

% Plot series and average
if ~isempty( d.H) &&  ~isempty( v.iH)
    
    % 2019-08-21 Temporary hack, H is now ( re)loaded per individual well
    v.iH = 1; 
    
    % Plot
    plotSeriesAverage( v.Gh.GWHeadAxes, d, v)
    
    % Axes limits
    xl = [ d.H( v.iH).values( 1, 1) d.H( v.iH).values( end, 1)];
    xl = xl + [-diff( xl)/25 diff( xl)/25];
    yl = [ min( d.H( v.iH).values( :, 2))  max( d.H( v.iH).values( :, 2))];
    yl = yl + diff( yl) * [-.1 .1];
    if ~any( isnan( yl))
        set ( v.Gh.GWHeadAxes, 'xlim', xl, 'ylim', yl, 'XGrid', 'on', 'YGrid', 'on');
    end
else
    title(  v.Gh.GWHeadAxes, ['Trend in tijdreeksgemiddelde (stijghoogte in peilbuisfilter <not found>)'], 'Fontsize', 12, 'Fontweight', 'bold')
end

tsmdatetick( v.Gh.GWHeadAxes)
end

function updateResidualsAxes( d, v)

% Clear axes
delete( get( v.Gh.ResidualsAxes, 'Children'));

% Plot residuals and average
if ~isempty( d.M) &&  ~isempty( v.iH)
    plotResidualAverage( v.Gh.ResidualsAxes, d, v)
    
    % Set axes limits
    xl = [ d.M( v.iM).result.r( 1, 1)  d.M( v.iM).result.r( end, 1)];
    xl = xl + [-diff( xl)/25 diff( xl)/25];
    yl = [ min( d.M( v.iM).result.r( :, 2))  max( d.M( v.iM).result.r( :, 2))];
    yl = yl + diff( yl) * [-.1 .1];
    if ~any( isnan( yl))
        set ( v.Gh.ResidualsAxes, 'xlim', xl, 'ylim', yl, 'XGrid', 'on', 'YGrid', 'on');
    end
end

tsmdatetick( v.Gh.ResidualsAxes)
end

function updateTSModelAxes( d, v)

% Clear axes
delete( get( v.Gh.TSModelAxes, 'Children'));

if ~isempty( d.M) &&  ~isempty( v.iH)
    % Plot prediction and observations
    plot( v.Gh.TSModelAxes, d.M( v.iM).result.hsim( :, 1), d.M( v.iM).result.hsim( :, 2), 'g-', 'linewidth', 1.5, 'userdata', 'Prediction');
    plot( v.Gh.TSModelAxes, d.M( v.iM).h.values( :, 1)   , d.M( v.iM).h.values( :, 2)   , 'r.', 'userdata', 'Observations', 'markersize', 12)
    
    % Set axes limits and label and title
    set   ( v.Gh.TSModelAxes, 'ylim', [min( [ d.M( v.iM).h.values( :, 2) ; d.M( v.iM).result.hsim( :, 2)])-0.1 max( [ d.M( v.iM).h.values( :, 2) ; d.M( v.iM).result.hsim( :, 2)])+0.1], 'xlim', [min( d.M( v.iM).h.values( :, 1))-30 max( d.M( v.iM).h.values( :, 1))+30])
    ylabel( v.Gh.TSModelAxes, 'Groundwater level (m+ref)');
    title ( v.Gh.TSModelAxes, ['Results of series ' d.M( v.iM).Name ], 'Fontsize', 14);
    %leg = strcat( { 'Residuals'}');
    h    = tsmlegend( v.Gh.TSModelAxes, {'Prediction';'Observations'}, 'Location', 'NW');
    %    set( h, 'visible', visi, 'interpreter', 'none');
else
    title(  v.Gh.TSModelAxes, ['Results of series < not found>' ], 'Fontsize', 14);
end
end

function setAxesPosTicksLocal( axhndls)

% Set dateticks in lowest axes
subplot( axhndls( 1))
tsmdatetick( axhndls( 1))
xt = get( axhndls( 1), 'xtick');
xl = get( axhndls( 1), 'xticklabel');

% Compute space for title
%titles_y_length = 0.13; % To do : improve by using fontsize / pixels
%axes_y_length   = sum( cellfun( @( x) x( 4), get( axhndls, 'position'))) + titles_y_length;

% set position lower axes, copy ticks, delete labels
% for i_ax = 1 : length( axhndls)
%     position = get( axhndls( i_ax), 'position');
% 
%     % Verschuif en rek op
%     if i_ax == 1
%         position = [ position( 1)*0.7  position( 2)-0.03  position( 3)*1.15  position( 4)/axes_y_length];
%     else
%         prevpos  = get( axhndls( i_ax-1), 'position');
%         position = [ prevpos( 1) prevpos( 2)+prevpos( 4)+0.01  prevpos( 3)  position( 4)/axes_y_length];        
%     end
%     
%     set( axhndls( i_ax), 'position', position)
% end

% reset xticklabels in lowest axes
set( axhndls( 1), 'xticklabel', '', 'xtick', xt, 'XGrid', 'on', 'YGrid', 'on');
set( axhndls( 2), 'xticklabel', xl, 'xtick', xt, 'XGrid', 'on', 'YGrid', 'on');
end

function plotSeriesAverage( ax, d, v)

% Test measurement presence
v.iH = 1; % 2019-08-21 Temporary hack, H is now ( re)loaded per individual well
if ~isempty( d.H( v.iH).values)
    
    % Plot series
    plot( ax, d.H( v.iH).values( :, 1), d.H( v.iH).values( :, 2), 'color', [.7 .7 .7]);
    
    % Plot PeriodAVG
    for i = 1 : size( d.PeriodAVG, 1)
        
        % Get plotdata
        t        = [d.PeriodAVG{ i, 'StartDateTime'}  d.PeriodAVG{ i, 'EndDateTime'}];
        avg      = [d.PeriodAVG{ i, 'Avg_Measurement'} d.PeriodAVG{ i, 'Avg_Measurement'}];
        conf_int = d.PeriodAVG{ i, 'Conf_Int_Trend_M'};
              
        % Plot
        plot( ax, t,  avg           , 'color', d.PeriodAVG{ i, 'Color_M'}, 'linewidth', 2.5);
        plot( ax, t,  avg - conf_int, 'color', d.PeriodAVG{ i, 'Color_M'}, 'linewidth', 1.5, 'linestyle', '--');
        plot( ax, t,  avg + conf_int, 'color', d.PeriodAVG{ i, 'Color_M'}, 'linewidth', 1.5, 'linestyle', '--');
    end
end

% Axes limits
xl              = [ d.H( v.iH).values( 1, 1) d.H( v.iH).values( end, 1)];
xl              = xl + [-diff( xl)/25 diff( xl)/25];
yl_up           = [ min( d.M( v.iM).result.r( :, 2))  max( d.M( v.iM).result.r( :, 2))];
yl_up           = yl_up + diff( yl_up) * [-.1 .1];
if ~any( isnan( yl_up))
    set ( ax, 'xlim', xl, 'ylim', yl_up);
end

 % Axes labels and title
well_filter = [d.H( v.iH).NITGCode  '_' num2str( d.H( v.iH).filtnr)];
title ( ax, ['Trend in tijdreeksgemiddelde (stijghoogte in peilbuisfilter ' well_filter ')'], 'Fontsize', 12, 'Fontweight', 'bold')
ylabel( ax , 'Stijghoogte (m+NAP)') ;
xlabel( ax , 'Datum (jaar)') ;
legend( ax, well_filter); % tsmlegend? set( legh, 'interpreter', 'none')?
end

function plotResidualAverage( ax, d, v)

% Test presence residuals
if ~isempty( d.M( v.iM).result.r)
    
    % Plot residuals
    %lcolor  = colormap( lines( 2));    
    hndl = bar( ax, nan, nan);
    set( hndl, 'Userdata', ['Residuals ' d.M( v.iM).Name], 'LineStyle', 'none', 'facecolor', [.7 .7 .7], 'BarWidth', 1) % 'facecolor', lcolor( 2, :)'
    set( hndl, 'xdata', d.M( v.iM).result.r( :, 1)','ydata', d.M( v.iM).result.r(:,2)')       
       
    % Plot PeriodAVG measurements
    % Match measurement and residual average
%     d.PeriodAVG{ :, 'Avg_Measurement'} = d.PeriodAVG{ :, 'Avg_Measurement'} - d.PeriodAVG{ end-2, 'Avg_Measurement'} + d.PeriodAVG{ end-2, 'Avg_Residual'};
%     for i = 1 : size( d.PeriodAVG, 1)
%         t   = [d.PeriodAVG{ i, 'StartDateTime'}  d.PeriodAVG{ i, 'EndDateTime' }];
%         avg = [d.PeriodAVG{ i, 'Avg_Measurement' }  d.PeriodAVG{ i, 'Avg_Measurement'}];
%         plot( ax, t , avg, 'color', [1 .8 .8], 'linewidth', 2);
%     end
    
    % Plot PeriodAVG residuals
    for i = 1 : size( d.PeriodAVG, 1)
        t   = [d.PeriodAVG{ i, 'StartDateTime'} d.PeriodAVG{ i, 'EndDateTime'  }];
        avg = [d.PeriodAVG{ i, 'Avg_Residual'} d.PeriodAVG{ i, 'Avg_Residual'}];
        conf_int = d.PeriodAVG{ i, 'Conf_Int_Trend_R'};
        plot( ax, t, avg, 'color', d.PeriodAVG{ i, 'Color_R'}, 'linewidth', 2);        
        plot( ax, t, avg - conf_int, 'color', d.PeriodAVG{ i, 'Color_R'}, 'linewidth', 1, 'linestyle', '--');
        plot( ax, t, avg + conf_int, 'color', d.PeriodAVG{ i, 'Color_R'}, 'linewidth', 1, 'linestyle', '--');
    end    
end

% Axes labels and title
%well_filter = [d.H( v.iH).Name  '_' num2str( d.H( v.iH).filtnr)];
%title ( ax, ['Vergelijking periodegemiddelde van peilbuisfilter ' well_filter], 'Fontsize', 12, 'Fontweight', 'bold')
ylabel( ax , 'Residuen (m)') ;% 'Date (year)')
xlabel( ax , 'Datum (jaar)') ;
%legend( ax, well_filter); % tsmlegend? set( legh, 'interpreter', 'none')?
end

function v = updateMap( d, v)
global SHAPE

% Plot map
if ~isempty( d.SHAPE)
    plotMapLayers( v.Gh.Mapaxes, d.SHAPE);
else
    plotMapLayers( v.Gh.Mapaxes, SHAPE);
end

% Calculate xy-limits so that the map fills the axes completely
if ~isempty( d.W)

    %xl = [min( [d.W.XCoordinate]) max( [d.W.XCoordinate])];
    %yl = [min( [d.W.YCoordinate]) max( [d.W.YCoordinate])];
    %xl = [0 3e5];
    %yl = [3e5 6e5];
    
    % Zoom in and correct limits
    %correctlims2( v.Gh.Mapaxes, xl + diff( xl)*[-.05 .05], yl + diff( yl)*[-.05 .05]);
        
    % PLot all locations ( Remove if present)  
    delete( findobj( v.Gh.Mapaxes, 'Tag', 'all_wellfilters'));
    z = ones( size( d.W, 1), 1) * 1000; % make sure markers have higher z-index then other layers
    line( [d.W{ :, 'XCoordinate'}], [d.W{ :, 'YCoordinate'}], z, 'Marker', '.', 'linest', 'none', 'markersize', 5, 'clipping', 'on', 'color', [.8 .8 .8] , 'Tag', 'all_wellfilters', 'Parent',  v.Gh.Mapaxes);
    %[~, v.Gh.LocationLabels] = plotMapLocations( v.Gh.Mapaxes, [d.H( :).xcoord], [d.H( :).ycoord], ( d.H( :), 'PrimaryLabel'), 'LocationMarkers', 'LocationLabels');
        
else
    % Use current zoom in and correct limits
    xl = [0 3e5];
    yl = [3e5 6.2e5];
    correctlims2( v.Gh.Mapaxes, xl + diff( xl)*[-.05 .05], yl + diff( yl)*[-.05 .05]);
    %correctlims2( v.Gh.Mapaxes, xlim( v.Gh.Mapaxes), ylim( v.Gh.Mapaxes));
    v.Gh.LocationLabels = [];
end

% Activate ZoomIn tool
%axesTools( fig);  % Saves handles to View ( how to do this in MVC-style?)
%v = getappdata( fig, 'View'); % Refresh view

% Save location labels handles to view
setappdata( v.Gh.guiWFDTrendAnalysis, 'View', v);
end

function v = updateWFDBody( d, v)

% Update Map
shape               = d.SHAPE( 1);
shape.map           = shape.map( v.iWFD);
shape( 1).penColor  = [1 .5 .5];
shape( 1).lineWidth = 2;
plotMapLayers( v.Gh.Mapaxes, [shape d.SHAPE]);
box = [shape( 1).map( 1).box];
xl = [min( box( 1, :))-5000 max( box( 3, :))+5000];
yl = [min( box( 2, :))-5000 max( box( 4, :))+5000];
correctlims2( v.Gh.Mapaxes, xl, yl);

% List of WFD body monitoring points
wfdbody     = d.SHAPE( 1).map( v.iWFD).gwbnaam;
is_body     = strcmp( d.W{ :, 'Grondwaterlichaam'}, wfdbody);
wellfilters = strcat( d.W{ is_body, 'NITGCode'}, '_',  num2str( d.W{ is_body, 'FilterNo'}));
set( v.Gh.WellListbox, 'String', wellfilters, 'value', v.iH, 'ListboxTop', max( [1 min( [v.iH])]));

% Map of WFD body monitoring points ( on top)
[~, v.Gh.LocationLabels] = plotMapLocations( v.Gh.Mapaxes, [d.W{ is_body, 'XCoordinate'}], [d.W{ is_body, 'YCoordinate'}] , [d.W{ is_body, 'NITGCode'}], 'LocationMarkers', 'LocationLabels');

% Save location labels handles to view
setappdata( v.Gh.guiWFDTrendAnalysis, 'View', v);
end

function d = save( d)
% save - Save local data to global database
%
% INPUT
%  d:
%    local database

global D

% Save local data to global database
D = d; % Or some other operation...............

% Change save status
d.Saved = true;
end

function [data, db_dir, db_name] = loadKRWFile( d, fig)

% Initialize
data = [];

%% Let user select file
[db_name, db_dir] = uigetfile( {'*.krw;*.zip' 'Menyanthes databases (*.krw,*.zip)'}, 'Open KRW database', d.DbDir);
if db_name
       
    % Get fileparts
    [~, db_name, ext] = fileparts( db_name);
    
    %% Load data
    try
        % Start loading, set pointer to watch
        OldWindowBMFcn  = get( fig, 'WindowButtonMotionFcn');
        set( fig, 'WindowButtonMotionFcn', '', 'pointer', 'watch')
        drawnow
        
        % Unzip if needed
        if strcmp( ext, '.zip')
            [db_dir, ext] = unzipfile( db_dir, db_name, ext);
        end
        
        % Load file
        db_name = [db_name ext];
        data    = load( '-MAT',  [ db_dir, db_name]);
        
        % Ready, restore pointer and WindowButtonMotionFcn
        set( fig, 'pointer', 'arrow', 'WindowButtonMotionFcn', OldWindowBMFcn)
        
    catch me
        % Restore OldWindowBMFcn and rethrow error
        set    ( fig, 'WindowButtonMotionFcn', OldWindowBMFcn)
        rethrow( me)
    end
end
end

function d = loadMenFile( d, v)

try
    % Get list of monitoring points
    wfdbody     = d.SHAPE( 1).map( v.iWFD).gwbnaam;
    is_body     = strcmp( d.W{ :, 'Grondwaterlichaam'}, wfdbody);
    wellfilters = strcat( d.W{ is_body, 'NITGCode'}, '_',  num2str( d.W{ is_body, 'FilterNo'}));                    
    
    % Load data
    men_dir     = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Individual well filters\';    
    dat         = load( [men_dir wellfilters{ v.iH ( 1)} '.men'], 'H', 'M', '-mat');
    d.H         = prepareHData( dat.H); % Convert diverfile data
    d.M         = dat.M;
    clear dat  
    
    % Get averages
    d.PeriodAVG = calcPeriodAverage( d.H, d.M);

catch
    % Clear data
    d.H( :) = [];
    d.M( :) = [];
end
end