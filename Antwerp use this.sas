
/*Setup*/

options nocenter nodate nonumber;
ods graphics on;

/*Step 1:Import data*/
proc import datafile='/home/u64133399/listings.csv'
    out=work.listings_raw
    dbms=csv
    replace;
    guessingrows=max;
    getnames=yes;
run;
/* Step 2: Data Cleaning & Useful Columns*/
data work.listings_clean;
    set work.listings_raw(keep=id price room_type property_type accommodates bedrooms bathrooms_text beds
        neighbourhood_cleansed host_is_superhost number_of_reviews
        review_scores_rating review_scores_cleanliness availability_365
        instant_bookable amenities);

/*Convert price to numeric */
    price_num = input(compress(price, '$,'), best12.);

/*Numeric conversion */
    accommodates_num = input(accommodates, best12.);
    bedrooms_num = input(bedrooms, best12.);
    beds_num = input(beds, best12.);
    number_of_reviews_num = input(number_of_reviews, best12.);
    review_scores_rating_num = input(review_scores_rating, best12.);
    review_scores_cleanliness_num = input(review_scores_cleanliness, best12.);
    availability_365_num = input(availability_365, best12.);

/*Extract bathrooms numeric */
    bathrooms = input(scan(bathrooms_text,1,' '), best12.);

/*Character to binary */
    is_superhost = (host_is_superhost='t');
    is_instant_bookable = (instant_bookable='t');
    room_entire_home = (room_type="Entire home/apt");
    property_apartment = (property_type="Apartment");
    property_house = (property_type="House");
    property_loft = (property_type="Loft");
    has_wifi = (index(lowcase(amenities),"wifi")>0);

/*Handle missing numeric values with mean*/
run;


/* Step 2b: Handle Missing Character Values */
data work.listings_clean2;
    set work.listings_clean;

    array char_vars{*} neighbourhood_cleansed;
    do i = 1 to dim(char_vars);
        if missing(char_vars{i}) then char_vars{i} = "Unknown";
    end;

    drop i price accommodates bedrooms beds host_is_superhost instant_bookable bathrooms_text amenities 
         room_type property_type number_of_reviews review_scores_rating review_scores_cleanliness availability_365;
    rename price_num=price
           accommodates_num=accommodates
           bedrooms_num=bedrooms
           beds_num=beds;
run;
/* Step 3: Impute missing numeric values with mean*/
proc means data=work.listings_clean2 noprint;
    var bedrooms bathrooms accommodates beds number_of_reviews_num review_scores_rating_num review_scores_cleanliness_num availability_365_num;
    output out=means_out mean=mean_bedrooms mean_bathrooms mean_accommodates mean_beds 
                        mean_number_of_reviews mean_review_scores_rating mean_review_scores_cleanliness mean_availability;
run;

data work.listings_final;
    if _N_=1 then set means_out;
    set work.listings_clean2;
    if missing(bedrooms) then bedrooms=mean_bedrooms;
    if missing(bathrooms) then bathrooms=mean_bathrooms;
    if missing(accommodates) then accommodates=mean_accommodates;
    if missing(beds) then beds=mean_beds;
    if missing(number_of_reviews_num) then number_of_reviews_num=mean_number_of_reviews;
    if missing(review_scores_rating_num) then review_scores_rating_num=mean_review_scores_rating;
    if missing(review_scores_cleanliness_num) then review_scores_cleanliness_num=mean_review_scores_cleanliness;
    if missing(availability_365_num) then availability_365_num=mean_availability;
run;

/* Step 4: Remove Outliers*/

data work.listings_final;
    set work.listings_final;
    if 0 < price <= 1000 and accommodates <= 20 and bedrooms <= 10 and bathrooms <= 10 and beds <= 20;
run;


/* Step 5: Transform Price*/

data work.listings_final;
    set work.listings_final;
    log_price = log(price);
run;
/* Step 6: Univariate & Correlation*/
ods graphics on;
ods select Moments Histogram Quantiles ExtremeObs BasicMeasures;

