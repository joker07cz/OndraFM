# Preloader — zkrácení „zakázaného okna“ při zavádění

## Problém

Modul OndraSD po resetu dokola vysílá obsah `__LOADER.BIN` rychlostí 9600 Bd
a mezi opakováními dělá pauzu ~1,7 s. Obsluha musí na Ondrovi zadat `#` + ENTER
**v pauze**, tedy ve chvíli, kdy LED na TxD nesvítí.

Zavaděč v [`../loader/orig/`](../loader/orig/) má ~500 B, což je při 9600 Bd a vloženém
`TXDELAY` zhruba **625 ms vysílání** z cyklu ~2,3 s. Víc než čtvrtina času je
tedy „zakázané okno“ a uživatel se do něj snadno trefí.

Nový zavaděč s podporou 4 MHz ([`../loader/`](../loader/)) má už 863 B, tedy
o ~365 B víc než původní. Z naměřených časů v tabulce níž (122 B ~153 ms,
94 B ~118 ms, ~500 B ~625 ms) vychází ~1,25 ms na bajt; čistá linka 9600 Bd je
1,04 ms na bajt (10 bitů) a zbytek jsou mezery, které modul mezi bajty dělá.
Pro 863 B to je ~0,9 s (nejméně) až ~1,1 s (podle měřené rychlosti modulu).
Kdyby se vysílal jako autoboot, měl by zakázané okno ~1,1 s z cyklu ~2,8 s
(vysílání + pauza ~1,7 s), tedy ~39 % místo ~27 % u původního zavaděče.

## Řešení

Jako `__LOADER.BIN` se použije **preloader**, který jen

1. zastaví opakované vysílání (příkaz `N`),
2. vyžádá si od modulu původní zavaděč (příkaz `F` + `_LOADER2BIN`),
3. a načtení předá **systémové rutině `LOADER` v ROM Ondry** (`1972h`).

Sám tedy nic nedekóduje — formát `.BIN`, který modul posílá, umí ROM rozebrat
a spustit sama. Pro čtení ze sériové linky stačí v FCB (`FCBFLAGS`) nastavit
bit 2 (SERIAL I/O), plné volání `OPEN` není potřeba. Úspěšná cesta se nevrací:
`LOADER` načtený program sám spustí, takže `JP LOADER` je správně. Díky tomu je
preloader řádově kratší:

| Build | Velikost | Doba vysílání |
|---|---|---|
| `PROBES = 1` (s pípáním) | 122 B | ~153 ms |
| `PROBES = 0` (tichý, minimální) | 94 B | ~118 ms |
| zavaděč z `../loader/orig/` pro srovnání | ~500 B | ~625 ms |
| zavaděč z `../loader/` (863 B), kdyby šel jako autoboot | 863 B | ~1,1 s |

Zakázané okno tím klesne z ~27 % na ~8 % cyklu (153 ms z 153 + 1 700 ms).
Načtení `_LOADER2.BIN` (~0,9–1,1 s) probíhá až po `#` + ENTER, takže okno
nezvětšuje, jen prodlužuje cestu k FileManageru.

## Proč jsou v preloaderu prodlevy

Modul po autoboot přenosu ještě dopisuje zbytek sektoru a do čekací smyčky se
dostane až za chvíli. UART jednočipu nemá frontu, takže bez prodlevy je ohrožené
`F` se jménem souboru. První bajt (`N`) se ztratit nemůže, protože je první.
Původní zavaděč si tuhle prodlevu dělá dvěma pípnutími (~135 ms), proto má
preloader s `PROBES = 1` taky dvě pípnutí. `PROBES = 0` dělá tichou prodlevu
přibližně stejné délky (~150 ms). Za `N` je ještě krátká prodleva (~50 ms),
která kryje celé `F` se jménem souboru; modul po 11. bajtu jména prohledá
adresář na kartě (několik ms), takže se následující skok do `LOADER` stihne
s velkou rezervou.

## Co dát na kartu

Jméno `__LOADER.BIN` zabírá preloader, takže zavaděč se na kartě jmenuje
`_LOADER2.BIN` — pod tím jménem si ho preloader od modulu vyžádá:

| Na kartě jako | Vezmi odsud | Velikost |
|---|---|---|
| `__LOADER.BIN` | [`../dist/__LOADER.BIN`](../dist/__LOADER.BIN) — preloader, build `PROBES = 1` | 122 B |
| `_LOADER2.BIN` | [`../dist/_LOADER2.BIN`](../dist/_LOADER2.BIN) — zavaděč, zdroje v [`../loader/`](../loader/) | 863 B |
| `_ONDRAFM.BIN` | [`../dist/_ONDRAFM.BIN`](../dist/_ONDRAFM.BIN) — FileManager, zdroje v kořeni repozitáře ([`../make.asm`](../make.asm)) | 5 040 B |

