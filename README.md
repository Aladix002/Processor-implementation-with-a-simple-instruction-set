# Implementácia procesoru s jednoduchou inštrukčnou sadou

## Úvod

Cieľom tohto projektu je implementovať pomocou VHDL procesor schopný vykonávať program napísaný v rozšírenej verzii jazyka BrainF*ck. Jazyk BrainF*ck používa len osem jednoduchých príkazov a je výpočtovo úplný, čo znamená, že s ním možno implementovať ľubovoľný algoritmus.

Procesor spracováva príkazy kódované pomocou tlačiteľných 8-bitových znakov. Vykonávanie programu začína prvou inštrukciou a končí, keď je detekovaný koniec sekvencie. Program aj dáta sú uložené v rovnakej pamäti s kapacitou 8192 8-bitových položiek. Pamäť je chápaná ako kruhový buffer. 

Implementovaný procesor podporuje niekoľko príkazov, ktoré sú definované v tabuľke nižšie.

| Príkaz | Operačný kód | Význam               | Ekvivalent v C          |
|--------|--------------|----------------------|-------------------------|
| >      | 0x3E         | Inkrementácia ukazovateľa   | ptr += 1;               |
| <      | 0x3C         | Dekrementácia ukazovateľa   | ptr -= 1;               |
| +      | 0x2B         | Inkrementácia hodnoty buňky | *ptr += 1;              |
| -      | 0x2D         | Dekrementácia hodnoty buňky | *ptr -= 1;              |
| [      | 0x5B         | Začiatok slučky while    | while (*ptr) {          || ]      | 0x5D         | Koniec slučky while      | }                       |
| .      | 0x2E         | Vytlačiť hodnotu buňky   | putchar(*ptr);          |
| ,      | 0x2C         | Načítať hodnotu do buňky | *ptr = getchar();       |
| @      | 0x40         | Oddelenie kódu a dát    | -                       |

## Mikrokontrolér

Na vykonávanie programov je potrebné doplniť procesor o pamäť programu, pamäť dát a vstupno-výstupné rozhranie. V našom prípade budeme uvažovať spoločnú pamäť programu a dát s kapacitou 8 kB.

Vstup a výstup dát by sa mohol v praxi riešiť pomocou vstupno-výstupných periférií, ako sú maticové klávesnice a LCD displeje.

## Úlohy

1. Seznamte sa s jednotlivými inštrukciami procesoru a vytvorte program v jazyku BrainF*ck, ktorý vytlačí na displej Váš login. Snažte sa využiť všetky dostupné príkazy s výnimkou príkazu načítania.
2. Spustite automatické testy pomocou testovacieho prostredia na serveri fitkit-build.

## Rozhranie procesoru

Procesor má štyri skupiny signálov: synchronizácia, pamäť programu a dát, vstupné rozhranie a výstupné rozhranie.

- **Synchronizačné rozhranie**: Obsahuje signály CLK, RESET a EN.
- **Pamäť programu a dát**: Obsahuje signály DATA ADDR, DATA RDATA, DATA WDATA, DATA EN, DATA RDWR.
- **Vstupné rozhranie**: Obsahuje signály IN REQ, IN VLD a IN DATA.
- **Výstupné rozhranie**: Obsahuje signály OUT BUSY, OUT DATA a OUT WE.

Cieľom procesoru je zrealizovať funkčnosť popísanú v projekte, čo sa dá overiť pomocou testov aj simuláciou.

Toto readme poskytuje základné informácie o implementácii procesoru s jednoduchou inštrukčnou sadou a ďalšie detaily sú uvedené v dokumentácii projektu.