proc univariate data=work.listings_final;
    var price log_price;
    histogram price log_price / normal;
    inset mean median std skewness kurtosis / position=ne;
run;

proc corr data=work.listings_final plots=matrix(histogram);
    var log_price bedrooms bathrooms accommodates 
        review_scores_rating_num review_scores_cleanliness_num
        has_wifi room_entire_home;
run;
ods graphics off;


/* Step 6b: Multicollinearity Diagnostics*/
title "Multicollinearity Check using Variance Inflation Factor (VIF)";
proc reg data=work.listings_final;
    model log_price = bedrooms bathrooms accommodates 
                      review_scores_rating_num review_scores_cleanliness_num
                      has_wifi room_entire_home
                      / vif tol collin;
run;
quit;
title;

/* Step 7: Frequency for categorical variables*/
proc freq data=work.listings_final;
    tables room_entire_home property_apartment property_house property_loft has_wifi neighbourhood_cleansed / nocum nopercent;
run;
/* Step 8: Train/Test Split*/
proc surveyselect data=work.listings_final out=train_test_split samprate=0.8 outall seed=12345;
run;

data work.train work.test;
    set train_test_split;
    if selected=1 then output work.train;
    else output work.test;
run;
/* Step 9: LASSO Regression*/
proc glmselect data=work.train plots=all;
    model log_price = bedrooms bathrooms accommodates 
                      review_scores_rating_num review_scores_cleanliness_num
                      has_wifi room_entire_home
                      / selection=lasso(stop=CV) cvmethod=random(5) stats=all;
    partition fraction(validate=0.2);
    ods output ParameterEstimates=lasso_coeffs;
run;
/* Step 10: Decision Tree (HPSPLIT)*/
proc hpsplit data=work.train;
    class has_wifi room_entire_home;
    model log_price = bedrooms bathrooms accommodates
                      review_scores_rating_num review_scores_cleanliness_num
                      has_wifi room_entire_home;
    grow variance;
    prune costcomplexity;
    partition fraction(validate=0.2);
    code file="/home/u64133399/dt_scorecode.sas";
run;

data scored_test;
    set work.test;
    %include "/home/u64133399/dt_scorecode.sas";
run;
/* Step 11: Random Forest*/
data combined_data;
    set work.train(in=a) work.test(in=b);
    source = 'train'; if b then source='test';
run;

proc hpforest data=combined_data maxtrees=100 seed=12345;
    target log_price;
    input bedrooms bathrooms accommodates review_scores_rating_num review_scores_cleanliness_num / level=interval;
    input has_wifi room_entire_home / level=nominal;
    id id source;
    score out=rf_scored_all;
run;

data rf_scored_test;
    set rf_scored_all;
    if source='test';
run;
/* Step 12: RMSE Calculations*/
%macro calc_rmse(ds_in=, pred_var=, out_ds=);
data &out_ds;
    set &ds_in;
    error = log_price - &pred_var;
    sq_error = error**2;
run;

proc means data=&out_ds mean noprint;
    var sq_error;
    output out=&out_ds._out mean=sq_error;
run;
%mend;

%calc_rmse(ds_in=pred_test, pred_var=predicted, out_ds=rmse_lasso);
%calc_rmse(ds_in=scored_test, pred_var=P_log_price, out_ds=rmse_tree);
%calc_rmse(ds_in=rf_scored_test, pred_var=P_log_price, out_ds=rmse_rf);

/* Combine RMSEs */
data all_rmse;
    set rmse_lasso_out(in=a) rmse_tree_out(in=b) rmse_rf_out(in=c);
    length Model $20;
    if a then Model='LASSO Regression';
    else if b then Model='Decision Tree';
    else if c then Model='Random Forest';
    RMSE = sqrt(sq_error);
    keep Model RMSE;
run;

proc print data=all_rmse noobs label;
    title "RMSE Comparison of Models (Test Set)";
    label RMSE="Root Mean Square Error";
run;
