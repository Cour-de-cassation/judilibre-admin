#!/usr/bin/env bash
# Revient à la révision précédente du Deployment.
#
# Avec maxUnavailable à 0, l'ancien pod sert toujours pendant un rollout raté :
# il n'y a pas de coupure à rattraper, mais l'objet resterait à mi-chemin sans
# cette étape.
#
# Ne défaire que ce qu'on a fait : un déploiement qui échoue **avant** d'avoir
# écrit le Deployment ne laisse rien à annuler, et lancer quand même un
# `rollout undo` ferait reculer une révision parfaitement saine, que nous
# n'avions pas touchée. Le témoin est l'image du Deployment vivant : tant
# qu'elle n'est pas celle qu'on vient de demander, notre apply n'a pas atterri.
#
# kubectl prévient par ailleurs qu'un retour arrière sur un objet géré par
# `apply` ne met pas à jour last-applied-configuration — le déploiement suivant
# repartirait donc d'une base fausse. Raison de plus pour ne s'y résoudre que
# lorsque c'est bien notre propre passage qu'il faut défaire.
set -euo pipefail

if [ -z "${NAMESPACE:-}" ]; then
    echo "❌ NAMESPACE est vide." >&2
    exit 1
fi
if [ -z "${IMAGE:-}" ]; then
    echo "❌ IMAGE est vide — impossible de savoir si notre apply a atterri." >&2
    exit 1
fi

image_vivante=$(kubectl --namespace="${NAMESPACE}" get deployment judilibre-admin-deployment \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

if [ "${image_vivante}" != "${IMAGE}" ]; then
    echo "⏭️  Rien à défaire : le Deployment porte toujours ${image_vivante:-aucune image}."
    echo "   L'échec est survenu avant que notre apply n'atteigne le cluster."
    exit 0
fi

echo "↩ retour arrière sur ${NAMESPACE}/judilibre-admin-deployment"
kubectl --namespace="${NAMESPACE}" rollout undo deployment/judilibre-admin-deployment
kubectl --namespace="${NAMESPACE}" rollout status deployment/judilibre-admin-deployment --timeout=180s
echo "✅ révision précédente rétablie"
