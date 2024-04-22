### Tic tack toe game

### Build and test

Project was done using Foundry. 

To build:
```
foundry build
```
To test:
```
foundry test
```

### Performed optimizations

My first implementation was done using multidimensional array `uint8[3][3]` but I moved it into the single `uint256` with cell
represented as bits in the continuous array. 