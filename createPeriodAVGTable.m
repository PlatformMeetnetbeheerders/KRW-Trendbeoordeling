function period_avg = createPeriodAVGTable()
% createPeriodAVGTable - create table with KRW periods and trend assesment
%
% OUTPUT
%  period_avg:
%    Table,  with KRW periods and trend assesment
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International)

% Create cellarray
c = {'StartDateTime', 'EndDateTime' , 'Avg_Measurement', 'Var_Avg_M', 'Conf_Int_Trend_M', 'Color_M', 'Avg_Residual', 'Var_Avg_R', 'Conf_Int_Trend_R', 'Color_R' ;...
     '[MatlabDate]' , '[MatlabDate]', '[m]'            , '[m]'      , '[m]'             , '[R G B]',  '[m]'        ,  '[m]'     ,  '[m]'            , '[R G B]' ;...     
      NaN           , NaN           , NaN              , NaN        , NaN               , [0 0 0]  ,   NaN         ,  NaN       ,   NaN             , [0 0 0] };

% Convert to table
period_avg = hymonCell2Table( c');

% Construct array with period startdates and enddates
year  = 1964 : 6 : 2018;
day   = ones( size( year));
month = ones( size( year));
dates = datenum( year, month, day)';

% Save to table
period_avg                                      = repmat(  period_avg, size( dates, 1) - 1, 1);
period_avg( :, {'StartDateTime' 'EndDateTime'}) = num2cell( [dates( 1 : end -1)   dates( 2 : end)]);
end