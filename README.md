# judilibre-admin

API d'indexation et d'administration de la plateforme JUDILIBRE.

## Dépendances

L'application nécessite node ainsi qu'une base de donnée elasticsearch, n'hésitez pas à jeter un coup d'oeil à [juridependencies](https://github.com/Cour-de-cassation/juridependencies).

La version de Node utilisée par ce projet est indiquée dans le fichier [.nvmrc](.nvmrc).

## Installation

```bash
npm install
```

## Utilisation de l'application

Configurer les variables d'environnement :
- Dupliquer le fichier `.env.example` et le renommer `.env`, adapter les variables d'environnement si besoin

### Avec Docker

```bash
npm run docker:start
```

### Sans Docker

Vous pouvez également lancer l'application sans utiliser docker avec la commande suivante :

```bash
npm run start:watch
```


#### Documentation ops
https://github.com/Cour-de-cassation/Knowledge-base-ops
