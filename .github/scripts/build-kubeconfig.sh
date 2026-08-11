#!/usr/bin/env bash
# Fabrique ~/.kube/config à partir des cinq secrets du cluster visé.
#
# Le kubeconfig n'est jamais stocké : il est reconstruit à chaque exécution,
# vit le temps du job, et n'existe que sur un runner éphémère.
set -euo pipefail

for variable in KUBE_CA KUBE_NAME KUBE_TOKEN KUBE_URL KUBE_USER; do
    if [ -z "${!variable:-}" ]; then
        echo "❌ ${variable} est vide — le secret correspondant manque au dépôt." >&2
        exit 1
    fi
done

mkdir -p "${HOME}/.kube"
envsubst < .github/kubeconfig.template.yaml > "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"

# Contrôle de joignabilité avant de lancer quoi que ce soit : un kubeconfig
# invalide ou un cluster injoignable doit se voir ici, pas au milieu d'un
# déploiement à demi appliqué.
kubectl version -o json >/dev/null
echo "✅ kubeconfig valide, plan de contrôle joignable"
