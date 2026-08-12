#!/usr/bin/env bash
# Revient à la révision précédente du Deployment.
#
# Avec maxUnavailable à 0, l'ancien pod sert toujours pendant un rollout raté :
# il n'y a pas de coupure à rattraper, mais l'objet resterait à mi-chemin sans
# cette étape.
set -euo pipefail

if [ -z "${NAMESPACE:-}" ]; then
    echo "❌ NAMESPACE est vide." >&2
    exit 1
fi

echo "↩ retour arrière sur ${NAMESPACE}/judilibre-admin-deployment"
kubectl --namespace="${NAMESPACE}" rollout undo deployment/judilibre-admin-deployment
kubectl --namespace="${NAMESPACE}" rollout status deployment/judilibre-admin-deployment --timeout=180s
echo "✅ révision précédente rétablie"
