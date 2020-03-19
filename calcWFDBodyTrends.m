function [tube_trend, body_trend, h] = calcWFDBodyTrends( d, wfdbody)
% calcWFDBodyTrends - Calculate trend per WFD groundwater 'body'
%
% INPUT
%  d:
%    Struct, local database
%
%  wfdbody:
%    Type, name of WFD groundwater 'body'
%
% OUTPUT
%  d:
%    Struct, local database
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International)

% Get list of WFD body monitoring tubes
is_body = strcmp( d.W{ :, 'Grondwaterlichaam'}, wfdbody);
tubes   = strcat( d.W{ is_body, 'NITGCode'}, '_',  num2str( d.W{ is_body, 'FilterNo'}));

% Remove blanks in tubes
for  i = 1 : size( tubes, 1)
     tubechari =  tubes{ i};
     tubes( i) = {tubechari( ~isspace( tubechari))};
end

% Store monitoring point metadata  % d.W.Properties.VariableNames tube_trend.Properties.VariableNames
tube_trend = createTubeTrendTable();
tube_trend = repmat( tube_trend, size( tubes, 1), 1);
metafields = {'NITGCode'  'FilterNo' 'Grondwaterlichaam'   'Provincie' 'XCoordinate' 'YCoordinate'};
tube_trend( 1 : size( tubes, 1), metafields) = d.W( is_body, metafields);

