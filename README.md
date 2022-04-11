<div align="center">
    <h1>
        SportZchain Token Vesting Smart Contracts
    </h1>
</div>

## Prerequsite

- NodeJS >= v12.18.3

## Installation

1. clone repo
```
$ git clone https://github.com/sportzchain-core/token-vesting.git
$ cd token-vesting
```
2. copy `.env.example` file & rename it to `.env` 

3. add relevant data as mentioned in it

4. install node modules
```
$ npm i
```
5. compile contracts
```
$ npm run compile
```
5. test contracts

- run normal test
```
$ npm run test:normal
```
- run factory test
```
$ npm run test:factory
```
- run clone test
```
$ npm run test:clone
```