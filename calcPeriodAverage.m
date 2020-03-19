function period_avg = calcPeriodAverage( h, m)
% calcPeriodAverage - calculate the average of the series of measurements over 
%                    a period from startdate to enddate
%
% INPUT
%  h:
%    Struct, groundwater head data
%  startdate:
%    Double, start of period ( matlab date number)
%  enddate:
%    Double, end of period   ( matlab date number)
%
% OUTPUT
%  avg:
%    Double, time series average
%  std:
%    Double, standard deviation of average
%
% Written by Jos von Asmuth (Trefoil Hydrology) d.d.: 19-Mar-2020.
% Published by Platform Meetnetbeheerders, under the CC-BY Public License (Creative Commons Attribution 4.0 International)
% Based partly on script by :   Wouter Swierstra ( RHDHV)  d.d. : xx-xx-2012

%% Check and convert input - h
if ~isstruct( h) && ~isfield( h, 'values')
    error( [mfilename ':InvalidInput'], 'Error, invalid groundwater head data input.')
    return
end

% Default, start- and enddate
% if ~exist( 'periods', 'var') 
%     periods = [ h.values( 1, 1) h.values( end, 1)];
% end
% if h.values( 1, 1) > periods( 1, 1) && h.values( end, 1) < periods( end, end)
%     error( [mfilename ':InvalidInput'], 'Error, the period of measurement does not match the period of averaging')
%     return
% end

% Create table with KRW periods and trend assesment
period_avg = createPeriodAVGTable();

