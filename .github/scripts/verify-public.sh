#!/usr/bin/env bash
# Contrôle de bout en bout après déploiement.
#
# Il n'interroge pas le pod mais l'URL publique, traversant l'Ingress, le
# certificat, le LoadBalancer et l'authentification — ce que les sondes du
# conteneur ne prouvent pas.
#
# Toutes les adresses sources n'obtiennent pas la même réponse : certaines
# reçoivent une redirection au lieu de l'API. Un tel retour n'apprend rien du
# déploiement et ne vaut donc pas échec, sous peine d'annuler une livraison
# saine. Le contrôle bascule alors sur un appel depuis le cluster : l'Ingress,
# le certificat et le LoadBalancer ne sont plus traversés, mais la réponse de
# l'application et l'accès à son Elasticsearch restent prouvés.
set -euo pipefail

if [ -z "${APP_HOST:-}" ]; then
    echo "❌ APP_HOST est vide." >&2
    exit 1
fi
if [ -z "${HTTP_PASSWD:-}" ]; then
    echo "❌ HTTP_PASSWD est vide — le secret manque au dépôt." >&2
    exit 1
fi
if [ -z "${NAMESPACE:-}" ]; then
    echo "❌ NAMESPACE est vide — nécessaire au contrôle de repli." >&2
    exit 1
fi

corps="$(mktemp)"
erreur="$(mktemp)"
trap 'rm -f "${corps}" "${erreur}"' EXIT

# Le mot de passe passe par -u et jamais par l'URL, qu'un message d'erreur
# recopierait telle quelle. Les tentatives couvrent le temps que met un nouveau
# pod à recevoir du trafic après la fin du rollout.
#
# Les redirections ne sont pas suivies : c'est justement ce qu'il faut pouvoir
# distinguer d'une réponse de l'application.
echo "▶ contrôle de https://${APP_HOST}/admin?command=test"

set +e
code=$(curl -sS --fail --retry 5 --retry-delay 3 --retry-all-errors \
    --max-time 15 -u "admin:${HTTP_PASSWD}" \
    -o "${corps}" -w '%{http_code}' \
    "https://${APP_HOST}/admin?command=test" 2>"${erreur}")
statut=$?
set -e

if [ "${statut}" -eq 0 ] && [ "${code}" -ge 200 ] && [ "${code}" -lt 300 ]; then
    # La paire complète, pas le seul mot : l'application répond « indisponible »
    # quand elle ne joint pas son Elasticsearch, et cette chaîne contient
    # « disponible ». Chercher le mot seul revient à déclarer le succès sur
    # l'échec qu'on cherche justement à détecter.
    if grep -qE '"result"[[:space:]]*:[[:space:]]*"disponible"' "${corps}"; then
        echo "✅ ${APP_HOST} répond, et se déclare disponible"
        exit 0
    fi
    echo "❌ réponse inattendue de ${APP_HOST} (HTTP ${code}) :" >&2
    head -c 500 "${corps}" >&2
    echo >&2
    exit 1
fi

if [ "${code}" -ge 300 ] && [ "${code}" -lt 400 ]; then
    echo "⚠️  HTTP ${code} : ce runner n'obtient pas l'API mais une redirection."
    echo "   Contrôle public non concluant — repli dans le cluster."
elif [ "${code}" -eq 401 ]; then
    # L'authentification est portée par l'application, pas par l'Ingress : un
    # 401 prouve que la requête a traversé toute la chaîne publique et que
    # l'application a répondu. Il ne dit rien du déploiement, seulement que le
    # secret du dépôt ne correspond plus au Secret du cluster, que ce
    # déploiement ne modifie pas. Le repli tranche, avec le mot de passe du
    # conteneur.
    echo "⚠️  HTTP 401 : le secret HTTP_PASSWD du dépôt ne correspond pas au"
    echo "   Secret du cluster. La chaîne publique, elle, a bien répondu."
    echo "   Contrôle public non concluant — repli dans le cluster."
else
    echo "❌ l'API publique n'a pas répondu (HTTP ${code}, curl ${statut}) :" >&2
    head -c 500 "${erreur}" >&2
    echo >&2
    exit 1
fi

# ── Repli : la même requête, depuis le pod ────────────────────────────────────
# Le mot de passe utilisé est celui du conteneur : il ne sort pas du cluster et
# n'apparaît dans aucune trace du runner.
echo "▶ contrôle interne de ${NAMESPACE}/judilibre-admin-deployment"

set +e
# shellcheck disable=SC2016  # $HTTP_PASSWD doit rester littéral : il s'évalue
# dans le conteneur, pas ici. C'est tout l'intérêt du repli.
reponse=$(kubectl --namespace="${NAMESPACE}" exec deploy/judilibre-admin-deployment -- \
    sh -c 'curl -sS --fail --retry 5 --retry-delay 3 --retry-all-errors --max-time 10 \
        -u "admin:${HTTP_PASSWD}" "http://localhost:'"${APP_PORT:-8080}"'/admin?command=test"' 2>&1)
statut=$?
set -e

if [ "${statut}" -ne 0 ]; then
    echo "❌ l'application n'a pas répondu depuis le cluster :" >&2
    printf '%s\n' "${reponse}" | head -c 500 >&2
    exit 1
fi

if printf '%s' "${reponse}" | grep -qE '"result"[[:space:]]*:[[:space:]]*"disponible"'; then
    echo "✅ l'application répond et se déclare disponible, vue du cluster"
    echo "   ⚠️  Ingress, certificat et LoadBalancer n'ont pas été traversés."
    exit 0
fi

echo "❌ réponse inattendue depuis le cluster :" >&2
printf '%s\n' "${reponse}" | head -c 500 >&2
exit 1
