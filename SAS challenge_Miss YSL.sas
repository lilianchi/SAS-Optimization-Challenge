proc optmodel;
set WCCONTRACT=/WC1 WC2/;   /***Set index for data WCCONTRACT***/
set DETAIL=/1 2 3 4/;   /***Set index for data DETAIL***/

put WCCONTRACT=;
put DETAIL=;

num costwc{WCCONTRACT} = [0.15 0.12];   /***Set costwc values for WCCONTRACT***/
num mindemand{WCCONTRACT} = [25000 35000];   /***Set mindemand values for WCCONTRACT***/
num costst{DETAIL} = [0.18 0.18 0.1 0.1];   /***Set costst values for data DETAIL***/
num weeklydemand{DETAIL} = [52997.3 54931.6 72141.1 77860.3];   /***Set weeklydemand values for DETAIL***/
num precipitation{DETAIL} = [12000 18000 20000 22000];   /***Set precipitation values for DETAIL***/
num tanklevel = 62500;	/***Set current water level of storage tank as 62500 gallons***/


/***Declare demandstweekly variable for DETAIL and set lower bound***/
var demandstweekly{DETAIL};   
for {i in DETAIL}
do;
  demandstweekly[i].lb=0;
end;

/***Declare demandstweekly variable for DETAIL and set lower bound given the alternative contract***/
var altdemandstweekly{DETAIL};
for {i in DETAIL}
do;
  altdemandstweekly[i].lb=0;
end;   

/***Declare a binary variable x for WCCONTRACT and declare a constraint statement to decide on whether go for contract one or contract two***/
var x{WCCONTRACT} binary;
con selectcon: sum{i in WCCONTRACT} x[i] = 1;

/***Alternative for the binary output.***/ 
impvar y{i in WCCONTRACT} = 1-x[i];

/***Declare an implicit variable selectweekly to calculate the weekly minimum demand based on the contract chosen***/
impvar selectweekly=sum{i in WCCONTRACT} mindemand[i] * x[i];   

/***Declare an implicit variable altweekly to calculate the weekly minimum demand based on the alternative contract***/
impvar altweekly=sum{i in WCCONTRACT} mindemand[i] * y[i];   

/***Declare a variable demandwcweekly and set lower bound***/
var demandwcweekly{DETAIL};
for {i in DETAIL}
do;
  demandwcweekly[i].lb=0;
end;

/***Declare a variable altdemandwcweekly and set lower bound given the alternative contract***/
var altdemandwcweekly{DETAIL};
for {i in DETAIL}
do;
  altdemandwcweekly[i].lb=0;
end;

/***Declare a variable totalstwcdemand***/
impvar totalstwcdemand {i in DETAIL}=
demandwcweekly[i] + demandstweekly[i];

/***Declare a variable altotalstwcdemand given the alternative contract***/
impvar altotalstwcdemand {i in DETAIL}=
altdemandwcweekly[i] + altdemandstweekly[i];

/***Set implicit variables currentlevel and do the cumulative demand over the four weeks***/
impvar currentlevel{i in DETAIL} =
if i=1 then tanklevel + precipitation[i] - demandstweekly[i]
else currentlevel[i-1] + precipitation[i] - demandstweekly[i];

/***Set implicit variables altcurrentlevel and do the cumulative demand over the four weeks given the alternative contract***/
impvar altcurrentlevel{i in DETAIL} =
if i=1 then tanklevel + precipitation[i] - altdemandstweekly[i]
else altcurrentlevel[i-1] + precipitation[i] - altdemandstweekly[i];

/***Set an implicit variable selectweeklycost to calculate the weekly cost of Water Co. given the chosen contract***/
impvar selectweeklycost=sum{i in WCCONTRACT} costwc[i] * x[i]; 

/***Set an implicit variable altweeklycost to calculate the weekly cost of Water Co. given the alternative contract***/ 
impvar altweeklycost=sum{i in WCCONTRACT} costwc[i] * y[i]; 

/***Set implicit variables totakcostwc and totalcostst to calculate the total cost of Water Co. and Storage Tank respectively***/
impvar totalcostwc= sum{i in DETAIL} demandwcweekly[i]*selectweeklycost;
impvar totalcostst= sum{i in DETAIL} demandstweekly[i]*costst[i];

/***Set implicit variables alttotakcostwc to calculate the total cost of Water Co. given the alternative contract***/ 
impvar alttotalcostwc= sum{i in DETAIL} altdemandwcweekly[i]*altweeklycost;
impvar altotalcostst= sum{i in DETAIL} altdemandstweekly[i]*costst[i];

/***Declare a constraint statement on weekly storage tank demand equals or larger than 25% of weekly total demand***/
con leastdemandstweekly{i in DETAIL}: demandstweekly[i]>= totalstwcdemand[i]*0.25;   

/***Declare a constraint statement on weekly storage tank demand equals or larger than 25% of weekly total demand given the alternative contract***/
con altleastdemandstweekly{i in DETAIL}: altdemandstweekly[i]>= altotalstwcdemand[i]*0.25;  

/***Declare a constraint statement on weekly total demand equals or less than 
the sum of weekly Water Co. demand and Storage Tank demand***/
con weeklydemandcon{i in DETAIL}: weeklydemand[i] <= totalstwcdemand[i];

/***Declare a constraint statement on weekly total demand equals or less than 
the sum of weekly Water Co. demand and Storage Tank demand given the alternative contract***/
con altweeklydemandcon{i in DETAIL}: weeklydemand[i] <= altotalstwcdemand[i];

/***Declare a constraint statement on the weekly level of Storage Tank equal or greater than 30000 gallons***/
con weeklylevel{i in DETAIL}:currentlevel[i] >= 30000;

/***Declare a constraint statement on the weekly level of Storage Tank equal or greater than 30000 gallons 
given the alternative contract***/
con altweeklylevel{i in DETAIL}:altcurrentlevel[i] >= 30000;

/***Declare a constraint statement on weekly demand of Water Co. equal or greater than the weekly minimum demand based on the contract chosen***/
con weeklymindemand{i in DETAIL}: demandwcweekly[i]>=selectweekly;

/***Declare a constraint statement on weekly demand of Water Co. equal or greater than the weekly minimum demand given the alternative contract***/
con altweeklymindemand{i in DETAIL}: altdemandwcweekly[i]>=altweekly;

/***Set the optimization target***/
min TotalCost = totalcostwc + totalcostst;

/***Set the optimization target given the alternative contract***/
min ALT_TotalCost = alttotalcostwc + altotalcostst;

expand;
solve with lso / maxtime=600 nthreads=4 primalin;   /***Solve the problem using the LSO Solver***/

print costst weeklydemand demandstweekly demandwcweekly precipitation; /*DETAIL*/
print costwc mindemand;  /*WCCONTRACT*/

print TotalCost.sol;
print x;
print selectweeklycost selectweekly;

print costst weeklydemand altdemandstweekly altdemandwcweekly precipitation; /*DETAIL for alternative*/
print ALT_TotalCost.sol;
print y;
print altweeklycost altweekly;

quit;
