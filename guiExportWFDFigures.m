function output = guiExportWFDFigures( event, input)
% guiExportWFDFigures - application for creating and exporting graphs and
%                       results for WFD groundwater head trend assesment
%
% INPUT
%  event:
%    Char, event triggered
%  input:
%    Type, description of input
%
% OUTPUT
%  output:
%    Var, contents of d.output
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International).

%%  Catch any errors
try
    
    % Initialize parameters
    output = [];
    if ~exist( 'event', 'var')
        event = 'StartUp';
    end
    if ~exist( 'input', 'var')
        input = 'default';
    end

    % Find or create figure    
    fig       = findobj( 'Tag', mfilename);
    is_newfig = isempty( fig);
    if ~is_newfig    
        
        % Bring fig to foreground 
        figure( fig); 
        updateModel( fig, input);    % Update model with new input
    else        
        fig = createView( input);  % Create figure and uicontrols, include d and v in appdata       
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

function [C, d, v] = initGUIData( input)
% initGUIData - create GUI constants, local data model and view state
%
% INPUT
%  fig:
%    type, description of fig
%  input:
%    type, description of input

% Access global Data
%global D

% C = GUI constants
C             = getGuiConstants( @controller);

% d = local database
d.Input       = input;
d.Saved       = true;        % acts as a save flag in closeView
d.TubeTrend   = [];
d.BodyTrend     = [];
d.h           = [];

%d.Output      = [];          % Uncomment in case of GUI without output, used as flag in getOuputWhenClosing

% v = local View State or settings
v.iWFD                  = 1;
v.Fig.Name              = 'KWR & Trefoil Hydrology - WFD Body Trend Assessment Results';
v.Fig.Tag               = mfilename;
v.Fig.Position          = [0.15 0.05 0.65 0.88]; % For Figure maximalisation, use State and restwindow in stead of Position
v.Fig.Renderer          = 'painters';
v.Fig.PaperPositionMode = 'auto';
v.Fig.PaperUnits        = 'normalized';
v.Fig.InvertHardcopy    = 'off';
v.Fig.NextPlot          = 'add';
 

% v.FigState       = struct( 'MinX', -1, 'MinY', -1, 'MaxX', -1, 'MaxY', -1, 'NormalLeft', 25, 'NormalRight', 1234, 'NormalTop', 4, 'NormalBottom', 784, 'ShowCmd', 3);
end

function fig = createView( input)
% createView - Create new figure, including appdata
%
% OUTPUT
%   fig:
%       Handle of created figure


% Initialize GUI constants, local database and view state
[C, d, v] = initGUIData( input);

%% Initialize figure, seticon
fig   = figure( C.FIGURE, v.Fig);
icons = getGuiIcons();
seticon( fig, icons.meny);

%% Create uicontrols
% Toolbar
v.Gh.Toolbar = uitoolbar( 'Tag', 'Toolbar', 'Parent', fig);
uipushtool  ( v.Gh.Toolbar, 'Tag', 'Save'    , 'ClickedCallback', @controller, 'Cdata', icons.save, 'Tooltipstring', 'Save', 'Enable', 'on');
uitoggletool( v.Gh.Toolbar, 'Tag', 'SetAoTop', 'ClickedCallback', @(o,e)setAlwaysOnTop( fig), 'Cdata', icons.on_top, 'Tooltipstring', 'Figure Always on Top', 'State', 'off');

