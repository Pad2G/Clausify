La funzione as-cnf chiama conjunctify sull'input che controlla la correttezza della
Formula Ben Formata, poi applica le regole 
per ridurla ad una CNF, ovvero riduce tutti i (not wff), doppie negazioni,
applica le leggi di De Morgan e distribuisce gli or sugli and della wff.

La funzione is-horn converte l'input in CNF, poi conta i letterali positivi,
se sono meno di 2 allora la clausola è di Horn.