Sada složená ze starších verzí (preloader 122 B, zavaděč 544 B, FileManager
4 747 B) byla ověřená na Ondrovi s OndraSD. **Aktuální sada, tedy s podporou
4 MHz, je ověřená v emulátoru JOndra a vyzkoušená na replice Ondry přepnuté na
4 MHz.** Přepínání taktu za běhu (hotswitch) na reálném stroji vyzkoušené není:
replika má jen čistý posuvný přepínač a pro spolehlivé přepnutí běžícího CPU by
potřebovala přídavný obvod proti zákmitům.

> **Jako `_LOADER2.BIN` nepoužívej nezměněný zavaděč z [`../loader/orig/`](../loader/orig/).**
> Má před prvním příkazem pro modul jen ~135 ms a v cestě přes preloader to
> nestačí — modul první příkazy zahodí, zavaděč pak čeká na odpověď, která
> nepřijde, a navenek to vypadá jako černá obrazovka.
>
> [`../loader/`](../loader/) je ten samý zavaděč s přidaným
> `LD HL,0D000h` / `CALL WAIT` (~690 ms) za úvodní pípnutí. S celkovou
> prodlevou ~0,83 s projde celý řetěz preloader → zavaděč → FileManager. Kde
> přesně mezi 135 ms a 0,83 s je hranice, změřené není. Druhá odlišnost je
> podpora 4 MHz, viz [`../changelog.txt`](../changelog.txt).
>
> Tyto časy počítají s 26 T na průchod smyčky `WAIT` (`DEC HL` 6, `LD A,H` 4,
> `OR L` 4, `JR NZ` 12). Dřívější odhady (~165 ms, ~825 ms, ~1 s) vycházely z
> 31 T, které uvádí komentář u `WAIT`; skutečné časy jsou o ~16 % kratší.

## Takt CPU 2 / 4 MHz

Preloader se pro 4 MHz **neupravuje**: čtení i zápis dělají rutiny v ROM, jejichž
časovky se nastavují při studeném startu. Podpora 4 MHz je v zavaděči
[`loader/`](../loader/) a ve FileManageru, popis je v [`changelog.txt`](../changelog.txt).

## Překlad

```sh
# z kořene repozitáře
(cd preloader && sjasmplus preload.asm)                         # -> dist/__LOADER.BIN
(cd loader && sjasmplus --raw=../dist/_LOADER2.BIN make.asm)    # -> dist/_LOADER2.BIN
```

Výstupní jméno si `preload.asm` určuje sám direktivou `OUTPUT` (cesta je
relativní k adresáři, ze kterého se překládá), zdroják zavaděče ne — tam se
předává na příkazové řádce. FileManager se překládá z kořene, viz
[`../README.md`](../README.md).

Varování `warning[fileorg]: ORG does not pad output file` je u preloaderu
v pořádku — hlavička `.BIN` se emituje od adresy 0 a `ORG` jen posune adresu
pro následující kód, výstup se plní sekvenčně.

Přeložené binárky jsou v repozitáři, aby se daly zkopírovat na kartu bez
instalace assembleru.

## Konfigurace

Na začátku [`preload.asm`](preload.asm) je jeden přepínač, `PROBES`. `1` přidá
dvě pípnutí na začátku (preloader se tím ozve, že běží) a jedno dlouhé nízké
pípnutí, když se zavaděč nenačte. `0` udělá tichou verzi (94 B, viz tabulka
výše), která nepípá vůbec. Jinak se oba buildy chovají stejně.

## Když se zavaděč nenačte

Když ROM `LOADER` narazí na chybu rámce, skončí `RET`em na to, co je na
zásobníku. Preloader proto před předáním řízení nastaví `SP` na `SPBAZE` (vrchol
systémového zásobníku, `0D4A0h`) a uloží tam vlastní obsluhu `LOADFAIL`; bez
toho stroj vypadá zamrzlý.

Chyba čtení není důvod stroj restartovat — OS se s ní umí vyrovnat sám.
Vypíše `?` a vrátí se do celoobrazovkového editoru; preloader k tomu jen
musí uklidit po sobě, tedy zapnout zpátky video, namapovat RAM a povolit
přerušení, které si na začátku zakázal. Bez toho stroj vypadá zamrzlý —
černá obrazovka a klávesnice bez reakce.

Tahle cesta je zatím vyzkoušená jen v emulátoru — na stroji je ověřené
úspěšné zavedení, ne chování při chybě.