%% Create main panel and button panel
fillFigure( C, fig);

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
            
            % Calculate trend per WFD groundwater 'body'
            wfdbody      = d.SHAPE( 1).map( v.iWFD).gwbnaam;
            [d.TubeTrend, d.BodyTrend, d.h] = calcWFDBodyTrends( d, wfdbody);      
                
        case 'NormalUpdate'
            % Instruct updateView() to update view
            update_type = 'Normal'; % N.B. : Call via guiTemplate( 'Normal Update')
            
        case {'Cancel' 'Close'}
            % Instruct updateView() to close view
            update_type = 'Close';
            
        case 'Save'
            % Instruct updateView() to update view
            update_type = 'Full'; 
            
            % Save local data to global database
            %d = save( d);
            
            % Set pathname
            %[filename, pathname] = uiputfile( {'jpg' 'JPEG - 300 dpi (*.jpg)'}, 'Save Figure as', [desktopdir '\untitled.jpg']);            
            pathname = 'C:\Users\trefo\Documents\Projecten\19203A - KWR - KRW-Trendanalyse\Figuren';
            
            % Loop through wfd bodies            
            for i = 1 : size( d.SHAPE( 1).map, 2);
                 
                % Update wfdbody indez
                v.iWFD = i;
                
                % Calculate trend per WFD groundwater 'body'
                wfdbody = d.SHAPE( 1).map( v.iWFD).gwbnaam;
                [d.TubeTrend, d.BodyTrend, d.h] = calcWFDBodyTrends( d, wfdbody);
                
                % Save view, data
                if ~isempty( d.TubeTrend)
                    saveModelViewState( fig, d, v);
                    
                    %% update GUI ( after catch to ensure that possible input errors are corrected)
                    updateView( fig, update_type);
                    
                    % set file name
                    filename = [ 'Trendbeoordeling grondwaterlichaam ' d.SHAPE( 1).map( v.iWFD).gwbnaam '.jpg'];
                    if exist(  fullfile( pathname, filename), 'file')
                        delete(  fullfile( pathname, filename))
                    end
                    
                    % Export figure to jpg
                    print( '-djpeg90', '-r300', fullfile( pathname, filename))
                end
            end                                                    
            return % Updated already!
            
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
%    String, type of update ( 'Start Up', 'Normal', 'Close', etc....)
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
        case {'StartUp' 'Full' }% Executed once, at startup
            
            % Update Map interface
            v = updateMap( d, v);                        
            
            % Update HistAAxes
            updateHistAxes( d, v);                     
            
            % Update GraphAxes
            updateGraphAxes( d, v)
            
            % Set CloseRequestFcn and Resizefcn ( after setting position or restwindow)
            set( fig, 'CloseRequestFcn', @(o,e)controller( fig, 'Close'), 'Resizefcn', @(o,e)resizeView( fig), 'Visible', 'On');
            
        case 'Normal' % or use other, more informative term
            % Update something......
            % N.B. : Call via guiTemplate( 'Normal Update')
            
        case 'Close'
            closeView( fig, @save);
            
        otherwise
            % Set Save related controls
            enable = {'on', 'off'};
            set( v.Gh.Save, 'enable', enable{ d.Saved + 1})
    end
    
catch me
    
    % Show error message
    kwrErrorHelpdlg( me,  ['Menyanthes - ' mfilename ' Error']); % Or use full GUI name.....
end
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

function updateModel( fig, input)
% updateModel - update Model with new input 
      
% Get data and view
[d, v]  = getModelViewState( fig);

% Store input
d.Input = input;

% Save data and view
saveModelViewState( fig, d, v);
end

function fillFigure( C, fig)


% Define GUI controls and layout
gui            = repmat( struct( C.CREATEGUI), 2, 2);
[gui.Style]    = deal(  'MAPAXES', 'AXES', 'AXES', 'AXES');
[gui.Tag]      = deal(  'MapAxes', 'HistAAxes', 'GraphAxes', 'HistBAxes');
%[gui.String]   = deal(  '');
%[gui.Visible]  = deal(  'on', 'on');
[gui.Xfactor]  = deal( 1.5, 1, 1.5, 1);
%[gui.Yfactor]  = deal( 1);
[gui.Ymargin]  = deal( 50);
[gui.Xmargin]  = deal( 50);

