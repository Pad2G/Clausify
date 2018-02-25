# Clausify
Convert any list-formatted Well Formed Formula into Conjunctive Normal Form

The function as-cnf first removes any implication, distributes (not wff) applying De Morgan's laws,
removes double negations and finally distributes ORs over ANDs.

Example:
```
(as-cnf '(or (and p q) r)) -> (AND (OR P R) (OR Q R))
```

The function is-horn returns T if its input is a Horn Clause.

Example: 
```
(is-horn '(implies p (not q))) -> T
```