% loop through periods
for i = 1 : size( period_avg, 1)
           
    % Select measurements within period
    start_d      = period_avg{ i, 'StartDateTime'};
    end_d        = period_avg{ i, 'EndDateTime'};
    i_meas       = h.values( :, 1) >= start_d & h.values( :, 1) <= end_d;
    measurements = h.values( i_meas, 2);    
    
    % Select residuals within period
    i_meas       = m.result.r( :, 1) >= start_d & m.result.r( :, 1) <= end_d;
    residuals    = m.result.r( i_meas, 2);
    
    % Period averages
    period_avg( i, 'Avg_Measurement') = { mean( measurements)};      
    period_avg( i, 'Avg_Residual'   ) = { mean( residuals)};   
    
    % Standard deviation measurements
    n        = length( measurements);
    autocorr = xcorr( measurements,  n, 'coeff');                           % Autocorrelation lag -n to n ( length 2n+1)
    autocorr = autocorr( n + 2 : end -1);                                   % Select lags > 0
    corrfact = ( 1 + (( 2/n) * sum( [( n-1) : -1 : 1]' .* autocorr))) / n;  % See (Van Geer en Lourens, 2001)
    period_avg{ i, 'Var_Avg_M'} = var( measurements) * corrfact; 
               
    % Standard deviation Residuals
    n        = length( residuals);
    autocorr = xcorr( residuals,  n, 'coeff');                              % Autocorrelation lag -n to n ( length 2n+1)
    autocorr = autocorr( n + 2 : end -1);                                   % Select lags > 0
    corrfact = ( 1 + (( 2/n) * sum( (( n-1) : -1 : 1)' .* autocorr))) / n;  % See (Van Geer en Lourens, 2001)
    period_avg{ i, 'Var_Avg_R'} = var( residuals) * corrfact;         
end

% Set reference periode to 2000- 2006 (7), 2006 - 20012 (8)
i_ref_per =  7; % find( ~isnan( period_avg{ :, 'Avg_Measurement'}), 1, 'last');

% Calculate 95% confidence interval (+/-)
period_avg{ :, 'Conf_Int_Trend_M'} = 1.96 * sqrt( ( period_avg{ :, 'Var_Avg_M'} +  period_avg{ i_ref_per, 'Var_Avg_M'}));
period_avg{ :, 'Conf_Int_Trend_R'} = 1.96 * sqrt( ( period_avg{ :, 'Var_Avg_R'} +  period_avg{ i_ref_per, 'Var_Avg_R'}));

% Set Measurement line color to ( significant) increase or decline
i_pos     = period_avg{ :, 'Avg_Measurement'} < period_avg{ i_ref_per, 'Avg_Measurement'};
i_neg     = period_avg{ :, 'Avg_Measurement'} > period_avg{ i_ref_per, 'Avg_Measurement'} ;
i_pos_sig = period_avg{ :, 'Avg_Measurement'} + period_avg{ :, 'Conf_Int_Trend_M'} < period_avg{ i_ref_per, 'Avg_Measurement'};
i_neg_sig = period_avg{ :, 'Avg_Measurement'} - period_avg{ :, 'Conf_Int_Trend_M'} > period_avg{ i_ref_per, 'Avg_Measurement'};

% Invert last periods
 i_pos( [ 8 9]) = ~i_pos( [8 9]);
 i_neg( [ 8 9]) = ~i_neg( [8 9]);
 if i_pos_sig( 8)
     i_pos_sig( 8) = 0; i_neg_sig( 8) = 1;
 elseif  i_neg_sig( 8)
     i_pos_sig( 8) = 1; i_neg_sig( 8) = 0;
 end
 if i_pos_sig( 9)
     i_pos_sig( 9) = 0; i_neg_sig( 9) = 1;
 elseif  i_neg_sig( 9)
     i_pos_sig( 9) = 1; i_neg_sig( 9) = 0;
 end

b = .6;
c = 1;
period_avg{ i_pos    , 'Color_M'}  = [b c b]; % Increase             = light green
period_avg{ i_pos_sig, 'Color_M'}  = [0 1 0]; % Significant increase = green
period_avg{ i_neg    , 'Color_M'}  = [c b b]; % Decrease             = light red
period_avg{ i_neg_sig, 'Color_M'}  = [1 0 0]; % Significant decrease = red

% Set Residual line color to ( significant) increase or decline
i_pos     = period_avg{ :, 'Avg_Residual'} < period_avg{ i_ref_per, 'Avg_Residual'};
i_neg     = period_avg{ :, 'Avg_Residual'} > period_avg{ i_ref_per, 'Avg_Residual'} ;
i_pos_sig = period_avg{ :, 'Avg_Residual'} + period_avg{ :, 'Conf_Int_Trend_R'} < period_avg{ i_ref_per, 'Avg_Residual'};
i_neg_sig = period_avg{ :, 'Avg_Residual'} - period_avg{ :, 'Conf_Int_Trend_R'} > period_avg{ i_ref_per, 'Avg_Residual'};

% Invert last periods
 i_pos( [ 8 9]) = ~i_pos( [8 9]);
 i_neg( [ 8 9]) = ~i_neg( [8 9]);
 if i_pos_sig( 8)
     i_pos_sig( 8) = 0; i_neg_sig( 8) = 1;
 elseif  i_neg_sig( 8)
     i_pos_sig( 8) = 1; i_neg_sig( 8) = 0;
 end
 if i_pos_sig( 9)
     i_pos_sig( 9) = 0; i_neg_sig( 9) = 1;
 elseif  i_neg_sig( 9)
     i_pos_sig( 9) = 1; i_neg_sig( 9) = 0;
 end
period_avg{ i_pos    , 'Color_R'}  = [b c b]; % Increase             = light green
period_avg{ i_pos_sig, 'Color_R'}  = [0 1 0]; % Significant increase = green
period_avg{ i_neg    , 'Color_R'}  = [c b b]; % Decrease             = light red
period_avg{ i_neg_sig, 'Color_R'}  = [1 0 0]; % Significant decrease = red

% Set to zero / apply covariance for last period
period_avg{ i_ref_per, {'Conf_Int_Trend_M' 'Conf_Int_Trend_R'}}  = 0;
period_avg( i_ref_per, {'Color_M' 'Color_R'})                = {[ 0 0 0]};
end