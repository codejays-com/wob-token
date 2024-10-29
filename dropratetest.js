const weights = [
    1000	,
    2500	,
    6500	,
    3500	,
    4000	,
    3500	,
    3500	,
    1500	,
    3000	,
    2800	,
    3100	,
    3000	,
    1500	,
    3000	,
    1250	,
    200	,
    700	,
    300	,
    200	,
    500	,
    180	,
    140	,
    180	,
    125	,
    160	
];

const multipliers = [
    75	,
    78	,
    80	,
    82	,
    85	,
    88	,
    90	,
    92	,
    95	,
    100	,
    105	,
    110	,
    115	,
    120	,
    125	,
    130	,
    135	,
    140	,
    145	,
    150	,
    175	,
    190	,
    200	,
    225	,
    250	
];

var cycleAmount = 0;
var returnAmount = 0;
var highLootTimes = 0;
var lossTimes = 0;
var profitTimes = 0; 
var breakEvenTimes = 0; 

const totalWeight = 46335;


const processSpin = (multiplier) => {
    
    cycleAmount =  parseFloat((cycleAmount  + 0.005).toFixed(10));
    returnAmount = parseFloat((returnAmount + 0.005 * multiplier / 100 * 0.985).toFixed(10)); // 0.985  
  
    if (multiplier < 100) {
        lossTimes = lossTimes + 1; 
    } else if (multiplier == 100) {
        breakEvenTimes = breakEvenTimes + 1;
    } else if (multiplier > 100 && multiplier < 200) {
        profitTimes = profitTimes + 1;
    } else if (multiplier >= 200) {
        highLootTimes = highLootTimes + 1;
    }
}


const main = () => {

    const randomValue = Math.floor(Math.random() * 10000000000000000000000000000000000000000000000000000000000000000000000000000);
    //const randomValue = 46334;
    
    let weightedRandom = randomValue % totalWeight;
    let cumulativeWeight = 0;

    for (var i = 0; i < weights.length; i++) {
        cumulativeWeight += weights[i];
        if (weightedRandom < cumulativeWeight) {
            processSpin(multipliers[i]);
           // console.log(weightedRandom, cumulativeWeight, multipliers[i]);
            break;
        }
    }
}

for (var j = 0; j < 5000; j++) {
    main();
    profitAmount =  cycleAmount - returnAmount;
}
console.log("profitAmount: ", profitAmount, " highLootTimes: ", highLootTimes, " lossTimes: ", lossTimes, " profitTimes: ", profitTimes, " breakEvenTimes: ", breakEvenTimes );
console.log("Cycled Amount: ", cycleAmount, " Returned amount: ", returnAmount);