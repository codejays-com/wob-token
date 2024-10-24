import prand from 'pure-rand';



const NUMBERS = [
    32,
    15,
    19,
    4,
    21,
    2,
    25,
    17,
    34,
    6,
    27,
    13,
    36,
    11,
    30,
    8,
    23,
    10,
    5,
    24,
    16,
    33,
    1,
    20,
    14,
    31,
    9,
    22,
    18,
    29,
    7,
    28,
    12,
    35,
    3,
    26,
    0
    ];
    const redNumbers = [
    32,
    19,
    21,
    25,
    34,
    27,
    36,
    30,
    23,
    5,
    16,
    1,
    14,
    9,
    18,
    7,
    12,
    3
    ];

var playerStakeBank = 0;
var incentivesBank = 0;
var houseBank = 0;
var pool = 0;
const totalOptions = 37;

var numberRed = 0;
var numberBlack = 0;
var numberGreen = 0;

const getColor = (number) => {
    if (redNumbers.includes(number)) {
        numberRed = numberRed + 1;
        return "red";
    } else if (number === 0) {
        numberGreen = numberGreen + 1;
        return "green";
    } else {
        numberBlack = numberBlack + 1;
        return "black";
    }
}


const placeBet = () => {

    //console.log(prand.uniformIntDistribution(1, 180, rng));

    // const randomValue = Math.floor(Math.random() * 10000000000000000000000000000000000000000000000000000000000000000000000000000);
    //const randomValue = 46334;
    const seed = Date.now() ^ (Math.random() * 0x100000000) * Math.random()/Math.random();
    const rng = prand.xoroshiro128plus(seed);

    let randomValue = prand.uniformIntDistribution(1, 37, rng)[0];

    let weightedRandom = randomValue % totalOptions;
    let cumulativeWeight = 0;
    

    for (var i = 0; i < NUMBERS.length; i++) {
        cumulativeWeight += 1;
        if (weightedRandom < cumulativeWeight) {
            //console.log(weightedRandom, getColor(weightedRandom));
            getColor(weightedRandom);
            break;
        }
    }
}

for (var j = 0; j < 10000000; j++) {
    placeBet();
}

console.log("Red: ", numberRed, " at: ", numberRed/(numberRed+numberGreen+numberBlack),"%");
console.log("Black: ", numberBlack, " at: ", numberBlack/(numberRed+numberGreen+numberBlack),"%");
console.log("Green: ", numberGreen, " at: ", numberGreen/(numberRed+numberGreen+numberBlack),"%");


