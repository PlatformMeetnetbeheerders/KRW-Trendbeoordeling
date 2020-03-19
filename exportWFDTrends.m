function exportWFDTrends()
% exportWFDTrends -  export results and calculate characteristics of WFD groundwater head trend assesment
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International)

% Load data
%file    = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Metadata\2019_11_05 Trendbeoordeling peilbuizen - alleen KRW.krw';
file    = 'C:\Users\trefo\Documents\Menyanthes\Data\2019 KRW trendanalyse\Verwerkte gegevens\Metadata\2020_01_03 Trendbeoordeling peilbuizen - alleen KRW.krw';
data    = load( '-MAT',  file);
d.W     = data.W;
d.SHAPE = data.SHAPE;
clear data % from memory

% Create table for results
tube_trend = createTubeTrendTable();
tube_trend = repmat( tube_trend, size( d.W, 1), 1);

% Loop through bodies
wfd_bodies = unique( d.W{ :, 'Grondwaterlichaam'});
ind        = 1;
for i = 1 : size( wfd_bodies, 1)
  
    % Calculate trend per WFD groundwater 'body'
    disp( wfd_bodies( i));
    tube_trend_body = calcWFDBodyTrends( d,  wfd_bodies( i));
    
    % Store in table for results
    tube_trend( ind : ind - 1 + size( tube_trend_body, 1), : ) = tube_trend_body;
    
    % Increase index
    ind = ind + size( tube_trend_body, 1);
end

% Start with all records of series and filters
no_records                              = size( tube_trend, 1);           % All records / filters / krw points / trends
i_r                                     = ( 1 : no_records )';             

% Select unique and duplicate series or results ( before setting isFilterUnique to 'No'
[~, i_s_un_dupl_nan]                    = unique( tube_trend( :, [1 : 6 14 : 19]), 'rows');    % Series unique, NaN may be duplicate
i_s_nan                                 = find( isnan(  tube_trend{ :, 'StartMeas'}));         % Series NaN (not found)
i_s_un_no_nan                           = setdiff( i_s_un_dupl_nan, i_s_nan);                  % Series unique, without NaNs
[~, i_s_nan_un]                         = unique( tube_trend( i_s_nan, 1 : 6), 'rows');        % Series NaN and unique
i_s_nan_dupl                            = setdiff( i_s_nan, i_s_nan( i_s_nan_un));             % Series NaN and duplicate
i_s_un                                  = [i_s_un_no_nan ; i_s_nan( i_s_nan_un)];              % Series unique, including unique NaNs
i_s_dupl                                = setdiff( i_r, i_s_un);                               % Series duplicates, and nans 
no_series_unique_nan                    = size( i_s_un_dupl_nan, 1);
no_series_nan                           = size( i_s_nan, 1);
no_series_unique                        = size( i_s_un, 1);
no_series_duplicate                     = size( i_s_dupl, 1);
no_series_unique_nan_dupl               = size( i_s_nan_dupl, 1);
no_series_nan_unique                    = size( i_s_nan_un, 1);

% Select unique and duplicate filters
[tubes_unique, i_f_un]                  = unique( tube_trend( :, [1 2]), 'rows');  % Unique filters 
i_f_dupl                                = setdiff( i_r, i_f_un);                   % Duplicate filters
no_filter_unique                        = size( i_f_un, 1);
no_filter_duplicates                    = size( i_f_dupl, 1);

% Select conflicts (duplicate filters with unique results)
i_s_conflict                            = intersect( i_f_dupl, i_s_un);   
no_series_conflicts                     = size( i_s_conflict, 1);

%  Trend applicability / complete series and models
i_A_nan                                 = find( isnan(  tube_trend{ :, 'TrendA'}));  % Series nan / not found 
i_B_nan                                 = find( isnan(  tube_trend{ :, 'TrendB'}));  % Series nan / not found 
i_s_com_series                          = setdiff( i_r, i_A_nan);
no_com_series                           = size( i_s_com_series, 1);
i_s_inc_series                          = setdiff( i_A_nan, i_s_nan);
no_inc_series                           = size( i_s_inc_series, 1);
i_s_com_models                          = setdiff( i_s_com_series, i_B_nan);
no_com_models                           = size( i_s_com_models, 1);
i_s_inc_models                          = setdiff( i_B_nan, i_A_nan);
no_inc_models                           = size( i_s_inc_models, 1);

% Model QC
i_rej_models                            = find( strcmp( tube_trend{  :, 'hasPassedModelQC'}, 'No'));
i_rej_models                            = setdiff( i_rej_models, i_B_nan);
no_rej_models                           = size( i_rej_models, 1);

% Store results in table
tube_trend( i_f_dupl    , 'isFilterUnique') = {'No'};
tube_trend( i_s_conflict, 'isResultUnique') = {'No'};
% tube_trend{ i_s_conflict, 'isResultUnique'} = {'No'};

% Reset table  results
% tube_trend( : , 'isFilterUnique') = {'Yes'};
% tube_trend( : , 'isResultUnique') = {'Yes'};

% Display results
disp(  '------------------- KRW point and trend records --------------------');
disp( [' number of records                          = ' num2str( no_records)])
disp( [' number of unique records                   = ' num2str( no_series_unique)]);
disp( [' number of unique filters                   = ' num2str( no_filter_unique)])
disp( [' number of duplicate records                = ' num2str( no_records - no_series_unique)]);
disp( [' number of duplicate filters                = ' num2str( no_filter_duplicates)]);
disp( [' number of conflicting records              = ' num2str( no_series_conflicts)]);
disp(  '--------------------------------------------------------------------');
disp(  '');
disp(  '------------------------ Measurements found -----------------------');
disp( [' number of filters not found                = ' num2str( no_series_nan)]);
disp( [' number of filters not found duplicates     = ' num2str( no_series_unique_nan_dupl)]);
disp( [' number of filters not found unique         = ' num2str( no_series_nan_unique)]);
disp(  '--------------------------------------------------------------------');
disp(  '');
disp(  '---------------- Usability for trend assessment --------------------');
disp( [' number of incomplete series                = ' num2str( no_inc_series)]); % Including 3 duplicates
disp( [' number of incomplete models                = ' num2str( no_inc_models)]); % 38
disp( [' number of complete series                  = ' num2str( no_com_series)]); % 590
disp( [' number of complete models                  = ' num2str( no_com_models )]);% 552
%disp( [' number of rejected series                  = ' num2str( NaN )]);
disp( [' number of rejected models                  = ' num2str( no_rej_models )]);
%disp( [' number of accepted series                  = ' num2str( NaN )]);
disp( [' number of accepted models                  = ' num2str( no_com_models - no_rej_models )]);
disp(  '--------------------------------------------------------------------');
disp(  '');

% Export result tot Excel
exportTable2Excel( tube_trend);
end

% Conflicts are duplicates with unique results
% 
% 
% i_t_inc_period                    = find( isnan(  tube_trend{ :, 'Trend_M'}) & ~isnan(  tube_trend{ :, 'Start_M'}));
% i_t_inc_period                    = intersect( i_t_inc_period, i_f_un);  
%  
% i_t_t_u_found                     = setdiff( i_s_un_nan, i_s_nan_dupl);
% tube_trends_unique_found          = tube_trend( i_t_t_u_found, :);
% no_trends                         = size( tube_trend, 1);
% no_tubes                          = size( tubes_unique, 1);
% no_tube_absent                    = size( i_s_nan, 1);
% no_tube_trends_unique             = size( trends_unique, 1);
% 
% 
% no_trends_inc_period              = size( i_t_inc_period, 1);
