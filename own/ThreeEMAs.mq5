// Te linie to średnia krocząca (exponential movement average) 
// Pomarańcz 25 
// Niebieska 50 
// Czerowna 100 
// na H4 grane

// jak wszstkie są w ułożeniu od najmniejszej 25 - 50 - 100 to mamy trend wzrostowy 
// jak są w drugą stronę 100 50 25 to spadkowy

// jak cena zejdzie pod 50 w stronę 100 to transakcja (połowa normalnej transakcji) 
// jak cena zejdzie pod 100 to cała transakcjamamy  (mamy 1,5 normalnej pozycji w grze)
// jak cena spadnie jeszcze mały kawałek np 100 pips to wszystko zamykamy ze stratą
// ale jak wejdzie do góry to czekamy aż wróci na 25

// Patrze sobie na te strategie, ma to na EURUSD szanse zarobić

// jak mamy buy i cena wejdzie powyzej 25 to SL na 50tke
// jak wyjdziemy ZMEINNA ilosc punktow ponad 25 to SL po świeczkach

// filtr na minimalna odleglosc miedzy srednimi


// rozpoznawanie ranging market i gra od krawędzi do środka
// ATR na 14 a w nim ema na 50 ale oparta na first indicator data
// jak ATR jest pod EMA to oznacza że mamy ranging market