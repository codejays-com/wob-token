const weights = [
    3839,
3839,
3839,
4799,
3391,
3839,
5759,
1920,
3199,
6399,
64,
64,
64,
64,
64,
64,
64,
66,
64,
64,
64,
640,
2560,
1280,
0,
0,
320,
0,
6,
0,
0,
0,
0,
0,
0,
0
];

const multipliers = [
    75,
    78,
    80,
    82,
    85,
    88,
    90,
    92,
    95,
    100,
    105,
    110,
    115,
    120,
    125,
    130,
    135,
    140,
    145,
    150,
    175,
    190,
    200,
    225,
    250,
    300,
    500,
    1000,
    2000,
    5000,
    10000,
    0,
    0,
    0,
    0,
    0
];


const totalWeight = 46335;

const main = () => {

    const randomValue = Math.floor(Math.random() * 10000000000000000000000000000000000000000000000000000000000000000000000000000);
    //const randomValue = 46334;
    
    let weightedRandom = randomValue % totalWeight;
    let cumulativeWeight = 0;

    for (var i = 0; i < weights.length; i++) {
        cumulativeWeight += weights[i];
        if (weightedRandom < cumulativeWeight) {

            console.log(weightedRandom, randomValue, cumulativeWeight, i, multipliers[i], totalWeight );
            break;
        }
    }
}

for (var j = 0; j < 1000; j++) {
    main();
}