%% Trends per tube
men_dir = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Individual well filters\';
boolean = {'No', 'Yes'};
h       = defaultH( size( tubes, 1)); 
for i = 1 : size( tubes, 1)
    
    % Load data
    try % in case men-file is missing
        dat     = load( [men_dir tubes{ i} '.men'], 'H', 'M', '-mat');
        tube_trend{ i, 'isFilterFound'}     = {'Yes'};
    catch
        tube_trend{ i, 'isFilterFound'}     = {'No'};
        tube_trend{ i, 'hasCorrectPeriod'}  = {'No'};
        tube_trend{ i, 'hasModelResult'}    = {'No'};
        %tube_trend{ i, 'hasPassedSeriesQC'} = {'No'};
        tube_trend{ i, 'hasPassedModelQC'}  = {'No'};
        tube_trend{ i, 'isTrendASignif'}    = {'No'};
        tube_trend{ i, 'isTrendBSignif'}    = {'No'};        
        continue
    end
    h( i)   = prepareHData( dat.H);  % Convert diverfile data
    m       = dat.M;
    clear dat
    
    % Get trend results
    period_avg                         = calcPeriodAverage( h( i), m);
    tube_trend{ i, 'StartMeas'}        = h( i).values(   1, 1);   
    tube_trend{ i, 'EndMeas'}          = h( i).values( end, 1);   
    tube_trend{ i, 'TrendA'}           = round(( period_avg{ 9, 'Avg_Measurement'} - period_avg{ 7, 'Avg_Measurement'}) * 1000) / 10;
    tube_trend{ i, 'TrendB'}           = round(( period_avg{ 9, 'Avg_Residual'} - period_avg{ 7, 'Avg_Residual'} ) * 1000 )/ 10;
    tube_trend{ i, 'ConfIntTrendA'}    = round( period_avg{ 9, 'Conf_Int_Trend_M'} * 1000) / 10;
    tube_trend{ i, 'ConfIntTrendB'}    = round( period_avg{ 9, 'Conf_Int_Trend_R'} * 1000) / 10;
    tube_trend{ i, 'isTrendASignif'}   = boolean( ( abs( tube_trend{ i, 'TrendA'}) - tube_trend{ i, 'ConfIntTrendA'} > 0) + 1);
    tube_trend{ i, 'isTrendBSignif'}   = boolean( ( abs( tube_trend{ i, 'TrendB'}) - tube_trend{ i, 'ConfIntTrendB'} > 0) + 1);
    tube_trend{ i, 'hasCorrectPeriod'} = boolean( ~isnan( tube_trend{ i, 'TrendA'}) + 1);
    tube_trend{ i, 'hasModelResult'}   = boolean( ~isnan( tube_trend{ i, 'TrendB'}) + 1);        
    
    % Get primary model results
    if ~isnan( tube_trend{ i, 'TrendB'})
        [prec_MO, prec_MO_std]             = prec( [], 'M0', m, find( strcmp( {m.in.ir}', 'PREC')));
        [evap_fctr, evap_fctr_std]         = evap( [], 'factor', m, find( strcmp( {m.in.ir}', 'EVAP')));
        model_qc                           = ( prec_MO < 5000) && ( 0.5 < evap_fctr) && ( evap_fctr < 1.5) && ...
                                             (( prec_MO - 2 * prec_MO_std) > 0) && (( evap_fctr - 2 * evap_fctr_std) > 0);
        tube_trend{ i, 'PrecM0'}           = round( prec_MO * 10) / 10;
        tube_trend{ i, 'PrecM0Std'}        = round( prec_MO_std * 10) / 10;
        tube_trend{ i, 'EvapFctr'}         = round( evap_fctr * 100) / 100;
        tube_trend{ i, 'EvapFctrStd'}      = round( evap_fctr_std * 100) / 100;
        tube_trend{ i, 'hasPassedModelQC'} = boolean( model_qc + 1);       
    else
        tube_trend{ i, 'hasPassedModelQC'} = {'No'};
    end
    
end

% Trends per body
body_trend        = createBodyTrendTable();
isnan_A           = isnan( [tube_trend{ :, 'TrendA'}]);
has_p_m_QC        = strcmp( tube_trend{ :, 'hasPassedModelQC'}, 'Yes');
body_trend.NoTrA = sum( ~isnan_A);
body_trend.NoTrB = sum( has_p_m_QC);
body_trend.TrendA = mean( [tube_trend{ ~isnan_A, 'TrendA'}]);
body_trend.TrendB = mean( [tube_trend{ has_p_m_QC, 'TrendB'}]);

% Trend classes
class_lims    = [-inf -50 -25  -10  -5   5   10  25 50 inf]';
class_count_A = NaN( size( class_lims, 1) -1, 1);
class_count_B = class_count_A;
for i = 1 : size( class_lims, 1) - 1
    
    % Trend A
    i_class_A        = tube_trend{ ~isnan_A, 'TrendA'} > class_lims( i) & ...
                       tube_trend{ ~isnan_A, 'TrendA'} <= class_lims( i + 1);
    class_count_A( i) = sum( i_class_A);
    
     % Trend A
    i_class_B        = tube_trend{ has_p_m_QC, 'TrendB'} > class_lims( i) & ...
                       tube_trend{ has_p_m_QC, 'TrendB'} <= class_lims( i + 1);
    class_count_B( i) = sum( i_class_B);    
end

% Store result
body_trend.ClassCountA = {class_count_A};
body_trend.ClassCountB = {class_count_B};
end

function body_trend = createBodyTrendTable()
% createTubeTrendTable - create table with KRW trend assesment per
%                        monitoring tube
%
% OUTPUT
%  tube_trend:
%    Table, KRW trend assesment per monitoring tube
%
% Written by trefo d.d. : 20-Sep-2019.
% Copyright ( c) KWR Watercycle Research Institute.

% Create cellarray
c = {...  
  'Grondwaterlichaam'    '[Categorical]'    {''}  ; ...
  'TrendA'               '[cm]'              NaN  ; ... 
  'ConfIntTrendA'        '[cm]'              NaN  ; ...   
  'ClassCountA'          '[Integer]'         NaN  ; ...   
  'TrendB'               '[cm]'              NaN  ; ... 
  'ConfIntTrendB'        '[cm]'              NaN  ; ...
  'ClassCountB'          '[Integer]'         NaN  ; ...   
  'isTrendASignif'       '[Boolean]'         ''  ; ...     % Filter has model results / Trend_R = 'Yes'  
  'isTrendBSignif'       '[Boolean]'         ''  };      % Filter has model results / Trend_R = 'Yes'           

% Convert to table
body_trend = hymonCell2Table( c);
end