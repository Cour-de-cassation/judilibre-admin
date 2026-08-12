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

- Dupliquer le fichier [.env-sample](.env-sample) et le renommer `.env`, adapter les variables d'environnement si besoin

L'application lit `API_PORT`, `APP_ID`, `ELASTIC_NODE`, `ELASTIC_INDEX`, `TRANSACTION_INDEX`, `HTTP_PASSWD` et `WITHOUT_ELASTIC`. Le second fichier, [.env-sample-scw](.env-sample-scw), ne sert pas à lancer l'application : il alimente les scripts de création d'environnement de `judilibre-ops`.

### Avec Docker

```bash
npm run start:docker
```

### Sans Docker

Vous pouvez également lancer l'application sans utiliser docker avec la commande suivante :

```bash
npm run start:watch
```

## Déploiement

L'application tourne sur deux plateformes : les clusters K3s internes, déployés par
le pipeline GitLab, et les clusters Scaleway, déployés par GitHub Actions. Les deux
exécutent le **même rôle Ansible**, celui de [ansible/roles/judilibre_admin](ansible/roles/judilibre_admin) ;
seules les valeurs des `group_vars` distinguent un environnement d'un autre.

Le détail des deux chaînes — déclenchement, image déployée, périmètre des objets
créés — est décrit dans [worklfow.md](worklfow.md).

#### Documentation ops

https://github.com/Cour-de-cassation/Knowledge-base-ops