% Create GUI
v = createGui3( C, fig, flipud( gui'));

% % Two axes
% v.Gh.MapAxes    = subplot( 2, 2, 1, 'tag', 'MapAxes', 'xtick', [], 'parent', fig);
% v.Gh.HistAAxes  = subplot( 2, 2, 2, 'tag', 'HistAAxes', 'parent', fig);
% v.Gh.GraphAxes  = subplot( 2, 2, 3, 'tag', 'GraphAxes', 'xtick', [], 'parent', fig);
% v.Gh.HistBAxes  = subplot( 2, 2, 4, 'tag', 'HistBAxes', 'parent', fig);

% Set link and hold
hold( v.Gh.MapAxes, 'on');
hold( v.Gh.HistAAxes, 'on');
hold( v.Gh.GraphAxes, 'on');
hold( v.Gh.HistBAxes, 'on');

end

function updateHistAxes( d, v)

% Clear axes
delete( get( v.Gh.HistAAxes, 'children'))
delete( get( v.Gh.HistBAxes, 'children'))

% Get valid models 
has_p_m_QC = strcmp( d.TubeTrend{ :, 'hasPassedModelQC'}, 'Yes');

% Plot histograms
if ~isempty( d.TubeTrend)
    
    % Plot bars with individual colors
    cmap = flipud( jet( 11));
    for i = 1 : 9
        bar( v.Gh.HistAAxes, i - 0.5, d.BodyTrend.ClassCountA{ :}( i), 'facecolor', cmap( i, :));
        bar( v.Gh.HistBAxes, i - 0.5, d.BodyTrend.ClassCountB{ :}( i), 'facecolor', cmap( i, :));
    end
    
    % bar( v.Gh.HistAAxes, 0.5 : 8.5, d.BodyTrend.ClassCountA{ i});
    % bar( v.Gh.HistBAxes, 0.5 : 8.5, d.BodyTrend.ClassCountB{:})
    set( v.Gh.HistAAxes , 'xtick', 1 : 8, 'xticklabel', {'-50' '-25'  '-10'  '-5'   '5'   '10'  '25' '50'}, 'xgrid', 'on', 'ygrid', 'on');
    set( v.Gh.HistBAxes , 'xtick', 1 : 8, 'xticklabel', {'-50' '-25'  '-10'  '-5'   '5'   '10'  '25' '50'}, 'xgrid', 'on', 'ygrid', 'on');
    
    % Set equal y-axes limits
    yl = [0 max( [0.9091 ; d.BodyTrend.ClassCountA{:} ; d.BodyTrend.ClassCountB{:}])*1.1];
    set( [v.Gh.HistAAxes v.Gh.HistBAxes], 'ylim', yl);
    
    % Annotation
    title( v.Gh.HistAAxes, { 'Histogram trend A' [ '(aantal reeksen = ' num2str( d.BodyTrend.NoTrA) ')']}, 'fontsize', 12);    
    title( v.Gh.HistBAxes, { 'Histogram trend B' [ '(aantal modellen = ' num2str( d.BodyTrend.NoTrB) ')']}, 'fontsize', 12);
        
    % Define color
    col     = [ 1  0 0
                .3  .1 0
                0 .5 0 
                0  0 .7];
    icolA   = find( [d.BodyTrend.TrendA < -5  d.BodyTrend.TrendA < 0 d.BodyTrend.TrendA > 0 d.BodyTrend.TrendA > 5], 1);
    icolB   = find( [d.BodyTrend.TrendB < -5  d.BodyTrend.TrendB < 0 d.BodyTrend.TrendB > 0 d.BodyTrend.TrendB > 5], 1);
    colstrA = ['\color[rgb]{' num2str( col( icolA, :)) '}']; 
    colstrB = ['\color[rgb]{' num2str( col( icolB, :)) '}'];
    
    % Define pos
    xpos    = [6.5 0.5];
    xposA   = xpos( 1 + ( d.BodyTrend.TrendA < 0));
    xposB   = xpos( 1 + ( d.BodyTrend.TrendB < 0));    
               
    % Plot text, lines and arrows
    props   = struct( 'fontweight', 'normal', 'fontsize', 12, 'BackgroundColor', 'w', 'Edgecolor', 'k', 'margin', 4);
    hl      = line( [4.5 4.5], [0 1e6], 'parent', v.Gh.HistAAxes, 'color', [ .7 .7 .7], 'linestyle', '--');        
    hl      = line( [4.5 4.5], [0 1e6], 'parent', v.Gh.HistBAxes, 'color', [ .7 .7 .7], 'linestyle', '--');
    if ~isnan(  d.BodyTrend.TrendA)
        axes( v.Gh.HistAAxes);
        htA     = text( xposA, yl( 2)*.86, [ 'gem = ' colstrA num2str( d.BodyTrend.TrendA, 2) '\color{black} cm'], 'parent', v.Gh.HistAAxes, props);           
        x_cls_A = getXposClass( d.BodyTrend.TrendA);        
        ha      = arrow( [xposA + 2 *( d.BodyTrend.TrendA < 0) yl( 2)*.82], [x_cls_A yl( 2)*.75]);
        hl      = line( [x_cls_A x_cls_A], [0 1e6], 'parent', v.Gh.HistAAxes, 'color',col( icolA, :), 'linestyle', '--');
    end    
    if ~isnan(  d.BodyTrend.TrendB)
        axes( v.Gh.HistBAxes)
        htB     = text( xposB, yl( 2)*.86, [ 'gem = ' colstrB  num2str( d.BodyTrend.TrendB, 2) '\color{black} cm'], 'parent', v.Gh.HistBAxes, props);
        x_cls_B = getXposClass( d.BodyTrend.TrendB);
        ha      = arrow( [xposB + 2 *( d.BodyTrend.TrendB < 0) yl( 2)*.82], [x_cls_B yl( 2)*.75]);
        hl      = line( [x_cls_B x_cls_B], [0 1e6], 'parent', v.Gh.HistBAxes, 'color',col( icolB, :), 'linestyle', '--');
    end

    %xlabel( v.Gh.HistAAxes, 'Trend (cm)')
    xlabel( v.Gh.HistBAxes, 'Trend (cm)')
    ylabel( v.Gh.HistAAxes, 'Aantal buizen (-)')
    ylabel( v.Gh.HistBAxes, 'Aantal buizen (-)')
     
%     % Trend A
%     [no_el_A, cntr_A] = hist( v.Gh.HistAAxes, [d.TubeTrend{ :, 'TrendA'}], 5);
%     hist( v.Gh.HistAAxes, [d.TubeTrend{ :, 'TrendA'}], 5);
%     %set( v.Gh.HistAAxes, 'xlim', [ min( [ -1  cntr_A-1])*1.2 max( [ 1  cntr_A+1])*1.2 ], 'ylim', [0 max( [1 no_el_A])*1.1]);
%     %set( v.Gh.HistAAxes,  'ylim', [0 max( [1 no_el_A])*1.1]);
%     plot( v.Gh.HistAAxes, [0 0], [0 100], '--', 'color', [1 0 0], 'linewidth', 3);
%     title( v.Gh.HistAAxes, { 'Histogram trend A' [ '(gem = '  num2str( d.BodyTrend.TrendA, 2) ' cm, aantal reeksen = ' num2str( d.BodyTrend.NoTrA) ')']}, 'fontsize', 12);    
%     
%     % Trend B
%     [no_el_B, cntr_B] = hist( v.Gh.HistBAxes, [d.TubeTrend{ has_p_m_QC, 'TrendB'}], 5);
%     hist( v.Gh.HistBAxes, [d.TubeTrend{ has_p_m_QC, 'TrendB'}], 5);
%     %set( v.Gh.HistBAxes, 'xlim', [ min( [ -1  cntr_B-1])*1.2 max( [ 1  cntr_B+1])*1.2 ], 'ylim', [0 max( [1 no_el_B])*1.1]);
%     %set( v.Gh.HistBAxes, 'ylim', [0 max( [1 no_el_B])*1.1]);
%     plot( v.Gh.HistBAxes, [0 0], [0 100], '--', 'color', [1 0 0], 'linewidth', 3);    
%     title( v.Gh.HistBAxes, { 'Histogram trend B' [ '(gem = '  num2str( d.BodyTrend.TrendB, 2) ' cm, aantal modellen = ' num2str( d.BodyTrend.NoTrB) ')']}, 'fontsize', 12);
%     xlabel( v.Gh.HistBAxes, 'Trend (cm)')
%     
%     % Set equal axes limits
%     set( [v.Gh.HistAAxes v.Gh.HistBAxes], 'ylim', [0 max( [1 no_el_A no_el_B])*1.1]);
%     if sum( has_p_m_QC) == 0
%         set( [v.Gh.HistAAxes  v.Gh.HistBAxes], 'xlim', [ min( [ -1  cntr_A-1])*1.2 max( [ 1  cntr_A+1])*1.2 ]);
%     else
%         set( [v.Gh.HistAAxes  v.Gh.HistBAxes], 'xlim', [ min( [ -1  cntr_B-1 cntr_A-1])*1.2 max( [ 1  cntr_B+1 cntr_A+1])*1.2 ]);
%     end
%     set( v.Gh.HistAAxes , 'xticklabel', '');
end
%set( [ v.Gh.HistAAxes v.Gh.HistBAxes], 'xlim', [-300 300], 'xtick', [-100 -50 -25 -10 10 25 50 100], 'xgrid', 'on', 'ygrid', 'on')
%set( [ v.Gh.HistAAxes v.Gh.HistBAxes], 'xlim', [-275 275])
end

function [data, db_dir, db_name] = loadKRWFile( d, fig)

% Initialize
data = [];

%% Let user select file
db_name = '2020_01_03 Trendbeoordeling peilbuizen - alleen KRW.krw';
db_dir  = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Metadata\';
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

function v = updateMap( d, v)
global SHAPE

% Plot map
if ~isempty( d.SHAPE)
    plotMapLayers( v.Gh.MapAxes, d.SHAPE);
else
    plotMapLayers( v.Gh.MapAxes, SHAPE);
end

% Calculate xy-limits so that the map fills the axes completely
if ~isempty( d.W)

    %xl = [min( [d.W.XCoordinate]) max( [d.W.XCoordinate])];
    %yl = [min( [d.W.YCoordinate]) max( [d.W.YCoordinate])];
    %xl = [0 3e5];
    %yl = [3e5 6e5];
    
    % Zoom in and correct limits
    %correctlims2( v.Gh.MapAxes, xl + diff( xl)*[-.05 .05], yl + diff( yl)*[-.05 .05]);
        
    % PLot all locations ( Remove if present)  
    delete( findobj( v.Gh.MapAxes, 'Tag', 'all_wellfilters'));
    z = ones( size( d.W, 1), 1) * 1000; % make sure markers have higher z-index then other layers
    line( [d.W{ :, 'XCoordinate'}], [d.W{ :, 'YCoordinate'}], z, 'Marker', '.', 'linest', 'none', 'markersize', 5, 'clipping', 'on', 'color', [.8 .8 .8] , 'Tag', 'all_wellfilters', 'Parent',  v.Gh.MapAxes);
    %[~, v.Gh.LocationLabels] = plotMapLocations( v.Gh.MapAxes, [d.H( :).xcoord], [d.H( :).ycoord], ( d.H( :), 'PrimaryLabel'), 'LocationMarkers', 'LocationLabels');
        
else
    % Use current zoom in and correct limits
    xl = [0 3e5];
    yl = [3e5 6.2e5];
    correctlims2( v.Gh.MapAxes, xl + diff( xl)*[-.05 .05], yl + diff( yl)*[-.05 .05]);
    %correctlims2( v.Gh.MapAxes, xlim( v.Gh.MapAxes), ylim( v.Gh.MapAxes));
    v.Gh.LocationLabels = [];
end

% Activate ZoomIn tool
%axesTools( fig);  % Saves handles to View ( how to do this in MVC-style?)
%v = getappdata( fig, 'View'); % Refresh view

% Update listboxes and monitoring points
if ~isempty( d.SHAPE) && isfield ( d.SHAPE( 1).map, 'gwbnaam')
    
    % Update WFD body monitoring points
    v = updateWFDBody( d, v);
end

no_wells   = size( unique(  d.TubeTrend.NITGCode), 1);
no_filters = size( d.TubeTrend, 1);
title( v.Gh.MapAxes, {[ 'Grondwaterlichaam ' d.SHAPE( 1).map( v.iWFD).gwbnaam] ['(aantal putten = ' num2str( no_wells) ', aantal buizen = ' num2str( no_filters) ')']}, 'fontsize', 12);    
 
% Save location labels handles to view
setappdata( v.Gh.guiExportWFDFigures, 'View', v);
end

function v = updateWFDBody( d, v)

% Update Map
shape               = d.SHAPE( 1);
shape.map           = shape.map( v.iWFD);
shape( 1).penColor  = [1 .5 .5];
shape( 1).lineWidth = 2;
plotMapLayers( v.Gh.MapAxes, [shape d.SHAPE]);
box = [shape( 1).map( 1).box];
xl = [min( box( 1, :))-5000 max( box( 3, :))+5000];
yl = [min( box( 2, :))-5000 max( box( 4, :))+5000];
correctlims2( v.Gh.MapAxes, xl, yl);

% List of WFD body monitoring points
wfdbody     = d.SHAPE( 1).map( v.iWFD).gwbnaam;
is_body     = strcmp( d.W{ :, 'Grondwaterlichaam'}, wfdbody);
if any( is_body)    
    
    % Map of WFD body monitoring points ( on top)
    wellfilters = strcat( d.W{ is_body, 'NITGCode'}, '_',  num2str( d.W{ is_body, 'FilterNo'}));
    [~, v.Gh.LocationLabels] = plotMapLocations( v.Gh.MapAxes, [d.W{ is_body, 'XCoordinate'}], [d.W{ is_body, 'YCoordinate'}] , [d.W{ is_body, 'NITGCode'}], 'LocationMarkers', 'LocationLabels');
end

% Save location labels handles to view
setappdata( v.Gh.guiExportWFDFigures, 'View', v);
end

function updateGraphAxes( d, v)

% Clear axes
delete( get( v.Gh.GraphAxes, 'children'))
grid( v.Gh.GraphAxes, 'on')

% Mark period of comparison with patch
% Construct array with period startdates and enddates
year  = 1994 : 6 : 2024;
day   = ones( size( year));
month = ones( size( year));
dates = datenum( year, month, day)';
% Create colormap with alternating shades of gray
col    = repmat( [0.85 0.85 0.85; 1 1 1], length( dates), 1);

% Do for every period
y = [-1e5 -1e5 1e5 1e5 -1e5];
for i = 1 : size( dates, 1) - 1
    
    % Plot patch
    x = [dates( i) dates( i+1) dates( i+1) dates( i) dates( i)];
    patch( x, y, [-1 -1 -1 -1 -1], col( i, :), 'edgecolor', col( i, :), 'parent', v.Gh.GraphAxes, 'tag', 'no_zoom');
end

% Get style 
style_prefs = tsmgetpref( 'Menyanthes_ApplicationPrefs', 'Linestyles');
graph_prefs = tsmgetpref( 'Menyanthes_ApplicationPrefs', 'graph');
cmap   = str2double( style_prefs( 1).data( :, [ 1 2 3]));
linest = [[style_prefs( 1).data{ :, 5 }]' char( style_prefs(1).data( :, 4 ))];
if length( d.h) > 20 %cmap te klein, dus aan elkaar plakken
    cmap   = repmat( cmap  , ceil( length( d.h) / 20), 1);
    linest = repmat( linest, ceil( length( d.h) / 20), 1);
end

% Do for every h
[ymin, ymax] = deal( []);
for i = 1 : length( d.h)
       
    try
        
        % If filter found
        if ~isempty( d.h( i).values) 
            
            % Get ylims
            ymin = min(  [ymin ;  d.h( i).values( :, 2)]);
            ymax = max(  [ymax ;  d.h( i).values( :, 2)]);
            
            % Plot series            
            line_hndls = plot(  v.Gh.GraphAxes, d.h( i).values( :, 1), d.h( i).values( :, 2), linest( i, :), 'markersize', 1, 'color', cmap( i, :), 'linewidth', 0.5);
        end
    catch
        dbstop in guiExportWFDFigures at 548
    end
end

% Afwerking
title( v.Gh.GraphAxes, 'Tijdstijghoogtelijnen', 'fontsize', 14);    
xlabel( v.Gh.GraphAxes, 'Datum (jaar)')
ylabel( v.Gh.GraphAxes, 'Stijghoogte (m+NAP)')
 
% Set axes limits
yl = [ ymin ymax];
set( v.Gh.GraphAxes, 'xlim', [datenum( 1999, 1, 1) datenum( 2019, 1, 1)], 'ylim', yl + ( [-1 1] * diff( yl)/20))

% Set x-ticks and labels
year  = 2000 : 3 : 2018;
day   = ones( size( year));
month = ones( size( year));
dates = datenum( year, month, day)';
set(  v.Gh.GraphAxes, 'xtick', dates, 'xticklabel', num2str( year'));
%tsmdatetick(  v.Gh.GraphAxes);
end

function x_class = getXposClass( x)

class_lims   = [-inf -50 -25  -10  -5   5   10  25 50 inf]';
x_range      = 1 : 10;
x_diff       = diff( class_lims);
iclass       = find( x > class_lims, 1, 'last');
x_class      = iclass - 1 + ((x - class_lims( iclass)) / x_diff( iclass));
end