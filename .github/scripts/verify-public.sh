#!/usr/bin/env bash
# Contrôle de bout en bout après déploiement, équivalent du test_minimal.sh que
# lançait l'ancienne chaîne.
#
# Il n'interroge pas le pod mais l'URL publique : il traverse donc l'Ingress, le
# certificat ACME, le LoadBalancer et l'authentification. Les sondes du pod, à
# l'inverse, ne prouvent que la santé interne du conteneur — c'est précisément
# ce qui manquait au portage.
set -euo pipefail

if [ -z "${APP_HOST:-}" ]; then
    echo "❌ APP_HOST est vide." >&2
    exit 1
fi
if [ -z "${HTTP_PASSWD:-}" ]; then
    echo "❌ HTTP_PASSWD est vide — le secret manque au dépôt." >&2
    exit 1
fi

# Le mot de passe passe par -u et jamais par l'URL : dans judilibre-sder, une URL
# complète finit dans les journaux en cas d'échec, donc dans Kibana. À ne pas
# reproduire ici.
#
# Les tentatives couvrent le temps que met un nouveau pod à recevoir du trafic
# après que le rollout s'est déclaré terminé.
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
