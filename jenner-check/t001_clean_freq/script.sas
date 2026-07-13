/* Mock Antwerp listings sample (character columns, mirroring a raw listings.csv)
   so the author's cleaning logic below runs standalone. */
data work.listings_raw;
    length id 8 price $10 room_type $20 property_type $12 accommodates $4 bedrooms $4
           bathrooms_text $16 beds $4 neighbourhood_cleansed $16 host_is_superhost $1
           number_of_reviews $6 review_scores_rating $6 review_scores_cleanliness $6
           availability_365 $6 instant_bookable $1 amenities $80;
    infile datalines dsd dlm='|' truncover;
    input id price $ room_type $ property_type $ accommodates $ bedrooms $ bathrooms_text $
          beds $ neighbourhood_cleansed $ host_is_superhost $ number_of_reviews $
          review_scores_rating $ review_scores_cleanliness $ availability_365 $
          instant_bookable $ amenities $;
    datalines;
101|$85.00|Entire home/apt|Apartment|4|2|1 bath|2|Antwerpen|t|45|4.8|4.9|120|f|["Wifi", "Kitchen", "Heating"]
102|$120.00|Entire home/apt|House|6|3|1.5 baths|3|Borgerhout|f|12|4.5|4.6|200|t|["Wifi", "Free parking"]
103|$45.00|Private room|Apartment|2|1|1 shared bath|1|Antwerpen|f|88|4.9|5.0|300|f|["Kitchen", "Heating"]
104|$210.00|Entire home/apt|Loft|5|2|2 baths|3|Berchem|t|7|4.2|4.1|50|t|["Wifi", "Washer", "Dryer"]
105|$65.00|Private room|House|2|1|1 bath|1|Deurne|f|150|4.7|4.8|280|f|["Wifi"]
106|$95.00|Entire home/apt|Apartment|3|1|1 bath|2|Borgerhout|t|33|4.6|4.7|95|f|["Wifi", "Kitchen"]
107|$300.00|Entire home/apt|House|8|4|3 baths|5|Antwerpen|t|3|5.0|5.0|30|t|["Wifi", "Pool", "Kitchen"]
108|$55.00|Private room|Apartment|1|1|1 shared bath|1|Berchem|f|64|4.4|4.5|340|f|["Heating"]
109|$150.00|Entire home/apt|Loft|4|2|1.5 baths|2|Deurne|t|21|4.8|4.9|110|t|["Wifi", "Kitchen", "Washer"]
110|$78.00|Entire home/apt|Apartment|3|1|1 bath|2||f||4.3||180|f|["Wifi", "Kitchen"]
111|$40.00|Private room|House|2|1|1 shared bath|1|Antwerpen|f|102|4.9|4.9|320|f|["Wifi"]
112|$185.00|Entire home/apt|Apartment|6|3|2 baths|4|Borgerhout|t|15|4.7|4.6|75|t|["Wifi", "Kitchen", "Heating", "Washer"]
113|$92.00|Entire home/apt|Loft|4|2|1 bath|2|Berchem|f|28|4.5|4.4|160|f|["Kitchen", "Heating"]
114|$68.00|Private room|Apartment|2|1|1 bath|1|Deurne|t|71|4.8|4.9|290|f|["Wifi", "Kitchen"]
115|$250.00|Entire home/apt|House|7|4|2.5 baths|4|Antwerpen|t|9|4.9|5.0|45|t|["Wifi", "Pool", "Free parking"]
116|$58.00|Private room|Apartment|2|1|1 shared bath|1|Borgerhout|f|55|4.6|4.7|310|f|["Heating"]
117|$135.00|Entire home/apt|House|5|2|1.5 baths|3|Berchem|t|18|4.7|4.8|130|t|["Wifi", "Kitchen", "Washer"]
118|$80.00|Entire home/apt|Apartment|3|1|1 bath|2|Deurne|f|40|4.4|4.3|220|f|["Wifi", "Kitchen"]
119|$105.00|Entire home/apt|Loft|4|2|1 bath|2|Antwerpen|t|25|4.8|4.9|100|f|["Wifi", "Heating"]
120|$62.00|Private room|House|2|1|1 shared bath|1|Borgerhout|f|90|4.9|5.0|330|f|["Wifi"]
;
run;

/* ---- Author's cleaning & feature engineering (Antwerp use this.sas, Steps 2-5) ---- */
data work.listings_clean;
    set work.listings_raw(keep=id price room_type property_type accommodates bedrooms bathrooms_text beds
        neighbourhood_cleansed host_is_superhost number_of_reviews
        review_scores_rating review_scores_cleanliness availability_365
        instant_bookable amenities);

    price_num = input(compress(price, '$,'), best12.);
    accommodates_num = input(accommodates, best12.);
    bedrooms_num = input(bedrooms, best12.);
    beds_num = input(beds, best12.);
    number_of_reviews_num = input(number_of_reviews, best12.);
    review_scores_rating_num = input(review_scores_rating, best12.);
    review_scores_cleanliness_num = input(review_scores_cleanliness, best12.);
    availability_365_num = input(availability_365, best12.);
    bathrooms = input(scan(bathrooms_text,1,' '), best12.);
    is_superhost = (host_is_superhost='t');
    is_instant_bookable = (instant_bookable='t');
    room_entire_home = (room_type="Entire home/apt");
    property_apartment = (property_type="Apartment");
    property_house = (property_type="House");
    property_loft = (property_type="Loft");
    has_wifi = (index(lowcase(amenities),"wifi")>0);
run;

data work.listings_clean2;
    set work.listings_clean;
    array char_vars{*} neighbourhood_cleansed;
    do i = 1 to dim(char_vars);
        if missing(char_vars{i}) then char_vars{i} = "Unknown";
    end;
    drop i price accommodates bedrooms beds host_is_superhost instant_bookable bathrooms_text amenities
         room_type property_type number_of_reviews review_scores_rating review_scores_cleanliness availability_365;
    rename price_num=price accommodates_num=accommodates bedrooms_num=bedrooms beds_num=beds;
run;

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

data work.listings_final;
    set work.listings_final;
    if 0 < price <= 1000 and accommodates <= 20 and bedrooms <= 10 and bathrooms <= 10 and beds <= 20;
run;

data work.listings_final;
    set work.listings_final;
    log_price = log(price);
run;

proc print data=work.listings_final(obs=10) noobs;
    var id price log_price bedrooms bathrooms accommodates room_entire_home has_wifi neighbourhood_cleansed;
    title "Cleaned Antwerp listings (first 10)";
run;

/* Step 7: Frequency for categorical variables */
proc freq data=work.listings_final;
    tables room_entire_home property_apartment property_house property_loft has_wifi neighbourhood_cleansed / nocum nopercent;
run;
title;
