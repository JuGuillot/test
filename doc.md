## Installation du module LAPS

D'abord il vous faut entrer les commandes suivantes : `Import-Module LAPS` et `Update-LapsADSchema`. Vous verrez par la suite dans les propriétés des PC de l'AD les attributs suivants dans "Attribute Editor" ainsi qu'un nouvel onglet "LAPS" : 

![image](https://github.com/JuGuillot/test/assets/161329881/b488494a-99a6-4a55-94a9-258377d278e7)

## Attribuer les droits d'écriture aux machines

Exécuter la commande suivante pour que les droits s'appliquent sur l'ensemble des PC du domaine : 
- `Set-LapsADComputerSelfPermission -Identity "OU=Computer_Pharmgreen,DC=pharmgreen.org"`

![image](https://github.com/JuGuillot/test/assets/161329881/ed27114d-ecfc-4acb-bad0-d5e2ba06703d)

## Configurer la GPO Windows LAPS

Les paramètres de LAPS dans la GPO sont situés sous `Computer Organization -> Administrative Templates -> System -> LAPS`.

La première que nous allons configurer est `Configure password backup directory` comme ceci : 

![image](https://github.com/JuGuillot/test/assets/161329881/be6de093-8e14-4c4c-8a9f-f704568e636a)


