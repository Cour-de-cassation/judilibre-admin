#!/usr/bin/env bash
# Contrôle de bout en bout après déploiement.
#
# Il n'interroge pas le pod mais l'URL publique, traversant l'Ingress, le
# certificat, le LoadBalancer et l'authentification — ce que les sondes du
# conteneur ne prouvent pas.
set -euo pipefail

if [ -z "${APP_HOST:-}" ]; then
    echo "❌ APP_HOST est vide." >&2
    exit 1
fi
if [ -z "${HTTP_PASSWD:-}" ]; then
    echo "❌ HTTP_PASSWD est vide — le secret manque au dépôt." >&2
    exit 1
fi

# Le mot de passe passe par -u et jamais par l'URL, qu'un message d'erreur
# recopierait telle quelle. Les tentatives couvrent le temps que met un nouveau
# pod à recevoir du trafic après la fin du rollout.
echo "▶ contrôle de https://${APP_HOST}/admin?command=test"

if ! reponse=$(curl -sS --fail --retry 5 --retry-delay 3 --retry-all-errors \
        --max-time 15 -u "admin:${HTTP_PASSWD}" \
        "https://${APP_HOST}/admin?command=test" 2>&1); then
    echo "❌ l'API publique n'a pas répondu : ${reponse}" >&2
    exit 1
fi

if printf '%s' "${reponse}" | grep -q 'disponible'; then
    echo "✅ ${APP_HOST} répond, et se déclare disponible"
else
    echo "❌ réponse inattendue de ${APP_HOST} :" >&2
    printf '%s\n' "${reponse}" | head -c 500 >&2
    exit 1
fi
