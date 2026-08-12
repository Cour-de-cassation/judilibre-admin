#!/usr/bin/env bash
# Revient à la révision précédente du Deployment.
#
# L'ancienne chaîne le faisait dans update_app.sh ; ne pas le reprendre aurait
# été une régression silencieuse. Avec maxUnavailable à 0, l'ancien pod sert
# toujours pendant un rollout raté — il n'y a donc pas de coupure à rattraper,
# mais l'objet resterait en état intermédiaire jusqu'à intervention humaine.
set -euo pipefail

if [ -z "${NAMESPACE:-}" ]; then
    echo "❌ NAMESPACE est vide." >&2
    exit 1
fi

echo "↩ retour arrière sur ${NAMESPACE}/judilibre-admin-deployment"
kubectl --namespace="${NAMESPACE}" rollout undo deployment/judilibre-admin-deployment
kubectl --namespace="${NAMESPACE}" rollout status deployment/judilibre-admin-deployment --timeout=180s
echo "✅ révision précédente rétablie"
